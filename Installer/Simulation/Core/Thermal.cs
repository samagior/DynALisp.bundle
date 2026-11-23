// Thermal.cs - DynALisp.Simulation.Core: the steady heat flow through a 2D detail
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
// The steady heat flow through a 2D detail (the method of THERM and ISO 10211): finite volumes
// on the grid of the detail, one temperature by cell of a material, at its center.
//
//  - Between two cells of a material, the conductance of their common face is its length over
//    the resistances of the two half cells in series (d/lambda each): the harmonic mean, which
//    keeps the resistance of layers in series exact.
//  - Between a cell of a material and a cell of a climate, the half cell in series with the
//    surface resistance Rs of the climate, to the temperature of the climate.
//  - Every other face (the border of the zone, a hole) lets no heat through (adiabatic): the
//    detail is cut far enough from what it shows for the cut to change nothing.
//
// The system (symmetric, positive definite) is solved by conjugate gradients, preconditioned
// by a modified incomplete Cholesky factorization. The cells of a material that touch no climate through other cells of a
// material (an island in a hole) have no temperature: they are counted (Isolated), never
// solved. Everything is computed in metres, for a depth of 1 m: the heat flows are in W/m.

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public class Thermal
    {
        // A face between a cell of a material and a cell of a climate (a surface of the detail):
        public struct Surface
        {
            public int Cell;        // the cell of the material
            public int Climate;     // the region of the climate
            public double Length;   // m
            public double Ts;       // the temperature of the surface, C
            public double Q;        // the heat flow through it, from the climate into the detail, W/m
            public P A, B;          // its ends, in drawing units
        }

        public Detail Detail;
        public double[] T;                // by cell: C, NaN where no material or isolated
        public List<Surface> Surfaces = new List<Surface>();
        public int Isolated;              // the cells of a material that touch no climate
        public int Iterations;
        public double Residual;           // the relative residual reached

        public const double Tolerance = 1e-10;

        // The detail d, the thermal conductivity of each region (W/(m.K), by index of
        // d.Regions; NaN or 0 for a climate or a material without one), the temperature (C)
        // and the surface resistance (m2.K/W) of each climate region (by the same index), and
        // the metres of a drawing unit:
        public static Thermal Solve(Detail d, double[] lambda, double[] temp, double[] rs, double metres)
        {
            var g = d.Grid;
            int nx = g.Nx, ny = g.Ny, n = nx * ny;
            var th = new Thermal { Detail = d, T = new double[n] };
            for (int c = 0; c < n; c++) th.T[c] = double.NaN;

            // The cells solved: of a material with a conductivity, joined to a climate:
            var mat = new bool[n];
            for (int c = 0; c < n; c++)
                mat[c] = d.Kind[c] == CellKind.Material && lambda[d.Owner[c]] > 0;
            var solved = Joined(d, mat);
            for (int c = 0; c < n; c++) if (mat[c] && !solved[c]) th.Isolated++;

            var diag = new double[n];
            var ge = new double[n];   // the conductance between c and c + 1
            var gn = new double[n];   // the conductance between c and c + nx
            var b = new double[n];

            for (int j = 0; j < ny; j++)
                for (int i = 0; i < nx; i++)
                {
                    int c = i + j * nx;
                    double w = (g.X[i + 1] - g.X[i]) * metres, h = (g.Y[j + 1] - g.Y[j]) * metres;
                    if (i + 1 < nx) Face(d, th, solved, lambda, temp, rs, c, c + 1, w / 2, (g.X[i + 2] - g.X[i + 1]) * metres / 2, h,
                                          new P(g.X[i + 1], g.Y[j]), new P(g.X[i + 1], g.Y[j + 1]), diag, ge, b);
                    if (j + 1 < ny) Face(d, th, solved, lambda, temp, rs, c, c + nx, h / 2, (g.Y[j + 2] - g.Y[j + 1]) * metres / 2, w,
                                          new P(g.X[i], g.Y[j + 1]), new P(g.X[i + 1], g.Y[j + 1]), diag, gn, b);
                }

            var x = new double[n];
            th.Iterations = Pcg(nx, n, solved, diag, ge, gn, b, x, out th.Residual);
            for (int c = 0; c < n; c++) if (solved[c]) th.T[c] = x[c];

            // The surfaces, now that the temperatures are known:
            for (int k = 0; k < th.Surfaces.Count; k++)
            {
                var s = th.Surfaces[k];
                double tc = temp[s.Climate], ta = th.T[s.Cell];
                s.Q *= tc - ta;                                  // the conductance, times the difference
                s.Ts = tc - s.Q / s.Length * rs[s.Climate];
                th.Surfaces[k] = s;
            }
            return th;
        }

        // The face between the cells a and b (b after a on one axis): da and db the half
        // widths of each (m), len its length (m), from p to q in drawing units. A face between
        // two cells solved goes in the matrix; one between a cell solved and a climate in its
        // diagonal and its right side, and is kept as a surface (its conductance in Q for now):
        static void Face(Detail d, Thermal th, bool[] solved, double[] lambda, double[] temp, double[] rs,
                         int a, int b, double da, double db, double len, P p, P q, double[] diag, double[] g, double[] rhs)
        {
            if (solved[a] && solved[b])
            {
                double k = len / (da / lambda[d.Owner[a]] + db / lambda[d.Owner[b]]);
                g[a] = k;
                diag[a] += k;
                diag[b] += k;
                return;
            }
            int m, cl;
            double dm;
            if (solved[a] && d.Kind[b] == CellKind.Climate) { m = a; cl = d.Owner[b]; dm = da; }
            else if (solved[b] && d.Kind[a] == CellKind.Climate) { m = b; cl = d.Owner[a]; dm = db; }
            else return;
            double r = rs[cl] > 0 ? rs[cl] : 0;
            double kc = len / (dm / lambda[d.Owner[m]] + r);
            diag[m] += kc;
            rhs[m] += kc * temp[cl];
            th.Surfaces.Add(new Surface { Cell = m, Climate = cl, Length = len, Q = kc, A = p, B = q });
        }

        // The cells of mat joined to a climate through cells of mat (sharing a side):
        static bool[] Joined(Detail d, bool[] mat)
        {
            int nx = d.Grid.Nx, ny = d.Grid.Ny, n = nx * ny;
            var res = new bool[n];
            var stack = new Stack<int>();
            for (int c = 0; c < n; c++)
            {
                if (!mat[c] || res[c]) continue;
                int i = c % nx, j = c / nx;
                bool touches = (i > 0 && d.Kind[c - 1] == CellKind.Climate) || (i < nx - 1 && d.Kind[c + 1] == CellKind.Climate)
                            || (j > 0 && d.Kind[c - nx] == CellKind.Climate) || (j < ny - 1 && d.Kind[c + nx] == CellKind.Climate);
                if (!touches) continue;
                res[c] = true;
                stack.Push(c);
                while (stack.Count > 0)
                {
                    int e = stack.Pop();
                    int ei = e % nx, ej = e / nx;
                    if (ei > 0) Visit(e - 1, mat, res, stack);
                    if (ei < nx - 1) Visit(e + 1, mat, res, stack);
                    if (ej > 0) Visit(e - nx, mat, res, stack);
                    if (ej < ny - 1) Visit(e + nx, mat, res, stack);
                }
            }
            return res;
        }

        static void Visit(int c, bool[] mat, bool[] res, Stack<int> stack)
        {
            if (mat[c] && !res[c]) { res[c] = true; stack.Push(c); }
        }

        // y = A x on the cells solved:
        static void Mul(int nx, int n, bool[] on, double[] diag, double[] ge, double[] gn, double[] x, double[] y)
        {
            for (int c = 0; c < n; c++)
            {
                if (!on[c]) { y[c] = 0; continue; }
                double v = diag[c] * x[c];
                if (ge[c] != 0) v -= ge[c] * x[c + 1];
                if (c >= 1 && ge[c - 1] != 0) v -= ge[c - 1] * x[c - 1];
                if (gn[c] != 0) v -= gn[c] * x[c + nx];
                if (c >= nx && gn[c - nx] != 0) v -= gn[c - nx] * x[c - nx];
                y[c] = v;
            }
        }

        // Conjugate gradients preconditioned by the modified incomplete Cholesky factorization
        // of the matrix (MIC(0), the cells in their order, its 5 diagonals kept; Bridson,
        // Fluid Simulation for Computer Graphics, 4.3.5): the iterations grow with the fourth
        // root of the cells, not their square root. Returns the iterations:
        const double Tau = 0.97, Sigma = 0.25;

        static int Pcg(int nx, int n, bool[] on, double[] diag, double[] ge, double[] gn, double[] b, double[] x, out double residual)
        {
            // The factorization: pc = 1 / sqrt(e) by cell.
            var pc = new double[n];
            for (int c = 0; c < n; c++)
            {
                if (!on[c]) continue;
                double e = diag[c];
                if (c >= 1 && on[c - 1])
                {
                    double a = ge[c - 1] * pc[c - 1];
                    e -= a * a + Tau * ge[c - 1] * gn[c - 1] * pc[c - 1] * pc[c - 1];
                }
                if (c >= nx && on[c - nx])
                {
                    double a = gn[c - nx] * pc[c - nx];
                    e -= a * a + Tau * gn[c - nx] * ge[c - nx] * pc[c - nx] * pc[c - nx];
                }
                if (e < Sigma * diag[c]) e = diag[c];
                pc[c] = 1 / Math.Sqrt(e);
            }

            var r = new double[n];
            var z = new double[n];
            var p = new double[n];
            var q = new double[n];
            double bn = 0;
            for (int c = 0; c < n; c++)
                if (on[c])
                {
                    // A start that is already close: the climates around, through each cell alone:
                    x[c] = diag[c] > 0 ? b[c] / diag[c] : 0;
                    bn += b[c] * b[c];
                }
            bn = Math.Sqrt(bn);
            residual = 0;
            if (bn == 0) { for (int c = 0; c < n; c++) x[c] = 0; return 0; }

            Mul(nx, n, on, diag, ge, gn, x, q);
            for (int c = 0; c < n; c++) r[c] = on[c] ? b[c] - q[c] : 0;
            Apply(nx, n, on, ge, gn, pc, r, z, q);
            double rz = 0;
            for (int c = 0; c < n; c++) if (on[c]) { p[c] = z[c]; rz += r[c] * z[c]; }

            const int max = 20000;
            int it = 0;
            for (; it < max; it++)
            {
                double rn = 0;
                for (int c = 0; c < n; c++) if (on[c]) rn += r[c] * r[c];
                residual = Math.Sqrt(rn) / bn;
                if (residual < Tolerance) break;

                Mul(nx, n, on, diag, ge, gn, p, q);
                double pq = 0;
                for (int c = 0; c < n; c++) if (on[c]) pq += p[c] * q[c];
                if (!(pq > 0)) break;
                double alpha = rz / pq;
                for (int c = 0; c < n; c++)
                {
                    if (!on[c]) continue;
                    x[c] += alpha * p[c];
                    r[c] -= alpha * q[c];
                }
                Apply(nx, n, on, ge, gn, pc, r, z, q);
                double rz2 = 0;
                for (int c = 0; c < n; c++) if (on[c]) rz2 += r[c] * z[c];
                double beta = rz2 / rz;
                rz = rz2;
                for (int c = 0; c < n; c++) if (on[c]) p[c] = z[c] + beta * p[c];
            }
            return it;
        }

        // z = M^-1 r, M the factorization (pc): forward, then backward (t: a work array):
        static void Apply(int nx, int n, bool[] on, double[] ge, double[] gn, double[] pc, double[] r, double[] z, double[] t)
        {
            for (int c = 0; c < n; c++)
            {
                if (!on[c]) { t[c] = 0; continue; }
                double v = r[c];
                if (c >= 1) v += ge[c - 1] * pc[c - 1] * t[c - 1];
                if (c >= nx) v += gn[c - nx] * pc[c - nx] * t[c - nx];
                t[c] = v * pc[c];
            }
            for (int c = n - 1; c >= 0; c--)
            {
                if (!on[c]) { z[c] = 0; continue; }
                double v = t[c];
                if (c + 1 < n) v += ge[c] * pc[c] * z[c + 1];
                if (c + nx < n) v += gn[c] * pc[c] * z[c + nx];
                z[c] = v * pc[c];
            }
        }

        // The heat flow from each climate region into the detail (W/m, by index of the regions;
        // their sum is 0 but for the tolerance of the solution):
        public double[] Flows()
        {
            var f = new double[Detail.Regions.Count];
            foreach (var s in Surfaces) f[s.Climate] += s.Q;
            return f;
        }

        // The equivalent conductivity of a region of a fixed thermal resistance rsi (an air
        // space): its thickness over its resistance, its thickness the smaller side of its
        // bounds (an air space is drawn as a band), in metres:
        public static double Equivalent(Shape s, double rsi, double metres)
        {
            var b = s.Bounds;
            if (b.IsEmpty || !(rsi > 0)) return double.NaN;
            return Math.Min(b.Width, b.Height) * metres / rsi;
        }
    }
}
