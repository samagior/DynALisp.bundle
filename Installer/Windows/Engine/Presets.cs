// Presets.cs - DynALisp.Windows: the preset editor of a preset window (Quick Draw...)
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
// A preset window edits the presets of a tool, as the preset dialog of the Lisp engine
// (Remote>>Dyl:PresetDialog, Remote\Dyl-Presets.lsp), whose rules it follows: its list
// (filter, sort, Show group), the presets selected (several: a value changed is given to
// all of them), New, Copy, Delete, Reset Selected, Reset All, the aliases of the command of
// the preset shown. All of it in the window, with no call to the Lisp: the Lisp gives the
// presets, gets them back as edited, and saves them. A button that must run Lisp (another
// window, a point picked) closes the window with its number (Win.Close), the Lisp opens it
// again on the presets it got.
//
// A window is a preset window when its list is a ListBox named "lst" and the Lisp gives its
// presets (pst/rows). The Lisp gives (Remote>>Dyl:PresetWinVals):
//
//   pst/rows    the presets, a row of strings each: the columns of the presets file (id
//               group name ...), then columns the Lisp adds for the window only (a summary,
//               a preview: read only, not saved)
//   pst/defs    the default presets (same columns): Reset, and the status of a preset
//   pst/new     a new preset (New: in the group of the preset shown)
//   pst/tiles   the controls of the values and their column: "nam:2,grp:1,mth:4,hbr:28:inv",
//               flags: inv (a checkbox showing the inverse of its column), up (saved in upper
//               case); a TextBlock shows its column, a HatchTile draws it (its Spec)
//   pst.idx     the preset shown (its index in pst/rows), pst.sel the presets selected
//               ("0 3 5"), pst.shw the group shown ("": all)
//   pst/cmds    "1" when the presets are commands (aliases, Draw), with pst/base and pst/cmd:
//               the command prefixes of the default and of the custom presets
//               (qd-Brick -> Pst-QuickDrawBrick, cu-Test -> Pst-QuickDrawCustomTest)
//   pst/als     the aliases ((ALIAS COMMAND) ...), pst/taken the names already taken
//               ((NAME what-has-it) ...), pst/prefix the text of a new alias by the value of a
//               column ("4|Polyline=PL-|*=QD-")
//   pst/mat     the column of the material id, pst/mats the materials
//               ((id group name spec pattern [surface-spec surface-pattern]) ...), spec drawn
//               by a HatchTile (Hatch.cs); pst/matview the column of the view of a preset:
//               "Surface", its material is previewed with its surface spec and pattern;
//               pst/matnoun what they are called in the messages ("material"), pst/matfree
//               "1": the list holds every one of them, never only those of the group of the
//               preset, and another group does not change it (the hatch presets of a
//               material); mgr/list the groups of the materials: the list mgr of the window
//               (a ComboBox, not a column) picks the group the material list lists, never the
//               group of the preset, and shows the group of the material of the preset shown
//               (Quick Draw: (matgroups . T) of the Lisp)
//   pst/spec    a column of the presets with a preview of their own (an assembly), used
//               when pst/specby holds for the preset (a rule, as Win.EnabledBy); else the
//               preview is the hatch of its material
//   pst/blank   a rule (as Win.EnabledBy): the preview of a preset it holds for (and its own
//               does not) is a space, without hatch (a Quick Draw preset without Has a hatch)
//   pst/outline a rule (as Win.EnabledBy): the preview of a preset it holds for is outlined
//               ("O*" before its bands, see Hatch.cs: the preset has a border)
//   pst/hatch   "3,4,6,9,10,63": the presets are hatches (the hatch presets): the preview of
//               each one is drawn from these columns as they are edited (its pattern, scale,
//               angle, annotative, adaptive scaling, type), with pst/pats, the .pat file of
//               each pattern ((PATTERN file metric) ...), and pst/ds, the drawing scale
//   pst/follow  "38:44,45,46": when the value of the column 38 changes (a list of the window,
//               the assembly preset of a Quick Draw preset), the columns 44, 45 and 46 of the
//               presets selected take the values of its row in pst/follow/rows ((value v44
//               v45 v46) ...: its width, its preview, its description), "" when it has none
//   pst/family  "13,14": the presets are the variants of families (the assemblies: B6a to
//               B6e are the family B6), the column of the name of their family and of its
//               short description. The list shows each family once (its first variant by
//               name, its number of variants), the variant shown is picked in the list var
//               (a ComboBox: its name, then the values of pst/famlabel, "9:min,11:STC": a
//               column, then the word written before its value, min: minutes written as
//               the building code writes them) under it, New variant (vnw) adds a copy of it
//               named after the family with the next letter (B6f), Delete variant (vdl) deletes
//               it. The family fields (fam its name, unique among the families) and the
//               columns of pst/famcols ("1,6,13,14,16-39": its group, its lines...) are given to
//               every variant of the families selected; the others to the variant shown, or to
//               every variant of the families selected while several are. New and Copy add a
//               family of one variant
//   pst/title   the name of the tool, pst/noun what the presets are called ("presets")
//   key/list, key/vals  the labels and the stored values of a list of the values
//   grp/list    the groups
//
// A list of rows of the window (Rows.cs) with dyl:Win.RowsIn="n" edits the rows held in the
// column n of the preset shown (the layers of an assembly preset); pst.many is "1" while
// several presets are selected (a rule greys it out then: it is for one preset only).
//
// It gives back pst/rows and pst/als as edited, pst.idx, pst.sel, pst.shw, pst.shd ("1":
// Set default was clicked, the group shown is the one the window opens on), and the values
// of the window (flt, srt...). The controls the editor keeps up to date, by their key:
//
//   lst  the list (its items: PresetItem, shown by its ItemTemplate: Spec, Group, Name,
//        Aliases), flt the filter, srt the sort (Name, Group), shg the Show group, shd Set
//        default, pcn how many are listed, mpv the preview of the preset shown, prm its
//        status, src its command, mat the material, mgr the group of the materials it
//        lists (with mgr/list), new cpy del rst all the buttons,
//        als aln aad aren adel ams the aliases panel, error the messages.

using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;

namespace DynALisp.Windows
{
    // An item of the list of the presets, shown by the ItemTemplate of the list:
    public sealed class PresetItem : INotifyPropertyChanged
    {
        string _spec, _group, _name, _aliases, _count;
        public int Index { get; internal set; }
        public string Spec { get => _spec; set => Set(ref _spec, value, "Spec"); }
        public string Group { get => _group; set => Set(ref _group, value, "Group"); }
        public string Name { get => _name; set => Set(ref _name, value, "Name"); }
        public string Aliases { get => _aliases; set => Set(ref _aliases, value, "Aliases"); }
        // its number of variants (pst/family), "" for a family of one:
        public string Count { get => _count; set => Set(ref _count, value, "Count"); }

        public event PropertyChangedEventHandler PropertyChanged;

        void Set(ref string field, string value, string name)
        {
            if (field == value) return;
            field = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        }
    }

    sealed class PresetEditor
    {
        public const string RowsKey = "pst/rows";
        const int GroupCol = 1, NameCol = 2;
        static readonly StringComparer Ic = StringComparer.OrdinalIgnoreCase;
        static readonly string[] Sorts = { "Name", "Group" };

        sealed class Field
        {
            public string Key;
            public int Col;
            public bool Inv, Up;
            public FrameworkElement El;
            public List<string> Vals;
        }

        readonly View _v;
        readonly Session _s;
        readonly List<string[]> _rows, _defs, _mats, _als;
        readonly string[] _new;
        readonly List<Field> _fields = new List<Field>();
        readonly Dictionary<string, string> _taken = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        readonly ObservableCollection<PresetItem> _items = new ObservableCollection<PresetItem>();
        readonly bool _cmds;
        readonly string _base, _cmd, _noun, _title, _specBy, _blankBy, _outlineBy, _prefix, _matNoun;
        readonly bool _matFree;
        readonly int _matCol = -1, _specCol = -1, _followCol = -1, _viewCol = -1;
        readonly int[] _followTo = new int[0];
        readonly List<string[]> _follow;
        readonly int[] _hatchCols = new int[0];
        readonly List<string[]> _pats;
        readonly double _ds = 1.0;
        readonly int _famCol = -1, _famDescCol = -1;
        readonly HashSet<int> _famCols = new HashSet<int>();
        readonly List<KeyValuePair<int, string>> _famLabel = new List<KeyValuePair<int, string>>();

        int _idx;
        List<int> _sel = new List<int>();
        string _shw = "";
        string _bad;                       // the key of a value not valid (not stored), null else
        List<string> _matIds = new List<string>();
        List<string> _alst = new List<string>();
        List<string> _shws = new List<string>();
        List<string> _mgrs = new List<string>();
        string _mgrVal = "";
        List<int> _vars = new List<int>();
        List<string> _varLabels = new List<string>();

        readonly ListBox _list, _alsList;
        readonly TextBox _flt, _aln;
        readonly ComboBox _srt, _shg, _mat, _mgr, _var;
        readonly TextBlock _pcn, _prm, _src, _ams;
        readonly HatchTile _mpv;

        public PresetEditor(View v)
        {
            _v = v;
            _s = v.Session;
            _rows = Table(RowsKey);
            _defs = Table("pst/defs");
            _mats = Table("pst/mats");
            _als = Table("pst/als");
            _new = Table("pst/new").FirstOrDefault() ?? new string[0];
            foreach (var t in Table("pst/taken"))
                if (t.Length > 0 && t[0].Length > 0) _taken[t[0]] = t.Length > 1 ? t[1] : "a command";
            _s.Rows["pst/als"] = _als;
            _s.OutRows.Add(RowsKey);
            _s.OutRows.Add("pst/als");

            _cmds = Val("pst/cmds") == "1";
            _base = Val("pst/base");
            _cmd = Val("pst/cmd");
            _noun = Val("pst/noun") is string n && n.Length > 0 ? n : "presets";
            _title = Val("pst/title") ?? "";
            _specBy = Val("pst/specby");
            _outlineBy = Val("pst/outline");
            _blankBy = Val("pst/blank");
            _prefix = Val("pst/prefix");
            _matCol = Int(Val("pst/mat"), -1);
            _matNoun = Val("pst/matnoun") is string mn && mn.Length > 0 ? mn : "material";
            _matFree = Val("pst/matfree") == "1";
            _specCol = Int(Val("pst/spec"), -1);
            _viewCol = Int(Val("pst/matview"), -1);
            var fw = (Val("pst/follow") ?? "").Split(':');
            if (fw.Length == 2)
            {
                _followCol = Int(fw[0], -1);
                _followTo = fw[1].Split(',').Select(x => Int(x, -1)).Where(c => c >= 0).ToArray();
            }
            _follow = Table("pst/follow/rows");
            // A preset that is itself a hatch (the hatch presets): its preview drawn from its
            // columns as they are edited (see HatchSpec):
            _hatchCols = (Val("pst/hatch") ?? "").Split(',').Select(x => Int(x.Trim(), -1)).ToArray();
            if (_hatchCols.Length != 6 || _hatchCols.Any(c => c < 0)) _hatchCols = new int[0];
            _pats = Table("pst/pats");
            // The families (pst/family), the columns given to all their variants (pst/famcols:
            // "1,6,13-14"), the label of a variant (pst/famlabel):
            var fm = (Val("pst/family") ?? "").Split(',');
            _famCol = Int(fm[0], -1);
            if (fm.Length > 1) _famDescCol = Int(fm[1], -1);
            if (_famCol >= 0)
            {
                _famCols.Add(GroupCol);
                _famCols.Add(_famCol);
                if (_famDescCol >= 0) _famCols.Add(_famDescCol);
                foreach (var x in (Val("pst/famcols") ?? "").Split(','))
                {
                    var ab = x.Split('-');
                    int a = Int(ab[0], -1), z = ab.Length > 1 ? Int(ab[1], -1) : a;
                    for (int c = a; a >= 0 && c <= z; c++) _famCols.Add(c);
                }
                foreach (var x in (Val("pst/famlabel") ?? "").Split(','))
                {
                    int cut = x.IndexOf(':');
                    int col = Int(cut < 0 ? x : x.Substring(0, cut), -1);
                    if (col >= 0) _famLabel.Add(new KeyValuePair<int, string>(col, cut < 0 ? "" : x.Substring(cut + 1)));
                }
            }
            if (double.TryParse(Val("pst/ds"), NumberStyles.Float, CultureInfo.InvariantCulture, out double ds) && ds > 0) _ds = ds;

            _list = (ListBox)v.Find("lst");
            _alsList = v.Find("als") as ListBox;
            _flt = v.Find("flt") as TextBox;
            _aln = v.Find("aln") as TextBox;
            _srt = v.Find("srt") as ComboBox;
            _shg = v.Find("shg") as ComboBox;
            _mat = v.Find("mat") as ComboBox;
            // The group of the materials the material list lists (mgr/list): those groups,
            // then the other groups of the materials:
            if (_s.Lists.TryGetValue("mgr", out var mgrs) && mgrs != null && _matCol >= 0 && !_matFree)
            {
                _mgr = v.Find("mgr") as ComboBox;
                _mgrs = mgrs.ToList();
                foreach (var g in _mats.Select(m => Cell(m, 1)).Where(g => g.Length > 0).Distinct(Ic))
                    if (!_mgrs.Contains(g, Ic)) _mgrs.Add(g);
                if (_mgr != null) _mgr.ItemsSource = _mgrs;
            }
            _pcn = v.Find("pcn") as TextBlock;
            _prm = v.Find("prm") as TextBlock;
            _src = v.Find("src") as TextBlock;
            _ams = v.Find("ams") as TextBlock;
            _mpv = v.Find("mpv") as HatchTile;
            _var = Fam ? v.Find("var") as ComboBox : null;

            // The controls of the values, by their key (pst/tiles):
            foreach (var part in (Val("pst/tiles") ?? "").Split(','))
            {
                var f = part.Split(':').Select(x => x.Trim()).ToArray();
                if (f.Length < 2 || !(v.Find(f[0]) is FrameworkElement el)) continue;
                var fd = new Field { Key = f[0], Col = Int(f[1], -1), El = el, Inv = f.Contains("inv"), Up = f.Contains("up") };
                if (fd.Col < 0) continue;
                if (el is ComboBox c)
                {
                    _s.Lists.TryGetValue(fd.Key, out var labels);
                    labels = labels ?? new List<string>();
                    fd.Vals = _s.Lists.TryGetValue(fd.Key + "/vals", out var vals) ? vals : labels;
                    if (fd.Key != "mat") c.ItemsSource = labels;
                }
                _fields.Add(fd);
            }

            _list.SelectionMode = SelectionMode.Extended;
            _list.ItemsSource = _items;
            _list.MouseDoubleClick += (a, e) =>
            {
                if (_cmds && e.OriginalSource is DependencyObject d && ItemsControl.ContainerFromElement(_list, d) is ListBoxItem)
                    _v.CloseWith(1);
            };
            if (_shg != null) _shg.ItemsSource = _shws;

            // As the Lisp left them:
            _idx = Math.Max(0, Math.Min(_rows.Count - 1, Int(Val("pst.idx"), 0)));
            _sel = (Val("pst.sel") ?? "").Split(' ').Select(x => Int(x, -1)).Where(i => i >= 0 && i < _rows.Count).Distinct().ToList();
            if (!_sel.Contains(_idx)) _sel = new List<int> { _idx };
            FamSel();
            _shw = Val("pst.shw") ?? "";
        }

        List<string[]> Table(string key) => _s.Rows.TryGetValue(key, out var t) ? t : (_s.Rows[key] = new List<string[]>());

        string Val(string key) => _s.Values.TryGetValue(key, out string v) ? v : null;

        static int Int(string s, int def) =>
            int.TryParse((s ?? "").Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out int i) ? i : def;

        static string Cell(string[] r, int col) => r != null && col >= 0 && col < r.Length ? r[col] ?? "" : "";

        static string[] Put(string[] r, int col, string val)
        {
            if (col < 0) return r;
            if (col >= r.Length) Array.Resize(ref r, col + 1);
            for (int i = 0; i < r.Length; i++) r[i] = r[i] ?? "";
            r[col] = val;
            return r;
        }

        void PutAll(int col, string val, bool one = false)
        {
            foreach (int j in one ? new List<int> { _idx } : Targets(col)) _rows[j] = Put(_rows[j], col, val);
        }

        // ---- Families (pst/family) ----

        bool Fam => _famCol >= 0;

        // The family of the preset i (its name when it has none), or the preset itself:
        string FamOf(int i)
        {
            if (!Fam) return i.ToString(CultureInfo.InvariantCulture);
            string f = Cell(_rows[i], _famCol);
            return f.Length > 0 ? f : Cell(_rows[i], NameCol);
        }

        // The variants of the family f, by name ("B6a" before "B6b", "W2" before "W10"):
        List<int> Variants(string f) =>
            Enumerable.Range(0, _rows.Count).Where(i => Ic.Equals(FamOf(i), f))
                      .OrderBy(i => Natural(Cell(_rows[i], NameCol)), StringComparer.Ordinal).ThenBy(i => i).ToList();

        List<string> SelFams => _sel.Select(FamOf).Distinct(Ic).ToList();

        // How many are selected: the families, or the presets:
        int SelCount => Fam ? SelFams.Count : _sel.Count;

        // The presets selected are every variant of the families selected:
        void FamSel()
        {
            if (!Fam || _rows.Count == 0) return;
            var fs = SelFams;
            if (!fs.Contains(FamOf(_idx), Ic)) fs.Add(FamOf(_idx));
            _sel = Enumerable.Range(0, _rows.Count).Where(i => fs.Contains(FamOf(i), Ic)).ToList();
        }

        // The presets a value of the column col is given to: with families, every variant of
        // the families selected for a column of the family (pst/famcols), else the variant
        // shown while one family is selected:
        IEnumerable<int> Targets(int col)
        {
            if (!Fam || _famCols.Contains(col) || SelCount > 1) return _sel;
            return new List<int> { _idx };
        }

        // "W10b" -> "W0000000010b": the numbers of a name sorted as numbers:
        static string Natural(string s)
        {
            var sb = new System.Text.StringBuilder();
            string u = (s ?? "").ToUpperInvariant();
            for (int i = 0; i < u.Length;)
            {
                if (char.IsDigit(u[i]))
                {
                    int j = i;
                    while (j < u.Length && char.IsDigit(u[j])) j++;
                    sb.Append(u.Substring(i, j - i).TrimStart('0').PadLeft(10, '0'));
                    i = j;
                }
                else sb.Append(u[i++]);
            }
            return sb.ToString();
        }

        // A rating in minutes as the building code writes it: "45" -> "45 min", "90" -> "1.5 h":
        static string Minutes(string v)
        {
            if (!int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int n)) return v;
            return n >= 60 && n % 30 == 0 ? (n / 60.0).ToString("0.#", CultureInfo.InvariantCulture) + " h" : n + " min";
        }

        // What the list var shows of the variant r: its name, then its values of pst/famlabel
        // ("9:min,10:NLB:min,11:STC": a column, the word written before its value, min for
        // minutes), each one but a value the same as that of the column before it:
        string VarLabel(string[] r)
        {
            var parts = new List<string>();
            string before = null;
            foreach (var p in _famLabel)
            {
                string v = Cell(r, p.Key).Trim();
                bool same = v == before;
                before = v;
                if (v.Length == 0 || same) continue;
                var w = p.Value.Split(':');
                string word = string.Join(" ", w.Where(x => x != "min" && x.Length > 0));
                if (w.Contains("min")) v = Minutes(v);
                parts.Add(word.Length > 0 ? word + " " + v : v);
            }
            string n = Cell(r, NameCol);
            return parts.Count == 0 ? n : n + "   " + string.Join(", ", parts);
        }

        // The list var: the variants of the family shown, the one shown picked:
        void VarFill()
        {
            if (_var == null) return;
            _vars = _rows.Count == 0 ? new List<int>() : Variants(FamOf(_idx));
            var labels = _vars.Select(i => VarLabel(_rows[i])).ToList();
            _v.Quiet(() =>
            {
                if (!labels.SequenceEqual(_varLabels)) { _varLabels = labels; _var.ItemsSource = _varLabels; }
                _var.SelectedIndex = _vars.IndexOf(_idx);
            });
            _s.Values["var"] = _vars.IndexOf(_idx).ToString(CultureInfo.InvariantCulture);
        }

        // Another variant picked: the one shown (the value shown valid first):
        void VarPicked()
        {
            int i = _var.SelectedIndex;
            if (i < 0 || i >= _vars.Count || _vars[i] == _idx) return;
            if (!Check()) { VarFill(); return; }
            _idx = _vars[i];
            FamSel();
            Show();
        }

        // The name of a new variant of the family f: f and the first letter no preset has
        // (B6 -> B6f; "Wall 2" -> "Wall 2 b"):
        string NextVariant(string f)
        {
            string sep = f.Length > 0 && char.IsDigit(f[f.Length - 1]) ? "" : " ";
            for (char c = 'a'; c <= 'z'; c++)
            {
                string n = f + sep + c;
                if (!_rows.Any(r => Ic.Equals(Cell(r, NameCol), n))) return n;
            }
            return Unique(f + sep + "z", -1);
        }

        // New variant: a copy of the variant shown, after it, its name selected:
        void VariantAdd()
        {
            if (_rows.Count == 0 || SelCount > 1) return;
            string f = FamOf(_idx);
            var r = (string[])Row.Clone();
            r = Put(r, 0, "");
            r = Put(r, _famCol, f);
            r = Put(r, NameCol, NextVariant(f));
            _idx++;
            _rows.Insert(_idx, r);
            _sel = new List<int> { _idx };
            FamSel();
            Show();
            Focus("nam");
        }

        // Delete variant: a custom variant of a family that has others:
        void VariantDelete()
        {
            if (_rows.Count == 0 || SelCount > 1 || Def(Row) != null) return;
            string f = FamOf(_idx);
            var vs = Variants(f);
            if (vs.Count < 2 || !Ask("Delete the variant \"" + Cell(Row, NameCol) + "\"?")) return;
            int k = vs.IndexOf(_idx);
            int next = vs[k > 0 ? k - 1 : 1];
            _rows.RemoveAt(_idx);
            _idx = next > _idx ? next - 1 : next;
            _sel = new List<int> { _idx };
            FamSel();
            Show();
        }

        // A family name not taken by another family than those of skip (" (2)"...):
        string UniqueFam(string name, ICollection<int> skip)
        {
            string n = name;
            for (int i = 2; Enumerable.Range(0, _rows.Count).Any(j => !skip.Contains(j) && Ic.Equals(FamOf(j), n)); i++)
                n = name + " (" + i.ToString(CultureInfo.InvariantCulture) + ")";
            return n;
        }

        void Focus(string key)
        {
            if (_v.Find(key) is TextBox t)
            {
                t.Focus();
                t.SelectAll();
            }
        }

        string[] Row => _rows.Count > 0 ? _rows[_idx] : new string[0];

        // The column col of the preset shown, and a value given to it only (the rows of a list
        // of the window that it holds, Rows.cs: Win.RowsIn):
        internal string ShownCell(int col) => Cell(Row, col);

        internal void PutShown(int col, string val)
        {
            if (_rows.Count == 0 || Cell(Row, col) == val) return;
            _rows[_idx] = Put(_rows[_idx], col, val);
            State();
        }

        // The keys the editor fills itself (not the view):
        public bool Owns(string key) =>
            key == "lst" || key == "als" || key == "shg" || key == "mat" || key == "mgr" || key == "mpv" || (key == "var" && _var != null)
            || _fields.Any(f => f.Key == key);

        // ---- Values and rules ----

        // The value of key for the preset r, as a rule reads it (a checkbox "1" / "0", the
        // value stored for a list); pst/solid: its material is a solid fill:
        string RowGet(string[] r, string key)
        {
            if (key == "pst/solid") return Solid(r) ? "1" : "0";
            var f = _fields.FirstOrDefault(x => x.Key == key);
            if (f == null) return null;
            string v = Cell(r, f.Col);
            if (f.El is ToggleButton) return ((v == "1") != f.Inv) ? "1" : "0";
            return v;
        }

        string[] MatOf(string[] r) =>
            _matCol < 0 ? null : _mats.FirstOrDefault(m => m.Length > 0 && m[0] == Cell(r, _matCol));

        // The cell of the material m for the preset r: its Cut (spec 3, pattern 4), or its
        // Surface (5, 6) while the view of r (pst/matview) is Surface:
        string MatCell(string[] r, string[] m, int i) =>
            _viewCol >= 0 && m != null && m.Length > i + 2 && Ic.Equals(Cell(r, _viewCol), "Surface") ? Cell(m, i + 2) : Cell(m, i);

        bool Solid(string[] r) => string.Equals(MatCell(r, MatOf(r), 4), "SOLID", StringComparison.OrdinalIgnoreCase);

        // The preview of the preset r: its own (an assembly), else a space while pst/blank holds
        // for it (no hatch), else the hatch of its material; outlined while pst/outline holds
        // for it (as the gallery shows it):
        string Spec(string[] r)
        {
            string sp;
            if (_hatchCols.Length > 0) sp = HatchSpec(r);
            else if (_specCol >= 0 && Cell(r, _specCol).Length > 0 && View.Holds(_specBy, k => RowGet(r, k))) sp = Cell(r, _specCol);
            else if (!string.IsNullOrWhiteSpace(_blankBy) && View.Holds(_blankBy, k => RowGet(r, k))) sp = "S?1";
            else sp = MatOf(r) is string[] m ? MatCell(r, m, 3) : "X?1";
            if (!string.IsNullOrWhiteSpace(_outlineBy) && View.Holds(_outlineBy, k => RowGet(r, k))) sp = "O*" + sp;
            return sp;
        }

        // The preview of a preset that is a hatch (pst/hatch: the columns of its pattern, scale,
        // angle, annotative, adaptive scaling and type), as Remote>>Dyl:MaterialBand draws it:
        // no pattern a space, SOLID a fill, else its pattern, from the .pat file pst/pats gives
        // it ((PATTERN file metric) ...: "1" a metric pattern, its scale in mm), its scale in
        // inches on paper divided by the drawing scale pst/ds, unless it keeps its size on paper
        // (annotative or adaptive scaling, never a Model hatch), then its type (a Drafting
        // hatch drawn 1:1, a Model one zoomed out to show its pattern):
        string HatchSpec(string[] r)
        {
            string pat = Cell(r, _hatchCols[0]).Trim().ToUpperInvariant();
            if (pat.Length == 0) return "S?1";
            if (pat == "SOLID") return "F?1";
            var p = _pats.FirstOrDefault(x => x.Length > 0 && Ic.Equals(x[0], pat));
            if (!double.TryParse(Cell(r, _hatchCols[1]), NumberStyles.Float, CultureInfo.InvariantCulture, out double s) || s <= 0) s = 1.0;
            if (p != null && Cell(p, 2) == "1") s /= 25.4;
            double.TryParse(Cell(r, _hatchCols[2]), NumberStyles.Float, CultureInfo.InvariantCulture, out double ang);
            bool model = Ic.Equals(Cell(r, _hatchCols[5]), "Model");
            double ds = !model && (Cell(r, _hatchCols[3]) == "1" || Cell(r, _hatchCols[4]) == "1") ? 1.0 : _ds;
            return string.Join("?", "P", "1", pat, p != null ? Cell(p, 1) : "",
                               (s / ds).ToString("0.########", CultureInfo.InvariantCulture),
                               ang.ToString("0.####", CultureInfo.InvariantCulture),
                               ds.ToString("0.####", CultureInfo.InvariantCulture),
                               model ? "Model" : "Drafting");
        }

        // ---- Commands and aliases ----

        string Command(string id)
        {
            if (!_cmds || string.IsNullOrEmpty(id) || id.Length < 4) return null;
            return (id.StartsWith("cu-", StringComparison.OrdinalIgnoreCase) ? _cmd + id.Substring(3) : _base + id.Substring(3)).ToUpperInvariant();
        }

        List<string> AliasesOf(string cmd) =>
            cmd == null ? new List<string>() :
            _als.Where(a => a.Length > 1 && Ic.Equals(a[1], cmd)).Select(a => a[0]).OrderBy(a => a, Ic).ToList();

        // "Modular brick 2" -> "ModularBrick2" (Remote>>Dyl:PresetCamel):
        static string Camel(string name)
        {
            var sb = new System.Text.StringBuilder();
            bool up = true;
            foreach (char c in name ?? "")
            {
                bool alnum = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
                if (!alnum) { up = true; continue; }
                sb.Append(up && c >= 'a' && c <= 'z' ? char.ToUpperInvariant(c) : c);
                up = false;
            }
            return sb.ToString();
        }

        // A custom id for the preset at index i, from its name, unique (Remote>>Dyl:PresetIds):
        void GiveId(int i)
        {
            if (Cell(_rows[i], 0).Length > 0) return;
            string camel = Camel(Cell(_rows[i], NameCol));
            string bas = "cu-" + (camel.Length > 0 ? camel : "Preset"), id = bas;
            for (int n = 2; _rows.Any(r => Ic.Equals(Cell(r, 0), id)); n++) id = bas + n.ToString(CultureInfo.InvariantCulture);
            _rows[i] = Put(_rows[i], 0, id);
        }

        string Prefix(string[] r)
        {
            // "4|Polyline=PL-|*=QD-": by the value of column 4:
            var f = (_prefix ?? "").Split('|');
            if (f.Length < 2) return "";
            string v = Cell(r, Int(f[0], -1));
            foreach (var p in f.Skip(1))
            {
                int eq = p.IndexOf('=');
                if (eq < 0) continue;
                string k = p.Substring(0, eq);
                if (k == "*" || Ic.Equals(k, v)) return p.Substring(eq + 1);
            }
            return "";
        }

        // ---- The list ----

        bool InShow(string[] r) => _shw.Length == 0 || Ic.Equals(_shw, Cell(r, GroupCol));

        string Filter => (_flt?.Text ?? "").Trim();

        bool Match(string[] r, string f)
        {
            if (f.Length == 0) return true;
            bool has(string s) => (s ?? "").IndexOf(f, StringComparison.OrdinalIgnoreCase) >= 0;
            return has(Cell(r, GroupCol)) || has(Cell(r, NameCol)) || has(string.Join(", ", AliasesOf(Command(Cell(r, 0)))))
                   || has(Cell(MatOf(r), 2));
        }

        string Sort => _srt != null && _srt.SelectedIndex >= 0 && _srt.SelectedIndex < Sorts.Length ? Sorts[_srt.SelectedIndex] : "Name";

        string SortKey(int i)
        {
            var r = _rows[i];
            if (Fam) return (Sort == "Group" ? Cell(r, GroupCol).ToUpperInvariant() + "\t" : "") + Natural(FamOf(i));
            return (Sort == "Group" ? Cell(r, GroupCol) + "\t" + Cell(r, NameCol) : Cell(r, NameCol)).ToUpperInvariant();
        }

        // With families, a family listed when one of its variants is, or its name or its
        // short description matches: its first variant (by name) stands for it:
        List<int> ListedFams(bool pin)
        {
            string f = Filter, shown = _rows.Count > 0 ? FamOf(_idx) : null;
            bool has(string s) => (s ?? "").IndexOf(f, StringComparison.OrdinalIgnoreCase) >= 0;
            var l = new List<int>();
            foreach (var g in Enumerable.Range(0, _rows.Count).GroupBy(FamOf, Ic))
            {
                var vs = g.OrderBy(i => Natural(Cell(_rows[i], NameCol)), StringComparer.Ordinal).ThenBy(i => i).ToList();
                bool pinned = pin && Ic.Equals(g.Key, shown);
                bool fits = InShow(_rows[vs[0]]) && (f.Length == 0 || has(g.Key) || has(Cell(_rows[vs[0]], _famDescCol)) || vs.Any(i => Match(_rows[i], f)));
                if (pinned || fits) l.Add(vs[0]);
            }
            l.Sort((a, b) =>
            {
                int c = string.CompareOrdinal(SortKey(a), SortKey(b));
                return c != 0 ? c : a.CompareTo(b);
            });
            return l;
        }

        // The presets listed: those of the Show group and of the filter, and the one shown
        // when pin is true (the fields shown are those of a line of the list), sorted:
        List<int> Listed(bool pin)
        {
            if (Fam) return ListedFams(pin);
            string f = Filter;
            var l = Enumerable.Range(0, _rows.Count).Where(i => (pin && i == _idx) || (InShow(_rows[i]) && Match(_rows[i], f))).ToList();
            l.Sort((a, b) =>
            {
                int c = string.CompareOrdinal(SortKey(a), SortKey(b));
                return c != 0 ? c : a.CompareTo(b);
            });
            return l;
        }

        PresetItem Item(int i)
        {
            var r = _rows[i];
            return new PresetItem
            {
                Index = i,
                Spec = Spec(r),
                Group = Cell(r, GroupCol),
                Name = Fam ? FamOf(i) : Cell(r, NameCol),
                Aliases = string.Join(", ", AliasesOf(Command(Cell(r, 0)))),
                Count = Fam && Variants(FamOf(i)) is List<int> vs && vs.Count > 1 ? vs.Count.ToString(CultureInfo.InvariantCulture) : "",
            };
        }

        // The list again: its items replaced only when the presets listed changed, else
        // updated in place (it does not scroll), then the selection:
        void List()
        {
            var l = Listed(true);
            _v.Quiet(() =>
            {
                if (!l.SequenceEqual(_items.Select(x => x.Index)))
                {
                    _items.Clear();
                    foreach (int i in l) _items.Add(Item(i));
                }
                else
                {
                    foreach (var it in _items)
                    {
                        var n = Item(it.Index);
                        it.Spec = n.Spec; it.Group = n.Group; it.Name = n.Name; it.Aliases = n.Aliases; it.Count = n.Count;
                    }
                }
                _list.SelectedItems.Clear();
                var fams = Fam ? SelFams : null;
                foreach (var it in _items.Where(x => Fam ? fams.Contains(FamOf(x.Index), Ic) : _sel.Contains(x.Index))) _list.SelectedItems.Add(it);
                var shown = _items.FirstOrDefault(x => Fam ? Ic.Equals(FamOf(x.Index), FamOf(_idx)) : x.Index == _idx);
                if (shown != null) _list.ScrollIntoView(shown);
            });
            ShowFill();
            if (_pcn != null)
            {
                int m = Listed(false).Count;
                int all = _rows.Count;
                // with families (the assemblies), no count: only No match
                _pcn.Text = m == 0 && (_shw.Length > 0 || Filter.Length > 0) ? "No match"
                          : Fam ? ""
                          : _shw.Length == 0 && Filter.Length == 0 ? all + " " + _noun
                          : m + " of " + all;
            }
        }

        // The Show list: All, then the groups of the presets (in the order of the groups), and
        // the group shown when no preset is in it any more:
        void ShowFill()
        {
            if (_shg == null) return;
            var used = _rows.Select(r => Cell(r, GroupCol)).Distinct(Ic).ToList();
            _s.Lists.TryGetValue("grp", out var grps);
            var lst = grps != null ? grps.Where(g => used.Contains(g, Ic)).ToList() : used.OrderBy(g => g, Ic).ToList();
            foreach (var g in used) if (!lst.Contains(g, Ic)) lst.Add(g);
            if (_shw.Length > 0 && !lst.Contains(_shw, Ic)) lst.Add(_shw);
            lst.Insert(0, "All");
            _v.Quiet(() =>
            {
                if (!lst.SequenceEqual(_shws))
                {
                    _shws = lst;
                    _shg.ItemsSource = _shws;
                }
                int i = _shw.Length == 0 ? 0 : _shws.FindIndex(g => Ic.Equals(g, _shw));
                _shg.SelectedIndex = Math.Max(0, i);
            });
        }

        // ---- The preset shown ----

        public void Fill()
        {
            if (_rows.Count == 0) return;
            Show();
        }

        // The values of the preset shown in the controls and the values:
        void Show()
        {
            var r = Row;
            MgrShow();
            MatFill();
            _v.Quiet(() =>
            {
                foreach (var f in _fields)
                {
                    string v = Cell(r, f.Col);
                    switch (f.El)
                    {
                        case ToggleButton t:
                            bool on = (v == "1") != f.Inv;
                            t.IsChecked = on;
                            _s.Values[f.Key] = on ? "1" : "0";
                            break;
                        case ComboBox c:
                            var vals = f.Key == "mat" ? _matIds : f.Vals;
                            int i = vals.FindIndex(x => x == v);
                            if (i < 0) i = vals.FindIndex(x => Ic.Equals(x, v));
                            c.SelectedIndex = i;
                            _s.Values[f.Key] = i.ToString(CultureInfo.InvariantCulture);
                            break;
                        case TextBox x:
                            x.Text = v;
                            _s.Values[f.Key] = v;
                            break;
                        case TextBlock tb:
                            tb.Text = v;
                            _s.Values[f.Key] = v;
                            break;
                        case HatchTile h:
                            h.Spec = v;
                            break;
                    }
                }
            });
            _bad = null;
            _v.Error(Val("error") ?? "");
            _s.Values["error"] = "";
            Aliases();
            State();
            _v.Rows?.Load();
        }

        // The material list of the preset shown: the materials of its group (with mgr, of the
        // group picked there) by name, then its material when it is not one of them ("group -
        // name", or marked missing); every material when the group has none
        // (Remote>>Dyl:PresetDlgMatFill), or always with pst/matfree:
        void MatFill()
        {
            if (_mat == null || _matCol < 0) return;
            var r = Row;
            string grp = _mgr != null ? _mgrVal : Cell(r, GroupCol), cur = Cell(r, _matCol);
            var inGrp = _matFree ? new List<string[]>() : MatsOf(grp);
            List<string[]> lst;
            bool byName = inGrp.Count > 0;
            if (byName)
            {
                lst = inGrp.ToList();
                var m = _mats.FirstOrDefault(x => Cell(x, 0) == cur);
                if (m != null && !lst.Contains(m)) lst.Add(m);
            }
            else lst = _mats.OrderBy(m => Cell(m, 1) + "\t" + Cell(m, 2), StringComparer.OrdinalIgnoreCase).ToList();
            var ids = lst.Select(m => Cell(m, 0)).ToList();
            var labels = lst.Select(m => byName && Ic.Equals(Cell(m, 1), grp) ? Cell(m, 2) : Cell(m, 1) + " - " + Cell(m, 2)).ToList();
            if (cur.Length > 0 && !ids.Contains(cur)) { ids.Add(cur); labels.Add(cur + "   (missing " + _matNoun + ")"); }
            _matIds = ids;
            _v.Quiet(() => _mat.ItemsSource = labels);
        }

        // The group of the material of the preset shown in mgr (kept when it no longer
        // exists, the first group when there is none yet):
        void MgrShow()
        {
            if (_mgr == null) return;
            if (MatOf(Row) is string[] m && Cell(m, 1).Length > 0) _mgrVal = Cell(m, 1);
            if (_mgrVal.Length == 0 && _mgrs.Count > 0) _mgrVal = _mgrs[0];
            int i = _mgrs.FindIndex(g => Ic.Equals(g, _mgrVal));
            _v.Quiet(() => _mgr.SelectedIndex = i);
            _s.Values["mgr"] = i.ToString(CultureInfo.InvariantCulture);
        }

        // Another group picked in mgr: the material list lists its materials, the first one
        // given to the presets selected when the material of the preset shown is not one of
        // them (as another group of the preset without mgr):
        void MgrPicked()
        {
            int i = _mgr.SelectedIndex;
            if (i < 0 || i >= _mgrs.Count) return;
            _mgrVal = _mgrs[i];
            var inGrp = MatsOf(_mgrVal);
            if (inGrp.Count > 0 && !inGrp.Any(m => m[0] == Cell(Row, _matCol)))
            {
                PutAll(_matCol, inGrp[0][0]);
                Show();
                return;
            }
            MatFill();
            _v.Quiet(() =>
            {
                int j = _matIds.IndexOf(Cell(Row, _matCol));
                _mat.SelectedIndex = j;
                _s.Values["mat"] = j.ToString(CultureInfo.InvariantCulture);
            });
        }

        List<string[]> MatsOf(string grp) =>
            _mats.Where(m => Ic.Equals(Cell(m, 1), grp)).OrderBy(m => Cell(m, 2), StringComparer.OrdinalIgnoreCase).ToList();

        // The state of the preset shown: its status, its command, the buttons, the list:
        void State()
        {
            var r = Row;
            var d = _defs.FirstOrDefault(x => x.Length > 0 && x[0] == Cell(r, 0));
            var sel = _sel.Select(j => _rows[j]).ToList();
            _s.Values["pst/solid"] = Solid(r) ? "1" : "0";
            _s.Values["pst.many"] = SelCount > 1 ? "1" : "0";
            if (_prm != null)
                _prm.Text = SelCount > 1 ? SelCount + " " + _noun + " selected"
                          : d == null ? (_defs.Count == 0 ? "" : "Custom " + One)
                          : Same(r, d) ? "Default " + One
                          : "Default " + One + ", modified";
            if (_src != null)
                _src.Text = !_cmds ? "" : Cell(r, 0).Length == 0 ? "Gets its command once saved or given an alias." : "Command: " + Command(Cell(r, 0));
            if (_mpv != null) _mpv.Spec = Spec(r);
            VarFill();
            List();
            Out();
        }

        // What one preset is called (pst/noun without its plural: "preset", "material",
        // "assembly"):
        string One => _noun.EndsWith("ies") ? _noun.Substring(0, _noun.Length - 3) + "y"
                    : _noun.EndsWith("s") ? _noun.Substring(0, _noun.Length - 1) : _noun;

        int Ncols => Int(Val("pst/ncols"), int.MaxValue);

        // Two presets the same (the columns of the presets file only):
        bool Same(string[] a, string[] b)
        {
            int n = Math.Min(Ncols, Math.Max(a.Length, b.Length));
            for (int i = 0; i < n; i++) if (Cell(a, i) != Cell(b, i)) return false;
            return true;
        }

        string[] Def(string[] r) => _defs.FirstOrDefault(x => x.Length > 0 && Cell(r, 0).Length > 0 && x[0] == Cell(r, 0));

        // Enabled for the presets selected (after the rules of the view):
        public void Refresh()
        {
            var sel = _sel.Select(j => _rows[j]).ToList();
            bool one = SelCount <= 1;
            if (Fam)
            {
                Enable("fam", one);
                Enable("var", one);
                Enable("vnw", one && _rows.Count > 0);
                Enable("vdl", one && _rows.Count > 0 && Def(Row) == null && Variants(FamOf(_idx)).Count > 1);
            }
            Enable("nam", one);
            Enable("cpy", one);
            Enable("del", sel.Count > 0 && sel.All(r => Def(r) == null));
            Enable("rst", sel.Any(r => Def(r) is string[] d && !Same(r, d)));
            Enable("als", one);
            Enable("aln", one);
            Enable("aad", one);
            bool picked = one && _alsList != null && _alsList.SelectedIndex >= 0;
            Enable("aren", picked);
            Enable("adel", picked);
        }

        void Enable(string key, bool on)
        {
            if (_v.Find(key) is FrameworkElement fe) fe.IsEnabled = on && !_s.Off.Contains(key);
        }

        // What the Lisp gets back (with pst/rows and pst/als, kept up to date as they are):
        void Out()
        {
            _s.Values["pst.idx"] = _idx.ToString(CultureInfo.InvariantCulture);
            _s.Values["pst.sel"] = string.Join(" ", _sel.Select(i => i.ToString(CultureInfo.InvariantCulture)));
            _s.Values["pst.shw"] = _shw;
        }

        // ---- Changes ----

        // A control changed by the user (its value already in the values):
        public void Changed(string key)
        {
            if (_rows.Count == 0) return;
            if (key == "lst") { Picked(); return; }
            if (key == "flt" || key == "srt") { Refilter(); return; }
            if (key == "shg") { ShowPicked(); return; }
            if (key == "als") { AliasPicked(); return; }
            if (key == "mgr" && _mgr != null) { MgrPicked(); return; }
            if (key == "var" && _var != null) { VarPicked(); return; }
            var f = _fields.FirstOrDefault(x => x.Key == key);
            if (f != null) FieldChanged(f);
        }

        void FieldChanged(Field f)
        {
            var r = Row;
            string val;
            switch (f.El)
            {
                case ToggleButton t:
                    val = ((t.IsChecked == true) != f.Inv) ? "1" : "0";
                    break;
                case ComboBox c:
                    var vals = f.Key == "mat" ? _matIds : f.Vals;
                    val = c.SelectedIndex >= 0 && c.SelectedIndex < vals.Count ? vals[c.SelectedIndex] : "";
                    break;
                case TextBox x:
                    val = x.Text.Trim();
                    break;
                default:
                    return;
            }
            if (f.Up) val = val.ToUpperInvariant();
            string msg = Problem(f, val);
            if (msg != null)
            {
                _bad = f.Key;
                _v.Error(msg);
                return;
            }
            if (_bad == f.Key) { _bad = null; _v.Error(""); }
            string old = Cell(r, f.Col);
            PutAll(f.Col, val, f.Key == "nam");
            if (Fam && f.Col == _famCol) { Show(); return; }
            // The columns that follow it (pst/follow), shown again:
            if (f.Col == _followCol && _followCol >= 0)
            {
                var fr = _follow.FirstOrDefault(x => x.Length > 0 && Ic.Equals(x[0], val));
                for (int k = 0; k < _followTo.Length; k++) PutAll(_followTo[k], Cell(fr, k + 1));
                Show();
                return;
            }
            // Another group: the materials of the new group (the first one given to the
            // presets selected when theirs is not one of them):
            if (f.Key == "grp" && _matCol >= 0 && !_matFree && _mgr == null && !Ic.Equals(old, val))
            {
                var inGrp = MatsOf(val);
                if (inGrp.Count > 0 && !inGrp.Any(m => m[0] == Cell(Row, _matCol))) PutAll(_matCol, inGrp[0][0]);
                Show();
                return;
            }
            State();
        }

        // Why the value val of f is not valid, null when it is:
        string Problem(Field f, string val)
        {
            if (f.Key == "nam")
            {
                if (val.Length == 0) return "The name cannot be empty.";
                if (_rows.Where((r, i) => i != _idx).Any(r => Ic.Equals(Cell(r, NameCol), val))) return "Another preset is already named \"" + val + "\".";
                return null;
            }
            if (Fam && f.Col == _famCol)
            {
                if (val.Length == 0) return "The name cannot be empty.";
                var fs = SelFams;
                if (Enumerable.Range(0, _rows.Count).Any(i => !fs.Contains(FamOf(i), Ic) && Ic.Equals(FamOf(i), val)))
                    return "Another " + One + " is already named \"" + val + "\".";
                return null;
            }
            if (f.Key == "grp" && val.Length == 0) return "The group cannot be empty.";
            if (f.Key == "mat" && !_mats.Any(m => m[0] == val)) return "This " + _matNoun + " no longer exists: pick another one.";
            if (f.El is TextBox && Win.GetCheck(f.El) is string kind && !View.Valid(kind, val))
                return Win.GetCheckMessage(f.El) ?? "This value is not valid.";
            return null;
        }

        // Before the presets selected change, the window closes or the list changes: a value
        // not valid is shown (false), unless its control is no longer enabled (its stored
        // value shown again):
        public bool Check()
        {
            if (_bad == null) return true;
            var f = _fields.FirstOrDefault(x => x.Key == _bad);
            if (f == null || !f.El.IsEnabled || !f.El.IsVisible)
            {
                _bad = null;
                _v.Error("");
                Show();
                return true;
            }
            FieldChanged(f);
            if (_bad == null) return true;
            f.El.Focus();
            if (f.El is TextBox x) x.SelectAll();
            return false;
        }

        // Lines picked in the list: the presets they show; the one shown stays when it is
        // still selected, else the first one picked:
        void Picked()
        {
            var l = _items.Where(it => _list.SelectedItems.Contains(it)).Select(it => it.Index).ToList();
            if (l.Count == 0 || !Check()) { List(); return; }
            if (Fam)
            {
                var fs = l.Select(FamOf).Distinct(Ic).ToList();
                var now = SelFams;
                if (fs.Count == now.Count && fs.All(x => now.Contains(x, Ic))) return;
                if (!fs.Contains(FamOf(_idx), Ic)) _idx = l[0];
                _sel = l;
                FamSel();
                Show();
                return;
            }
            if (l.SequenceEqual(_sel)) return;
            _sel = l;
            if (!_sel.Contains(_idx)) _idx = _sel[0];
            Show();
        }

        // The filter or the sort changed: the preset shown kept when it is listed, else the
        // first one listed:
        void Refilter()
        {
            if (_bad == null)
            {
                var m = Listed(false);
                bool listed = Fam ? m.Any(i => Ic.Equals(FamOf(i), FamOf(_idx))) : m.Contains(_idx);
                if (m.Count > 0 && !listed) { _idx = m[0]; _sel = new List<int> { _idx }; FamSel(); Show(); return; }
            }
            List();
            Out();
        }

        void ShowPicked()
        {
            int i = _shg.SelectedIndex;
            _shw = i <= 0 || i >= _shws.Count ? "" : _shws[i];
            Refilter();
        }

        // ---- Buttons ----

        public bool Click(Button b)
        {
            switch (b.Name)
            {
                case "new": if (Check()) Add(NewRow()); return true;
                case "cpy": if (Check()) Add(CopyRow()); return true;
                case "del": if (Check()) Delete(); return true;
                case "rst": Reset(); return true;
                case "all": ResetAll(); return true;
                case "shd": ShowDefault(); return true;
                case "vnw" when Fam: if (Check()) VariantAdd(); return true;
                case "vdl" when Fam: if (Check()) VariantDelete(); return true;
                case "aad": AliasAdd(); return true;
                case "aren": AliasRename(); return true;
                case "adel": AliasRemove(); return true;
            }
            // a sub-window on columns of the preset shown (not on the rows of a list, Rows.cs):
            if (Win.GetOpen(b) is string file && Win.GetColumns(b) is string cols && !(_v.Rows?.HasSub(b) ?? false))
            {
                if (Check()) Sub(b, file, cols);
                return true;
            }
            // a button of the window: the value shown must be valid first (Win.Close checks it)
            return false;
        }

        // The window file opened on the columns cols of the preset shown ("out:5,bco:6"): their
        // values as those of its keys (a list with key/vals: the index of the value); its OK
        // gives them to every preset selected the rules of the button b hold for (as Rows.Sub:
        // the lines of an assembly that has them off keep theirs), its Cancel keeps them:
        void Sub(FrameworkElement b, string file, string cols)
        {
            if (_rows.Count == 0) return;
            var map = new List<KeyValuePair<string, int>>();
            foreach (var x in cols.Split(','))
            {
                var p = x.Split(':');
                if (p.Length == 2 && p[0].Trim().Length > 0 && int.TryParse(p[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out int c) && c >= 0)
                    map.Add(new KeyValuePair<string, int>(p[0].Trim(), c));
            }
            foreach (var m in map)
            {
                string cell = Cell(Row, m.Value);
                if (_s.Lists.TryGetValue(m.Key + "/vals", out var vals))
                    _s.Values[m.Key] = Math.Max(0, vals.FindIndex(v => Ic.Equals(v, cell))).ToString(CultureInfo.InvariantCulture);
                else _s.Values[m.Key] = cell;
            }
            if (_v.OpenSub(file) == 1)
            {
                var rules = new List<string>();
                for (DependencyObject o = b; o != null && !(o is Window); o = LogicalTreeHelper.GetParent(o))
                    if (Win.GetEnabledBy(o) is string rule && rule.Trim().Length > 0) rules.Add(rule);
                foreach (var m in map)
                {
                    _s.Values.TryGetValue(m.Key, out string v);
                    if (_s.Lists.TryGetValue(m.Key + "/vals", out var vals))
                        v = int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int j) && j >= 0 && j < vals.Count ? vals[j] : Cell(Row, m.Value);
                    foreach (int i in Targets(m.Value).ToList())
                    {
                        var r = _rows[i];
                        if (rules.All(rule => View.Holds(rule, k => RowGet(r, k) ?? _v.Stored(k)))) _rows[i] = Put(r, m.Value, (v ?? "").Trim());
                    }
                }
            }
            Show();
        }

        string[] NewRow()
        {
            var r = (string[])_new.Clone();
            r = Put(r, 0, "");
            return Put(r, GroupCol, Cell(Row, GroupCol));
        }

        // A copy of the preset shown (with families: of its variant shown, a family of its own):
        string[] CopyRow()
        {
            var r = (string[])Row.Clone();
            r = Put(r, 0, "");
            return Put(r, NameCol, Cell(r, NameCol) + " copy");
        }

        // " (2)", " (3)"... when the name is taken by another preset than skip:
        string Unique(string name, int skip)
        {
            string n = name;
            for (int i = 2; _rows.Where((r, j) => j != skip).Any(r => Ic.Equals(Cell(r, NameCol), n)); i++)
                n = name + " (" + i.ToString(CultureInfo.InvariantCulture) + ")";
            return n;
        }

        // A custom preset after the one shown, its name selected:
        void Add(string[] r)
        {
            r = Put(r, NameCol, Unique(Cell(r, NameCol), -1));
            // a family of one variant, named after it:
            if (Fam) r = Put(r, _famCol, UniqueFam(Cell(r, NameCol), new int[0]));
            _idx = Math.Min(_idx + 1, _rows.Count);
            _rows.Insert(_idx, r);
            _sel = new List<int> { _idx };
            Show();
            Focus(Fam ? "fam" : "nam");
        }

        void Delete()
        {
            var sel = _sel.ToList();
            if (sel.Count == 0 || sel.Any(j => Def(_rows[j]) != null)) return;
            string msg = Fam
                ? (SelCount > 1 ? "Delete the " + SelCount + " custom " + _noun + " selected and their variants?"
                   : "Delete the custom " + One + " \"" + FamOf(_idx) + "\"" + (sel.Count > 1 ? " and its " + sel.Count + " variants" : "") + "?")
                : sel.Count > 1
                ? "Delete the " + sel.Count + " custom " + _noun + " selected" + (_cmds ? " and their aliases" : "") + "?"
                : "Delete the custom preset \"" + Cell(Row, NameCol) + "\"" + (_alst.Count > 0 ? " and its aliases" : "") + "?";
            if (!Ask(msg)) return;
            foreach (int j in sel)
            {
                string c = Command(Cell(_rows[j], 0));
                if (c != null) _als.RemoveAll(a => a.Length > 1 && Ic.Equals(a[1], c));
            }
            foreach (int j in sel.OrderByDescending(j => j)) _rows.RemoveAt(j);
            // the last one deleted: the fields show no preset (nor its rows), none selected
            if (_rows.Count == 0) { _items.Clear(); _idx = 0; _sel = new List<int>(); Show(); Out(); return; }
            _idx = Math.Min(sel.Min(), _rows.Count - 1);
            _sel = new List<int> { _idx };
            FamSel();
            Show();
        }

        // The presets whose name is now used twice renamed; keep: the index of the preset that
        // keeps its name (-1: only the custom presets are renamed):
        void Rename(int keep)
        {
            for (int i = 0; i < _rows.Count; i++)
            {
                if (i == keep || (keep < 0 && Def(_rows[i]) != null)) continue;
                string n = Cell(_rows[i], NameCol);
                if (_rows.Where((r, j) => j != i).Any(r => Ic.Equals(Cell(r, NameCol), n)))
                    _rows[i] = Put(_rows[i], NameCol, Unique(n, i));
            }
        }

        void Reset()
        {
            foreach (int j in _sel)
                if (Def(_rows[j]) is string[] d) { _rows[j] = (string[])d.Clone(); Rename(j); }
            Show();
        }

        void ResetAll()
        {
            if (!Ask("Reset every default preset to its default values? Custom presets are kept.")) return;
            for (int i = 0; i < _rows.Count; i++)
                if (Def(_rows[i]) is string[] d) _rows[i] = (string[])d.Clone();
            Rename(-1);
            Show();
        }

        // Set default: the group shown is the one the window opens on (the Lisp saves it):
        void ShowDefault()
        {
            _s.Values["pst.shd"] = "1";
            _v.Error(_title + " now opens on " + (_shw.Length == 0 ? "every group." : "the group " + _shw + "."));
        }

        // A question, OK / Cancel, in the look of the window:
        bool Ask(string msg)
        {
            var w = new Window { Title = _v.Window.Title, Owner = _v.Window };
            Theme.Apply(w, _s.Dark);
            var text = new TextBlock { Text = msg, TextWrapping = TextWrapping.Wrap, MaxWidth = 440, Margin = new Thickness(0, 0, 0, 18) };
            var ok = new Button { Content = "OK", IsDefault = true };
            ok.Click += (a, e) => { w.DialogResult = true; };
            var cancel = new Button { Content = "_Cancel", IsCancel = true };
            var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            buttons.Children.Add(ok);
            buttons.Children.Add(cancel);
            var stack = new StackPanel { Margin = new Thickness(18, 18, 18, 14), MinWidth = 320 };
            stack.Children.Add(text);
            stack.Children.Add(buttons);
            w.Content = stack;
            Reveal.Attach(w);
            return w.ShowDialog() == true;
        }

        // ---- Aliases ----

        string Acmd => Command(Cell(Row, 0));

        // The panel for the preset shown:
        void Aliases()
        {
            if (!_cmds) return;
            _alst = AliasesOf(Acmd);
            _v.Quiet(() =>
            {
                if (_alsList != null) { _alsList.ItemsSource = _alst; _alsList.SelectedIndex = -1; }
                if (_aln != null) _aln.Text = Prefix(Row);
            });
            Say(_sel.Count > 1 ? "Several presets selected: pick one to edit its aliases."
                : Acmd == null ? "New preset: adding an alias gives it its command."
                : _alst.Count == 0 ? "No alias yet: type one and click Add."
                : "Pick an alias to rename or remove it.");
        }

        void Say(string msg)
        {
            if (_ams != null) _ams.Text = msg;
        }

        void AliasPicked()
        {
            int i = _alsList.SelectedIndex;
            if (i < 0 || i >= _alst.Count) return;
            _v.Quiet(() => { if (_aln != null) _aln.Text = _alst[i]; });
            Say("");
        }

        string Typed()
        {
            string a = (_aln?.Text ?? "").Trim().ToUpperInvariant();
            return a.StartsWith("C:") ? a.Substring(2) : a;
        }

        // Why the alias a cannot be given (old: the alias renamed), null when it can:
        string AliasProblem(string a, string old)
        {
            if (a.Length == 0) return "Type an alias name.";
            if (!a.All(c => (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || c == '-' || c == '_')) return "Use letters, digits, - and _ only.";
            if (a == old) return "The name did not change.";
            if (Acmd != null && a == Acmd) return "This is the name of the command itself.";
            if (a.StartsWith("DYL-") || a.StartsWith("LM-") || a.StartsWith("PST-")) return "An alias is a short name, never a name starting with Dyl-, LM- or Pst-.";
            var x = _als.FirstOrDefault(p => p.Length > 1 && Ic.Equals(p[0], a));
            if (x != null) return a + " is already an alias of " + x[1] + ".";
            if (_taken.TryGetValue(a, out string what)) return a + " is already " + what + ".";
            return null;
        }

        void AliasDone(string msg)
        {
            Aliases();
            State();
            Say(msg);
        }

        void AliasAdd()
        {
            string a = Typed(), err = AliasProblem(a, null);
            if (err != null) { Say(err); return; }
            if (Acmd == null)
            {
                if (!Check()) return;
                GiveId(_idx);
            }
            _als.Add(new[] { a, Acmd });
            AliasDone(a + " added.");
        }

        string PickedAlias => _alsList != null && _alsList.SelectedIndex >= 0 && _alsList.SelectedIndex < _alst.Count ? _alst[_alsList.SelectedIndex] : null;

        void AliasRename()
        {
            string old = PickedAlias, a = Typed();
            if (old == null) { Say("Pick the alias to rename."); return; }
            string err = AliasProblem(a, old);
            if (err != null) { Say(err); return; }
            var p = _als.FirstOrDefault(x => x.Length > 1 && Ic.Equals(x[0], old) && Ic.Equals(x[1], Acmd));
            if (p != null) p[0] = a;
            AliasDone(old + " renamed " + a + ".");
        }

        void AliasRemove()
        {
            string old = PickedAlias;
            if (old == null) { Say("Pick the alias to remove."); return; }
            _als.RemoveAll(x => x.Length > 1 && Ic.Equals(x[0], old) && Ic.Equals(x[1], Acmd));
            AliasDone(old + " removed.");
        }
    }
}
