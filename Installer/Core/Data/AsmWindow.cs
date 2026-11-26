// AsmWindow.cs - DynALisp.Core.Data: what the Assembly Presets window is given
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
// What the Assembly Presets window (Apps\Draw\Dyl-QuickDraw.lsp) is given of the assemblies
// and of the materials. Each function gives what the Lisp function it is named after gives,
// step for step:
//   AsmWindow.Mats    Dyl:QuickDrawAsmWinMats         the materials of the Material list of a
//                                                     layer, the groups of its Group list, the
//                                                     layer keys the assemblies use
//   AsmWindow.Def     qa:def of Dyl:QuickDrawAsmWinPrep  the row Add starts from
//   AsmWindow.Data    Remote>>Dyl:MaterialDataLists   the data of each material
//   AsmWindow.Rows    Dyl:QuickDrawLayersRows         the rows of the layers of an assembly
//   AsmWindow.Extra   Dyl:QuickDrawAsmExtra           the columns the window adds to an assembly
// The layer keys (LayerKeys.csv) stay in the Lisp: it makes the list of the keys from those
// the assemblies use (Remote>>Dyl:MaterialDlgKeys), and the row Add starts from on its first
// key, given back to Rows and Extra.

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    public static class AsmWindow
    {
        // A material of the Material list (an item of qa:mats): its id, its name, the index of
        // its row among the materials read (Materials.Both, -1 for a material missing), its
        // group ("" for a material missing):
        public sealed class Mat
        {
            public string Id, Name, Group;
            public int Row = -1;
        }

        // What Mats gives: the materials of the Material list, the groups of the Group list, the
        // layer keys used (each once, in the order they are found):
        public sealed class Lists
        {
            public List<Mat> Mats;
            public List<string> Groups, Used;
        }

        // *qd:layerband*, its first 8 values: the band settings of a layer when they are the
        // defaults:
        public static readonly string[] LayerBand = { "Line", "Square", "", "45", "Mitered", "4", "First", "Interrupted" };

        static string[] Sub(string[] a, int i, int n) => a.Skip(i).Take(n).ToArray();

        // (Dyl:QuickDrawAsmWinMats lst) for the presets lst (the layers, Border lines and
        // Dividing lines of each one, its columns 3, 4 and 5): the materials by group, in the
        // order of the groups, then by name; those of the layers that no longer exist after them,
        // marked, without group; the groups that have materials; the layer keys of the layers,
        // of their borders and of the lines. null when the Lisp reads the materials (see
        // Materials.Both):
        public static Lists Mats(Bundle b, int dimzin, IEnumerable<string[]> presets)
        {
            var both = Materials.Both(b, dimzin);
            if (both == null) return null;
            var all = both.Value.Rows.Select((m, i) => new Mat { Id = m[0], Name = m[2], Row = i, Group = DynALisp.Core.Data.Groups.CaseOf(b, m[1], "Material") }).ToList();
            var grps = DynALisp.Core.Data.Groups.Of(b, "Material").ToList();
            foreach (var m in all)
                if (!grps.Any(g => Lisp.StrCase(g) == Lisp.StrCase(m.Group))) grps.Add(m.Group);
            grps = grps.Where(g => all.Any(m => Lisp.StrCase(g) == Lisp.StrCase(m.Group))).ToList();
            var mats = new List<Mat>();
            foreach (var g in grps)
                mats.AddRange(all.Where(m => Lisp.StrCase(g) == Lisp.StrCase(m.Group))
                                 .OrderBy(m => Lisp.StrCase(m.Name), StringComparer.Ordinal));
            var lst = presets.ToList();
            var ls = lst.SelectMany(p => Assemblies.Layers(Lisp.Nth(p, 0))).ToList();
            var ups = new HashSet<string>(mats.Select(m => Lisp.StrCase(m.Id)), StringComparer.Ordinal);
            foreach (var id in ls.Where(l => l.Kind == "P").Select(l => l.Ref)
                                 .Concat(ls.Where(l => l.Framing != null).Select(l => l.Framing[0])))
                if (ups.Add(Lisp.StrCase(id))) mats.Add(new Mat { Id = id, Name = id + "   (missing material)", Group = "" });
            var used = new List<string>();
            var seen = new HashSet<string>(StringComparer.Ordinal);
            void Use(string k)
            {
                if (!string.IsNullOrEmpty(k) && seen.Add(k)) used.Add(k);
            }
            foreach (var l in ls) Use(l.HatchKey);
            foreach (var l in ls) Use(l.Border?[1]);
            foreach (var p in lst)
            {
                Use(Assemblies.Lines(Lisp.Nth(p, 1))[1]);
                Use(Assemblies.Lines(Lisp.Nth(p, 2))[1]);
            }
            return new Lists { Mats = mats, Groups = grps, Used = used };
        }

        // qa:def of Dyl:QuickDrawAsmWinPrep: the row Add starts from, a layer of the first
        // material of mats, 10 thick; its band settings off, the defaults; its border off, on the
        // key bk, overriding nothing; its hatch on, on the key of its material, overriding
        // nothing; no framing, its thickness the same everywhere, not of low permeance:
        public static string[] Def(List<Mat> mats, string bk)
        {
            var m = mats.FirstOrDefault();
            return new[] { "P", m?.Id ?? "", "10", "", bk, "0" }
                .Concat(LayerBand)
                .Concat(new[] { "0", bk, "0" })
                .Concat(Assemblies.NewOverrides)
                .Concat(new[] { "1" })
                .Concat(Assemblies.NewOverrides)
                .Concat(Assemblies.LayerScale)
                .Concat(new[] { m?.Group ?? "", "", "", "0", "0" })
                .ToArray();
        }

        // (Remote>>Dyl:MaterialDataLists ids nil): for each id, the data of the first material
        // of that id in any case (its resistance "per-unit fixed" and its mass "per-unit", ""
        // when not known): (resistances masses). null when the Lisp reads the materials:
        public static (List<string> Rsi, List<string> Mass)? Data(Bundle b, Units u, IEnumerable<string> ids)
        {
            var both = Materials.Both(b, u.Dimzin);
            if (both == null) return null;
            var rows = new Dictionary<string, string[]>(StringComparer.Ordinal);
            foreach (var m in both.Value.Rows)
            {
                var k = Lisp.StrCase(m[0]);
                if (!rows.ContainsKey(k)) rows[k] = m;
            }
            var rs = new List<string>();
            var ms = new List<string>();
            foreach (var id in ids)
            {
                var d = rows.TryGetValue(Lisp.StrCase(id ?? ""), out var m) ? Shows.LayerData(m, u) : (null, null, null);
                rs.Add(d.R is double r ? Lisp.NumP(r, 10, u.Dimzin) + " " + Lisp.NumP(d.Fixed.Value, 10, u.Dimzin) : "");
                ms.Add(d.M is double mm ? Lisp.NumP(mm, 10, u.Dimzin) : "");
            }
            return (rs, ms);
        }

        // (Dyl:QuickDrawLayersDefBorder def): the border of a row as the layers keep it:
        static string[] DefBorder(string[] r) => Sub(r, 14, 2).Concat(Sub(r, 17, 10)).ToArray();

        // (Dyl:QuickDrawLayersRows lst def): the rows of the window for the P layers of lst, group
        // the group of a material (Dyl:QuickDrawAsmMatGroup):
        public static List<string[]> Rows(IEnumerable<Layer> lst, string[] def, Func<string, string> group)
        {
            var res = new List<string[]>();
            foreach (var l in lst.Where(l => l.Kind == "P"))
            {
                var border = l.Border ?? DefBorder(def);
                var r = new List<string> { "P", l.Ref, l.Thick, l.HatchKey ?? "", Lisp.Nth(def, 4) };
                r.AddRange(l.Band != null ? Sub(l.Band, 0, 9) : Sub(def, 5, 9));
                r.AddRange(Sub(border, 0, 2));
                r.Add(l.Bearing == "1" ? "1" : "0");
                r.AddRange(Sub(border, 2, 10));
                r.AddRange(Sub(l.Hatch ?? Sub(def, 27, 11), 0, 11));
                r.AddRange(l.Band != null ? Sub(l.Band, 9, 5) : Sub(def, 38, 5));
                r.Add(group(l.Ref));
                r.AddRange(l.Framing ?? new[] { "", "" });
                r.Add(l.Variable == "1" ? "1" : "0");
                r.Add(l.LowPerm == "1" ? "1" : "0");
                res.Add(r.ToArray());
            }
            return res;
        }

        // (Dyl:QuickDrawAsmLinesOf str): the lines split for the window, on the key bk when they
        // have none; off when there is no key at all:
        static string[] LinesOf(string str, string bk)
        {
            var b = Assemblies.Lines(str);
            if (b[1] != "") return b;
            if (bk == "") return new[] { "0" }.Concat(b.Skip(1)).ToArray();
            return new[] { b[0], bk }.Concat(b.Skip(2)).ToArray();
        }

        // (Dyl:QuickDrawAsmExtra r) for the preset p (its layers, Border lines, Dividing lines and
        // units, its columns 3, 4, 5 and 7): its layers as rows (one a line, their columns divided
        // by tabs; its column 3 as it is when it holds tabs, rows the window gave back not valid),
        // their thicknesses in the units of the drawing (f: the drawing units in a millimetre, 8
        // decimals), then its Border lines and its Dividing lines (12 values each):
        public static string[] Extra(string[] p, double f, int dimzin, string[] def, string bk, Func<string, string> group)
        {
            string ls = Lisp.Nth(p, 0) ?? "", enc;
            if (ls.Contains('\t')) enc = ls;
            else
            {
                var row = new[] { "", "", "", ls, "", "", "", Lisp.Nth(p, 3) ?? "" };
                var rows = Rows(Assemblies.Layers(Assemblies.Scale(row, f, 8, dimzin)[3]), def, group);
                enc = string.Join("\n", rows.Select(r => string.Join("\t", r)));
            }
            return new[] { enc }.Concat(LinesOf(Lisp.Nth(p, 1), bk)).Concat(LinesOf(Lisp.Nth(p, 2), bk)).ToArray();
        }

        // The same for each preset of presets, the group of a material that of the first one of
        // its id in any case among the materials of the Material list (Mats), "" for none; null
        // when the Lisp reads the materials:
        public static List<string[]> Extras(Bundle b, Units u, string[] def, string bk, IEnumerable<string[]> presets)
        {
            var lists = Mats(b, u.Dimzin, Enumerable.Empty<string[]>());
            if (lists == null) return null;
            var groups = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var m in lists.Mats)
            {
                var k = Lisp.StrCase(m.Id);
                if (!groups.ContainsKey(k)) groups[k] = m.Group;
            }
            Func<string, string> group = id => groups.TryGetValue(Lisp.StrCase(id), out var g) ? g : "";
            return presets.Select(p => Extra(p, u.Factor, u.Dimzin, def, bk, group)).ToList();
        }
    }
}
