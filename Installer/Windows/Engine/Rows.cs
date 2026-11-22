// Rows.cs - DynALisp.Windows: a list of rows edited in its window (the layers of an assembly...)
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
// A window edits a list of rows (the layers of an assembly, the groups of the presets) when a
// ListBox has dyl:Win.Rows="1". The rows are edited in the window, with no call to the Lisp:
// the Lisp gives them, gets them back as edited, and checks them again before it saves them.
// The key k of the list names what the Lisp gives:
//
//   k/rows   the rows, a row of strings each
//   k/new    one row: what the fields show while the list is empty, and the row Add starts
//            from (its columns that are not fields: a row added has the values of the fields)
//   k/defs   the rows of Reset (a button dyl:Win.Do="reset")
//   k.sel    the rows selected when the window opens ("0 3"; none when not given)
//
// and it gets back k/rows as edited and k.sel. The fields are the controls with
// dyl:Win.Column="n": they show the column n of the row shown (the first one selected). A
// field changed gives its value to every row selected that its rules hold for (the
// dyl:Win.EnabledBy of the field and of the panels holding it, read on that row), the other
// values of those rows kept. With none selected the fields keep their values, for Add.
//
//   ComboBox   the value stored for its item (key/vals), else its label
//   TextBox    its text, checked by Win.Check (in every row its rules hold for, on OK)
//   CheckBox   "1" / "0"
//   dyl:Win.Unique="message"   no two rows with the same text in its column (any case): the
//                              message when it is typed, a row added gets " (2)"... It is for
//                              one row only: greyed out while several are selected.
//   dyl:Win.Exclusive="1"      a checkbox on in one row at most: checked, it is cleared in
//                              the other rows (several selected: the first one keeps it).
//   dyl:Win.Follows="lp/widths"  this field takes the item of lp/widths (a list of the Lisp,
//                              one item for each item of the field lp) when lp changes, if
//                              it was empty or the item of its former value.
//   dyl:Win.ListBy="lg"        a list field that lists only its items whose key/by (a list of
//                              the Lisp, one item for each of its items: the group of each
//                              material) is the value of the field lg in the row shown (all
//                              of them when it is empty); lg changed, a row whose item is not
//                              one of them gets the first one (none: empty).
//
// The buttons: dyl:Win.Do="add" (a row of the fields, after the rows selected, selected),
// "remove" (the rows selected), "up" and "down" (one row selected), "flip" (the rows the other
// way) and "reset" (the rows of k/defs). The list shows RowItem: {Binding [n]} the text of
// column n (the label of its item when a field with a list shows it), {Binding V[n]} its value.
//
// dyl:Win.Summary on a TextBlock (its Text) or a GroupBox (its Header) shows the rows:
// {count} how many, {count:rule|one|many} how many a rule holds for, with their noun (a rule
// without "|": lk=L, lk!=L), {sum:n:rule} the total of column n (of the rows the rule holds
// for, all without it), {sel|text} the text, # the number of rows selected, when there are two
// or more; dyl:Win.SummaryEmpty in its place while the list is empty. dyl:Win.Check="rows" on
// the list: at least one row before OK, its dyl:Win.CheckMessage else.
//
// A button with dyl:Win.Open and dyl:Win.Columns="men:7,mex:8" opens that window (beside this
// one) on the row shown (the first one selected): its columns as the values of those keys (a
// list with key/vals: the index of the value), so the window edits them as its own controls;
// its OK gives them to every row selected its rules hold for (as a field), its Cancel keeps
// them. It is greyed out while no row is selected. The other values the window needs (its
// lists) are given by the Lisp with the rows.
//
// In a preset window (Presets.cs), dyl:Win.RowsIn="n" on the list makes its rows those of the
// column n of the preset shown (the layers of an assembly preset): the column holds them, a
// row on each line ("\n"), its columns divided by tabs. They are loaded each time another
// preset is shown (none selected: the fields show k/new), and each change is given back to
// that column, of the preset shown only (the window greys the list out while several presets
// are selected: pst.many). k/rows is then not given.
//
// An AssemblyTile (Assembly.cs) whose Rows is the key of the list draws the rows (the layers
// of an assembly): the editor gives it its Spec each time the rows or the selection change,
// and the value of its Line (the justification of the assembly, a key of the window that is
// not a field) each time it changes.

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;

namespace DynALisp.Windows
{
    // A row of the list, shown by the ItemTemplate of the list:
    public sealed class RowItem : INotifyPropertyChanged
    {
        readonly RowsEditor _ed;
        string[] _v;

        internal RowItem(RowsEditor ed, string[] v)
        {
            _ed = ed;
            _v = v;
        }

        // The values of the row (a new array each time it changes):
        public string[] V
        {
            get => _v;
            internal set
            {
                _v = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs("V"));
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(Binding.IndexerName));
            }
        }

        // The text of column col, as the list shows it:
        public string this[int col] => _ed.Text(_v, col);

        public event PropertyChangedEventHandler PropertyChanged;
    }

    sealed class RowsEditor
    {
        sealed class Field
        {
            public string Key, Unique, Follows, ListBy;
            public bool Exclusive;
            public int Col;
            public FrameworkElement El;
            public List<string> Vals, All, By;   // All: its labels, By: the group of each (ListBy)
            public List<int> Shown;              // the items listed (ListBy), null: all
            public List<string> Rules = new List<string>();
        }

        static readonly StringComparer Ic = StringComparer.OrdinalIgnoreCase;
        static readonly Regex Token = new Regex(@"\{(count|sum|sel)([^}]*)\}");

        readonly View _v;
        readonly Session _s;
        readonly ListBox _list;
        readonly string _k;
        readonly List<string[]> _rows;
        readonly string[] _new;
        readonly List<string[]> _defs;
        readonly List<Field> _fields = new List<Field>();
        readonly List<FrameworkElement> _summaries, _buttons;
        readonly List<Button> _subs;
        readonly List<AssemblyTile> _tiles;
        readonly ObservableCollection<RowItem> _items = new ObservableCollection<RowItem>();
        readonly int _ncols;
        readonly int _in = -1;             // the column of the preset shown holding the rows (RowsIn)
        string _bad;                       // the key of a value not valid (not stored), null else

        // A list of rows of a window: a ListBox with Win.Rows:
        public static bool Is(FrameworkElement fe) => fe is ListBox && !string.IsNullOrEmpty(fe.Name) && Win.GetRows(fe) == "1";

        public RowsEditor(View v, ListBox list, IList<FrameworkElement> all)
        {
            _v = v;
            _s = v.Session;
            _list = list;
            // (set at once: the preset window may load its rows before Fill)
            _list.SelectionMode = SelectionMode.Extended;
            _k = list.Name;
            _rows = _s.Rows.TryGetValue(_k + "/rows", out var r) ? r.Select(x => x.ToArray()).ToList() : new List<string[]>();
            _new = _s.Rows.TryGetValue(_k + "/new", out var n) && n.Count > 0 ? n[0] : null;
            _defs = _s.Rows.TryGetValue(_k + "/defs", out var d) ? d.Select(x => x.ToArray()).ToList() : null;
            foreach (var fe in all)
            {
                string c = Win.GetColumn(fe);
                if (c == null || string.IsNullOrEmpty(fe.Name)) continue;
                if (!int.TryParse(c, NumberStyles.Integer, CultureInfo.InvariantCulture, out int col) || col < 0) continue;
                var f = new Field { Key = fe.Name, Col = col, El = fe, Unique = Win.GetUnique(fe), Follows = Win.GetFollows(fe),
                                    Exclusive = fe is ToggleButton && Win.GetExclusive(fe) == "1", ListBy = Win.GetListBy(fe) };
                f.Vals = _s.Lists.TryGetValue(fe.Name + "/vals", out var vals) ? vals : null;
                if (f.ListBy != null && !_s.Lists.TryGetValue(fe.Name + "/by", out f.By)) f.ListBy = null;
                // Its rules and those of the panels holding it, up to the window:
                for (DependencyObject o = fe; o != null && !(o is Window); o = LogicalTreeHelper.GetParent(o))
                    if (Win.GetEnabledBy(o) is string rule && rule.Trim().Length > 0) f.Rules.Add(rule);
                _fields.Add(f);
            }
            _summaries = all.Where(e => Win.GetSummary(e) != null).ToList();
            _buttons = all.Where(e => e is Button && Win.GetDo(e) != null).ToList();
            _subs = all.OfType<Button>().Where(b => Win.GetOpen(b) != null && Win.GetColumns(b) != null).ToList();
            _tiles = all.OfType<AssemblyTile>().Where(t => t.Rows == _k).ToList();
            if (int.TryParse(Win.GetRowsIn(list) ?? "", NumberStyles.Integer, CultureInfo.InvariantCulture, out int rin) && rin >= 0) _in = rin;
            _ncols = new[] { _new?.Length ?? 0, _fields.Count > 0 ? _fields.Max(f => f.Col) + 1 : 0 }
                .Concat(_rows.Select(x => x.Length)).Concat((_defs ?? new List<string[]>()).Select(x => x.Length)).Max();
            for (int i = 0; i < _rows.Count; i++) _rows[i] = Pad(_rows[i]);
            if (_defs != null) for (int i = 0; i < _defs.Count; i++) _defs[i] = Pad(_defs[i]);
            // given back to the Lisp as they are edited:
            _s.Rows[_k + "/rows"] = _rows;
            _s.OutRows.Add(_k + "/rows");
        }

        // The keys the editor fills itself (not the view):
        public bool Owns(string key) => key == _k || _fields.Any(f => f.Key == key);

        // A button that opens a window on the rows (Win.Open with Win.Columns):
        internal bool HasSub(Button b) => _subs.Contains(b);

        string[] Pad(string[] r)
        {
            if (r.Length >= _ncols) return r;
            var p = new string[_ncols];
            for (int i = 0; i < _ncols; i++) p[i] = i < r.Length ? r[i] ?? "" : "";
            return p;
        }

        static string Cell(string[] r, int col) => r != null && col >= 0 && col < r.Length ? r[col] ?? "" : "";

        string[] Put(string[] r, int col, string val)
        {
            var c = Pad((string[])r.Clone());
            if (col < c.Length) c[col] = val;
            return c;
        }

        // The labels of the list of a field, the index of a value in it:
        static List<string> Labels(Field f) => f.All ?? (f.El as ComboBox)?.ItemsSource as List<string>;

        // The items of the list field f for the row r (ListBy: those of the group of the row):
        List<int> ItemsOf(Field f, string[] r)
        {
            var labels = Labels(f);
            int n = labels?.Count ?? 0;
            var g = _fields.FirstOrDefault(x => x.Key == f.ListBy);
            string grp = g != null ? Cell(r, g.Col) : "";
            return Enumerable.Range(0, n).Where(i => grp.Length == 0 || (i < f.By.Count && Ic.Equals(f.By[i], grp))).ToList();
        }

        // The value of the first item of f for the row r (ListBy), "" when it has none:
        string FirstOf(Field f, string[] r)
        {
            var items = ItemsOf(f, r);
            if (items.Count == 0) return "";
            return f.Vals != null ? (items[0] < f.Vals.Count ? f.Vals[items[0]] : "") : Labels(f)[items[0]];
        }

        static int IndexOf(Field f, string val)
        {
            if (f.Vals != null) return f.Vals.IndexOf(val);
            return Labels(f)?.IndexOf(val) ?? -1;
        }

        // The text of column col of the row v, as the list shows it:
        internal string Text(string[] v, int col)
        {
            string cell = Cell(v, col);
            var f = _fields.FirstOrDefault(x => x.Col == col && x.El is ComboBox);
            if (f == null) return cell;
            int i = IndexOf(f, cell);
            var labels = Labels(f);
            return labels != null && i >= 0 && i < labels.Count ? labels[i] : cell;
        }

        // ---- The list ----

        public void Fill()
        {
            foreach (var f in _fields)
                if (f.El is ComboBox c && _s.Lists.TryGetValue(f.Key, out var items))
                {
                    // (a list by group: its items set for each row shown)
                    if (f.ListBy != null) f.All = items; else c.ItemsSource = items;
                }
            _list.ItemsSource = _items;
            // (the rows of the preset shown: k.sel the ones selected when the window opens)
            if (_in >= 0) Load(); else Rebuild();
            var sel = new List<int>();
            if (_s.Values.TryGetValue(_k + ".sel", out string s))
                foreach (var x in s.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries))
                    if (int.TryParse(x, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i) && i >= 0 && i < _rows.Count) sel.Add(i);
            Select(sel);
            // none selected: the fields show the new row (what Add adds):
            if (sel.Count == 0) Show(_new ?? (_rows.Count > 0 ? _rows[0] : new string[_ncols]));
        }

        // The rows of the preset shown (RowsIn), none selected:
        internal void Load()
        {
            if (_in < 0 || _v.Presets == null) return;
            _rows.Clear();
            _rows.AddRange(Decode(_v.Presets.ShownCell(_in)).Select(Pad));
            _bad = null;
            Rebuild();
            Select(new List<int>());
            Show(_new ?? new string[_ncols]);
            Summary();
        }

        // The rows of a column (RowsIn): a row on each line, its columns divided by tabs:
        static IEnumerable<string[]> Decode(string cell) =>
            (cell ?? "").Split('\n').Where(l => l.Trim().Length > 0).Select(l => l.TrimEnd('\r').Split('\t'));

        string Encode() => string.Join("\n", _rows.Select(r => string.Join("\t", r.Select(c => (c ?? "").Replace("\t", " ").Replace("\n", " ")))));

        // A change given back to the preset shown (RowsIn):
        void Store()
        {
            if (_in >= 0) _v.Presets?.PutShown(_in, Encode());
        }

        void Rebuild()
        {
            _v.Quiet(() =>
            {
                _items.Clear();
                foreach (var r in _rows) _items.Add(new RowItem(this, r));
            });
        }

        // The rows selected, the one shown first (the one clicked first):
        List<int> Selected() => _list.SelectedItems.Cast<RowItem>().Select(i => _items.IndexOf(i)).Where(i => i >= 0).ToList();

        void Select(List<int> sel)
        {
            _v.Quiet(() =>
            {
                _list.SelectedItems.Clear();
                foreach (int i in sel) if (i >= 0 && i < _items.Count) _list.SelectedItems.Add(_items[i]);
                if (sel.Count > 0 && sel[0] < _items.Count) _list.ScrollIntoView(_items[sel[0]]);
            });
            if (sel.Count > 0) Show(_rows[sel[0]]);
            Out();
        }

        // The fields show the row r:
        void Show(string[] r)
        {
            _v.Quiet(() =>
            {
                foreach (var f in _fields) ShowField(f, r);
            });
        }

        void ShowField(Field f, string[] r)
        {
            string cell = Cell(r, f.Col);
            switch (f.El)
            {
                case ComboBox c:
                    int i = IndexOf(f, cell);
                    if (f.ListBy != null)
                    {
                        f.Shown = ItemsOf(f, r);
                        c.ItemsSource = f.Shown.Select(j => f.All[j]).ToList();
                        int at = f.Shown.IndexOf(i);
                        c.SelectedIndex = at;
                        _s.Values[f.Key] = at.ToString(CultureInfo.InvariantCulture);
                        break;
                    }
                    c.SelectedIndex = i >= 0 && i < c.Items.Count ? i : -1;
                    _s.Values[f.Key] = c.SelectedIndex.ToString(CultureInfo.InvariantCulture);
                    break;
                case TextBox x:
                    x.Text = cell;
                    _s.Values[f.Key] = cell;
                    break;
                case ToggleButton t:
                    t.IsChecked = cell == "1";
                    _s.Values[f.Key] = cell == "1" ? "1" : "0";
                    break;
            }
        }

        // The value of the field f, as a row keeps it:
        static string Read(Field f)
        {
            switch (f.El)
            {
                case ComboBox c:
                    int i = c.SelectedIndex;
                    if (f.Shown != null) i = i >= 0 && i < f.Shown.Count ? f.Shown[i] : -1;
                    if (f.Vals != null) return i >= 0 && i < f.Vals.Count ? f.Vals[i] : "";
                    var labels = Labels(f);
                    return labels != null && i >= 0 && i < labels.Count ? labels[i] : "";
                case TextBox x: return x.Text.Trim();
                case ToggleButton t: return t.IsChecked == true ? "1" : "0";
            }
            return "";
        }

        // The value of key for the row r, as a rule reads it (the value of the window for a key
        // that is not a field):
        string RowGet(string[] r, string key)
        {
            var f = _fields.FirstOrDefault(x => x.Key == key);
            return f != null ? Cell(r, f.Col) : _v.Stored(key);
        }

        bool Applies(Field f, string[] r) => f.Rules.All(rule => View.Holds(rule, k => RowGet(r, k)));

        void Out() => _s.Values[_k + ".sel"] = string.Join(" ", Selected().Select(i => i.ToString(CultureInfo.InvariantCulture)));

        // ---- Changes ----

        // A control changed by the user (its value already in the values):
        public void Changed(string key)
        {
            if (key == _k) { Picked(); return; }
            var f = _fields.FirstOrDefault(x => x.Key == key);
            if (f == null) { if (_tiles.Any(t => t.Line == key || t.BorderLines == key || t.DividingLines == key)) Tiles(); return; }
            string val = Read(f);
            var sel = Selected();
            string msg = Problem(f, val, sel.Count == 1 ? sel[0] : -1);
            if (msg != null)
            {
                _bad = f.Key;
                _v.Error(msg);
                return;
            }
            if (_bad == f.Key) { _bad = null; _v.Error(""); }
            int kept = -1;
            foreach (int i in sel)
            {
                var r = _rows[i];
                if (!Applies(f, r)) continue;
                // on in one row at most: the first one selected it applies to:
                if (f.Exclusive && val == "1") { if (kept >= 0) continue; kept = i; }
                var nr = Put(r, f.Col, val);
                foreach (var g in _fields.Where(g => g.Follows != null && g.Follows.Split('/')[0] == f.Key))
                    nr = Follow(g, f, Cell(r, f.Col), val, nr);
                // the lists by this field (ListBy): their first item when theirs is no longer listed:
                foreach (var g in _fields.Where(g => g.ListBy == f.Key))
                    if (!ItemsOf(g, nr).Contains(IndexOf(g, Cell(nr, g.Col)))) nr = Put(nr, g.Col, FirstOf(g, nr));
                Set(i, nr);
            }
            // an exclusive checkbox checked: cleared in the other rows (the row shown too, when
            // another one kept it):
            if (kept >= 0)
            {
                for (int i = 0; i < _rows.Count; i++)
                    if (i != kept && Cell(_rows[i], f.Col) == "1") Set(i, Put(_rows[i], f.Col, "0"));
                if (sel.Count > 0 && sel[0] != kept) _v.Quiet(() => ShowField(f, _rows[sel[0]]));
            }
            if (sel.Count > 0) Store();
            // none selected (the fields of the row Add adds): the lists by this field follow it:
            if (sel.Count == 0 && _fields.Any(g => g.ListBy == f.Key))
            {
                var nr = Pad(new string[_ncols]);
                foreach (var x in _fields) nr = Put(nr, x.Col, Read(x));
                foreach (var g in _fields.Where(g => g.ListBy == f.Key))
                {
                    if (!ItemsOf(g, nr).Contains(IndexOf(g, Cell(nr, g.Col)))) nr = Put(nr, g.Col, FirstOf(g, nr));
                    var row = nr;
                    _v.Quiet(() => ShowField(g, row));
                }
            }
            // the fields that followed it, in the row shown:
            if (sel.Count > 0)
                _v.Quiet(() => { foreach (var g in _fields.Where(g => (g.Follows != null && g.Follows.Split('/')[0] == f.Key) || g.ListBy == f.Key)) ShowField(g, _rows[sel[0]]); });
            Summary();
        }

        // The field g takes the item of its list (Follows) for the new value of f, when it was
        // empty or the item of its former value:
        string[] Follow(Field g, Field f, string was, string now, string[] r)
        {
            if (!_s.Lists.TryGetValue(g.Follows, out var list)) return r;
            int a = IndexOf(f, was), b = IndexOf(f, now);
            string before = a >= 0 && a < list.Count ? list[a] : "", after = b >= 0 && b < list.Count ? list[b] : "";
            string cur = Cell(r, g.Col);
            if (after.Length == 0 || (cur.Length > 0 && cur != before)) return r;
            return Put(r, g.Col, after);
        }

        void Set(int i, string[] r)
        {
            _rows[i] = r;
            _items[i].V = r;
        }

        // Why the value val of f is not valid, null when it is (row: the row edited, -1 when
        // none or several):
        string Problem(Field f, string val, int row)
        {
            if (f.El is TextBox && Win.GetCheck(f.El) is string kind && !View.Valid(kind, val))
                return Win.GetCheckMessage(f.El) ?? "This value is not valid.";
            if (f.Unique != null && _rows.Where((r, i) => i != row).Any(r => Ic.Equals(Cell(r, f.Col), val)))
                return f.Unique;
            return null;
        }

        // Rows picked in the list: the first one in the fields (a value not valid is dropped):
        void Picked()
        {
            if (_bad != null) { _bad = null; _v.Error(""); }
            var sel = Selected();
            if (sel.Count > 0) Show(_rows[sel[0]]);
            Out();
            Summary();
        }

        // ---- Buttons ----

        public bool Click(Button b)
        {
            if (_subs.Contains(b)) { Sub(b); return true; }
            string act = Win.GetDo(b);
            if (act == null) return false;
            var sel = Selected();
            var keep = new List<int>();
            switch (act)
            {
                case "add":
                    // a new row (k/new, else the row shown) with the values of the fields:
                    var from = _new ?? (sel.Count > 0 ? _rows[sel[0]] : new string[_ncols]);
                    var nr = Pad((string[])from.Clone());
                    foreach (var f in _fields)
                    {
                        string val = Read(f);
                        if (f.El is TextBox && Win.GetCheck(f.El) is string kind && Applies(f, nr) && !View.Valid(kind, val))
                        {
                            Problem(f);
                            return true;
                        }
                        nr = Put(nr, f.Col, val);
                    }
                    foreach (var f in _fields.Where(x => x.Unique != null)) nr = Put(nr, f.Col, UniqueText(f, Cell(nr, f.Col)));
                    int at = sel.Count > 0 ? sel.Max() + 1 : _rows.Count;
                    _rows.Insert(at, nr);
                    keep.Add(at);
                    break;
                case "remove":
                    foreach (int i in sel.OrderByDescending(i => i)) _rows.RemoveAt(i);
                    break;
                case "up":
                case "down":
                    if (sel.Count != 1) return true;
                    int j = sel[0] + (act == "up" ? -1 : 1);
                    if (j < 0 || j >= _rows.Count) return true;
                    var t = _rows[j];
                    _rows[j] = _rows[sel[0]];
                    _rows[sel[0]] = t;
                    keep.Add(j);
                    break;
                case "flip":
                    _rows.Reverse();
                    keep.AddRange(sel.Select(i => _rows.Count - 1 - i));
                    break;
                case "reset":
                    if (_defs == null) return true;
                    _rows.Clear();
                    _rows.AddRange(_defs.Select(x => (string[])x.Clone()));
                    break;
                default:
                    return false;
            }
            _bad = null;
            _v.Error("");
            Rebuild();
            Select(keep);
            Store();
            Summary();
            return true;
        }

        // The columns a button opens a window on (Win.Columns): (key, column) ...:
        static List<KeyValuePair<string, int>> ColumnsOf(Button b)
        {
            var res = new List<KeyValuePair<string, int>>();
            foreach (var x in (Win.GetColumns(b) ?? "").Split(','))
            {
                var p = x.Split(':');
                if (p.Length == 2 && p[0].Trim().Length > 0 && int.TryParse(p[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out int c) && c >= 0)
                    res.Add(new KeyValuePair<string, int>(p[0].Trim(), c));
            }
            return res;
        }

        // The window of the button b on the row shown; its OK gives its values to the rows
        // selected its rules hold for:
        void Sub(Button b)
        {
            var sel = Selected();
            var map = ColumnsOf(b);
            if (sel.Count == 0 || map.Count == 0) return;
            var shown = _rows[sel[0]];
            foreach (var m in map)
            {
                string cell = Cell(shown, m.Value);
                if (_s.Lists.TryGetValue(m.Key + "/vals", out var vals))
                    _s.Values[m.Key] = Math.Max(0, vals.FindIndex(v => Ic.Equals(v, cell))).ToString(CultureInfo.InvariantCulture);
                else _s.Values[m.Key] = cell;
            }
            if (_v.OpenSub(Win.GetOpen(b)) != 1) return;
            var rules = new List<string>();
            for (DependencyObject o = b; o != null && !(o is Window); o = LogicalTreeHelper.GetParent(o))
                if (Win.GetEnabledBy(o) is string rule && rule.Trim().Length > 0) rules.Add(rule);
            foreach (int i in sel)
            {
                var r = _rows[i];
                if (!rules.All(rule => View.Holds(rule, k => RowGet(r, k)))) continue;
                foreach (var m in map)
                {
                    _s.Values.TryGetValue(m.Key, out string v);
                    if (_s.Lists.TryGetValue(m.Key + "/vals", out var vals))
                        v = int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int j) && j >= 0 && j < vals.Count ? vals[j] : Cell(r, m.Value);
                    r = Put(r, m.Value, (v ?? "").Trim());
                }
                Set(i, r);
            }
            Show(_rows[sel[0]]);
            Store();
            Summary();
        }

        // The message of a field not valid, its text selected:
        void Problem(Field f)
        {
            _v.Error(Win.GetCheckMessage(f.El) ?? "This value is not valid.");
            f.El.Focus();
            if (f.El is TextBox x) x.SelectAll();
        }

        // The text t, followed by " (2)", " (3)"... when another row has it in the column of f:
        string UniqueText(Field f, string t)
        {
            string u = t;
            for (int n = 2; _rows.Any(r => Ic.Equals(Cell(r, f.Col), u)); n++) u = t + " (" + n.ToString(CultureInfo.InvariantCulture) + ")";
            return u;
        }

        // ---- State ----

        // The buttons and the fields of one row only, after the rules of the view:
        public void Refresh()
        {
            var sel = Selected();
            foreach (var b in _buttons)
            {
                bool on;
                switch (Win.GetDo(b))
                {
                    case "remove": on = sel.Count > 0; break;
                    case "up": on = sel.Count == 1 && sel[0] > 0; break;
                    case "down": on = sel.Count == 1 && sel[0] < _rows.Count - 1; break;
                    case "flip": on = _rows.Count > 1; break;
                    case "reset": on = _defs != null; break;
                    default: on = true; break;
                }
                b.IsEnabled = on && !_s.Off.Contains(b.Name ?? "");
            }
            // a window on the rows selected: greyed out while none is (and by its rules):
            foreach (var b in _subs)
                b.IsEnabled = sel.Count > 0 && _v.Holds(Win.GetEnabledBy(b)) && !_s.Off.Contains(b.Name ?? "");
            // a field unique to each row is for one row only (its own rule, if any, set by the view):
            foreach (var f in _fields.Where(x => x.Unique != null))
            {
                if (sel.Count > 1) f.El.IsEnabled = false;
                else if (Win.GetEnabledBy(f.El) == null && !_s.Off.Contains(f.Key)) f.El.IsEnabled = true;
            }
            Summary();
        }

        void Summary()
        {
            Tiles();
            foreach (var e in _summaries)
            {
                string text = _rows.Count == 0 && Win.GetSummaryEmpty(e) is string empty ? empty : Summary(Win.GetSummary(e));
                if (e is TextBlock tb) tb.Text = text;
                else if (e is HeaderedContentControl h) h.Header = text;
            }
        }

        // The Spec of the tiles of the rows (see Assembly.cs):
        void Tiles()
        {
            if (_tiles.Count == 0) return;
            var sel = new HashSet<int>(Selected());
            foreach (var t in _tiles)
            {
                var c = (t.Columns ?? "").Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries)
                    .Select(x => int.TryParse(x, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i) ? i : -1).ToArray();
                if (c.Length < 8) continue;
                List<string> specs = null, ends = null, paper = null;
                if (t.Specs != null) _s.Lists.TryGetValue(t.Specs, out specs);
                if (t.Ends != null) _s.Lists.TryGetValue(t.Ends, out ends);
                if (t.Paper != null && _s.Lists.TryGetValue(t.Paper, out paper) && paper.Count >= 2
                    && double.TryParse(paper[0], NumberStyles.Float, CultureInfo.InvariantCulture, out double u)
                    && double.TryParse(paper[1], NumberStyles.Float, CultureInfo.InvariantCulture, out double ds))
                {
                    t.Unit = u;
                    t.DrawScale = ds;
                }
                string End(int i) => ends != null && i < ends.Count ? ends[i] : "";
                t.Justify = t.Line != null ? _v.Stored(t.Line) ?? "" : "";
                t.BorderOn = t.BorderLines == null || _v.Stored(t.BorderLines) == "1";
                t.DividingOn = t.DividingLines == null || _v.Stored(t.DividingLines) == "1";
                var pf = _fields.FirstOrDefault(f => f.Col == c[1]);
                var parts = new List<string>();
                for (int i = 0; i < _rows.Count; i++)
                {
                    var r = _rows[i];
                    string kind = Cell(r, c[0]).ToUpperInvariant(), w = Cell(r, c[2]), band;
                    if (kind == "L") band = "L?0";
                    else if (kind == "S") band = "S?" + w;
                    // a Hatch layer without hatch (Has a hatch off): a space, its border kept:
                    else if (c.Length > 10 && Cell(r, c[10]) == "0") band = "S?" + w;
                    else
                    {
                        int j = pf != null ? IndexOf(pf, Cell(r, c[1])) : -1;
                        var f = (specs != null && j >= 0 && j < specs.Count ? specs[j] : "X?1").Split('?');
                        if (f.Length > 1) f[1] = w;
                        // a hatch scale from the thickness: "w" and the ppu of a unit of it:
                        if (f.Length > 4 && f[4].StartsWith("w")
                            && double.TryParse(f[4].Substring(1), NumberStyles.Float, CultureInfo.InvariantCulture, out double pw)
                            && double.TryParse(w, NumberStyles.Float, CultureInfo.InvariantCulture, out double th))
                            f[4] = (pw * th).ToString("R", CultureInfo.InvariantCulture);
                        // or by the band settings of the row (Scale by width, its width factor:
                        // the thickness x the factor drawing units, at the drawing scale):
                        else if (f.Length == 7 && f[0] == "P" && c.Length > 12 && Cell(r, c[3]) == "1" && Cell(r, c[11]) == "1" && t.Unit > 0
                            && double.TryParse(w, NumberStyles.Float, CultureInfo.InvariantCulture, out double tw) && tw > 0)
                        {
                            if (!double.TryParse(Cell(r, c[12]), NumberStyles.Float, CultureInfo.InvariantCulture, out double fc) || fc <= 0) fc = 1;
                            double dsc = t.DrawScale > 0 ? t.DrawScale : 1;
                            f[4] = (fc * t.Unit * tw / dsc).ToString("R", CultureInfo.InvariantCulture);
                            f[6] = dsc.ToString("R", CultureInfo.InvariantCulture);
                        }
                        band = string.Join("?", f);
                    }
                    bool own = kind == "P" && Cell(r, c[3]) == "1";
                    parts.Add(string.Join("~", band,
                        own ? Cell(r, c[4]) : End(0), own ? Cell(r, c[5]) : End(1), own ? Cell(r, c[6]) : End(2),
                        own ? "1" : "0", kind == "P" && Cell(r, c[7]) == "1" ? "1" : "0", sel.Contains(i) ? "1" : "0",
                        own && c.Length > 8 ? Cell(r, c[8]) : "",
                        kind == "P" && c.Length > 9 && Cell(r, c[9]) == "1" ? "1" : "0"));
                }
                t.Spec = string.Join("*", parts);
            }
        }

        string Summary(string template)
        {
            int nsel = Selected().Count;
            return Token.Replace(template, m =>
            {
                string rest = m.Groups[2].Value;
                switch (m.Groups[1].Value)
                {
                    case "sel":
                        return nsel >= 2 ? (rest.StartsWith("|") ? rest.Substring(1) : rest).Replace("#", nsel.ToString(CultureInfo.InvariantCulture)) : "";
                    case "sum":
                        var p = rest.TrimStart(':').Split(new[] { ':' }, 2);
                        if (!int.TryParse(p[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out int col)) return "";
                        string rule = p.Length > 1 ? p[1] : null;
                        double sum = 0;
                        foreach (var r in _rows.Where(r => View.Holds(rule, k => RowGet(r, k))))
                            if (double.TryParse(Cell(r, col), NumberStyles.Float, CultureInfo.InvariantCulture, out double x)) sum += x;
                        return sum.ToString("0.####", CultureInfo.InvariantCulture);
                    default:
                        var q = rest.Split('|');
                        string cr = q[0].TrimStart(':');
                        int n = _rows.Count(r => View.Holds(cr, k => RowGet(r, k)));
                        string ns = n.ToString(CultureInfo.InvariantCulture);
                        return q.Length >= 3 ? ns + " " + (n == 1 ? q[1] : q[2]) : ns;
                }
            });
        }

        // Before the window closes: a value not valid is shown (false), every row is checked
        // (the first one not valid selected), at least one row when the list says so:
        public bool Check()
        {
            if (_bad != null)
            {
                var b = _fields.FirstOrDefault(x => x.Key == _bad);
                if (b != null && b.El.IsEnabled && b.El.IsVisible)
                {
                    Problem(b);
                    return false;
                }
                _bad = null;
            }
            for (int i = 0; i < _rows.Count; i++)
            {
                foreach (var f in _fields)
                {
                    if (!Applies(f, _rows[i])) continue;
                    string val = Cell(_rows[i], f.Col);
                    string msg = f.El is TextBox && Win.GetCheck(f.El) is string kind && !View.Valid(kind, val)
                        ? Win.GetCheckMessage(f.El) ?? "This value is not valid."
                        : f.Unique != null && _rows.Where((r, j) => j != i).Any(r => Ic.Equals(Cell(r, f.Col), val)) ? f.Unique : null;
                    if (msg == null) continue;
                    Select(new List<int> { i });
                    _v.Refresh();
                    _v.Error(msg);
                    f.El.Focus();
                    if (f.El is TextBox x) x.SelectAll();
                    return false;
                }
            }
            if (_rows.Count == 0 && Win.GetCheck(_list) == "rows")
            {
                _v.Error(Win.GetCheckMessage(_list) ?? "Add a row first.");
                return false;
            }
            _v.Error("");
            return true;
        }
    }
}
