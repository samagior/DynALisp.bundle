// VapourTests.cs - the tests of the diffusion of vapour and of the condensation (Glaser)
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

using System;
using System.Collections.Generic;
using System.Linq;
using DynALisp.Simulation.Core;
using Xunit;

namespace DynALisp.Simulation.Tests
{
    public class VapourTests
    {
        static Shape Rect(double x0, double y0, double x1, double y1) =>
            new Shape(new P(x0, y0), new P(x1, y0), new P(x1, y1), new P(x0, y1));

        static Region Mat(Shape s, string id) => new Region { Shape = s, Material = id };
        static Region Clim(Shape s, string id) => new Region { Shape = s, Climate = id };

        static double[] By(Detail d, Dictionary<string, double> v) =>
            d.Regions.Select(r => v.TryGetValue(r.IsClimate ? r.Climate : r.Material, out var x) ? x : double.NaN).ToArray();

        const double Ti = 20, Te = -10, RhI = 50, RhE = 80;

        // A wall of two layers, 100 mm each, between an interior at 20 C and 50 % (Rsi 0.13) and
        // an exterior at -10 C and 80 % (Rse 0.04), 200 mm high, in millimetres: the interior layer
        // of lambda li and delta di, the exterior one of lambda le and delta de:
        static (Detail, Thermal, double[] delta, double[] rh, double[] temp) Wall(double h, double li, double di, double le, double de)
        {
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 50, 200), "cl-In"),
                Mat(Rect(50, 0, 150, 200), "mt-A"),
                Mat(Rect(150, 0, 250, 200), "mt-B"),
                Clim(Rect(250, 0, 300, 200), "cl-Out"),
            };
            var d = Detail.Read(Rect(0, 0, 300, 200), regs, h);
            var lambda = By(d, new Dictionary<string, double> { ["mt-A"] = li, ["mt-B"] = le });
            var temp = By(d, new Dictionary<string, double> { ["cl-In"] = Ti, ["cl-Out"] = Te });
            var rs = By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 });
            var delta = By(d, new Dictionary<string, double> { ["mt-A"] = di, ["mt-B"] = de });
            var rh = By(d, new Dictionary<string, double> { ["cl-In"] = RhI, ["cl-Out"] = RhE });
            return (d, Thermal.Solve(d, lambda, temp, rs, 0.001), delta, rh, temp);
        }

        [Fact]
        public void AVapourBarrierOnTheWarmSideKeepsTheWallDry()
        {
            // Concrete inside, tight (2), insulation outside, open (150):
            var (d, th, delta, rh, temp) = Wall(5, 1.0, 2, 0.04, 150);
            var v = Vapour.Solve(d, delta, rh, th, temp, 0.001);
            Assert.Equal(0, v.Condensing.Count(x => x));
            Assert.True(v.Rounds <= 2);

            // The pressure is linear in the vapour resistance of the layers: through each cell
            // center, pi - (pi - pe) Z(x) / Ztotal:
            double pi = Psychro.Saturation(Ti) * RhI / 100, pe = Psychro.Saturation(Te) * RhE / 100;
            double za = 0.1 / 2, zb = 0.1 / 150, zt = za + zb;
            var g = d.Grid;
            for (int i = 0; i < g.Nx; i++)
            {
                int c = d.Cell(i, 10);
                if (double.IsNaN(v.Pv[c])) continue;
                double x = g.Cx(i) / 1000;
                double z = x < 0.15 ? (x - 0.05) / 2 : za + (x - 0.15) / 150;
                Assert.Equal(pi - (pi - pe) * z / zt, v.Pv[c], 4);
                Assert.True(v.Rh(c) < 1);
            }
            var s = Summary.Of(th, th, temp, rh);
            s.Add(v, 0.001);
            Assert.True(s.MaxRh < 100);
            Assert.Equal(0, s.Rate);
        }

        [Theory]
        [InlineData(5)]
        [InlineData(2)]
        public void ATightLayerOnTheColdSideCondensesAsGlaserSays(double h)
        {
            // Insulation inside, open (150), concrete outside, tight (2):
            var (d, th, delta, rh, temp) = Wall(h, 0.04, 150, 1.0, 2);
            var v = Vapour.Solve(d, delta, rh, th, temp, 0.001);
            Assert.True(v.Converged);
            var g = d.Grid;

            // A band of columns condenses, the whole height, where the insulation is coldest, up
            // to the interface of the layers: nowhere else is the pressure above saturation, and
            // each cell held takes vapour in:
            var cols = new SortedSet<int>();
            for (int c = 0; c < v.Condensing.Length; c++) if (v.Condensing[c]) cols.Add(c % g.Nx);
            int first = cols.Min, last = cols.Max;
            Assert.Equal(last - first + 1, cols.Count);
            Assert.Equal(g.Ny * cols.Count, v.Condensing.Count(x => x));
            double x0 = g.Cx(first) / 1000, x1 = g.Cx(last) / 1000;
            Assert.True(x0 < 0.15 && Math.Abs(x1 - 0.15) < h / 1000, "the band from " + x0 + " to " + x1);
            for (int c = 0; c < v.Pv.Length; c++)
            {
                if (double.IsNaN(v.Pv[c])) continue;
                if (v.Condensing[c]) Assert.True(v.Rate[c] > 0);
                else Assert.True(v.Pv[c] <= v.Psat[c] * (1 + 1e-6), "above saturation at " + c);
            }

            // What condenses is what comes from the interior to the first column held, at the
            // saturation pressure of its temperature, less what goes from the last one to the
            // exterior (Glaser, the flows between the columns held cancelled):
            double pi = Psychro.Saturation(Ti) * RhI / 100, pe = Psychro.Saturation(Te) * RhE / 100;
            double p0 = Psychro.Saturation(th.T[d.Cell(first, 0)]), p1 = Psychro.Saturation(th.T[d.Cell(last, 0)]);
            double Z(double x) => x < 0.15 ? (x - 0.05) / 150 : 0.1 / 150 + (x - 0.15) / 2;
            double z1 = Z(x0), z2 = 0.1 / 150 + 0.1 / 2 - Z(x1);
            double rate = ((pi - p0) / z1 - (p1 - pe) / z2) * 0.2;   // ng/(s.m) for 200 mm
            Assert.Equal(1, v.Total() / rate, 6);

            var s = Summary.Of(th, th, temp, rh);
            s.Add(v, 0.001);
            Assert.Equal(rate * 86400e-9, s.Rate, 6);
            Assert.Contains("mt-A", s.CondensingMaterials);
        }

        [Fact]
        public void ALargeDetailCondensesInAFewRounds()
        {
            // 90 000 cells: insulation between steel studs, a concrete footing, a tight exterior
            // layer, 2 mm cells:
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 100, 600), "cl-In"),
                Mat(Rect(100, 0, 450, 600), "mt-Insulation"),
                Mat(Rect(250, 100, 252, 600), "mt-Steel"),
                Mat(Rect(350, 100, 352, 600), "mt-Steel"),
                Mat(Rect(100, 0, 450, 100), "mt-Concrete"),
                Mat(Rect(450, 0, 500, 600), "mt-Concrete"),
                Clim(Rect(500, 0, 600, 600), "cl-Out"),
            };
            foreach (var (r, k) in regs.Select((r, k) => (r, k))) r.Order = k;
            var d = Detail.Read(Rect(0, 0, 600, 600), regs, 2);
            var lambda = By(d, new Dictionary<string, double> { ["mt-Insulation"] = 0.035, ["mt-Steel"] = 50, ["mt-Concrete"] = 1.8 });
            var delta = By(d, new Dictionary<string, double> { ["mt-Insulation"] = 150, ["mt-Steel"] = 1e-6, ["mt-Concrete"] = 2 });
            var temp = By(d, new Dictionary<string, double> { ["cl-In"] = 21, ["cl-Out"] = -25 });
            var rs = By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 });
            var rh = By(d, new Dictionary<string, double> { ["cl-In"] = 35, ["cl-Out"] = 80 });
            var th = Thermal.Solve(d, lambda, temp, rs, 0.001);
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var v = Vapour.Solve(d, delta, rh, th, temp, 0.001);
            Console.WriteLine("90 000 cells: " + v.Rounds + " rounds, " + v.Iterations + " iterations, " + v.Sweeps + " sweeps, " + sw.ElapsedMilliseconds + " ms, "
                              + v.Condensing.Count(x => x) + " cells condensing");
            Assert.True(v.Converged);
            Assert.True(v.Total() > 0);
        }

        [Fact]
        public void TheEquivalentPermeabilityOfAMembrane()
        {
            // 0.15 mm of 3 ng/(Pa.s.m2): 0.00045 ng/(Pa.s.m):
            Assert.Equal(0.00045, Vapour.Equivalent(Rect(0, 0, 0.15, 500), 3, 0.001), 12);
            Assert.True(double.IsNaN(Vapour.Equivalent(Rect(0, 0, 1, 1), 0, 0.001)));
        }
    }
}
