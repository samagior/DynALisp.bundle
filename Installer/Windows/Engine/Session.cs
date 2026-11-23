// Session.cs - DynALisp.Windows: shows a window file (.xaml) on the values of the Lisp
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
// A session is one call of (Dyl:Window file values): the values given by the Lisp, kept by
// key while the window and its sub-windows are open, then given back.
//
//   Values  key -> value, as get_tile / set_tile of DCL: "1" / "0" for a checkbox, the
//           index of the item picked for a list ("0"), the text of a text box or a text
//   Lists   key -> the items of a list (start_list / add_list)
//   Off     the keys greyed out by the Lisp (mode_tile 1), whatever their rules
//   Rows    key -> rows of strings (a table: the presets of a preset window, see Presets.cs,
//           the rows of a list edited in the window, see Rows.cs);
//           those named in OutRows are given back to the Lisp with the values
//
// The value win/title, when the Lisp gives it, is the title of the next window shown in
// place of the Title of its file (the Preset Groups window on the groups of the materials:
// Material Groups), then dropped.
//
// A control takes the value of its key when the window opens, and puts its value back
// each time it changes, so the rules (Win.EnabledBy, Win.VisibleBy) and the sub-windows
// see it at once. A sub-window (Win.Open) works on the same values: its Cancel puts back
// the values it had when it opened. No AutoCAD here: Bridge.cs shows the first window
// over AutoCAD (ShowRoot), the pictures tool of the docs renders them (Shots\).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Interop;
using System.Windows.Media;
using System.Xaml;
using System.Xml;
using WpfXamlReader = System.Windows.Markup.XamlReader;

namespace DynALisp.Windows
{
    public sealed class Session
    {
        public readonly Dictionary<string, string> Values = new Dictionary<string, string>(StringComparer.Ordinal);
        public readonly Dictionary<string, List<string>> Lists = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        public readonly HashSet<string> Off = new HashSet<string>(StringComparer.Ordinal);
        public readonly Dictionary<string, List<string[]>> Rows = new Dictionary<string, List<string[]>>(StringComparer.Ordinal);
        public readonly HashSet<string> OutRows = new HashSet<string>(StringComparer.Ordinal);

        // The dark theme of AutoCAD (COLORTHEME 0), the light one else:
        public bool Dark;

        // Shows the first window (over AutoCAD); ShowDialog when null:
        public Func<Window, bool?> ShowRoot;

        // The docs of a window: "docs/<page>" -> what opens it (the address on the docs
        // website, or a file), given by the Lisp (Dyl:WinShow), as Dyl:DocsTarget finds it:
        public static string DocsKey(string page) => "docs/" + (page ?? "");

        // Shows the window file path, then its sub-windows as they are opened. Returns the
        // number of the button that closed it: 0 Cancel (or the window closed), 1 OK / Save,
        // or its Win.Close.
        public int Show(string path) => Show(path, null);

        int Show(string path, Window owner)
        {
            var view = Open(path);
            if (owner != null)
            {
                view.Window.Owner = owner;
                view.Window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                view.Window.ShowDialog();
            }
            else if (ShowRoot != null) ShowRoot(view.Window);
            else view.Window.ShowDialog();
            return view.Status;
        }

        // The window of path on the values, not shown yet (the pictures tool renders it):
        public View Open(string path)
        {
            var w = Load(path, Dark);
            if (Values.TryGetValue("win/title", out string title) && !string.IsNullOrEmpty(title))
            {
                w.Title = title;
                Values.Remove("win/title");
            }
            var view = new View(this, w, Path.GetDirectoryName(Path.GetFullPath(path)));
            view.Fill();
            return view;
        }

        internal int ShowSub(string path, Window owner)
        {
            var before = new Dictionary<string, string>(Values, StringComparer.Ordinal);
            int status = Show(path, owner);
            if (status == 0)
            {
                Values.Clear();
                foreach (var kv in before) Values[kv.Key] = kv.Value;
            }
            return status;
        }

        // A window file: its root is a Window. The dyl: prefix (clr-namespace:DynALisp.Windows,
        // no assembly) is this assembly, wherever AutoCAD loaded it from:
        public static Window Load(string path, bool dark)
        {
            if (!File.Exists(path)) throw new FileNotFoundException("Window file not found: " + path, path);
            object root;
            using (var xml = XmlReader.Create(path))
            using (var reader = new XamlXmlReader(xml, WpfXamlReader.GetWpfSchemaContext(),
                       new XamlXmlReaderSettings { LocalAssembly = typeof(Session).Assembly }))
                root = WpfXamlReader.Load(reader);
            var w = root as Window;
            if (w == null) throw new InvalidDataException("Not a window (its root must be a Window): " + path);
            Theme.Apply(w, dark);
            return w;
        }

        public static void OpenTarget(string target)
        {
            if (string.IsNullOrEmpty(target)) return;
            Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
        }
    }

    // The look of the windows: the styles of Theme.xaml (embedded, read once) and the Dyl.*
    // brushes of the light or the dark theme of AutoCAD (COLORTHEME 1 or 0), its blue for
    // what is picked. A dark window also gets the dark title bar of Windows.
    public static class Theme
    {
        static ResourceDictionary _styles;

        // Dark: the grey blue of the palettes of AutoCAD; light: its light greys.
        static readonly Dictionary<string, string> DarkColors = new Dictionary<string, string>
        {
            ["Back"] = "#252A32", ["Surface"] = "#313844", ["Border"] = "#3C4452", ["BorderStrong"] = "#4C5566",
            ["Text"] = "#E6EAF0", ["Heading"] = "#FFFFFF", ["Muted"] = "#A3ADBC", ["Disabled"] = "#6E7889",
            ["Hover"] = "#434C5B", ["Pressed"] = "#525D71", ["Input"] = "#2A3039", ["InputBorder"] = "#4C5566",
            ["Accent"] = "#0696D7", ["AccentHover"] = "#22A9E8", ["AccentText"] = "#FFFFFF", ["ErrorText"] = "#FF8F85",
            ["TitleBar"] = "#1E2229", ["TitleText"] = "#E6EAF0", ["ButtonBack"] = "#3A4250",
        };
        static readonly Dictionary<string, string> LightColors = new Dictionary<string, string>
        {
            ["Back"] = "#E9ECEF", ["Surface"] = "#FFFFFF", ["Border"] = "#D5DAE0", ["BorderStrong"] = "#B9C1CB",
            ["Text"] = "#1F2933", ["Heading"] = "#111820", ["Muted"] = "#5F6B7A", ["Disabled"] = "#A3ACB8",
            ["Hover"] = "#EDF1F5", ["Pressed"] = "#DEE5EC", ["Input"] = "#FFFFFF", ["InputBorder"] = "#B9C1CB",
            ["Accent"] = "#0696D7", ["AccentHover"] = "#0784BD", ["AccentText"] = "#FFFFFF", ["ErrorText"] = "#B42318",
            ["TitleBar"] = "#FFFFFF", ["TitleText"] = "#1F2933", ["ButtonBack"] = "#FFFFFF",
        };

        static ResourceDictionary Styles()
        {
            if (_styles != null) return _styles;
            using (var s = typeof(Theme).Assembly.GetManifestResourceStream("DynALisp.Windows.Theme.xaml"))
                _styles = (ResourceDictionary)WpfXamlReader.Load(s);
            return _styles;
        }

        // The Dyl.* brushes of a theme:
        public static ResourceDictionary Brushes(bool dark)
        {
            var d = new ResourceDictionary();
            foreach (var kv in dark ? DarkColors : LightColors)
            {
                var b = new SolidColorBrush((Color)ColorConverter.ConvertFromString(kv.Value));
                b.Freeze();
                d["Dyl." + kv.Key] = b;
            }
            // The hatches of the sketches (Dyl.Sketch.* of Theme.xaml): lines of the muted
            // ink, at 45 and -45 degrees, as the sketches of the docs:
            var ink = (Color)ColorConverter.ConvertFromString((dark ? DarkColors : LightColors)["Muted"]);
            d["Dyl.HatchA"] = Hatch(ink, 45);
            d["Dyl.HatchB"] = Hatch(ink, -45);
            return d;
        }

        static Brush Hatch(Color ink, double angle)
        {
            var pen = new Pen(new SolidColorBrush(ink), 0.8);
            var tile = new Rect(0, 0, 7, 7);
            var b = new DrawingBrush(new GeometryDrawing(null, pen, new LineGeometry(new Point(3.5, -1), new Point(3.5, 8))))
            {
                TileMode = TileMode.Tile,
                Viewport = tile, ViewportUnits = BrushMappingMode.Absolute,
                Viewbox = tile, ViewboxUnits = BrushMappingMode.Absolute,
                Transform = new RotateTransform(angle),
            };
            b.Freeze();
            return b;
        }

        public static void Apply(Window w, bool dark)
        {
            w.Resources.MergedDictionaries.Insert(0, Styles());
            w.Resources.MergedDictionaries.Insert(0, Brushes(dark));
            w.SetResourceReference(Control.BackgroundProperty, "Dyl.Back");
            w.SetResourceReference(Control.ForegroundProperty, "Dyl.Text");
            w.FontFamily = new FontFamily("Segoe UI");
            w.FontSize = 12.5;
            TextOptions.SetTextFormattingMode(w, TextFormattingMode.Display);
            w.UseLayoutRounding = true;
            w.SnapsToDevicePixels = true;
            if (w.ReadLocalValue(Window.SizeToContentProperty) == DependencyProperty.UnsetValue) w.SizeToContent = SizeToContent.WidthAndHeight;
            if (w.ReadLocalValue(Window.ResizeModeProperty) == DependencyProperty.UnsetValue) w.ResizeMode = ResizeMode.NoResize;
            w.ShowInTaskbar = false;
            w.WindowStartupLocation = WindowStartupLocation.CenterOwner;
            if (dark) w.SourceInitialized += (a, b) => DarkTitleBar(w);
        }

        [DllImport("dwmapi.dll")]
        static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        // The dark title bar of Windows 10 (20H1) and 11; nothing in an older Windows:
        static void DarkTitleBar(Window w)
        {
            try
            {
                var hwnd = new WindowInteropHelper(w).Handle;
                int on = 1;
                if (DwmSetWindowAttribute(hwnd, 20, ref on, sizeof(int)) != 0)
                    DwmSetWindowAttribute(hwnd, 19, ref on, sizeof(int));
            }
            catch { }
        }
    }

    // A window open on the values of its session:
    public sealed class View
    {
        readonly Session _s;
        readonly string _dir;
        readonly List<FrameworkElement> _all = new List<FrameworkElement>();
        bool _filling, _closed;

        public readonly Window Window;
        public int Status { get; private set; }

        // The preset editor of a preset window (its list named "lst", the rows pst/rows):
        internal PresetEditor Presets;
        // The list of rows edited in the window (a ListBox with Win.Rows, Rows.cs):
        internal RowsEditor Rows;
        internal Session Session => _s;

        internal View(Session s, Window w, string dir)
        {
            _s = s;
            _dir = dir;
            Window = w;
            Collect(w);
            foreach (var fe in _all) Wire(fe);
            w.Closed += (a, b) => _closed = true;
        }

        // Every element of the window (its logical tree: what the file holds):
        void Collect(DependencyObject o)
        {
            if (o is FrameworkElement fe) _all.Add(fe);
            foreach (var c in LogicalTreeHelper.GetChildren(o))
                if (c is DependencyObject d) Collect(d);
        }

        static bool Named(FrameworkElement fe) => !string.IsNullOrEmpty(fe.Name);

        void Wire(FrameworkElement fe)
        {
            switch (fe)
            {
                case ToggleButton t when Named(t):
                    t.Checked += (a, b) => Changed(t.Name, "1", t);
                    t.Unchecked += (a, b) => Changed(t.Name, "0", t);
                    break;
                case ComboBox c when Named(c):
                    c.SelectionChanged += (a, b) => Changed(c.Name, c.SelectedIndex.ToString(CultureInfo.InvariantCulture), c);
                    break;
                case ListBox l when Named(l):
                    l.SelectionChanged += (a, b) => Changed(l.Name, l.SelectedIndex.ToString(CultureInfo.InvariantCulture), l);
                    break;
                case TextBox x when Named(x):
                    x.TextChanged += (a, b) => Changed(x.Name, x.Text, x);
                    break;
                case Button b:
                    b.Click += (a, e) => Click(b);
                    break;
                case Gallery g when Named(g):
                    g.Selected += (i, m) => { _s.Values[g.Name + ".method"] = m; Changed(g.Name, i.ToString(CultureInfo.InvariantCulture), g); };
                    g.Picked += (i, m) => { _s.Values[g.Name + ".method"] = m; Pick(g, i); };
                    break;
            }
        }

        // A tile of a gallery double-clicked: its index, then the window closes (status 1, or
        // the Win.Close of the gallery):
        void Pick(Gallery g, int index)
        {
            _s.Values[g.Name] = index.ToString(CultureInfo.InvariantCulture);
            int status = 1;
            string close = Win.GetClose(g);
            if (close != null) int.TryParse(close, NumberStyles.Integer, CultureInfo.InvariantCulture, out status);
            Status = status;
            if (!_closed) Window.Close();
        }

        void Changed(string key, string value, FrameworkElement from)
        {
            if (_filling) return;
            _s.Values[key] = value;
            Presets?.Changed(key);
            Rows?.Changed(key);
            // A checkbox turned on turns off the ones it excludes (one answer at most):
            string ex = Win.GetExcludes(from);
            if (value == "1" && !string.IsNullOrEmpty(ex))
            {
                foreach (var k in Keys(ex))
                {
                    _s.Values[k] = "0";
                    if (Find(k) is ToggleButton t) { _filling = true; t.IsChecked = false; _filling = false; }
                }
            }
            Refresh();
        }

        internal FrameworkElement Find(string key) => _all.FirstOrDefault(e => e.Name == key);

        // Opens the window file beside this one over it, on the values (see Session.ShowSub):
        internal int OpenSub(string file) => _s.ShowSub(Path.Combine(_dir, file), Window);

        // Sets controls without their change being taken as the user's:
        internal void Quiet(Action a)
        {
            bool was = _filling;
            _filling = true;
            try { a(); }
            finally { _filling = was; }
        }

        static IEnumerable<string> Keys(string list) =>
            list.Split(',').Select(k => k.Trim()).Where(k => k.Length > 0);

        // The controls from the values (a control without a value gives its own to the values,
        // so the Lisp gets every key back), then the rules:
        public void Fill()
        {
            if (Presets == null && _s.Rows.ContainsKey(PresetEditor.RowsKey) && Find("lst") is ListBox)
                Presets = new PresetEditor(this);
            if (Rows == null && _all.FirstOrDefault(RowsEditor.Is) is ListBox rl)
                Rows = new RowsEditor(this, rl, _all);
            _filling = true;
            try
            {
                foreach (var fe in _all.Where(Named))
                {
                    // the controls of the presets, filled by the editor:
                    if (Presets != null && Presets.Owns(fe.Name)) continue;
                    if (Rows != null && Rows.Owns(fe.Name)) continue;
                    bool has = _s.Values.TryGetValue(fe.Name, out string v);
                    switch (fe)
                    {
                        case ToggleButton t:
                            if (has) t.IsChecked = v == "1";
                            else _s.Values[t.Name] = t.IsChecked == true ? "1" : "0";
                            break;
                        case Selector c:
                            if (_s.Lists.TryGetValue(c.Name, out var items)) c.ItemsSource = items;
                            if (has && int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i))
                                c.SelectedIndex = i >= 0 && i < c.Items.Count ? i : -1;
                            else if (!has) _s.Values[c.Name] = c.SelectedIndex.ToString(CultureInfo.InvariantCulture);
                            break;
                        case TextBox x:
                            if (has) x.Text = v ?? "";
                            else _s.Values[x.Name] = x.Text;
                            break;
                        case TextBlock tb:
                            if (has) tb.Text = v ?? "";
                            break;
                        case Gallery g:
                            g.Attach(Find, k => _s.Lists.TryGetValue(k, out var l) ? l : null);
                            // A tile selected when it opens (a sample), else none:
                            int.TryParse(has ? v : "-1", NumberStyles.Integer, CultureInfo.InvariantCulture, out int gi);
                            _s.Values[g.Name] = "-1";
                            _s.Values[g.Name + ".method"] = "";
                            if (gi >= 0) { g.SelectIndex(gi); _s.Values[g.Name] = gi.ToString(CultureInfo.InvariantCulture); }
                            break;
                    }
                }
            }
            finally { _filling = false; }
            Presets?.Fill();
            Rows?.Fill();
            Refresh();
        }

        // Enabled and shown from the values (Win.EnabledBy, Win.VisibleBy, Session.Off):
        public void Refresh()
        {
            foreach (var fe in _all)
            {
                bool off = Named(fe) && _s.Off.Contains(fe.Name);
                string eb = Win.GetEnabledBy(fe);
                if (fe is Button b && b.Name == "docs") fe.IsEnabled = Docs() != null;
                else if (off || eb != null) fe.IsEnabled = !off && Holds(eb);
                string vb = Win.GetVisibleBy(fe);
                if (vb != null) fe.Visibility = Holds(vb) ? Visibility.Visible : Visibility.Collapsed;
            }
            Presets?.Refresh();
            Rows?.Refresh();
        }

        // A rule of the values (Win.EnabledBy, Win.VisibleBy):
        internal bool Holds(string rule) => Holds(rule, Stored);

        // The value of a key as a rule reads it: "1" / "0" for a checkbox, the text of a text
        // box, the value stored for the item picked in a list that has its values (key/vals,
        // given by the Lisp: the values of the items of key/list), else its index:
        internal string Stored(string key)
        {
            if (!_s.Values.TryGetValue(key, out string v)) return null;
            if (_s.Lists.TryGetValue(key + "/vals", out var vals))
                return int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i) && i >= 0 && i < vals.Count ? vals[i] : null;
            return v;
        }

        // "rea,!lkk": every key on ("1"), or off with !; "mth=Linear|Offset|": the value of the
        // key is one of these (here also "", nothing), "mth!=Origin": none of them; the parts
        // divided by "," must all hold, the rules divided by ";" are alternatives (one is
        // enough). The value of a key is given by get:
        internal static bool Holds(string rule, Func<string, string> get)
        {
            if (string.IsNullOrWhiteSpace(rule)) return true;
            foreach (var alt in rule.Split(';'))
                if (alt.Trim().Length > 0 && All(alt, get)) return true;
            return false;
        }

        static bool All(string rule, Func<string, string> get)
        {
            foreach (var k in Keys(rule))
            {
                int ne = k.IndexOf("!=", StringComparison.Ordinal), eq = k.IndexOf('=');
                if (ne > 0 || eq > 0)
                {
                    bool not = ne > 0;
                    string key = k.Substring(0, not ? ne : eq).Trim();
                    var set = k.Substring(not ? ne + 2 : eq + 1).Split('|').Select(x => x.Trim());
                    bool @in = set.Contains(get(key) ?? "", StringComparer.OrdinalIgnoreCase);
                    if (@in == not) return false;
                }
                else
                {
                    bool not = k.StartsWith("!");
                    bool on = get(not ? k.Substring(1) : k) == "1";
                    if (on == not) return false;
                }
            }
            return true;
        }

        string Docs()
        {
            _s.Values.TryGetValue(Session.DocsKey(Win.GetDocs(Window)), out string t);
            return string.IsNullOrEmpty(t) ? null : t;
        }

        void Click(Button b)
        {
            if (b.Name == "docs") { try { Session.OpenTarget(Docs()); } catch (Exception e) { Error("Unable to open the docs: " + e.Message); } return; }
            if (Presets != null && Presets.Click(b)) { Refresh(); return; }
            if (Rows != null && Rows.Click(b)) { Refresh(); return; }
            string all = Win.GetSetAll(b);
            if (all != null)
            {
                foreach (var t in _all.OfType<ToggleButton>().Where(Named).Where(t => t.IsEnabled)) t.IsChecked = all == "1";
                return;
            }
            string open = Win.GetOpen(b);
            if (open != null)
            {
                _s.ShowSub(Path.Combine(_dir, open), Window);
                Fill();
                return;
            }
            string close = Win.GetClose(b);
            int status;
            if (close != null) int.TryParse(close, NumberStyles.Integer, CultureInfo.InvariantCulture, out status);
            else if (b.IsDefault) status = 1;
            else if (b.IsCancel) status = 0;
            else return;
            CloseWith(status);
        }

        // Closes the window with status (its values checked first, unless it is 0, Cancel):
        internal void CloseWith(int status)
        {
            if (status != 0 && !Checks()) return;
            Status = status;
            // a Cancel button has closed it already (IsCancel):
            if (!_closed) Window.Close();
        }

        // The text boxes checked (Win.Check) before the window closes:
        bool Checks()
        {
            if (Presets != null) return Presets.Check() && (Rows == null || Rows.Check());
            if (Rows != null && !Rows.Check()) return false;
            foreach (var x in _all.OfType<TextBox>())
            {
                if (Rows != null && Rows.Owns(x.Name)) continue;
                string kind = Win.GetCheck(x);
                if (kind == null || !x.IsEnabled || Valid(kind, x.Text)) continue;
                Error(Win.GetCheckMessage(x) ?? "This value is not valid.");
                x.Focus();
                x.SelectAll();
                return false;
            }
            Error("");
            return true;
        }

        // A value checked by Win.Check: its kinds divided by ";", all of them true (number,
        // positive, integer, min=0, max=90, text: not empty, plain: without ; , or ",
        // widths: numbers greater than 0 divided by commas, color: an AutoCAD color 1-255 or
        // r,g,b), or empty when one of them is "empty" ("empty;integer;min=3": nothing, or a
        // whole number of 3 or more):
        internal static bool Valid(string kind, string text)
        {
            text = (text ?? "").Trim();
            var kinds = (kind ?? "").Split(';').Select(k => k.Trim()).Where(k => k.Length > 0).ToList();
            if (text.Length == 0 && kinds.Contains("empty")) return true;
            foreach (var k in kinds)
            {
                double d;
                bool num = double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out d);
                switch (k)
                {
                    case "empty": break;
                    case "text": if (text.Length == 0) return false; break;
                    case "plain": if (text.IndexOfAny(new[] { ';', ',', '"' }) >= 0) return false; break;
                    case "integer": if (!int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out _)) return false; break;
                    case "number": if (!num) return false; break;
                    case "positive": if (!num || d <= 0) return false; break;
                    case "widths":
                        foreach (var w in text.Split(','))
                            if (!double.TryParse(w.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out double x) || x <= 0) return false;
                        break;
                    case "color": if (!Color(text)) return false; break;
                    default:
                        if (k.StartsWith("min=") || k.StartsWith("max="))
                        {
                            if (!num || !double.TryParse(k.Substring(4), NumberStyles.Float, CultureInfo.InvariantCulture, out double lim)) return false;
                            if (k[1] == 'i' ? d < lim : d > lim) return false;
                        }
                        break;
                }
            }
            return true;
        }

        // An AutoCAD color: 1 to 255, or r,g,b (0 to 255 each), as Remote>>Dyl:MaterialColorParse:
        static bool Color(string text)
        {
            var f = text.Split(',');
            if (f.Length != 1 && f.Length != 3) return false;
            foreach (var x in f)
            {
                string t = x.Trim();
                if (t.Length == 0 || t.Length > 3 || !t.All(char.IsDigit)) return false;
                int n = int.Parse(t, CultureInfo.InvariantCulture);
                if (n > 255 || (f.Length == 1 && n < 1)) return false;
            }
            return true;
        }

        // The message in the text named "error", or a message box when the window has none:
        internal void Error(string msg)
        {
            if (Find("error") is TextBlock tb) { tb.Text = msg; tb.Visibility = msg == "" ? Visibility.Collapsed : Visibility.Visible; }
            else if (msg != "") MessageBox.Show(Window, msg, Window.Title, MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }
}
