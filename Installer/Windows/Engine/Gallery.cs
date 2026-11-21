// Gallery.cs - DynALisp.Windows: a gallery of tiles, each a hatch preview and its name
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
// <dyl:Gallery x:Name="gal" Group="grp" Search="find" Count="cnt"/>: its items are the list
// of its key (gal/list), one a tile: "name<TAB>group<TAB>spec" (spec: see HatchTile). The
// tiles shown are filtered in the window itself, with no call to the Lisp: the group picked
// in the ComboBox named by Group (its first item, All: every group), the text typed in the
// TextBox named by Search (in the name or the group, any case); the TextBlock named by Count
// says how many are shown (its Tag: "preset,presets"). A tile clicked closes the window: the value of the key is the
// index of its item in the list, the status 1, or the Win.Close of the gallery.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace DynALisp.Windows
{
    public class Gallery : ContentControl
    {
        public static readonly DependencyProperty GroupProperty = DependencyProperty.Register("Group", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty SearchProperty = DependencyProperty.Register("Search", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty CountProperty = DependencyProperty.Register("Count", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty TileWidthProperty = DependencyProperty.Register("TileWidth", typeof(double), typeof(Gallery), new PropertyMetadata(150.0));

        public string Group { get => (string)GetValue(GroupProperty); set => SetValue(GroupProperty, value); }
        public string Search { get => (string)GetValue(SearchProperty); set => SetValue(SearchProperty, value); }
        public string Count { get => (string)GetValue(CountProperty); set => SetValue(CountProperty, value); }
        public double TileWidth { get => (double)GetValue(TileWidthProperty); set => SetValue(TileWidthProperty, value); }

        // A tile clicked: the index of its item:
        public event Action<int> Picked;

        readonly WrapPanel _panel = new WrapPanel();
        readonly List<Tuple<FrameworkElement, string, string>> _tiles = new List<Tuple<FrameworkElement, string, string>>();
        ComboBox _group;
        TextBox _search;
        TextBlock _count;

        public Gallery()
        {
            Focusable = false;
            Content = new ScrollViewer
            {
                Content = _panel,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
                Focusable = false,
                Padding = new Thickness(0, 0, 4, 0),
            };
        }

        // The tiles of the items, and the controls that filter them:
        internal void Attach(IList<string> items, ComboBox group, TextBox search, TextBlock count)
        {
            _panel.Children.Clear();
            _tiles.Clear();
            for (int i = 0; i < (items?.Count ?? 0); i++)
            {
                var f = (items[i] ?? "").Split('\t');
                string name = f[0], grp = f.Length > 1 ? f[1] : "", spec = f.Length > 2 ? f[2] : "";
                var tile = Tile(i, name, grp, spec);
                _panel.Children.Add(tile);
                _tiles.Add(Tuple.Create(tile, name, grp));
            }
            if (_group != null) _group.SelectionChanged -= OnFilter;
            if (_search != null) _search.TextChanged -= OnFilter;
            _group = group;
            _search = search;
            _count = count;
            if (_group != null) _group.SelectionChanged += OnFilter;
            if (_search != null) _search.TextChanged += OnFilter;
            Filter();
        }

        FrameworkElement Tile(int index, string name, string grp, string spec)
        {
            var hatch = new HatchTile { Spec = spec, Height = 74, Radius = 5 };
            hatch.SetResourceReference(HatchTile.InkProperty, "Dyl.Text");
            hatch.SetResourceReference(HatchTile.FillProperty, "Dyl.Input");
            hatch.SetResourceReference(HatchTile.LabelBackProperty, "Dyl.Surface");
            var title = new TextBlock { Text = name, Margin = new Thickness(2, 7, 0, 0), TextTrimming = TextTrimming.CharacterEllipsis };
            var sub = new TextBlock { Text = grp, Margin = new Thickness(2, 1, 0, 0), FontSize = 11, TextTrimming = TextTrimming.CharacterEllipsis };
            sub.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            var stack = new StackPanel();
            stack.Children.Add(hatch);
            stack.Children.Add(title);
            stack.Children.Add(sub);
            var b = new Button { Content = stack, Width = TileWidth, ToolTip = name };
            b.SetResourceReference(StyleProperty, "Dyl.Tile");
            b.Click += (s, e) => Picked?.Invoke(index);
            return b;
        }

        void OnFilter(object sender, EventArgs e) => Filter();

        void Filter()
        {
            string grp = _group != null && _group.SelectedIndex > 0 ? _group.SelectedItem as string : null;
            string text = (_search?.Text ?? "").Trim();
            int n = 0;
            foreach (var t in _tiles)
            {
                bool show = (grp == null || string.Equals(grp, t.Item3, StringComparison.CurrentCultureIgnoreCase))
                            && (text.Length == 0
                                || t.Item2.IndexOf(text, StringComparison.CurrentCultureIgnoreCase) >= 0
                                || t.Item3.IndexOf(text, StringComparison.CurrentCultureIgnoreCase) >= 0);
                t.Item1.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
                if (show) n++;
            }
            // "preset,presets": the Tag of the count, the word for one and for several:
            if (_count != null)
            {
                var words = ((_count.Tag as string) ?? "item,items").Split(',');
                _count.Text = n.ToString(CultureInfo.CurrentCulture) + " " + (n == 1 ? words[0] : words[words.Length - 1]).Trim();
            }
        }
    }
}
