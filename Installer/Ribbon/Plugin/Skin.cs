// Skin.cs - DynALisp.Ribbon: the ribbon and palettes of AutoCAD in the dark of DynALisp (experiment)
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
// EXPERIMENT, not supported by Autodesk. AutoCAD lets a user pick only its Dark or Light theme
// (COLORTHEME). Its interface takes its colours from two theme objects, each a target here:
//   - Ribbon: ComponentManager.CurrentTheme (AdWindows.dll, Autodesk.Internal.Windows.Theme):
//     the brushes of the ribbon, its tabs and panels (Ribbon, Ribbon.MainTab), the application
//     menu and the frame, which the controls of the ribbon are bound to.
//   - Palettes: PaletteSettings.CurrentTheme of ThemeManager (AdUiPalettes.dll,
//     Autodesk.Windows.Palettes.PaletteTheme): the colours of the palettes made in WPF (Layer
//     Properties, QuickCalc...), and of the status bar, the file tabs, the command line and the
//     menus; with them, the native themes of the palettes written in C++ (Properties), found
//     in AutoCAD by NativeThemes.cs.
// While a target is on and AutoCAD is in its dark theme, every colour of its theme goes through
// a filter (Map): the greys and blue-greys of the surfaces take the hue of the DynALisp windows
// (Installer\Windows\Engine\Session.cs) and get darker, the light ones (the texts) take their
// hue, the saturated ones (the blue of what is picked) and the icons stay as they are.
//
// The theme is put in a copy made current, so AutoCAD tells every part drawn from it (the
// title bar keeps its own copy of the colours, read when a theme is made current); changed in
// place when AutoCAD takes the copy back twice, and it is not frozen. Turned off, the colours it had are given back.
// Everything is done when AutoCAD is idle with no command running (Host.OnIdle), at most once
// a second; anything not found (another version of AdWindows) leaves the ribbon as it is and
// says why in (Dyl:RibbonSkin).
//
// On while Display is on in Dyl-Settings (DynalispDisplayOn) and its Interface
// (DynalispInterface) is DynALisp or DynALisp Neutral, read here from the registry when the
// plugin loads, and again when the Lisp side calls (Dyl:RibbonSkin) after the settings are
// saved; the former Palettes and Ribbon settings (DynalispPaletteColors, DynalispRibbonColors)
// are read in its place while it is not set. The WPF parts with a theme of their own (the
// file tabs) follow by Hosted.cs, the themes in C++ (the native lists, the title bar) by
// CppThemes.cs.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Windows;
using System.Windows.Media;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    // The Lisp function of the skin (see LangCommands: a static class cannot hold it).
    public class SkinCommands
    {
        // (Dyl:RibbonSkin ["Palettes"]): reads the settings again, applies or removes the skin
        // the next time AutoCAD is idle, and returns what it does with the ribbon (or the
        // palettes): "DynALisp (57 colours)", "off", "waiting for the dark theme", "not found:
        // ..." (Dyl-Settings, Dyl-Diagnostics).
        [LispFunction("Dyl:RibbonSkin")]
        public static object RibbonSkin(ResultBuffer args)
        {
            try
            {
                Skin.Read();
                FileTabs.Read();
                string which = args?.AsArray().Select(v => v.Value as string).FirstOrDefault(v => v != null);
                if (string.Equals(which, "Web", StringComparison.OrdinalIgnoreCase))
                {
                    var wb = new ResultBuffer();
                    // "Detail": what AutoCAD gives to reach its browser, long, in a text file of %TEMP%:
                    if (args.AsArray().Any(v => string.Equals(v.Value as string, "Detail", StringComparison.OrdinalIgnoreCase)))
                    {
                        string file = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "DynALisp-Web.txt");
                        var lines = WebPages.Report(true);
                        System.IO.File.WriteAllLines(file, lines);
                        return file + " (" + lines.Count + " lines)";
                    }
                    foreach (var line in WebPages.Report()) wb.Add(new TypedValue((int)LispDataType.Text, line));
                    return wb;
                }
                if (string.Equals(which, "Timeline", StringComparison.OrdinalIgnoreCase))
                {
                    // What was done when since the plugin loaded, in a text file of %TEMP%:
                    string file = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "DynALisp-Timeline.txt");
                    var lines = Skin.TimelineReport();
                    lines.Insert(0, "DynALisp - the colours of the interface, what was done when (" + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + ")");
                    System.IO.File.WriteAllLines(file, lines);
                    return file + " (" + lines.Count + " lines)";
                }
                if (string.Equals(which, "Hosted", StringComparison.OrdinalIgnoreCase))
                {
                    // What still shows the blue-greys of AutoCAD, long, in a text file of %TEMP%:
                    string file = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "DynALisp-Hosted.txt");
                    // "Push": the current CAcColorTheme given to the native themes (an experiment):
                    if (args.AsArray().Any(v => string.Equals(v.Value as string, "Push", StringComparison.OrdinalIgnoreCase)))
                        return CppThemes.Push();
                    // "Colors": the colour themes of AutoCAD in C++, read only:
                    var lines = Hosted.Report(args.AsArray().Any(v => string.Equals(v.Value as string, "Colors", StringComparison.OrdinalIgnoreCase)));
                    System.IO.File.WriteAllLines(file, lines);
                    return file + " (" + lines.Count + " lines)";
                }
                if (string.Equals(which, "Native", StringComparison.OrdinalIgnoreCase))
                {
                    // What was found of the native palettes, one string each (a diagnostic);
                    // "Search" first searches every module for the names of the themes:
                    bool Arg(string a) => args.AsArray().Any(v => string.Equals(v.Value as string, a, StringComparison.OrdinalIgnoreCase));
                    if (Arg("Search")) NativeThemes.Search();
                    var rb = new ResultBuffer();
                    rb.Add(new TypedValue((int)LispDataType.Text, "ribbon: " + Skin.Ribbon.Status() + ", " + Skin.Ribbon.Again + " themes made current again"));
                    rb.Add(new TypedValue((int)LispDataType.Text, "palettes: " + Skin.Palettes.Status() + ", " + Skin.Palettes.Again + " themes made current again"));
                    foreach (var line in NativeThemes.Report(Arg("Exports"))) rb.Add(new TypedValue((int)LispDataType.Text, line));
                    return rb;
                }
                if (!string.Equals(which, "Palettes", StringComparison.OrdinalIgnoreCase)) return Skin.Ribbon.Status();
                string st = Skin.Palettes.Status();
                return Skin.Palettes.Wanted && Skin.Dark() ? st + "; " + NativeThemes.Status() + "; " + CppThemes.Status() : st;
            }
            catch (System.Exception ex) { return "error: " + ex.Message; }
        }
    }

    // One theme object of AutoCAD put in the colours of DynALisp: how to get it and make
    // another one current, the setting that turns it on, and what it changed.
    public sealed class SkinTarget
    {
        public readonly string Name, Setting;
        readonly Func<object> _get;
        readonly Action<object> _set;
        public SkinTarget(string name, string setting, Func<object> get, Action<object> set)
        {
            Name = name; Setting = setting; _get = get; _set = set;
        }

        public bool Wanted;
        // The look chosen (DynALisp or DynALisp Neutral), and the one the theme was put in:
        public Look Look = Look.DynALisp;
        Look _applied;
        string _fail;
        // The theme changed in place: (object, property, value it had), to give them back.
        readonly List<(object Node, PropertyInfo Prop, object Was)> _changed = new();
        object _inPlace;        // the theme changed in place
        object _copy, _orig;    // the copy made current, and the theme it was made from
        int _count;             // the colours changed
        // The themes AutoCAD made current again after one was put in the colours of DynALisp:
        // past Limit, AutoCAD fights back (they would flicker), and the target gives up.
        public int Again;
        bool _gaveUp;
        const int Limit = 5;
        // A copy of the theme made current even when it is not frozen, until AutoCAD made
        // another one current CopyTries times:
        public bool Copy = true;
        const int CopyTries = 2;

        public bool Busy => Wanted || _inPlace != null || _copy != null;

        // The themes this target changed or made current, and the one a copy was made from
        // (Hosted.cs leaves them to it):
        public IEnumerable<object> Themes() => new[] { _inPlace, _copy, _orig, Current() }.Where(t => t != null);

        public string Status()
        {
            if (!Wanted) return "off";
            if (_gaveUp) return "given up: AutoCAD made " + Again + " other themes current";
            if (_fail != null) return "not found: " + _fail;
            if (!Skin.Dark()) return "waiting for the dark theme";
            if (_inPlace != null) return Look.Name + " (" + _count + " colours)";
            if (_copy != null) return Look.Name + " (" + _count + " colours, copy of the theme)";
            return Look.Name + " (on the next idle)";
        }

        object Current()
        {
            try { return _get(); }
            catch (System.Exception ex) { _fail = ex.Message; return null; }
        }

        public void Apply()
        {
            try { Run(); }
            catch (System.Exception ex) { _fail = ex.Message; Host.Log(Name + " colours: " + ex.Message); }
        }

        void Run()
        {
            object cur = Current();
            if (cur == null) { _fail ??= Name + " theme"; return; }
            _fail = null;
            if (Wanted && Skin.Dark())
            {
                bool same = ReferenceEquals(cur, _inPlace) || ReferenceEquals(cur, _copy);
                if (_gaveUp || same && _applied == Look) return;
                // Another theme made current by AutoCAD (or another look chosen): the former
                // one given back first.
                if (!same && (_inPlace != null || _copy != null)) Again++;
                Undo();
                if (same) cur = Current();
                if (Again > Limit) { _gaveUp = true; Host.Log(Name + " colours: given up, " + Again + " themes made current"); return; }
                // A copy made current when it may be: AutoCAD tells every part drawn from the
                // theme that it changed (the title bar of AutoCAD keeps its own copy of the
                // colours, read when a theme is made current); in place when AutoCAD made
                // another theme current again too often (it takes the copy back).
                if (Skin.Unfrozen(cur) && !(Copy && Again < CopyTries))
                {
                    _count = Skin.Filter(cur, _changed, Look);
                    _inPlace = cur;
                    _applied = Look;
                }
                else
                {
                    var copy = Skin.CopyOf(cur);
                    _count = Skin.Filter(copy, null, Look);
                    _applied = Look;
                    _orig = cur;
                    _copy = copy;
                    _set(copy);
                }
            }
            else { Undo(); _gaveUp = false; Again = 0; }
        }

        // The colours given back: the theme changed in place, or the theme the copy was made
        // from made current again (when AutoCAD has not made another one current since).
        void Undo()
        {
            foreach (var (node, prop, was) in Enumerable.Reverse(_changed))
                try { prop.SetValue(node, was); } catch { }
            _changed.Clear();
            _inPlace = null;
            if (_copy != null)
            {
                if (ReferenceEquals(Current(), _copy)) _set(_orig);
                _copy = null;
                _orig = null;
            }
            _count = 0;
        }
    }

    // A look the greys of AutoCAD are put in: the value of the setting (Ribbon, Palettes), the
    // hue and saturation the greys take, and how much darker the surfaces get.
    public sealed class Look
    {
        public readonly string Name;
        public readonly double Hue, MinSat, MaxSat, Darker;
        Look(string name, double hue, double minSat, double maxSat, double darker)
        {
            Name = name; Hue = hue; MinSat = minSat; MaxSat = maxSat; Darker = darker;
        }

        // The greys of the DynALisp windows (#252A32, #313844: 217 degrees, 10 to 16 %):
        // AutoCAD's dark panels (a lightness of about 28 %) come near the cards of the windows
        // (#313844, 23 %).
        public static readonly Look DynALisp = new Look("DynALisp", 217, 0.10, 0.16, 0.78);
        // Its variant in a neutral grey, darker: no hue, the panels near 17 % (#2C2C2C), beside
        // a model space almost black (#121212).
        public static readonly Look Neutral = new Look("DynALisp Neutral", 0, 0, 0, 0.62);

        static readonly Look[] All = { DynALisp, Neutral };

        // The look of a value of the setting, null for any other (not set, off):
        public static Look Of(string name) => All.FirstOrDefault(l => l.Name == name);
    }

    public static class Skin
    {
        // A colour more saturated than this is a colour, not a grey: it stays.
        const double Grey = 0.35;
        // A colour lighter than this is a text or a light line: it only takes the hue.
        const double Light = 0.6;

        public static readonly SkinTarget Ribbon = new SkinTarget("ribbon", "DynalispRibbonColors",
            () => ComponentManager.CurrentTheme,
            t => ComponentManager.CurrentTheme = (Autodesk.Internal.Windows.Theme)t);

        public static readonly SkinTarget Palettes = new SkinTarget("palettes", "DynalispPaletteColors",
            () => Autodesk.Windows.Themes.ThemeManager.PaletteSettings.CurrentTheme,
            t => Autodesk.Windows.Themes.ThemeManager.PaletteSettings.CurrentTheme = (Autodesk.Windows.Palettes.PaletteTheme)t);

        static readonly SkinTarget[] Targets = { Ribbon, Palettes };

        static bool _due = true;
        static int _next = Environment.TickCount;

        // How often the colours are checked: every 100 ms for 20 s after the plugin loads, the
        // settings are read again, COLORTHEME changes or a drawing is opened (the palettes,
        // the tabs and their themes are made one after the other then, and each would show the
        // blue-greys of AutoCAD for a second or two), once a second after that (Hosted.cs and
        // CppThemes.cs every 2 s).
        static int _fastUntil = Environment.TickCount + Fast;
        const int Fast = 20000;
        public static bool Settling => Environment.TickCount - _fastUntil < 0;

        // While Settling, a timer of the dispatcher calls OnIdle too: AutoCAD raises no Idle
        // while it opens the first drawing and runs its startup (the Lisp of the drawings), the
        // time its palettes and tabs are made, and each stayed in the blue-greys of AutoCAD
        // until then.
        static System.Windows.Threading.DispatcherTimer _timer;

        // What was done when, from the time the plugin loaded (Dyl:RibbonSkin "Timeline"):
        // each status that changed, the idle gaps longer than 300 ms, the main window shown.
        static readonly System.Diagnostics.Stopwatch Clock = System.Diagnostics.Stopwatch.StartNew();
        static readonly List<string> Timeline = new();
        static readonly Dictionary<string, string> LastStatus = new();
        static long _lastTick = -1;
        static bool _shown;

        public static void Mark(string what)
        {
            if (Timeline.Count < 400) Timeline.Add(Clock.ElapsedMilliseconds.ToString().PadLeft(7) + " ms  " + what);
        }

        static void Timed(string name, Action step)
        {
            long t0 = Clock.ElapsedMilliseconds;
            step();
            long d = Clock.ElapsedMilliseconds - t0;
            if (d > 50) Mark(name + " took " + d + " ms");
        }

        public static List<string> TimelineReport() => new List<string>(Timeline);

        static void Track(string name, Func<string> status)
        {
            string s;
            try { s = status(); } catch (System.Exception ex) { s = "error: " + ex.Message; }
            if (LastStatus.TryGetValue(name, out var was) && was == s) return;
            LastStatus[name] = s;
            Mark(name + ": " + s);
        }

        [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
        public static void Settle() => _fastUntil = Environment.TickCount + Fast;

        public static void Start()
        {
            Read();
            AcApp.SystemVariableChanged += (s, e) =>
            {
                if (string.Equals(e.Name, "COLORTHEME", StringComparison.OrdinalIgnoreCase)) { _due = true; Settle(); }
            };
            AcApp.DocumentManager.DocumentCreated += (s, e) => { Mark("drawing opened"); Settle(); };
            Mark("plugin loaded");
            try
            {
                _timer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Normal)
                { Interval = TimeSpan.FromMilliseconds(100) };
                _timer.Tick += (s, e) => { if (Settling) Tick("timer"); };
                _timer.Start();
            }
            catch (System.Exception ex) { Mark("timer: " + ex.Message); }
            // At once, as the plugin loads with AutoCAD: the palettes and the ribbon are drawn
            // in the colours of DynALisp from the start, never first in those of AutoCAD.
            Tick("load");
        }

        // The settings, from the registry (setenv / getenv: FixedProfile\General):
        public static void Read()
        {
            bool on = Env("DynalispDisplayOn") == "1";
            // The Interface of Display (DynalispInterface) colours them all; before it, the
            // Ribbon and the Palettes were each a setting of their own (still read, until saved).
            string ifc = new[] { "DynalispInterface", Palettes.Setting, Ribbon.Setting }
                .Select(Env).FirstOrDefault(v => !string.IsNullOrEmpty(v));
            foreach (var t in Targets)
            {
                var look = Look.Of(ifc);
                t.Wanted = on && look != null;
                if (look != null) t.Look = look;
            }
            _due = true;
            _next = Environment.TickCount;
            Settle();
        }

        static string Env(string name)
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General");
                return key?.GetValue(name) as string;
            }
            catch { return null; }
        }

        public static bool Dark()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("COLORTHEME")) == 0; }
            catch { return true; }
        }

        // Run by Host.OnIdle: the skin put on, kept on (AutoCAD makes another theme current when
        // COLORTHEME changes or the ribbon is made again) or taken off, once a second at most
        // (every 100 ms while Settling).
        public static void OnIdle() => Tick("idle");

        static void Tick(string from)
        {
            long now = Clock.ElapsedMilliseconds;
            if (from == "idle")
            {
                if (_lastTick >= 0 && now - _lastTick > 300 && Timeline.Count < 400) Mark("no idle for " + (now - _lastTick) + " ms");
                _lastTick = now;
            }
            if (!_shown)
            {
                try { if (AcApp.MainWindow != null && IsWindowVisible(AcApp.MainWindow.Handle)) { _shown = true; Mark("main window shown (" + from + ")"); } } catch { }
            }
            if (!_due && !Targets.Any(t => t.Busy)) return;
            if (Environment.TickCount - _next < 0) return;
            _next = Environment.TickCount + (Settling ? 100 : 1000);
            _due = false;
            bool on = Palettes.Wanted && Dark();
            // Each step timed for the Timeline (one of more than 50 ms is marked); the title bar
            // and the lists of the palettes first, the cheapest and most seen:
            // The themes in C++ of the native lists and buttons and of the title bar:
            Timed("C++", () => CppThemes.Apply(on, Palettes.Look));
            // The palettes written in C++ (Properties), by their native themes:
            Timed("native", () => NativeThemes.Apply(on, Palettes.Look));
            foreach (var t in Targets) Timed(t.Name, t.Apply);
            // The WPF parts with a theme of their own (the file tabs):
            Timed("hosted", () => Hosted.Apply(on, Palettes.Look));
            // The web pages (Start), by a script in their browser:
            Timed("web", () => WebPages.Apply(on, Palettes.Look));
            if (Timeline.Count < 400)
            {
                Track("ribbon", Ribbon.Status);
                Track("palettes", Palettes.Status);
                Track("native", NativeThemes.Status);
                Track("hosted", Hosted.Status);
                Track("C++", CppThemes.Status);
            }
        }

        // ---- the walk of the theme ----

        // The parts of a theme are Freezable objects of Autodesk (RibbonTheme, TabTheme,
        // ApplicationMenuTheme...); their colours are its Brush and Color properties.
        static bool IsPart(Type t) =>
            typeof(Freezable).IsAssignableFrom(t) && !typeof(Brush).IsAssignableFrom(t)
            && (t.Namespace ?? "").StartsWith("Autodesk", StringComparison.Ordinal);

        static IEnumerable<PropertyInfo> Props(object node) =>
            node.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.CanRead && p.GetIndexParameters().Length == 0);

        // The theme and every part of it, for Hosted.cs: they are filtered here, never there.
        public static void Parts(object node, HashSet<object> into)
        {
            if (node == null || !into.Add(node)) return;
            foreach (var p in Props(node))
            {
                object v;
                try { v = p.GetValue(node); } catch { continue; }
                if (v is Freezable && IsPart(v.GetType())) Parts(v, into);
            }
        }

        // A copy of a theme, of its own type: Freezable.Clone, or when that gives another type
        // (the Theme of the ribbon, frozen while AutoCAD starts, clones into a RibbonTheme, which
        // ComponentManager.CurrentTheme does not take, and the ribbon kept the blue-greys of
        // AutoCAD for 3 s), a new object of its type given each of its settable properties, a
        // frozen part given as its unfrozen clone.
        public static object CopyOf(object cur)
        {
            var c = ((Freezable)cur).Clone();
            if (cur.GetType().IsInstanceOfType(c)) return c;
            var n = Activator.CreateInstance(cur.GetType(), true);
            foreach (var p in Props(cur))
            {
                if (!p.CanWrite || p.SetMethod == null || !p.SetMethod.IsPublic) continue;
                object v;
                try { v = p.GetValue(cur); } catch { continue; }
                if (v is Freezable f && f.IsFrozen && IsPart(v.GetType()))
                {
                    var fc = f.Clone();
                    if (p.PropertyType.IsInstanceOfType(fc)) v = fc;
                }
                try { p.SetValue(n, v); } catch { }
            }
            return n;
        }

        public static bool Unfrozen(object theme)
        {
            var seen = new HashSet<object>(ReferenceEqualityComparer.Instance);
            return Unfrozen(theme, seen);
        }

        static bool Unfrozen(object node, HashSet<object> seen)
        {
            if (node == null || !seen.Add(node)) return true;
            if (node is Freezable f && f.IsFrozen) return false;
            foreach (var p in Props(node))
                if (IsPart(p.PropertyType))
                {
                    object v;
                    try { v = p.GetValue(node); } catch { continue; }
                    if (!Unfrozen(v, seen)) return false;
                }
            return true;
        }

        // Every colour of the theme through Map; keep (in place): where to remember what it was.
        // Returns how many were changed.
        // The look the filter puts the colours in, while a theme is filtered:
        static Look _look = Look.DynALisp;

        public static int Filter(object theme, List<(object, PropertyInfo, object)> keep, Look look)
        {
            var seen = new HashSet<object>(ReferenceEqualityComparer.Instance);
            var was = _look;
            _look = look;
            try { return Filter(theme, keep, seen); }
            finally { _look = was; }
        }

        static int Filter(object node, List<(object, PropertyInfo, object)> keep, HashSet<object> seen)
        {
            if (node == null || !seen.Add(node)) return 0;
            int n = 0;
            foreach (var p in Props(node))
            {
                object v;
                try { v = p.GetValue(node); } catch { continue; }
                if (v == null) continue;
                if (IsPart(p.PropertyType) || (v is Freezable && IsPart(v.GetType()))) { n += Filter(v, keep, seen); continue; }
                if (!p.CanWrite || p.SetMethod == null || !p.SetMethod.IsPublic) continue;
                object nv = v is Brush b ? MapBrush(b) : v is Color c ? Map(c) : null;
                if (nv == null || Equals(nv, v)) continue;
                try
                {
                    p.SetValue(node, nv);
                    keep?.Add((node, p, v));
                    n++;
                }
                catch { }
            }
            return n;
        }

        static Brush MapBrush(Brush b)
        {
            switch (b)
            {
                case SolidColorBrush s:
                    var c = Map(s.Color);
                    if (c == s.Color) return null;
                    var ns = new SolidColorBrush(c) { Opacity = s.Opacity };
                    ns.Freeze();
                    return ns;
                case GradientBrush g:
                    var ng = g.Clone();
                    bool any = false;
                    foreach (var stop in ng.GradientStops)
                    {
                        var m = Map(stop.Color);
                        if (m != stop.Color) { stop.Color = m; any = true; }
                    }
                    if (!any) return null;
                    ng.Freeze();
                    return ng;
                default:
                    return null;    // images and drawings: left as they are
            }
        }

        // ---- the filter ----

        // A colour of AutoCAD's dark theme in the dark of the DynALisp windows: a grey (not
        // saturated) takes their hue; a dark one gets darker; a saturated one stays.
        public static Color Map(Color c) => Map(c, _look);

        public static Color Map(Color c, Look look)
        {
            if (c.A == 0) return c;
            ToHsl(c, out double h, out double s, out double l);
            if (s > Grey && l > 0.08 && l < 0.92) return c;
            if (l < Light) l *= look.Darker;
            return FromHsl(c.A, look.Hue, Math.Min(Math.Max(s, look.MinSat), look.MaxSat), l);
        }

        public static double Lightness(Color c) { ToHsl(c, out _, out _, out double l); return l; }

        internal static void ToHsl(Color c, out double h, out double s, out double l)
        {
            double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
            double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b));
            l = (max + min) / 2;
            double d = max - min;
            if (d < 1e-9) { h = 0; s = 0; return; }
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max == r) h = (g - b) / d + (g < b ? 6 : 0);
            else if (max == g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h *= 60;
        }

        static Color FromHsl(byte a, double h, double s, double l)
        {
            double q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
            double k = h / 360;
            static double Ch(double p, double q, double t)
            {
                if (t < 0) t += 1;
                if (t > 1) t -= 1;
                if (t < 1.0 / 6) return p + (q - p) * 6 * t;
                if (t < 0.5) return q;
                if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6;
                return p;
            }
            static byte B(double v) => (byte)Math.Round(Math.Clamp(v, 0, 1) * 255);
            return Color.FromArgb(a, B(Ch(p, q, k + 1.0 / 3)), B(Ch(p, q, k)), B(Ch(p, q, k - 1.0 / 3)));
        }
    }
}
