// Reader.cs - DynALisp.Simulation: the regions of a detail, read in the drawing
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
// What a detail is made of is read from the extended data of the application DYNALISP, strings
// Key=value (Remote>>Dyl:MaterialTagPut of Remote\Dyl-Materials.lsp writes them):
//   - a hatch or a closed curve with Material=<id>: a region of that material (a hatch inside
//     its loops, a curve inside itself);
//   - a hatch without Material: a region of no material, shown as a problem;
//   - a closed curve with Role=Climate and Climate=<id>: a climate zone;
//   - a closed curve with Role=SimulationZone: a simulation zone, never a region.
// Only the objects of the space of the zone whose extents touch it are read. Their arcs are
// divided into segments (every 10 degrees), a spline or an ellipse into 96. The draw order of
// the space gives the order of each region (the one in front wins where two overlap).

using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using DynALisp.Simulation.Core;
using Shape = DynALisp.Simulation.Core.Shape;
using Region = DynALisp.Simulation.Core.Region;

namespace DynALisp.Simulation
{
    // An object read: its region and what it is.
    class Source
    {
        public ObjectId Id;
        public Region Region;
        public bool Tagged;     // it carries a Material (or a Climate) key
    }

    static class Reader
    {
        public const string App = "DYNALISP";
        const double ArcStep = Math.PI / 18;   // 10 degrees
        const int CurveSamples = 96;

        // The Key=value strings of the DYNALISP data of an object (empty when it has none):
        public static Dictionary<string, string> Tags(DBObject o)
        {
            var res = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            using (var rb = o.GetXDataForApplication(App))
            {
                if (rb == null) return res;
                foreach (var tv in rb)
                {
                    if (tv.TypeCode != (int)DxfCode.ExtendedDataAsciiString) continue;
                    var s = tv.Value as string;
                    int k = s == null ? -1 : s.IndexOf('=');
                    if (k > 0) res[s.Substring(0, k)] = s.Substring(k + 1);
                }
            }
            return res;
        }

        public static string Tag(Dictionary<string, string> tags, string key) =>
            tags.TryGetValue(key, out var v) ? v ?? "" : "";

        // The shape of a closed curve (nil when it is not closed or not a curve read here):
        public static Shape CurveShape(Entity e)
        {
            var pts = new List<P>();
            switch (e)
            {
                case Polyline pl:
                    if (!pl.Closed && pl.NumberOfVertices > 2 && !pl.GetPoint2dAt(0).IsEqualTo(pl.GetPoint2dAt(pl.NumberOfVertices - 1))) return null;
                    for (int i = 0; i < pl.NumberOfVertices; i++)
                    {
                        double b = pl.GetBulgeAt(i);
                        int n = 1;
                        if (Math.Abs(b) > 1e-9 && (pl.Closed || i < pl.NumberOfVertices - 1))
                            n = Math.Max(2, (int)Math.Ceiling(Math.Abs(4 * Math.Atan(b)) / ArcStep));
                        for (int s = 0; s < n; s++)
                        {
                            double prm = i + (double)s / n;
                            if (prm > pl.EndParam) break;
                            Add(pts, pl.GetPointAtParameter(prm));
                        }
                    }
                    break;
                case Circle c:
                    for (int s = 0; s < 36; s++) Add(pts, c.Center + new Vector3d(c.Radius * Math.Cos(s * ArcStep), c.Radius * Math.Sin(s * ArcStep), 0));
                    break;
                case Polyline2d p2:
                    if (!p2.Closed) return null;
                    for (int prm = (int)p2.StartParam; prm < (int)Math.Round(p2.EndParam); prm++) Add(pts, p2.GetPointAtParameter(prm));
                    break;
                case Curve cv when cv is Ellipse || cv is Spline:
                    if (!cv.Closed) return null;
                    for (int s = 0; s < CurveSamples; s++)
                        Add(pts, cv.GetPointAtParameter(cv.StartParam + (cv.EndParam - cv.StartParam) * s / CurveSamples));
                    break;
                default:
                    return null;
            }
            var sh = new Shape();
            sh.AddLoop(pts);
            return sh.Loops.Count > 0 ? sh : null;
        }

        static void Add(List<P> pts, Point3d p) => pts.Add(new P(p.X, p.Y));

        // The shape of a hatch: each of its loops, in the coordinates of the drawing:
        public static Shape HatchShape(Hatch h)
        {
            var sh = new Shape();
            var m = Matrix3d.PlaneToWorld(h.GetPlane());
            for (int k = 0; k < h.NumberOfLoops; k++)
            {
                var pts = new List<Point2d>();
                var loop = h.GetLoopAt(k);
                if (loop.IsPolyline)
                {
                    var bv = loop.Polyline;
                    int n = bv.Count;
                    for (int i = 0; i < n; i++)
                    {
                        var a = bv[i];
                        var b = bv[(i + 1) % n];
                        pts.Add(a.Vertex);
                        if (Math.Abs(a.Bulge) > 1e-9 && !a.Vertex.IsEqualTo(b.Vertex)) ArcPoints(a.Vertex, b.Vertex, a.Bulge, pts);
                    }
                }
                else
                {
                    Point2d? last = null;
                    foreach (Curve2d c in loop.Curves)
                    {
                        Point2d[] seg;
                        if (c is LineSegment2d ls) seg = new[] { ls.StartPoint, ls.EndPoint };
                        else
                        {
                            int n = c is NurbCurve2d || c is EllipticalArc2d ? CurveSamples : 36;
                            seg = c.GetSamplePoints(n);
                        }
                        if (seg.Length == 0) continue;
                        // The curves of a loop follow each other; one given the other way is turned:
                        if (last.HasValue && seg.Length > 1 &&
                            seg[seg.Length - 1].GetDistanceTo(last.Value) < seg[0].GetDistanceTo(last.Value))
                            Array.Reverse(seg);
                        for (int i = 0; i < seg.Length - 1; i++) pts.Add(seg[i]);
                        last = seg[seg.Length - 1];
                    }
                }
                var wl = new List<P>();
                foreach (var p in pts)
                {
                    var w = new Point3d(p.X, p.Y, 0).TransformBy(m);
                    wl.Add(new P(w.X, w.Y));
                }
                sh.AddLoop(wl);
            }
            return sh.Loops.Count > 0 ? sh : null;
        }

        // The points inside the arc from a to b of bulge bu (a and b left out):
        static void ArcPoints(Point2d a, Point2d b, double bu, List<Point2d> pts)
        {
            double th = 4 * Math.Atan(bu);
            int n = Math.Max(2, (int)Math.Ceiling(Math.Abs(th) / ArcStep));
            double d = a.GetDistanceTo(b);
            if (d < 1e-12) return;
            double r = d / (2 * Math.Sin(Math.Abs(th) / 2));
            var mid = new Point2d((a.X + b.X) / 2, (a.Y + b.Y) / 2);
            var u = (b - a) / d;
            var nrm = new Vector2d(-u.Y, u.X);
            double off = r * Math.Cos(th / 2) * Math.Sign(bu);   // from the chord to the center
            var c = mid + nrm * off;
            double a0 = Math.Atan2(a.Y - c.Y, a.X - c.X);
            for (int s = 1; s < n; s++)
            {
                double t = a0 + th * s / n;
                pts.Add(new Point2d(c.X + r * Math.Cos(t), c.Y + r * Math.Sin(t)));
            }
        }

        // The objects of the space of the zone that make the detail of zone box zb:
        public static List<Source> Read(Transaction tr, BlockTableRecord space, ObjectId zoneId, Box zb)
        {
            var order = new Dictionary<ObjectId, int>();
            try
            {
                var dot = (DrawOrderTable)tr.GetObject(space.DrawOrderTableId, OpenMode.ForRead);
                var ids = dot.GetFullDrawOrder(0);
                for (int i = 0; i < ids.Count; i++) order[ids[i]] = i;
            }
            catch (Autodesk.AutoCAD.Runtime.Exception) { }

            var res = new List<Source>();
            foreach (ObjectId id in space)
            {
                if (id == zoneId || id.IsErased) continue;
                var cls = id.ObjectClass.DxfName;
                if (cls != "HATCH" && cls != "LWPOLYLINE" && cls != "POLYLINE" && cls != "CIRCLE" && cls != "ELLIPSE" && cls != "SPLINE") continue;
                var e = tr.GetObject(id, OpenMode.ForRead) as Entity;
                if (e == null) continue;
                Box eb;
                try
                {
                    var ext = e.GeometricExtents;
                    eb = new Box(ext.MinPoint.X, ext.MinPoint.Y, ext.MaxPoint.X, ext.MaxPoint.Y);
                }
                catch (Autodesk.AutoCAD.Runtime.Exception) { continue; }
                if (!eb.Touches(zb)) continue;

                var tags = Tags(e);
                string mat = Tag(tags, "Material"), role = Tag(tags, "Role"), clim = Tag(tags, "Climate");
                var src = new Source { Id = id };
                if (e is Hatch h)
                {
                    src.Region = new Region { Shape = HatchShape(h), Material = mat };
                    src.Tagged = mat.Length > 0;
                }
                else if (mat.Length > 0 || (role.Equals("Climate", StringComparison.OrdinalIgnoreCase) && clim.Length > 0))
                {
                    var sh = CurveShape(e);
                    if (sh == null) continue;
                    src.Region = new Region { Shape = sh, Material = mat.Length > 0 ? mat : "", Climate = mat.Length > 0 ? "" : clim };
                    src.Tagged = true;
                }
                else continue;
                if (src.Region.Shape == null) continue;
                src.Region.Order = order.TryGetValue(id, out var o) ? o : 0;
                src.Region.Source = res.Count;
                res.Add(src);
            }
            return res;
        }
    }
}
