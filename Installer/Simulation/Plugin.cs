// Plugin.cs - DynALisp.Simulation: the Lisp functions of the simulation
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
// The Lisp side (Apps\Analysis\Dyl-Simulation.lsp) keeps what it already does: the materials,
// the climates, the units, the windows. It calls (each one checked first, (if Dyl:X ...)):
//
//   (Dyl:SimulationRead zone size known data climates)
//     zone: the closed curve of the simulation zone; size: the target size of the cells, in
//     drawing units; known: the ids of every material; data: the ids of the materials that have
//     a thermal conductivity or a fixed RSI; climates: the ids of every climate.
//     Reads the detail of the zone, shows its grid and its problems over the drawing, and
//     returns (cells nx ny regions nomaterial unknown nodata holes overlaps badclimates
//     climatecells grid (material ...)): the cells of the zone; the columns and rows of the
//     grid; the regions in the zone; those of a hatch without a material, of a material that
//     no longer exists, of a material without data; the holes (groups of cells of no region);
//     the cells inside two regions of a material or more (the one in front wins); the climate
//     zones of a climate that no longer exists; the cells of climate (air); 1 when the grid
//     was drawn (0: too dense to be read); the materials of the regions. A text when the zone
//     cannot be read (the message).
//
//     The climates of the climate zones in the zone follow, as a list (climate ...).
//
//   (Dyl:SimulationRun zone size known mats climates imperial metres)
//     zone, size, known: as above; mats: a text "id|conductivity|resistance|permeability|
//     permeance" for each material that has a conductivity or a resistance (W/(m.K), m2.K/W,
//     ng/(Pa.s.m), ng/(Pa.s.m2), each one empty when not known); climates: a text
//     "id|temperature|humidity|rs|rscondensation" for each climate (C, %, m2.K/W, empty when
//     not known); imperial: 1 for the labels in F, else 0; metres: the metres of a drawing
//     unit (Remote>>Dyl:MaterialUnitMetres).
//     Reads and checks the zone as Dyl:SimulationRead. With a problem (or a climate of the
//     zone without a temperature), shows it as Dyl:SimulationRead and returns (check nil).
//     Else solves the heat through the detail (Core\Thermal.cs) twice, with the surface
//     resistances of the heat and with those of the condensation, shows its temperatures
//     over the drawing (blue at the exterior, red at the interior), the line of the dew point
//     of the interior air, the interior surfaces colder than it and the coldest one, and
//     returns (check result): check the list of Dyl:SimulationRead, result a list of pairs
//     (("Interior" . id) ("Exterior" . id) ("Ti" . C) ("Te" . C) ("Q" . W/m) ("L2D" . W/(m.K))
//     ("Length" . m) ("Rsi" . m2.K/W) ("Tsi" . C) ("TsiAt" x y) ("TsiMaterial" . id)
//     ("fRsi" . x) ("Dew" . C) ("BelowDew" . m) ("Isolated" . cells) ("Iterations" . n)),
//     a value not known left out. When every material of the detail has a vapour
//     permeability (or permeance) and every climate a humidity, also solves the vapour
//     (Core\Vapour.cs, Glaser, with the temperatures of the heat), shows the cells where it
//     condenses and adds ("Vapour" . 1) ("MaxRh" . %) ("Condensing" . cells) ("Rate" .
//     g/(m.day)) ("CondensingArea" . m2) ("CondensingMaterials" id ...) ("Rounds" . n)
//     (("VapourNotConverged" . 1) when the cells held still changed); else
//     ("NoVapour" id ...) the materials without one, ("NoHumidity" id ...) the climates
//     without one. A text when the zone cannot be read or solved.
//
//   (Dyl:SimulationProbe point)
//     The result of the last run of the current drawing at point (WCS): (temperature material
//     climate [rh pv condensing]), temperature nil where the cell has none (a climate, a
//     hole), nil outside it; with the vapour of the run, its relative humidity (%), its
//     vapour pressure (Pa) and T where it condenses.
//
//   (Dyl:SimulationView "Humidity") or (Dyl:SimulationView "Temperature")
//     The last run shown again with its relative humidity or its temperatures; nil when
//     there is no run, or no vapour for the humidity.
//
//   (Dyl:SimulationClear)  clears what the simulation shows over the current drawing; T.

using System;
using System.Collections.Generic;
using System.Globalization;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using DynALisp.Simulation.Core;
using Shape = DynALisp.Simulation.Core.Shape;
using Region = DynALisp.Simulation.Core.Region;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Simulation.Plugin))]

namespace DynALisp.Simulation
{
    public class Plugin
    {
        [LispFunction("Dyl:SimulationRead")]
        public ResultBuffer Read(ResultBuffer args)
        {
            try
            {
                var a = Args(args);
                if (a.Count < 5 || !(a[0] is ObjectId zoneId) || !(a[1] is double size))
                    return Text("Dyl:SimulationRead: (zone size known data climates) expected.");
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                using (var tr = doc.Database.TransactionManager.StartTransaction())
                {
                    var ck = Check.Of(tr, zoneId, size, Set(a[2]), Set(a[3]), Set(a[4]), out string error);
                    tr.Commit();
                    if (ck == null) return Text(error);
                    ck.Show(doc);
                    var res = new ResultBuffer();
                    ck.Write(res);
                    return res;
                }
            }
            catch (System.Exception ex)
            {
                return Text("Dyl:SimulationRead: " + ex.Message);
            }
        }

        [LispFunction("Dyl:SimulationRun")]
        public ResultBuffer Run(ResultBuffer args)
        {
            try
            {
                var a = Args(args);
                if (a.Count < 6 || !(a[0] is ObjectId zoneId) || !(a[1] is double size))
                    return Text("Dyl:SimulationRun: (zone size known mats climates imperial metres) expected.");
                var mats = Table(a[3]);
                var clims = Table(a[4]);
                bool imperial = a[5] is double imp && imp != 0;
                var data = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var m in mats) if (Num(m.Value, 0) > 0 || Num(m.Value, 1) > 0) data.Add(m.Key);
                var climIds = new HashSet<string>(clims.Keys, StringComparer.OrdinalIgnoreCase);
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                double metres = a.Count > 6 && a[6] is double mu && mu > 0 ? mu : Metres(doc.Database);

                using (var tr = doc.Database.TransactionManager.StartTransaction())
                {
                    var ck = Check.Of(tr, zoneId, size, Set(a[2]), data, climIds, out string error);
                    tr.Commit();
                    if (ck == null) return Text(error);
                    var res = new ResultBuffer();
                    bool noTemp = false;
                    foreach (var c in ck.Climates)
                        if (clims.TryGetValue(c, out var row) && double.IsNaN(Num(row, 0))) noTemp = true;
                    if (ck.Problems || noTemp)
                    {
                        ck.Show(doc);
                        ck.Write(res);
                        res.Add(new TypedValue((int)LispDataType.Nil));
                        return res;
                    }

                    var d = ck.Detail;
                    int nr = d.Regions.Count;
                    double[] lambda = new double[nr], temp = new double[nr], rs = new double[nr], rsc = new double[nr], rh = new double[nr];
                    var delta = new double[nr];
                    var noVapour = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                    var noHumidity = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                    bool same = true;
                    for (int r = 0; r < nr; r++)
                    {
                        var reg = d.Regions[r];
                        lambda[r] = temp[r] = rs[r] = rsc[r] = rh[r] = delta[r] = double.NaN;
                        if (reg.IsClimate)
                        {
                            if (!clims.TryGetValue(reg.Climate, out var row)) continue;
                            temp[r] = Num(row, 0);
                            rh[r] = Num(row, 1);
                            rs[r] = Num(row, 2);
                            rsc[r] = Num(row, 3);
                            if (double.IsNaN(rs[r])) rs[r] = 0;
                            if (double.IsNaN(rsc[r])) rsc[r] = rs[r];
                            if (rsc[r] != rs[r]) same = false;
                            if (d.CellsOf[r] > 0 && !(rh[r] > 0)) noHumidity.Add(reg.Climate);
                        }
                        else if (mats.TryGetValue(reg.Material, out var row))
                        {
                            lambda[r] = Num(row, 0);
                            if (!(lambda[r] > 0)) lambda[r] = Thermal.Equivalent(reg.Shape, Num(row, 1), metres);
                            delta[r] = Num(row, 2);
                            if (!(delta[r] > 0)) delta[r] = Vapour.Equivalent(reg.Shape, Num(row, 3), metres);
                            if (d.CellsOf[r] > 0 && !(delta[r] > 0)) noVapour.Add(reg.Material);
                        }
                    }

                    var heat = Thermal.Solve(d, lambda, temp, rs, metres);
                    var surf = same ? heat : Thermal.Solve(d, lambda, temp, rsc, metres);
                    var sum = Summary.Of(heat, surf, temp, rh);

                    // The vapour, when every material has a permeability and every climate a
                    // humidity (the temperatures of the heat, ISO 13788):
                    Vapour vap = null;
                    if (noVapour.Count == 0 && noHumidity.Count == 0)
                    {
                        vap = Vapour.Solve(d, delta, rh, heat, temp, metres);
                        sum.Add(vap, metres);
                    }
                    var zb = ck.Zone.Bounds;
                    Show.Field(doc, new Show.Result
                    {
                        Heat = heat, Surface = surf, Summary = sum, Vapour = vap, Zone = ck.Zone, Imperial = imperial,
                        W = Math.Max(zb.Width, zb.Height) / 400,
                    });

                    ck.Write(res);
                    res.Add(new TypedValue((int)LispDataType.ListBegin));
                    Pair(res, "Interior", sum.Interior);
                    Pair(res, "Exterior", sum.Exterior);
                    Pair(res, "Ti", sum.Ti);
                    Pair(res, "Te", sum.Te);
                    Pair(res, "Q", sum.Q);
                    Pair(res, "L2D", sum.L2D);
                    Pair(res, "Length", sum.Length);
                    Pair(res, "Rsi", sum.Rsi);
                    Pair(res, "Tsi", sum.Tsi);
                    if (!double.IsNaN(sum.Tsi))
                    {
                        res.Add(new TypedValue((int)LispDataType.ListBegin));
                        res.Add(new TypedValue((int)LispDataType.Text, "TsiAt"));
                        res.Add(new TypedValue((int)LispDataType.Double, sum.TsiAt.X));
                        res.Add(new TypedValue((int)LispDataType.Double, sum.TsiAt.Y));
                        res.Add(new TypedValue((int)LispDataType.ListEnd));
                    }
                    Pair(res, "TsiMaterial", sum.TsiMaterial);
                    Pair(res, "fRsi", sum.FRsi);
                    Pair(res, "Dew", sum.Dew);
                    if (!double.IsNaN(sum.Dew)) Pair(res, "BelowDew", sum.BelowDew);
                    if (vap != null)
                    {
                        Pair(res, "Vapour", 1);
                        Pair(res, "MaxRh", sum.MaxRh);
                        Pair(res, "Condensing", sum.Condensing);
                        if (sum.Condensing > 0)
                        {
                            Pair(res, "Rate", sum.Rate);
                            Pair(res, "CondensingArea", sum.CondensingArea);
                            List(res, "CondensingMaterials", sum.CondensingMaterials);
                        }
                        if (!sum.VapourConverged) Pair(res, "VapourNotConverged", 1);
                        Pair(res, "Rounds", vap.Rounds);
                    }
                    else
                    {
                        List(res, "NoVapour", noVapour);
                        List(res, "NoHumidity", noHumidity);
                    }
                    Pair(res, "Isolated", heat.Isolated);
                    Pair(res, "Iterations", heat.Iterations);
                    res.Add(new TypedValue((int)LispDataType.ListEnd));
                    return res;
                }
            }
            catch (System.Exception ex)
            {
                return Text("Dyl:SimulationRun: " + ex.Message);
            }
        }

        [LispFunction("Dyl:SimulationProbe")]
        public ResultBuffer Probe(ResultBuffer args)
        {
            var a = Args(args);
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            var last = Show.Last(doc);
            if (last == null || a.Count < 1 || !(a[0] is Point3d pt)) return null;
            var d = last.Surface.Detail;
            int c = d.Grid.CellAt(new P(pt.X, pt.Y));
            if (c < 0 || d.Kind[c] == CellKind.Outside) return null;
            var res = new ResultBuffer();
            double t = last.Surface.T[c];
            res.Add(double.IsNaN(t) ? new TypedValue((int)LispDataType.Nil) : new TypedValue((int)LispDataType.Double, t));
            var reg = d.Owner[c] >= 0 ? d.Regions[d.Owner[c]] : null;
            res.Add(new TypedValue((int)LispDataType.Text, reg == null || reg.IsClimate ? "" : reg.Material));
            res.Add(new TypedValue((int)LispDataType.Text, reg != null && reg.IsClimate ? reg.Climate : ""));
            // The relative humidity (%) and the vapour pressure (Pa), and T when vapour condenses:
            var v = last.Vapour;
            if (v != null && !double.IsNaN(v.Pv[c]))
            {
                res.Add(new TypedValue((int)LispDataType.Double, Math.Min(100, v.Rh(c) * 100)));
                res.Add(new TypedValue((int)LispDataType.Double, v.Pv[c]));
                res.Add(new TypedValue((int)(v.Condensing[c] ? LispDataType.T_atom : LispDataType.Nil)));
            }
            return res;
        }

        // (Dyl:SimulationView "Humidity") or "Temperature": the last run shown again with that
        // field; nil when there is no run (or no vapour for the humidity):
        [LispFunction("Dyl:SimulationView")]
        public ResultBuffer View(ResultBuffer args)
        {
            var a = Args(args);
            bool wet = a.Count > 0 && a[0] is string k && k.Equals("Humidity", StringComparison.OrdinalIgnoreCase);
            return Show.View(AcApp.DocumentManager.MdiActiveDocument, wet)
                ? new ResultBuffer(new TypedValue((int)LispDataType.T_atom)) : null;
        }

        [LispFunction("Dyl:SimulationClear")]
        public ResultBuffer Clear(ResultBuffer args)
        {
            Show.Clear(AcApp.DocumentManager.MdiActiveDocument);
            return new ResultBuffer(new TypedValue((int)LispDataType.T_atom));
        }

        static ResultBuffer Text(string s) => new ResultBuffer(new TypedValue((int)LispDataType.Text, s));

        // A pair (key . value) of a result, left out when the value is not known:
        static void Pair(ResultBuffer res, string key, object v)
        {
            if (v is double x && (double.IsNaN(x) || double.IsInfinity(x))) return;
            if (v is string t && t.Length == 0) return;
            res.Add(new TypedValue((int)LispDataType.ListBegin));
            res.Add(new TypedValue((int)LispDataType.Text, key));
            if (v is double dv) res.Add(new TypedValue((int)LispDataType.Double, dv));
            else if (v is int iv) res.Add(new TypedValue((int)LispDataType.Int32, iv));
            else res.Add(new TypedValue((int)LispDataType.Text, v.ToString()));
            res.Add(new TypedValue((int)LispDataType.DottedPair));
        }

        // A list (key "text" ...) of a result, left out when it is empty:
        static void List(ResultBuffer res, string key, IEnumerable<string> items)
        {
            var l = new List<string>(items);
            if (l.Count == 0) return;
            res.Add(new TypedValue((int)LispDataType.ListBegin));
            res.Add(new TypedValue((int)LispDataType.Text, key));
            foreach (var x in l) res.Add(new TypedValue((int)LispDataType.Text, x));
            res.Add(new TypedValue((int)LispDataType.ListEnd));
        }

        // Texts "id|value|value..." by id (the values after the id):
        static Dictionary<string, string[]> Table(object o)
        {
            var t = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
            if (o is List<string> l)
                foreach (var x in l)
                {
                    var f = x.Split('|');
                    if (f[0].Length == 0) continue;
                    var v = new string[f.Length - 1];
                    Array.Copy(f, 1, v, 0, v.Length);
                    t[f[0]] = v;
                }
            return t;
        }

        // The number of the field i of a row (a decimal comma read as a point), NaN when empty:
        static double Num(string[] row, int i)
        {
            if (row == null || i >= row.Length) return double.NaN;
            var s = row[i].Trim().Replace(',', '.');
            return double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : double.NaN;
        }

        // The metres of a drawing unit when the Lisp gives none (INSUNITS, the same rule as
        // Remote>>Dyl:MaterialUnitMetres: change both together):
        static double Metres(Database db)
        {
            switch (db.Insunits)
            {
                case UnitsValue.Inches: return 0.0254;
                case UnitsValue.Feet: return 0.3048;
                case UnitsValue.Millimeters: return 0.001;
                case UnitsValue.Centimeters: return 0.01;
                case UnitsValue.Meters: return 1;
                default: return db.Measurement == MeasurementValue.English ? 0.0254 : 0.001;
            }
        }

        // The arguments of a Lisp call: an ObjectId, a double (an integer read as one), a list of
        // texts (List<string>, nil an empty list), in their order:
        static List<object> Args(ResultBuffer rb)
        {
            var res = new List<object>();
            if (rb == null) return res;
            List<string> list = null;
            foreach (var tv in rb)
            {
                switch ((LispDataType)tv.TypeCode)
                {
                    case LispDataType.ListBegin: list = new List<string>(); break;
                    case LispDataType.ListEnd:
                    case LispDataType.DottedPair:
                        if (list != null) { res.Add(list); list = null; }
                        break;
                    case LispDataType.Text:
                        if (list != null) list.Add((string)tv.Value); else res.Add((string)tv.Value);
                        break;
                    case LispDataType.Nil:
                        if (list == null) res.Add(new List<string>());
                        break;
                    case LispDataType.Double: if (list == null) res.Add((double)tv.Value); break;
                    case LispDataType.Int16: if (list == null) res.Add((double)(short)tv.Value); break;
                    case LispDataType.Int32: if (list == null) res.Add((double)(int)tv.Value); break;
                    case LispDataType.ObjectId: if (list == null) res.Add((ObjectId)tv.Value); break;
                    case LispDataType.Point3d: if (list == null) res.Add((Point3d)tv.Value); break;
                }
            }
            return res;
        }

        static HashSet<string> Set(object o)
        {
            var s = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (o is List<string> l) foreach (var x in l) s.Add(x);
            return s;
        }
    }
}
