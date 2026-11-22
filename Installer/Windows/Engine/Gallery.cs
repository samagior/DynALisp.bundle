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
// <dyl:Gallery x:Name="gal" Group="grp" Pills="pills" Recent="Recent" Search="find" Count="cnt"/>:
// its items are the list of its key (gal/list), one a tile: "name<TAB>group<TAB>spec<TAB>rank"
// (spec: see HatchTile; rank, optional: 1 for the item used last, 2 the one before...). The
// tiles shown are filtered in the window itself, with no call to the Lisp:
//   Group   the ComboBox of the groups (its first item, All: every group), the value the Lisp
//           gets back; it may be hidden (Visibility="Collapsed") when the pills show it
//   Pills   a Panel the gallery fills with a pill (Dyl.Pill) for each group of that ComboBox
//           that has tiles, All first: a pill picked picks its group
//   Recent  the group of the ComboBox that shows the items with a rank, the last used first
//           (its pill only when there are some)
//   Search  the TextBox of the text typed (in the name or the group, any case)
//   Count   the TextBlock saying how many are shown (its Tag: "preset,presets")
// A tile clicked closes the window: the value of the key is the index of its item in the
// list, the status 1, or the Win.Close of the gallery.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;

namespace DynALisp.Windows
{
    public class Gallery : ContentControl
    {
        public static readonly DependencyProperty GroupProperty = DependencyProperty.Register("Group", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty PillsProperty = DependencyProperty.Register("Pills", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty RecentProperty = DependencyProperty.Register("Recent", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty SearchProperty = DependencyProperty.Register("Search", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty CountProperty = DependencyProperty.Register("Count", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty TileWidthProperty = DependencyProperty.Register("TileWidth", typeof(double), typeof(Gallery), new PropertyMetadata(150.0));

        public string Group { get => (string)GetValue(GroupProperty); set => SetValue(GroupProperty, value); }
        public string Pills { get => (string)GetValue(PillsProperty); set => SetValue(PillsProperty, value); }
        public string Recent { get => (string)GetValue(RecentProperty); set => SetValue(RecentProperty, value); }
        public string Search { get => (string)GetValue(SearchProperty); set => SetValue(SearchProperty, value); }
        public string Count { get => (string)GetValue(CountProperty); set => SetValue(CountProperty, value); }
        public double TileWidth { get => (double)GetValue(TileWidthProperty); set => SetValue(TileWidthProperty, value); }

        // A tile clicked: the index of its item:
        public event Action<int> Picked;

        sealed class Item
        {
            public FrameworkElement Tile;
            public string Name, Group;
            public int Index, Rank;
        }

        static readonly StringComparison Ic = StringComparison.CurrentCultureIgnoreCase;
        readonly WrapPanel _panel = new WrapPanel();
        readonly List<Item> _items = new List<Item>();
        readonly List<RadioButton> _pills = new List<RadioButton>();
        ComboBox _group;
        TextBox _search;
        TextBlock _count;
        bool _recent;

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
        internal void Attach(IList<string> items, ComboBox group, Panel pills, TextBox search, TextBlock count)
        {
            _panel.Children.Clear();
            _items.Clear();
            for (int i = 0; i < (items?.Count ?? 0); i++)
            {
                var f = (items[i] ?? "").Split('\t');
                string name = f[0], grp = f.Length > 1 ? f[1] : "", spec = f.Length > 2 ? f[2] : "";
                int.TryParse(f.Length > 3 ? f[3] : "", NumberStyles.Integer, CultureInfo.InvariantCulture, out int rank);
                var it = new Item { Tile = Tile(i, name, grp, spec), Name = name, Group = grp, Index = i, Rank = rank > 0 ? rank : 0 };
                _items.Add(it);
                _panel.Children.Add(it.Tile);
            }
            if (_group != null) _group.SelectionChanged -= OnFilter;
            if (_search != null) _search.TextChanged -= OnFilter;
            _group = group;
            _search = search;
            _count = count;
            if (_group != null) _group.SelectionChanged += OnFilter;
            if (_search != null) _search.TextChanged += OnFilter;
            MakePills(pills);
            Filter();
        }

        // A pill for All, for each group with tiles, and for the recent items when there are
        // some, in the order of the ComboBox (the groups of the Preset Groups window):
        void MakePills(Panel host)
        {
            _pills.Clear();
            if (host == null || _group == null) return;
            host.Children.Clear();
            string name = "pills" + GetHashCode().ToString(CultureInfo.InvariantCulture);
            for (int i = 0; i < _group.Items.Count; i++)
            {
                string g = _group.Items[i] as string ?? "";
                bool has = i == 0
                           || (IsRecent(g) ? _items.Any(x => x.Rank > 0) : _items.Any(x => string.Equals(x.Group, g, Ic)));
                if (!has) continue;
                int idx = i;
                var p = new RadioButton { Content = g, GroupName = name, Tag = idx };
                p.SetResourceReference(StyleProperty, "Dyl.Pill");
                p.Checked += (s, e) => { if (_group.SelectedIndex != idx) _group.SelectedIndex = idx; };
                _pills.Add(p);
                host.Children.Add(p);
            }
        }

        bool IsRecent(string g) => !string.IsNullOrEmpty(Recent) && string.Equals(g, Recent, Ic);

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
            int sel = _group?.SelectedIndex ?? -1;
            string grp = sel > 0 ? _group.SelectedItem as string : null;
            bool recent = grp != null && IsRecent(grp);
            foreach (var p in _pills) p.IsChecked = (int)p.Tag == Math.Max(sel, 0);
            // The recent items, the last used first; else the order of the list:
            if (recent != _recent)
            {
                _recent = recent;
                _panel.Children.Clear();
                foreach (var it in recent ? _items.Where(x => x.Rank > 0).OrderBy(x => x.Rank).Concat(_items.Where(x => x.Rank == 0)) : _items)
                    _panel.Children.Add(it.Tile);
            }
            string text = (_search?.Text ?? "").Trim();
            int n = 0;
            foreach (var t in _items)
            {
                bool show = (grp == null || (recent ? t.Rank > 0 : string.Equals(grp, t.Group, Ic)))
                            && (text.Length == 0 || t.Name.IndexOf(text, Ic) >= 0 || t.Group.IndexOf(text, Ic) >= 0);
                t.Tile.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
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
