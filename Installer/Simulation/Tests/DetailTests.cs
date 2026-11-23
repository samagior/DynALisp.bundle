// DetailTests.cs - the tests of the grid and of the reading of a detail
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
    public class DetailTests
    {
        static Shape Rect(double x0, double y0, double x1, double y1) =>
            new Shape(new P(x0, y0), new P(x1, y0), new P(x1, y1), new P(x0, y1));

        static Region Mat(Shape s, string id, int order = 0) => new Region { Shape = s, Material = id, Order = order };
        static Region Clim(Shape s, string id, int order = 0) => new Region { Shape = s, Climate = id, Order = order };

        [Fact]
        public void LinesGoThroughTheVerticesAndKeepTheTargetSize()
        {
            var l = Grid.Lines(new[] { 12.7, 100.0 }, 0, 200, 10);
            Assert.Contains(12.7, l);
            Assert.Contains(100.0, l);
            Assert.Equal(0, l.First());
            Assert.Equal(200, l.Last());
            for (int k = 1; k < l.Length; k++) Assert.True(l[k] - l[k - 1] <= 10 + 1e-9);
        }

        [Fact]
        public void LinesAreGradedByAFactorTwoAtMost()
        {
            // A thin layer of 1 beside a thick one of 99, target 50:
            var l = Grid.Lines(new[] { 1.0 }, 0, 100, 50);
            for (int k = 2; k < l.Length; k++)
            {
                double a = l[k - 1] - l[k - 2], b = l[k] - l[k - 1];
                Assert.True(Math.Max(a, b) <= 2 * Math.Min(a, b) + 1e-9, "intervals " + a + " and " + b);
            }
        }

        [Fact]
        public void LinesCloserThanAQuarterOfTheSizeAreMerged()
        {
            var l = Grid.Lines(new[] { 50.0, 50.5 }, 0, 100, 10);
            Assert.Single(l, x => x > 49 && x < 51);
        }

        [Fact]
        public void TwoLayersSideBySideLeaveNoHole()
        {
            var zone = Rect(0, 0, 100, 50);
            var regs = new List<Region> { Mat(Rect(0, 0, 40, 50), "mt-A"), Mat(Rect(40, 0, 100, 50), "mt-B") };
            var d = Detail.Read(zone, regs, 5);
            Assert.Empty(d.Holes);
            Assert.Equal(0, d.Count(CellKind.Outside));
            Assert.Equal(d.Kind.Length, d.CellsOf.Sum());
            Assert.True(d.CellsOf[0] > 0 && d.CellsOf[1] > 0);
            Assert.Equal(0, d.Overlaps);
            // The border of the two layers is a line of the grid:
            Assert.Contains(40.0, d.Grid.X);
        }

        [Fact]
        public void AGapBetweenTwoLayersIsOneHole()
        {
            var zone = Rect(0, 0, 100, 50);
            var regs = new List<Region> { Mat(Rect(0, 0, 40, 50), "mt-A"), Mat(Rect(45, 0, 100, 50), "mt-B") };
            var d = Detail.Read(zone, regs, 1);
            Assert.Single(d.Holes);
            Assert.All(d.Holes[0], c => Assert.InRange(d.Grid.Cx(c % d.Grid.Nx), 40, 45));
        }

        [Fact]
        public void TheClimateZonesAreNotHoles()
        {
            var zone = Rect(0, 0, 100, 50);
            var regs = new List<Region>
            {
                Mat(Rect(30, 0, 70, 50), "mt-A"),
                Clim(Rect(-10, -10, 30, 60), "cl-Interior"),
                Clim(Rect(70, -10, 110, 60), "cl-Exterior"),
            };
            var d = Detail.Read(zone, regs, 5);
            Assert.Empty(d.Holes);
            Assert.True(d.Count(CellKind.Climate) > 0);
        }

        [Fact]
        public void TheRegionInFrontWinsWhereTwoOverlap()
        {
            var zone = Rect(0, 0, 100, 100);
            var regs = new List<Region> { Mat(Rect(0, 0, 100, 100), "mt-Back", 1), Mat(Rect(20, 20, 40, 40), "mt-Front", 2) };
            var d = Detail.Read(zone, regs, 5);
            int c = d.Cell(d.Grid.FirstCenterX(30), Array.FindIndex(d.Grid.Y, y => y >= 30));
            Assert.Equal(1, d.Owner[c]);
            Assert.True(d.Overlaps > 0);
            // A material always wins over a climate, whatever its order:
            var regs2 = new List<Region> { Mat(Rect(0, 0, 100, 100), "mt-A", 0), Clim(Rect(0, 0, 100, 100), "cl-Interior", 5) };
            var d2 = Detail.Read(zone, regs2, 10);
            Assert.Equal(0, d2.Count(CellKind.Climate));
        }

        [Fact]
        public void AnIslandOfAHatchIsAHoleInIt()
        {
            var zone = Rect(0, 0, 100, 100);
            var s = Rect(0, 0, 100, 100);
            s.AddLoop(new[] { new P(40, 40), new P(60, 40), new P(60, 60), new P(40, 60) });
            var d = Detail.Read(zone, new List<Region> { Mat(s, "mt-A") }, 5);
            Assert.Single(d.Holes);
            Assert.Equal(16, d.Holes[0].Count);
        }

        [Fact]
        public void TheCellsOutsideAZoneThatIsNotARectangleAreLeftOut()
        {
            // An L-shaped zone, filled by one material:
            var zone = new Shape(new P(0, 0), new P(100, 0), new P(100, 50), new P(50, 50), new P(50, 100), new P(0, 100));
            var d = Detail.Read(zone, new List<Region> { Mat(Rect(-1, -1, 101, 101), "mt-A") }, 10);
            Assert.Empty(d.Holes);
            Assert.Equal(25, d.Count(CellKind.Outside));
            Assert.Equal(75, d.Count(CellKind.Material));
        }

        [Fact]
        public void ATooFineGridIsRefused()
        {
            Assert.Throws<ArgumentException>(() => Detail.Read(Rect(0, 0, 10000, 10000), new List<Region>(), 1));
        }

        [Fact]
        public void TheRunsCoverTheHoleCells()
        {
            var zone = Rect(0, 0, 100, 50);
            var d = Detail.Read(zone, new List<Region> { Mat(Rect(0, 0, 40, 50), "mt-A") }, 5);
            var runs = d.Runs(c => d.Kind[c] == CellKind.Hole);
            Assert.Equal(60 * 50, runs.Sum(b => b.Width * b.Height), 6);
        }

        [Fact]
        public void TheAreaOfAShapeTakesItsIslandsAway()
        {
            var s = Rect(0, 0, 10, 10);
            Assert.Equal(100, s.Area, 9);
            Assert.True(s.Contains(new P(5, 5)));
            Assert.False(s.Contains(new P(15, 5)));
        }
    }
}
