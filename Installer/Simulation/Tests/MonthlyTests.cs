// MonthlyTests.cs - the tests of the monthly balance of the water (ISO 13788)
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
    public class MonthlyTests
    {
        static Shape Rect(double x0, double y0, double x1, double y1) =>
            new Shape(new P(x0, y0), new P(x1, y0), new P(x1, y1), new P(x0, y1));

        static Region Mat(Shape s, string id) => new Region { Shape = s, Material = id };
        static Region Clim(Shape s, string id) => new Region { Shape = s, Climate = id };

        static double[] By(Detail d, Dictionary<string, double> v) =>
            d.Regions.Select(r => v.TryGetValue(r.IsClimate ? r.Climate : r.Material, out var x) ? x : double.NaN).ToArray();

        // A wall of two layers, 100 mm each, 200 mm high, in millimetres, 5 mm cells: the interior
        // layer of lambda li and delta di, the exterior one of lambda le and delta de:
        static (Detail d, double[] lambda, double[] delta, double[] rs) Wall(double li, double di, double le, double de)
        {
            var regs = new List<Region>
            {
                Clim(Rect(0, 0, 50, 200), "cl-In"),
                Mat(Rect(50, 0, 150, 200), "mt-A"),
                Mat(Rect(150, 0, 250, 200), "mt-B"),
                Clim(Rect(250, 0, 300, 200), "cl-Out"),
            };
            var d = Detail.Read(Rect(0, 0, 300, 200), regs, 5);
            return (d,
                    By(d, new Dictionary<string, double> { ["mt-A"] = li, ["mt-B"] = le }),
                    By(d, new Dictionary<string, double> { ["mt-A"] = di, ["mt-B"] = de }),
                    By(d, new Dictionary<string, double> { ["cl-In"] = 0.13, ["cl-Out"] = 0.04 }));
        }

        // The climates of each month: the interior at 20 C and 50 %, the exterior of te[m] and rhe[m]:
        static (double[][] temp, double[][] rh) Year(Detail d, double[] te, double[] rhe)
        {
            var temp = new double[12][];
            var rh = new double[12][];
            for (int m = 0; m < 12; m++)
            {
                temp[m] = By(d, new Dictionary<string, double> { ["cl-In"] = 20, ["cl-Out"] = te[m] });
                rh[m] = By(d, new Dictionary<string, double> { ["cl-In"] = 50, ["cl-Out"] = rhe[m] });
            }
            return (temp, rh);
        }

        static double[] All(double x) => Enumerable.Repeat(x, 12).ToArray();

        [Fact]
        public void AWallWithAVapourBarrierOnTheWarmSideNeverCondenses()
        {
            var (d, lambda, delta, rs) = Wall(1.0, 2, 0.04, 150);
            var (temp, rh) = Year(d, All(-10), All(80));
            var mo = Monthly.Solve(d, lambda, delta, rs, temp, rh, 0.001);
            Assert.Equal(-1, mo.Start);
            Assert.True(mo.Dries);
            Assert.Equal(0, mo.MaxWater);
            Assert.All(mo.Months, m => Assert.False(m.Condenses));
        }

        [Fact]
        public void TheSameClimateEveryMonthAddsUpItsCondensation()
        {
            // Insulation inside, open (150), concrete outside, tight (2), -10 C all year: the
            // water held grows each month by the steady rate of Glaser times its days:
            var (d, lambda, delta, rs) = Wall(0.04, 150, 1.0, 2);
            var (temp, rh) = Year(d, All(-10), All(80));
            var mo = Monthly.Solve(d, lambda, delta, rs, temp, rh, 0.001);
            var th = Thermal.Solve(d, lambda, temp[0], rs, 0.001);
            double rate = Vapour.Solve(d, delta, rh[0], th, temp[0], 0.001).Total() * 1e-9;   // g/(s.m)
            Assert.True(rate > 0);
            Assert.Equal(0, mo.Start);
            Assert.False(mo.Dries);
            double sum = 0;
            for (int m = 0; m < 12; m++)
            {
                sum += rate * Monthly.Days[m] * 86400;
                Assert.Equal(1, mo.Months[m].Condensed / (rate * Monthly.Days[m] * 86400), 6);
                Assert.Equal(0, mo.Months[m].Dried, 9);
                Assert.Equal(1, mo.Months[m].Water / sum, 6);
            }
            Assert.Equal(11, mo.MaxMonth);
            Assert.Equal(1, mo.Remaining / sum, 6);
            Assert.Equal(1, mo.MaxCells.Sum() / sum, 6);
        }

        [Fact]
        public void AWetBandDriesToBothSidesAsGlaserSays()
        {
            // The wall at 20 C through, the columns from 100 to 150 mm wet: held at the saturation
            // pressure of 20 C, they dry to the interior (50 %) and to the exterior (70 %) by the
            // pressures over the vapour resistances on each side:
            var (d, lambda, delta, rs) = Wall(0.04, 150, 1.0, 2);
            var (temp, rh) = Year(d, All(20), All(70));
            var th = Thermal.Solve(d, lambda, temp[0], rs, 0.001);
            var g = d.Grid;
            var wet = new bool[g.Nx * g.Ny];
            int first = -1, last = -1;
            for (int i = 0; i < g.Nx; i++)
                if (g.Cx(i) > 100 && g.Cx(i) < 150)
                {
                    if (first < 0) first = i;
                    last = i;
                    for (int j = 0; j < g.Ny; j++) wet[d.Cell(i, j)] = true;
                }
            var v = Vapour.Solve(d, delta, rh[0], th, temp[0], 0.001, wet);
            double ps = Psychro.Saturation(20), pi = ps * 0.5, pe = ps * 0.7;
            double x0 = g.Cx(first) / 1000, x1 = g.Cx(last) / 1000;
            double z1 = (x0 - 0.05) / 150, z2 = (0.15 - x1) / 150 + 0.1 / 2;
            double rate = -((ps - pi) / z1 + (ps - pe) / z2) * 0.2;   // ng/(s.m) for 200 mm
            Assert.Equal(1, v.Total() / rate, 6);
            for (int c = 0; c < wet.Length; c++)
                if (wet[c]) Assert.Equal(ps, v.Pv[c], 6);
                else if (!double.IsNaN(v.Pv[c])) Assert.True(v.Pv[c] < ps);
        }

        [Fact]
        public void TheWaterOfTheWinterDriesInTheSummer()
        {
            // -10 C from November to March, 20 C the rest of the year:
            var (d, lambda, delta, rs) = Wall(0.04, 150, 1.0, 2);
            var te = new double[] { -10, -10, -10, 20, 20, 20, 20, 20, 20, 20, -10, -10 };
            var rhe = new double[] { 80, 80, 80, 70, 70, 70, 70, 70, 70, 70, 80, 80 };
            var (temp, rh) = Year(d, te, rhe);
            var mo = Monthly.Solve(d, lambda, delta, rs, temp, rh, 0.001);

            // The balance starts in November, the water grows until March, then dries:
            Assert.Equal(10, mo.Start);
            Assert.Equal(2, mo.MaxMonth);
            double before = 0;
            foreach (int m in new[] { 10, 11, 0, 1, 2 })
            {
                Assert.True(mo.Months[m].Condenses);
                Assert.True(mo.Months[m].Water > before);
                before = mo.Months[m].Water;
            }
            Assert.False(mo.Months[3].Condenses);
            Assert.True(mo.Months[3].Dried > 0);
            Assert.True(mo.Months[3].Water < mo.Months[2].Water);
            Assert.True(mo.Dries);
            Assert.Equal(0, mo.Remaining);

            // Everything condensed has dried:
            double c = mo.Months.Sum(m => m.Condensed), dr = mo.Months.Sum(m => m.Dried);
            Assert.Equal(1, dr / c, 9);
            Assert.Equal(mo.MaxWater, mo.MaxCells.Sum(), 9);
            Assert.Equal(mo.MaxCells.Count(w => w > 0), mo.MaxVapour.Condensing.Count(x => x));
        }
    }
}
