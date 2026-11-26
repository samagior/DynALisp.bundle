// Shows.cs - DynALisp.Core.Data: what the Quick Draw window shows of each assembly
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
// What the Quick Draw window shows of each assembly preset (Apps\Draw\Dyl-QuickDraw.lsp), with
// the previews and the data of Remote\Dyl-Materials.lsp. Each function gives what the Lisp
// function it is named after gives, step for step:
//   Shows.Show           Dyl:QuickDrawAsmShow             what is shown of an assembly
//   Shows.All            Dyl:QuickDrawAsmShows            the same for every assembly read
//   Shows.Desc           Dyl:QuickDrawLayersDesc          the description of its layers
//   Shows.Ratings        Dyl:QuickDrawAsmRatingsText      its ratings
//   Shows.Preview        Dyl:QuickDrawGalleryLayers       its preview
//   Shows.Band           Remote>>Dyl:MaterialBand         a band of a preview
//   Shows.Data           Remote>>Dyl:MaterialAssemblyData its thermal resistance and mass
//   Shows.DataText       Remote>>Dyl:MaterialAssemblyText the same as text
//   Shows.Sig            Remote>>Dyl:MaterialSig          a number of 4 significant digits
//   Shows.Patterns       the patterns whose units the Lisp gives (Remote>>Dyl:MaterialPatUnits)
// What depends on the drawing comes from the Lisp: its system variables (Units) and the units
// of each pattern, found by AutoCAD on its support path. A drawing whose lengths are not
// decimal (LUNITS other than 2: rtos then writes feet and inches, or fractions) is left to the
// Lisp (null).

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    // The system variables of the drawing that what is shown depends on:
    public sealed class Units
    {
        public double? CannoScale;  // CANNOSCALEVALUE (nil: null)
        public int Measurement, Insunits, Lunits = 2, Luprec = 4, Dimzin;

        // (Remote>>Dyl:MaterialUnitMetres): the metres of a drawing unit:
        public double Metres =>
            Insunits == 1 ? 0.0254 : Insunits == 2 ? 0.3048 : Insunits == 4 ? 0.001 : Insunits == 5 ? 0.01 : Insunits == 6 ? 1.0
            : Measurement == 1 ? 0.001 : 0.0254;

        // (Dyl:QuickDrawAsmFactor): the drawing units in a millimetre:
        public double Factor => 0.001 / Metres;

        // (Remote>>Dyl:MaterialImperial-p):
        public bool Imperial => Measurement == 0;

        // (Remote>>Dyl:MaterialDrawScale): 1:50 -> 50.0, 1.0 when it cannot be read:
        public double DrawScale => CannoScale is double v && v > 0 ? 1.0 / v : 1.0;

        public string Key => string.Join(",", (CannoScale?.ToString("R") ?? "nil"), Measurement, Insunits, Lunits, Luprec, Dimzin);
    }

    public static class Shows
    {
        // *mt:asmdata*: the factors of the data of an assembly in imperial units (RSI -> R,
        // kg/m2 -> lb/ft2):
        const double RImp = 5.678263, MImp = 0.2048161;

        // *hp:none*: the hatch of a material without hatch preset (no pattern):
        public static readonly string[] HpNone =
            new[] { "", "", "", "", "1.0", "1.0", "0", "THIN", "HATCH", "1", "0", "1" }.Concat(Materials.Extra).ToArray();

        // The units of a pattern (Remote>>Dyl:MaterialPatUnits): "Imperial" or "Metric" and the
        // file that defines it, null when no file does:
        public delegate (string Units, string File)? PatUnits(string pattern);

        // (Remote>>Dyl:MaterialJoinAs m hps "Cut"): the material row m joined to its Cut hatch
        // preset:
        public static string[] Join(string[] m, List<string[]> hps)
        {
            var hp = (m[3] != "" ? Presets.Assoc(m[3], hps) : null) ?? HpNone;
            return new[] { m[0], m[1], m[2] }.Concat(hp.Skip(3)).ToArray();
        }

        // What a material is looked for in (Dyl:QuickDrawGalleryMat): the materials joined
        // (pst:mats), by id as written, else in any case:
        sealed class Mats
        {
            public readonly List<string[]> Joined, Rows;
            readonly Dictionary<string, string[]> exact = new Dictionary<string, string[]>(StringComparer.Ordinal);
            readonly Dictionary<string, string[]> upper = new Dictionary<string, string[]>(StringComparer.Ordinal);
            readonly Dictionary<string, string[]> rowsUp = new Dictionary<string, string[]>(StringComparer.Ordinal);

            public Mats(List<string[]> hps, List<string[]> rows)
            {
                Rows = rows;
                Joined = rows.Select(m => Join(m, hps)).ToList();
                foreach (var m in Joined)
                {
                    if (!exact.ContainsKey(m[0])) exact[m[0]] = m;
                    var u = Lisp.StrCase(m[0]);
                    if (!upper.ContainsKey(u)) upper[u] = m;
                }
                foreach (var m in rows)
                {
                    var u = Lisp.StrCase(m[0]);
                    if (!rowsUp.ContainsKey(u)) rowsUp[u] = m;
                }
            }

            // (Dyl:QuickDrawGalleryMat id): (Remote>>Dyl:MaterialGet id) finds no other one, every
            // material being among them:
            public string[] Get(string id) =>
                exact.TryGetValue(id, out var m) ? m : upper.TryGetValue(Lisp.StrCase(id), out m) ? m : null;

            // The row of the material id among the material rows (qd:mrows), in any case:
            public string[] Row(string id) => rowsUp.TryGetValue(Lisp.StrCase(id), out var m) ? m : null;
        }

        // (rtos v) of the drawing: its LUNITS decimal, LUPREC decimals:
        static string Rtos(double v, Units u) => Lisp.Rtos(v, u.Luprec, u.Dimzin);

        // (atoi s) of C: its leading spaces, a sign, its digits:
        static int Atoi(string s)
        {
            int i = 0, sign = 1;
            long n = 0;
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r' || s[i] == '\f' || s[i] == '\v')) i++;
            if (i < s.Length && (s[i] == '+' || s[i] == '-')) sign = s[i++] == '-' ? -1 : 1;
            while (i < s.Length && s[i] >= '0' && s[i] <= '9' && n < int.MaxValue) n = n * 10 + (s[i++] - '0');
            return (int)Math.Max(int.MinValue, Math.Min(int.MaxValue, sign * n));
        }

        static double Thick(Layer l) => Lisp.Distof(l.Thick) ?? 0.0;

        // (Remote>>Dyl:MaterialSig v):
        public static string Sig(double v, int dimzin)
        {
            if (!(0 < v)) return Lisp.NumP(v, 4, dimzin);
            double e = Math.Log(v) / Math.Log(10.0);
            int k = (int)Math.Truncate(e);
            if (e < 0) k -= 1;
            return Lisp.NumP(v, Math.Max(0, Math.Min(8, 3 - k)), dimzin);
        }

        // (Remote>>Dyl:MaterialLayerData m): per drawing unit of thickness, (r-per-unit r-fixed
        // mass-per-unit), null when not known:
        static (double? R, double? Fixed, double? M) LayerData(string[] m, Units u)
        {
            double metres = u.Metres;
            double? k = Lisp.Distof(Lisp.Nth(m, 5) ?? ""), d = Lisp.Distof(Lisp.Nth(m, 6) ?? ""), r = Lisp.Distof(Lisp.Nth(m, 7) ?? "");
            double fr = u.Imperial ? RImp : 1.0, fm = u.Imperial ? MImp : 1.0;
            bool kr = k != null || r != null;
            return (kr ? (k is double kk ? fr * (metres / kk) : 0.0) : (double?)null,
                    kr ? (r is double rr ? fr * rr : 0.0) : (double?)null,
                    d is double dd ? fm * dd * metres : (double?)null);
        }

        // (Remote>>Dyl:MaterialLayerOf id th mats):
        static (double? R, double? M) LayerOf(string id, double th, Mats mats, Units u)
        {
            var m = mats.Row(id);
            var d = m != null ? LayerData(m, u) : (null, null, null);
            return (d.R is double r ? th * r + d.Fixed.Value : (double?)null, d.M is double mm ? th * mm : (double?)null);
        }

        // (Remote>>Dyl:MaterialLayerValues l mats):
        static (double? R, double? M) LayerValues(Layer l, Mats mats, Units u)
        {
            double th = Thick(l);
            var c = LayerOf(l.Ref, th, mats, u);
            if (l.Framing == null) return c;
            var fr = LayerOf(l.Framing[0], th, mats, u);
            double f = Lisp.Distof(l.Framing[1].Replace(',', '.')).Value / 100.0;
            double? r = c.R is double cr && fr.R is double frr
                ? (0 < cr && 0 < frr ? 1.0 / (f / frr + (1.0 - f) / cr) : 0.0)
                : (double?)null;
            double? m = c.M is double cm && fr.M is double fmm ? f * fmm + (1.0 - f) * cm : (double?)null;
            return (r, m);
        }

        // (Remote>>Dyl:MaterialAssemblyData ls mats ext): (resistance mass n-resistance n-mass
        // continuous n-continuous ratio):
        public sealed class AsmData
        {
            public double R, M;
            public int NR, NM, NC;
            public double? C, Ratio;
        }

        static AsmData Data(List<Layer> ls, Mats mats, string ext, Units u)
        {
            var d = new AsmData();
            foreach (var l in ls)
            {
                var v = LayerValues(l, mats, u);
                if (v.R is double r) d.R += r; else d.NR++;
                if (v.M is double m) d.M += m; else d.NM++;
                if (l.Framing == null)
                {
                    if (v.R is double cr) d.C = (d.C ?? 0.0) + cr;
                    else { d.C = d.C ?? 0.0; d.NC++; }
                }
            }
            if (!ls.Any(l => l.Framing != null)) { d.C = null; d.NC = 0; }
            d.Ratio = PermRatio(ls, mats, ext, u);
            return d;
        }

        // (Remote>>Dyl:MaterialPermRatio ls mats ext): nil without a layer of low permeance, -1
        // when a layer has no thermal resistance or nothing is inboard:
        static double? PermRatio(List<Layer> ls, Mats mats, string ext, Units u)
        {
            var lst = Lisp.StrCase(ext ?? "") == "LAST" ? Enumerable.Reverse(ls).ToList() : ls;
            if (!lst.Any(l => l.LowPerm == "1")) return null;
            double o = 0.0, i = 0.0;
            bool past = false, bad = false;
            foreach (var l in lst)
            {
                var d = LayerValues(l, mats, u).R;
                if (d == null) bad = true;
                else if (past) i += d.Value;
                else o += d.Value;
                if (l.LowPerm == "1") past = true;
            }
            return bad ? -1 : 0.0 < i ? o / i : -1;
        }

        static string Miss(int n) => n == 0 ? "" : n == 1 ? "  (1 layer unknown)" : "  (" + n + " layers unknown)";

        // (Remote>>Dyl:MaterialAssemblyText d):
        static string DataText(AsmData d, Units u)
        {
            string rs = u.Imperial ? "R " : "RSI ";
            return "Thermal resistance  " + rs + Sig(d.R, u.Dimzin) + Miss(d.NR)
                 + "\nMass  " + Sig(d.M, u.Dimzin) + (u.Imperial ? " lb/ft2" : " kg/m2") + Miss(d.NM)
                 + (d.C is double c ? "\nContinuous layers  " + rs + Sig(c, u.Dimzin) + Miss(d.NC) : "")
                 + (d.Ratio == null ? "" : d.Ratio < 0 ? "\nLow permeance ratio  unknown" : "\nLow permeance ratio  " + Lisp.Rtos(d.Ratio.Value, 2, u.Dimzin));
        }

        // (Dyl:QuickDrawLayersDesc ls ext):
        static string Desc(List<Layer> ls, string ext, Mats mats, Units u)
        {
            if (ls.Count == 0) return "";
            double sum = 0.0;
            foreach (var l in ls) sum += Thick(l);
            var sb = new System.Text.StringBuilder("Total thickness  " + Rtos(sum, u));
            foreach (var l in ls)
            {
                var rec = mats.Get(l.Ref);
                sb.Append('\n').Append(rec != null ? rec[2] : l.Ref);
                if (l.Framing != null)
                {
                    var fr = mats.Get(l.Framing[0]);
                    sb.Append(" + ").Append(fr != null ? fr[2] : l.Framing[0]).Append(' ').Append(l.Framing[1]).Append('%');
                }
                sb.Append("  ").Append(Rtos(Lisp.Distof(l.Thick).Value, u));
                if (l.Bearing == "1") sb.Append("  (load-bearing)");
                if (l.Variable == "1") sb.Append("  (variable)");
                if (l.LowPerm == "1") sb.Append("  (low permeance)");
            }
            sb.Append("\n\n").Append(DataText(Data(ls, mats, ext, u), u));
            return sb.ToString();
        }

        // (Dyl:QuickDrawAsmMinutes v):
        static string Minutes(string v, int dimzin)
        {
            int n = Atoi(v);
            return 60 <= n && n % 30 == 0 ? Lisp.NumP(n / 60.0, 4, dimzin) + " h" : n + " min";
        }

        // (Dyl:QuickDrawAsmRatingsText a):
        static string Ratings(string[] a, int dimzin)
        {
            var lst = new List<string>();
            if (a[9] != "") lst.Add("Fire-resistance rating " + Minutes(a[9], dimzin));
            if (a[10] != "") lst.Add((lst.Count > 0 ? "non-load-bearing " : "Fire-resistance rating, non-load-bearing ") + Minutes(a[10], dimzin));
            if (a[11] != "") lst.Add("STC " + a[11]);
            if (a[12] != "") lst.Add("IIC " + a[12]);
            return string.Join(", ", lst);
        }

        // (Remote>>Dyl:MaterialBand kind mat w), mat with its No hatch off (column 64, see
        // Remote>>Dyl:MaterialNoHatch):
        static string Band(string kind, string[] mat, double w, Units u, PatUnits pats)
        {
            string ws = Lisp.NumP(w, 6, u.Dimzin);
            if (kind == "S" || kind == "L") return kind + "?" + ws;
            if (mat == null) return "X?" + ws;
            if (mat[3] == "") return "S?" + ws;
            string pat = Lisp.StrCase(mat[3]);
            if (pat == "SOLID") return "F?" + ws;
            var pu = pats(pat);
            double s = Lisp.Distof(mat[4]) ?? 1.0;
            double ds = mat[9] == "1" || mat[10] == "1" ? 1.0 : u.DrawScale;
            if (pu?.Units == "Metric") s = s / 25.4;
            return "P?" + ws + "?" + pat + "?" + (pu?.File ?? "") + "?" + Lisp.NumP(s / ds, 8, u.Dimzin)
                 + "?" + Lisp.NumP(Lisp.Distof(mat[6]) ?? 0.0, 4, u.Dimzin)
                 + "?" + Lisp.NumP(ds, 4, u.Dimzin)
                 + "?" + (mat[63] == "Model" ? "Model" : "Drafting");
        }

        // (Dyl:QuickDrawGalleryLayers ls lines):
        static string Preview(List<Layer> ls, string[] border, string[] dividing, Mats mats, Units u, PatUnits pats)
        {
            var res = new List<string>();   // (as the Lisp list: its first item first)
            foreach (var l in ls)
            {
                string b = Band(l.Hatch[0] == "0" ? "S" : "P", mats.Get(l.Ref), Thick(l), u, pats);
                if (l.Border != null && l.Border[0] == "1")
                {
                    var rest = res.Count > 0 && res[0] == "L?0" ? res.Skip(1) : res;
                    res = new[] { "L?0", b, "L?0" }.Concat(rest).ToList();
                }
                else if (res.Count > 0 && dividing[0] == "1" && res[0] != "L?0") res.InsertRange(0, new[] { b, "L?0" });
                else res.Insert(0, b);
            }
            bool outline = border[0] == "1";
            if (outline && res.Count > 1 && res[0] == "L?0") res.RemoveAt(0);
            res.Reverse();
            if (outline && res.Count > 1 && res[0] == "L?0") res.RemoveAt(0);
            return (outline ? "O*" : "") + string.Join("*", res);
        }

        // (Dyl:QuickDrawAsmShow a): what its layers are, their width, its preview and its
        // description; null when one of its layers is not a P layer (the assemblies fixed have
        // none):
        static string[] Show(string[] a, Mats mats, Units u, PatUnits pats)
        {
            var ls = Assemblies.Layers(a[3]);
            if (ls.Any(l => l.Kind != "P")) return null;
            string d = Desc(ls, a[6], mats, u), r = Ratings(a, u.Dimzin);
            if (r != "") d = d + (d == "" ? "" : "\n") + r;
            if (a[8] != "") d = d + (d == "" ? "" : "\n\n") + a[8];
            int n = ls.Count;
            double sum = 0.0;
            foreach (var l in ls) sum += Thick(l);
            return new[]
            {
                a[0],
                n == 0 ? "No layers" : n == 1 ? "1 layer" : n + " layers",
                Lisp.NumP(sum, 4, u.Dimzin),
                n > 0 ? Preview(ls, Assemblies.Lines(a[4]), Assemblies.Lines(a[5]), mats, u, pats) : "",
                d,
            };
        }

        // The patterns of the hatched layers of the assemblies (upper case, without SOLID),
        // whose units the Lisp gives to All (each one found reads a .pat file: only those
        // previewed); null when the assemblies or the materials are read by the Lisp:
        public static List<string> Patterns(Bundle b, Units u)
        {
            var both = Materials.Both(b, u.Dimzin);
            var asms = u.Lunits == 2 ? Assemblies.Read(b, u.Factor, u.Dimzin) : null;
            if (both == null || asms == null) return null;
            var mats = new Mats(both.Value.Hatches, both.Value.Rows);
            var res = new SortedSet<string>(StringComparer.Ordinal);
            foreach (var a in asms)
                foreach (var l in Assemblies.Layers(a[3]))
                    if (l.Kind == "P" && l.Hatch[0] != "0" && mats.Get(l.Ref) is string[] m && m[3] != "")
                        res.Add(Lisp.StrCase(m[3]));
            res.Remove("SOLID");
            return res.ToList();
        }

        // (Dyl:QuickDrawAsmShows asms) for the assemblies read (Assemblies.Read, in the order
        // they are read): ((id layers width preview description) ...), pats the units of each
        // pattern; null when the Lisp makes them (see the header). Kept while none of the files,
        // the units nor the patterns changed:
        public static List<string[]> All(Bundle b, Units u, IDictionary<string, (string Units, string File)?> pats)
        {
            string stamp = Presets.Stamps(b) + "|" + u.Key + "|" + string.Join(";", pats.OrderBy(p => p.Key, StringComparer.Ordinal)
                                                                            .Select(p => p.Key + "=" + p.Value?.Units + "," + p.Value?.File));
            if (b.Reads.TryGetValue("Shows", out var o) && o is Kept k && k.Stamp == stamp) return k.Rows;
            List<string[]> res = null;
            var both = Materials.Both(b, u.Dimzin);
            var asms = u.Lunits == 2 ? Assemblies.Read(b, u.Factor, u.Dimzin) : null;
            if (both != null && asms != null)
            {
                var mats = new Mats(both.Value.Hatches, both.Value.Rows);
                PatUnits pu = p => pats.TryGetValue(p, out var v) ? v : null;
                res = new List<string[]>(asms.Count);
                foreach (var a in asms)
                {
                    var s = Show(a, mats, u, pu);
                    if (s == null) { res = null; break; }
                    res.Add(s);
                }
            }
            b.Reads["Shows"] = new Kept { Stamp = stamp, Rows = res };
            return res;
        }

        sealed class Kept
        {
            public string Stamp;
            public List<string[]> Rows;
        }
    }
}
