// Keep.cs - DynALisp.Simulation: the result of a simulation drawn on purpose
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
// What the user keeps of the last run of a drawing, added to its current space as objects of
// its own (to print the detail with them): the isotherms as polylines, each level labelled
// once, the line of the dew point of the interior air, and a hatch over the cells where
// vapour condenses. Everything goes on the current layer: the Lisp puts each one on its layer
// key (Dyl:SimKeep), so the objects are the drawing's, saved, plotted and undone as any other.

using System;
using System.Collections.Generic;
using System.Globalization;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using DynALisp.Simulation.Core;
using DbPolyline = Autodesk.AutoCAD.DatabaseServices.Polyline;

namespace DynALisp.Simulation
{
    static class Keep
    {
        public class Made
        {
            public List<ObjectId> Isotherms = new List<ObjectId>(), Labels = new List<ObjectId>(),
                                  Dew = new List<ObjectId>(), Condensation = new List<ObjectId>();
        }

        // The run r of the document: the isotherms every step degrees (in the units shown: F
        // when r.Imperial), labels of height h, the dew point line and the hatch of the
        // condensation (hatch: its spacing, in drawing units). Returns what was made:
        public static Made Draw(Document doc, Show.Result r, double step, double h, double hatch)
        {
            var made = new Made();
            var th = r.Surface;
            var d = th.Detail;
            var g = d.Grid;
            double eps = 1e-6 * Math.Max(g.X[g.Nx] - g.X[0], g.Y[g.Ny] - g.Y[0]);
            var db = doc.Database;
            using (var tr = db.TransactionManager.StartTransaction())
            {
                var space = (BlockTableRecord)tr.GetObject(db.CurrentSpaceId, OpenMode.ForWrite);
                ObjectId Add(Entity e)
                {
                    e.SetDatabaseDefaults(db);
                    var id = space.AppendEntity(e);
                    tr.AddNewlyCreatedDBObject(e, true);
                    return id;
                }

                // The levels between the lowest and the highest temperature of the detail:
                double lo = double.MaxValue, hi = double.MinValue;
                foreach (var t in th.T) if (!double.IsNaN(t)) { lo = Math.Min(lo, t); hi = Math.Max(hi, t); }
                Func<double, double> shown = c => r.Imperial ? c * 1.8 + 32 : c;
                Func<double, double> si = x => r.Imperial ? (x - 32) / 1.8 : x;
                if (step > 0 && lo < hi)
                {
                    for (double x = Math.Ceiling(shown(lo) / step) * step; x < shown(hi); x += step)
                    {
                        if (x <= shown(lo)) continue;
                        var lines = Contour.Chains(Contour.Segments(g, th.T, si(x)), eps);
                        List<P> longest = null;
                        foreach (var l in lines)
                        {
                            made.Isotherms.Add(Add(Line(l, eps)));
                            if (longest == null || l.Count > longest.Count) longest = l;
                        }
                        if (longest != null && h > 0)
                        {
                            var p = longest[longest.Count / 2];
                            made.Labels.Add(Add(new DBText
                            {
                                Position = new Point3d(p.X, p.Y, 0),
                                Height = h,
                                TextString = x.ToString("0.#", CultureInfo.InvariantCulture) + (r.Imperial ? " °F" : " °C"),
                            }));
                        }
                    }
                }

                // The dew point of the interior air:
                var s = r.Summary;
                if (!double.IsNaN(s.Dew))
                {
                    List<P> longest = null;
                    foreach (var l in Contour.Chains(Contour.Segments(g, th.T, s.Dew), eps))
                    {
                        made.Dew.Add(Add(Line(l, eps)));
                        if (longest == null || l.Count > longest.Count) longest = l;
                    }
                    if (longest != null && h > 0)
                    {
                        var p = longest[longest.Count / 2];
                        made.Dew.Add(Add(new DBText
                        {
                            Position = new Point3d(p.X, p.Y, 0),
                            Height = h,
                            TextString = "Dew point " + shown(s.Dew).ToString("0.#", CultureInfo.InvariantCulture) + (r.Imperial ? " °F" : " °C"),
                        }));
                    }
                }

                // The cells where vapour condenses, their runs along each row the loops of one hatch:
                if (r.Vapour != null && s.Condensing > 0)
                {
                    var runs = d.Runs(c => r.Vapour.Condensing[c]);
                    if (runs.Count > 0)
                    {
                        var hb = new Hatch();
                        hb.SetDatabaseDefaults(db);
                        var id = space.AppendEntity(hb);
                        tr.AddNewlyCreatedDBObject(hb, true);
                        // ANSI37 is 0.125 in apart in acad.pat, 3.175 mm in acadiso.pat:
                        double basis = db.Measurement == MeasurementValue.English ? 0.125 : 3.175;
                        hb.SetHatchPattern(HatchPatternType.PreDefined, "ANSI37");
                        hb.PatternScale = hatch > 0 ? hatch / basis : 1;
                        // Set again, for the scale to apply to the pattern:
                        hb.SetHatchPattern(HatchPatternType.PreDefined, "ANSI37");
                        hb.Associative = false;
                        foreach (var b in runs)
                        {
                            var pts = new Point2dCollection
                            {
                                new Point2d(b.X0, b.Y0), new Point2d(b.X1, b.Y0), new Point2d(b.X1, b.Y1), new Point2d(b.X0, b.Y1), new Point2d(b.X0, b.Y0),
                            };
                            hb.AppendLoop(HatchLoopTypes.Polyline, pts, new DoubleCollection(new double[] { 0, 0, 0, 0, 0 }));
                        }
                        hb.EvaluateHatch(true);
                        made.Condensation.Add(id);
                    }
                }
                tr.Commit();
            }
            return made;
        }

        // A polyline through the points l, closed when its ends meet:
        static DbPolyline Line(List<P> l, double eps)
        {
            var pl = new DbPolyline();
            bool closed = l.Count > 3 && Math.Abs(l[0].X - l[l.Count - 1].X) < eps && Math.Abs(l[0].Y - l[l.Count - 1].Y) < eps;
            int n = closed ? l.Count - 1 : l.Count;
            for (int i = 0; i < n; i++) pl.AddVertexAt(i, new Point2d(l[i].X, l[i].Y), 0, 0, 0);
            pl.Closed = closed;
            return pl;
        }
    }
}
