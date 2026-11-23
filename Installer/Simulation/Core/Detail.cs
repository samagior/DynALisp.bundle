// Detail.cs - DynALisp.Simulation.Core: a 2D detail read on its grid
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
// The detail of a simulation zone: each cell of the grid inside the zone gets what its center
// is in, the region of a material in front (the highest Order: the draw order of the drawing
// decides where two hatches overlap), else the climate zone in front, else nothing: a hole,
// which the calculation refuses (an empty space is almost always something left out; an air
// space is a region of a material, Void or an air layer). A cell outside the zone is left out.
// The holes are counted by groups of cells that touch (by a side), so one gap is one hole.

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public enum CellKind : byte { Outside = 0, Material = 1, Climate = 2, Hole = 3 }

    public class Detail
    {
        public Grid Grid;
        public CellKind[] Kind;       // by cell, i + j * Nx
        public int[] Owner;           // the index of the region of the cell in Regions, -1 for none
        public List<Region> Regions;  // the regions given, materials and climates
        public int[] CellsOf;         // the number of cells of each region in the zone
        public int Overlaps;          // the cells inside more than one region of a material
        public List<List<int>> Holes = new List<List<int>>(); // the cells of each hole

        public const long MaxCells = 1000000;

        public int Cell(int i, int j) => i + j * Grid.Nx;

        // The detail of the zone (a closed shape), its regions and the target size h of the cells.
        // More than MaxCells cells: an ArgumentException (a smaller zone, or a coarser grid):
        public static Detail Read(Shape zone, IList<Region> regions, double h)
        {
            var zb = zone.Bounds;
            if (zb.IsEmpty) throw new ArgumentException("The simulation zone has no area.");
            var inside = new List<Region>();
            foreach (var r in regions) if (r.Shape != null && r.Shape.Bounds.Touches(zb)) inside.Add(r);

            var shapes = new List<Shape> { zone };
            foreach (var r in inside) shapes.Add(r.Shape);
            var xs = Grid.Lines(Coords(shapes, true), zb.X0, zb.X1, h);
            var ys = Grid.Lines(Coords(shapes, false), zb.Y0, zb.Y1, h);
            long count = (long)(xs.Length - 1) * (ys.Length - 1);
            if (count > MaxCells)
                throw new ArgumentException("The grid would have " + count + " cells (" + MaxCells + " at most): pick a smaller zone or a coarser grid.");
            var g = new Grid(xs, ys);

            var d = new Detail
            {
                Grid = g,
                Kind = new CellKind[g.Nx * g.Ny],
                Owner = new int[g.Nx * g.Ny],
                Regions = new List<Region>(regions),
                CellsOf = new int[regions.Count],
            };
            for (int k = 0; k < d.Owner.Length; k++) d.Owner[k] = -1;
            var inZone = new bool[d.Kind.Length];
            g.Fill(zone, (i, j) => inZone[d.Cell(i, j)] = true);

            // The materials, then the climates, each cell to the one in front:
            var hits = new int[d.Kind.Length];
            for (int pass = 0; pass < 2; pass++)
                for (int r = 0; r < regions.Count; r++)
                {
                    var reg = regions[r];
                    if (reg.Shape == null || reg.IsClimate != (pass == 1) || !reg.Shape.Bounds.Touches(zb)) continue;
                    g.Fill(reg.Shape, (i, j) =>
                    {
                        int c = d.Cell(i, j);
                        if (!inZone[c]) return;
                        if (pass == 0)
                        {
                            if (++hits[c] == 2) d.Overlaps++;
                            if (d.Kind[c] != CellKind.Material || reg.Order > regions[d.Owner[c]].Order)
                            { d.Kind[c] = CellKind.Material; d.Owner[c] = r; }
                        }
                        else if (d.Kind[c] != CellKind.Material)
                        {
                            if (d.Kind[c] != CellKind.Climate || reg.Order > regions[d.Owner[c]].Order)
                            { d.Kind[c] = CellKind.Climate; d.Owner[c] = r; }
                        }
                    });
                }

            for (int c = 0; c < d.Kind.Length; c++)
            {
                if (!inZone[c]) { d.Kind[c] = CellKind.Outside; d.Owner[c] = -1; }
                else if (d.Owner[c] < 0) d.Kind[c] = CellKind.Hole;
                else d.CellsOf[d.Owner[c]]++;
            }
            d.FindHoles();
            return d;
        }

        static IEnumerable<double> Coords(List<Shape> shapes, bool x)
        {
            foreach (var s in shapes)
                foreach (var l in s.Loops)
                    foreach (var p in l) yield return x ? p.X : p.Y;
        }

        // The holes: the cells of kind Hole, by groups of cells that share a side:
        void FindHoles()
        {
            int nx = Grid.Nx, ny = Grid.Ny;
            var seen = new bool[Kind.Length];
            var stack = new Stack<int>();
            for (int c0 = 0; c0 < Kind.Length; c0++)
            {
                if (Kind[c0] != CellKind.Hole || seen[c0]) continue;
                var hole = new List<int>();
                seen[c0] = true;
                stack.Push(c0);
                while (stack.Count > 0)
                {
                    int c = stack.Pop();
                    hole.Add(c);
                    int i = c % nx, j = c / nx;
                    if (i > 0) Visit(c - 1, seen, stack);
                    if (i < nx - 1) Visit(c + 1, seen, stack);
                    if (j > 0) Visit(c - nx, seen, stack);
                    if (j < ny - 1) Visit(c + nx, seen, stack);
                }
                hole.Sort();
                Holes.Add(hole);
            }
        }

        void Visit(int c, bool[] seen, Stack<int> stack)
        {
            if (Kind[c] == CellKind.Hole && !seen[c]) { seen[c] = true; stack.Push(c); }
        }

        public int Count(CellKind k)
        {
            int n = 0;
            foreach (var x in Kind) if (x == k) n++;
            return n;
        }

        // The rectangles of the cells that pass the test, merged along each row (to draw them):
        public List<Box> Runs(Func<int, bool> test)
        {
            var res = new List<Box>();
            var g = Grid;
            for (int j = 0; j < g.Ny; j++)
            {
                int i = 0;
                while (i < g.Nx)
                {
                    if (!test(Cell(i, j))) { i++; continue; }
                    int i0 = i;
                    while (i < g.Nx && test(Cell(i, j))) i++;
                    res.Add(new Box(g.X[i0], g.Y[j], g.X[i], g.Y[j + 1]));
                }
            }
            return res;
        }
    }
}
