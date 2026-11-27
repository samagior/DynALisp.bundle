// CppThemes.cs - DynALisp.Ribbon: the colour themes of AutoCAD written in C++ (experiment)
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
// EXPERIMENT, not supported by Autodesk. Two parts of AutoCAD keep the blue-greys of its dark
// theme under DynALisp Neutral, since they draw with neither the themes of Skin.cs nor the
// CAdUiTheme of NativeThemes.cs:
//   - the native lists and buttons of the palettes (the combo boxes of Properties, the Sheet
//     Set Manager) read CAcColorTheme of AdUi (adui26.dll), one colour per AcThemeElement;
//   - the title bar, drawn in C++ by AdImpApplicationFrame, reads AdColorTheme of
//     AdApplicationFrame.dll, one colour per AdThemeElement.
// Both are reached by the functions they export (their full C++ names, so their arguments are
// the ones expected): GetCurrentTheme, GetRGBColor and SetColor. How many elements they have is
// not in any header: (Dyl:RibbonSkin "Hosted" "Colors") read them in AutoCAD 2027, 0 to 307 for
// CAcColorTheme (then values that are no colours) and 0 to 46 for AdColorTheme (then zeros).
// So nothing is written in another version of AutoCAD (Application.Version 26 only), nor past
// those elements, nor in a theme whose memory is not writable (VirtualQuery).
//
// Only the blue-greys of AutoCAD are changed (215 to 220 degrees, 12 to 22 %, Hosted.Blue), each
// through Skin.Map once, from the colour AutoCAD gave it; the blues of what is picked and
// hovered (#465E75, #517898, more saturated) and every other colour stay. What each one was is
// kept, to give it back when the interface is off or another look is chosen. AutoCAD sets them
// again when its theme changes: a colour found back at what AutoCAD gave is given again. After a
// change, the windows of AutoCAD draw again (RedrawWindow) and the title bar with
// AdApplicationFrame::ForceFrameRepaint. The title bar takes them; the lists of Properties do
// not until the native themes of the palettes (NativeThemes.cs) are given the current
// CAcColorTheme (CAdUiTheme::SetColorTheme, the dark theme 0), as AutoCAD does when its theme
// changes: done after each change of its colours and when a native theme is found, the colours
// it sets there taken as given (NativeThemes.Adopt); given again the colours of AutoCAD when
// turned off. (Dyl:RibbonSkin "Hosted" "Push") does it by hand.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Media;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    public static class CppThemes
    {
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr StaticFn();
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate uint GetFn(IntPtr self, int element);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate void SetFn(IntPtr self, int element, uint colour);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate byte SetBoolFn(IntPtr self, int element, uint colour);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate void RepaintFn(IntPtr self, IntPtr hwnd);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate IntPtr HwndFn(IntPtr self);

        // One theme of C++: its functions, and the colours changed (element -> what AutoCAD
        // gave, what DynALisp gave).
        sealed class Theme
        {
            public string Name, Prefix, GetCurrent, GetColor, SetColor;
            public bool SetReturnsBool;
            public int Count;
            public StaticFn Current;
            public GetFn Get;
            public SetFn Set;
            public SetBoolFn SetB;
            public string Fail;
            public readonly Dictionary<int, (uint Was, uint Given)> Changed = new();
            public IntPtr Last;

            public void Write(IntPtr t, int e, uint v)
            {
                if (SetB != null) SetB(t, e, v); else Set(t, e, v);
            }
        }

        static readonly Theme Ac = new Theme
        {
            Name = "CAcColorTheme", Prefix = "adui26", Count = 308,
            GetCurrent = "?GetCurrentTheme@CAcColorTheme@@SAAEBV1@XZ",
            GetColor = "?GetRGBColor@CAcColorTheme@@QEBAKW4AcThemeElement@1@@Z",
            SetColor = "?SetColor@CAcColorTheme@@QEAAXW4AcThemeElement@1@K@Z",
        };

        static readonly Theme Frame = new Theme
        {
            Name = "AdColorTheme", Prefix = "AdApplicationFrame", Count = 47, SetReturnsBool = true,
            GetCurrent = "?GetCurrentTheme@AdColorTheme@@SAPEAV1@XZ",
            GetColor = "?GetRGBColor@AdColorTheme@@UEBAKW4AdThemeElement@1@@Z",
            SetColor = "?SetColor@AdColorTheme@@IEAA_NW4AdThemeElement@1@K@Z",
        };

        const string NameAppFrame = "?spAppFrame@AdApplicationFrame@@1PEAV1@EA";
        const string NameRepaint = "?ForceFrameRepaint@AdApplicationFrame@@QEAAXPEAUHWND__@@@Z";
        const string NameFrameHwnd = "?GetAppFrameHwnd@AdApplicationFrame@@QEAAPEAUHWND__@@XZ";

        static readonly Theme[] Themes = { Ac, Frame };
        static bool _on, _found;
        static Look _look = Look.DynALisp;
        static int _next, _pushed = -1;
        static bool _acWrote;
        static SetColorThemeFn _give;
        static string _fail;
        static IntPtr _appFrame;
        static RepaintFn _repaint;
        static HwndFn _frameHwnd;
        const int Every = 2000;

        public static string Status()
        {
            if (_fail != null) return "C++ themes: " + _fail;
            return "C++ themes " + string.Join(", ", Themes.Select(t =>
                t.Name + " " + (t.Fail ?? t.Changed.Count + " colours")));
        }

        // Run by Skin.OnIdle (once a second at most).
        public static void Apply(bool on, Look look)
        {
            try
            {
                if (!on)
                {
                    if (_on) Undo();
                    _on = false;
                    return;
                }
                if (_on && look != _look) Undo();
                bool first = !_on;
                _on = true;
                _look = look;
                if (!first && Environment.TickCount - _next < 0) return;
                _next = Environment.TickCount + Every;
                if (!_found) Find();
                bool any = false;
                foreach (var t in Themes) any |= Keep(t);
                // The native themes of the palettes given the colours of CAcColorTheme, as AutoCAD
                // does when its theme changes (the lists of Properties draw from them): when they
                // changed, and when a native theme is found (Properties opened the first time).
                int n = NativeThemes.Pointers().Count();
                if (Ac.Changed.Count > 0 && (_acWrote || n != _pushed))
                {
                    _pushed = n;
                    Give(out _);
                    NativeThemes.Adopt();
                    any = true;
                }
                _acWrote = false;
                if (any) Repaint();
            }
            catch (System.Exception ex) { _fail = ex.Message; Host.Log("C++ themes: " + ex.Message); }
        }

        // The functions of each theme, found once.
        static void Find()
        {
            _found = true;
            int major = 0;
            try { major = AcApp.Version.Major; } catch { }
            foreach (var t in Themes)
            {
                if (major != 26) { t.Fail = "not checked in this version of AutoCAD"; continue; }
                ProcessModule mod = null;
                foreach (ProcessModule m in Process.GetCurrentProcess().Modules)
                    if (m.ModuleName.StartsWith(t.Prefix, StringComparison.OrdinalIgnoreCase)) { mod = m; break; }
                if (mod == null) { t.Fail = t.Prefix + " not loaded"; continue; }
                var ex = new Dictionary<string, IntPtr>();
                NativeThemes.Exports(mod.BaseAddress, ex, x => x == t.GetCurrent || x == t.GetColor || x == t.SetColor
                    || x == NameAppFrame || x == NameRepaint || x == NameFrameHwnd);
                if (!ex.TryGetValue(t.GetCurrent, out var g) || !ex.TryGetValue(t.GetColor, out var c) || !ex.TryGetValue(t.SetColor, out var s))
                { t.Fail = "functions not found"; continue; }
                t.Current = Marshal.GetDelegateForFunctionPointer<StaticFn>(g);
                t.Get = Marshal.GetDelegateForFunctionPointer<GetFn>(c);
                if (t.SetReturnsBool) t.SetB = Marshal.GetDelegateForFunctionPointer<SetBoolFn>(s);
                else t.Set = Marshal.GetDelegateForFunctionPointer<SetFn>(s);
                if (t == Frame)
                {
                    if (ex.TryGetValue(NameAppFrame, out var p)) _appFrame = p;
                    if (ex.TryGetValue(NameRepaint, out var r)) _repaint = Marshal.GetDelegateForFunctionPointer<RepaintFn>(r);
                    if (ex.TryGetValue(NameFrameHwnd, out var h)) _frameHwnd = Marshal.GetDelegateForFunctionPointer<HwndFn>(h);
                }
            }
        }

        static Color Rgb(uint v) => Color.FromRgb((byte)(v & 0xFF), (byte)(v >> 8 & 0xFF), (byte)(v >> 16 & 0xFF));
        static uint Ref(Color c) => (uint)(c.R | c.G << 8 | c.B << 16);

        // A blue-grey of AutoCAD's panels, not the blue of what is picked or hovered:
        static bool Panel(Color c)
        {
            if (!Hosted.Blue(c)) return false;
            Skin.ToHsl(c, out _, out double s, out _);
            return s <= 0.22;
        }

        // The colours of a theme put in the look, and kept there; true when one was written.
        static bool Keep(Theme t)
        {
            if (t.Current == null) return false;
            IntPtr theme = t.Current();
            if (theme == IntPtr.Zero) { t.Fail = "no current theme"; return false; }
            if (theme != t.Last)
            {
                // Another theme made current: what was given to the other one is forgotten
                // (AutoCAD keeps it), this one is filtered.
                if (!Writable(theme)) { t.Fail = "theme not writable"; return false; }
                t.Changed.Clear();
                t.Last = theme;
                t.Fail = null;
            }
            bool wrote = false;
            for (int e = 0; e < t.Count; e++)
            {
                uint v = t.Get(theme, e);
                uint rgb = v & 0xFFFFFF;
                if (t.Changed.TryGetValue(e, out var k))
                {
                    if (rgb == (k.Given & 0xFFFFFF)) continue;
                    if (rgb != (k.Was & 0xFFFFFF)) { t.Changed.Remove(e); }
                    else { t.Write(theme, e, k.Given); wrote = true; continue; }
                }
                var c = Rgb(v);
                if (!Panel(c)) continue;
                var m = Skin.Map(c, _look);
                if (m == c) continue;
                uint given = (v & 0xFF000000) | Ref(m);
                t.Write(theme, e, given);
                if ((t.Get(theme, e) & 0xFFFFFF) != (given & 0xFFFFFF))
                {
                    t.Fail = "SetColor changes nothing (element " + e + ")";
                    return wrote;
                }
                t.Changed[e] = (v, given);
                wrote = true;
            }
            if (wrote && t == Ac) _acWrote = true;
            return wrote;
        }

        static void Undo()
        {
            foreach (var t in Themes)
            {
                try
                {
                    if (t.Current != null && t.Changed.Count > 0)
                    {
                        IntPtr theme = t.Current();
                        if (theme == t.Last)
                            foreach (var (e, k) in t.Changed)
                                if ((t.Get(theme, e) & 0xFFFFFF) == (k.Given & 0xFFFFFF)) t.Write(theme, e, k.Was);
                    }
                }
                catch { }
                t.Changed.Clear();
                t.Last = IntPtr.Zero;
            }
            // The native themes given the colours of AutoCAD again:
            if (_pushed >= 0) { try { Give(out _); } catch { } _pushed = -1; }
            Repaint();
        }

        // ---- drawing again ----

        const uint RDW_INVALIDATE = 0x1, RDW_ERASE = 0x4, RDW_ALLCHILDREN = 0x80, RDW_FRAME = 0x400;

        [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr hwnd, IntPtr rect, IntPtr rgn, uint flags);
        [DllImport("user32.dll")] static extern bool EnumThreadWindows(uint thread, EnumProc proc, IntPtr lp);
        [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
        delegate bool EnumProc(IntPtr hwnd, IntPtr lp);

        static void Repaint()
        {
            try
            {
                // The windows of AutoCAD's thread (the main window, its floating palettes):
                EnumThreadWindows(GetCurrentThreadId(), (h, _) =>
                {
                    RedrawWindow(h, IntPtr.Zero, IntPtr.Zero, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN);
                    return true;
                }, IntPtr.Zero);
                // The title bar, drawn by the frame:
                if (_appFrame != IntPtr.Zero && _repaint != null)
                {
                    IntPtr frame = Marshal.ReadIntPtr(_appFrame);
                    if (frame != IntPtr.Zero)
                    {
                        IntPtr hwnd = _frameHwnd != null ? _frameHwnd(frame) : IntPtr.Zero;
                        if (hwnd == IntPtr.Zero) hwnd = AcApp.MainWindow.Handle;
                        _repaint(frame, hwnd);
                    }
                }
            }
            catch (System.Exception ex) { Host.Log("C++ themes, repaint: " + ex.Message); }
        }

        // ---- the copies of the table (a report) ----

        const string NameGetTheme = "?GetTheme@CAcColorTheme@@SAAEBV1@W4AcColorThemeEnum@@@Z";
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr ThemeOfFn(int which);

        // For (Dyl:RibbonSkin "Hosted" "Colors"), read only: where the colours of CAcColorTheme
        // are kept (the lists of Properties kept the blue-greys once the current theme was
        // changed), and the elements of the native themes still in a blue-grey.
        public static void Copies(List<string> r)
        {
            r.Add("Copies of the colours of CAcColorTheme (" + Status() + ")");
            if (!_found) Find();
            if (Ac.Current == null) { r.Add("  not found: " + Ac.Fail); return; }
            IntPtr cur = Ac.Current();
            var was = new uint[Ac.Count];
            var now = new uint[Ac.Count];
            for (int e = 0; e < Ac.Count; e++)
            {
                now[e] = Ac.Get(cur, e) & 0xFFFFFF;
                was[e] = Ac.Changed.TryGetValue(e, out var k) && cur == Ac.Last ? k.Was & 0xFFFFFF : now[e];
            }
            r.Add("  current theme " + Hex(cur) + ", " + Ac.Changed.Count + " colours changed in it");
            // GetTheme of each value of AcColorThemeEnum (0 and 1):
            ProcessModule mod = Process.GetCurrentProcess().Modules.Cast<ProcessModule>()
                .FirstOrDefault(m => m.ModuleName.StartsWith(Ac.Prefix, StringComparison.OrdinalIgnoreCase));
            var ptrs = new List<(string, IntPtr)> { ("current", cur) };
            if (mod != null)
            {
                var ex = new Dictionary<string, IntPtr>();
                NativeThemes.Exports(mod.BaseAddress, ex, x => x == NameGetTheme);
                if (ex.TryGetValue(NameGetTheme, out var g))
                {
                    var of = Marshal.GetDelegateForFunctionPointer<ThemeOfFn>(g);
                    for (int i = 0; i < 2; i++)
                    {
                        IntPtr p = of(i);
                        ptrs.Add(("GetTheme(" + i + ")", p));
                        r.Add("  GetTheme(" + i + ") " + Hex(p) + (p == cur ? " (the current one)" : "")
                            + (p != IntPtr.Zero ? ", element 212 " + Col(Ac.Get(p, 212)) + ", element 0 " + Col(Ac.Get(p, 0)) : ""));
                    }
                }
                else r.Add("  GetTheme not exported");
            }
            foreach (var (n, p) in NativeThemes.Pointers()) ptrs.Add(("CAdUiTheme " + n, p));
            // Where the current colours lie, from the theme (inline or behind a pointer):
            r.Add("  current colours at " + Where(cur, now, ptrs));
            // The theme object is 8 bytes (GetTheme(1) follows GetTheme(0)): what it holds,
            // and the first bytes it points to. The colours are not a table of 4 bytes each (a
            // search of the whole memory found no copy of them): a map, read by GetRGBColor.
            try
            {
                IntPtr q = Marshal.ReadIntPtr(cur);
                r.Add("  the current theme holds " + Hex(q) + (Readable(q, 64) ? ": " + Bytes(q, 64) : " (not readable)"));
            }
            catch (System.Exception x) { r.Add("  layout: " + x.Message); }
            // The native themes of the palettes (CAdUiTheme), elements 0 to 399: those still in
            // a blue-grey of AutoCAD (NativeThemes filters 8 to 199):
            r.Add("");
            r.AddRange(NativeThemes.Blues(400));
        }

        static string Bytes(IntPtr p, int n)
        {
            var b = new byte[n];
            Marshal.Copy(p, b, 0, n);
            return BitConverter.ToString(b).Replace("-", " ");
        }

        // ---- given to the native themes of the palettes ----

        const string NameSetColorTheme = "?SetColorTheme@CAdUiTheme@@AEAAXAEBVCAcColorTheme@@W4AcColorThemeEnum@@@Z";
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate void SetColorThemeFn(IntPtr self, IntPtr colours, int which);

        // (Dyl:RibbonSkin "Hosted" "Push"), done by Apply too: each native theme of the palettes
        // (CAdUiTheme) is given the current CAcColorTheme, in the colours of DynALisp, as AutoCAD gives it when
        // its theme changes (CAdUiTheme::SetColorTheme, the dark theme: 0), then AutoCAD draws
        // again. The lists of Properties draw from what the palettes made of it.
        public static string Push()
        {
            if (!_found) Find();
            string why = Give(out var done);
            if (why != null) return why;
            Repaint();
            return "CAcColorTheme (" + Ac.Changed.Count + " colours changed) given to " + done.Count + " native themes: " + string.Join(", ", done);
        }

        // Each native theme found by NativeThemes given the current CAcColorTheme; null when
        // done, else why not.
        static string Give(out List<string> done)
        {
            done = new List<string>();
            if (Ac.Current == null) return "not found: " + Ac.Fail;
            IntPtr cur = Ac.Current();
            if (cur == IntPtr.Zero) return "no current theme";
            if (_give == null)
            {
                ProcessModule mod = Process.GetCurrentProcess().Modules.Cast<ProcessModule>()
                    .FirstOrDefault(m => m.ModuleName.StartsWith(Ac.Prefix, StringComparison.OrdinalIgnoreCase));
                if (mod == null) return Ac.Prefix + " not loaded";
                var ex = new Dictionary<string, IntPtr>();
                NativeThemes.Exports(mod.BaseAddress, ex, x => x == NameSetColorTheme);
                if (!ex.TryGetValue(NameSetColorTheme, out var f)) return "CAdUiTheme::SetColorTheme not exported";
                _give = Marshal.GetDelegateForFunctionPointer<SetColorThemeFn>(f);
            }
            foreach (var (n, p) in NativeThemes.Pointers().GroupBy(x => x.Theme).Select(g => g.First()))
            {
                if (p == IntPtr.Zero) continue;
                _give(p, cur, 0);
                done.Add(n);
            }
            return null;
        }

        static string Hex(IntPtr p) => "0x" + p.ToInt64().ToString("X");
        static string Col(uint v) => "#" + (v & 0xFF).ToString("X2") + (v >> 8 & 0xFF).ToString("X2") + (v >> 16 & 0xFF).ToString("X2");

        // The colours of a theme in its object (offset, 4 bytes a colour) or behind one of its
        // first 32 pointers:
        static string Where(IntPtr theme, uint[] vals, List<(string, IntPtr)> ptrs)
        {
            int at = Find(theme, 0x2000, vals);
            if (at >= 0) return "the theme +0x" + at.ToString("X");
            for (int i = 0; i < 32; i++)
            {
                IntPtr p;
                try { if (!Readable(theme + i * 8, 8)) break; p = Marshal.ReadIntPtr(theme + i * 8); } catch { break; }
                if (p == IntPtr.Zero || !Readable(p, 16)) continue;
                int k = Find(p, 0x2000, vals);
                if (k >= 0) return "the pointer at +0x" + (i * 8).ToString("X") + " (" + Hex(p) + ") +0x" + k.ToString("X");
            }
            return "not found within 0x2000 bytes of the theme or of its pointers";
        }

        static int Find(IntPtr start, int len, uint[] vals)
        {
            int n = Math.Min(len, Readable(start, len) ? len : 0);
            if (n < 64) return -1;
            var buf = new byte[n];
            Marshal.Copy(start, buf, 0, n);
            var u = MemoryMarshal.Cast<byte, uint>(buf);
            for (int i = 0; i + 12 <= u.Length; i++)
            {
                int j = 0;
                while (j < 12 && (u[i + j] & 0xFFFFFF) == vals[j]) j++;
                if (j == 12) return i * 4;
            }
            return -1;
        }

        static bool Readable(IntPtr p, int len)
        {
            if (VirtualQuery(p, out var mi, (IntPtr)Marshal.SizeOf<MemoryInfo>()) == IntPtr.Zero) return false;
            if (mi.State != 0x1000 || (mi.Protect & 0x101) != 0 || (mi.Protect & 0xEE) == 0) return false;
            return p.ToInt64() + len <= mi.BaseAddress.ToInt64() + mi.RegionSize.ToInt64();
        }

        // ---- memory ----

        [StructLayout(LayoutKind.Sequential)]
        struct MemoryInfo
        {
            public IntPtr BaseAddress, AllocationBase;
            public uint AllocationProtect;
            public ushort PartitionId;
            public IntPtr RegionSize;
            public uint State, Protect, Type;
        }

        [DllImport("kernel32.dll")] static extern IntPtr VirtualQuery(IntPtr address, out MemoryInfo info, IntPtr length);

        // The memory of a theme committed and writable (PAGE_READWRITE, WRITECOPY and their
        // EXECUTE forms), so SetColor never writes in read-only data:
        static bool Writable(IntPtr p)
        {
            if (VirtualQuery(p, out var mi, (IntPtr)Marshal.SizeOf<MemoryInfo>()) == IntPtr.Zero) return false;
            return mi.State == 0x1000 && (mi.Protect & 0xCC) != 0 && (mi.Protect & 0x100) == 0;
        }
    }
}
