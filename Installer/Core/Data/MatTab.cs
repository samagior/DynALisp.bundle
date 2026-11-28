// MatTab.cs - DynALisp.Core.Data: the Materials window, its values and what it gives back
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
// The Materials window (Res\Dyl-Materials.xaml, the tab Materials of the Manager and the open
// button of the material of Quick Draw and Quick Shape), as the preset engine of
// Remote\Dyl-Presets.lsp ran it on the spec of Remote>>Dyl:MaterialDlg
// (Remote\Dyl-Materials.lsp), shown by DynALisp.Windows.dll (Dyl:MatWindow) without the Lisp.
// What every preset window does is in PresetTab; here the App part, each step named after the
// Lisp function it gives what of, checked by the witness files (sections mattab):
//   MatTab.Open        Remote>>Dyl:PresetDialog         the materials read, the one shown
//   MatTab.Prep        Remote>>Dyl:PresetWinPrep        the groups, the hatch presets (mats)
//   MatTab.Rows        Remote>>Dyl:MaterialWinRow       the data in imperial units, when shown so
//   MatTab.More        Remote>>Dyl:PresetWinVals and    the hatch presets of the Cut list, the
//                      Remote>>Dyl:MaterialWinVals      Surface list
//   MatTab.WinGet      Remote>>Dyl:MaterialWinGet       the data back in SI units
//   MatTab.ValueCheck  Remote>>Dyl:MaterialWinCheck     why a value is not valid
// What stays in the Lisp: the units of the patterns of the hatch presets (their previews), the
// Hatch Presets window opened from a button (the codes of Remote>>Dyl:MaterialDialog).

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    public sealed class MatTab : PresetTab
    {
        public static PresetSpec Spec => Presets.Material;
        public override PresetSpec Tool => Spec;
        protected override string GroupKind => "Material";
        protected override string Title => "Materials";
        protected override string Noun => "materials";
        public override string[] NewRow => New;
        protected override string TilesText => Tiles;

        // *mt:newrow*: a new material, no hatch preset yet, no data:
        public static readonly string[] New = { "", "Generic", "New material", "", "", "", "", "", "", "" };

        // The tiles of Remote>>Dyl:MaterialDlg and their column, the name and the group first, the
        // material (its Cut hatch preset) last (Remote>>Dyl:PresetWinTiles):
        public const string Tiles = "nam:2,grp:1,sur:4,cnd:5,den:6,rsi:7,vpm:8,vpc:9,mat:3";

        static readonly (string, int)[] TileCols = { ("sur", 4), ("cnd", 5), ("den", 6), ("rsi", 7), ("vpm", 8), ("vpc", 9) };

        // *mt:data*: (column factor) of each value of the data, the value in imperial units its
        // SI value x factor:
        static readonly (int Col, double F)[] Data = { (5, 6.933471), (6, 0.06242796), (7, 5.678263), (8, 0.688127), (9, 0.0174784) };

        // The units of a pattern (Remote>>Dyl:MaterialPatUnits), for the previews of the hatch
        // presets:
        public readonly Shows.PatUnits Pats;

        // What Prep makes besides the groups: the hatch presets of the Cut and Surface lists
        // (pst:mats, Remote>>Dyl:HatchPresetRead):
        public List<string[]> Mats;

        // mt:shown: each value of the data shown in imperial units ((column text) its SI value),
        // the first one kept, so a value not changed gets back its SI value as it was:
        readonly Dictionary<(int, string), string> shown = new Dictionary<(int, string), string>();

        MatTab(Bundle b, Units u, Shows.PatUnits pats) : base(b, u, null)
        {
            Pats = pats ?? (p => null);
        }

        // (Remote>>Dyl:PresetDialog "Material" (Remote>>Dyl:MaterialDlg id)) up to the window: the
        // materials read (Remote>>Dyl:MaterialRead), the one shown that of id select (else the
        // one shown last, last, else the first), the Show group shw (the
        // DynalispPresetShowMaterial setting), the sort srt of the session. null when the Lisp
        // reads the materials (a materials file of DynALisp 1.1, a default file missing):
        public static MatTab Open(Bundle b, Units u, string select, int? last, string shw, string srt, Shows.PatUnits pats)
        {
            var both = Materials.Both(b, u.Dimzin);
            if (both == null) return null;
            var t = new MatTab(b, u, pats);
            t.Init(both.Value.Rows, Materials.RowDefs(b), select, last, shw, srt);
            return t;
        }

        // The patterns of the hatch presets (upper case, SOLID and none left out), whose units
        // the Lisp gives for their previews; null when the Lisp reads the materials:
        public static List<string> Patterns(Bundle b, int dimzin)
        {
            var both = Materials.Both(b, dimzin);
            if (both == null) return null;
            var res = new SortedSet<string>(StringComparer.Ordinal);
            foreach (var h in both.Value.Hatches)
            {
                string p = Lisp.StrCase(Lisp.Nth(h, 3) ?? "");
                if (p != "" && p != "SOLID") res.Add(p);
            }
            return res.ToList();
        }

        // (Remote>>Dyl:PresetWinPrep): the groups of the materials (MaterialGroups.csv), then
        // the others the materials use; the hatch presets:
        public override void Prep()
        {
            PrepGroups();
            Mats = Materials.Both(B, U.Dimzin).Value.Hatches;
        }

        // (Remote>>Dyl:MaterialWinRow r) on each: its data in imperial units in an imperial
        // drawing (MEASUREMENT 0), each value shown kept with its SI value:
        public override List<string[]> Rows(IEnumerable<string[]> lst) => lst.Select(Row).ToList();

        string[] Row(string[] r)
        {
            if (!U.Imperial) return r;
            foreach (var (col, f) in Data)
            {
                if (!(Lisp.Distof(Lisp.Nth(r, col)) is double v)) continue;
                string s = Shows.Sig(v * f, U.Dimzin);
                if (!shown.ContainsKey((col, s))) shown[(col, s)] = Lisp.Nth(r, col);
                r = Lisp.Subst(r, col, s);
            }
            return r;
        }

        // (Remote>>Dyl:MaterialWinGet r): its data in SI units again, a value shown and not
        // changed its SI value as it was:
        protected override string[] WinGet(string[] r)
        {
            if (!U.Imperial) return r;
            foreach (var (col, f) in Data)
            {
                string v = (Lisp.Nth(r, col) ?? "").Trim(' ');
                string x = v == "" ? ""
                    : shown.TryGetValue((col, v), out var si) ? si
                    : Lisp.Distof(v) is double d ? Shows.Sig(d / f, U.Dimzin)
                    : v;
                r = Lisp.Subst(r, col, x);
            }
            return r;
        }

        // The values of Remote>>Dyl:PresetWinVals for a window with a material (the hatch
        // presets of the Cut list: (id group name preview pattern) each), then those of
        // Remote>>Dyl:MaterialWinVals (wvals): the Surface list (Same as Cut, then every hatch
        // preset, "group - name", sorted in any case), mt.imp ("1": the data shown in imperial
        // units):
        protected override void More(List<WinVal> res)
        {
            res.Add(WinVal.S("pst/mat", "3"));
            res.Add(WinVal.S("pst/matnoun", "hatch preset"));
            res.Add(WinVal.S("pst/matfree", "1"));
            res.Add(WinVal.R("pst/mats", Mats.Select(m => new[]
            {
                m[0], Lisp.Nth(m, 1), Lisp.Nth(m, 2), Shows.Band("P", m, 1.0, U, Pats), Lisp.StrCase(Lisp.Nth(m, 3)),
            })));
            var hps = Mats.OrderBy(h => Lisp.StrCase(Lisp.Nth(h, 1) + "\t" + Lisp.Nth(h, 2)), StringComparer.Ordinal).ToList();
            res.Add(WinVal.L("sur/list", new[] { "Same as Cut" }.Concat(hps.Select(h => Lisp.Nth(h, 1) + " - " + Lisp.Nth(h, 2)))));
            res.Add(WinVal.L("sur/vals", new[] { "" }.Concat(hps.Select(h => h[0]))));
            res.Add(WinVal.S("mt.imp", U.Imperial ? "1" : "0"));
        }

        protected override (string Key, int Col)[] Checks => TileCols;

        // (Remote>>Dyl:MaterialWinCheck key val): a hatch preset that exists ("": none), a value
        // of the data empty or greater than 0:
        protected override string ValueCheck(string key, string val)
        {
            if ((key == "mat" || key == "sur") && val != "" && !Mats.Any(h => h[0] == val))
                return "This hatch preset no longer exists: pick another one.";
            if (key != "mat" && key != "sur" && (val ?? "").Trim(' ') != "" && !(Lisp.Distof(val) is double v && v > 0))
                return "A value of the data must be a number greater than 0 (empty: not known).";
            return null;
        }
    }
}
