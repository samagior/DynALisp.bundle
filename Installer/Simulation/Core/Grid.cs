// Grid.cs - DynALisp.Simulation.Core: the grid of the calculation
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
// A rectangular grid, not uniform, as the one of WUFI 2D: its lines go through every vertex of
// the shapes (most details are orthogonal, so the border of two materials falls on a line of
// the grid), lines closer than a quarter of the target size merged, then each interval
// divided until it is no longer than the target size, and two neighbours kept within a
// factor 2 of each other (the larger one halved), so the cells grow slowly from a thin layer.

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public class Grid
    {
        public readonly double[] X, Y;

        public Grid(double[] x, double[] y) { X = x; Y = y; }

        public int Nx => X.Length - 1;
        public int Ny => Y.Length - 1;
        public long Count => (long)Nx * Ny;

        public double Cx(int i) => (X[i] + X[i + 1]) / 2;
        public double Cy(int j) => (Y[j] + Y[j + 1]) / 2;

        // The lines of one axis: the coordinates cs (the vertices) kept within [lo, hi], with lo
        // and hi themselves, h the target size (drawing units):
        public static double[] Lines(IEnumerable<double> cs, double lo, double hi, double h)
        {
            if (!(h > 0) || !(hi > lo)) throw new ArgumentException("The size of the grid and of the zone must be more than 0.");
            double tol = h / 4;
            var all = new List<double> { lo, hi };
            foreach (var c in cs) if (c > lo && c < hi) all.Add(c);
            all.Sort();

            // Merged: a line closer than tol to the one kept before it is dropped, hi always kept:
            var kept = new List<double> { lo };
            foreach (var c in all)
                if (c - kept[kept.Count - 1] >= tol) kept.Add(c);
            if (kept[kept.Count - 1] < hi)
            {
                if (kept.Count > 1 && hi - kept[kept.Count - 1] < tol) kept[kept.Count - 1] = hi;
                else kept.Add(hi);
            }

            // Divided to the target size:
            var lines = new List<double> { kept[0] };
            for (int k = 1; k < kept.Count; k++)
            {
                double a = kept[k - 1], b = kept[k];
                int n = (int)Math.Ceiling((b - a) / h - 1e-9);
                if (n < 1) n = 1;
                for (int s = 1; s < n; s++) lines.Add(a + (b - a) * s / n);
                lines.Add(b);
            }

            // Graded: no interval more than twice its neighbour:
            for (bool again = true; again;)
            {
                again = false;
                for (int k = 0; k + 2 < lines.Count; k++)
                {
                    double d1 = lines[k + 1] - lines[k], d2 = lines[k + 2] - lines[k + 1];
                    if (d1 > 2 * d2 * (1 + 1e-9)) { lines.Insert(k + 1, (lines[k] + lines[k + 1]) / 2); again = true; }
                    else if (d2 > 2 * d1 * (1 + 1e-9)) { lines.Insert(k + 2, (lines[k + 1] + lines[k + 2]) / 2); again = true; }
                }
            }
            return lines.ToArray();
        }

        // The first index i of the centers at or after x (binary search of the centers):
        public int FirstCenterX(double x)
        {
            int lo = 0, hi = Nx;
            while (lo < hi)
            {
                int m = (lo + hi) / 2;
                if (Cx(m) < x) lo = m + 1; else hi = m;
            }
            return lo;
        }

        // Calls f(i, j) for every cell whose center is inside the shape (a scan of each row):
        public void Fill(Shape s, Action<int, int> f)
        {
            var b = s.Bounds;
            if (b.IsEmpty) return;
            for (int j = 0; j < Ny; j++)
            {
                double y = Cy(j);
                if (y < b.Y0 || y > b.Y1) continue;
                var xs = s.Crossings(y);
                for (int k = 0; k + 1 < xs.Count; k += 2)
                {
                    for (int i = FirstCenterX(xs[k]); i < Nx && Cx(i) < xs[k + 1]; i++) f(i, j);
                }
            }
        }
    }
}
