// Contour.cs - DynALisp.Simulation.Core: the lines of a value of a field
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
// The lines where a field of the detail (the temperature) has a given value (the dew point,
// an isotherm): marching squares on the centers of the cells, each square of four centers that
// all have a value cut by straight segments. A square with a cell without a value (a climate,
// a hole, outside) is left out, so a line stops half a cell from a surface.

using System;
using System.Collections.Generic;

namespace DynALisp.Simulation.Core
{
    public static class Contour
    {
        // The segments where the field v (by cell, NaN where none) is level:
        public static List<(P, P)> Segments(Grid g, double[] v, double level)
        {
            var res = new List<(P, P)>();
            int nx = g.Nx;
            var pts = new List<P>(4);
            for (int j = 0; j + 1 < g.Ny; j++)
                for (int i = 0; i + 1 < nx; i++)
                {
                    double a = v[i + j * nx], b = v[i + 1 + j * nx], c = v[i + 1 + (j + 1) * nx], d = v[i + (j + 1) * nx];
                    if (double.IsNaN(a) || double.IsNaN(b) || double.IsNaN(c) || double.IsNaN(d)) continue;
                    double x0 = g.Cx(i), x1 = g.Cx(i + 1), y0 = g.Cy(j), y1 = g.Cy(j + 1);
                    pts.Clear();
                    // The corners counter-clockwise: (x0,y0) a, (x1,y0) b, (x1,y1) c, (x0,y1) d.
                    Cut(pts, a, b, new P(x0, y0), new P(x1, y0), level);
                    Cut(pts, b, c, new P(x1, y0), new P(x1, y1), level);
                    Cut(pts, c, d, new P(x1, y1), new P(x0, y1), level);
                    Cut(pts, d, a, new P(x0, y1), new P(x0, y0), level);
                    if (pts.Count == 2) res.Add((pts[0], pts[1]));
                    else if (pts.Count == 4)
                    {
                        // A saddle: split by the value at the center.
                        double m = (a + b + c + d) / 4;
                        // The center on the side of a joins a and c, cutting off b and d; else b and d are joined:
                        if ((m >= level) == (a >= level)) { res.Add((pts[0], pts[1])); res.Add((pts[2], pts[3])); }
                        else { res.Add((pts[0], pts[3])); res.Add((pts[1], pts[2])); }
                    }
                }
            return res;
        }

        // The segments joined into lines where they share an end (two ends closer than eps are
        // the same point): each line its points in order, closed when its first point is its
        // last. A line of a contour ends only at a surface or the edge of the zone:
        public static List<List<P>> Chains(List<(P, P)> segs, double eps)
        {
            var ends = new Dictionary<(long, long), List<int>>();
            (long, long) Key(P p) => ((long)Math.Round(p.X / eps), (long)Math.Round(p.Y / eps));
            for (int k = 0; k < segs.Count; k++)
            {
                foreach (var p in new[] { segs[k].Item1, segs[k].Item2 })
                {
                    var key = Key(p);
                    if (!ends.TryGetValue(key, out var l)) ends[key] = l = new List<int>();
                    l.Add(k);
                }
            }
            var used = new bool[segs.Count];
            var res = new List<List<P>>();

            // From the point p, the segment not used yet at it, and its other end:
            bool Next(P p, out P q)
            {
                q = p;
                foreach (int k in ends[Key(p)])
                {
                    if (used[k]) continue;
                    used[k] = true;
                    var (a, b) = segs[k];
                    q = Key(a).Equals(Key(p)) ? b : a;
                    return true;
                }
                return false;
            }

            List<P> Walk(int k)
            {
                used[k] = true;
                var line = new List<P> { segs[k].Item1, segs[k].Item2 };
                while (Next(line[line.Count - 1], out var q)) line.Add(q);
                var back = new List<P>();
                var p = line[0];
                while (Next(p, out var q)) { back.Add(q); p = q; }
                back.Reverse();
                back.AddRange(line);
                return back;
            }

            // The open lines first (from an end that has one segment), then the loops:
            for (int k = 0; k < segs.Count; k++)
                if (!used[k] && (ends[Key(segs[k].Item1)].Count == 1 || ends[Key(segs[k].Item2)].Count == 1)) res.Add(Walk(k));
            for (int k = 0; k < segs.Count; k++)
                if (!used[k]) res.Add(Walk(k));
            return res;
        }

        // The point of the edge p-q where the value goes past level (an end at level counts as
        // above, so a value equal on two corners gives one point):
        static void Cut(List<P> pts, double va, double vb, P p, P q, double level)
        {
            if ((va >= level) == (vb >= level)) return;
            double t = (level - va) / (vb - va);
            pts.Add(new P(p.X + (q.X - p.X) * t, p.Y + (q.Y - p.Y) * t));
        }
    }
}
