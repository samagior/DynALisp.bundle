// PresetTab.cs - DynALisp.Core.Data: a preset window of the Manager, its values and what it gives back
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
// A preset window shown by DynALisp.Windows.dll without the Lisp (a tab of the Manager in .NET),
// as the preset engine of Remote\Dyl-Presets.lsp ran it: what every tab does alike, the App
// part of each one in its own class (AsmTab the Assembly Presets, HatchTab the Hatch Presets,
// MatTab the Materials). Each step gives what the Lisp function it is named after gave, checked
// by the witness files (sections asmtab, hptab, mattab):
//   Init        Remote>>Dyl:PresetDialog          the presets read, the one shown, Show
//   PrepGroups  Remote>>Dyl:PresetDlgGrps         the groups of the Group list
//   Vals        Remote>>Dyl:PresetWinVals         the values of the window (the App ones by More)
//   Rows        Remote>>Dyl:PresetWinRows         the presets as the window shows them (wrow, extra)
//   Back        Remote>>Dyl:PresetWinBack         the presets of the rows got back (wget: WinGet)
//   Get         Remote>>Dyl:PresetWinGet          the presets, the list, the Show group
//   Check       Remote>>Dyl:PresetWinCheck        why a preset changed is not valid (RowCheck)
//   Put         Remote>>Dyl:PresetDlgPut          a value given to the presets selected
//   Write       the end of Remote>>Dyl:PresetDialog  the presets written when they changed

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    // A value of a window, as the Lisp gave it to Dyl:Window: a text, a list (its key ends with
    // /list or /vals) or a table (its rows), in the order they are given:
    public sealed class WinVal
    {
        public string Key, Text;
        public List<string> List;
        public List<string[]> Rows;

        public static WinVal S(string key, string text) => new WinVal { Key = key, Text = text ?? "" };
        public static WinVal L(string key, IEnumerable<string> items) => new WinVal { Key = key, List = items.ToList() };
        public static WinVal R(string key, IEnumerable<string[]> rows) => new WinVal { Key = key, Rows = rows.ToList() };
    }

    public abstract class PresetTab
    {
        // *pst:sorts*:
        public static readonly string[] Sorts = { "Name", "Group" };

        // *mt:weights*: the lineweights of AutoCAD, in hundredths of mm:
        public static readonly string[] Weights = { "0", "5", "9", "13", "15", "18", "20", "25", "30", "35", "40", "50", "53", "60", "70", "80", "90",
                                                    "100", "106", "120", "140", "158", "200", "211" };

        // The spec of the tool (*dyl:presetspecs*), the kind of its groups (nil: those of the
        // presets), its title and what its presets are called (noun), a new preset (new), the
        // controls of its values and their column (the tiles of its App part, then those of the
        // window, see Remote>>Dyl:PresetWinTiles), the columns the window compares (wncols):
        public abstract PresetSpec Tool { get; }
        protected virtual string GroupKind => null;
        protected abstract string Title { get; }
        protected abstract string Noun { get; }
        public abstract string[] NewRow { get; }
        protected abstract string TilesText { get; }
        protected virtual int NCols => Cols;

        // The columns of a preset in the file:
        public int Cols => Tool.Header.Length;

        // What the window is opened on: the bundle, the units of the drawing, the names of the
        // layer keys defined (Remote>>Dyl:LayerKeyRead, in its order):
        public readonly Bundle B;
        public readonly Units U;
        public List<string> Defined;

        // pst:* of Remote>>Dyl:PresetDialog: the presets edited, as read, the defaults, the
        // preset shown, those selected, the filter, the sort, the Show group; the rows last
        // sent and the presets they were made from; the groups of the Group list (pst:grps):
        public List<string[]> Lst, Lst0, Defs, Sent, SentOf;
        public int Idx;
        public List<int> Sel;
        public string Flt = "", Srt = "Name", Shw = "";
        public List<string> Grps;

        protected PresetTab(Bundle b, Units u, List<string> defined)
        {
            B = b;
            U = u;
            Defined = defined ?? new List<string>();
        }

        // (Remote>>Dyl:PresetDialog key dlg) up to the window: the presets lst, the defaults defs,
        // the preset shown that of id select (else the one shown last, last, else the first),
        // the Show group shw (the DynalispPresetShow<tool> setting: All when no preset is in
        // it), the sort srt of the session:
        protected void Init(List<string[]> lst, List<string[]> defs, string select, int? last, string shw, string srt)
        {
            Lst = lst;
            Lst0 = lst;
            Defs = defs;
            Srt = Sorts.Contains(srt) ? srt : "Name";
            Flt = "";
            int pos = select != null ? lst.FindIndex(r => r[0] == select) : -1;
            Idx = Math.Max(0, Math.Min(pos >= 0 ? pos : last ?? 0, lst.Count - 1));
            Sel = new List<int> { Idx };
            Shw = shw ?? "";
            if (!lst.Any(InShow)) Shw = "";
            if (select == null && Idx < lst.Count && !InShow(lst[Idx]))
            {
                Idx = View().First();
                Sel = new List<int> { Idx };
            }
        }

        // (Remote>>Dyl:PresetDlgInShow-p r):
        bool InShow(string[] r) => Shw == "" || Lisp.SameCase(Shw, Lisp.Nth(r, 1));

        // (Remote>>Dyl:PresetDlgView nil): the indexes of the presets of the Show group and of the
        // filter, in the order of the sort (the same key: the file order). A tool without
        // commands, its line its group and its name:
        protected List<int> View()
        {
            string f = Lisp.StrCase((Flt ?? "").Trim(' '));
            var lst = new List<int>();
            for (int i = 0; i < Lst.Count; i++)
            {
                var r = Lst[i];
                string line = Lisp.StrCase(Lisp.Nth(r, 1) + "\t" + Lisp.Nth(r, 2) + "\t" + (Lisp.Nth(r, 3) ?? ""));
                if (InShow(r) && (f == "" || line.Contains(f))) lst.Add(i);
            }
            Func<int, string> key = i => Lisp.StrCase(Srt == "Group" ? Lst[i][1] + "\t" + Lst[i][2] : Lst[i][2]);
            return lst.OrderBy(key, StringComparer.Ordinal).ThenBy(i => i).ToList();
        }

        // The renames of the groups of the presets made in the Preset Groups window ((old new)
        // ..., Remote>>Dyl:PresetDlgGroupsSync): given to the presets edited, to those as read
        // and to the Show group:
        public void Renamed(IEnumerable<(string Old, string New)> pairs)
        {
            var ps = pairs.ToList();
            if (ps.Count == 0) return;
            string Of(string g)
            {
                foreach (var p in ps) if (Lisp.SameCase(p.Old, g)) return p.New;
                return g;
            }
            string[] Row(string[] r) => Lisp.Subst(r, 1, Of(r[1]));
            Lst = Lst.Select(Row).ToList();
            Lst0 = Lst0.Select(Row).ToList();
            if (Shw != "") Shw = Of(Shw);
        }

        // (Remote>>Dyl:PresetDlgGrps): the groups of its kind, then the others the presets use:
        protected void PrepGroups()
        {
            Grps = Groups.Of(B, GroupKind).ToList();
            foreach (var r in Lst) if (!Grps.Contains(r[1])) Grps.Add(r[1]);
        }

        // (Remote>>Dyl:PresetWinPrep): what the window is made from, before it is shown:
        public abstract void Prep();

        // (Remote>>Dyl:LayerKeyMaterial-p key): a key a material may have (*lk:nomaterial*):
        protected static bool MaterialKey(string k) => !Lisp.Wcmatch(Lisp.StrCase(k), "G-DS-ANNO-STD-*");

        // (Remote>>Dyl:MaterialDlgKeys nil used): the layer keys defined that a material may have,
        // then those used that are not, sorted in any case:
        protected List<string> KeysOf(IEnumerable<string> used)
        {
            var keys = Defined.Where(MaterialKey).ToList();
            foreach (var k in used)
                if (!string.IsNullOrEmpty(k) && !keys.Contains(k) && MaterialKey(k)) keys.Add(k);
            return keys.OrderBy(Lisp.StrCase, StringComparer.Ordinal).ToList();
        }

        // The layer keys of a list, those not defined marked:
        protected List<string> Marked(IEnumerable<string> keys) =>
            keys.Select(k => Defined.Contains(k) ? k : k + "   (not defined)").ToList();

        // (Remote>>Dyl:PresetWinRows lst): each preset as the window shows it (wrow), with the
        // columns it adds (extra); as it is when the App has neither:
        public virtual List<string[]> Rows(IEnumerable<string[]> lst) => lst.ToList();

        // (Remote>>Dyl:PresetWinVals err): the values of the window, those of the App (More) after
        // the groups; err the message shown (null: none). The rows sent are kept (Sent, SentOf)
        // for Back:
        public List<WinVal> Vals(string err)
        {
            SentOf = Lst;
            Sent = Rows(Lst);
            int srt = Array.IndexOf(Sorts, Srt);
            var res = new List<WinVal>
            {
                WinVal.R("pst/rows", Sent),
                WinVal.R("pst/defs", Rows(Defs)),
                WinVal.R("pst/new", Rows(new[] { NewRow })),
                WinVal.S("pst/ncols", NCols.ToString()),
                WinVal.S("pst/tiles", TilesText),
                WinVal.S("pst.idx", Idx.ToString()),
                WinVal.S("pst.sel", string.Join(" ", SelOf())),
                WinVal.S("pst.shw", Shw),
                WinVal.S("flt", Flt ?? ""),
                WinVal.S("pst/title", Title),
                WinVal.S("pst/noun", Noun),
                WinVal.S("error", err ?? ""),
                WinVal.L("srt/list", Sorts),
                WinVal.S("srt", (srt < 0 ? 0 : srt).ToString()),
            };
            if (Grps != null && Grps.Count > 0) res.Add(WinVal.L("grp/list", Grps));
            More(res);
            return res;
        }

        // The values of the App part, after those of every preset window:
        protected abstract void More(List<WinVal> res);

        // (Remote>>Dyl:PresetDlgSel): the presets selected, the one shown with them:
        protected List<int> SelOf() => Sel.Contains(Idx) ? Sel : new List<int> { Idx };

        // ----- what the window gives back -----

        // (Remote>>Dyl:PresetWinBack rows n): the presets of the rows got back. A row as it was
        // sent (at the same place, or with the same id) is the preset it was made from, as it
        // was read; the others through WinGet (wget), cut to the columns of the file:
        public List<string[]> Back(List<string[]> rows)
        {
            var sent = Sent ?? new List<string[]>();
            var orig = SentOf ?? new List<string[]>();
            var ids = new List<(string Id, string[] S, string[] O)>();
            for (int i = 0; i < sent.Count && i < orig.Count; i++) ids.Add((sent[i][0], sent[i], orig[i]));
            var res = new List<string[]>(rows.Count);
            for (int k = 0; k < rows.Count; k++)
            {
                var r = rows[k];
                var s = k < sent.Count ? sent[k] : null;
                var o = k < orig.Count ? orig[k] : null;
                if (o != null && Same(r, s)) { res.Add(o); continue; }
                if (Lisp.Nth(r, 0) != "" && r.Length > 0)
                {
                    int h = ids.FindIndex(x => x.Id == r[0]);
                    if (h >= 0 && Same(r, ids[h].S)) { res.Add(ids[h].O); continue; }
                }
                res.Add(Cut(WinGet(r), Cols));
            }
            return res;
        }

        protected static bool Same(string[] a, string[] b) =>
            ReferenceEquals(a, b) || (a != null && b != null && a.SequenceEqual(b, StringComparer.Ordinal));

        // (Remote>>Dyl:PresetWinCut r n):
        static string[] Cut(string[] r, int n)
        {
            var res = new string[n];
            for (int i = 0; i < n; i++) res[i] = Lisp.Nth(r, i) ?? "";
            return res;
        }

        // (wget r) of the App: a row got back, edited or added, as a preset (before it is cut to
        // the columns of the file):
        protected virtual string[] WinGet(string[] r) => r;

        // (Remote>>Dyl:PresetWinGet res): the presets of the rows got back (null: the window
        // gave no table), the preset shown and those selected, the filter, the Show group and
        // the sort:
        public void Get(List<string[]> rows, string idx, string sel, string flt, string shw, string srt)
        {
            if (rows != null)
            {
                Lst = Back(rows);
                int.TryParse(idx ?? "0", out int i);
                Idx = Math.Max(0, Math.Min(i, Lst.Count - 1));
                var s = new List<int>();
                foreach (var x in (sel ?? "").Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries))
                    if (int.TryParse(x, out int k) && k >= 0 && k < Lst.Count) s.Add(k);
                Sel = s.Contains(Idx) ? s : new List<int> { Idx };
            }
            Flt = flt ?? "";
            if (shw != null) Shw = shw;
            int.TryParse(srt ?? "", out int si);
            Srt = si >= 0 && si < Sorts.Length ? Sorts[si] : "Name";
        }

        // Why the preset r is not valid (null: it is): the check of the App on each value of its
        // tiles ((check key val), Checks), in their order, then its rowcheck:
        public virtual string RowCheck(string[] r)
        {
            foreach (var (key, col) in Checks)
                if (ValueCheck(key, Lisp.Nth(r, col)) is string m) return m;
            return null;
        }

        // The tiles of the App part checked, (key column) in their order (the tiles of its
        // spec, never the name, the group nor the material):
        protected virtual (string Key, int Col)[] Checks => new (string, int)[0];

        // (check key val) of the App:
        protected virtual string ValueCheck(string key, string val) => null;

        // (Remote>>Dyl:PresetWinCheck): the message of the first preset changed since the window
        // opened that is not valid, its name first, the preset shown and selected (null: all
        // are valid):
        public string Check()
        {
            for (int i = 0; i < Lst.Count; i++)
            {
                var r = Lst[i];
                // (a preset not edited is the one read, at the same place: found at once)
                if ((i < Lst0.Count && Same(Lst0[i], r)) || Lst0.Any(x => Same(x, r))) continue;
                var m = RowCheck(r);
                if (m == null) continue;
                Idx = i;
                Sel = new List<int> { i };
                return Lisp.Nth(r, 2) + ": " + m;
            }
            return null;
        }

        // (Remote>>Dyl:PresetDlgPut i val): the value val given to the column i of every preset
        // selected:
        public void Put(int i, string val)
        {
            foreach (int j in SelOf())
                if (j >= 0 && j < Lst.Count)
                {
                    var l = new List<string[]>(Lst);
                    l[j] = Lisp.Subst(l[j], i, val);
                    Lst = l;
                }
        }

        // The presets selected in the order of the list, then those selected that it does not
        // show (Remote>>Dyl:MaterialDlgSelected), the presets being edited:
        public List<string[]> Selected()
        {
            var sel = SelOf();
            var view = View();
            return view.Where(sel.Contains).Concat(sel.Where(i => !view.Contains(i)))
                       .Where(i => i >= 0 && i < Lst.Count).Select(i => Lst[i]).ToList();
        }

        // The presets of each group in upper case (Remote>>Dyl:PresetDlgGroupCounts), for the
        // Preset Groups window:
        public List<(string Group, int Count)> GroupCounts()
        {
            var res = new List<(string, int)>();
            foreach (var r in Lst)
            {
                string g = Lisp.StrCase(Lisp.Nth(r, 1) ?? "");
                int k = res.FindIndex(x => x.Item1 == g);
                if (k >= 0) res[k] = (g, res[k].Item2 + 1); else res.Add((g, 1));
            }
            return res;
        }

        // The presets given their ids (Remote>>Dyl:PresetIds), written when they changed (the
        // end of Remote>>Dyl:PresetDialog on OK or Save): true once written, false when they
        // cannot be (open in Excel), null when nothing changed:
        public bool? Write()
        {
            Lst = Presets.Ids(Lst);
            if (Lst.Count == Lst0.Count && Lst.Zip(Lst0, Same).All(x => x)) return null;
            return Presets.Write(B, Tool, Lst);
        }

        // The preset shown (null: none):
        public string[] Shown => Idx >= 0 && Idx < Lst.Count ? Lst[Idx] : null;

        // ----- what the checks of the materials share -----

        // (wcmatch v "#,##..."): v of min to max digits:
        protected static bool IsDigits(string v, int min, int max) =>
            v != null && v.Length >= min && v.Length <= max && v.All(c => c >= '0' && c <= '9');

        // (Remote>>Dyl:MaterialColorParse s): (n) for an AutoCAD color 1-255, (r g b) for
        // "r,g,b", null when it is not one:
        public static int[] ColorParse(string s)
        {
            s = (s ?? "").Trim(' ');
            if (IsDigits(s, 1, 3) && int.Parse(s) is int n && n >= 1 && n <= 255) return new[] { n };
            var l = s.Split(',');
            if (l.Length == 3 && l.All(x => IsDigits(x.Trim(' '), 1, 3) && int.Parse(x.Trim(' ')) <= 255))
                return l.Select(x => int.Parse(x.Trim(' '))).ToArray();
            return null;
        }
    }
}
