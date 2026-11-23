// Show.cs - DynALisp.Simulation: what the simulation shows over the drawing
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
// Transient graphics (TransientManager, AutoCAD 2015 and later): drawn over the drawing, never
// added to it, so nothing is left to erase, nothing is plotted and nothing is undone. Kept by
// drawing until they are cleared (Dyl:SimulationClear, a new read of a zone, or the drawing
// closed). The grid in grey, the holes filled in red, the objects with a problem outlined in
// red and the zone outlined in orange; after a run, the temperatures (blue at the exterior,
// white between, red at the interior) or the relative humidity (white to dark blue), the line
// of the dew point, the interior surfaces colder than it, the coldest one and the cells where
// vapour condenses in magenta, and a legend beside the zone. The result of the last run of
// each drawing is kept for the probe and the views (Last).

using System;
using System.Collections.Generic;
using System.Globalization;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Colors;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.GraphicsInterface;
using DynALisp.Simulation.Core;
using Shape = DynALisp.Simulation.Core.Shape;
using Region = DynALisp.Simulation.Core.Region;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;
using DbPolyline = Autodesk.AutoCAD.DatabaseServices.Polyline;

namespace DynALisp.Simulation
{
    static class Show
    {
        static readonly Dictionary<Document, List<Entity>> _shown = new Dictionary<Document, List<Entity>>();
        static readonly Dictionary<Document, Result> _last = new Dictionary<Document, Result>();

        // A run shown: its two heat flows (Heat with the surface resistances of the heat, Surface
        // with those of the condensation, shown), its summary, its vapour (null when it was not
        // computed), its zone, its units, the width of its lines, and the field shown:
        public class Result
        {
            public Thermal Heat, Surface;
            public Summary Summary;
            public Vapour Vapour;
            public Shape Zone;
            public bool Imperial;
            public double W;
            public bool Humidity;
        }
        static bool _hooked;

        public const int MaxLines = 1500;   // grid lines drawn at most on each axis
        public const int MaxRuns = 20000;   // filled rectangles drawn at most

        static readonly Color Grey = Color.FromColorIndex(ColorMethod.ByAci, 253);
        static readonly Color Red = Color.FromColorIndex(ColorMethod.ByAci, 1);
        static readonly Color Orange = Color.FromColorIndex(ColorMethod.ByAci, 30);

        public static Result Last(Document doc) => doc != null && _last.TryGetValue(doc, out var t) ? t : null;

        public static void Clear(Document doc)
        {
            if (doc != null) _last.Remove(doc);
            if (doc == null || !_shown.TryGetValue(doc, out var list)) return;
            var tm = TransientManager.CurrentTransientManager;
            foreach (var e in list)
            {
                try { tm.EraseTransient(e, new IntegerCollection()); } catch { }
                e.Dispose();
            }
            _shown.Remove(doc);
        }

        static void Add(Document doc, Entity e)
        {
            if (!_hooked)
            {
                AcApp.DocumentManager.DocumentToBeDestroyed += (s, a) => Clear(a.Document);
                _hooked = true;
            }
            if (!_shown.TryGetValue(doc, out var list)) _shown[doc] = list = new List<Entity>();
            list.Add(e);
            TransientManager.CurrentTransientManager.AddTransient(e, TransientDrawingMode.DirectTopmost, 128, new IntegerCollection());
        }

        static void Line(Document doc, double x0, double y0, double x1, double y1, Color c)
        {
            var l = new Line(new Point3d(x0, y0, 0), new Point3d(x1, y1, 0)) { Color = c };
            Add(doc, l);
        }

        static void Fill(Document doc, Box b, Color c, byte alpha = 128)
        {
            var s = new Solid(new Point3d(b.X0, b.Y0, 0), new Point3d(b.X1, b.Y0, 0), new Point3d(b.X0, b.Y1, 0), new Point3d(b.X1, b.Y1, 0))
            {
                Color = c,
                Transparency = new Transparency(alpha),
            };
            Add(doc, s);
        }

        static void Segment(Document doc, P a, P b, Color c, double width)
        {
            var pl = new DbPolyline();
            pl.AddVertexAt(0, new Point2d(a.X, a.Y), 0, width, width);
            pl.AddVertexAt(1, new Point2d(b.X, b.Y), 0, width, width);
            pl.Color = c;
            Add(doc, pl);
        }

        static void Label(Document doc, double x, double y, double h, string text, Color c)
        {
            var t = new DBText { Position = new Point3d(x, y, 0), Height = h, TextString = text, Color = c };
            Add(doc, t);
        }

        public static void Outline(Document doc, Shape sh, Color c, double width)
        {
            foreach (var loop in sh.Loops)
            {
                var pl = new DbPolyline();
                for (int i = 0; i < loop.Count; i++) pl.AddVertexAt(i, new Point2d(loop[i].X, loop[i].Y), 0, width, width);
                pl.Closed = true;
                pl.Color = c;
                Add(doc, pl);
            }
        }

        // The detail d of the zone: its grid (unless it is too dense to be read), its holes, the
        // objects with a problem (bad: their shapes) and the zone (its shape). w: the width of the
        // outlines, in drawing units. Returns false when the grid was too dense to be drawn:
        public static bool Detail(Document doc, Detail d, Shape zone, IEnumerable<Shape> bad, double w)
        {
            Clear(doc);
            var g = d.Grid;
            bool grid = g.X.Length <= MaxLines && g.Y.Length <= MaxLines;
            if (grid)
            {
                // Each line drawn where it crosses the zone (its cells inside, merged):
                foreach (var b in d.Runs(c => d.Kind[c] != CellKind.Outside))
                {
                    Line(doc, b.X0, b.Y0, b.X1, b.Y0, Grey);
                    Line(doc, b.X0, b.Y1, b.X1, b.Y1, Grey);
                }
                for (int i = 0; i <= g.Nx; i++)
                {
                    int j = 0;
                    while (j < g.Ny)
                    {
                        if (!In(d, i, j)) { j++; continue; }
                        int j0 = j;
                        while (j < g.Ny && In(d, i, j)) j++;
                        Line(doc, g.X[i], g.Y[j0], g.X[i], g.Y[j], Grey);
                    }
                }
            }
            int n = 0;
            foreach (var b in d.Runs(c => d.Kind[c] == CellKind.Hole))
            {
                if (++n > MaxRuns) break;
                Fill(doc, b, Red);
            }
            foreach (var s in bad) Outline(doc, s, Red, w);
            Outline(doc, zone, Orange, w);
            return grid;
        }

        public const int Levels = 32;       // the colours of the temperatures
        public const int MaxFieldRuns = 60000;

        static readonly Color Magenta = Color.FromColorIndex(ColorMethod.ByAci, 6);
        static readonly Color Ink = Color.FromColorIndex(ColorMethod.ByAci, 7);

        // The colour of u, 0 (cold: blue) to 1 (warm: red), white between (diverging, not a
        // rainbow, which would draw borders the field does not have):
        static Color Of(double u)
        {
            int[] cold = { 33, 102, 172 }, mid = { 247, 247, 247 }, warm = { 178, 24, 43 };
            int[] a = u < 0.5 ? cold : mid, b = u < 0.5 ? mid : warm;
            double t = u < 0.5 ? u * 2 : (u - 0.5) * 2;
            return Mix(a, b, t);
        }

        // The colour of a relative humidity u, 0 (dry: white) to 1 (saturated: dark blue): a
        // sequential scale, the field having one end only (ColorBrewer Blues):
        static Color Wet(double u)
        {
            int[] dry = { 247, 251, 255 }, wet = { 8, 48, 107 };
            return Mix(dry, wet, Math.Max(0, Math.Min(1, u)));
        }

        static Color Mix(int[] a, int[] b, double t) =>
            Color.FromRgb((byte)(a[0] + (b[0] - a[0]) * t), (byte)(a[1] + (b[1] - a[1]) * t), (byte)(a[2] + (b[2] - a[2]) * t));

        // The field of a run r over the drawing (its temperatures, or the relative humidity of its
        // vapour when r.Humidity), with what its summary tells (the dew point, the coldest interior
        // surface, the cells where vapour condenses), the zone and a legend beside it:
        public static void Field(Document doc, Result r)
        {
            Clear(doc);
            _last[doc] = r;
            var th = r.Surface;
            var s = r.Summary;
            var d = th.Detail;
            double w = r.W;
            bool wet = r.Humidity && r.Vapour != null;
            double lo = s.Te, hi = s.Ti;
            if (double.IsNaN(lo) || double.IsNaN(hi)) { lo = hi = 0; }

            // The colour level of each cell (-1: none, -2: a cell of a material not solved):
            var level = new int[th.T.Length];
            for (int levels = Levels; ; levels /= 2)
            {
                for (int c = 0; c < level.Length; c++)
                {
                    if (d.Kind[c] != CellKind.Material) { level[c] = -1; continue; }
                    double u;
                    if (wet)
                    {
                        if (double.IsNaN(r.Vapour.Pv[c])) { level[c] = -2; continue; }
                        u = Math.Min(1, r.Vapour.Rh(c));
                    }
                    else
                    {
                        double t = th.T[c];
                        if (double.IsNaN(t)) { level[c] = -2; continue; }
                        u = hi > lo ? (t - lo) / (hi - lo) : 0.5;
                    }
                    level[c] = (int)Math.Max(0, Math.Min(levels - 1, Math.Floor(u * levels)));
                }
                if (levels <= 4 || Runs(d, level) <= MaxFieldRuns)
                {
                    int n = 0;
                    foreach (var run in LevelRuns(d, level))
                    {
                        if (++n > MaxFieldRuns) break;
                        double u = (run.Item2 + 0.5) / levels;
                        Fill(doc, run.Item1, run.Item2 == -2 ? Grey : wet ? Wet(u) : Of(u), 180);
                    }
                    break;
                }
            }

            // The cells where vapour condenses:
            if (r.Vapour != null)
            {
                int n = 0;
                foreach (var b in d.Runs(c => r.Vapour.Condensing[c]))
                {
                    if (++n > MaxRuns) break;
                    Fill(doc, b, Magenta, 100);
                }
            }

            // The line of the dew point of the interior air, and the interior surfaces colder:
            if (!double.IsNaN(s.Dew) && !wet)
            {
                foreach (var (a, b) in Contour.Segments(d.Grid, th.T, s.Dew)) Segment(doc, a, b, Magenta, w);
            }
            if (!double.IsNaN(s.Dew))
                foreach (var f in th.Surfaces)
                    if (f.Ts < s.Dew && string.Equals(d.Regions[f.Climate].Climate, s.Interior, StringComparison.OrdinalIgnoreCase))
                        Segment(doc, f.A, f.B, Magenta, 3 * w);
            // The coldest interior surface:
            if (!double.IsNaN(s.Tsi) && !wet)
            {
                var ci = new Circle(new Point3d(s.TsiAt.X, s.TsiAt.Y, 0), Vector3d.ZAxis, 6 * w) { Color = Magenta };
                Add(doc, ci);
            }
            Outline(doc, r.Zone, Orange, w);
            if (wet) WetLegend(doc, r.Zone.Bounds, s);
            else Legend(doc, r.Zone.Bounds, lo, hi, s, r.Imperial);
        }

        // The run of a drawing shown again, with its temperatures or its relative humidity;
        // false when there is none (or no vapour for the humidity):
        public static bool View(Document doc, bool humidity)
        {
            var r = Last(doc);
            if (r == null || (humidity && r.Vapour == null)) return false;
            r.Humidity = humidity;
            Field(doc, r);
            return true;
        }

        // The size of a legend at the right of the zone b: (x0, bw, y0, bh, text height):
        static (double, double, double, double, double) Place(Box b)
        {
            double size = Math.Max(b.Width, b.Height);
            double x0 = b.X1 + size * 0.04, bw = size * 0.03, y0 = b.Y0 + b.Height * 0.1, bh = b.Height * 0.8;
            return (x0, bw, y0, bh, Math.Min(bh / 16, size / 40));
        }

        // The legend at the right of the zone b: the colours from lo (bottom) to hi (top), their
        // values, the dew point, and the condensation when vapour condenses:
        static void Legend(Document doc, Box b, double lo, double hi, Summary s, bool imperial)
        {
            var (x0, bw, y0, bh, th) = Place(b);
            int n = 16;
            for (int k = 0; k < n; k++)
                Fill(doc, new Box(x0, y0 + bh * k / n, x0 + bw, y0 + bh * (k + 1) / n), Of((k + 0.5) / n), 255);
            string Deg(double t) => (imperial ? (t * 1.8 + 32).ToString("0.#", CultureInfo.InvariantCulture) + " \u00b0F"
                                              : t.ToString("0.#", CultureInfo.InvariantCulture) + " \u00b0C");
            double tx = x0 + bw + th * 0.6;
            Label(doc, tx, y0 - th / 2, th, Deg(lo) + (s.Exterior.Length > 0 ? "  " + Name(s.Exterior) : ""), Ink);
            Label(doc, tx, y0 + bh - th / 2, th, Deg(hi) + (s.Interior.Length > 0 ? "  " + Name(s.Interior) : ""), Ink);
            if (!double.IsNaN(s.Dew) && hi > lo && s.Dew > lo && s.Dew < hi)
            {
                double y = y0 + bh * (s.Dew - lo) / (hi - lo);
                Segment(doc, new P(x0 - bw * 0.3, y), new P(x0 + bw * 1.3, y), Magenta, th / 6);
                Label(doc, tx, y - th / 2, th, Deg(s.Dew) + "  Dew point", Magenta);
            }
            Condensation(doc, x0, bw, y0, th, s);
        }

        // The legend of the relative humidity: 0 % (bottom) to 100 % (top):
        static void WetLegend(Document doc, Box b, Summary s)
        {
            var (x0, bw, y0, bh, th) = Place(b);
            int n = 16;
            for (int k = 0; k < n; k++)
                Fill(doc, new Box(x0, y0 + bh * k / n, x0 + bw, y0 + bh * (k + 1) / n), Wet((k + 0.5) / n), 255);
            double tx = x0 + bw + th * 0.6;
            Label(doc, tx, y0 - th / 2, th, "0 %", Ink);
            Label(doc, tx, y0 + bh / 2 - th / 2, th, "50 %", Ink);
            Label(doc, tx, y0 + bh - th / 2, th, "100 %  Relative humidity", Ink);
            Condensation(doc, x0, bw, y0, th, s);
        }

        // Under a legend, the swatch of the condensation, when vapour condenses:
        static void Condensation(Document doc, double x0, double bw, double y0, double th, Summary s)
        {
            if (s.Condensing == 0) return;
            double y = y0 - th * 3;
            Fill(doc, new Box(x0, y, x0 + bw, y + th), Magenta, 100);
            Label(doc, x0 + bw + th * 0.6, y, th, "Condensation", Magenta);
        }

        // An id shown as its name (cl-Interior: Interior):
        static string Name(string id) => id.StartsWith("cl-", StringComparison.OrdinalIgnoreCase) ? id.Substring(3) : id;

        // The runs of cells of one level along each row (level -1 left out):
        static IEnumerable<(Box, int)> LevelRuns(Detail d, int[] level)
        {
            var g = d.Grid;
            for (int j = 0; j < g.Ny; j++)
            {
                int i = 0;
                while (i < g.Nx)
                {
                    int l = level[d.Cell(i, j)];
                    if (l == -1) { i++; continue; }
                    int i0 = i;
                    while (i < g.Nx && level[d.Cell(i, j)] == l) i++;
                    yield return (new Box(g.X[i0], g.Y[j], g.X[i], g.Y[j + 1]), l);
                }
            }
        }

        static int Runs(Detail d, int[] level)
        {
            int n = 0;
            foreach (var _ in LevelRuns(d, level)) n++;
            return n;
        }

        // A vertical line of the grid at i touches the zone at row j (a cell on either side):
        static bool In(Detail d, int i, int j)
        {
            var g = d.Grid;
            return (i > 0 && d.Kind[d.Cell(i - 1, j)] != CellKind.Outside) || (i < g.Nx && d.Kind[d.Cell(i, j)] != CellKind.Outside);
        }
    }
}
