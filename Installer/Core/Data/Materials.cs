// Materials.cs - DynALisp.Core.Data: the materials and the hatch presets, read and fixed
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
// The materials (Res\Materials.csv) and the hatch presets (Res\HatchPresets.csv) as
// Remote\Dyl-Materials.lsp reads them. Each function gives what the Lisp function it is named
// after gives, step for step:
//   Materials.Fix        Remote>>Dyl:MaterialFix         a row of the hatch presets, fixed
//   Materials.RowFix     Remote>>Dyl:MaterialRowFix      a row of the materials, fixed
//   Materials.Widths     Remote>>Dyl:MaterialWidths      the widths of the Linear method
//   Materials.HatchDefs  Remote>>Dyl:HatchPresetDefs     the default hatch presets
//   Materials.RowDefs    Remote>>Dyl:MaterialRowDefs     the default materials
//   Materials.OldP       Remote>>Dyl:MaterialOld-p       a materials file of DynALisp 1.1
//   Materials.Both       Remote>>Dyl:MaterialBoth        the hatch presets and the materials
// What the Lisp has in its code and the C# does not is left to the Lisp, which then reads the
// files itself (null): the defaults of the code (*hp:defaults*, *mt:defaults*) when a default
// file is missing, the split of a materials file of DynALisp 1.1 (Remote>>Dyl:MaterialMigrate,
// which writes both files). A material of an older file in the group Section or Elevation
// that is not a group of the materials gets the group of its default in *mt:defaults*
// (CodeGroups, the ids and groups of that list, checked against the Lisp by the tests).

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    public static class Materials
    {
        public static PresetSpec HatchSpec => Presets.HatchPreset;
        public static PresetSpec Spec => Presets.Material;

        // *mt:extra*: the default values of the columns 12 to 63 of a hatch preset:
        public static readonly string[] Extra =
        {
            "0", "7", "0", "CONTINUOUS", "0", "1", "0", "25", "0", "50",
            "0", "7", "0", "254", "0", "13", "0", "50",
            "1", "0", "0",
            "", "", "Center", "",
            "0", "1", "0", "0",
            "0", "253",
            "", "0", "",
            "0",
            "0", "CONTINUOUS", "0", "1",
            "Square", "", "45", "Mitered", "4", "First", "Interrupted", "Line",
            "0", "",
            "", "",
            "Drafting",
        };

        // The keys of *mt:methods*, *mt:justify*, *mt:ends*, *mt:corners*, *mt:laps*,
        // *mt:joints* and *mt:hatchmodes*, in their order:
        public static readonly string[] Methods = { "Polyline", "Rectangle", "Circle", "Polygon", "Ellipse", "Shrinkwrap", "Pick", "Select", "Linear", "Offset", "Replace" };
        public static readonly string[] Justify = { "Ask", "Center", "Edge", "Structural" };
        public static readonly string[] Ends = { "Ask", "Square", "Open", "Extended", "Round", "Angled" };
        public static readonly string[] Corners = { "Ask", "Mitered", "Beveled", "Round", "Lapped" };
        public static readonly string[] Laps = { "First", "Second" };
        public static readonly string[] Joints = { "Interrupted", "Uninterrupted" };
        public static readonly string[] HatchModes = { "Line", "Origin" };

        // *mt:toggles*: the on/off columns:
        public static readonly int[] Toggles = { 9, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 31, 32, 37, 39, 41, 44, 47, 49, 59 };

        // *lk:nomaterial* (Remote\Dyl-LayerKey.lsp): the layer keys kept for compatibility only:
        public const string NoMaterial = "G-DS-ANNO-STD-*";

        static string Ex(int i) => Extra[i - 12];

        // (car (vl-some ... keys)): the key of keys that is s in any case, null for none:
        static string KeyOf(string s, string[] keys) => keys.FirstOrDefault(k => Lisp.StrCase(k) == Lisp.StrCase(s));

        static bool Num(string s, Func<double, bool> ok) => Lisp.Distof(s) is double v && ok(v);

        // (Remote>>Dyl:MaterialWidths str): the numbers of str divided by commas, each greater
        // than 0; null when it is empty or one is not:
        public static double[] Widths(string str)
        {
            if (str == null || str.Trim(' ') == "") return null;
            var lst = str.Split(',').Select(x => Lisp.Distof(x.Trim(' '))).ToArray();
            return lst.All(v => v is double d && d > 0) ? lst.Select(v => v.Value).ToArray() : null;
        }

        // (Remote>>Dyl:MaterialEndsDefault-p row):
        static bool EndsDefault(string[] row) =>
            Lisp.StrCase(row[51]) == "SQUARE" && row[52] == "" && Lisp.Distof(row[53]) is double v && Math.Abs(v - 45.0) <= 1e-9;

        // (Remote>>Dyl:MaterialCornersDefault-p row):
        static bool CornersDefault(string[] row) =>
            Lisp.StrCase(row[54]) == "MITERED" && Lisp.Distof(row[55]) is double v && Math.Abs(v - 4.0) <= 1e-9
            && Lisp.StrCase(row[56]) == "FIRST" && Lisp.StrCase(row[57]) == "INTERRUPTED";

        // (wcmatch s "#,##,###,####"): 1 to 4 digits:
        static bool Digits4(string s) => s.Length >= 1 && s.Length <= 4 && s.All(c => c >= '0' && c <= '9');

        // (Remote>>Dyl:MaterialFix row): a row of the hatch presets fixed (64 columns), groupCase
        // the case of a group of the presets (Remote>>Dyl:GroupCase), dimzin DIMZIN (the scale of
        // a row set for another drawing scale is written with rtos):
        public static string[] Fix(string[] row, int dimzin, Func<string, string> groupCase)
        {
            // (a copy: the rows read are shared, never changed)
            var r = new List<string>(row);
            while (r.Count < 12) r.Add("");
            while (r.Count < 64) r.Add(Extra[r.Count - 12]);
            row = r.ToArray();
            row[63] = Lisp.StrCase(row[63]) == "MODEL" ? "Model" : "Drafting";
            if (row[63] == "Model") row[9] = row[10] = "0";
            if (row[60].Contains(':')) row[60] = Assemblies.LayersStr(Assemblies.Layers(row[60]));
            foreach (var (i, keys) in new[] { (51, Ends), (54, Corners), (56, Laps), (57, Joints), (58, HatchModes) })
                row[i] = KeyOf(row[i], keys) ?? Ex(i);
            if (!Num(row[52], v => 0 <= v)) row[52] = "";
            if (!Num(row[53], v => -80 <= v && v <= 80)) row[53] = "45";
            if (!Num(row[55], v => 1 <= v)) row[55] = "4";
            if (row[61] != "0" && row[61] != "1") row[61] = EndsDefault(row) ? "0" : "1";
            if (row[62] != "0" && row[62] != "1") row[62] = CornersDefault(row) ? "0" : "1";
            foreach (var i in new[] { 43, 45 })
                if (!Num(row[i], v => 0 <= v)) row[i] = "";
            if (row[43] == "") row[43] = row[45];
            row[45] = "";
            if (!Assemblies.ScaleP(row[38])) row[38] = "1";
            foreach (var i in new[] { 40, 46 })
                if (Lisp.Distof(row[i]) == null) row[i] = "0";
            row[33] = KeyOf(row[33], Methods) ?? "";
            if (Widths(row[34]) == null) row[34] = "";
            if (Lisp.StrCase(row[35]) == "LEFT" || Lisp.StrCase(row[35]) == "RIGHT") row[35] = "Edge";
            row[35] = KeyOf(row[35], Justify) ?? "Center";
            if (!(Digits4(row[36]) && int.Parse(row[36]) is int n && 3 <= n && n <= 1024)) row[36] = "";
            row[1] = groupCase(row[1]);
            foreach (var i in new[] { 3, 7, 8, 15, 48 }) row[i] = Lisp.StrCase(row[i]);
            foreach (var i in new[] { 7, 8 })
                if (Lisp.Wcmatch(Lisp.StrCase(row[i]), NoMaterial)) row[i] = "HATCH";
            foreach (var i in Toggles) row[i] = row[i] == "1" ? "1" : "0";
            if (Assemblies.ScaleP(row[11]) && Lisp.Distof(row[11]) is double sr && sr != 1.0 && row[10] == "1"
                && Assemblies.ScaleP(row[4]))
                row[4] = Lisp.NumP(Lisp.Distof(row[4]).Value / sr, 6, dimzin);
            row[11] = "1";
            if (!Assemblies.ScaleP(row[4])) row[4] = "1";
            row[5] = "";
            foreach (var i in new[] { 13, 15, 17, 19, 21, 23, 25, 27, 29, 42, 48, 50 })
                if (row[i] == "") row[i] = Ex(i);
            return row;
        }

        // The id and group of each material of *mt:defaults* (Remote\Dyl-Materials.lsp), in its
        // order: the group a material of an older file in the group Section or Elevation gets:
        public static readonly (string Id, string Group)[] CodeGroups =
        {
            ("mt-Demolition", "Phase"), ("mt-NotInContract", "Phase"), ("mt-Existing", "Phase"),
            ("mt-Concrete", "Concrete"), ("mt-LightweightConcrete", "Concrete"), ("mt-Mortar", "Concrete"),
            ("mt-Brick", "Masonry"), ("mt-Stone", "Masonry"), ("mt-CMU", "Masonry"),
            ("mt-Firebrick", "Masonry"), ("mt-Marble", "Masonry"), ("mt-Grout", "Concrete"),
            ("mt-Iron", "Metal"), ("mt-Steel", "Metal"), ("mt-Bronze", "Metal"), ("mt-Lead", "Metal"),
            ("mt-Aluminium", "Metal"), ("mt-Plywood", "Wood"), ("mt-WoodPlank", "Wood"),
            ("mt-WoodFrame", "Wood"), ("mt-Particleboard", "Wood"), ("mt-Hardboard", "Wood"),
            ("mt-Plastic", "Generic"), ("mt-LooseInsulation", "Insulation"),
            ("mt-SprayInsulation", "Insulation"), ("mt-RigidInsulation", "Insulation"),
            ("mt-ExtrudedPolystyrene", "Insulation"), ("mt-ExpandedPolystyrene", "Insulation"),
            ("mt-Polyisocyanurate", "Insulation"), ("mt-Gypsum", "Board"), ("mt-Plaster", "Finish"),
            ("mt-CompactedSoil", "Site"), ("mt-Topsoil", "Site"), ("mt-UndisturbedSoil", "Site"),
            ("mt-Sand", "Site"), ("mt-Asphalt", "Site"), ("mt-Gravel", "Site"), ("mt-CrushedStone", "Site"),
            ("mt-Birch", "Wood"), ("mt-Oak", "Wood"), ("mt-MapleAsh", "Wood"), ("mt-WhiteCedar", "Wood"),
            ("mt-YellowCypress", "Wood"), ("mt-WhiteSpruce", "Wood"), ("mt-WhitePine", "Wood"),
            ("mt-LodgepolePine", "Wood"), ("mt-RedPine", "Wood"), ("mt-Hemlock", "Wood"),
            ("mt-WesternHemlock", "Wood"), ("mt-DouglasFirLarch", "Wood"), ("mt-AmabilisFir", "Wood"),
            ("mt-OSB", "Wood"), ("mt-AsphaltFiberboard", "Board"), ("mt-GypsumSheathing", "Board"),
            ("mt-FoilFiberboard", "Board"), ("mt-CementBoard", "Board"),
            ("mt-ExpandedPolystyrene1", "Insulation"), ("mt-ExpandedPolystyrene3", "Insulation"),
            ("mt-ExpandedPolystyrene4", "Insulation"), ("mt-MineralWoolBoard", "Insulation"),
            ("mt-PhenolicFoam", "Insulation"), ("mt-InsulatingFiberboard", "Insulation"),
            ("mt-StrawBoard", "Insulation"), ("mt-WoodFiberBatt", "Insulation"), ("mt-Perlite", "Insulation"),
            ("mt-SprayPolyurethane1", "Insulation"), ("mt-SprayPolyurethane2", "Insulation"),
            ("mt-SprayedAsbestos", "Insulation"), ("mt-CMU90", "Masonry"), ("mt-CMU140", "Masonry"),
            ("mt-CMU190", "Masonry"), ("mt-CMU240", "Masonry"), ("mt-CMU290", "Masonry"),
            ("mt-CMU190Perlite", "Masonry"), ("mt-CMU140Vermiculite", "Masonry"),
            ("mt-CMU190Vermiculite", "Masonry"), ("mt-CMU240Vermiculite", "Masonry"),
            ("mt-CMU290Vermiculite", "Masonry"), ("mt-ConcreteBrick", "Masonry"), ("mt-Sandstone", "Masonry"),
            ("mt-Stucco", "Finish"), ("mt-WoodShingles", "Finish"), ("mt-WoodShinglesDouble", "Finish"),
            ("mt-WoodSiding", "Finish"), ("mt-HardboardSiding", "Finish"), ("mt-FiberCementSiding", "Finish"),
            ("mt-LapSiding", "Finish"), ("mt-LapSidingInsulated", "Finish"), ("mt-LapSidingFoil", "Finish"),
            ("mt-RollRoofing", "Roofing"), ("mt-Bitumen", "Roofing"), ("mt-AsphaltShingles", "Roofing"),
            ("mt-BuiltUpRoof", "Roofing"), ("mt-WoodShingleRoof", "Roofing"), ("mt-Slate", "Roofing"),
            ("mt-CementPlaster", "Finish"), ("mt-LDF", "Wood"), ("mt-MDF", "Wood"), ("mt-HDF", "Wood"),
            ("mt-Terrazzo", "Finish"), ("mt-CarpetFibrous", "Finish"), ("mt-CarpetRubber", "Finish"),
            ("mt-CorkTile", "Finish"), ("mt-HardwoodFloor", "Finish"), ("mt-ResilientFlooring", "Finish"),
            ("mt-AirWall13", "Air"), ("mt-AirWall20", "Air"), ("mt-AirCeiling13", "Air"),
            ("mt-AirCeiling40", "Air"), ("mt-AirFloor13", "Air"), ("mt-AirFloor20", "Air"),
            ("mt-AirFloor40", "Air"), ("mt-AirFloor90", "Air"), ("mt-GypsumTypeX", "Board"),
            ("mt-GypsumSandPlaster", "Finish"), ("mt-AbsorptiveMaterial", "Insulation"),
            ("mt-ResilientChannel", "Metal"), ("mt-SteelFurring", "Metal"), ("mt-HollowCoreSlab", "Concrete"),
            ("mt-GypsumConcrete", "Concrete"), ("mt-SteelDeck", "Metal"), ("mt-Void", "Air")
        };

        static readonly Dictionary<string, string> codeGroups = CodeGroups.GroupBy(x => x.Id, StringComparer.Ordinal)
                                                                          .ToDictionary(g => g.Key, g => g.First().Group, StringComparer.Ordinal);

        // (Remote>>Dyl:MaterialRowFix row): a row of the materials fixed (10 columns); a default
        // material of an older file in the group of the presets it had (Section, Elevation), not
        // a group of the materials, in its default group (its id as written, CodeGroups); its group
        // as in the groups of the materials (any case), each value of its data a number greater
        // than 0 (a decimal comma read as a point), else "":
        public static string[] RowFix(Bundle b, string[] row)
        {
            // (a copy: the rows read are shared, never changed)
            row = (string[])Csv.Fit(row, 10).Clone();
            string g = Lisp.StrCase(row[1]);
            if ((g == "SECTION" || g == "ELEVATION")
                && !Groups.Of(b, "Material").Any(x => Lisp.StrCase(x) == g)
                && codeGroups.TryGetValue(row[0], out var dg))
                row[1] = dg;
            row[1] = Groups.CaseOf(b, row[1], "Material");
            foreach (var i in new[] { 5, 6, 7, 8, 9 })
            {
                string v = row[i].Replace(',', '.');
                row[i] = Num(v, d => 0 < d) ? v : "";
            }
            return row;
        }

        // (Remote>>Dyl:HatchPresetDefs): the default hatch presets fixed; null when the default
        // file is missing or has none (the defaults of the code, *hp:defaults*):
        public static List<string[]> HatchDefs(Bundle b, int dimzin)
        {
            Func<string, string> gc = g => Groups.CaseOf(b, g, null);
            return Presets.DefsOf(b, HatchSpec, r => Fix(r, dimzin, gc), null);
        }

        // (Remote>>Dyl:MaterialRowDefs): the default materials fixed; null as HatchDefs (the
        // defaults of the code, *mt:defaults*):
        public static List<string[]> RowDefs(Bundle b)
        {
            var raw = Presets.DefsOf(b, Spec, null, null);
            return raw?.Select(r => RowFix(b, r)).ToList();
        }

        // (Remote>>Dyl:MaterialOld-p): true when the user copy of the materials file is a file of
        // DynALisp 1.1 and older (Pattern in column 3 of its header):
        public static bool OldP(Bundle b)
        {
            string def = Presets.Default(b, Spec), fle = b.UserFile(def);
            if (string.Equals(fle, def, StringComparison.OrdinalIgnoreCase) || !System.IO.File.Exists(fle)) return false;
            return Lisp.StrCase(Lisp.Nth(b.Head(fle), 3) ?? "") == "PATTERN";
        }

        // (Remote>>Dyl:MaterialBoth): the hatch presets and the materials read, fixed and
        // cleaned, the defaults missing from the files added (Remote>>Dyl:PresetRead); null when
        // the Lisp reads them (see the header). Kept while none of the files changed:
        public static (List<string[]> Hatches, List<string[]> Rows)? Both(Bundle b, int dimzin)
        {
            string stamp = Presets.Stamps(b) + "|" + dimzin;
            if (b.Reads.TryGetValue("Materials", out var o) && o is Kept k && k.Stamp == stamp) return k.Both;
            (List<string[]>, List<string[]>)? res = null;
            var hdefs = HatchDefs(b, dimzin);
            var mdefs = RowDefs(b);
            var rows = Presets.Csv(b, Spec);
            if (!OldP(b) && hdefs != null && mdefs != null)
            {
                Func<string, string> gc = g => Groups.CaseOf(b, g, null);
                res = (Read(HatchSpec, Presets.Csv(b, HatchSpec).Select(r => Fix(r, dimzin, gc)), hdefs),
                       Read(Spec, rows.Select(r => RowFix(b, r)), mdefs));
            }
            b.Reads["Materials"] = new Kept { Stamp = stamp, Both = res };
            return res;
        }

        // (Remote>>Dyl:PresetRead key defs fix) on rows already fixed:
        static List<string[]> Read(PresetSpec s, IEnumerable<string[]> rows, List<string[]> defs)
        {
            var lst = Presets.Clean(s, rows, defs);
            var ids = new HashSet<string>(lst.Select(r => r[0]), StringComparer.Ordinal);
            foreach (var d in defs) if (!ids.Contains(d[0])) lst.Add(d);
            return lst;
        }

        sealed class Kept
        {
            public string Stamp;
            public (List<string[]>, List<string[]>)? Both;
        }
    }
}
