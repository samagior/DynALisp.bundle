// Start.cs - DynALisp.Windows: the recent drawings of the Start page, and a window shown as a page
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
// <dyl:RecentDrawings x:Name="rec" Search="find" Count="cnt"/>: a tile for each row of its
// table (rec/rows), the drawings opened last first, its fields:
//   path, name, folder, when (the text of its date), thumbnail (a .png file, "" none: a sheet
//   is drawn in its place), missing ("1": the file is not found, its tile greyed out)
// The tiles shown are filtered in the page itself as the box Search is typed (every word in
// the name or the folder, accents and case ignored), Count says how many are shown (its Tag:
// "drawing,drawings"). A tile clicked raises Opened (its path, false), its right-click menu
// opens it read-only (Opened, true) or shows it in its folder (Folder). Nothing here knows
// AutoCAD: StartPage.cs of the plugin opens them, the pictures tool of the docs (Shots\)
// draws the page on sample rows.
//
// Page.Of(window) takes the content of a window file to show it as a page (the Start page,
// inside the Start tab of AutoCAD), with the resources and the text settings of the window.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

namespace DynALisp.Windows
{
    public class RecentDrawings : ContentControl
    {
        public static readonly DependencyProperty SearchProperty = DependencyProperty.Register("Search", typeof(string), typeof(RecentDrawings));
        public static readonly DependencyProperty CountProperty = DependencyProperty.Register("Count", typeof(string), typeof(RecentDrawings));
        public static readonly DependencyProperty TileWidthProperty = DependencyProperty.Register("TileWidth", typeof(double), typeof(RecentDrawings), new PropertyMetadata(196.0));

        public string Search { get => (string)GetValue(SearchProperty); set => SetValue(SearchProperty, value); }
        public string Count { get => (string)GetValue(CountProperty); set => SetValue(CountProperty, value); }
        public double TileWidth { get => (double)GetValue(TileWidthProperty); set => SetValue(TileWidthProperty, value); }

        // A drawing to open (its path, read-only), a drawing to show in its folder:
        public event Action<string, bool> Opened;
        public event Action<string> Folder;

        public const string RowsSuffix = "/rows";

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
            Content = new ScrollViewer
            {
                Content = stack,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
                Focusable = false,
                Padding = new Thickness(0, 0, 4, 0),
            };
        }

        // The tiles of the rows (null: none yet, read), and the controls that filter them
        // (find: a control of the window by its name):
        internal void Attach(Func<string, FrameworkElement> find, List<string[]> rows)
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
                    string F(int k) => r.Length > k ? r[k] ?? "" : "";
                    var it = new Item { Path = F(0), Hay = View.Fold(F(1) + "\n" + F(2)) };
                    it.Tile = Tile(it, F(1), F(2), F(3), F(4), F(5) == "1");
                    _items.Add(it);
                    _panel.Children.Add(it.Tile);
                }
            }
            Filter();
        }

        static bool Same(List<string[]> a, List<string[]> b) =>
            a.Count == b.Count && a.Zip(b, (x, y) => x.SequenceEqual(y)).All(t => t);

        void OnSearch(object sender, TextChangedEventArgs e) => Filter();

        void Filter()
        {
            var words = View.Fold(_search?.Text ?? "").Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            int shown = 0;
            foreach (var it in _items)
            {
                bool on = words.All(w => it.Hay.IndexOf(w, StringComparison.Ordinal) >= 0);
                it.Tile.Visibility = on ? Visibility.Visible : Visibility.Collapsed;
                if (on) shown++;
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
            var pic = new Border { Height = Math.Round((w - 16) * 0.66), CornerRadius = new CornerRadius(4), ClipToBounds = true };
            pic.SetResourceReference(Border.BackgroundProperty, "Dyl.Input");
            var img = Thumb(thumb);
            pic.Child = img != null
                ? (UIElement)new Image { Source = img, Stretch = Stretch.Uniform, Margin = new Thickness(2) }
                : Sheet();
            var title = new TextBlock { Text = name, FontWeight = FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 7, 0, 0) };
            var where = new TextBlock { Text = folder, FontSize = 11.5, TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 1, 0, 0) };
            where.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            var date = new TextBlock { Text = missing ? "Not found" : when, FontSize = 11.5, Margin = new Thickness(0, 1, 0, 0) };
            date.SetResourceReference(TextBlock.ForegroundProperty, missing ? "Dyl.ErrorText" : "Dyl.Muted");
            var stack = new StackPanel();
            stack.Children.Add(pic);
            stack.Children.Add(title);
            stack.Children.Add(where);
            stack.Children.Add(date);
            var b = new Button { Content = stack, Width = w, ToolTip = it.Path, Opacity = missing ? 0.55 : 1 };
            b.SetResourceReference(StyleProperty, "Dyl.Tile");
            b.Click += (s, e) => Opened?.Invoke(it.Path, false);
            var menu = new ContextMenu();
            menu.Items.Add(MenuOf("Open", () => Opened?.Invoke(it.Path, false), !missing));
            menu.Items.Add(MenuOf("Open read-only", () => Opened?.Invoke(it.Path, true), !missing));
            menu.Items.Add(MenuOf("Show in folder", () => Folder?.Invoke(it.Path), true));
            b.ContextMenu = menu;
            return b;
        }

        static MenuItem MenuOf(string text, Action run, bool on)
        {
            var m = new MenuItem { Header = text, IsEnabled = on };
            m.Click += (s, e) => run();
            return m;
        }

        // The picture of a .png file (read at once, the file left free), null when it cannot:
        static ImageSource Thumb(string file)
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

        // A drawing without a picture: a sheet with its corner folded, in the muted ink:
        static UIElement Sheet()
        {
            var p = new Path
            {
                Data = Geometry.Parse("M 0,0 L 22,0 L 30,8 L 30,38 L 0,38 Z M 22,0 L 22,8 L 30,8"),
                StrokeThickness = 1.4,
                StrokeLineJoin = PenLineJoin.Round,
                Width = 32, Height = 40,
                Stretch = Stretch.None,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
            };
            p.SetResourceReference(Shape.StrokeProperty, "Dyl.Muted");
            return p;
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
