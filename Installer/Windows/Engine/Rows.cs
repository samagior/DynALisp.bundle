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
//   dyl:Win.Follows="lp/widths"  this field takes the item of lp/widths (a list of the Lisp,
//                              one item for each item of the field lp) when lp changes, if
//                              it was empty or the item of its former value.
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
            public string Key, Unique, Follows;
            public int Col;
            public FrameworkElement El;
            public List<string> Vals;
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
        readonly ObservableCollection<RowItem> _items = new ObservableCollection<RowItem>();
        readonly int _ncols;
        string _bad;                       // the key of a value not valid (not stored), null else

        // A list of rows of a window: a ListBox with Win.Rows:
        public static bool Is(FrameworkElement fe) => fe is ListBox && !string.IsNullOrEmpty(fe.Name) && Win.GetRows(fe) == "1";

        public RowsEditor(View v, ListBox list, IList<FrameworkElement> all)
        {
            _v = v;
            _s = v.Session;
            _list = list;
            _k = list.Name;
            _rows = _s.Rows.TryGetValue(_k + "/rows", out var r) ? r.Select(x => x.ToArray()).ToList() : new List<string[]>();
            _new = _s.Rows.TryGetValue(_k + "/new", out var n) && n.Count > 0 ? n[0] : null;
            _defs = _s.Rows.TryGetValue(_k + "/defs", out var d) ? d.Select(x => x.ToArray()).ToList() : null;
            foreach (var fe in all)
            {
                string c = Win.GetColumn(fe);
                if (c == null || string.IsNullOrEmpty(fe.Name)) continue;
                if (!int.TryParse(c, NumberStyles.Integer, CultureInfo.InvariantCulture, out int col) || col < 0) continue;
                var f = new Field { Key = fe.Name, Col = col, El = fe, Unique = Win.GetUnique(fe), Follows = Win.GetFollows(fe) };
                f.Vals = _s.Lists.TryGetValue(fe.Name + "/vals", out var vals) ? vals : null;
                // Its rules and those of the panels holding it, up to the window:
                for (DependencyObject o = fe; o != null && !(o is Window); o = LogicalTreeHelper.GetParent(o))
                    if (Win.GetEnabledBy(o) is string rule && rule.Trim().Length > 0) f.Rules.Add(rule);
                _fields.Add(f);
            }
            _summaries = all.Where(e => Win.GetSummary(e) != null).ToList();
            _buttons = all.Where(e => e is Button && Win.GetDo(e) != null).ToList();
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
        static List<string> Labels(Field f) => (f.El as ComboBox)?.ItemsSource as List<string>;

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
                if (f.El is ComboBox c && _s.Lists.TryGetValue(f.Key, out var items)) c.ItemsSource = items;
            _list.SelectionMode = SelectionMode.Extended;
            _list.ItemsSource = _items;
            Rebuild();
            var sel = new List<int>();
            if (_s.Values.TryGetValue(_k + ".sel", out string s))
                foreach (var x in s.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries))
                    if (int.TryParse(x, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i) && i >= 0 && i < _rows.Count) sel.Add(i);
            Select(sel);
            // none selected: the fields show the new row (what Add adds):
            if (sel.Count == 0) Show(_new ?? (_rows.Count > 0 ? _rows[0] : new string[_ncols]));
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
            if (f == null) return;
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
            foreach (int i in sel)
            {
                var r = _rows[i];
                if (!Applies(f, r)) continue;
                var nr = Put(r, f.Col, val);
                foreach (var g in _fields.Where(g => g.Follows != null && g.Follows.Split('/')[0] == f.Key))
                    nr = Follow(g, f, Cell(r, f.Col), val, nr);
                Set(i, nr);
            }
            // the fields that followed it, in the row shown:
            if (sel.Count > 0)
                _v.Quiet(() => { foreach (var g in _fields.Where(g => g.Follows != null && g.Follows.Split('/')[0] == f.Key)) ShowField(g, _rows[sel[0]]); });
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
            Summary();
            return true;
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
            foreach (var e in _summaries)
            {
                string text = _rows.Count == 0 && Win.GetSummaryEmpty(e) is string empty ? empty : Summary(Win.GetSummary(e));
                if (e is TextBlock tb) tb.Text = text;
                else if (e is HeaderedContentControl h) h.Header = text;
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
