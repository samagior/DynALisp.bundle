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
//   (Dyl:SimulationMonthly zone size known mats climates months imperial metres)
//     As Dyl:SimulationRun, months a text "id|t1|...|t12|rh1|...|rh12" for each climate (C, %,
//     January first, each one empty when not typed): the monthly balance of ISO 13788
//     (Core\Monthly.cs). A climate of the zone without its months is the same all year; one
//     with some months and not all of them is a problem. Without a climate of its twelve
//     months, a material without vapour data or a climate without a humidity, shows the check
//     and returns (check (("NoMonths" . 1) ("PartMonths" id ...) ("NoVapour" id ...)
//     ("NoHumidity" id ...))). Else shows the month that holds the most water (its cells that
//     hold water in magenta; no water: the coldest month) and returns (check result), result
//     the pairs of the heat of that month as Dyl:SimulationRun, then ("Vapour" . 1)
//     ("Monthly" . 1) ("Shown" . month) ("Start" . month, 0: no month condenses)
//     ("MaxWater" . g/m) ("MaxMonth" . month) ("Remaining" . g/m) ("Dries" . 1 or 0)
//     ("WaterMaterials" id ...) ("Months" (month Ti Te condenses condensed dried water wet)
//     ...), the months from 1 (January), the water in g per metre of depth.
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
//   (Dyl:SimulationKeep step height hatch)
//     Adds the last run of the current drawing to its current space, on the current layer
//     (Keep.cs): the isotherms every step degrees (F in an imperial drawing; 0: none), each
//     level labelled once with a text of height height, the line of the dew point and its
//     label, and a hatch over the cells where vapour condenses, its lines hatch apart (drawing
//     units). Returns (("Isotherm" ename ...) ("Label" ename ...) ("Dew" ename ...)
//     ("Condensation" ename ...)), a kind with nothing left out; nil when there is no run.
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

        // What a run reads from its arguments: the detail checked, the data of each of its
        // regions by index (lambda, delta: the materials; temp, rh, rs, rsc: the climates), the
        // materials of the detail without vapour data and its climates without a humidity:
        class Input
        {
            public Check Ck;
            public double[] Lambda, Delta, Temp, Rh, Rs, Rsc;
            public bool Same = true;
            public SortedSet<string> NoVapour = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
            public SortedSet<string> NoHumidity = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
            public Dictionary<string, string[]> Climates;
            public double Metres;
            public bool Imperial;
        }

        // The input of a run (zone size known mats climates, then imperial and metres at ip and
        // ip + 1), or null with the result to return (res: the check and nil when the detail has
        // a problem, or a climate of the zone has no temperature, but those of yearly that have
        // their months; a text when it cannot be read):
        static Input Prepare(List<object> a, int ip, out ResultBuffer res, ISet<string> yearly = null)
        {
            res = null;
            var mats = Table(a[3]);
            var clims = Table(a[4]);
            var data = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var m in mats) if (Num(m.Value, 0) > 0 || Num(m.Value, 1) > 0) data.Add(m.Key);
            var climIds = new HashSet<string>(clims.Keys, StringComparer.OrdinalIgnoreCase);
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            var inp = new Input
            {
                Climates = clims,
                Imperial = a.Count > ip && a[ip] is double imp && imp != 0,
                Metres = a.Count > ip + 1 && a[ip + 1] is double mu && mu > 0 ? mu : Metres(doc.Database),
            };
            using (var tr = doc.Database.TransactionManager.StartTransaction())
            {
                var ck = Check.Of(tr, (ObjectId)a[0], (double)a[1], Set(a[2]), data, climIds, out string error);
                tr.Commit();
                if (ck == null) { res = Text(error); return null; }
                bool noTemp = false;
                foreach (var c in ck.Climates)
                    if (clims.TryGetValue(c, out var row) && double.IsNaN(Num(row, 0)) && !(yearly?.Contains(c) ?? false)) noTemp = true;
                if (ck.Problems || noTemp)
                {
                    ck.Show(doc);
                    res = new ResultBuffer();
                    ck.Write(res);
                    res.Add(new TypedValue((int)LispDataType.Nil));
                    return null;
                }
                inp.Ck = ck;
            }

            var d = inp.Ck.Detail;
            int nr = d.Regions.Count;
            inp.Lambda = new double[nr]; inp.Temp = new double[nr]; inp.Rs = new double[nr];
            inp.Rsc = new double[nr]; inp.Rh = new double[nr]; inp.Delta = new double[nr];
            for (int r = 0; r < nr; r++)
            {
                var reg = d.Regions[r];
                inp.Lambda[r] = inp.Temp[r] = inp.Rs[r] = inp.Rsc[r] = inp.Rh[r] = inp.Delta[r] = double.NaN;
                if (reg.IsClimate)
                {
                    if (!clims.TryGetValue(reg.Climate, out var row)) continue;
                    inp.Temp[r] = Num(row, 0);
                    inp.Rh[r] = Num(row, 1);
                    inp.Rs[r] = Num(row, 2);
                    inp.Rsc[r] = Num(row, 3);
                    if (double.IsNaN(inp.Rs[r])) inp.Rs[r] = 0;
                    if (double.IsNaN(inp.Rsc[r])) inp.Rsc[r] = inp.Rs[r];
                    if (inp.Rsc[r] != inp.Rs[r]) inp.Same = false;
                }
                else if (mats.TryGetValue(reg.Material, out var row))
                {
                    inp.Lambda[r] = Num(row, 0);
                    if (!(inp.Lambda[r] > 0)) inp.Lambda[r] = Thermal.Equivalent(reg.Shape, Num(row, 1), inp.Metres);
                    inp.Delta[r] = Num(row, 2);
                    if (!(inp.Delta[r] > 0)) inp.Delta[r] = Vapour.Equivalent(reg.Shape, Num(row, 3), inp.Metres);
                    if (d.CellsOf[r] > 0 && !(inp.Delta[r] > 0)) inp.NoVapour.Add(reg.Material);
                }
            }
            return inp;
        }

        // The climates of the zone without a humidity (rh by region):
        static SortedSet<string> NoHumidity(Detail d, double[] rh)
        {
            var res = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
            for (int r = 0; r < d.Regions.Count; r++)
                if (d.Regions[r].IsClimate && d.CellsOf[r] > 0 && !(rh[r] > 0)) res.Add(d.Regions[r].Climate);
            return res;
        }

        [LispFunction("Dyl:SimulationRun")]
        public ResultBuffer Run(ResultBuffer args)
        {
            try
            {
                var a = Args(args);
                if (a.Count < 6 || !(a[0] is ObjectId) || !(a[1] is double))
                    return Text("Dyl:SimulationRun: (zone size known mats climates imperial metres) expected.");
                var inp = Prepare(a, 5, out var early);
                if (inp == null) return early;
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                var ck = inp.Ck;
                var d = ck.Detail;
                double metres = inp.Metres;
                var noHumidity = NoHumidity(d, inp.Rh);

                var heat = Thermal.Solve(d, inp.Lambda, inp.Temp, inp.Rs, metres);
                var surf = inp.Same ? heat : Thermal.Solve(d, inp.Lambda, inp.Temp, inp.Rsc, metres);
                var sum = Summary.Of(heat, surf, inp.Temp, inp.Rh);

                // The vapour, when every material has a permeability and every climate a
                // humidity (the temperatures of the heat, ISO 13788):
                Vapour vap = null;
                if (inp.NoVapour.Count == 0 && noHumidity.Count == 0)
                {
                    vap = Vapour.Solve(d, inp.Delta, inp.Rh, heat, inp.Temp, metres);
                    sum.Add(vap, metres);
                }
                var zb = ck.Zone.Bounds;
                Show.Field(doc, new Show.Result
                {
                    Heat = heat, Surface = surf, Summary = sum, Vapour = vap, Zone = ck.Zone, Imperial = inp.Imperial,
                    W = Math.Max(zb.Width, zb.Height) / 400,
                });

                var res = new ResultBuffer();
                ck.Write(res);
                res.Add(new TypedValue((int)LispDataType.ListBegin));
                Heat(res, sum);
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
                    List(res, "NoVapour", inp.NoVapour);
                    List(res, "NoHumidity", noHumidity);
                }
                Pair(res, "Isolated", heat.Isolated);
                Pair(res, "Iterations", heat.Iterations);
                res.Add(new TypedValue((int)LispDataType.ListEnd));
                return res;
            }
            catch (System.Exception ex)
            {
                return Text("Dyl:SimulationRun: " + ex.Message);
            }
        }

        // The pairs of the heat of a summary:
        static void Heat(ResultBuffer res, Summary sum)
        {
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
        }

        [LispFunction("Dyl:SimulationMonthly")]
        public ResultBuffer RunMonthly(ResultBuffer args)
        {
            try
            {
                var a = Args(args);
                if (a.Count < 7 || !(a[0] is ObjectId) || !(a[1] is double))
                    return Text("Dyl:SimulationMonthly: (zone size known mats climates months imperial metres) expected.");
                var months = Table(a[5]);
                var yearly = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var x in months)
                {
                    int k = 0;
                    for (int m = 0; m < 12; m++) if (!double.IsNaN(Num(x.Value, m))) k++;
                    if (k == 12) yearly.Add(x.Key);
                }
                var inp = Prepare(a, 6, out var early, yearly);
                if (inp == null) return early;
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                var ck = inp.Ck;
                var d = ck.Detail;
                double metres = inp.Metres;
                int nr = d.Regions.Count;

                // The climates of each month: those of the months typed, else the climate all year;
                // a climate of the zone with some months typed and not all of them is a problem:
                var temp = new double[12][];
                var rh = new double[12][];
                var partial = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                bool typed = false;
                for (int m = 0; m < 12; m++) { temp[m] = (double[])inp.Temp.Clone(); rh[m] = (double[])inp.Rh.Clone(); }
                for (int r = 0; r < nr; r++)
                {
                    var reg = d.Regions[r];
                    if (!reg.IsClimate || d.CellsOf[r] == 0 || !months.TryGetValue(reg.Climate, out var row)) continue;
                    int nt = 0, nh = 0;
                    for (int m = 0; m < 12; m++)
                    {
                        if (!double.IsNaN(Num(row, m))) nt++;
                        if (!double.IsNaN(Num(row, 12 + m))) nh++;
                    }
                    if (nt == 0 && nh == 0) continue;
                    if (nt < 12 || nh < 12) { partial.Add(reg.Climate); continue; }
                    typed = true;
                    for (int m = 0; m < 12; m++) { temp[m][r] = Num(row, m); rh[m][r] = Num(row, 12 + m); }
                }
                var noHumidity = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                for (int m = 0; m < 12; m++) noHumidity.UnionWith(NoHumidity(d, rh[m]));

                var res = new ResultBuffer();
                if (!typed || partial.Count > 0 || inp.NoVapour.Count > 0 || noHumidity.Count > 0)
                {
                    ck.Show(doc);
                    ck.Write(res);
                    res.Add(new TypedValue((int)LispDataType.ListBegin));
                    if (!typed && partial.Count == 0) Pair(res, "NoMonths", 1);
                    List(res, "PartMonths", partial);
                    List(res, "NoVapour", inp.NoVapour);
                    List(res, "NoHumidity", noHumidity);
                    res.Add(new TypedValue((int)LispDataType.ListEnd));
                    return res;
                }

                var mo = Monthly.Solve(d, inp.Lambda, inp.Delta, inp.Rs, temp, rh, metres);

                // Shown: the month that holds the most water (else the coldest one), its cells
                // that hold water in magenta:
                int shown = mo.MaxMonth;
                if (shown < 0)
                {
                    shown = 0;
                    for (int m = 1; m < 12; m++) if (Summary.Of(mo.Heat[m], mo.Heat[m], temp[m], rh[m]).Te < Summary.Of(mo.Heat[shown], mo.Heat[shown], temp[shown], rh[shown]).Te) shown = m;
                }
                var heat = mo.Heat[shown];
                var surf = inp.Same ? heat : Thermal.Solve(d, inp.Lambda, temp[shown], inp.Rsc, metres);
                var sum = Summary.Of(heat, surf, temp[shown], rh[shown]);
                var vap = mo.MaxVapour ?? Vapour.Solve(d, inp.Delta, rh[shown], heat, temp[shown], metres);
                sum.Add(vap, metres);
                var zb = ck.Zone.Bounds;
                Show.Field(doc, new Show.Result
                {
                    Heat = heat, Surface = surf, Summary = sum, Vapour = vap, Zone = ck.Zone, Imperial = inp.Imperial,
                    W = Math.Max(zb.Width, zb.Height) / 400,
                });

                ck.Write(res);
                res.Add(new TypedValue((int)LispDataType.ListBegin));
                Heat(res, sum);
                Pair(res, "Vapour", 1);
                Pair(res, "Monthly", 1);
                Pair(res, "Shown", shown + 1);
                Pair(res, "Start", mo.Start + 1);
                Pair(res, "MaxWater", mo.MaxWater);
                Pair(res, "MaxMonth", mo.MaxMonth + 1);
                Pair(res, "Remaining", mo.Remaining);
                Pair(res, "Dries", mo.Dries ? 1 : 0);
                if (mo.MaxMonth >= 0) List(res, "WaterMaterials", sum.CondensingMaterials);
                bool converged = true;
                // Each month: (month Ti Te condenses condensed dried water wet), January first:
                res.Add(new TypedValue((int)LispDataType.ListBegin));
                res.Add(new TypedValue((int)LispDataType.Text, "Months"));
                for (int m = 0; m < 12; m++)
                {
                    var x = mo.Months[m];
                    var s = Summary.Of(mo.Heat[m], mo.Heat[m], temp[m], rh[m]);
                    converged &= x.Converged;
                    res.Add(new TypedValue((int)LispDataType.ListBegin));
                    res.Add(new TypedValue((int)LispDataType.Int32, m + 1));
                    res.Add(new TypedValue((int)LispDataType.Double, double.IsNaN(s.Ti) ? 0 : s.Ti));
                    res.Add(new TypedValue((int)LispDataType.Double, double.IsNaN(s.Te) ? 0 : s.Te));
                    res.Add(new TypedValue((int)LispDataType.Int32, x.Condenses ? 1 : 0));
                    res.Add(new TypedValue((int)LispDataType.Double, x.Condensed));
                    res.Add(new TypedValue((int)LispDataType.Double, x.Dried));
                    res.Add(new TypedValue((int)LispDataType.Double, x.Water));
                    res.Add(new TypedValue((int)LispDataType.Int32, x.Wet));
                    res.Add(new TypedValue((int)LispDataType.ListEnd));
                }
                res.Add(new TypedValue((int)LispDataType.ListEnd));
                if (!converged) Pair(res, "VapourNotConverged", 1);
                Pair(res, "Isolated", heat.Isolated);
                res.Add(new TypedValue((int)LispDataType.ListEnd));
                return res;
            }
            catch (System.Exception ex)
            {
                return Text("Dyl:SimulationMonthly: " + ex.Message);
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

        [LispFunction("Dyl:SimulationKeep")]
        public ResultBuffer KeepRun(ResultBuffer args)
        {
            try
            {
                var a = Args(args);
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                var last = Show.Last(doc);
                if (last == null) return null;
                double Arg(int i) => a.Count > i && a[i] is double x ? x : 0;
                var made = Keep.Draw(doc, last, Arg(0), Arg(1), Arg(2));
                var res = new ResultBuffer();
                res.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var (key, ids) in new[] { ("Isotherm", made.Isotherms), ("Label", made.Labels), ("Dew", made.Dew), ("Condensation", made.Condensation) })
                {
                    if (ids.Count == 0) continue;
                    res.Add(new TypedValue((int)LispDataType.ListBegin));
                    res.Add(new TypedValue((int)LispDataType.Text, key));
                    foreach (var id in ids) res.Add(new TypedValue((int)LispDataType.ObjectId, id));
                    res.Add(new TypedValue((int)LispDataType.ListEnd));
                }
                res.Add(new TypedValue((int)LispDataType.ListEnd));
                return res;
            }
            catch (System.Exception ex)
            {
                return Text("Dyl:SimulationKeep: " + ex.Message);
            }
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
