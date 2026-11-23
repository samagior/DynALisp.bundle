// ThermalTests.cs - the tests of the heat flow, the summary, the contours and the vapour
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
    public class ThermalTests
    {
        static Shape Rect(double x0, double y0, double x1, double y1) =>
            new Shape(new P(x0, y0), new P(x1, y0), new P(x1, y1), new P(x0, y1));

        static Region Mat(Shape s, string id, int order = 0) => new Region { Shape = s, Material = id, Order = order };
        static Region Clim(Shape s, string id, int order = 0) => new Region { Shape = s, Climate = id, Order = order };

        // The values of each region of d, by a value of each material and climate id:
        static double[] By(Detail d, Dictionary<string, double> v) =>
            d.Regions.Select(r => v.TryGetValue(r.IsClimate ? r.Climate : r.Material, out var x) ? x : double.NaN).ToArray();

        // A wall of two layers (100 mm of lambda 1.0, then 100 mm of lambda 0.04) between an
        // interior at 20 C (Rs 0.13, 0.25 for the condensation) and an exterior at -10 C (Rs 0.04),
        // 200 mm high, in millimetres:
        static Detail Wall(double h, out double[] lambda, out double[] temp, out double[] rs, out double[] rsc, out double[] rh)
        {
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 50, 200), "cl-In"),
                Mat(Rect(50, 0, 150, 200), "mt-Concrete"),
                Mat(Rect(150, 0, 250, 200), "mt-Insulation"),
                Clim(Rect(250, 0, 300, 200), "cl-Out"),
            };
            var d = Detail.Read(Rect(0, 0, 300, 200), regs, h);
            lambda = By(d, new Dictionary<string, double> { ["mt-Concrete"] = 1.0, ["mt-Insulation"] = 0.04 });
            temp = By(d, new Dictionary<string, double> { ["cl-In"] = 20, ["cl-Out"] = -10 });
            rs = By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 });
            rsc = By(d, new Dictionary<string, double> { ["cl-In"] = 0.25, ["cl-Out"] = 0.04 });
            rh = By(d, new Dictionary<string, double> { ["cl-In"] = 50 });
            return d;
        }

        const double RTotal = 0.13 + 0.1 / 1.0 + 0.1 / 0.04 + 0.04;

        [Theory]
        [InlineData(50)]
        [InlineData(10)]
        [InlineData(3)]
        public void AWallOfLayersGivesTheirResistanceInSeries(double h)
        {
            var d = Wall(h, out var lambda, out var temp, out var rs, out _, out _);
            var th = Thermal.Solve(d, lambda, temp, rs, 0.001);
            double q = 30 / RTotal * 0.2;                         // W/m through 200 mm
            var f = th.Flows();
            Assert.Equal(q, f[0], 6);
            Assert.Equal(-q, f[3], 6);
            Assert.Equal(0, th.Isolated);

            // The temperature is linear in each layer: at the interface, 20 - q (Rsi + 0.1 / 1.0):
            double ti = 20 - 30 / RTotal * (0.13 + 0.1);
            var g = d.Grid;
            for (int j = 0; j < g.Ny; j++)
                for (int i = 0; i < g.Nx; i++)
                {
                    double x = g.Cx(i) / 1000;
                    double expect = x < 0.05 || x > 0.25 ? double.NaN
                                  : x < 0.15 ? 20 - 30 / RTotal * (0.13 + (x - 0.05) / 1.0)
                                  : ti - 30 / RTotal * ((x - 0.15) / 0.04);
                    var t = th.T[i + j * g.Nx];
                    if (double.IsNaN(expect)) Assert.True(double.IsNaN(t));
                    else Assert.Equal(expect, t, 6);
                }
        }

        [Fact]
        public void TheSummaryOfAWall()
        {
            var d = Wall(10, out var lambda, out var temp, out var rs, out var rsc, out var rh);
            var heat = Thermal.Solve(d, lambda, temp, rs, 0.001);
            var surf = Thermal.Solve(d, lambda, temp, rsc, 0.001);
            var s = Summary.Of(heat, surf, temp, rh);
            Assert.Equal("cl-In", s.Interior);
            Assert.Equal("cl-Out", s.Exterior);
            Assert.Equal(0.2, s.Length, 9);
            Assert.Equal(RTotal, s.Rsi, 6);
            Assert.Equal(0.2 / RTotal, s.L2D, 6);

            // The coldest interior surface, with Rsi 0.25:
            double r2 = RTotal - 0.13 + 0.25;
            double tsi = 20 - 30 / r2 * 0.25;
            Assert.Equal(tsi, s.Tsi, 6);
            Assert.Equal((tsi + 10) / 30, s.FRsi, 6);
            Assert.Equal(50, s.TsiAt.X, 9);
            Assert.Equal("mt-Concrete", s.TsiMaterial);
            Assert.Equal(Psychro.DewPoint(20, 50), s.Dew, 9);
            Assert.Equal(0, s.BelowDew);
        }

        [Fact]
        public void AColdSurfaceIsBelowTheDewPoint()
        {
            var d = Wall(10, out var lambda, out var temp, out var rs, out var rsc, out var rh);
            for (int r = 0; r < d.Regions.Count; r++) if (d.Regions[r].Material == "mt-Insulation") lambda[r] = 10;
            for (int r = 0; r < d.Regions.Count; r++) if (d.Regions[r].Climate == "cl-In") rh[r] = 90;
            var surf = Thermal.Solve(d, lambda, temp, rsc, 0.001);
            var s = Summary.Of(surf, surf, temp, rh);
            Assert.True(s.Tsi < s.Dew);
            Assert.Equal(0.2, s.BelowDew, 9);
        }

        [Fact]
        public void TheHeatInIsTheHeatOutAroundAThermalBridge()
        {
            // An insulated wall with a steel stud through it:
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 20, 400), "cl-In"),
                Mat(Rect(20, 0, 160, 400), "mt-Insulation"),
                Mat(Rect(20, 190, 160, 210), "mt-Steel", 1),
                Clim(Rect(160, 0, 200, 400), "cl-Out"),
            };
            var d = Detail.Read(Rect(0, 0, 200, 400), regs, 2);
            var lambda = By(d, new Dictionary<string, double> { ["mt-Insulation"] = 0.035, ["mt-Steel"] = 50 });
            var temp = By(d, new Dictionary<string, double> { ["cl-In"] = 21, ["cl-Out"] = -25 });
            var rs = By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 });
            var th = Thermal.Solve(d, lambda, temp, rs, 0.001);
            var f = th.Flows();
            Assert.True(th.Residual < 1e-8, "residual " + th.Residual);
            Assert.Equal(0, f.Sum(), 6);

            // More heat than the insulation alone, less than the steel over the whole height:
            double alone = 46 / (0.13 + 0.14 / 0.035 + 0.04) * 0.4;
            Assert.True(f[0] > alone * 1.05, "flow " + f[0] + ", insulation alone " + alone);
            Assert.True(f[0] < 46 / (0.13 + 0.14 / 50 + 0.04) * 0.4);

            // The coldest interior surface is at the stud:
            var rh = By(d, new Dictionary<string, double> { ["cl-In"] = 35 });
            var s = Summary.Of(th, th, temp, rh);
            Assert.InRange(s.TsiAt.Y, 190, 210);
            Assert.Equal("mt-Steel", s.TsiMaterial);
        }

        [Fact]
        public void ACellOfAMaterialThatTouchesNoClimateIsNotSolved()
        {
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 10, 100), "cl-In"),
                Mat(Rect(10, 0, 50, 100), "mt-A"),
                Mat(Rect(60, 40, 80, 60), "mt-A"),
                Clim(Rect(90, 0, 100, 100), "cl-Out"),
            };
            var d = Detail.Read(Rect(0, 0, 100, 100), regs, 5);
            var lambda = By(d, new Dictionary<string, double> { ["mt-A"] = 1 });
            var temp = By(d, new Dictionary<string, double> { ["cl-In"] = 20, ["cl-Out"] = 0 });
            var rs = By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 });
            var th = Thermal.Solve(d, lambda, temp, rs, 0.001);
            Assert.Equal(16, th.Isolated);
            // Only the interior side touches the first block: it is all at 20 C (no flow).
            Assert.Equal(0, th.Flows()[0], 9);
            var c = d.Cell(d.Grid.FirstCenterX(30), 10);
            Assert.Equal(20, th.T[c], 6);
        }

        [Fact]
        public void TheEquivalentConductivityOfAnAirSpace()
        {
            Assert.Equal(0.019 / 0.18, Thermal.Equivalent(Rect(0, 0, 19, 2400), 0.18, 0.001), 12);
            Assert.True(double.IsNaN(Thermal.Equivalent(Rect(0, 0, 19, 2400), 0, 0.001)));
        }

        [Fact]
        public void TheVapourOfTheAir()
        {
            Assert.Equal(2337, Psychro.Saturation(20), 0);
            Assert.Equal(610.5, Psychro.Saturation(0), 9);
            Assert.Equal(20, Psychro.DewPoint(20, 100), 9);
            Assert.Equal(-5, Psychro.DewPoint(-5, 100), 9);
            Assert.InRange(Psychro.DewPoint(20, 50), 9.2, 9.4);
            Assert.True(double.IsNaN(Psychro.DewPoint(20, 0)));
        }

        [Fact]
        public void AContourOfALinearField()
        {
            var g = new Grid(new double[] { 0, 1, 2, 3, 4 }, new double[] { 0, 1, 2, 3 });
            var v = new double[g.Nx * g.Ny];
            for (int j = 0; j < g.Ny; j++) for (int i = 0; i < g.Nx; i++) v[i + j * g.Nx] = g.Cx(i);   // the value is x
            var segs = Contour.Segments(g, v, 2.25);
            Assert.Equal(2, segs.Count);                    // one per row of squares
            foreach (var (a, b) in segs) { Assert.Equal(2.25, a.X, 9); Assert.Equal(2.25, b.X, 9); }

            v[1] = double.NaN;                               // a square with no value is left out
            Assert.Single(Contour.Segments(g, v, 2.25));
        }

        [Fact]
        public void ASaddleIsSplitByItsCenter()
        {
            // The centers (0.5,0.5) a = 1, (1.5,0.5) b = 0, (0.5,1.5) d = 0, (1.5,1.5) c = 1 (the
            // cells by index: a, b, d, c); the mean 0.5 at the center, on the side of a and c:
            // they are joined, and b and d each cut off by a segment of their own.
            var g = new Grid(new double[] { 0, 1, 2 }, new double[] { 0, 1, 2 });
            var segs = Contour.Segments(g, new double[] { 1, 0, 0, 1 }, 0.5);
            Assert.Equal(2, segs.Count);
            Assert.Contains(segs, s => Near(s, new P(1, 0.5), new P(1.5, 1)));
            Assert.Contains(segs, s => Near(s, new P(1, 1.5), new P(0.5, 1)));
        }

        static bool Near((P, P) s, P a, P b)
        {
            bool Eq(P p, P q) => Math.Abs(p.X - q.X) < 1e-9 && Math.Abs(p.Y - q.Y) < 1e-9;
            return (Eq(s.Item1, a) && Eq(s.Item2, b)) || (Eq(s.Item1, b) && Eq(s.Item2, a));
        }

        [Fact]
        public void ALargeDetailIsSolved()
        {
            // 600 x 600 mm at 1 mm (360 000 cells): a wall of insulation crossed by two steel
            // studs and a concrete slab, the method's worst case (conductivities 0.035 to 50):
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 100, 600), "cl-In"),
                Mat(Rect(100, 0, 500, 600), "mt-Insulation"),
                Mat(Rect(250, 100, 252, 600), "mt-Steel", 1),
                Mat(Rect(350, 100, 352, 600), "mt-Steel", 1),
                Mat(Rect(100, 0, 500, 100), "mt-Concrete", 2),
                Clim(Rect(500, 0, 600, 600), "cl-Out"),
            };
            var d = Detail.Read(Rect(0, 0, 600, 600), regs, 1);
            var lambda = By(d, new Dictionary<string, double> { ["mt-Insulation"] = 0.035, ["mt-Steel"] = 50, ["mt-Concrete"] = 1.8 });
            var temp = By(d, new Dictionary<string, double> { ["cl-In"] = 21, ["cl-Out"] = -25 });
            var rs = By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 });
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var th = Thermal.Solve(d, lambda, temp, rs, 0.001);
            Console.WriteLine("360 000 cells: " + th.Iterations + " iterations, " + sw.ElapsedMilliseconds + " ms");
            Assert.True(th.Residual < Thermal.Tolerance, "residual " + th.Residual + " after " + th.Iterations);
            Assert.Equal(0, th.Flows().Sum(), 4);
        }

        [Fact]
        public void TheSegmentsOfAContourAreJoinedIntoLines()
        {
            // A ring of values: high in the middle of a 5 x 5 grid, its level a closed loop:
            var g = new Grid(new double[] { 0, 1, 2, 3, 4, 5 }, new double[] { 0, 1, 2, 3, 4, 5 });
            var v = new double[25];
            for (int j = 0; j < 5; j++)
                for (int i = 0; i < 5; i++)
                    v[i + j * 5] = 10 - Math.Abs(i - 2) - Math.Abs(j - 2);
            var segs = Contour.Segments(g, v, 8.5);
            var lines = Contour.Chains(segs, 1e-9);
            Assert.Single(lines);
            Assert.Equal(segs.Count + 1, lines[0].Count);
            Assert.Equal(lines[0][0].X, lines[0][lines[0].Count - 1].X, 9);
            Assert.Equal(lines[0][0].Y, lines[0][lines[0].Count - 1].Y, 9);

            // A straight field: one open line, its ends on the edge of the grid:
            for (int c = 0; c < 25; c++) v[c] = c % 5;
            lines = Contour.Chains(Contour.Segments(g, v, 1.5), 1e-9);
            Assert.Single(lines);
            Assert.Equal(5, lines[0].Count);
        }

        [Fact]
        public void TheCellAtAPoint()
        {
            var g = new Grid(new double[] { 0, 1, 3, 6 }, new double[] { 0, 2, 4 });
            Assert.Equal(0, g.CellAt(new P(0, 0)));
            Assert.Equal(1, g.CellAt(new P(2, 1)));
            Assert.Equal(2 + 3, g.CellAt(new P(6, 4)));
            Assert.Equal(-1, g.CellAt(new P(7, 1)));
        }
    }
}
