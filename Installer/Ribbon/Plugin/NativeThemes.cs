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
//   - the names of the themes, among the words (UTF-16 and ASCII) in the read-only data of
//     every module of the AutoCAD folder, each asked of the manager with HasTheme (a lookup,
//     it creates nothing): a palette may draw with a theme of its own (Properties).
// Each dark theme found (IsDark, or a dark kPaletteBackground) has its colours (elements 8 to 199: kPaletteBackground to the frame
// colours, the fonts before them left as they are) put through Skin.Map with SetColor, which
// tells the palettes to draw again; what each was is kept, to give it back. AutoCAD sets them
// again when its theme changes: a colour found changed is filtered again.

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
        // A function that returns the manager: ?<name>@@YAPEAVCAdUiThemeManager@@XZ
        const string ManagerSuffix = "@@YAPEAVCAdUiThemeManager@@XZ";

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr GetManagerFn();
        [UnmanagedFunctionPointer(CallingConvention.ThisCall, CharSet = CharSet.Unicode)] delegate IntPtr GetThemeFn(IntPtr self, string name);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall, CharSet = CharSet.Unicode)] delegate int HasThemeFn(IntPtr self, string name);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate int ReleaseFn(IntPtr self, IntPtr theme);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate uint GetColorFn(IntPtr self, int element);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate int SetColorFn(IntPtr self, int element, uint color);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate byte IsDarkFn(IntPtr self);

        static bool _looked;
        static string _fail;
        static IntPtr _manager;
        static GetThemeFn _getTheme;
        static HasThemeFn _hasTheme;
        static ReleaseFn _release;
        static GetColorFn _getColor;
        static SetColorFn _setColor;
        static IsDarkFn _isDark;
        static List<string> _names;
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
        }
        static readonly List<Done> Changed = new();

        public static string Status()
        {
            if (_fail != null) return "native palettes not found: " + _fail;
            if (Changed.Count == 0) return "native palettes: none changed";
            return "native palettes " + string.Join(", ", Changed.Select(d => d.Name)) + " (" + Changed.Sum(d => d.Colours.Count) + " colours)";
        }

        // Run by Skin.OnIdle: on (the palettes wanted, AutoCAD dark) or off.
        public static void Apply(bool on)
        {
            try
            {
                if (!on) { Undo(); return; }
                if (!Find()) return;
                if (Changed.Count > 0 && !Reset()) return;   // still as they were left
                Undo();
                Seen.Clear();
                foreach (var name in _names)
                {
                    IntPtr theme = _getTheme(_manager, name);
                    if (theme == IntPtr.Zero) { Seen.Add(name + ": no theme"); continue; }
                    uint bg = _getColor(theme, First);
                    bool dark = _isDark(theme) != 0;
                    string seen = name + " (" + Where.GetValueOrDefault(name, "?") + "): " + (dark ? "dark" : "light")
                        + ", background " + Hex(bg);
                    if (!dark && Skin.Lightness(FromRef(bg)) >= 0.5) { Seen.Add(seen + ", left as it is"); _release(_manager, theme); continue; }
                    var d = new Done { Theme = theme, Name = name };
                    for (int el = First; el <= Last; el++)
                    {
                        uint was = _getColor(theme, el);
                        uint now = ToRef(Skin.Map(FromRef(was)));
                        if (now == was) continue;
                        _setColor(theme, el, now);
                        d.Colours.Add((el, was, now));
                    }
                    Seen.Add(seen + ", " + d.Colours.Count + " colours changed");
                    Changed.Add(d);
                }
            }
            catch (System.Exception ex) { _fail = ex.Message; Host.Log("native palettes: " + ex.Message); }
        }

        // What was found and done, one line each, for (Dyl:RibbonSkin "Native"):
        public static List<string> Report()
        {
            var r = new List<string>();
            if (!_looked) { r.Add("not searched yet (the palettes off, or AutoCAD not dark)"); return r; }
            r.Add(_words + " words in " + _modules + " modules, " + _ms + " ms");
            if (_fail != null) r.Add("not found: " + _fail);
            if (_names != null) r.Add(_names.Count + " themes: " + string.Join(", ", _names));
            r.AddRange(Seen);
            return r;
        }

        static string Hex(uint c) => "#" + (c & 0xFF).ToString("X2") + ((c >> 8) & 0xFF).ToString("X2") + ((c >> 16) & 0xFF).ToString("X2");

        // True when AutoCAD set a colour again since (its theme changed): filtered again.
        static bool Reset()
        {
            foreach (var d in Changed)
            {
                var (el, _, now) = d.Colours.FirstOrDefault();
                if (d.Colours.Count > 0 && _getColor(d.Theme, el) != now) return true;
            }
            return false;
        }

        static void Undo()
        {
            if (_setColor == null) { Changed.Clear(); return; }
            foreach (var d in Changed)
            {
                try
                {
                    foreach (var (el, was, now) in d.Colours)
                        if (_getColor(d.Theme, el) == now) _setColor(d.Theme, el, was);
                    _release(_manager, d.Theme);
                }
                catch { }
            }
            Changed.Clear();
        }

        // COLORREF (0x00BBGGRR) and back:
        static Color FromRef(uint c) => Color.FromRgb((byte)(c & 0xFF), (byte)((c >> 8) & 0xFF), (byte)((c >> 16) & 0xFF));
        static uint ToRef(Color c) => (uint)(c.R | (c.G << 8) | (c.B << 16));

        // ---- finding them ----

        static bool Find()
        {
            if (_looked) return _fail == null;
            _looked = true;
            var clock = Stopwatch.StartNew();
            var exports = new Dictionary<string, IntPtr>();
            var modules = new List<ProcessModule>();
            var others = new List<ProcessModule>();
            var proc = Process.GetCurrentProcess();
            string home = System.IO.Path.GetDirectoryName(proc.MainModule.FileName) + System.IO.Path.DirectorySeparatorChar;
            foreach (ProcessModule m in proc.Modules)
            {
                string n = m.ModuleName;
                if (n.StartsWith("adui", StringComparison.OrdinalIgnoreCase)) modules.Add(m);
                else if (m.FileName.StartsWith(home, StringComparison.OrdinalIgnoreCase)) others.Add(m);
            }
            if (modules.Count == 0) { _fail = "no AdUi module"; return false; }
            foreach (var m in modules) Exports(m.BaseAddress, exports);

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
            _manager = Marshal.GetDelegateForFunctionPointer<GetManagerFn>(getter[0])();
            if (_manager == IntPtr.Zero) { _fail = "no theme manager"; return false; }

            var words = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var m in modules.Concat(others))
            {
                try { Words(m.BaseAddress, m.ModuleName, words); _modules++; } catch { }
            }
            _words = words.Count;
            _names = new List<string>();
            foreach (var (w, mod) in words)
            {
                if (_hasTheme(_manager, w) == 0) continue;
                _names.Add(w);
                Where[w] = mod;
            }
            _ms = clock.ElapsedMilliseconds;
            if (_names.Count == 0) { _fail = "no theme name among " + words.Count + " words"; return false; }
            return true;
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

        const int MaxWords = 400000;

        static void Take(string w, string module, Dictionary<string, string> into)
        {
            if (w.Length >= 3 && w.Length <= 40 && char.IsLetter(w[0]) && into.Count < MaxWords)
                into.TryAdd(w, module);
        }
    }
}
