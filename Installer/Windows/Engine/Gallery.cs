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
// <dyl:Gallery x:Name="gal" Group="grp" Pills="pills" Recent="Recent" Kinds="kinds"
//              Methods="mths" Search="find" Count="cnt"/>:
// its items are the list of its key (gal/list), one a tile, its fields divided by tabs:
//   name, group, spec (see HatchTile), rank (optional: 1 for the item used last, 2 the one
//   before...), kind (a pill of Kinds), methods (the values of the methods it can be drawn
//   with, divided by commas, "" for Ask when drawn), default (its method)
// The tiles shown are filtered in the window itself, with no call to the Lisp:
//   Group   the ComboBox of the groups (its first item, All: every group), the value the Lisp
//           gets back; it may be hidden (Visibility="Collapsed") when the pills show it
//   Pills   a Panel the gallery fills with a pill (Dyl.Pill) for each group of that ComboBox
//           that has tiles, All first: a pill picked picks its group
//   Recent  the group of the ComboBox that shows the items with a rank, the last used first
//           (its pill only when there are some)
//   Kinds   a Panel the gallery fills with a pill for All and each kind of its list <key>/kinds
//           (given as "gal/kinds/list"); it filters the tiles with the group
//   Search  the TextBox of the text typed (in the name or the group, any case)
//   Count   the TextBlock saying how many are shown (its Tag: "preset,presets")
// A tile clicked is selected: the key gets its index ("-1": none), and the Panel named by
// Methods a pill for each method of the tile (the list <key>/methods, given as
// "gal/methods/list": "value<TAB>label<TAB>tooltip", in their order), its default method picked; the method picked is the value of the key
// "<key>.method". A tile double-clicked closes the window with its index and its method: the
// status 1, or the Win.Close of the gallery.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;

namespace DynALisp.Windows
{
    public class Gallery : ContentControl
    {
        public static readonly DependencyProperty GroupProperty = DependencyProperty.Register("Group", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty PillsProperty = DependencyProperty.Register("Pills", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty RecentProperty = DependencyProperty.Register("Recent", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty KindsProperty = DependencyProperty.Register("Kinds", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty MethodsProperty = DependencyProperty.Register("Methods", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty SearchProperty = DependencyProperty.Register("Search", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty CountProperty = DependencyProperty.Register("Count", typeof(string), typeof(Gallery));
        public static readonly DependencyProperty TileWidthProperty = DependencyProperty.Register("TileWidth", typeof(double), typeof(Gallery), new PropertyMetadata(150.0));

        public string Group { get => (string)GetValue(GroupProperty); set => SetValue(GroupProperty, value); }
        public string Pills { get => (string)GetValue(PillsProperty); set => SetValue(PillsProperty, value); }
        public string Recent { get => (string)GetValue(RecentProperty); set => SetValue(RecentProperty, value); }
        public string Kinds { get => (string)GetValue(KindsProperty); set => SetValue(KindsProperty, value); }
        public string Methods { get => (string)GetValue(MethodsProperty); set => SetValue(MethodsProperty, value); }
        public string Search { get => (string)GetValue(SearchProperty); set => SetValue(SearchProperty, value); }
        public string Count { get => (string)GetValue(CountProperty); set => SetValue(CountProperty, value); }
        public double TileWidth { get => (double)GetValue(TileWidthProperty); set => SetValue(TileWidthProperty, value); }

        // A tile selected (its index, -1 none) or its method picked (its value):
        public event Action<int, string> Selected;
        // A tile double-clicked: its index and its method:
        public event Action<int, string> Picked;

        sealed class Item
        {
            public Button Tile;
            public string Name, Group, Kind, Default;
            public string[] Methods;
            public int Index, Rank;
        }

        static readonly StringComparison Ic = StringComparison.CurrentCultureIgnoreCase;
        readonly WrapPanel _panel = new WrapPanel();
        readonly List<Item> _items = new List<Item>();
        readonly List<RadioButton> _pills = new List<RadioButton>(), _kinds = new List<RadioButton>();
        List<string[]> _methods = new List<string[]>();
        ComboBox _group;
        TextBox _search;
        TextBlock _count;
        Panel _mths;
        bool _recent;
        string _kind;
        Item _sel;
        string _method = "";

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

        // The tiles of the items, and the controls that filter them (find: a control of the
        // window by its name; list: a list given by the Lisp, by its key):
        internal void Attach(Func<string, FrameworkElement> find, Func<string, IList<string>> list)
        {
            var items = list(Name);
            _panel.Children.Clear();
            _items.Clear();
            _sel = null;
            _method = "";
            for (int i = 0; i < (items?.Count ?? 0); i++)
            {
                var f = (items[i] ?? "").Split('\t');
                string F(int k) => f.Length > k ? f[k] : "";
                int.TryParse(F(3), NumberStyles.Integer, CultureInfo.InvariantCulture, out int rank);
                var it = new Item
                {
                    Name = F(0), Group = F(1), Index = i, Rank = rank > 0 ? rank : 0, Kind = F(4),
                    Methods = f.Length > 5 ? f[5].Split(',') : new string[0], Default = F(6),
                };
                it.Tile = Tile(it, F(2));
                _items.Add(it);
                _panel.Children.Add(it.Tile);
            }
            _methods = (list(Name + "/methods") ?? new List<string>()).Select(m => (m ?? "").Split('\t')).ToList();
            if (_group != null) _group.SelectionChanged -= OnFilter;
            if (_search != null) _search.TextChanged -= OnFilter;
            _group = find(Group ?? "") as ComboBox;
            _search = find(Search ?? "") as TextBox;
            _count = find(Count ?? "") as TextBlock;
            _mths = find(Methods ?? "") as Panel;
            if (_group != null) _group.SelectionChanged += OnFilter;
            if (_search != null) _search.TextChanged += OnFilter;
            MakePills(find(Pills ?? "") as Panel);
            MakeKinds(find(Kinds ?? "") as Panel, list(Name + "/kinds"));
            ShowMethods();
            Filter();
        }

        RadioButton Pill(string text, string group, Action picked, string tip = null)
        {
            var p = new RadioButton { Content = text, GroupName = group, ToolTip = string.IsNullOrEmpty(tip) ? null : tip };
            p.SetResourceReference(StyleProperty, "Dyl.Pill");
            p.Checked += (s, e) => picked();
            return p;
        }

        string Gname(string what) => what + GetHashCode().ToString(CultureInfo.InvariantCulture);

        // A pill for All, for each group with tiles, and for the recent items when there are
        // some, in the order of the ComboBox (the groups of the Preset Groups window):
        void MakePills(Panel host)
        {
            _pills.Clear();
            if (host == null || _group == null) return;
            host.Children.Clear();
            for (int i = 0; i < _group.Items.Count; i++)
            {
                string g = _group.Items[i] as string ?? "";
                bool has = i == 0
                           || (IsRecent(g) ? _items.Any(x => x.Rank > 0) : _items.Any(x => string.Equals(x.Group, g, Ic)));
                if (!has) continue;
                int idx = i;
                var p = Pill(g, Gname("pills"), () => { if (_group.SelectedIndex != idx) _group.SelectedIndex = idx; });
                p.Tag = idx;
                _pills.Add(p);
                host.Children.Add(p);
            }
        }

        // A pill for All and for each kind, in the order of its list (each one, even without a
        // tile, so the kinds read the same in every group):
        void MakeKinds(Panel host, IList<string> kinds)
        {
            _kinds.Clear();
            _kind = null;
            if (host == null) return;
            host.Children.Clear();
            var all = new List<string> { null };
            all.AddRange(kinds ?? new List<string>());
            if (all.Count < 2) return;
            foreach (var k in all)
            {
                string kind = k;
                var p = Pill(k ?? "All", Gname("kinds"), () => { _kind = kind; Filter(); });
                p.Tag = kind;
                _kinds.Add(p);
                host.Children.Add(p);
            }
            _kinds[0].IsChecked = true;
        }

        bool IsRecent(string g) => !string.IsNullOrEmpty(Recent) && string.Equals(g, Recent, Ic);

        Button Tile(Item it, string spec)
        {
            var hatch = new HatchTile { Spec = spec, Height = 74, Radius = 5 };
            hatch.SetResourceReference(HatchTile.InkProperty, "Dyl.Text");
            hatch.SetResourceReference(HatchTile.FillProperty, "Dyl.Input");
            hatch.SetResourceReference(HatchTile.LabelBackProperty, "Dyl.Surface");
            var title = new TextBlock { Text = it.Name, Margin = new Thickness(2, 7, 0, 0), TextTrimming = TextTrimming.CharacterEllipsis };
            var sub = new TextBlock { Text = it.Group, Margin = new Thickness(2, 1, 0, 0), FontSize = 11, TextTrimming = TextTrimming.CharacterEllipsis };
            sub.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            var stack = new StackPanel();
            stack.Children.Add(hatch);
            stack.Children.Add(title);
            stack.Children.Add(sub);
            var b = new Button { Content = stack, Width = TileWidth, ToolTip = it.Name };
            b.SetResourceReference(StyleProperty, "Dyl.Tile");
            b.Click += (s, e) => Select(it);
            b.MouseDoubleClick += (s, e) => { if (e.ChangedButton == MouseButton.Left) { Select(it); Picked?.Invoke(it.Index, _method); } };
            return b;
        }

        // The tile of the item i selected (as the Lisp gives it, a sample: -1 none):
        internal void SelectIndex(int i) => Select(i >= 0 && i < _items.Count ? _items[i] : null);

        // The tile selected (null: none), its default method picked:
        void Select(Item it)
        {
            if (it == _sel) return;
            if (_sel != null) _sel.Tile.Tag = null;
            _sel = it;
            if (_sel != null) _sel.Tile.Tag = "sel";
            _method = _sel == null ? "" : _sel.Methods.Contains(_sel.Default) ? _sel.Default : _sel.Methods.FirstOrDefault() ?? "";
            ShowMethods();
            Selected?.Invoke(_sel?.Index ?? -1, _method);
        }

        // The pills of the methods of the tile selected, its method picked:
        void ShowMethods()
        {
            if (_mths == null) return;
            _mths.Children.Clear();
            if (_sel == null) return;
            foreach (var m in _methods.Where(m => _sel.Methods.Contains(m[0])))
            {
                string val = m[0];
                var p = Pill(m.Length > 1 ? m[1] : val, Gname("mths"), () =>
                {
                    if (_method == val) return;
                    _method = val;
                    Selected?.Invoke(_sel?.Index ?? -1, _method);
                }, m.Length > 2 ? m[2] : null);
                p.IsChecked = val == _method;
                _mths.Children.Add(p);
            }
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
                            && (_kind == null || string.Equals(_kind, t.Kind, Ic))
                            && (text.Length == 0 || t.Name.IndexOf(text, Ic) >= 0 || t.Group.IndexOf(text, Ic) >= 0);
                t.Tile.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
                if (show) n++;
            }
            // A tile hidden is no longer selected:
            if (_sel != null && _sel.Tile.Visibility != Visibility.Visible) Select(null);
            // "preset,presets": the Tag of the count, the word for one and for several:
            if (_count != null)
            {
                var words = ((_count.Tag as string) ?? "item,items").Split(',');
                _count.Text = n.ToString(CultureInfo.CurrentCulture) + " " + (n == 1 ? words[0] : words[words.Length - 1]).Trim();
            }
        }
    }
}
