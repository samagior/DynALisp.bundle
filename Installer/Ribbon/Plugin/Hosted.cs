// Hosted.cs - DynALisp.Ribbon: the WPF parts of AutoCAD that keep colours of their own (experiment)
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
// EXPERIMENT, not supported by Autodesk. Some parts of AutoCAD made in WPF do not draw with the
// two themes of Skin.cs but with a theme object of their own, made once from them: the file
// tabs (FileTabsColor of AcWindows.dll, a ThemeBase), a palette given its own theme
// (ThemeManager.OverridePaletteTheme). They kept the blue-greys of AutoCAD under the
// DynALisp Neutral look. This file finds those themes in the windows of AutoCAD themselves:
// each WPF window of the process (PresentationSource.CurrentSources) is walked, and a theme is
// an Autodesk Freezable that is the source of a binding of a colour (Background, BorderBrush,
// Fill...), the data context of an element, a resource of it, or its OverridePaletteTheme,
// never the themes of Skin.cs or a part of them (they are filtered there). Each one found
// unfrozen goes through Skin.Filter, what it had kept to give it back; a colour the part sets
// again (UpdateUserPreferences) has its theme filtered again.
//
// The windows are walked again when their set changes (checked every 2 s); nothing is done
// while the interface is off or AutoCAD is light. (Dyl:RibbonSkin "Hosted") writes a report
// to %TEMP%\DynALisp-Hosted.txt: the themes found and what still shows a blue-grey of AutoCAD
// (each WPF element and its source, each native window and how many of its pixels).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using System.ComponentModel;
using System.Collections.Specialized;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    public static class Hosted
    {
        // A theme found and filtered: what it had (to give it back) and what it was given.
        sealed class Found
        {
            public object Theme;
            public string Where;
            public readonly List<(object Node, PropertyInfo Prop, object Was)> Kept = new();
            public readonly List<object> Given = new();
            public int Again;
            public bool Frozen;
        }

        static readonly Dictionary<object, Found> Themes = new(ReferenceEqualityComparer.Instance);
        static bool _on;
        static Look _look = Look.DynALisp;
        static int _sources = -1, _next, _full, _walked, _ms;
        // The windows already walked: a new one (a palette opened) is walked at once, all of
        // them again every 30 s at most when their number changed (a tree filled later).
        static readonly HashSet<PresentationSource> Walked = new(ReferenceEqualityComparer.Instance);
        const int Full = 30000;
        static string _fail;
        const int Every = 2000, Limit = 3, MaxNodes = 60000;

        // The colour properties whose binding source may be a theme, with the type that has
        // each (Control.BackgroundProperty is the one of Panel, added to Control: its
        // OwnerType says Panel, so it cannot tell which elements have it):
        static readonly (Type Type, DependencyProperty Prop)[] Colours = {
            (typeof(Control), Control.BackgroundProperty), (typeof(Control), Control.BorderBrushProperty),
            (typeof(Control), Control.ForegroundProperty),
            (typeof(Border), Border.BackgroundProperty), (typeof(Border), Border.BorderBrushProperty),
            (typeof(Panel), Panel.BackgroundProperty),
            (typeof(TextBlock), TextBlock.BackgroundProperty), (typeof(TextBlock), TextBlock.ForegroundProperty),
            (typeof(Shape), Shape.FillProperty), (typeof(Shape), Shape.StrokeProperty) };

        public static string Status() =>
            _fail != null ? "hosted themes: " + _fail
            : (Themes.Count == 0 ? "hosted themes: none found"
            : "hosted themes " + string.Join(", ", Themes.Values.Select(f => f.Theme.GetType().Name + (f.Frozen ? " (frozen)" : " (" + f.Kept.Count + ")"))))
            + "; " + Tabbed.Count + " tabs, " + TabShapes.Count + " shapes recoloured"
            + (_tabTypes.Count > 0 ? " (Background: " + string.Join(", ", _tabTypes) + ")" : "");

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
                _next = Environment.TickCount + (Skin.Settling ? 100 : Every);
                int n = PresentationSource.CurrentSources.Cast<object>().Count();
                if (first || n != _sources)
                {
                    bool all = first || Environment.TickCount - _full >= 0;
                    if (all) { Walked.Clear(); _full = Environment.TickCount + Full; }
                    _sources = n;
                    Work.Count("colours: the WPF windows walked (" + (all ? "all" : "the new ones") + ")");
                    Walk();
                }
                Keep();
            }
            catch (System.Exception ex) { _fail = ex.Message; Host.Log("hosted themes: " + ex.Message); }
        }

        // The themes of Skin.cs and their parts: never filtered here.
        static HashSet<object> Skinned()
        {
            var set = new HashSet<object>(ReferenceEqualityComparer.Instance);
            foreach (var t in new[] { Skin.Ribbon, Skin.Palettes })
                foreach (var th in t.Themes()) Skin.Parts(th, set);
            return set;
        }

        static bool IsTheme(object v) =>
            v is Freezable && v is not Brush && v is not Transform && v is not Geometry && v is not ImageSource
            && (v.GetType().Namespace ?? "").StartsWith("Autodesk", StringComparison.Ordinal);

        // Each WPF window of AutoCAD walked: the themes it draws with, filtered.
        static void Walk()
        {
            var sw = Stopwatch.StartNew();
            var skinned = Skinned();
            var seen = new HashSet<object>(ReferenceEqualityComparer.Instance);
            int nodes = 0;
            // The dark theme given to the palettes that override theirs:
            try
            {
                var dark = Autodesk.Windows.Themes.OverridePaletteTheme.Dark;
                if (IsTheme(dark) && !skinned.Contains(dark) && seen.Add(dark)) Take(dark, "OverridePaletteTheme.Dark");
            }
            catch { }
            Walked.RemoveWhere(s => s.IsDisposed);
            foreach (var src in Sources().Where(Walked.Add).ToList())
                Visit(src.RootVisual, src.RootVisual?.GetType().Name, (th, where) =>
                {
                    if (!skinned.Contains(th) && seen.Add(th)) Take(th, where);
                }, ref nodes);
            _walked += nodes;
            _ms = (int)sw.ElapsedMilliseconds;
            _fail = null;
        }

        static IEnumerable<PresentationSource> Sources() =>
            PresentationSource.CurrentSources.Cast<PresentationSource>().Where(s => s?.RootVisual != null && !s.IsDisposed);

        // The tree of a window, each theme it holds given to found (with where it was found).
        static void Visit(DependencyObject root, string top, Action<object, string> found, ref int nodes)
        {
            var stack = new Stack<DependencyObject>();
            if (root != null) stack.Push(root);
            while (stack.Count > 0 && nodes < MaxNodes)
            {
                var d = stack.Pop();
                nodes++;
                string where = top + " > " + d.GetType().Name;
                Tabs(d);
                foreach (var (type, dp) in Colours)
                {
                    if (!type.IsInstanceOfType(d)) continue;
                    foreach (var src in BindingSources(d, dp))
                        if (IsTheme(src)) found(src, where + "." + dp.Name);
                }
                if (d is FrameworkElement fe)
                {
                    if (IsTheme(fe.DataContext)) found(fe.DataContext, where + " (data context)");
                    if (fe.Resources != null && (fe.Resources.Count > 0 || fe.Resources.MergedDictionaries.Count > 0))
                        foreach (var v in Values(fe.Resources))
                            if (IsTheme(v)) found(v, where + " (resource)");
                }
                object over = null;
                try { over = Autodesk.Windows.Themes.ThemeManager.GetOverridePaletteTheme(d); } catch { }
                if (over is Autodesk.Windows.Themes.OverridePaletteTheme o)
                {
                    try { if (IsTheme(o.Theme)) found(o.Theme, where + " (OverridePaletteTheme)"); } catch { }
                }
                int n = 0;
                try { n = d is Visual || d is System.Windows.Media.Media3D.Visual3D ? VisualTreeHelper.GetChildrenCount(d) : 0; } catch { }
                for (int i = 0; i < n; i++) stack.Push(VisualTreeHelper.GetChild(d, i));
            }
        }

        static IEnumerable<object> BindingSources(DependencyObject d, DependencyProperty dp)
        {
            BindingExpressionBase b;
            try { b = BindingOperations.GetBindingExpressionBase(d, dp); } catch { yield break; }
            if (b is BindingExpression be) { if (be.ResolvedSource != null) yield return be.ResolvedSource; }
            else if (b is MultiBindingExpression mb)
                foreach (var x in mb.BindingExpressions.OfType<BindingExpression>())
                    if (x.ResolvedSource != null) yield return x.ResolvedSource;
            else if (b is PriorityBindingExpression pb)
                foreach (var y in pb.BindingExpressions.OfType<BindingExpression>())
                    if (y.ResolvedSource != null) yield return y.ResolvedSource;
        }

        static IEnumerable<object> Values(ResourceDictionary rd, int depth = 0)
        {
            var list = new List<object>();
            try { foreach (var k in rd.Keys) { try { list.Add(rd[k]); } catch { } } } catch { }
            if (depth < 3)
                foreach (var m in rd.MergedDictionaries) list.AddRange(Values(m, depth + 1));
            return list;
        }

        static void Take(object th, string where)
        {
            if (Themes.TryGetValue(th, out var f)) return;
            f = new Found { Theme = th, Where = where };
            Themes[th] = f;
            if (!Skin.Unfrozen(th)) { f.Frozen = true; return; }
            Filter(f);
        }

        static void Filter(Found f)
        {
            int from = f.Kept.Count;
            Skin.Filter(f.Theme, f.Kept, _look);
            for (int i = from; i < f.Kept.Count; i++)
            {
                object now = null;
                try { now = f.Kept[i].Prop.GetValue(f.Kept[i].Node); } catch { }
                f.Given.Add(now);
            }
        }

        // A theme whose part set its colours again (the file tabs read them again when a
        // drawing opens): what it set is filtered, past Limit given up (it would flicker).
        static void Keep()
        {
            foreach (var f in Themes.Values)
            {
                if (f.Frozen || f.Again > Limit) continue;
                bool changed = false;
                for (int i = 0; i < f.Kept.Count && !changed; i++)
                {
                    object now = null;
                    try { now = f.Kept[i].Prop.GetValue(f.Kept[i].Node); } catch { }
                    changed = !ReferenceEquals(now, f.Given[i]) && !Equals(now, f.Given[i]);
                }
                if (!changed) continue;
                f.Again++;
                // What it holds now is AutoCAD's: kept as what it had, then filtered again.
                f.Kept.Clear();
                f.Given.Clear();
                Filter(f);
            }
        }

        // ---- the tabs ----

        // The file tabs and the layout tabs (SwitchContentControl of AcWindows.dll) get their
        // colour from the code of AutoCAD, in their Background (a value or a binding of its
        // own, set again as their state changes: current, under the mouse), which the shapes
        // of their template (a Rectangle, the Paths of the slanted sides) are bound to. Those
        // shapes are given the colour of Background in the look, again each time Background
        // changes (a ValueChanged handler); Background itself is left to AutoCAD, and the
        // shapes get their binding back when it is turned off. The lists of tabs
        // (SwitchItemsControl) are watched, so a tab added (a drawing opened) is found at once.
        static readonly HashSet<Control> Tabbed = new(ReferenceEqualityComparer.Instance);
        static readonly HashSet<Shape> TabShapes = new(ReferenceEqualityComparer.Instance);
        static readonly Dictionary<Brush, Brush> TabMapped = new(ReferenceEqualityComparer.Instance);
        static readonly HashSet<ItemsControl> Lists = new(ReferenceEqualityComparer.Instance);
        static readonly HashSet<string> _tabTypes = new();
        static int _tabFixed;

        static void Tabs(DependencyObject d)
        {
            string n = d.GetType().Name;
            if (d is Control c && n == "SwitchContentControl" && Tabbed.Add(c))
            {
                DependencyPropertyDescriptor.FromProperty(Control.BackgroundProperty, typeof(Control))?.AddValueChanged(c, OnTab);
                c.Loaded += OnTabLoaded;
                Fix(c);
            }
            else if (d is ItemsControl ic && n == "SwitchItemsControl" && Lists.Add(ic))
                ((INotifyCollectionChanged)ic.Items).CollectionChanged += OnList;
        }

        static void OnTab(object sender, EventArgs e) { if (sender is Control c) Work.Time("colours: a tab recoloured (its colour changed)", () => Fix(c)); }
        static void OnTabLoaded(object sender, RoutedEventArgs e) { if (sender is Control c) Work.Time("colours: a tab recoloured (loaded)", () => Fix(c)); }

        static void OnList(object sender, NotifyCollectionChangedEventArgs e)
        {
            var ic = Lists.FirstOrDefault(l => ReferenceEquals(l.Items, sender));
            if (ic == null) return;
            // Once the new tabs are made:
            ic.Dispatcher.BeginInvoke(DispatcherPriority.Loaded, new Action(() =>
            {
                if (!_on) return;
                int nodes = 0;
                Work.Time("colours: the tabs walked (a tab added)", () => Visit(ic, "tabs", (th, where) => { }, ref nodes));
            }));
        }

        // The shapes of the template of a tab bound to its Background, or given its colour:
        static IEnumerable<Shape> Shapes(Control c)
        {
            var stack = new Stack<(DependencyObject, int)>();
            stack.Push((c, 0));
            while (stack.Count > 0)
            {
                var (d, depth) = stack.Pop();
                if (d is Shape sh && !ReferenceEquals(d, c))
                {
                    var be = BindingOperations.GetBindingExpression(sh, Shape.FillProperty);
                    if (TabShapes.Contains(sh) || be?.ParentBinding?.Path?.Path == "Background" && (be.ResolvedSource == null || ReferenceEquals(be.ResolvedSource, c)))
                        yield return sh;
                }
                // Not into the content (the name of the drawing, its close button):
                if (depth >= 4 || d is ContentPresenter) continue;
                int k = 0;
                try { k = d is Visual ? VisualTreeHelper.GetChildrenCount(d) : 0; } catch { }
                for (int i = 0; i < k; i++) stack.Push((VisualTreeHelper.GetChild(d, i), depth + 1));
            }
        }

        static void Fix(Control c)
        {
            if (!_on || !Tabbed.Contains(c)) return;
            var bg = c.Background;
            if (bg != null) _tabTypes.Add(bg.GetType().Name + " " + c.ReadLocalValue(Control.BackgroundProperty)?.GetType().Name);
            Brush m = null;
            if (bg != null && !TabMapped.TryGetValue(bg, out m))
            {
                m = MapTab(bg) ?? bg;
                TabMapped[bg] = m;
            }
            foreach (var sh in Shapes(c).ToList())
            {
                if (m == null) continue;
                if (!ReferenceEquals(sh.Fill, m)) sh.SetValue(Shape.FillProperty, m);
                if (TabShapes.Add(sh)) _tabFixed++;
            }
        }

        // A brush of a tab in the look (a plain colour or a gradient), null when it stays:
        static Brush MapTab(Brush b)
        {
            switch (b)
            {
                case SolidColorBrush sc:
                    var m = Skin.Map(sc.Color, _look);
                    if (m == sc.Color) return null;
                    var ns = new SolidColorBrush(m) { Opacity = sc.Opacity };
                    ns.Freeze();
                    return ns;
                case GradientBrush g:
                    var ng = g.Clone();
                    bool any = false;
                    foreach (var st in ng.GradientStops)
                    {
                        var mm = Skin.Map(st.Color, _look);
                        if (mm != st.Color) { st.Color = mm; any = true; }
                    }
                    if (!any) return null;
                    ng.Freeze();
                    return ng;
                default:
                    return null;
            }
        }

        static void TabsBack()
        {
            foreach (var c in Tabbed)
            {
                DependencyPropertyDescriptor.FromProperty(Control.BackgroundProperty, typeof(Control))?.RemoveValueChanged(c, OnTab);
                c.Loaded -= OnTabLoaded;
            }
            // The shapes bound to Background again (their style gives the binding back):
            foreach (var sh in TabShapes) try { sh.ClearValue(Shape.FillProperty); } catch { }
            Tabbed.Clear();
            TabShapes.Clear();
            TabMapped.Clear();
            _tabFixed = 0;
            foreach (var ic in Lists) ((INotifyCollectionChanged)ic.Items).CollectionChanged -= OnList;
            Lists.Clear();
        }

        static void Undo()
        {
            TabsBack();
            foreach (var f in Themes.Values)
                foreach (var (node, prop, was) in Enumerable.Reverse(f.Kept))
                    try { prop.SetValue(node, was); } catch { }
            Themes.Clear();
            Walked.Clear();
            _sources = -1;
        }

        // ---- the report ----

        // A blue-grey of AutoCAD's dark theme (#222933, #2A303B, #3B4453, #4E5A6E: 215 to 220
        // degrees, 17 to 20 %), not a grey of DynALisp Neutral nor a blue of what is picked.
        internal static bool Blue(Color c)
        {
            Skin.ToHsl(c, out double h, out double s, out double l);
            return h >= 200 && h <= 235 && s >= 0.12 && s <= 0.32 && l >= 0.08 && l <= 0.5;
        }

        static string Hex(Color c) => "#" + c.R.ToString("X2") + c.G.ToString("X2") + c.B.ToString("X2");

        public static List<string> Report(bool colours = false)
        {
            var r = new List<string>();
            if (colours)
            {
                r.Add("DynALisp - the colour themes of AutoCAD in C++ (" + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + ")");
                try { Colours2(r); } catch (System.Exception ex) { r.Add("error: " + ex.Message); }
                r.Add("");
                try { CppThemes.Copies(r); } catch (System.Exception ex) { r.Add("copies, error: " + ex.Message); }
                return r;
            }
            r.Add("DynALisp - what keeps the blue-greys of AutoCAD (" + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + ")");
            r.Add("look: " + _look.Name + ", on: " + _on + ", ribbon: " + Skin.Ribbon.Status() + ", palettes: " + Skin.Palettes.Status());
            r.Add(Status() + "; " + _walked + " elements walked in " + _ms + " ms");
            foreach (var f in Themes.Values)
                r.Add("  theme " + f.Theme.GetType().FullName + (f.Frozen ? " FROZEN" : ", " + f.Kept.Count + " colours, filtered again " + f.Again) + " - at " + f.Where);
            r.Add("");
            r.Add("");
            r.Add("WPF elements drawn in a blue-grey of AutoCAD (type path, property, colour, where the colour comes from):");
            int count = 0;
            foreach (var src in Sources())
            {
                string top = src.RootVisual.GetType().FullName;
                if (src is HwndSource hs) top += " [hwnd " + ClassOf(hs.Handle) + "]";
                var stack = new Stack<(DependencyObject, string)>();
                stack.Push((src.RootVisual, src.RootVisual.GetType().Name));
                int nodes = 0;
                while (stack.Count > 0 && nodes++ < MaxNodes && count < 400)
                {
                    var (d, path) = stack.Pop();
                    foreach (var (type, dp) in Colours)
                    {
                        if (!type.IsInstanceOfType(d)) continue;
                        object v;
                        try { v = d.GetValue(dp); } catch { continue; }
                        Color? c = v is SolidColorBrush sb ? sb.Color : v is GradientBrush gb && gb.GradientStops.Count > 0 ? gb.GradientStops[0].Color : null;
                        if (c == null || !Blue(c.Value)) continue;
                        string from;
                        try { from = DependencyPropertyHelper.GetValueSource(d, dp).BaseValueSource.ToString(); } catch { from = "?"; }
                        var b = BindingOperations.GetBindingExpression(d, dp);
                        if (b != null) from += ", binding " + b.ParentBinding?.Path?.Path + " of " + (b.ResolvedSource?.GetType().FullName ?? b.DataItem?.GetType().FullName ?? "?");
                        var rr = d.ReadLocalValue(dp);
                        if (rr != null && rr.GetType().Name.Contains("ResourceReference")) from += ", resource reference";
                        r.Add("  " + top + " : " + Trim(path) + "." + dp.Name + " " + Hex(c.Value) + " (" + from + ")" + (d is FrameworkElement fe && !string.IsNullOrEmpty(fe.Name) ? " name " + fe.Name : ""));
                        count++;
                    }
                    int n = 0;
                    try { n = d is Visual ? VisualTreeHelper.GetChildrenCount(d) : 0; } catch { }
                    for (int i = 0; i < n; i++)
                    {
                        var ch = VisualTreeHelper.GetChild(d, i);
                        stack.Push((ch, path + " > " + ch.GetType().Name));
                    }
                }
            }
            if (count == 0) r.Add("  none");
            r.Add("");
            r.Add("Windows of AutoCAD with pixels in a blue-grey of AutoCAD on the screen (class, size, pixels, WPF):");
            try { Pixels(r); } catch (System.Exception ex) { r.Add("  " + ex.Message); }
            r.Add("");
            r.Add("Native themes: elements that had a blue-grey of the title bar, the tabs or the lists of AutoCAD:");
            try { r.AddRange(NativeThemes.Holding(new uint[] { 0x332922, 0x53443B, 0x6E5A4E, 0x3B302A, 0x40342E }).Select(l => "  " + l)); }
            catch (System.Exception ex) { r.Add("  " + ex.Message); }
            r.Add("");
            r.Add("Functions exported about the colour theme of AutoCAD, and by AdApplicationFrame.dll (module: name):");
            try { Frame(r); } catch (System.Exception ex) { r.Add("  " + ex.Message); }
            r.Add("");
            r.Add("Web pages:");
            try { r.AddRange(WebPages.Report().Select(l => "  " + l)); } catch (System.Exception ex) { r.Add("  " + ex.Message); }
            return r;
        }

        // The colour themes of AutoCAD in C++, read only, for (Dyl:RibbonSkin "Hosted" "Colors"):
        // CAcColorTheme of AdUi (from which the native themes and their controls take their
        // colours) and AdColorTheme of AdApplicationFrame.dll (the title bar), each element
        // from 0 until the call fails or Max: how many elements they have is not known.
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr StaticFn();
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate uint ColorFn(IntPtr self, int element);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int IntFn();

        static void Colours2(List<string> r)
        {
            void One(string prefix, string getName, string colName, string darkName, int max)
            {
                ProcessModule mod = null;
                foreach (ProcessModule m in Process.GetCurrentProcess().Modules)
                    if (m.ModuleName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) { mod = m; break; }
                if (mod == null) { r.Add(prefix + ": not loaded"); return; }
                var ex = new Dictionary<string, IntPtr>();
                NativeThemes.Exports(mod.BaseAddress, ex, x => x == getName || x == colName || x == darkName);
                if (!ex.TryGetValue(getName, out var g) || !ex.TryGetValue(colName, out var c)) { r.Add(mod.ModuleName + ": functions not found"); return; }
                IntPtr theme = Marshal.GetDelegateForFunctionPointer<StaticFn>(g)();
                r.Add(mod.ModuleName + ": current theme " + (theme == IntPtr.Zero ? "none" : "found")
                    + (ex.TryGetValue(darkName, out var d) ? ", dark " + Marshal.GetDelegateForFunctionPointer<IntFn>(d)() : ""));
                if (theme == IntPtr.Zero) return;
                var get = Marshal.GetDelegateForFunctionPointer<ColorFn>(c);
                var line = new StringBuilder();
                for (int e = 0; e < max; e++)
                {
                    uint v;
                    try { v = get(theme, e); }
                    catch (System.Exception x) { r.Add("  element " + e + ": " + x.GetType().Name + ", stopped"); break; }
                    var col = Color.FromRgb((byte)(v & 0xFF), (byte)(v >> 8 & 0xFF), (byte)(v >> 16 & 0xFF));
                    line.Append(e.ToString().PadLeft(4) + " " + Hex(col) + (v >> 24 != 0 ? "/" + (v >> 24).ToString("X2") : "   ") + (Blue(col) ? "*" : " "));
                    if (e % 8 == 7) { r.Add(line.ToString()); line.Clear(); }
                }
                if (line.Length > 0) r.Add(line.ToString());
            }
            r.Add("* = a blue-grey of AutoCAD");
            One("adui", "?GetCurrentTheme@CAcColorTheme@@SAAEBV1@XZ", "?GetRGBColor@CAcColorTheme@@QEBAKW4AcThemeElement@1@@Z",
                "?IsDarkTheme@CAcColorTheme@@SAHXZ", 400);
            r.Add("");
            One("AdApplicationFrame", "?GetCurrentTheme@AdColorTheme@@SAPEAV1@XZ", "?GetRGBColor@AdColorTheme@@UEBAKW4AdThemeElement@1@@Z",
                "-", 120);
        }

        // The functions exported by the modules of AutoCAD whose name speaks of the frame
        // (AdImpApplicationFrame draws the title bar in C++) and of its colours:
        static void Frame(List<string> r)
        {
            int n = 0;
            foreach (ProcessModule m in Process.GetCurrentProcess().Modules)
            {
                var into = new Dictionary<string, IntPtr>();
                try
                {
                    bool frame = m.ModuleName.StartsWith("AdApplicationFrame", StringComparison.OrdinalIgnoreCase)
                        || m.ModuleName.StartsWith("AdImp", StringComparison.OrdinalIgnoreCase);
                    NativeThemes.Exports(m.BaseAddress, into, x => frame
                        || x.Contains("ColorTheme") || x.Contains("ColourTheme") || x.Contains("ThemeColor")
                        || (x.Contains("ApplicationFrame") || x.Contains("TitleBar")) && (x.Contains("Color") || x.Contains("Theme")));
                }
                catch { continue; }
                foreach (var k in into.Keys.OrderBy(k => k))
                {
                    if (n++ >= 500) { r.Add("  ..."); return; }
                    r.Add("  " + m.ModuleName + ": " + k);
                }
            }
            if (n == 0) r.Add("  none");
        }

        static string Trim(string path)
        {
            var parts = path.Split(" > ");
            return parts.Length <= 6 ? path : parts[0] + " > ... > " + string.Join(" > ", parts.Skip(parts.Length - 5));
        }

        // ---- the windows on the screen ----

        [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
        delegate bool EnumProc(IntPtr h, IntPtr l);
        [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
        [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
        [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr h);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
        [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
        [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
        [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
        [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
        [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
        [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr d, int x, int y, int w, int h, IntPtr s, int sx, int sy, int op);
        [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
        [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
        [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr dc, IntPtr bmp, uint start, uint lines, [Out] byte[] bits, ref BITMAPINFO bi, uint usage);
        [StructLayout(LayoutKind.Sequential)]
        struct BITMAPINFO
        {
            public int Size, Width, Height; public short Planes, BitCount; public int Compression, SizeImage, XPels, YPels, ClrUsed, ClrImportant;
        }

        static string ClassOf(IntPtr h) { var sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }
        static string TextOf(IntPtr h) { var sb = new StringBuilder(128); GetWindowText(h, sb, 128); return sb.ToString(); }

        static void Pixels(List<string> r)
        {
            int vx = GetSystemMetrics(76), vy = GetSystemMetrics(77), vw = GetSystemMetrics(78), vh = GetSystemMetrics(79);
            byte[] bits = new byte[vw * vh * 4];
            IntPtr sdc = GetDC(IntPtr.Zero), mdc = CreateCompatibleDC(sdc), bmp = CreateCompatibleBitmap(sdc, vw, vh);
            try
            {
                var old = SelectObject(mdc, bmp);
                BitBlt(mdc, 0, 0, vw, vh, sdc, vx, vy, 0x00CC0020);
                SelectObject(mdc, old);
                var bi = new BITMAPINFO { Size = 40, Width = vw, Height = -vh, Planes = 1, BitCount = 32 };
                GetDIBits(mdc, bmp, 0, (uint)vh, bits, ref bi, 0);
            }
            finally { DeleteObject(bmp); DeleteDC(mdc); ReleaseDC(IntPtr.Zero, sdc); }

            // Each pixel given to the last (deepest, topmost child) visible window of AutoCAD over it:
            uint pid = (uint)Process.GetCurrentProcess().Id;
            var wins = new List<(IntPtr H, RECT R, int Depth)>();
            void Add(IntPtr h, int depth)
            {
                if (!IsWindowVisible(h) || !GetWindowRect(h, out var rc) || rc.Right <= rc.Left || rc.Bottom <= rc.Top) return;
                wins.Add((h, rc, depth));
                EnumChildWindows(h, (c, _) => { if (GetParent(c) == h) Add(c, depth + 1); return true; }, IntPtr.Zero);
            }
            var tops = new List<IntPtr>();
            EnumWindows((h, _) => { GetWindowThreadProcessId(h, out uint p); if (p == pid) tops.Add(h); return true; }, IntPtr.Zero);
            // EnumWindows gives the topmost first: the last added wins, so the tops go in reverse.
            tops.Reverse();
            foreach (var h in tops) Add(h, 0);
            var counts = new Dictionary<IntPtr, (int N, Dictionary<uint, int> Cols)>();
            // A grid of one pixel in 2 each way (a quarter of them), enough to find each part:
            for (int y = 0; y < vh; y += 2)
                for (int x = 0; x < vw; x += 2)
                {
                    int i = (y * vw + x) * 4;
                    var c = Color.FromRgb(bits[i + 2], bits[i + 1], bits[i]);
                    if (!Blue(c)) continue;
                    int sx = x + vx, sy = y + vy;
                    IntPtr owner = IntPtr.Zero;
                    for (int k = wins.Count - 1; k >= 0; k--)
                    {
                        var w = wins[k].R;
                        if (sx >= w.Left && sx < w.Right && sy >= w.Top && sy < w.Bottom) { owner = wins[k].H; break; }
                    }
                    if (owner == IntPtr.Zero) continue;
                    counts.TryGetValue(owner, out var e);
                    e.Cols ??= new Dictionary<uint, int>();
                    uint key = (uint)(c.R << 16 | c.G << 8 | c.B);
                    e.Cols[key] = e.Cols.TryGetValue(key, out int m) ? m + 1 : 1;
                    e.N++;
                    counts[owner] = e;
                }
            foreach (var (h, rc, depth) in wins)
            {
                if (!counts.TryGetValue(h, out var e) || e.N < 20) continue;
                var src = HwndSource.FromHwnd(h);
                string chain = ClassOf(h);
                for (IntPtr p = GetParent(h); p != IntPtr.Zero; p = GetParent(p)) chain = ClassOf(p) + " > " + chain;
                r.Add("  " + chain + " \"" + TextOf(h) + "\" " + (rc.Right - rc.Left) + "x" + (rc.Bottom - rc.Top) + " at " + rc.Left + "," + rc.Top
                    + ": " + e.N * 4 + " px (" + string.Join(" ", e.Cols.OrderByDescending(kv => kv.Value).Take(4).Select(kv => "#" + kv.Key.ToString("X6") + " " + kv.Value * 4))
                    + ")" + (src != null ? ", WPF " + src.RootVisual?.GetType().FullName : ""));
            }
        }
    }
}
