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
// gets a band of the colour of its project across its top (the tabs of the list, down their
// left side), drawn over it by an adorner, which changes nothing of the control, nor its size;
// where the tab has no adorner layer, its first border takes the colour instead. Anything not
// found (another version of AcWindows) leaves the tabs as they are and is said by
// (Dyl:RibbonFileTabs).
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

        const double Thick = 3;        // the band, in pixels

        // "Project" or "Sheet set", null while off:
        public static string Mode;
        static string _fail;
        static int _tabs, _colours;
        static bool _border;           // a tab coloured by its border (no adorner layer)
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
            return Mode + " (" + _tabs + " tabs, " + _colours + " colours" + (_border ? ", by their border" : "") + ")";
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
            _tabs = 0; _colours = 0; _border = false;
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
                if (band.Attached()) { band.Set(fill, side); _border |= band.ByBorder; return true; }
                band.Remove();
                Shown.Remove(tab);
            }
            band = Band.On(tab, fill, side);
            if (band == null) return false;
            Shown[tab] = band;
            _border |= band.ByBorder;
            return true;
        }

        // The band of a tab: an adorner drawn over it, or its first border in the colour.
        sealed class Band
        {
            readonly FrameworkElement _tab;
            Strip _strip;
            AdornerLayer _layer;
            Border _bd;
            object _wasBrush, _wasThick;
            public bool ByBorder => _bd != null;

            Band(FrameworkElement tab) { _tab = tab; }

            public static Band On(FrameworkElement tab, Brush fill, bool side)
            {
                var b = new Band(tab);
                var layer = AdornerLayer.GetAdornerLayer(tab);
                if (layer != null)
                {
                    b._layer = layer;
                    b._strip = new Strip(tab) { Fill = fill, Side = side };
                    layer.Add(b._strip);
                    return b;
                }
                // No adorner layer above the tab: its first border takes the colour.
                if (Find(tab, v => v is Border, 0) is Border bd)
                {
                    b._bd = bd;
                    b._wasBrush = bd.ReadLocalValue(Border.BorderBrushProperty);
                    b._wasThick = bd.ReadLocalValue(Border.BorderThicknessProperty);
                    b.Set(fill, side);
                    return b;
                }
                return null;
            }

            // Still on its tab (the tab bar made again takes another adorner layer):
            public bool Attached()
            {
                if (_bd != null) return PresentationSource.FromVisual(_bd) != null && IsAncestor(_tab, _bd);
                return _layer != null && ReferenceEquals(AdornerLayer.GetAdornerLayer(_tab), _layer)
                       && (_layer.GetAdorners(_tab)?.Contains(_strip) ?? false);
            }

            static bool IsAncestor(DependencyObject up, DependencyObject node)
            {
                for (var n = node; n != null; n = VisualTreeHelper.GetParent(n))
                    if (ReferenceEquals(n, up)) return true;
                return false;
            }

            public void Set(Brush fill, bool side)
            {
                if (_strip != null)
                {
                    if (!ReferenceEquals(_strip.Fill, fill) || _strip.Side != side)
                    {
                        _strip.Fill = fill;
                        _strip.Side = side;
                        _strip.InvalidateVisual();
                    }
                    return;
                }
                if (_bd == null) return;
                var th = side ? new Thickness(Thick, 0, 0, 0) : new Thickness(0, Thick, 0, 0);
                if (!ReferenceEquals(_bd.BorderBrush, fill)) _bd.BorderBrush = fill;
                if (_bd.BorderThickness != th) _bd.BorderThickness = th;
            }

            // Gone, and the border given back what it had:
            public void Remove()
            {
                try { if (_strip != null) _layer?.Remove(_strip); } catch { }
                if (_bd == null) return;
                try
                {
                    if (_wasBrush == DependencyProperty.UnsetValue) _bd.ClearValue(Border.BorderBrushProperty);
                    else _bd.BorderBrush = _wasBrush as Brush;
                    if (_wasThick == DependencyProperty.UnsetValue) _bd.ClearValue(Border.BorderThicknessProperty);
                    else if (_wasThick is Thickness t) _bd.BorderThickness = t;
                }
                catch { }
            }
        }

        // The band itself: across the top of a tab, or down the left side of a tab of the list.
        // Never hit by the mouse, so the tab is clicked, dragged and closed as before.
        sealed class Strip : Adorner
        {
            public Brush Fill;
            public bool Side;

            public Strip(UIElement tab) : base(tab)
            {
                IsHitTestVisible = false;
                IsClipEnabled = true;
            }

            protected override void OnRender(DrawingContext dc)
            {
                var s = AdornedElement.RenderSize;
                if (Fill == null || s.Width <= 0 || s.Height <= 0) return;
                dc.DrawRectangle(Fill, null, Side ? new Rect(0, 0, Math.Min(Thick, s.Width), s.Height)
                                                  : new Rect(0, 0, s.Width, Math.Min(Thick, s.Height)));
            }
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
                                           (AdornerLayer.GetAdornerLayer(tab) != null ? ", adorner layer" : ", no adorner layer")));
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

        static string Size(FrameworkElement e) => Math.Round(e.ActualWidth) + "x" + Math.Round(e.ActualHeight);

        static string Safe(Func<object> f)
        {
            try { return Convert.ToString(f()); } catch (System.Exception ex) { return "(" + ex.GetType().Name + ")"; }
        }
    }
}
