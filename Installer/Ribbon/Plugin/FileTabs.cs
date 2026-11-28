// FileTabs.cs - DynALisp.Ribbon: a band of colour on the file tabs, by project or sheet set (experiment)
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
// EXPERIMENT, not supported by Autodesk. The file tabs of AutoCAD (FILETAB) are a WPF control
// of AcWindows.dll (Autodesk.AutoCAD.UserControls.DocumentSwitchControl, internal): its tabs
// are the items of its ItemsControl tabDrawings (and of MoreControl, the list of the tabs that
// do not fit), each a WindowData; a drawing is a DrawingWindowData, whose Doc is its Document.
// No API gives them: the control is found among the WPF windows of AutoCAD by the name of its
// type, the items read by the names of their properties. Each tab of a drawing of a project
// gets a thin bar of the colour of its project just left of its title, slanted as the side of
// the tab (the tabs of the list: down their left side), always shown: an element of DynALisp
// added over the grid of the tab (or an adorner), which changes nothing of the control, nor its
// size, nor any element of its template. Anything not found (another version of AcWindows)
// leaves the tabs as they are and is said by (Dyl:RibbonFileTabs).
//
// The project of a drawing is found from the folder of the drawing up, as the Lisp side finds it:
//   - Project: the first folder holding a .apj (Project Navigator of AutoCAD Architecture),
//     Remote>>Dyl:RevProject of Remote\Dyl-Revisions.lsp;
//   - Sheet set: the first folder holding a .dst, Local>>Dyl:FindSheetSetDir of
//     Apps\Utilities\Dyl-OpenFolder.lsp.
// Change them together. A drawing in neither (or never saved) has no band.
//
// Each project keeps its colour for the session: the colour of its name in the palette (the
// same project, the same colour, every day and on every computer), the next one free when
// another project open has it.
//
// On while Display is on in Dyl-Settings (DynalispDisplayOn) and its File tabs
// (DynalispFileTabColors) is Project or Sheet set, read here from the registry when the plugin
// loads and again when the Lisp side calls (Dyl:RibbonFileTabs) or (Dyl:RibbonSkin). Done when
// AutoCAD is idle (Host.OnIdle), twice a second at most; turned off, every band is removed.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    // The Lisp function of the file tabs (see LangCommands: a static class cannot hold it).
    public class FileTabCommands
    {
        // (Dyl:RibbonFileTabs ["Tree"]): reads the settings again, shows or removes the bands the
        // next time AutoCAD is idle, and returns what it does: "Project (5 tabs, 2 colours)",
        // "off", "not found: ...". "Tree": what AutoCAD gives of its file tabs, in a text file
        // of %TEMP% (a diagnostic, for another version of AutoCAD).
        [LispFunction("Dyl:RibbonFileTabs")]
        public static object RibbonFileTabs(ResultBuffer args)
        {
            try
            {
                FileTabs.Read();
                string which = args?.AsArray().Select(v => v.Value as string).FirstOrDefault(v => v != null);
                if (string.Equals(which, "Tree", StringComparison.OrdinalIgnoreCase))
                {
                    string file = Path.Combine(Path.GetTempPath(), "DynALisp-FileTabs.txt");
                    var lines = FileTabs.Report();
                    File.WriteAllLines(file, lines);
                    return file + " (" + lines.Count + " lines)";
                }
                return FileTabs.Status();
            }
            catch (System.Exception ex) { return "error: " + ex.Message; }
        }
    }

    public static class FileTabs
    {
        // The colours of the projects: saturated, readable on the dark and the light tabs, the
        // orange and the teal of the logo first.
        // Also in StartPage.cs of DynALisp.Windows.dll (the dots of the Start page), which reads
        // Colours by reflection: change them together.
        static readonly Color[] Palette =
        {
            Color.FromRgb(0xF2, 0x8C, 0x28),  // orange
            Color.FromRgb(0x1F, 0xB5, 0xA8),  // teal
            Color.FromRgb(0x3D, 0x8E, 0xF0),  // blue
            Color.FromRgb(0xA0, 0x66, 0xD3),  // purple
            Color.FromRgb(0xE8, 0xC5, 0x47),  // yellow
            Color.FromRgb(0x5C, 0xB8, 0x5C),  // green
            Color.FromRgb(0xE2, 0x5D, 0x8E),  // pink
            Color.FromRgb(0xD9, 0x44, 0x3A),  // red
        };
        static readonly Brush[] Brushes = Palette.Select(c => { var b = new SolidColorBrush(c); b.Freeze(); return (Brush)b; }).ToArray();


        // "Project" or "Sheet set", null while off:
        public static string Mode;
        static string _fail;
        static int _tabs, _colours;
        static bool _hidden;           // the file tabs not shown (FILETABSTATE 0)
        static bool _due = true;
        static bool _waiting = true;   // the mode changed, not applied yet
        static int _next = Environment.TickCount;
        static int _nextFind = Environment.TickCount;
        static FrameworkElement _ctl;  // the DocumentSwitchControl

        // The bands shown: the tab (the container of its item) and its band.
        static readonly Dictionary<FrameworkElement, Band> Shown = new(ReferenceEqualityComparer.Instance);

        public static void Start() => Read();

        // The settings, from the registry (setenv / getenv: FixedProfile\General):
        public static void Read()
        {
            string m = Env("DynalispDisplayOn") == "1" ? Env("DynalispFileTabColors") : null;
            string mode = m == "Project" || m == "Sheet set" ? m : null;
            if (mode != Mode) { Folders.Clear(); _fail = null; _waiting = true; }
            Mode = mode;
            _due = true;
            _next = Environment.TickCount;
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

        public static string Status()
        {
            if (Mode == null) return "off";
            if (_fail != null) return "not found: " + _fail;
            if (_waiting) return Mode + " (on the next idle)";
            if (_hidden) return Mode + " (the file tabs are hidden: FILETAB shows them)";
            return Mode + " (" + _tabs + " tabs, " + _colours + " colours)";
        }

        // AutoCAD idle: the bands shown again, twice a second at most (the tabs change with no
        // event: a drawing opened, saved under another name, a tab dragged...).
        public static void OnIdle()
        {
            if (Mode == null && Shown.Count == 0) { _due = false; return; }
            if (!_due && Environment.TickCount - _next < 0) return;
            _due = false;
            _next = Environment.TickCount + 500;
            try { Apply(); }
            catch (System.Exception ex) { _fail = ex.GetType().Name + ": " + ex.Message; }
            _waiting = false;
        }

        // ---- the control of the file tabs ----

        static bool Hidden()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("FILETABSTATE")) == 0; }
            catch { return false; }
        }

        // Found among the WPF windows of AutoCAD by the name of its type, then kept while it is
        // shown; looked for again every 5 seconds at most while it is not found (FILETAB off).
        static FrameworkElement Control()
        {
            if (_ctl != null && PresentationSource.FromVisual(_ctl) != null) return _ctl;
            _ctl = null;
            if (Environment.TickCount - _nextFind < 0) return null;
            _nextFind = Environment.TickCount + 5000;
            foreach (PresentationSource src in PresentationSource.CurrentSources)
            {
                var found = Find(src?.RootVisual, v => v.GetType().Name == "DocumentSwitchControl", 0);
                if (found is FrameworkElement fe) return _ctl = fe;
            }
            return null;
        }

        static DependencyObject Find(DependencyObject node, Func<DependencyObject, bool> test, int depth)
        {
            if (node == null || depth > 60) return null;
            if (test(node)) return node;
            if (!(node is Visual) && !(node is System.Windows.Media.Media3D.Visual3D)) return null;
            int n = VisualTreeHelper.GetChildrenCount(node);
            for (int i = 0; i < n; i++)
            {
                var r = Find(VisualTreeHelper.GetChild(node, i), test, depth + 1);
                if (r != null) return r;
            }
            return null;
        }

        // Its lists of tabs: the tabs shown (tabDrawings) and the tabs that do not fit
        // (MoreControl, a drop-down list), by their names, else every ItemsControl in it.
        static List<(ItemsControl List, bool Side)> Lists(FrameworkElement ctl)
        {
            var res = new List<(ItemsControl, bool)>();
            if (ctl.FindName("tabDrawings") is ItemsControl tabs) res.Add((tabs, false));
            if (ctl.FindName("MoreControl") is ItemsControl more) res.Add((more, true));
            if (res.Count == 0)
            {
                var first = Find(ctl, v => v is ItemsControl ic && ic.Items.Cast<object>().Any(IsWindow), 0) as ItemsControl;
                if (first != null) res.Add((first, false));
            }
            return res;
        }

        static bool IsWindow(object item)
        {
            for (var t = item?.GetType(); t != null; t = t.BaseType)
                if (t.Name == "WindowData") return true;
            return false;
        }

        // The drawing of a tab (DrawingWindowData.Doc), null for another tab (the Start tab):
        static Document DocOf(object item)
        {
            try { return item?.GetType().GetProperty("Doc", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(item) as Document; }
            catch { return null; }
        }

        // ---- the projects ----

        // The project of each folder (the path of its .apj or .dst, "" for none), until the
        // mode or the drawings open change:
        static readonly Dictionary<string, string> Folders = new(StringComparer.OrdinalIgnoreCase);
        static string _docsSeen = "";

        // The project of a drawing (the path of its .apj or .dst), null when it has none:
        static string ProjectOf(Document doc)
        {
            string name;
            try { name = doc?.Name; } catch { return null; }
            if (string.IsNullOrEmpty(name) || !Path.IsPathRooted(name)) return null;
            string dir = Path.GetDirectoryName(name);
            if (dir == null) return null;
            if (!Folders.TryGetValue(dir, out string key))
            {
                key = "";
                string pattern = Mode == "Project" ? "*.apj" : "*.dst";
                for (var d = dir; !string.IsNullOrEmpty(d); d = Path.GetDirectoryName(d))
                {
                    string hit = null;
                    try { hit = Directory.EnumerateFiles(d, pattern).OrderBy(f => f, StringComparer.OrdinalIgnoreCase).FirstOrDefault(); }
                    catch { }
                    if (hit != null) { key = hit; break; }
                }
                Folders[dir] = key;
            }
            return key == "" ? null : key;
        }

        // The colour of each project for the session (its index in Palette), and the projects
        // of the tabs at the last pass:
        static readonly Dictionary<string, int> Colours = new(StringComparer.OrdinalIgnoreCase);
        static HashSet<string> _open = new(StringComparer.OrdinalIgnoreCase);

        // The colours of the projects open, in the order of their tabs: a project already open
        // keeps its colour; one that appears takes the colour it had this session, else the
        // colour of its name, or the next one free when another project open has it.
        static Dictionary<string, int> Assign(List<string> projects)
        {
            var res = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in projects.Distinct(StringComparer.OrdinalIgnoreCase))
                if (_open.Contains(p) && Colours.TryGetValue(p, out int k)) res[p] = k;
            foreach (var p in projects.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                if (res.ContainsKey(p)) continue;
                int want = Colours.TryGetValue(p, out int had) ? had : (int)(Hash(Path.GetFileNameWithoutExtension(p)) % (uint)Palette.Length);
                int pick = want;
                for (int i = 0; i < Palette.Length; i++)
                {
                    int c = (want + i) % Palette.Length;
                    if (!res.ContainsValue(c)) { pick = c; break; }
                }
                res[p] = pick;
                Colours[p] = pick;
            }
            _open = new HashSet<string>(res.Keys, StringComparer.OrdinalIgnoreCase);
            return res;
        }

        // FNV-1a of the name in lower case: the same on every computer and in every session.
        static uint Hash(string s)
        {
            uint h = 2166136261;
            foreach (char ch in (s ?? "").ToLowerInvariant()) { h ^= ch; h *= 16777619; }
            return h;
        }

        // ---- the bands ----

        static void Apply()
        {
            // The file tabs hidden (FILETABCLOSE): nothing to colour, nothing wrong, and no
            // window of AutoCAD searched for them.
            _hidden = Mode != null && Hidden();
            var ctl = Mode == null || _hidden ? null : Control();
            var keep = new HashSet<FrameworkElement>(ReferenceEqualityComparer.Instance);
            _tabs = 0; _colours = 0;
            if (_hidden) _fail = null;
            else if (Mode != null && ctl == null) _fail = "the file tabs of AutoCAD";
            if (ctl != null)
            {
                _fail = null;
                var lists = Lists(ctl);
                if (lists.Count == 0) _fail = "the list of the file tabs";
                // The drawings open changed: their folders are looked at again.
                string docs = string.Join("|", AcApp.DocumentManager.Cast<Document>().Select(d => { try { return d.Name; } catch { return ""; } }));
                if (docs != _docsSeen) { Folders.Clear(); _docsSeen = docs; }
                var tabs = new List<(FrameworkElement Tab, string Project, bool Side)>();
                foreach (var (list, side) in lists)
                    foreach (var item in list.Items)
                    {
                        if (!IsWindow(item)) continue;
                        var tab = list.ItemContainerGenerator.ContainerFromItem(item) as FrameworkElement;
                        if (tab == null) continue;
                        tabs.Add((tab, ProjectOf(DocOf(item)), side));
                    }
                var colours = Assign(tabs.Where(t => t.Project != null && !t.Side).Select(t => t.Project)
                                         .Concat(tabs.Where(t => t.Project != null && t.Side).Select(t => t.Project)).ToList());
                _colours = colours.Count;
                foreach (var (tab, project, side) in tabs)
                {
                    if (project == null) continue;
                    if (Show(tab, Brushes[colours[project]], side)) { keep.Add(tab); _tabs++; }
                }
            }
            // The bands of the tabs gone, or of a drawing no longer in a project:
            foreach (var tab in Shown.Keys.Where(t => !keep.Contains(t)).ToList())
            {
                Shown[tab].Remove();
                Shown.Remove(tab);
            }
        }

        // The band of a tab, shown or given its colour; false when it cannot be shown.
        static bool Show(FrameworkElement tab, Brush fill, bool side)
        {
            if (Shown.TryGetValue(tab, out var band))
            {
                if (band.Attached()) { band.Set(fill, side); return true; }
                band.Remove();
                Shown.Remove(tab);
            }
            band = Band.On(tab, fill, side);
            if (band == null) return false;
            Shown[tab] = band;
            return true;
        }

        // The band of a tab, in this order:
        //   - an element of DynALisp (Overlay) added over the content of the first grid of the tab
        //     that is always shown (not a part shown only under the mouse): the band stays
        //     whatever the mouse does, and takes no room;
        //   - else an adorner over the tab (Strip), when the tab has an adorner layer above it;
        //   - else none: never an element of the template recoloured (the first border of the tab
        //     of AutoCAD 2027 is its close button, shown only under the mouse).
        sealed class Band
        {
            readonly FrameworkElement _tab;
            Overlay _over;
            Grid _grid;
            Strip _strip;
            AdornerLayer _layer;
            public string How => _over != null ? "grid" : _strip != null ? "adorner" : "-";

            Band(FrameworkElement tab) { _tab = tab; }

            public static Band On(FrameworkElement tab, Brush fill, bool side)
            {
                var b = new Band(tab);
                var grid = HostGrid(tab);
                if (grid != null)
                {
                    b._grid = grid;
                    b._over = new Overlay(tab) { Fill = fill, Side = side };
                    Grid.SetRowSpan(b._over, Math.Max(1, grid.RowDefinitions.Count));
                    Grid.SetColumnSpan(b._over, Math.Max(1, grid.ColumnDefinitions.Count));
                    Panel.SetZIndex(b._over, 10000);
                    grid.Children.Add(b._over);
                    return b;
                }
                var layer = AdornerLayer.GetAdornerLayer(tab);
                if (layer != null)
                {
                    b._layer = layer;
                    b._strip = new Strip(tab) { Fill = fill, Side = side };
                    layer.Add(b._strip);
                    return b;
                }
                return null;
            }

            // The first grid of the tab (from the tab down) as wide as the tab nearly, always
            // shown: it and every element between it and the tab visible and opaque (a part of
            // the template shown only under the mouse is hidden or transparent otherwise).
            static Grid HostGrid(FrameworkElement tab)
            {
                var queue = new Queue<(DependencyObject, int)>();
                queue.Enqueue((tab, 0));
                while (queue.Count > 0)
                {
                    var (node, depth) = queue.Dequeue();
                    if (node is UIElement u && (u.Visibility != System.Windows.Visibility.Visible || u.Opacity < 0.99)) continue;
                    if (node is Grid g && g.ActualWidth >= tab.ActualWidth * 0.8 && g.ActualHeight >= tab.ActualHeight * 0.6) return g;
                    if (depth >= 8 || !(node is Visual)) continue;
                    int n = VisualTreeHelper.GetChildrenCount(node);
                    for (int i = 0; i < n; i++) queue.Enqueue((VisualTreeHelper.GetChild(node, i), depth + 1));
                }
                return null;
            }

            // Still on its tab (the tab made again from its template, the tab bar again):
            public bool Attached()
            {
                if (_over != null)
                    return ReferenceEquals(VisualTreeHelper.GetParent(_over), _grid) && IsAncestor(_tab, _grid)
                           && PresentationSource.FromVisual(_over) != null;
                return _layer != null && ReferenceEquals(AdornerLayer.GetAdornerLayer(_tab), _layer)
                       && (_layer.GetAdorners(_tab)?.Contains(_strip) ?? false);
            }

            static bool IsAncestor(DependencyObject up, DependencyObject node)
            {
                for (var n = node; n != null; n = VisualTreeHelper.GetParent(n))
                    if (ReferenceEquals(n, up)) return true;
                return false;
            }

            // The colour, and the band drawn again, only when what it is drawn from changed (its
            // colour, the size of the tab, the place of its title): a band drawn again twice a
            // second made WPF lay out the file tabs again during a pan or a zoom.
            string _key;

            public void Set(Brush fill, bool side)
            {
                FrameworkElement on = (FrameworkElement)_over ?? _strip;
                if (on == null) return;
                string key;
                try { key = RuntimeHelpers.GetHashCode(fill) + "|" + side + "|" + on.RenderSize + "|" + TextLeft(on, _tab).ToString("0.0"); }
                catch { key = null; }
                if (key != null && key == _key) return;
                _key = key;
                if (_over != null) { _over.Fill = fill; _over.Side = side; _over.InvalidateVisual(); return; }
                _strip.Fill = fill; _strip.Side = side; _strip.InvalidateVisual();
            }

            public void Remove()
            {
                try { if (_over != null) _grid?.Children.Remove(_over); } catch { }
                try { if (_strip != null) _layer?.Remove(_strip); } catch { }
            }
        }

        // The band, drawn on an element over the tab (on): a thin bar just left of the title of
        // the tab, slanted as the left side of the tab (the first shape of the tab whose left
        // edge leans), from its top to its bottom; down the left side of a tab of the list.
        // Never hit by the mouse, so the tab is clicked, dragged and closed as before.
        static void Draw(DrawingContext dc, FrameworkElement on, FrameworkElement tab, Brush fill, bool side)
        {
            var size = on.RenderSize;
            if (fill == null || size.Width <= 0 || size.Height <= 0) return;
            if (side) { dc.DrawRectangle(fill, null, new Rect(0, 0, Math.Min(Wide, size.Width), size.Height)); return; }
            var (xt, xb, yt, yb) = LeftEdge(on, tab, size);
            double tx = TextLeft(on, tab);
            // The slant of the side (its x at the top less its x at the bottom), the bar put just
            // left of the title with it: the side found may be the one at the right of the tab.
            double lean = xt - xb;
            double top = double.IsNaN(tx) ? Math.Max(xt, xb) + 4 : tx - Gap - Wide;
            double bot = top - lean;
            var g = new StreamGeometry();
            using (var c = g.Open())
            {
                c.BeginFigure(new Point(bot, yb), true, true);
                c.LineTo(new Point(bot + Wide, yb), false, false);
                c.LineTo(new Point(top + Wide, yt), false, false);
                c.LineTo(new Point(top, yt), false, false);
            }
            g.Freeze();
            dc.DrawGeometry(fill, null, g);
        }

        const double Wide = 2;         // the band, in pixels
        const double Gap = 4;          // between the band and the title

        // A side of the tab in the coordinates of on: (x at the top, x at the bottom, top, bottom).
        // The tab of AutoCAD 2027 is a grid of a Rectangle (its body) and Paths 10 px wide (the
        // slanted separators of the tabs, / ): the side is the leftmost leaning edge of its
        // shapes as tall as the tab nearly; a straight side (x the same) when none leans.
        public static (double, double, double, double) LeftEdge(FrameworkElement on, FrameworkElement tab, Size size)
        {
            (double, double, double, double)? best = null;
            try
            {
                foreach (var sh in Below(tab).OfType<System.Windows.Shapes.Shape>())
                {
                    if (sh.Visibility != System.Windows.Visibility.Visible || sh.ActualHeight < size.Height * 0.6) continue;
                    var geo = sh.RenderedGeometry?.GetFlattenedPathGeometry();
                    if (geo == null || geo.IsEmpty()) continue;
                    var to = sh.TransformToVisual(on);
                    var pts = new List<Point>();
                    foreach (var f in geo.Figures)
                    {
                        pts.Add(to.Transform(f.StartPoint));
                        foreach (var seg in f.Segments)
                            if (seg is PolyLineSegment pl) foreach (var pt in pl.Points) pts.Add(to.Transform(pt));
                            else if (seg is LineSegment ls) pts.Add(to.Transform(ls.Point));
                    }
                    if (pts.Count < 2) continue;
                    double top = pts.Min(q => q.Y), bot = pts.Max(q => q.Y);
                    if (bot - top < size.Height * 0.6) continue;
                    double xt = pts.Where(q => q.Y - top < 1.5).Min(q => q.X);
                    double xb = pts.Where(q => bot - q.Y < 1.5).Min(q => q.X);
                    if (Math.Abs(xt - xb) < 1) continue;
                    if (best == null || Math.Min(xt, xb) < Math.Min(best.Value.Item1, best.Value.Item2))
                        best = (xt, xb, top, bot);
                }
            }
            catch { }
            return best ?? (0, 0, 0, size.Height);
        }

        // The left of the title of the tab in the coordinates of on, NaN when it has none:
        public static double TextLeft(FrameworkElement on, FrameworkElement tab)
        {
            try
            {
                foreach (var v in Below(tab))
                    if (v is TextBlock t && t.IsVisible && !string.IsNullOrWhiteSpace(t.Text) && t.ActualWidth > 0)
                        return t.TransformToVisual(on).Transform(new Point(0, 0)).X;
            }
            catch { }
            return double.NaN;
        }

        // The elements of the tab, from the tab down (never the bands of DynALisp):
        static IEnumerable<DependencyObject> Below(DependencyObject node)
        {
            if (node == null || node is Overlay) yield break;
            yield return node;
            if (!(node is Visual)) yield break;
            int n = VisualTreeHelper.GetChildrenCount(node);
            for (int i = 0; i < n; i++)
                foreach (var d in Below(VisualTreeHelper.GetChild(node, i))) yield return d;
        }

        // The band as an element of the tab:
        sealed class Overlay : FrameworkElement
        {
            public Brush Fill;
            public bool Side;
            readonly FrameworkElement _tab;
            public Overlay(FrameworkElement tab)
            {
                _tab = tab;
                IsHitTestVisible = false;
                Focusable = false;
                HorizontalAlignment = HorizontalAlignment.Stretch;
                VerticalAlignment = VerticalAlignment.Stretch;
            }
            protected override void OnRender(DrawingContext dc) => Draw(dc, this, _tab, Fill, Side);
        }

        // The band as an adorner of the tab:
        sealed class Strip : Adorner
        {
            public Brush Fill;
            public bool Side;

            public Strip(UIElement tab) : base(tab)
            {
                IsHitTestVisible = false;
                IsClipEnabled = true;
            }

            protected override void OnRender(DrawingContext dc) => Draw(dc, this, (FrameworkElement)AdornedElement, Fill, Side);
        }

        // ---- the diagnostic ----

        // What AutoCAD gives of its file tabs: the control, its lists, each tab with its drawing
        // and its project, then the tree of the control (types, names, sizes) for a version of
        // AutoCAD whose tabs are not found.
        public static List<string> Report()
        {
            var lines = new List<string>
            {
                "DynALisp file tabs - " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                "Status: " + Status(),
                "AutoCAD: " + Safe(() => AcApp.GetSystemVariable("ACADVER")) + ", FILETAB " + Safe(() => AcApp.GetSystemVariable("FILETABSTATE")),
            };
            _nextFind = Environment.TickCount;
            var ctl = Control();
            int sources = 0;
            foreach (PresentationSource src in PresentationSource.CurrentSources)
            {
                sources++;
                lines.Add("WPF window: " + (src?.RootVisual?.GetType().FullName ?? "(none)"));
            }
            lines.Add(sources + " WPF windows");
            if (ctl == null) { lines.Add("DocumentSwitchControl: not found"); return lines; }
            lines.Add("DocumentSwitchControl: " + ctl.GetType().AssemblyQualifiedName);
            lines.Add("Adorner layer above it: " + (AdornerLayer.GetAdornerLayer(ctl) != null ? "yes" : "no"));
            foreach (var (list, side) in Lists(ctl))
            {
                lines.Add("");
                lines.Add("List " + (list.Name ?? "") + " (" + list.GetType().Name + "), " + list.Items.Count + " items" + (side ? ", the drop-down list" : ""));
                foreach (var item in list.Items)
                {
                    var tab = list.ItemContainerGenerator.ContainerFromItem(item) as FrameworkElement;
                    var doc = DocOf(item);
                    string title = Safe(() => item.GetType().GetProperty("Title")?.GetValue(item));
                    lines.Add("  " + item.GetType().Name + " \"" + title + "\"" +
                              ", drawing: " + (doc != null ? Safe(() => doc.Name) : "-") +
                              ", project: " + (doc != null && Mode != null ? (ProjectOf(doc) ?? "-") : "-") +
                              ", tab: " + (tab == null ? "-" : tab.GetType().Name + " " + Size(tab) +
                                           (AdornerLayer.GetAdornerLayer(tab) != null ? ", adorner layer" : ", no adorner layer") +
                                           (Shown.TryGetValue(tab, out var bd) ? ", band: " + bd.How : "") +
                                           ", side " + Edge(tab) + ", title at " + Math.Round(TextLeft(tab, tab), 1)));
                }
            }
            lines.Add("");
            lines.Add("Tree:");
            Tree(ctl, 0, lines);
            return lines;
        }

        static void Tree(DependencyObject node, int depth, List<string> lines)
        {
            if (node == null || depth > 25 || lines.Count > 4000) return;
            string name = node is FrameworkElement fe && !string.IsNullOrEmpty(fe.Name) ? " #" + fe.Name : "";
            string dc = node is FrameworkElement f2 && f2.DataContext != null ? " [" + f2.DataContext.GetType().Name + "]" : "";
            string extra = node is Border b ? " border " + b.BorderThickness + " " + b.BorderBrush : "";
            lines.Add(new string(' ', depth * 2) + node.GetType().Name + name + (node is FrameworkElement f3 ? " " + Size(f3) : "") + dc + extra);
            if (!(node is Visual)) return;
            int n = VisualTreeHelper.GetChildrenCount(node);
            for (int i = 0; i < n; i++) Tree(VisualTreeHelper.GetChild(node, i), depth + 1, lines);
        }

        static string Edge(FrameworkElement tab)
        {
            var (xt, xb, yt, yb) = LeftEdge(tab, tab, tab.RenderSize);
            return "(" + Math.Round(xb, 1) + "," + Math.Round(yb, 1) + ")-(" + Math.Round(xt, 1) + "," + Math.Round(yt, 1) + ")";
        }

        static string Size(FrameworkElement e) => Math.Round(e.ActualWidth) + "x" + Math.Round(e.ActualHeight);

        static string Safe(Func<object> f)
        {
            try { return Convert.ToString(f()); } catch (System.Exception ex) { return "(" + ex.GetType().Name + ")"; }
        }
    }
}
