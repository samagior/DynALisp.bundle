// Assemblies.cs - DynALisp.Core.Data: the assembly presets, read and fixed
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
// The assemblies of Quick Draw (the tool QuickDrawAssembly, Res\QuickDrawAssemblies.csv), as
// Apps\Draw\Dyl-QuickDraw.lsp reads them, with the layers and lines of Remote\Dyl-Materials.lsp.
// Each function gives what the Lisp function it is named after gives, step for step:
//   Assemblies.Layers     Remote>>Dyl:MaterialLayers     the layers of a text
//   Assemblies.LayersStr  Remote>>Dyl:MaterialLayersStr  the text of layers
//   Assemblies.Lines      Remote>>Dyl:MaterialLines      the Border or Dividing lines of a text
//   Assemblies.LinesStr   Remote>>Dyl:MaterialLinesStr   the text of lines
//   Assemblies.Fix        Dyl:QuickDrawAsmFix            a row of the file, fixed
//   Assemblies.Defs       Dyl:QuickDrawAsmDefs           the default assemblies
//   Assemblies.Scale      Dyl:QuickDrawAsmScale          the thicknesses of an assembly in mm scaled
//   Assemblies.Read       Dyl:QuickDrawAsmReadAll        the assemblies read, fixed and scaled
// A layer of an older file whose material is the id of a Quick Draw preset takes the material
// of that preset (Dyl:QuickDrawAsmFixLayer): the presets of Quick Draw are not read here, so a
// file that has one is read by the Lisp (Read gives null).

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    // A layer of an assembly (Remote>>Dyl:MaterialLayers): its kind ("P" a material, "S" a space
    // and "L" a line of an older file), its material (or layer key of a line), its thickness;
    // for P: the key of its hatch (upper case, "" for that of its material), its band settings
    // (14 values, null for none), its border (12 values, null), "1" when it is load-bearing, its
    // hatch (on and its 10 overrides), its framing (id percent, null), "1" when its thickness
    // varies, "1" for the layer of low permeance; null for each value the Lisp has nil:
    public sealed class Layer
    {
        public string Kind, Ref, Thick, HatchKey;
        public string[] Band, Border, Hatch, Framing;
        public string Bearing, Variable, LowPerm;

        public Layer With(string thick)
        {
            var l = (Layer)MemberwiseClone();
            l.Thick = thick;
            return l;
        }
    }

    public static class Assemblies
    {
        public static PresetSpec Spec => Presets.QuickDrawAssembly;

        // (Remote>>LM:sublst *mt:new* 12 10): the overrides of a border, of a hatch or of lines,
        // all off:
        public static readonly string[] NewOverrides = { "0", "7", "0", "CONTINUOUS", "0", "1", "0", "25", "0", "50" };

        // *mt:layerscale*: the scale and origin of the hatch of a layer in its band settings when
        // it has none (an older file):
        public static readonly string[] LayerScale = { "0", "1", "0", "0", "0" };

        // (Remote>>LM:lst->str lst del): nil (null) for an empty list:
        static string Join(IList<string> lst, string del) => lst == null || lst.Count == 0 ? null : string.Join(del, lst);

        // (Remote>>LM:str->lst str del):
        static string[] Split(string s, string del) => s.Split(new[] { del }, StringSplitOptions.None);

        // (vl-string-translate a b s) for one character:
        static string Tr(string s, char a, char b) => s?.Replace(a, b);

        static string[] Cat(params IEnumerable<string>[] parts) => parts.SelectMany(p => p).ToArray();

        static string[] Sub(string[] a, int i, int n) => a.Skip(i).Take(n).ToArray();

        // (Remote>>Dyl:MaterialScale-p str): a number greater than 0:
        public static bool ScaleP(string s) => Lisp.Distof(s) is double v && v > 0;

        // (Remote>>Dyl:MaterialShare-p v): a number greater than 0 and less than 100, a comma
        // read as a point:
        public static bool ShareP(string s) => s != null && Lisp.Distof(Tr(s, ',', '.')) is double v && v > 0 && v < 100;

        // A border or lines of 12 values as they are read: on, key in upper case, the comma of
        // the color, the linetype in upper case:
        static string[] Border12(string on, string[] d) =>
            Cat(new[] { on, Lisp.StrCase(d[1]), d[2], Tr(d[3], '.', ','), d[4], Lisp.StrCase(d[5]) }, Sub(d, 6, 6));

        // (Remote>>Dyl:MaterialLayers str): the layers that are valid only:
        public static List<Layer> Layers(string str)
        {
            var res = new List<Layer>();
            if (str == null) return res;
            foreach (var part in Split(str, "|"))
            {
                var x = Split(part, ":").Select(y => y.Trim(' ')).ToArray();
                if (x.Length < 3 || x.Length > 10) continue;
                string k = Lisp.StrCase(x[0]), r = x[1], w = x[2];
                string[] b = Split(Lisp.Nth(x, 4) ?? "", "~"), d = Split(Lisp.Nth(x, 5) ?? "", "~"),
                         h = Split(Lisp.Nth(x, 3) ?? "", "~"), f = Split(Lisp.Nth(x, 7) ?? "", "~");
                if (k == "P" && r != "" && ScaleP(w))
                {
                    string[] band = null;
                    if (b.Length == 14) band = b;
                    else if (b.Length == 9) band = Cat(b, LayerScale);
                    else if (b.Length == 10)
                    {
                        var s = Sub(b, 0, 9);
                        if (b[9] == "Edge" && b[1] == "Line") s = Lisp.Subst(s, 1, "Edge");
                        band = Cat(s, LayerScale);
                    }
                    string[] border = d.Length == 2 ? Cat(new[] { d[0], Lisp.StrCase(d[1]) }, NewOverrides)
                                    : d.Length == 12 ? Border12(d[0], d)
                                    : null;
                    string[] hatch = h.Length == 12
                        ? Cat(new[] { h[1] == "0" ? "0" : "1", h[2], Tr(h[3], '.', ','), h[4], Lisp.StrCase(h[5]) }, Sub(h, 6, 6))
                        : Cat(new[] { "1" }, NewOverrides);
                    res.Add(new Layer
                    {
                        Kind = "P", Ref = r, Thick = w, HatchKey = Lisp.StrCase(h[0]),
                        Band = band, Border = border,
                        Bearing = Lisp.Nth(x, 6) == "1" ? "1" : null,
                        Hatch = hatch,
                        Framing = f.Length == 2 && f[0] != "" && ShareP(f[1]) ? f : null,
                        Variable = Lisp.Nth(x, 8) == "1" ? "1" : null,
                        LowPerm = Lisp.Nth(x, 9) == "1" ? "1" : null,
                    });
                }
                else if (k == "S" && ScaleP(w)) res.Add(new Layer { Kind = "S", Ref = "", Thick = w });
                else if (k == "L" && r != "") res.Add(new Layer { Kind = "L", Ref = Lisp.StrCase(r), Thick = "" });
            }
            return res;
        }

        // (Remote>>Dyl:MaterialLayerBorderStr b): on and key alone when it overrides nothing,
        // the commas of its color as dots; null for none:
        static string[] BorderStr(string[] b)
        {
            if (b == null) return null;
            if (!new[] { 2, 4, 6, 8, 10 }.Any(i => Lisp.Nth(b, i) == "1")) return new[] { b[0], b[1] };
            return Lisp.Subst(b, 3, Tr(Lisp.Nth(b, 3) ?? "", ',', '.'));
        }

        // (Remote>>Dyl:MaterialLayerHatchStr k h): its key, then its hatch when it has none or
        // overrides a property of it:
        static string HatchStr(string k, string[] h)
        {
            if (h != null && (h[0] == "0" || new[] { 1, 3, 5, 7, 9 }.Any(i => Lisp.Nth(h, i) == "1")))
                return Join(Cat(new[] { k ?? "" }, Lisp.Subst(h, 2, Tr(Lisp.Nth(h, 2) ?? "", ',', '.'))), "~");
            return k ?? "";
        }

        // (Remote>>Dyl:MaterialLayersStr lst): the fields of a P layer after its thickness only
        // when it has them:
        public static string LayersStr(IEnumerable<Layer> lst)
        {
            var parts = new List<string>();
            foreach (var l in lst)
            {
                var x = new List<string>();
                if (l.Kind == "P")
                {
                    x.Add(HatchStr(l.HatchKey, l.Hatch));
                    x.Add(Join(l.Band, "~") ?? "");
                    x.Add(Join(BorderStr(l.Border), "~") ?? "");
                    x.Add(l.Bearing == "1" ? "1" : "");
                    x.Add(l.Framing != null ? Join(l.Framing, "~") ?? "" : "");
                    x.Add(l.Variable == "1" ? "1" : "");
                    x.Add(l.LowPerm == "1" ? "1" : "");
                    while (x.Count > 0 && x[x.Count - 1] == "") x.RemoveAt(x.Count - 1);
                }
                parts.Add(string.Join(":", new[] { l.Kind, l.Ref, l.Thick }.Concat(x)));
            }
            return parts.Count == 0 ? "" : string.Join("|", parts);
        }

        // (Remote>>Dyl:MaterialLines str): on "1" or "0", key, overrides; off on no key when str
        // is not lines:
        public static string[] Lines(string str)
        {
            var d = Split(str ?? "", "~");
            if (d.Length == 2) return Cat(new[] { d[0] == "1" ? "1" : "0", Lisp.StrCase(d[1]) }, NewOverrides);
            if (d.Length == 12) return Border12(d[0] == "1" ? "1" : "0", d);
            return Cat(new[] { "0", "" }, NewOverrides);
        }

        // (Remote>>Dyl:MaterialLinesStr b):
        public static string LinesStr(string[] b) => Join(BorderStr(b), "~");

        // (Dyl:QuickDrawAsmFix row), defs the default assemblies (*qd:asmdefs*, null while they
        // are read), case the case of a group (Remote>>Dyl:GroupCase):
        public static string[] Fix(string[] row, List<string[]> defs, Func<string, string> groupCase)
        {
            row = Csv.Fit(row, 15);
            if (row[13] == "")
            {
                string[] d = defs != null && defs.Count > 0 && row[0] != ""
                    ? defs.FirstOrDefault(a => Lisp.StrCase(row[0]) == Lisp.StrCase(a[0]))
                    : null;
                row = Lisp.Subst(row, 13, d != null ? d[13] : row[2]);
                if (d != null && row[14] == "") row = Lisp.Subst(row, 14, d[14]);
            }
            row = Lisp.Subst(row, 6, Lisp.StrCase(row[6]) == "LAST" ? "Last" : "First");
            row = Lisp.Subst(row, 7, Lisp.StrCase(row[7]) == "MM" ? "mm" : "");
            row = Lisp.Subst(row, 1, groupCase(row[1]));
            var ls = Layers(row[3]);
            var bl = Lines(row[4]);
            var dl = Lines(row[5]);
            string bk = null, dk = null;
            var res = new List<Layer>();
            for (int i = 0; i < ls.Count; i++)
            {
                var l = ls[i];
                if (l.Kind != "L")
                    res.Add(l.Kind == "S"
                        ? new Layer { Kind = "P", Ref = "mt-Void", Thick = l.Thick, HatchKey = "", Hatch = Cat(new[] { "1" }, NewOverrides) }
                        : l);
                else if (ls.Take(i).Any(y => y.Kind != "L") && ls.Skip(i + 1).Any(y => y.Kind != "L"))
                {
                    if (row[5] == "" && dk == null) dk = l.Ref;
                }
                else if (row[4] == "" && bk == null) bk = l.Ref;
            }
            if (bk != null) bl = Cat(new[] { "1", bk }, bl.Skip(2));
            if (dk != null) dl = Cat(new[] { "1", dk }, dl.Skip(2));
            row = Lisp.Subst(row, 3, LayersStr(res));
            row = Lisp.Subst(row, 4, LinesStr(bl) ?? "");
            return Lisp.Subst(row, 5, LinesStr(dl) ?? "");
        }

        // The layers of a row of an older file that the Lisp reads (the id of a Quick Draw preset
        // in place of a material, see Dyl:QuickDrawAsmFixLayer): true when a P layer has an id
        // that is not that of a default material (mt-*) nor of a material, and that may be that
        // of a preset (qd-*, or an id of the Quick Draw file), in any case:
        public static bool NeedsLisp(string[] row, ISet<string> mats, ISet<string> qds)
        {
            foreach (var l in Layers(Lisp.Nth(row, 3)))
            {
                if (l.Kind != "P") continue;
                string u = Lisp.StrCase(l.Ref);
                if (Lisp.Wcmatch(u, "MT-*") || (mats != null && mats.Contains(u))) continue;
                if (mats == null || Lisp.Wcmatch(u, "QD-*") || qds.Contains(u)) return true;
            }
            return false;
        }

        // (Dyl:QuickDrawAsmDefs): the default assemblies (as-*, the default file, never its user
        // copy) fixed, as they are written:
        public static List<string[]> Defs(Bundle b)
        {
            string fle = Presets.Default(b, Spec);
            Func<string, string> gc = g => Groups.CaseOf(b, g, null);
            return b.Rows(fle, Spec.Header.Length)
                    .Select(r => Fix(r, null, gc))
                    .Where(r => Lisp.Wcmatch(Lisp.StrCase(r[0]), Spec.Default))
                    .ToList();
        }

        // (Dyl:QuickDrawAsmScale row f n): an assembly in millimetres with its thicknesses
        // multiplied by f, each with n decimals at most (dimzin: DIMZIN, which rtos follows); any
        // other as it is, and one whose layers hold tabs (rows the window gave back not valid):
        public static string[] Scale(string[] row, double f, int n, int dimzin)
        {
            if (Lisp.Nth(row, 7) != "mm" || f == 1.0 || row[3].Contains('\t')) return row;
            var ls = Layers(row[3]).Select(l => Lisp.Distof(l.Thick) is double v ? l.With(Lisp.NumP(f * v, n, dimzin)) : l);
            return Lisp.Subst(row, 3, LayersStr(ls));
        }

        // (Dyl:QuickDrawAsmReadAll): the assemblies of the file fixed and cleaned, the defaults
        // missing added (Remote>>Dyl:PresetRead), in the units of the drawing (f: the drawing
        // units in a millimetre, Dyl:QuickDrawAsmFactor; 8 decimals); null when the file has a
        // layer the Lisp reads (NeedsLisp). Kept while none of the files changed:
        public static List<string[]> Read(Bundle b, double f, int dimzin)
        {
            string stamp = Presets.Stamps(b) + "|" + f.ToString("R") + "|" + dimzin;
            if (b.Reads.TryGetValue("Assemblies", out var o) && o is Kept k && k.Stamp == stamp) return k.Rows;
            var rows = Presets.Csv(b, Spec);
            List<string[]> res = null;
            var mats = MaterialIds(b);
            var qds = new HashSet<string>(Presets.Csv(b, Presets.QuickDraw).Select(r => Lisp.StrCase(r[0])), StringComparer.Ordinal);
            var dfl = b.Rows(Presets.Default(b, Spec), Spec.Header.Length);
            if (!rows.Concat(dfl).Any(r => NeedsLisp(r, mats, qds)))
            {
                var defs = Defs(b);
                Func<string, string> gc = g => Groups.CaseOf(b, g, null);
                var lst = Presets.Clean(Spec, rows.Select(r => Fix(r, defs, gc)), defs);
                var ids = new HashSet<string>(lst.Select(r => r[0]), StringComparer.Ordinal);
                foreach (var d in defs) if (!ids.Contains(d[0])) lst.Add(d);
                res = lst.Select(r => Scale(r, f, 8, dimzin)).ToList();
            }
            b.Reads["Assemblies"] = new Kept { Stamp = stamp, Rows = res };
            return res;
        }

        // The ids of the materials in upper case (those of the file and the defaults), null when
        // the default file is missing (the materials of the code of the Lisp):
        static HashSet<string> MaterialIds(Bundle b)
        {
            var defs = Presets.DefsOf(b, Presets.Material, null, null);
            if (defs == null) return null;
            var lst = Presets.Clean(Presets.Material, Presets.Csv(b, Presets.Material), defs);
            return new HashSet<string>(lst.Concat(defs).Select(r => Lisp.StrCase(r[0])), StringComparer.Ordinal);
        }

        sealed class Kept
        {
            public string Stamp;
            public List<string[]> Rows;
        }
    }
}
