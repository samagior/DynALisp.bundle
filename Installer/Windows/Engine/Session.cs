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
            return d;
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
            }
        }

        void Changed(string key, string value, FrameworkElement from)
        {
            if (_filling) return;
            _s.Values[key] = value;
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

        FrameworkElement Find(string key) => _all.FirstOrDefault(e => e.Name == key);

        static IEnumerable<string> Keys(string list) =>
            list.Split(',').Select(k => k.Trim()).Where(k => k.Length > 0);

        // The controls from the values (a control without a value gives its own to the values,
        // so the Lisp gets every key back), then the rules:
        public void Fill()
        {
            _filling = true;
            try
            {
                foreach (var fe in _all.Where(Named))
                {
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
                    }
                }
            }
            finally { _filling = false; }
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
        }

        // "rea,!lkk": every key on ("1"), or off with !:
        bool Holds(string rule)
        {
            if (string.IsNullOrWhiteSpace(rule)) return true;
            foreach (var k in Keys(rule))
            {
                bool not = k.StartsWith("!");
                string key = not ? k.Substring(1) : k;
                bool on = _s.Values.TryGetValue(key, out string v) && v == "1";
                if (on == not) return false;
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
            if (status != 0 && !Checks()) return;
            Status = status;
            // a Cancel button has closed it already (IsCancel):
            if (!_closed) Window.Close();
        }

        // The text boxes checked (Win.Check) before the window closes:
        bool Checks()
        {
            foreach (var x in _all.OfType<TextBox>())
            {
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

        static bool Valid(string kind, string text)
        {
            text = (text ?? "").Trim();
            switch (kind)
            {
                case "integer": return int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out _);
                case "number": return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out _);
                case "positive": return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out double d) && d > 0;
                default: return true;
            }
        }

        // The message in the text named "error", or a message box when the window has none:
        void Error(string msg)
        {
            if (Find("error") is TextBlock tb) { tb.Text = msg; tb.Visibility = msg == "" ? Visibility.Collapsed : Visibility.Visible; }
            else if (msg != "") MessageBox.Show(Window, msg, Window.Title, MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }
}
