// NativeThemes.cs - DynALisp.Ribbon: the native palettes of AutoCAD in the dark of DynALisp (experiment)
// Copyright (C) 2026  Samuel Martineau
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// EXPERIMENT, not supported by Autodesk. The palettes written in C++ (Properties, its property
// inspector) do not use the managed PaletteTheme of Skin.cs: they draw with the native themes
// of AdUi (CAdUiTheme, owned by the CAdUiThemeManager of the ObjectARX headers), one colour per
// AdUiThemeElement (kPaletteBackground, kInspectorTop, kInspectorItem...). No .NET API reaches
// them, so this file finds them in AutoCAD itself, when it is idle:
//   - the functions, in the export tables of the modules loaded whose name starts with "adui"
//     (AdUi25.dll...), by their full C++ names, which say their exact arguments: a function
//     whose name is not exactly the one expected is never called, and nothing is done;
//   - the theme manager, from an exported function that returns it and takes nothing;
//   - the themes, by the names known (those of AutoCAD 2026: ACTIVETHEME, PropertyPalette...),
//     each asked of the manager with HasTheme (a lookup, it creates nothing) at each call, since
//     a palette makes its theme when it first opens; when none is there (another version), by
//     the words (UTF-16 and ASCII) in the read-only data of every module of the AutoCAD folder.
// Each dark theme found (IsDark, or a dark kPaletteBackground) has its colours (elements 8 to
// 199: kPaletteBackground to the frame colours, the fonts before them left as they are) put
// through Skin.Map with SetColor, between SuspendModifiedNotifications and
// ResumeModifiedNotifications, then SendModifiedNotification tells the palettes to draw again
// once (each SetColor alone redraws them: they flickered); what each was is kept,
// to give it back. Several names may give the same theme, and themes may share their colours:
// a theme is filtered once, and a colour already given is never filtered again (Skin.Map
// darkens each time, so the colours would flip between the two). AutoCAD sets them again when
// its theme changes: a colour found that DynALisp did not give makes its theme filtered again.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Media;

namespace DynALisp.Ribbon
{
    public static class NativeThemes
    {
        // The colours of AdUiThemeElement: kPaletteBackground (8) to kAppFrameQATOuterBorder
        // (199), the elements known (adui Global Enums.h); 0 to 7 are fonts.
        const int First = 8, Last = 199;

        const string NameGetTheme = "?GetTheme@CAdUiThemeManager@@QEAAPEAVCAdUiTheme@@PEB_W@Z";
        const string NameHasTheme = "?HasTheme@CAdUiThemeManager@@QEBAHPEB_W@Z";
        const string NameRelease = "?ReleaseTheme@CAdUiThemeManager@@QEAAHPEAVCAdUiTheme@@@Z";
        const string NameGetColor = "?GetColor@CAdUiTheme@@QEBAKW4AdUiThemeElement@@@Z";
        const string NameSetColor = "?SetColor@CAdUiTheme@@QEAAHW4AdUiThemeElement@@K@Z";
        const string NameIsDark = "?IsDark@CAdUiTheme@@QEBA_NXZ";
        // Not needed, used when there: the colours of a theme set together, with one
        // notification (one SetColor is one redraw of every palette of the theme: they flickered).
        const string NameSuspend = "?SuspendModifiedNotifications@CAdUiTheme@@QEAAXXZ";
        const string NameResume = "?ResumeModifiedNotifications@CAdUiTheme@@QEAAXXZ";
        const string NameSend = "?SendModifiedNotification@CAdUiTheme@@QEBAXXZ";
        // A function that returns the manager: ?<name>@@YAPEAVCAdUiThemeManager@@XZ
        const string ManagerSuffix = "@@YAPEAVCAdUiThemeManager@@XZ";

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr GetManagerFn();
        [UnmanagedFunctionPointer(CallingConvention.ThisCall, CharSet = CharSet.Unicode)] delegate IntPtr GetThemeFn(IntPtr self, string name);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall, CharSet = CharSet.Unicode)] delegate int HasThemeFn(IntPtr self, string name);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate int ReleaseFn(IntPtr self, IntPtr theme);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate uint GetColorFn(IntPtr self, int element);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate int SetColorFn(IntPtr self, int element, uint color);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate byte IsDarkFn(IntPtr self);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate void ThemeFn(IntPtr self);

        static bool _looked;
        static string _fail;
        static IntPtr _manager;
        static GetThemeFn _getTheme;
        static HasThemeFn _hasTheme;
        static ReleaseFn _release;
        static GetColorFn _getColor;
        static SetColorFn _setColor;
        static IsDarkFn _isDark;
        static ThemeFn _suspend, _resume, _send;
        static List<string> _names = new();
        static bool _searched;
        // What the search saw, for (Dyl:RibbonSkin "Native"): the words, the modules, the time,
        // and the module each theme name was found in.
        static int _words, _modules;
        static long _ms;
        static readonly Dictionary<string, string> Where = new(StringComparer.Ordinal);
        // Each theme found, as it was the last time the palettes were put in the dark:
        static readonly List<string> Seen = new();

        // The themes changed: their pointer, and (element, colour it had, colour given).
        sealed class Done
        {
            public IntPtr Theme;
            public string Name;
            public readonly List<(int El, uint Was, uint Now)> Colours = new();
            // Filtered again (a colour found that DynALisp did not give), the last colour so
            // found, and given up past Limit: AutoCAD sets it again each time (it would flicker).
            public int Again, LastEl;
            public uint LastGiven, LastFound;
            public bool GaveUp;
        }
        const int Limit = 3;
        // The names of the functions of CAdUiTheme exported, for (Dyl:RibbonSkin "Native" "Exports"):
        static readonly List<string> Exported = new();
        static readonly List<Done> Changed = new();

        public static string Status()
        {
            if (_fail != null) return "native palettes not found: " + _fail;
            if (Changed.Count == 0) return "native palettes: none changed";
            return "native palettes " + string.Join(", ", Changed.Select(d => d.Name)) + " (" + Changed.Sum(d => d.Colours.Count) + " colours)";
        }

        // The names of the themes found in AutoCAD 2026 (the search of (Dyl:RibbonSkin "Native"
        // "Search")): asked first, so the search of every module runs only when none is there.
        static readonly string[] Known = {
            "ACTIVETHEME", "OwnerDrawButton", "DockControlBar", "DockBar", "PaletteSet", "DialogWorksheet",
            "ToolPalette", "paletteset", "paletteSet", "PropertyPalette" };

        // The names already seen (changed, the same theme as another name, or light), not asked again:
        static readonly HashSet<string> Taken = new(StringComparer.Ordinal);
        // Every colour given, so a theme seen under two names (or sharing its colours with
        // another one) is never filtered twice, and a colour AutoCAD set again is told apart:
        static readonly HashSet<uint> Given = new();

        // Run by Skin.OnIdle: on (the palettes wanted, AutoCAD dark) or off. A theme made later
        // (PropertyPalette, when Properties first opens) is found at the next call.
        public static void Apply(bool on)
        {
            try
            {
                if (!on) { Undo(); return; }
                if (!Find()) return;
                foreach (var d in Changed)
                {
                    if (d.GaveUp) continue;
                    int i = d.Colours.FindIndex(x => !Given.Contains(_getColor(d.Theme, x.El)));
                    if (i < 0) continue;
                    var c = d.Colours[i];
                    d.Again++;
                    d.LastEl = c.El; d.LastGiven = c.Now; d.LastFound = _getColor(d.Theme, c.El);
                    if (d.Again > Limit) { GiveUp(d); continue; }
                    Filter(d);
                }
                foreach (var name in _names)
                {
                    // A name known is made by GetTheme when it is not there yet (PropertyPalette,
                    // before Properties first opens): the palette finds it in the colours of
                    // DynALisp, and never shows those of AutoCAD first.
                    if (Taken.Contains(name) || (!Known.Contains(name) && _hasTheme(_manager, name) == 0)) continue;
                    IntPtr theme = _getTheme(_manager, name);
                    if (theme == IntPtr.Zero) continue;
                    Taken.Add(name);
                    var same = Changed.FirstOrDefault(d => d.Theme == theme);
                    if (same != null) { _release(_manager, theme); Seen.Add(name + ": the theme of " + same.Name); continue; }
                    uint bg = _getColor(theme, First);
                    bool dark = _isDark(theme) != 0;
                    string seen = name + " (" + Where.GetValueOrDefault(name, "known") + "): " + (dark ? "dark" : "light")
                        + ", background " + Hex(bg);
                    if (!dark && Skin.Lightness(FromRef(bg)) >= 0.5) { Seen.Add(seen + ", left as it is"); _release(_manager, theme); continue; }
                    var nd = new Done { Theme = theme, Name = name };
                    Filter(nd);
                    Seen.Add(seen + ", " + nd.Colours.Count + " colours changed");
                    Changed.Add(nd);
                }
            }
            catch (System.Exception ex) { _fail = ex.Message; Host.Log("native palettes: " + ex.Message); }
        }

        // Puts the colours of a theme through Skin.Map, those it has now: a colour already given
        // is left (the theme shares it, or was filtered already), and so is a key colour (black
        // or almost, which a palette may use as its transparent colour).
        static void Filter(Done d) => Quiet(d.Theme, () => FilterAll(d));

        // The colours of a theme changed with its notifications suspended, then one sent:
        static void Quiet(IntPtr theme, Action change)
        {
            if (_suspend == null) { change(); return; }
            _suspend(theme);
            try { change(); }
            finally { _resume(theme); _send(theme); }
        }

        static void FilterAll(Done d)
        {
            var was = d.Colours.ToDictionary(c => c.El);
            d.Colours.Clear();
            for (int el = First; el <= Last; el++)
            {
                uint cur = _getColor(d.Theme, el);
                if (Given.Contains(cur))
                {
                    if (was.TryGetValue(el, out var w) && w.Now == cur) d.Colours.Add(w);
                    continue;
                }
                if (Key(cur)) continue;
                uint now = ToRef(Skin.Map(FromRef(cur)));
                if (now == cur) continue;
                _setColor(d.Theme, el, now);
                Given.Add(now);
                d.Colours.Add((el, cur, now));
            }
        }

        // A theme AutoCAD keeps setting again: its colours given back, and left alone.
        static void GiveUp(Done d)
        {
            Quiet(d.Theme, () => Back(d));
            d.Colours.Clear();
            d.GaveUp = true;
            Host.Log("native palettes: " + d.Name + " given up, set again " + d.Again + " times");
        }

        static bool Key(uint c) => (c & 0xFF) <= 3 && ((c >> 8) & 0xFF) <= 3 && ((c >> 16) & 0xFF) <= 3;

        // What was found and done, one line each, for (Dyl:RibbonSkin "Native"):
        public static List<string> Report(bool exports = false)
        {
            var r = new List<string>();
            if (!_looked) { r.Add("not searched yet (the palettes off, or AutoCAD not dark)"); return r; }
            r.Add(_searched ? _words + " words in " + _modules + " modules, " + _ms + " ms" : "the names known (\"Search\" to search every module)");
            if (_fail != null) r.Add("not found: " + _fail);
            if (_names != null) r.Add(_names.Count + " themes: " + string.Join(", ", _names));
            if (_suspend == null) r.Add("no SuspendModifiedNotifications: one redraw per colour");
            r.AddRange(Seen);
            foreach (var d in Changed.Where(d => d.Again > 0))
                r.Add(d.Name + ": set again by AutoCAD " + d.Again + " times (element " + d.LastEl + ": given " + Hex(d.LastGiven)
                    + ", found " + Hex(d.LastFound) + ")" + (d.GaveUp ? ", given up" : ""));
            if (exports) r.AddRange(Exported);
            return r;
        }

        static string Hex(uint c) => "#" + (c & 0xFF).ToString("X2") + ((c >> 8) & 0xFF).ToString("X2") + ((c >> 16) & 0xFF).ToString("X2");

        static void Back(Done d)
        {
            foreach (var (el, was, now) in d.Colours)
                if (_getColor(d.Theme, el) == now) _setColor(d.Theme, el, was);
        }

        static void Undo()
        {
            Taken.Clear();
            Seen.Clear();
            if (_setColor == null) { Changed.Clear(); return; }
            for (int i = Changed.Count - 1; i >= 0; i--)    // the last first: a colour shared goes back to the first
            {
                var d = Changed[i];
                try
                {
                    if (d.Colours.Count > 0) Quiet(d.Theme, () => Back(d));
                    _release(_manager, d.Theme);
                }
                catch { }
            }
            Changed.Clear();
            Given.Clear();
        }

        // COLORREF (0x00BBGGRR) and back:
        static Color FromRef(uint c) => Color.FromRgb((byte)(c & 0xFF), (byte)((c >> 8) & 0xFF), (byte)((c >> 16) & 0xFF));
        static uint ToRef(Color c) => (uint)(c.R | (c.G << 8) | (c.B << 16));

        // ---- finding them ----

        static bool Find()
        {
            if (_looked) return _fail == null;
            _looked = true;
            var exports = new Dictionary<string, IntPtr>();
            var modules = new List<ProcessModule>();
            foreach (ProcessModule m in Process.GetCurrentProcess().Modules)
                if (m.ModuleName.StartsWith("adui", StringComparison.OrdinalIgnoreCase)) modules.Add(m);
            if (modules.Count == 0) { _fail = "no AdUi module"; return false; }
            foreach (var m in modules) Exports(m.BaseAddress, exports);
            Exported.AddRange(exports.Keys.OrderBy(k => k, StringComparer.Ordinal));

            IntPtr F(string name) => exports.TryGetValue(name, out var p) ? p : IntPtr.Zero;
            var need = new[] { NameGetTheme, NameHasTheme, NameRelease, NameGetColor, NameSetColor, NameIsDark };
            var missing = need.Where(n => F(n) == IntPtr.Zero).ToList();
            var getter = exports.Where(kv => kv.Key.StartsWith("?") && kv.Key.EndsWith(ManagerSuffix)).Select(kv => kv.Value).ToList();
            if (missing.Count > 0) { _fail = "functions " + string.Join(" ", missing.Select(n => n.Substring(1, n.IndexOf('@') - 1))); return false; }
            if (getter.Count != 1) { _fail = getter.Count + " functions returning the theme manager"; return false; }

            _getTheme = Marshal.GetDelegateForFunctionPointer<GetThemeFn>(F(NameGetTheme));
            _hasTheme = Marshal.GetDelegateForFunctionPointer<HasThemeFn>(F(NameHasTheme));
            _release = Marshal.GetDelegateForFunctionPointer<ReleaseFn>(F(NameRelease));
            _getColor = Marshal.GetDelegateForFunctionPointer<GetColorFn>(F(NameGetColor));
            _setColor = Marshal.GetDelegateForFunctionPointer<SetColorFn>(F(NameSetColor));
            _isDark = Marshal.GetDelegateForFunctionPointer<IsDarkFn>(F(NameIsDark));
            if (F(NameSuspend) != IntPtr.Zero && F(NameResume) != IntPtr.Zero && F(NameSend) != IntPtr.Zero)
            {
                _suspend = Marshal.GetDelegateForFunctionPointer<ThemeFn>(F(NameSuspend));
                _resume = Marshal.GetDelegateForFunctionPointer<ThemeFn>(F(NameResume));
                _send = Marshal.GetDelegateForFunctionPointer<ThemeFn>(F(NameSend));
            }
            _manager = Marshal.GetDelegateForFunctionPointer<GetManagerFn>(getter[0])();
            if (_manager == IntPtr.Zero) { _fail = "no theme manager"; return false; }

            _names = Known.ToList();
            if (Known.Any(n => _hasTheme(_manager, n) != 0)) return true;
            Search();
            if (_names.Count == 0) { _fail = "no theme name among " + _words + " words"; return false; }
            return true;
        }

        // Every word of the read-only data of the modules of the AutoCAD folder asked of the
        // manager: the names of the themes of another version of AutoCAD, added to those known.
        // About a second: run when none of the names known is there, or by (Dyl:RibbonSkin
        // "Native" "Search").
        public static void Search()
        {
            if (!Find() && _manager == IntPtr.Zero) return;
            var clock = Stopwatch.StartNew();
            var proc = Process.GetCurrentProcess();
            string home = System.IO.Path.GetDirectoryName(proc.MainModule.FileName) + System.IO.Path.DirectorySeparatorChar;
            var words = new Dictionary<string, string>(StringComparer.Ordinal);
            _modules = 0;
            foreach (ProcessModule m in proc.Modules)
            {
                if (!m.ModuleName.StartsWith("adui", StringComparison.OrdinalIgnoreCase) && !m.FileName.StartsWith(home, StringComparison.OrdinalIgnoreCase)) continue;
                try { Words(m.BaseAddress, m.ModuleName, words); _modules++; } catch { }
            }
            _words = words.Count;
            foreach (var (w, mod) in words)
            {
                if (_hasTheme(_manager, w) == 0) continue;
                if (!_names.Contains(w)) _names.Add(w);
                Where[w] = mod;
            }
            _ms = clock.ElapsedMilliseconds;
            _searched = true;
            if (_names.Count > 0 && _fail != null && _fail.StartsWith("no theme name")) _fail = null;
        }

        // The names and addresses of the functions a module exports (its export table):
        static void Exports(IntPtr b, Dictionary<string, IntPtr> into)
        {
            int pe = Marshal.ReadInt32(b, 0x3C);
            if (Marshal.ReadInt32(b, pe) != 0x4550) return;              // "PE\0\0"
            int opt = pe + 24;
            if (Marshal.ReadInt16(b, opt) != 0x20B) return;              // PE32+
            int dir = Marshal.ReadInt32(b, opt + 112);                   // export directory
            if (dir == 0) return;
            int count = Marshal.ReadInt32(b, dir + 0x18);
            int funcs = Marshal.ReadInt32(b, dir + 0x1C);
            int names = Marshal.ReadInt32(b, dir + 0x20);
            int ords = Marshal.ReadInt32(b, dir + 0x24);
            for (int i = 0; i < count; i++)
            {
                string name = Marshal.PtrToStringAnsi(b + Marshal.ReadInt32(b, names + 4 * i));
                if (name == null || !(name.Contains("CAdUiTheme"))) continue;
                int ord = (ushort)Marshal.ReadInt16(b, ords + 2 * i);
                into[name] = b + Marshal.ReadInt32(b, funcs + 4 * ord);
            }
        }

        // The words in the read-only data of a module (.rdata), in UTF-16 and in ASCII: the
        // names the themes may have, with the module they were found in.
        static void Words(IntPtr b, string module, Dictionary<string, string> into)
        {
            int pe = Marshal.ReadInt32(b, 0x3C);
            int sections = Marshal.ReadInt16(b, pe + 6);
            int optSize = Marshal.ReadInt16(b, pe + 20);
            int sec = pe + 24 + optSize;
            for (int s = 0; s < sections; s++, sec += 40)
            {
                var raw = new byte[8];
                Marshal.Copy(b + sec, raw, 0, 8);
                if (Encoding.ASCII.GetString(raw).TrimEnd('\0') != ".rdata") continue;
                int size = Marshal.ReadInt32(b, sec + 8), at = Marshal.ReadInt32(b, sec + 12);
                var data = new byte[size];
                Marshal.Copy(b + at, data, 0, size);
                var cur = new StringBuilder();
                for (int i = 0; i + 1 < size; i += 2)                    // UTF-16
                {
                    char c = (char)(data[i] | (data[i + 1] << 8));
                    if (Part(c)) { cur.Append(c); continue; }
                    if (c == '\0') Take(cur.ToString(), module, into);
                    cur.Clear();
                }
                cur.Clear();
                for (int i = 0; i < size; i++)                           // ASCII
                {
                    char c = (char)data[i];
                    if (c < 128 && Part(c)) { cur.Append(c); continue; }
                    if (c == '\0') Take(cur.ToString(), module, into);
                    cur.Clear();
                }
            }
        }

        static bool Part(char c) => char.IsLetterOrDigit(c) || c == '_' || c == ' ' || c == '.' || c == '-';

        const int MaxWords = 1500000;

        static void Take(string w, string module, Dictionary<string, string> into)
        {
            if (w.Length >= 3 && w.Length <= 40 && char.IsLetter(w[0]) && into.Count < MaxWords)
                into.TryAdd(w, module);
        }
    }
}
