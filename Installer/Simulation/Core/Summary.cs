// Summary.cs - DynALisp.Simulation.Core: what a simulation tells, and the vapour of the air
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
// What a steady simulation of a detail tells, between its warm side (the interior: the climate
// of the highest temperature) and its cold side (the exterior: the lowest one):
//
//  - the heat flow through the detail, per metre of its depth, and its thermal coupling
//    coefficient L2D = Q / (Ti - Te) (ISO 10211), from the solution with the surface
//    resistances of the heat (Rs: Rsi 0.13, Rse 0.04);
//  - its effective thermal resistance: the length of its interior surface times (Ti - Te) / Q;
//  - the coldest interior surface, its temperature factor fRsi = (Tsi - Te) / (Ti - Te) and the
//    dew point of the interior air (ISO 13788), from the solution with the surface resistance
//    of the condensation (Rsi 0.25): an interior surface colder than the dew point gets
//    condensation.

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public class Summary
    {
        public string Interior = "", Exterior = "";   // the ids of the climates
        public double Ti = double.NaN, Te = double.NaN;
        public double Q = double.NaN;                  // W/m, from the interior into the detail
        public double Length;                          // m, of the interior surface
        public double L2D = double.NaN;                // W/(m.K)
        public double Rsi = double.NaN;                // m2.K/W, effective
        public double Tsi = double.NaN;                // C, the coldest interior surface
        public P TsiAt;                                // where, in drawing units
        public string TsiMaterial = "";
        public double FRsi = double.NaN;
        public double Dew = double.NaN;                // C, of the interior air (NaN: no humidity)
        public double BelowDew;                        // m of interior surface colder than Dew

        // The vapour (see Vapour), when it was computed:
        public bool Vapour;
        public double MaxRh = double.NaN;              // %, the highest relative humidity of a cell not condensing
        public P MaxRhAt;
        public int Condensing;                         // the cells where vapour condenses
        public double CondensingArea;                  // m2 (of the section)
        public double Rate;                            // g/(m.day), the vapour condensing per metre of depth
        public List<string> CondensingMaterials = new List<string>();
        public bool VapourConverged = true;

        // heat: the solution with the surface resistances of the heat; surface: the one with
        // those of the condensation (the same one when they are the same); temp and rh: the
        // temperature (C) and the relative humidity (%, NaN when not known) of each climate
        // region, by index of the regions:
        public static Summary Of(Thermal heat, Thermal surface, double[] temp, double[] rh)
        {
            var s = new Summary();
            var regions = heat.Detail.Regions;
            int wi = -1, ci = -1;
            foreach (var f in heat.Surfaces)
            {
                if (wi < 0 || temp[f.Climate] > temp[wi]) wi = f.Climate;
                if (ci < 0 || temp[f.Climate] < temp[ci]) ci = f.Climate;
            }
            if (wi < 0) return s;
            s.Interior = regions[wi].Climate;
            s.Exterior = regions[ci].Climate;
            s.Ti = temp[wi];
            s.Te = temp[ci];
            if (rh[wi] > 0) s.Dew = Psychro.DewPoint(s.Ti, rh[wi]);

            double q = 0;
            foreach (var f in heat.Surfaces)
                if (Same(regions[f.Climate].Climate, s.Interior)) { q += f.Q; s.Length += f.Length; }
            if (s.Ti > s.Te)
            {
                s.Q = q;
                s.L2D = q / (s.Ti - s.Te);
                if (q > 0) s.Rsi = s.Length * (s.Ti - s.Te) / q;
            }

            foreach (var f in surface.Surfaces)
            {
                if (!Same(regions[f.Climate].Climate, s.Interior)) continue;
                if (double.IsNaN(s.Tsi) || f.Ts < s.Tsi)
                {
                    s.Tsi = f.Ts;
                    s.TsiAt = new P((f.A.X + f.B.X) / 2, (f.A.Y + f.B.Y) / 2);
                    s.TsiMaterial = regions[heat.Detail.Owner[f.Cell]].Material;
                }
                if (f.Ts < s.Dew) s.BelowDew += f.Length;
            }
            if (s.Ti > s.Te && !double.IsNaN(s.Tsi)) s.FRsi = (s.Tsi - s.Te) / (s.Ti - s.Te);
            return s;
        }

        // What the vapour v of the detail tells (metres: of a drawing unit):
        public void Add(Vapour v, double metres)
        {
            Vapour = true;
            VapourConverged = v.Converged;
            var d = v.Detail;
            var g = d.Grid;
            for (int j = 0; j < g.Ny; j++)
                for (int i = 0; i < g.Nx; i++)
                {
                    int c = d.Cell(i, j);
                    if (double.IsNaN(v.Pv[c])) continue;
                    if (v.Condensing[c])
                    {
                        Condensing++;
                        CondensingArea += (g.X[i + 1] - g.X[i]) * (g.Y[j + 1] - g.Y[j]) * metres * metres;
                        var m = d.Regions[d.Owner[c]].Material;
                        if (!CondensingMaterials.Exists(x => Same(x, m))) CondensingMaterials.Add(m);
                        continue;
                    }
                    double rh = v.Rh(c) * 100;
                    if (double.IsNaN(MaxRh) || rh > MaxRh) { MaxRh = rh; MaxRhAt = new P(g.Cx(i), g.Cy(j)); }
                }
            // ng/(s.m) to g/(m.day):
            Rate = v.Total() * 86400 * 1e-9;
        }

        static bool Same(string a, string b) => string.Equals(a, b, StringComparison.OrdinalIgnoreCase);
    }

    // The water vapour of the air (ISO 13788, Annex E): the saturation pressure over water at 0 C
    // and above, over ice below.
    public static class Psychro
    {
        public static double Saturation(double t) =>
            t >= 0 ? 610.5 * Math.Exp(17.269 * t / (237.3 + t)) : 610.5 * Math.Exp(21.875 * t / (265.5 + t));

        // The temperature at which the air of temperature t (C) and relative humidity rh (%)
        // gets saturated:
        public static double DewPoint(double t, double rh)
        {
            double p = Saturation(t) * rh / 100;
            if (!(p > 0)) return double.NaN;
            double l = Math.Log(p / 610.5);
            return p >= 610.5 ? 237.3 * l / (17.269 - l) : 265.5 * l / (21.875 - l);
        }
    }
}
