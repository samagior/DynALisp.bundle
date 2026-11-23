// Monthly.cs - DynALisp.Simulation.Core: the water that a 2D detail holds month by month
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
// The monthly balance of ISO 13788 (clause 6.4), in two dimensions: the water that condenses
// inside a detail in the cold months, and whether it dries out in the warm ones.
//
//  - Each month is steady: the heat flow of its climates (Thermal.cs, the surface resistances
//    of ISO 6946), then the vapour of Glaser at its temperatures (Vapour.cs).
//  - The balance starts with the first month that condenses after a month that does not, each
//    cell dry (every month condensing: January). From there, twelve months in their order:
//    the water of each cell grows by what condenses in it over the month, and a cell that holds
//    water is held at the saturation pressure, so it dries by what it gives back. A cell whose
//    water would go below 0 is dry: its water 0, the month after it is free again.
//  - The detail passes when every cell is dry at the end of the twelve months (ISO 13788: the
//    water condensed has evaporated by the end of the year). Its water at the month it holds
//    the most is kept, with the heat and the vapour of that month, to be shown.
//
// The water is in g per metre of the depth of the detail (the rates of Vapour.cs are in
// ng/(s.m)), the months of 31, 28, 31, 30... days.

using System;

namespace DynALisp.Simulation.Core
{
    public class Monthly
    {
        public static readonly int[] Days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

        public class Month
        {
            public bool Condenses;      // with every cell dry: does vapour condense in it?
            public double Condensed;    // g/m condensed over the month (of the balance)
            public double Dried;        // g/m dried over the month
            public double Water;        // g/m held at its end
            public int Wet;             // the cells that hold water at its end
            public bool Converged = true;
        }

        public Detail Detail;
        public Month[] Months = new Month[12];   // January first
        public Thermal[] Heat = new Thermal[12]; // the heat flow of each month
        public int Start = -1;                   // the first month of the balance, -1: no month condenses
        public double MaxWater;                  // g/m, the most the detail holds at the end of a month
        public int MaxMonth = -1;                // that month
        public double[] MaxCells;                // by cell: g/m held at the end of that month
        public Thermal MaxHeat;                  // the heat flow of that month
        public Vapour MaxVapour;                 // its vapour, its cells held those that hold water
        public double Remaining;                 // g/m still held at the end of the twelve months
        public bool Dries = true;                // every cell dry at the end of the twelve months

        // The detail d, the conductivity (W/(m.K)) and the vapour permeability (ng/(Pa.s.m)) of each
        // region, the surface resistance of each climate (m2.K/W), the temperature (C) and the
        // relative humidity (%) of each climate for each month (temp[m][region], rh[m][region],
        // January first), and the metres of a drawing unit:
        public static Monthly Solve(Detail d, double[] lambda, double[] delta, double[] rs, double[][] temp, double[][] rh, double metres)
        {
            int n = d.Grid.Nx * d.Grid.Ny;
            var res = new Monthly { Detail = d };

            // The heat of each month (a month of the same temperatures as one before: the same):
            var heat = res.Heat;
            for (int m = 0; m < 12; m++)
            {
                for (int k = 0; k < m && heat[m] == null; k++)
                    if (Same(temp[k], temp[m])) heat[m] = heat[k];
                if (heat[m] == null) heat[m] = Thermal.Solve(d, lambda, temp[m], rs, metres);
            }

            // Each month with every cell dry: does it condense?
            for (int m = 0; m < 12; m++)
            {
                var v = Vapour.Solve(d, delta, rh[m], heat[m], temp[m], metres);
                res.Months[m] = new Month { Condenses = v.Total() > 0, Converged = v.Converged };
            }
            int any = 0;
            for (int m = 0; m < 12; m++) if (res.Months[m].Condenses) any++;
            if (any == 0) return res;
            res.Start = 0;
            if (any < 12)
                for (int m = 0; m < 12; m++)
                    if (res.Months[m].Condenses && !res.Months[(m + 11) % 12].Condenses) { res.Start = m; break; }

            // The twelve months of the balance:
            var water = new double[n];
            var wet = new bool[n];
            for (int k = 0; k < 12; k++)
            {
                int m = (res.Start + k) % 12;
                for (int c = 0; c < n; c++) wet[c] = water[c] > 0;
                var v = Vapour.Solve(d, delta, rh[m], heat[m], temp[m], metres, wet);
                var mo = res.Months[m];
                mo.Converged = v.Converged;
                double s = Days[m] * 86400.0 * 1e-9;
                double total = 0;
                for (int c = 0; c < n; c++)
                {
                    if (v.Condensing[c])
                    {
                        double add = v.Rate[c] * s;
                        if (add > 0) mo.Condensed += add;
                        else mo.Dried += Math.Min(-add, water[c]);
                        water[c] = Math.Max(0, water[c] + add);
                    }
                    if (water[c] > 0) { mo.Wet++; total += water[c]; }
                }
                mo.Water = total;
                if (total > res.MaxWater)
                {
                    res.MaxWater = total;
                    res.MaxMonth = m;
                    res.MaxCells = (double[])water.Clone();
                    res.MaxHeat = heat[m];
                    for (int c = 0; c < n; c++) v.Condensing[c] = water[c] > 0;
                    res.MaxVapour = v;
                }
            }
            res.Remaining = 0;
            foreach (var w in water) res.Remaining += w;
            res.Dries = res.Remaining == 0;
            return res;
        }

        static bool Same(double[] a, double[] b)
        {
            for (int i = 0; i < a.Length; i++)
                if (!(a[i] == b[i] || (double.IsNaN(a[i]) && double.IsNaN(b[i])))) return false;
            return true;
        }
    }
}
