// Vapour.cs - DynALisp.Simulation.Core: the steady diffusion of water vapour through a 2D detail
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
// The steady diffusion of water vapour through a 2D detail, and where it condenses: the
// method of Glaser (ISO 13788, clause 6) on the grid of the heat flow, one vapour pressure by
// cell of a material, at its center.
//
//  - Between two cells, the vapour conductance of their common face is its length over the
//    vapour resistances of the two half cells in series (d/delta each), as the heat flow.
//  - Between a cell and a climate, the half cell alone, to the vapour pressure of the climate
//    (its relative humidity times the saturation pressure at its temperature): ISO 13788
//    neglects the vapour resistance of the surfaces.
//  - Every other face lets no vapour through.
//
// A cell whose vapour pressure would be above the saturation pressure at its temperature (the
// temperatures of the heat flow, with the surface resistances of ISO 6946, as ISO 13788 asks
// for the condensation inside a building element) condenses: its pressure is held at the
// saturation pressure and the system solved again, until no other cell goes above it and no
// cell held would give vapour back (less coming in than going out), the 2D form of the
// condensation planes of Glaser. What a cell held condenses is what comes into it less what
// goes out. Everything is computed in metres, for a depth of 1 m, the permeabilities in
// ng/(Pa.s.m): the flows are in ng/(s.m).

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public class Vapour
    {
        public Detail Detail;
        public double[] Pv;              // by cell: Pa, NaN where no material or not solved
        public double[] Psat;            // by cell: Pa, the saturation pressure at its temperature
        public double[] Rate;            // by cell: ng/(s.m) condensing in it, 0 elsewhere
        public bool[] Condensing;        // by cell
        public int Rounds;               // the systems solved, until the cells held did not change
        public int Iterations;           // of all the solves
        public int Sweeps;               // the sweeps of the cells around the cells held, between them
        public bool Converged = true;    // false when the cells held still changed after MaxRounds

        public const int MaxRounds = 200;
        public const double Loose = 1e-6;   // the residual of the solves while the cells held change

        // The relative humidity of the cell c (0 to 1), NaN where it has none:
        public double Rh(int c) => Pv[c] / Psat[c];

        // The total condensing, ng/(s.m) of depth:
        public double Total()
        {
            double t = 0;
            foreach (var r in Rate) t += r;
            return t;
        }

        // The detail d, the water vapour permeability of each region (ng/(Pa.s.m), by index of
        // d.Regions; NaN or 0 for a climate or a material without one), the relative humidity
        // (%) of each climate region, the heat flow th (its temperatures by cell, and of the
        // climates temp, C), and the metres of a drawing unit:
        public static Vapour Solve(Detail d, double[] delta, double[] rh, Thermal th, double[] temp, double metres)
        {
            var g = d.Grid;
            int nx = g.Nx, ny = g.Ny, n = nx * ny;
            var v = new Vapour
            {
                Detail = d,
                Pv = new double[n],
                Psat = new double[n],
                Rate = new double[n],
                Condensing = new bool[n],
            };

            var mat = new bool[n];
            for (int c = 0; c < n; c++)
            {
                v.Pv[c] = v.Psat[c] = double.NaN;
                mat[c] = d.Kind[c] == CellKind.Material && delta[d.Owner[c]] > 0 && !double.IsNaN(th.T[c]);
            }
            var solved = Thermal.Joined(d, mat);
            for (int c = 0; c < n; c++) if (solved[c]) v.Psat[c] = Psychro.Saturation(th.T[c]);

            // The vapour pressure of each climate (NaN without a humidity: no vapour through it):
            var pc = new double[d.Regions.Count];
            for (int r = 0; r < pc.Length; r++)
                pc[r] = d.Regions[r].IsClimate && rh[r] > 0 && !double.IsNaN(temp[r])
                      ? Psychro.Saturation(temp[r]) * rh[r] / 100 : double.NaN;

            // The conductances between the cells solved (ge: c and c + 1, gn: c and c + nx), and to
            // the climates of each cell (kc, and kc times their pressure in kp):
            var ge = new double[n];
            var gn = new double[n];
            var kc = new double[n];
            var kp = new double[n];
            for (int j = 0; j < ny; j++)
                for (int i = 0; i < nx; i++)
                {
                    int c = i + j * nx;
                    double w = (g.X[i + 1] - g.X[i]) * metres, h = (g.Y[j + 1] - g.Y[j]) * metres;
                    if (i + 1 < nx) Face(d, solved, delta, pc, c, c + 1, w / 2, (g.X[i + 2] - g.X[i + 1]) * metres / 2, h, ge, kc, kp);
                    if (j + 1 < ny) Face(d, solved, delta, pc, c, c + nx, h / 2, (g.Y[j + 2] - g.Y[j + 1]) * metres / 2, w, gn, kc, kp);
                }

            var on = new bool[n];
            var diag = new double[n];
            var b = new double[n];
            var ae = new double[n];
            var an = new double[n];
            var x = new double[n];
            var held = v.Condensing;
            bool tight = false;
            for (v.Rounds = 1; ; v.Rounds++)
            {
                // The system of the cells not held, a cell held a pressure known:
                for (int c = 0; c < n; c++)
                {
                    on[c] = solved[c] && !held[c];
                    diag[c] = b[c] = ae[c] = an[c] = 0;
                }
                for (int c = 0; c < n; c++)
                {
                    if (!on[c]) continue;
                    diag[c] = kc[c];
                    b[c] = kp[c];
                    Couple(c, c + 1, ge[c], on, held, v.Psat, diag, b, ae);
                    if (c >= 1) Couple(c, c - 1, ge[c - 1], on, held, v.Psat, diag, b, null);
                    Couple(c, c + nx, gn[c], on, held, v.Psat, diag, b, an);
                    if (c >= nx) Couple(c, c - nx, gn[c - nx], on, held, v.Psat, diag, b, null);
                }
                if (v.Rounds > 1) for (int c = 0; c < n; c++) x[c] = on[c] ? v.Pv[c] : 0;
                v.Iterations += Thermal.Pcg(nx, n, on, diag, ae, an, b, x, out _, v.Rounds > 1, tight ? Thermal.Tolerance : Loose);
                for (int c = 0; c < n; c++)
                    if (solved[c]) v.Pv[c] = on[c] ? x[c] : v.Psat[c];

                // The cells held that give vapour back are let go, those above saturation held:
                bool changed = false;
                for (int c = 0; c < n; c++)
                {
                    if (!solved[c]) continue;
                    if (held[c])
                    {
                        double net = Net(v, c, nx, n, ge, gn, kc, kp, solved);
                        if (net < 0) { held[c] = false; changed = true; }
                    }
                    else if (v.Pv[c] > v.Psat[c] * (1 + 1e-9)) { held[c] = true; changed = true; }
                }
                // The cells held found with a solve not as close: once more, as close as the heat:
                if (!changed) { if (tight) break; tight = true; continue; }
                if (v.Rounds >= MaxRounds) { v.Converged = false; break; }
                v.Sweeps += Relax(v, solved, held, nx, n, ge, gn, kc, kp);
            }

            for (int c = 0; c < n; c++)
                if (held[c]) v.Rate[c] = Math.Max(0, Net(v, c, nx, n, ge, gn, kc, kp, solved));
            return v;
        }

        // Between two solves, the cells held and the cells next to them relaxed alone (projected
        // Gauss-Seidel): each one at the pressure its neighbours give it, held at the saturation
        // pressure when that is above it. The edge of a band of cells held moves by one cell a
        // sweep, at the cost of the band alone, where a solve of the whole detail would move it
        // by one cell too. Returns the sweeps:
        public const int MaxSweeps = 2000;

        static int Relax(Vapour v, bool[] solved, bool[] held, int nx, int n, double[] ge, double[] gn, double[] kc, double[] kp)
        {
            var p = v.Pv;
            var near = new bool[n];
            var list = new List<int>();
            void Mark(int c) { if (c >= 0 && c < n && solved[c] && !near[c]) { near[c] = true; list.Add(c); } }
            void Around(int c) { Mark(c); if (c % nx > 0) Mark(c - 1); if (c % nx < nx - 1) Mark(c + 1); Mark(c - nx); Mark(c + nx); }
            for (int c = 0; c < n; c++) if (held[c]) Around(c);
            int sweep = 0;
            for (; sweep < MaxSweeps; sweep++)
            {
                bool changed = false;
                for (int k = 0; k < list.Count; k++)
                {
                    int c = list[k];
                    double s = kp[c], t = kc[c];
                    if (c % nx < nx - 1 && ge[c] != 0) { s += ge[c] * p[c + 1]; t += ge[c]; }
                    if (c % nx > 0 && ge[c - 1] != 0) { s += ge[c - 1] * p[c - 1]; t += ge[c - 1]; }
                    if (c + nx < n && gn[c] != 0) { s += gn[c] * p[c + nx]; t += gn[c]; }
                    if (c >= nx && gn[c - nx] != 0) { s += gn[c - nx] * p[c - nx]; t += gn[c - nx]; }
                    if (!(t > 0)) continue;
                    double gs = s / t;
                    bool h = gs >= v.Psat[c];
                    p[c] = h ? v.Psat[c] : gs;
                    if (h != held[c])
                    {
                        held[c] = h;
                        changed = true;
                        if (h) Around(c);
                    }
                }
                if (!changed) break;
            }
            return sweep;
        }

        // The face between the cells a and b (b after a on one axis), as Thermal.Face: between two
        // cells solved, its conductance in g[a]; between a cell solved and a climate with a
        // pressure, in kc and kp of the cell:
        static void Face(Detail d, bool[] solved, double[] delta, double[] pc, int a, int b, double da, double db, double len,
                         double[] g, double[] kc, double[] kp)
        {
            if (solved[a] && solved[b])
            {
                g[a] = len / (da / delta[d.Owner[a]] + db / delta[d.Owner[b]]);
                return;
            }
            int m, cl;
            double dm;
            if (solved[a] && d.Kind[b] == CellKind.Climate) { m = a; cl = d.Owner[b]; dm = da; }
            else if (solved[b] && d.Kind[a] == CellKind.Climate) { m = b; cl = d.Owner[a]; dm = db; }
            else return;
            if (double.IsNaN(pc[cl])) return;
            double k = len / (dm / delta[d.Owner[m]]);
            kc[m] += k;
            kp[m] += k * pc[cl];
        }

        // The face of conductance k between the cell c (not held) and its neighbour e: in the
        // matrix when e is not held either (its coupling in a[c] when e is after c), on the right
        // side when e is held (at its saturation pressure):
        static void Couple(int c, int e, double k, bool[] on, bool[] held, double[] psat, double[] diag, double[] b, double[] a)
        {
            if (k == 0) return;
            diag[c] += k;
            if (on[e]) { if (a != null) a[c] = k; }
            else if (held[e]) b[c] += k * psat[e];
        }

        // What comes into the cell c less what goes out (ng/(s.m)), its neighbours and climates:
        static double Net(Vapour v, int c, int nx, int n, double[] ge, double[] gn, double[] kc, double[] kp, bool[] solved)
        {
            double p = v.Pv[c], net = kp[c] - kc[c] * p;
            if (c + 1 < n && ge[c] != 0) net += ge[c] * (v.Pv[c + 1] - p);
            if (c >= 1 && ge[c - 1] != 0) net += ge[c - 1] * (v.Pv[c - 1] - p);
            if (c + nx < n && gn[c] != 0) net += gn[c] * (v.Pv[c + nx] - p);
            if (c >= nx && gn[c - nx] != 0) net += gn[c - nx] * (v.Pv[c - nx] - p);
            return net;
        }

        // The equivalent permeability of a region of a fixed permeance w (a membrane): its
        // permeance times its thickness, the smaller side of its bounds, in metres:
        public static double Equivalent(Shape s, double w, double metres)
        {
            var bb = s.Bounds;
            if (bb.IsEmpty || !(w > 0)) return double.NaN;
            return Math.Min(bb.Width, bb.Height) * metres * w;
        }
    }
}
