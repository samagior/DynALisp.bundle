// Start.cs - DynALisp.Windows: the controls of the Start page, and a window shown as a page
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
// Three controls, each filled from a table of the values (key/rows, null: not read yet, the
// rows are being read). Nothing here knows AutoCAD: StartPage.cs of the plugin gives the rows
// and does what they ask (open a drawing, pin it), the pictures tool of the docs (Shots\) draws
// the page on sample rows.
//
// <dyl:PinnedItems x:Name="pin" Graph="act"/>: the cards of what is pinned, the fields of a row:
//   path, name, kind ("Drawing", "Sheet set" or "Project"), where (its folder), time (the text
//   of its active time), thumbnail (a .png file, "" none), missing ("1": not found)
// A drawing clicked raises Opened; a sheet set or a project clicked shows only its active time
// in the graph Graph (clicked again: all of it). Its right-click menu: Open (a drawing, a sheet
// set), Show its active time, Show in folder (Folder), Unpin (Unpinned).
//
// <dyl:ActivityGraph x:Name="act"/>: the active time of each day, as a grid of the weeks of
// the year (a square a day, darker for more time), the rows: date (yyyy-MM-dd), seconds,
// drawing. The last 12 months, or a year picked at its right; a day clicked lists the drawings
// worked on that day under it (a month clicked over the grid: that month), the most recent
// month with time until then; a drawing of that list clicked raises Opened.
//
// <dyl:RecentDrawings x:Name="rec" Search="find" Count="cnt" Max="12"/>: a tile for each
// drawing opened last, the fields of a row:
//   path, name, folder, when (the text of its date), thumbnail (a .png file, "" none: a sheet
//   is drawn in its place), missing ("1": the file is not found, its tile greyed out)
// The tiles shown are filtered as the box Search is typed (every word in the name or the
// folder, accents and case ignored), Count says how many are shown (its Tag:
// "drawing,drawings"), Max shows only the first ones. A tile clicked raises Opened (its path,
// false), its right-click menu opens it read-only (Opened, true), shows it in its folder
// (Folder) or pins it, its sheet set or its project (PinChoices, Pin).
//
// Page.Of(window) takes the content of a window file to show it as a page (the Start page,
// inside the Start tab of AutoCAD), with the resources and the text settings of the window.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

namespace DynALisp.Windows
{
    // A control filled from the table key/rows of the values (View.Fill):
    public interface IShowsRows
    {
        void Attach(Func<string, FrameworkElement> find, List<string[]> rows);
    }

    static class StartUi
    {
        public const string RowsSuffix = "/rows";

        public static string F(string[] r, int k) => r.Length > k ? r[k] ?? "" : "";

        public static TextBlock Text(string text, string brush = null, double size = 0, bool bold = false)
        {
            var t = new TextBlock { Text = text ?? "", TextTrimming = TextTrimming.CharacterEllipsis };
            if (brush != null) t.SetResourceReference(TextBlock.ForegroundProperty, brush);
            if (size > 0) t.FontSize = size;
            if (bold) t.FontWeight = FontWeights.SemiBold;
            return t;
        }

        public static MenuItem MenuOf(string text, Action run, bool on = true)
        {
            var m = new MenuItem { Header = text, IsEnabled = on };
            m.Click += (s, e) => run();
            return m;
        }

        // A text that acts as a link (Accent, underlined under the mouse):
        public static TextBlock Link(string text, Action run, string brush = "Dyl.Accent")
        {
            var t = Text(text, brush);
            t.Cursor = Cursors.Hand;
            t.MouseEnter += (s, e) => t.TextDecorations = TextDecorations.Underline;
            t.MouseLeave += (s, e) => t.TextDecorations = null;
            t.MouseLeftButtonUp += (s, e) => { e.Handled = true; run(); };
            return t;
        }

        // The picture of a .png file (read at once, the file left free), null when it cannot:
        public static ImageSource Thumb(string file)
        {
            if (string.IsNullOrEmpty(file) || !System.IO.File.Exists(file)) return null;
            try
            {
                var bi = new BitmapImage();
                bi.BeginInit();
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
                bi.UriSource = new Uri(System.IO.Path.GetFullPath(file));
                bi.EndInit();
                bi.Freeze();
                return bi;
            }
            catch { return null; }
        }

        // A drawing without a picture: a sheet with its corner folded, in the muted ink; a sheet
        // set: three sheets; a project: a folder.
        public static UIElement Glyph(string kind, double scale = 1)
        {
            string data = kind == "Sheet set"
                ? "M 6,0 L 30,0 L 30,30 M 3,3 L 27,3 L 27,33 M 0,6 L 18,6 L 24,12 L 24,38 L 0,38 Z"
                : kind == "Project"
                ? "M 0,6 L 0,34 L 38,34 L 38,10 L 17,10 L 13,4 L 2,4 Z M 0,14 L 38,14"
                : "M 0,0 L 22,0 L 30,8 L 30,38 L 0,38 Z M 22,0 L 22,8 L 30,8";
            var p = new Path
            {
                Data = Geometry.Parse(data),
                StrokeThickness = 1.4,
                StrokeLineJoin = PenLineJoin.Round,
                Width = 40 * scale, Height = 40 * scale,
                Stretch = Stretch.Uniform,
                Margin = new Thickness(6 * scale),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
            };
            p.SetResourceReference(Shape.StrokeProperty, "Dyl.Muted");
            return p;
        }

        // "3 h 05", "12 min", "< 1 min":
        public static string Dur(double seconds)
        {
            long m = (long)Math.Round(seconds / 60);
            if (m < 1) return seconds > 0 ? "< 1 min" : "0 min";
            if (m < 60) return m + " min";
            return (m / 60) + " h " + (m % 60).ToString("00", CultureInfo.InvariantCulture);
        }

        // The name of a drawing and its folder:
        public static string Name(string path)
        {
            try { return System.IO.Path.GetFileNameWithoutExtension(path); } catch { return path; }
        }

        public static string Dir(string path)
        {
            try { return System.IO.Path.GetDirectoryName(path) ?? ""; } catch { return ""; }
        }
    }

    // ---- the recent drawings ----

    public class RecentDrawings : ContentControl, IShowsRows
    {
        public static readonly DependencyProperty SearchProperty = DependencyProperty.Register("Search", typeof(string), typeof(RecentDrawings));
        public static readonly DependencyProperty CountProperty = DependencyProperty.Register("Count", typeof(string), typeof(RecentDrawings));
        public static readonly DependencyProperty TileWidthProperty = DependencyProperty.Register("TileWidth", typeof(double), typeof(RecentDrawings), new PropertyMetadata(196.0));
        public static readonly DependencyProperty MaxProperty = DependencyProperty.Register("Max", typeof(int), typeof(RecentDrawings), new PropertyMetadata(0));

        public string Search { get => (string)GetValue(SearchProperty); set => SetValue(SearchProperty, value); }
        public string Count { get => (string)GetValue(CountProperty); set => SetValue(CountProperty, value); }
        public double TileWidth { get => (double)GetValue(TileWidthProperty); set => SetValue(TileWidthProperty, value); }
        public int Max { get => (int)GetValue(MaxProperty); set => SetValue(MaxProperty, value); }

        // A drawing to open (its path, read-only), a drawing to show in its folder, a path to
        // pin or unpin (Pin: its path, true to pin):
        public event Action<string, bool> Opened;
        public event Action<string> Folder;
        public event Action<string, bool> Pin;
        // What a drawing can pin (the label of its menu item, the path, pinned already), given
        // by the plugin; none: the drawing itself only.
        public Func<string, List<(string Label, string Path, bool Pinned)>> PinChoices;

        public const string RowsSuffix = StartUi.RowsSuffix;

        sealed class Item
        {
            public Button Tile;
            public string Path, Hay;
        }

        readonly WrapPanel _panel = new WrapPanel();
        readonly TextBlock _empty = new TextBlock { Margin = new Thickness(2, 4, 0, 0), TextWrapping = TextWrapping.Wrap, Visibility = Visibility.Collapsed };
        readonly List<Item> _items = new List<Item>();
        // The rows shown, to draw the tiles again only when they changed:
        List<string[]> _rows;
        TextBox _search;
        TextBlock _count;

        public RecentDrawings()
        {
            Focusable = false;
            _empty.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            var stack = new StackPanel();
            stack.Children.Add(_empty);
            stack.Children.Add(_panel);
            Content = stack;
        }

        // The tiles of the rows (null: none yet, read), and the controls that filter them
        // (find: a control of the window by its name):
        public void Attach(Func<string, FrameworkElement> find, List<string[]> rows)
        {
            if (_search != null) _search.TextChanged -= OnSearch;
            _search = find(Search ?? "") as TextBox;
            _count = find(Count ?? "") as TextBlock;
            if (_search != null) _search.TextChanged += OnSearch;
            if (rows == null)
            {
                _rows = null;
                _items.Clear();
                _panel.Children.Clear();
                _empty.Text = "Reading the recent drawings...";
                _empty.Visibility = Visibility.Visible;
                if (_count != null) _count.Text = "";
                return;
            }
            if (_rows == null || !Same(_rows, rows))
            {
                _rows = rows.Select(r => (string[])r.Clone()).ToList();
                _items.Clear();
                _panel.Children.Clear();
                foreach (var r in rows)
                {
                    var it = new Item { Path = StartUi.F(r, 0), Hay = View.Fold(StartUi.F(r, 1) + "\n" + StartUi.F(r, 2)) };
                    it.Tile = Tile(it, StartUi.F(r, 1), StartUi.F(r, 2), StartUi.F(r, 3), StartUi.F(r, 4), StartUi.F(r, 5) == "1");
                    _items.Add(it);
                    _panel.Children.Add(it.Tile);
                }
            }
            Filter();
        }

        internal static bool Same(List<string[]> a, List<string[]> b) =>
            a.Count == b.Count && a.Zip(b, (x, y) => x.SequenceEqual(y)).All(t => t);

        void OnSearch(object sender, TextChangedEventArgs e) => Filter();

        void Filter()
        {
            var words = View.Fold(_search?.Text ?? "").Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            int shown = 0, max = Max > 0 ? Max : int.MaxValue;
            foreach (var it in _items)
            {
                bool on = words.All(w => it.Hay.IndexOf(w, StringComparison.Ordinal) >= 0);
                if (on) shown++;
                it.Tile.Visibility = on && shown <= max ? Visibility.Visible : Visibility.Collapsed;
            }
            _empty.Text = _items.Count == 0 ? "No recent drawing." : "No drawing has this name.";
            _empty.Visibility = shown == 0 ? Visibility.Visible : Visibility.Collapsed;
            if (_count != null)
            {
                var forms = (_count.Tag as string ?? "drawing,drawings").Split(',');
                string word = shown == 1 || forms.Length < 2 ? forms[0] : forms[1];
                _count.Text = shown == _items.Count
                    ? shown.ToString(CultureInfo.InvariantCulture) + " " + word
                    : shown.ToString(CultureInfo.InvariantCulture) + " of " + _items.Count.ToString(CultureInfo.InvariantCulture) + " " + (forms.Length > 1 ? forms[1] : word);
            }
        }

        Button Tile(Item it, string name, string folder, string when, string thumb, bool missing)
        {
            double w = TileWidth;
            var pic = new Border { Height = Math.Round((w - 16) * 0.62), CornerRadius = new CornerRadius(4), ClipToBounds = true };
            pic.SetResourceReference(Border.BackgroundProperty, "Dyl.Input");
            var img = StartUi.Thumb(thumb);
            pic.Child = img != null
                ? (UIElement)new Image { Source = img, Stretch = Stretch.Uniform, Margin = new Thickness(2) }
                : StartUi.Glyph("Drawing", 0.8);
            var title = StartUi.Text(name, null, 0, true);
            title.Margin = new Thickness(0, 6, 0, 0);
            var where = StartUi.Text(folder, "Dyl.Muted", 11.5);
            var date = StartUi.Text(missing ? "Not found" : when, missing ? "Dyl.ErrorText" : "Dyl.Muted", 11.5);
            var stack = new StackPanel();
            stack.Children.Add(pic);
            stack.Children.Add(title);
            stack.Children.Add(where);
            stack.Children.Add(date);
            var b = new Button { Content = stack, Width = w, ToolTip = it.Path, Opacity = missing ? 0.55 : 1 };
            b.SetResourceReference(StyleProperty, "Dyl.Tile");
            b.Click += (s, e) => Opened?.Invoke(it.Path, false);
            var menu = new ContextMenu();
            b.ContextMenu = menu;
            // its items made as it opens (what is pinned changes):
            b.ContextMenuOpening += (s, e) =>
            {
                menu.Items.Clear();
                menu.Items.Add(StartUi.MenuOf("Open", () => Opened?.Invoke(it.Path, false), !missing));
                menu.Items.Add(StartUi.MenuOf("Open read-only", () => Opened?.Invoke(it.Path, true), !missing));
                menu.Items.Add(StartUi.MenuOf("Show in folder", () => Folder?.Invoke(it.Path)));
                var pins = PinChoices?.Invoke(it.Path) ?? new List<(string, string, bool)> { ("Pin", it.Path, false) };
                if (pins.Count > 0) menu.Items.Add(new Separator());
                foreach (var p in pins)
                {
                    var (label, path, on) = p;
                    menu.Items.Add(StartUi.MenuOf(on ? "Un" + char.ToLowerInvariant(label[0]) + label.Substring(1) : label, () => Pin?.Invoke(path, !on)));
                }
            };
            return b;
        }
    }

    // ---- the pins ----

    public class PinnedItems : ContentControl, IShowsRows
    {
        public static readonly DependencyProperty GraphProperty = DependencyProperty.Register("Graph", typeof(string), typeof(PinnedItems));
        public static readonly DependencyProperty CardWidthProperty = DependencyProperty.Register("CardWidth", typeof(double), typeof(PinnedItems), new PropertyMetadata(336.0));
        public string Graph { get => (string)GetValue(GraphProperty); set => SetValue(GraphProperty, value); }
        public double CardWidth { get => (double)GetValue(CardWidthProperty); set => SetValue(CardWidthProperty, value); }

        public event Action<string, bool> Opened;
        public event Action<string> Folder;
        public event Action<string> Unpinned;

        readonly WrapPanel _panel = new WrapPanel();
        readonly TextBlock _empty = new TextBlock { Margin = new Thickness(2, 0, 0, 10), TextWrapping = TextWrapping.Wrap };
        readonly List<(Button Card, string Path)> _cards = new List<(Button, string)>();
        List<string[]> _rows;
        ActivityGraph _graph;

        public PinnedItems()
        {
            Focusable = false;
            _empty.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            var stack = new StackPanel();
            stack.Children.Add(_empty);
            stack.Children.Add(_panel);
            Content = stack;
        }

        public void Attach(Func<string, FrameworkElement> find, List<string[]> rows)
        {
            var g = find(Graph ?? "") as ActivityGraph;
            if (g != _graph)
            {
                if (_graph != null) _graph.Scopes -= Mark;
                _graph = g;
                if (_graph != null) _graph.Scopes += Mark;
            }
            if (rows == null) { _empty.Text = ""; return; }
            if (_rows != null && RecentDrawings.Same(_rows, rows)) return;
            _rows = rows.Select(r => (string[])r.Clone()).ToList();
            _panel.Children.Clear();
            _cards.Clear();
            _empty.Text = rows.Count == 0 ? "Nothing pinned: right-click a recent drawing to pin it, its sheet set or its project, or Pin..." : "";
            _empty.Visibility = rows.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
            foreach (var r in rows)
            {
                var c = Card(StartUi.F(r, 0), StartUi.F(r, 1), StartUi.F(r, 2), StartUi.F(r, 3), StartUi.F(r, 4), StartUi.F(r, 5), StartUi.F(r, 6) == "1");
                _cards.Add((c, StartUi.F(r, 0)));
                _panel.Children.Add(c);
            }
            Mark();
        }

        // The card of the scope of the graph marked:
        void Mark()
        {
            foreach (var (card, path) in _cards)
                card.Tag = _graph != null && string.Equals(_graph.ScopePath, path, StringComparison.OrdinalIgnoreCase) ? "sel" : null;
        }

        void Scope(string path, string name, string kind)
        {
            if (_graph == null) return;
            if (string.Equals(_graph.ScopePath, path, StringComparison.OrdinalIgnoreCase)) _graph.SetScope(null, null, false);
            else _graph.SetScope(path, name, kind != "Drawing");
            Mark();
        }

        Button Card(string path, string name, string kind, string where, string time, string thumb, bool missing)
        {
            var pic = new Border { Width = 58, Height = 44, CornerRadius = new CornerRadius(4), ClipToBounds = true, Margin = new Thickness(0, 0, 10, 0), VerticalAlignment = VerticalAlignment.Top };
            pic.SetResourceReference(Border.BackgroundProperty, "Dyl.Input");
            var img = StartUi.Thumb(thumb);
            pic.Child = img != null ? (UIElement)new Image { Source = img, Stretch = Stretch.Uniform, Margin = new Thickness(1) } : StartUi.Glyph(kind, 0.62);
            var title = StartUi.Text(name, "Dyl.Accent", 13, true);
            var badge = new Border { BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(9), Padding = new Thickness(7, 0, 7, 1), Margin = new Thickness(8, 1, 0, 0), VerticalAlignment = VerticalAlignment.Center };
            badge.SetResourceReference(Border.BorderBrushProperty, "Dyl.BorderStrong");
            badge.Child = StartUi.Text(kind, "Dyl.Muted", 11);
            var top = new DockPanel { LastChildFill = true };
            DockPanel.SetDock(badge, Dock.Right);
            top.Children.Add(badge);
            top.Children.Add(title);
            var lines = new StackPanel();
            lines.Children.Add(top);
            var w = StartUi.Text(where, "Dyl.Muted", 11.5);
            w.Margin = new Thickness(0, 2, 0, 0);
            lines.Children.Add(w);
            var t = StartUi.Text(missing ? "Not found" : time, missing ? "Dyl.ErrorText" : "Dyl.Text", 11.5);
            t.Margin = new Thickness(0, 5, 0, 0);
            lines.Children.Add(t);
            var dock = new DockPanel();
            DockPanel.SetDock(pic, Dock.Left);
            dock.Children.Add(pic);
            dock.Children.Add(lines);
            var b = new Button { Content = dock, Width = CardWidth, ToolTip = path, Opacity = missing ? 0.55 : 1, Padding = new Thickness(12, 10, 12, 10) };
            b.SetResourceReference(StyleProperty, "Dyl.Tile");
            b.Click += (s, e) =>
            {
                if (kind == "Drawing") Opened?.Invoke(path, false);
                else Scope(path, name, kind);
            };
            var menu = new ContextMenu();
            if (kind != "Project") menu.Items.Add(StartUi.MenuOf("Open", () => Opened?.Invoke(path, false), !missing));
            menu.Items.Add(StartUi.MenuOf("Show its active time", () => Scope(path, name, kind), _graph != null));
            menu.Items.Add(StartUi.MenuOf("Show in folder", () => Folder?.Invoke(path)));
            menu.Items.Add(new Separator());
            menu.Items.Add(StartUi.MenuOf("Unpin", () => Unpinned?.Invoke(path)));
            b.ContextMenu = menu;
            return b;
        }
    }

    // ---- the active time ----

    public class ActivityGraph : ContentControl, IShowsRows
    {
        const double Cell = 11, Pitch = 14, Left = 30, Top = 18;
        static readonly double[] Levels = { 1, 3600, 3 * 3600, 6 * 3600 };       // the seconds of a level 1 to 4
        static readonly double[] Opacities = { 0.32, 0.55, 0.78, 1.0 };

        public event Action<string, bool> Opened;

        struct Row { public DateTime Day; public long Seconds; public string Path; }

        readonly TextBlock _total = StartUi.Text("", "Dyl.Heading", 14.5);
        readonly TextBlock _all;
        readonly Canvas _grid = new Canvas();
        readonly StackPanel _years = new StackPanel { Margin = new Thickness(16, 0, 0, 0), MinWidth = 96 };
        readonly TextBlock _period = StartUi.Text("", "Dyl.Heading", 13, true);
        readonly TextBlock _summary = StartUi.Text("", "Dyl.Muted", 12);
        readonly StackPanel _list = new StackPanel { Margin = new Thickness(0, 6, 0, 0) };
        readonly StackPanel _details = new StackPanel { Margin = new Thickness(0, 14, 0, 0) };
        List<Row> _rows = new List<Row>();
        List<string[]> _raw;
        int _year;                                // 0: the last 12 months
        DateTime? _day;                           // the day picked, or the first of the month picked
        bool _month;
        string _scope, _scopeName;
        bool _scopeFolder;

        public string ScopePath => _scope;

        public ActivityGraph()
        {
            Focusable = false;
            _all = StartUi.Link("Show all", () => { SetScope(null, null, false); Scopes?.Invoke(); });
            _all.Margin = new Thickness(12, 0, 0, 0);
            _all.VerticalAlignment = VerticalAlignment.Bottom;
            var head = new DockPanel { Margin = new Thickness(0, 0, 0, 8) };
            DockPanel.SetDock(_all, Dock.Right);
            head.Children.Add(_all);
            head.Children.Add(_total);

            var legend = new DockPanel { Margin = new Thickness(Left, 6, 0, 0) };
            var scale = new StackPanel { Orientation = Orientation.Horizontal };
            scale.Children.Add(Small("Less", new Thickness(0, 0, 5, 0)));
            for (int l = 0; l <= 4; l++) scale.Children.Add(Square(l, new Thickness(0, 0, 3, 0)));
            scale.Children.Add(Small("More", new Thickness(2, 0, 0, 0)));
            DockPanel.SetDock(scale, Dock.Right);
            legend.Children.Add(scale);
            legend.Children.Add(Small("Time spent working in a drawing, each day.", new Thickness(0)));

            var inner = new StackPanel();
            inner.Children.Add(_grid);
            inner.Children.Add(legend);
            var card = new Border { BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(6), Padding = new Thickness(12, 10, 14, 10), HorizontalAlignment = HorizontalAlignment.Left };
            card.SetResourceReference(Border.BorderBrushProperty, "Dyl.Border");
            card.SetResourceReference(Border.BackgroundProperty, "Dyl.Surface");
            card.Child = inner;

            var row = new DockPanel { LastChildFill = false };
            DockPanel.SetDock(_years, Dock.Right);
            var left = new StackPanel();
            left.Children.Add(head);
            left.Children.Add(card);
            _details.Children.Add(_period);
            _details.Children.Add(_summary);
            _details.Children.Add(_list);
            left.Children.Add(_details);
            row.Children.Add(left);
            row.Children.Add(_years);
            DockPanel.SetDock(left, Dock.Left);
            Content = row;
            Draw();
        }

        // The scope changed here (Show all): the pins mark their card again.
        public event Action Scopes;

        public void Attach(Func<string, FrameworkElement> find, List<string[]> rows)
        {
            if (rows == null || (_raw != null && RecentDrawings.Same(_raw, rows))) return;
            _raw = rows.Select(r => (string[])r.Clone()).ToList();
            _rows = new List<Row>();
            foreach (var r in rows)
            {
                if (!DateTime.TryParseExact(StartUi.F(r, 0), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)) continue;
                if (!long.TryParse(StartUi.F(r, 1), NumberStyles.Integer, CultureInfo.InvariantCulture, out long s) || s <= 0) continue;
                _rows.Add(new Row { Day = d, Seconds = s, Path = StartUi.F(r, 2) });
            }
            Draw();
        }

        // Only the time of a drawing, or of the drawings of a folder (a sheet set, a project:
        // the folder of its file and every folder under it); null: all of it.
        public void SetScope(string path, string name, bool folder)
        {
            _scope = path;
            _scopeName = name;
            _scopeFolder = folder;
            Draw();
        }

        bool InScope(string p)
        {
            if (_scope == null) return true;
            if (!_scopeFolder) return string.Equals(p, _scope, StringComparison.OrdinalIgnoreCase);
            string dir = StartUi.Dir(_scope).TrimEnd('\\', '/') + "\\";
            return p.StartsWith(dir, StringComparison.OrdinalIgnoreCase);
        }

        (DateTime From, DateTime To) Range()
        {
            var today = DateTime.Today;
            if (_year == 0) return (today.AddDays(-364), today);
            return (new DateTime(_year, 1, 1), new DateTime(_year, 12, 31) < today ? new DateTime(_year, 12, 31) : today);
        }

        void Draw()
        {
            var (from, to) = Range();
            var rows = _rows.Where(r => InScope(r.Path)).ToList();
            var days = rows.Where(r => r.Day >= from && r.Day <= to).GroupBy(r => r.Day).ToDictionary(g => g.Key, g => (double)g.Sum(r => r.Seconds));
            double total = days.Values.Sum();
            string when = _year == 0 ? "in the last year" : "in " + _year.ToString(CultureInfo.InvariantCulture);
            _total.Text = (total > 0 ? StartUi.Dur(total) + " of active time " : "No active time ") + when + (_scope != null ? " in " + _scopeName : "");
            _all.Visibility = _scope != null ? Visibility.Visible : Visibility.Collapsed;
            DrawGrid(from, to, days);
            DrawYears();
            DrawDetails(rows, from, to);
        }

        void DrawGrid(DateTime from, DateTime to, Dictionary<DateTime, double> days)
        {
            _grid.Children.Clear();
            // the columns: the weeks, Sunday first; the end of the year shown whole (a year past)
            DateTime end = _year == 0 ? to : new DateTime(_year, 12, 31);
            DateTime start = from.AddDays(-(int)from.DayOfWeek);
            int weeks = (int)((end - start).TotalDays / 7) + 1;
            _grid.Width = Left + weeks * Pitch;
            _grid.Height = Top + 7 * Pitch;
            string[] wd = { "", "Mon", "", "Wed", "", "Fri", "" };
            for (int i = 0; i < 7; i++)
                if (wd[i].Length > 0) Place(Small(wd[i], new Thickness(0)), 0, Top + i * Pitch - 2);
            double lastLabel = -100;
            for (int w = 0; w < weeks; w++)
                for (int i = 0; i < 7; i++)
                {
                    var d = start.AddDays(w * 7 + i);
                    double x = Left + w * Pitch, y = Top + i * Pitch;
                    if (d.Day == 1 && d >= from && d <= end && x - lastLabel >= 3 * Pitch)
                    {
                        var month = new DateTime(d.Year, d.Month, 1);
                        var lbl = StartUi.Link(d.ToString("MMM", CultureInfo.InvariantCulture), () => Pick(month, true), "Dyl.Muted");
                        lbl.FontSize = 11;
                        Place(lbl, x, 0);
                        lastLabel = x;
                    }
                    if (d < from || d > end) continue;
                    if (d > to) continue;
                    days.TryGetValue(d, out double s);
                    var sq = Square(Level(s), new Thickness(0));
                    sq.ToolTip = (s > 0 ? StartUi.Dur(s) + " on " : "No active time on ") + d.ToString("dddd, MMMM d, yyyy", CultureInfo.InvariantCulture);
                    sq.Cursor = Cursors.Hand;
                    var day = d;
                    sq.MouseLeftButtonUp += (a, b) => Pick(day, false);
                    if (_day == d && !_month) { sq.StrokeThickness = 1.2; sq.SetResourceReference(Shape.StrokeProperty, "Dyl.Text"); }
                    Place(sq, x, y);
                }
        }

        void Place(UIElement e, double x, double y)
        {
            Canvas.SetLeft(e, x);
            Canvas.SetTop(e, y);
            _grid.Children.Add(e);
        }

        static int Level(double s)
        {
            int l = 0;
            while (l < Levels.Length && s >= Levels[l]) l++;
            return l;
        }

        static Rectangle Square(int level, Thickness margin)
        {
            var r = new Rectangle { Width = Cell, Height = Cell, RadiusX = 2, RadiusY = 2, Margin = margin, VerticalAlignment = VerticalAlignment.Center };
            if (level == 0) r.SetResourceReference(Shape.FillProperty, "Dyl.Hover");
            else { r.SetResourceReference(Shape.FillProperty, "Dyl.Accent"); r.Opacity = Opacities[level - 1]; }
            return r;
        }

        static TextBlock Small(string text, Thickness margin)
        {
            var t = StartUi.Text(text, "Dyl.Muted", 11);
            t.Margin = margin;
            t.VerticalAlignment = VerticalAlignment.Center;
            return t;
        }

        void Pick(DateTime day, bool month)
        {
            if (_day == day && _month == month) _day = null;
            else { _day = day; _month = month; }
            Draw();
        }

        void DrawYears()
        {
            _years.Children.Clear();
            var years = _rows.Select(r => r.Day.Year).Distinct().OrderByDescending(y => y).ToList();
            if (years.Count == 0) return;
            _years.Children.Add(Year("Last year", 0));
            foreach (var y in years) _years.Children.Add(Year(y.ToString(CultureInfo.InvariantCulture), y));
        }

        RadioButton Year(string text, int year)
        {
            var b = new RadioButton { Content = text, IsChecked = _year == year, Margin = new Thickness(0, 0, 0, 6), Padding = new Thickness(14, 5, 14, 5), GroupName = "years" + GetHashCode() };
            b.SetResourceReference(StyleProperty, "Dyl.Pill");
            b.Checked += (s, e) => { if (_year != year) { _year = year; _day = null; Dispatcher.BeginInvoke(new Action(Draw)); } };
            return b;
        }

        // The drawings of the day or the month picked, else of the last month with time:
        void DrawDetails(List<Row> rows, DateTime from, DateTime to)
        {
            _list.Children.Clear();
            DateTime a, b;
            if (_day is DateTime d)
            {
                a = d;
                b = _month ? d.AddMonths(1).AddDays(-1) : d;
                _period.Text = _month ? d.ToString("MMMM yyyy", CultureInfo.InvariantCulture) : d.ToString("dddd, MMMM d, yyyy", CultureInfo.InvariantCulture);
            }
            else
            {
                var last = rows.Where(r => r.Day >= from && r.Day <= to).Select(r => r.Day).DefaultIfEmpty(DateTime.MinValue).Max();
                if (last == DateTime.MinValue) { _details.Visibility = Visibility.Collapsed; return; }
                a = new DateTime(last.Year, last.Month, 1);
                b = a.AddMonths(1).AddDays(-1);
                _period.Text = a.ToString("MMMM yyyy", CultureInfo.InvariantCulture);
            }
            _details.Visibility = Visibility.Visible;
            var by = rows.Where(r => r.Day >= a && r.Day <= b).GroupBy(r => r.Path, StringComparer.OrdinalIgnoreCase)
                         .Select(g => (Path: g.Key, Seconds: (double)g.Sum(r => r.Seconds), Days: g.Select(r => r.Day).Distinct().Count()))
                         .OrderByDescending(x => x.Seconds).ToList();
            double total = by.Sum(x => x.Seconds);
            _summary.Text = by.Count == 0
                ? "No active time."
                : StartUi.Dur(total) + " in " + by.Count + (by.Count == 1 ? " drawing" : " drawings");
            double most = by.Count > 0 ? by[0].Seconds : 1;
            foreach (var x in by.Take(8))
            {
                var line = new DockPanel { Margin = new Thickness(0, 4, 0, 0) };
                var bar = new Border { Width = 90, Height = 6, CornerRadius = new CornerRadius(3), Margin = new Thickness(12, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
                bar.SetResourceReference(Border.BackgroundProperty, "Dyl.Hover");
                var fill = new Border { Width = Math.Max(4, 90 * x.Seconds / most), HorizontalAlignment = HorizontalAlignment.Left, CornerRadius = new CornerRadius(3) };
                fill.SetResourceReference(Border.BackgroundProperty, "Dyl.Accent");
                bar.Child = fill;
                var time = StartUi.Text(StartUi.Dur(x.Seconds) + (_month || _day == null ? (x.Days > 1 ? ", " + x.Days + " days" : ", 1 day") : ""), "Dyl.Muted", 12);
                time.Width = 120;
                time.TextAlignment = TextAlignment.Right;
                DockPanel.SetDock(bar, Dock.Right);
                DockPanel.SetDock(time, Dock.Right);
                line.Children.Add(bar);
                line.Children.Add(time);
                var path = x.Path;
                var name = StartUi.Link(StartUi.Name(path), () => Opened?.Invoke(path, false));
                name.ToolTip = path;
                var folder = StartUi.Text("  " + StartUi.Dir(path), "Dyl.Muted", 11.5);
                folder.VerticalAlignment = VerticalAlignment.Center;
                var names = new DockPanel();
                DockPanel.SetDock(name, Dock.Left);
                names.Children.Add(name);
                names.Children.Add(folder);
                line.Children.Add(names);
                _list.Children.Add(line);
            }
            if (by.Count > 8) _list.Children.Add(Small("... and " + (by.Count - 8) + " more", new Thickness(0, 4, 0, 0)));
            _list.MaxWidth = Math.Max(_grid.Width + 28, 560);
        }
    }

    public static class Page
    {
        // The content of the window w, out of it, in a border that takes its resources (its
        // theme), its font and its background: what a window file shows as a page.
        public static Border Of(Window w)
        {
            var content = (UIElement)w.Content;
            w.Content = null;
            var page = new Border { Child = content, UseLayoutRounding = true, SnapsToDevicePixels = true };
            page.Resources = w.Resources;
            TextElement.SetFontFamily(page, w.FontFamily);
            TextElement.SetFontSize(page, w.FontSize);
            TextOptions.SetTextFormattingMode(page, TextFormattingMode.Display);
            page.SetResourceReference(Border.BackgroundProperty, "Dyl.Back");
            page.SetResourceReference(TextElement.ForegroundProperty, "Dyl.Text");
            // the size the file gives the page for its picture: the page takes the room it has
            if (content is FrameworkElement fe)
            {
                fe.Width = double.NaN;
                fe.Height = double.NaN;
            }
            return page;
        }
    }
}
