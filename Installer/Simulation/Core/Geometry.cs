// Geometry.cs - DynALisp.Simulation.Core: the shapes of a 2D detail
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
// A shape is a set of closed loops of points (the arcs already divided into segments by the
// plugin), read even-odd: a point is inside when a ray from it crosses its loops an odd number
// of times, so an island of a hatch is a hole in it and an island in that hole is inside
// again (the Normal style of AutoCAD). The units are those of the drawing.

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public struct P
    {
        public double X, Y;
        public P(double x, double y) { X = x; Y = y; }
        public override string ToString() => X + "," + Y;
    }

    public struct Box
    {
        public double X0, Y0, X1, Y1;
        public Box(double x0, double y0, double x1, double y1) { X0 = x0; Y0 = y0; X1 = x1; Y1 = y1; }
        public static Box Empty => new Box(double.MaxValue, double.MaxValue, double.MinValue, double.MinValue);
        public bool IsEmpty => X0 > X1 || Y0 > Y1;
        public double Width => X1 - X0;
        public double Height => Y1 - Y0;
        public Box Add(P p) => new Box(Math.Min(X0, p.X), Math.Min(Y0, p.Y), Math.Max(X1, p.X), Math.Max(Y1, p.Y));
        public bool Touches(Box b) => !IsEmpty && !b.IsEmpty && b.X0 <= X1 && b.X1 >= X0 && b.Y0 <= Y1 && b.Y1 >= Y0;
    }

    public class Shape
    {
        public readonly List<List<P>> Loops = new List<List<P>>();

        public Shape() { }
        public Shape(params P[] loop) { AddLoop(loop); }

        // A loop of at least three points (its last point not repeated); a shorter one is left out:
        public void AddLoop(IEnumerable<P> pts)
        {
            var l = new List<P>(pts);
            if (l.Count > 1 && Same(l[0], l[l.Count - 1])) l.RemoveAt(l.Count - 1);
            if (l.Count >= 3) Loops.Add(l);
        }

        static bool Same(P a, P b) => Math.Abs(a.X - b.X) < 1e-12 && Math.Abs(a.Y - b.Y) < 1e-12;

        public Box Bounds
        {
            get
            {
                var b = Box.Empty;
                foreach (var l in Loops) foreach (var p in l) b = b.Add(p);
                return b;
            }
        }

        // The area, even-odd (the islands taken away), for the summaries and the tests:
        public double Area
        {
            get
            {
                double a = 0;
                foreach (var l in Loops)
                {
                    double s = 0;
                    for (int i = 0, j = l.Count - 1; i < l.Count; j = i++) s += (l[j].X + l[i].X) * (l[j].Y - l[i].Y);
                    a += Math.Abs(s) / 2;
                }
                return a;
            }
        }

        // The x where the loops cross the line y, sorted: the shape is inside between the 1st and
        // the 2nd, the 3rd and the 4th... (even-odd). A vertex on the line counts once (the
        // half-open test of each edge):
        public List<double> Crossings(double y)
        {
            var xs = new List<double>();
            foreach (var l in Loops)
                for (int i = 0, j = l.Count - 1; i < l.Count; j = i++)
                {
                    P a = l[j], b = l[i];
                    if ((a.Y > y) != (b.Y > y)) xs.Add(a.X + (y - a.Y) * (b.X - a.X) / (b.Y - a.Y));
                }
            xs.Sort();
            return xs;
        }

        public bool Contains(P p)
        {
            var xs = Crossings(p.Y);
            int n = 0;
            foreach (var x in xs) if (x < p.X) n++;
            return (n & 1) == 1;
        }
    }

    // A region of the detail: a hatch or a closed curve of the drawing, what it is made of
    // (Material: the id of a material, "" for a hatch without one) or the climate it is
    // (Climate: the id of a climate, for a climate zone), its place in the draw order (Order:
    // the higher one is in front, and wins where two regions overlap) and the object it comes
    // from (Source: an index of the plugin, to show it).
    public class Region
    {
        public Shape Shape;
        public string Material = "";
        public string Climate = "";
        public int Order;
        public int Source = -1;
        public bool IsClimate => Climate.Length > 0;
    }
}
