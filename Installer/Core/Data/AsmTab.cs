// AsmTab.cs - DynALisp.Core.Data: the Assembly Presets window, its values and what it gives back
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
// The Assembly Presets window (Res\Dyl-AssemblyPresets.xaml, the tab Assemblies of the Manager
// and the open button of Assembly of Quick Draw), as the preset engine of
// Remote\Dyl-Presets.lsp ran it on the spec of Apps\Draw\Dyl-QuickDraw.lsp, now shown by
// DynALisp.Windows.dll (Bridge.cs, Dyl:AsmWindow) without the Lisp: the values of the window,
// the presets got back from it, checked, and written. Each step gives what the Lisp function it
// is named after gave, checked by the witness files (sections asmtab). That Lisp (the spec of
// the window and its functions in Dyl-QuickDraw.lsp) is gone: what it gave is kept in
// Installer\Core\Tests\Witness\Kept, and git keeps its code:
//   AsmTab.Open    Remote>>Dyl:PresetDialog          the presets read, the one shown, Show
//   AsmTab.Prep    Remote>>Dyl:PresetWinPrep and     the groups, the materials, the layer keys,
//                  Dyl:QuickDrawAsmWinPrep           the row Add starts from
//   AsmTab.Vals    Remote>>Dyl:PresetWinVals and     the values of the window
//                  Dyl:QuickDrawAsmWinVals
//   AsmTab.Back    Remote>>Dyl:PresetWinBack and     the presets of the rows got back
//                  Dyl:QuickDrawAsmWinGet
//   AsmTab.Get     Remote>>Dyl:PresetWinGet          the presets, the list, the Show group
//   AsmTab.Check   Remote>>Dyl:PresetWinCheck and    why a preset changed is not valid
//                  Dyl:QuickDrawAsmCheck
//   AsmTab.Write   the end of Remote>>Dyl:PresetDialog  the presets written when they changed
//   AsmTab.LayersOf  Dyl:QuickDrawLayersOf           the layers of the rows of the window
// What stays in the Lisp: the layer keys (LayerKeys.csv, their names given), the units of the
// patterns (found by AutoCAD on its support path), the Preset Groups window (status 8), a
// materials file of DynALisp 1.1 (split by the Lisp before the window opens) and the
// assemblies of an older file made of a Quick Draw preset (read by the Lisp, given to Open).

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

    public sealed class AsmTab
    {
        public static PresetSpec Spec => Presets.QuickDrawAssembly;

        // *pst:sorts*:
        public static readonly string[] Sorts = { "Name", "Group" };

        // The columns of a preset in the file:
        public static int Cols => Spec.Header.Length;

        // What the window is opened on: the bundle, the units of the drawing, the names of the
        // layer keys defined (Remote>>Dyl:LayerKeyRead, in its order), the layer key of the
        // border of the Quick Draw preset it was opened from (null: from no preset), the units
        // of a pattern (Remote>>Dyl:MaterialPatUnits):
        public readonly Bundle B;
        public readonly Units U;
        public readonly List<string> Defined;
        public readonly string QdBorder;
        public readonly Shows.PatUnits Pats;

        // pst:* of Remote>>Dyl:PresetDialog: the presets edited, as read, the defaults, the
        // preset shown, those selected, the filter, the sort, the Show group; the rows last
        // sent and the presets they were made from:
        public List<string[]> Lst, Lst0, Defs, Sent, SentOf;
        public int Idx;
        public List<int> Sel;
        public string Flt = "", Srt = "Name", Shw = "";

        // What Prep makes: the groups of the Group list (pst:grps), the materials of the
        // Material list (qa:mats, qa:grps), the layer keys (mt:keys), the layer key of new
        // lines (qa:bk), the row Add starts from (qa:def):
        public List<string> Grps, Keys;
        public AsmWindow.Lists Mats;
        public string Bk = "";
        public string[] Def;

        AsmTab(Bundle b, Units u, List<string> defined, string qdBorder, Shows.PatUnits pats)
        {
            B = b;
            U = u;
            Defined = defined ?? new List<string>();
            QdBorder = qdBorder;
            Pats = pats ?? (p => null);
        }

        // (Remote>>Dyl:PresetRead "QuickDrawAssembly" (Dyl:QuickDrawAsmDefs) 'Dyl:QuickDrawAsmFix):
        // the presets as saved, fixed, the defaults missing added, in millimetres; null when the
        // Lisp reads them (a layer made of a Quick Draw preset, see Assemblies.NeedsLisp) or the
        // materials (a materials file of DynALisp 1.1, a default file missing). The assemblies
        // read unscaled (the factor 1: Assemblies.Scale leaves them as they are):
        public static List<string[]> Read(Bundle b, int dimzin) =>
            Materials.Both(b, dimzin) == null ? null : Assemblies.Read(b, 1.0, dimzin);

        // The patterns of the materials joined to their Cut hatch preset (upper case, SOLID and
        // none left out), whose units the Lisp gives for the previews of the Material list (see
        // Vals); null when the Lisp reads the materials:
        public static List<string> Patterns(Bundle b, int dimzin)
        {
            var both = Materials.Both(b, dimzin);
            if (both == null) return null;
            var res = new SortedSet<string>(StringComparer.Ordinal);
            foreach (var m in both.Value.Rows)
            {
                string p = Lisp.StrCase(Shows.Join(m, both.Value.Hatches)[3]);
                if (p != "" && p != "SOLID") res.Add(p);
            }
            return res.ToList();
        }

        // (Remote>>Dyl:PresetDialog "QuickDrawAssembly" (Dyl:QuickDrawAsmDlg r)) up to the window:
        // the presets (rows: those the Lisp read, null: read here), the preset shown that of id
        // select (else the one shown last, last, else the first), the Show group shw (the
        // DynalispPresetShowQuickDrawAssembly setting: All when no preset is in it), the sort
        // srt of the session. null when the Lisp reads the presets or the materials (see Read):
        public static AsmTab Open(Bundle b, Units u, List<string[]> rows, string select, int? last, string shw, string srt,
                                  List<string> defined, string qdBorder, Shows.PatUnits pats)
        {
            if (Materials.Both(b, u.Dimzin) == null) return null;
            var lst = rows ?? Read(b, u.Dimzin);
            if (lst == null) return null;
            var t = new AsmTab(b, u, defined, qdBorder, pats)
            {
                Lst = lst,
                Lst0 = lst,
                Defs = Assemblies.Defs(b),
                Srt = Sorts.Contains(srt) ? srt : "Name",
                Flt = "",
            };
            int pos = select != null ? lst.FindIndex(r => r[0] == select) : -1;
            t.Idx = Math.Max(0, Math.Min(pos >= 0 ? pos : last ?? 0, lst.Count - 1));
            t.Sel = new List<int> { t.Idx };
            t.Shw = shw ?? "";
            if (!lst.Any(t.InShow)) t.Shw = "";
            if (select == null && t.Idx < lst.Count && !t.InShow(lst[t.Idx]))
            {
                t.Idx = t.View().First();
                t.Sel = new List<int> { t.Idx };
            }
            return t;
        }

        // (Remote>>Dyl:PresetDlgInShow-p r):
        bool InShow(string[] r) => Shw == "" || Lisp.SameCase(Shw, Lisp.Nth(r, 1));

        // (Remote>>Dyl:PresetDlgView nil): the indexes of the presets of the Show group and of the
        // filter, in the order of the sort (the same key: the file order):
        List<int> View()
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

        // (Remote>>Dyl:PresetWinPrep) with (Dyl:QuickDrawAsmWinPrep): the groups of the Group
        // list (those of the presets, then the others the presets use), the materials of the
        // Material list of a layer, the layer keys (those defined that a material may have,
        // then those the assemblies use that are not, sorted in any case), the layer key of
        // new lines (that of the border of the Quick Draw preset when it is one of them, else
        // the first one) and the row Add starts from:
        public void Prep()
        {
            Grps = Groups.Of(B, null).ToList();
            foreach (var r in Lst) if (!Grps.Contains(r[1])) Grps.Add(r[1]);
            Mats = AsmWindow.Mats(B, U.Dimzin, Lst.Select(a => new[] { a[3], a[4], a[5] }));
            Keys = Defined.Where(MaterialKey).ToList();
            foreach (var k in Mats.Used)
                if (!string.IsNullOrEmpty(k) && !Keys.Contains(k) && MaterialKey(k)) Keys.Add(k);
            Keys = Keys.OrderBy(Lisp.StrCase, StringComparer.Ordinal).ToList();
            Bk = QdBorder != null && Keys.Contains(QdBorder) ? QdBorder : Keys.FirstOrDefault() ?? "";
            Def = AsmWindow.Def(Mats.Mats, Bk);
        }

        // (Remote>>Dyl:LayerKeyMaterial-p key): a key a material may have (*lk:nomaterial*):
        static bool MaterialKey(string k) => !Lisp.Wcmatch(Lisp.StrCase(k), "G-DS-ANNO-STD-*");

        // The groups of the materials by id in any case (Dyl:QuickDrawAsmMatGroup), for the rows:
        Func<string, string> GroupOf()
        {
            var groups = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var m in Mats.Mats)
            {
                var k = Lisp.StrCase(m.Id);
                if (!groups.ContainsKey(k)) groups[k] = m.Group;
            }
            return id => groups.TryGetValue(Lisp.StrCase(id ?? ""), out var g) ? g : "";
        }

        // (Remote>>Dyl:PresetWinRows lst): each preset with the columns the window adds
        // (Dyl:QuickDrawAsmExtra):
        public List<string[]> Rows(IEnumerable<string[]> lst)
        {
            var group = GroupOf();
            return lst.Select(r => r.Concat(AsmWindow.Extra(new[] { r[3], r[4], r[5], Lisp.Nth(r, 7) ?? "" }, U.Factor, U.Dimzin, Def, Bk, group)).ToArray())
                      .ToList();
        }

        // The new preset ((new ...) of Dyl:QuickDrawAsmDlg): a wall of no layers, its Border
        // lines and Dividing lines on:
        public static readonly string[] New = { "", "Wall", "New assembly", "", "1~", "1~", "First", "", "", "", "", "", "", "New assembly", "" };

        // The controls of the values and their column (Remote>>Dyl:PresetWinTiles):
        public const string Tiles = "nam:2,grp:1,aex:6,ads:8,afl:9,afn:10,ast:11,aii:12,fam:13,fds:14,abl:16,adl:28";

        // *qd:layerhatch*, *mt:ends*, *mt:corners*, *mt:laps*, *mt:joints*: the lists of the Band
        // Settings window of a layer, (key label), without Ask:
        static readonly (string, string)[] HatchModes = { ("Line", "Layer center"), ("Edge", "Layer edge"), ("Origin", "Drawing origin") };
        static readonly (string Key, (string, string)[] Items)[] BandLists =
        {
            ("men", new[] { ("Square", "Square"), ("Open", "Open"), ("Extended", "Extended"), ("Round", "Round"), ("Angled", "Angled") }),
            ("mco", new[] { ("Mitered", "Mitered"), ("Beveled", "Beveled"), ("Round", "Round"), ("Lapped", "Lapped") }),
            ("mlt", new[] { ("First", "First segment"), ("Second", "Next segment") }),
            ("mjo", new[] { ("Interrupted", "Interrupted"), ("Uninterrupted", "Uninterrupted") }),
        };

        // *mt:weights*: the lineweights of AutoCAD, in hundredths of mm:
        static readonly string[] Weights = { "0", "5", "9", "13", "15", "18", "20", "25", "30", "35", "40", "50", "53", "60", "70", "80", "90",
                                             "100", "106", "120", "140", "158", "200", "211" };

        // (Dyl:QuickDrawUnitInches): the inches of a drawing unit:
        double UnitInches =>
            U.Insunits == 1 ? 1.0 : U.Insunits == 2 ? 12.0 : U.Insunits == 4 ? 1.0 / 25.4 : U.Insunits == 5 ? 1.0 / 2.54
            : U.Insunits == 6 ? 1000.0 / 25.4 : U.Measurement == 1 ? 1.0 / 25.4 : 1.0;

        // (Remote>>Dyl:PresetWinVals err) on the spec of Dyl:QuickDrawAsmDlg, its wvals
        // (Dyl:QuickDrawAsmWinVals) last; err the message shown (null: none). The rows sent are
        // kept (Sent, SentOf) for Back:
        public List<WinVal> Vals(string err)
        {
            SentOf = Lst;
            Sent = Rows(Lst);
            var mats = Mats.Mats;
            var both = Materials.Both(B, U.Dimzin).Value;
            var data = AsmWindow.Data(B, U, mats.Select(m => m.Id)).Value;
            var mark = Keys.Select(k => Defined.Contains(k) ? k : k + "   (not defined)").ToList();
            int srt = Array.IndexOf(Sorts, Srt);
            var res = new List<WinVal>
            {
                WinVal.R("pst/rows", Sent),
                WinVal.R("pst/defs", Rows(Defs)),
                WinVal.R("pst/new", Rows(new[] { New })),
                WinVal.S("pst/ncols", "16"),
                WinVal.S("pst/tiles", Tiles),
                WinVal.S("pst.idx", Idx.ToString()),
                WinVal.S("pst.sel", string.Join(" ", SelOf())),
                WinVal.S("pst.shw", Shw),
                WinVal.S("flt", Flt ?? ""),
                WinVal.S("pst/title", "Assembly Presets"),
                WinVal.S("pst/noun", "assemblies"),
                WinVal.S("error", err ?? ""),
                WinVal.L("srt/list", Sorts),
                WinVal.S("srt", (srt < 0 ? 0 : srt).ToString()),
            };
            if (Grps.Count > 0) res.Add(WinVal.L("grp/list", Grps));
            res.Add(WinVal.S("pst/family", "13,14"));
            res.Add(WinVal.S("pst/famcols", "6,16-39"));
            res.Add(WinVal.S("pst/famlabel", "9:min,10:NLB:min,11:STC,12:IIC"));
            res.Add(WinVal.R("ll/new", new[] { Def }));
            res.Add(WinVal.L("lg/list", Mats.Groups));
            res.Add(WinVal.L("lg/vals", Mats.Groups));
            res.Add(WinVal.L("lp/list", mats.Select(m => m.Name)));
            res.Add(WinVal.L("lp/vals", mats.Select(m => m.Id)));
            res.Add(WinVal.L("lp/by/list", mats.Select(m => m.Group)));
            res.Add(WinVal.L("hky/list", new[] { "From material" }.Concat(mark)));
            res.Add(WinVal.L("hky/vals", new[] { "" }.Concat(Keys)));
            res.Add(WinVal.L("out/list", mark));
            res.Add(WinVal.L("out/vals", Keys));
            res.Add(WinVal.L("bwt/list", Weights.Select(w => Lisp.Rtos(int.Parse(w) / 100.0, 2, U.Dimzin) + " mm")));
            res.Add(WinVal.L("bwt/vals", Weights));
            res.Add(WinVal.S("sub", "1"));
            res.Add(WinVal.L("lp/specs/list", mats.Select(m =>
                m.Row < 0 ? "X?1" : Shows.Band("P", Shows.Join(both.Rows[m.Row], both.Hatches), 1.0, U, Pats))));
            res.Add(WinVal.L("ll/ends/list", new[] { AsmWindow.LayerBand[1], AsmWindow.LayerBand[2], AsmWindow.LayerBand[3] }));
            res.Add(WinVal.L("ll/paper/list", new[] { Lisp.NumP(UnitInches, 10, U.Dimzin), Lisp.NumP(U.DrawScale, 4, U.Dimzin) }));
            res.Add(WinVal.S("mth", "Layer"));
            res.Add(WinVal.L("lp/rsi/list", data.Rsi));
            res.Add(WinVal.L("lp/mass/list", data.Mass));
            res.Add(WinVal.L("lfm/list", new[] { "None" }.Concat(mats.Select(m => m.Name))));
            res.Add(WinVal.L("lfm/vals", new[] { "" }.Concat(mats.Select(m => m.Id))));
            res.Add(WinVal.L("lfm/rsi/list", new[] { "" }.Concat(data.Rsi)));
            res.Add(WinVal.L("lfm/mass/list", new[] { "" }.Concat(data.Mass)));
            res.Add(WinVal.S("mt.imp", U.Imperial ? "1" : "0"));
            res.Add(WinVal.L("aex/list", new[] { "First layer", "Last layer" }));
            res.Add(WinVal.L("aex/vals", new[] { "First", "Last" }));
            res.Add(WinVal.L("mht/list", HatchModes.Select(x => x.Item2)));
            res.Add(WinVal.L("mht/vals", HatchModes.Select(x => x.Item1)));
            foreach (var (key, items) in BandLists)
            {
                res.Add(WinVal.L(key + "/list", items.Select(x => x.Item2)));
                res.Add(WinVal.L(key + "/vals", items.Select(x => x.Item1)));
            }
            if (mats.Count == 0) res.Add(WinVal.S("lp/off", "1"));
            if (Mats.Groups.Count == 0) res.Add(WinVal.S("lg/off", "1"));
            if (Keys.Count == 0) res.Add(WinVal.S("out/off", "1"));
            return res;
        }

        // (Remote>>Dyl:PresetDlgSel): the presets selected, the one shown with them:
        List<int> SelOf() => Sel.Contains(Idx) ? Sel : new List<int> { Idx };

        // ----- what the window gives back -----

        // (Remote>>Dyl:PresetWinBack rows n): the presets of the rows got back. A row as it was
        // sent (at the same place, or with the same id) is the preset it was made from, as it
        // was read; the others through Get (wget), cut to the columns of the file:
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

        static bool Same(string[] a, string[] b) =>
            ReferenceEquals(a, b) || (a != null && b != null && a.SequenceEqual(b, StringComparer.Ordinal));

        // (Remote>>Dyl:PresetWinCut r n):
        static string[] Cut(string[] r, int n)
        {
            var res = new string[n];
            for (int i = 0; i < n; i++) res[i] = Lisp.Nth(r, i) ?? "";
            return res;
        }

        // (Dyl:QuickDrawAsmWinGet r): its layers from its rows (column 15), back in millimetres
        // for an assembly in millimetres, or its rows themselves in its column 3 when one is not
        // valid; its lines from their columns (their layer key and linetype in upper case); its
        // ratings, its family and its description trimmed:
        string[] WinGet(string[] r)
        {
            var (layers, msg) = LayersOf(Decode(Lisp.Nth(r, 15) ?? ""), Def);
            r = Lisp.Subst(r, 3, msg != null ? Lisp.Nth(r, 15) : Assemblies.LayersStr(layers));
            r = Assemblies.Scale(r, 1.0 / U.Factor, 4, U.Dimzin);
            for (int i = 8; i <= 14; i++)
                if (Lisp.Nth(r, i) != null) r = Lisp.Subst(r, i, r[i].Trim(' '));
            if (Lisp.Nth(r, 39) != null)
                foreach (var (col, from) in new[] { (4, 16), (5, 28) })
                {
                    var b = new string[12];
                    for (int i = 0; i < 12; i++)
                    {
                        string v = Lisp.Nth(r, from + i);
                        b[i] = i == 1 || i == 5 ? Lisp.StrCase(v) : v;
                    }
                    r = Lisp.Subst(r, col, Assemblies.LinesStr(b));
                }
            return r;
        }

        // (Dyl:QuickDrawAsmDecode str): the rows of the layers of the window (a row on each line,
        // its columns divided by tabs), the lines blank left out:
        public static List<string[]> Decode(string str) =>
            str.Split('\n').Where(l => l.Trim(' ', '\t', '\r') != "").Select(l => l.Split('\t')).ToList();

        // *qd:layerband*: the band settings of a layer when they are the defaults (its last 13
        // values, after On):
        static readonly string[] LayerBand = AsmWindow.LayerBand.Concat(Assemblies.LayerScale).ToArray();

        static string[] Sub(string[] a, int i, int n) => a.Skip(i).Take(n).ToArray();

        // (Dyl:QuickDrawLayersOf rows def): the layers of the rows of the window, or the message
        // of the first one not valid:
        public static (List<Layer> Layers, string Msg) LayersOf(List<string[]> rows, string[] def)
        {
            var res = new List<Layer>();
            foreach (var row in rows)
            {
                var r = row.Length >= def.Length ? row : row.Concat(def.Skip(row.Length)).ToArray();
                var b = Sub(r, 5, 9).Concat(Sub(r, 38, 5)).ToArray();
                var d = Sub(r, 14, 2).Concat(Sub(r, 17, 10)).ToArray();
                var h = Sub(r, 27, 11);
                if (h.Length < 11) h = Sub(def, 27, 11);
                string msg = null;
                if (!Assemblies.ScaleP(r[2])) msg = "The thickness must be a number greater than 0.";
                else if (r[1] == "") msg = "No material: add one in the Materials window.";
                else if (r[44] != "" && !Assemblies.ShareP(r[45])) msg = "The framing must be a percentage greater than 0 and less than 100.";
                else if (b[0] == "1" && (msg = First(("mex", b[3]), ("mea", b[4]), ("mml", b[6]))) != null) { }
                else if (b[0] == "1" && (msg = First(b[9] == "1" ? ("mfc", b[10]) : default, b[11] == "1" ? ("moa", b[12]) : default,
                                                     b[11] == "1" ? ("mof", b[13]) : default)) != null) { }
                else if (d[0] == "1" && d[1] == "") msg = "No layer key for the border: add one in the Layer Keys window.";
                else if (h[0] == "1" && (msg = Overrides(h, 1)) != null) { }
                else if (d[0] == "1" && (msg = Overrides(d, 2)) != null) { }
                if (msg != null) return (null, msg);
                res.Add(new Layer
                {
                    Kind = "P",
                    Ref = r[1],
                    Thick = r[2],
                    HatchKey = r[3],
                    Band = b[0] == "1" || !b.Skip(1).SequenceEqual(LayerBand, StringComparer.Ordinal) ? b : null,
                    Border = d[0] == "1" || d[1] != Lisp.Nth(def, 15) || new[] { 2, 4, 6, 8, 10 }.Any(i => d[i] == "1")
                        ? Lisp.Subst(d, 5, Lisp.StrCase(d[5])) : null,
                    Bearing = r[16] == "1" ? "1" : null,
                    Hatch = Lisp.Subst(h, 4, Lisp.StrCase(h[4])),
                    Framing = r[44] != "" ? new[] { r[44], r[45].Trim(' ').Replace(',', '.') } : null,
                    Variable = r[46] == "1" ? "1" : null,
                    LowPerm = r[47] == "1" ? "1" : null,
                });
            }
            return (res, null);
        }

        // The message of the first value of checks not valid (Remote>>Dyl:MaterialDlgCheck); a
        // check of no key (default) is left out:
        static string First(params (string Key, string Val)[] checks)
        {
            foreach (var c in checks)
                if (c.Key != null && DlgCheck(c.Key, c.Val) is string m) return m;
            return null;
        }

        // The overrides of a hatch (from 1), of a border or of lines (from 2): the color, the
        // linetype, the linetype scale and the transparency each checked when it is on:
        static string Overrides(string[] x, int from) =>
            First(new[] { ("bcv", 0), ("blt", 2), ("bsc", 4), ("btr", 8) }
                  .Select(c => Lisp.Nth(x, from + c.Item2) == "1" ? (c.Item1, Lisp.Nth(x, from + c.Item2 + 1)) : default((string, string)))
                  .ToArray());

        // (Remote>>Dyl:MaterialDlgCheck key val) for the values of a layer and of the lines:
        public static string DlgCheck(string key, string val)
        {
            switch (key)
            {
                case "bcv":
                    return ColorParse(val) == null
                        ? "A color is an AutoCAD color number 1-255 or r,g,b (0-255 each), or use the open button beside it." : null;
                case "blt": return val == "" ? "The linetype cannot be empty." : null;
                case "bsc": return !Assemblies.ScaleP(val) ? "The linetype scale must be a number greater than 0." : null;
                case "btr":
                    return !(IsDigits(val, 1, 2) && int.Parse(val) <= 90) ? "The transparency must be a whole number from 0 to 90." : null;
                case "mfc": return !Assemblies.ScaleP(val) ? "The width factor must be a number greater than 0." : null;
                case "mof": return Lisp.Distof(val) == null ? "The origin Y offset must be a number (0: on the line)." : null;
                case "moa": return Lisp.Distof(val) == null ? "The origin X offset must be a number (0: at the start of the segment)." : null;
                case "mex":
                    return val != "" && !(Lisp.Distof(val) is double e && e >= 0)
                        ? "The extension must be a number, 0 or more (empty: half the width)." : null;
                case "mea":
                    return !(Lisp.Distof(val) is double a && a >= -80 && a <= 80)
                        ? "The end angle must be a number from -80 to 80 (0: square)." : null;
                case "mml":
                    return !(Lisp.Distof(val) is double l && l >= 1) ? "The miter limit must be a number, 1 or more (x the width)." : null;
            }
            return null;
        }

        // (wcmatch v "#,##..."): v of min to max digits:
        static bool IsDigits(string v, int min, int max) =>
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

        // (Dyl:QuickDrawAsmCheck r): why the assembly r is not valid (null: it is): its layers,
        // then its lines, then its ratings:
        public string RowCheck(string[] r)
        {
            string ls = Lisp.Nth(r, 3) ?? "";
            if (ls.Contains('\t')) return LayersOf(Decode(ls), Def).Msg;
            if (Assemblies.Layers(ls).Count == 0) return "No layers: add one.";
            var m = LinesCheck(Assemblies.Lines(Lisp.Nth(r, 4)), "Border lines") ?? LinesCheck(Assemblies.Lines(Lisp.Nth(r, 5)), "Dividing lines");
            if (m != null) return m;
            var msgs = new[]
            {
                "The fire-resistance ratings must be whole numbers of minutes.",
                "The fire-resistance ratings must be whole numbers of minutes.",
                "The STC must be a whole number.",
                "The IIC must be a whole number.",
            };
            for (int i = 0; i < 4; i++)
            {
                string v = Lisp.Nth(r, 9 + i) ?? "";
                if (!(v == "" || IsDigits(v, 1, int.MaxValue))) return msgs[i];
            }
            return null;
        }

        // (Dyl:QuickDrawAsmLinesCheck d name):
        static string LinesCheck(string[] d, string name)
        {
            if (d[0] != "1") return null;
            if (d[1] == "") return name + ": no layer key, add one in the Layer Keys window.";
            return Overrides(d, 2);
        }

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
        // end of Remote>>Dyl:PresetDialog on Draw or Save): true once written, false when they
        // cannot be (open in Excel), null when nothing changed:
        public bool? Write()
        {
            Lst = Presets.Ids(Lst);
            if (Lst.Count == Lst0.Count && Lst.Zip(Lst0, Same).All(x => x)) return null;
            return Presets.Write(B, Spec, Lst);
        }

        // The preset shown (null: none):
        public string[] Shown => Idx >= 0 && Idx < Lst.Count ? Lst[Idx] : null;
    }
}
