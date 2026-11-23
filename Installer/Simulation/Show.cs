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
// red and the zone outlined in orange.

using System.Collections.Generic;
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
        static bool _hooked;

        public const int MaxLines = 1500;   // grid lines drawn at most on each axis
        public const int MaxRuns = 20000;   // filled rectangles drawn at most

        static readonly Color Grey = Color.FromColorIndex(ColorMethod.ByAci, 253);
        static readonly Color Red = Color.FromColorIndex(ColorMethod.ByAci, 1);
        static readonly Color Orange = Color.FromColorIndex(ColorMethod.ByAci, 30);

        public static void Clear(Document doc)
        {
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

        static void Fill(Document doc, Box b, Color c)
        {
            var s = new Solid(new Point3d(b.X0, b.Y0, 0), new Point3d(b.X1, b.Y0, 0), new Point3d(b.X0, b.Y1, 0), new Point3d(b.X1, b.Y1, 0))
            {
                Color = c,
                Transparency = new Transparency((byte)128),
            };
            Add(doc, s);
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

        // A vertical line of the grid at i touches the zone at row j (a cell on either side):
        static bool In(Detail d, int i, int j)
        {
            var g = d.Grid;
            return (i > 0 && d.Kind[d.Cell(i - 1, j)] != CellKind.Outside) || (i < g.Nx && d.Kind[d.Cell(i, j)] != CellKind.Outside);
        }
    }
}
