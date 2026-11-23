// Plugin.cs - DynALisp.Simulation: the Lisp functions of the simulation
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
// The Lisp side (Apps\Analysis\Dyl-Simulation.lsp) keeps what it already does: the materials,
// the climates, the units, the windows. It calls (each one checked first, (if Dyl:X ...)):
//
//   (Dyl:SimulationRead zone size known data climates)
//     zone: the closed curve of the simulation zone; size: the target size of the cells, in
//     drawing units; known: the ids of every material; data: the ids of the materials that have
//     a thermal conductivity or a fixed RSI; climates: the ids of every climate.
//     Reads the detail of the zone, shows its grid and its problems over the drawing, and
//     returns (cells nx ny regions nomaterial unknown nodata holes overlaps badclimates
//     climatecells grid (material ...)): the cells of the zone; the columns and rows of the
//     grid; the regions in the zone; those of a hatch without a material, of a material that
//     no longer exists, of a material without data; the holes (groups of cells of no region);
//     the cells inside two regions of a material or more (the one in front wins); the climate
//     zones of a climate that no longer exists; the cells of climate (air); 1 when the grid
//     was drawn (0: too dense to be read); the materials of the regions. A text when the zone
//     cannot be read (the message).
//
//   (Dyl:SimulationClear)  clears what the simulation shows over the current drawing; T.

using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using DynALisp.Simulation.Core;
using Shape = DynALisp.Simulation.Core.Shape;
using Region = DynALisp.Simulation.Core.Region;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Simulation.Plugin))]

namespace DynALisp.Simulation
{
    public class Plugin
    {
        [LispFunction("Dyl:SimulationRead")]
        public ResultBuffer Read(ResultBuffer args)
        {
            try
            {
                var a = Args(args);
                if (a.Count < 5 || !(a[0] is ObjectId zoneId) || !(a[1] is double size))
                    return Text("Dyl:SimulationRead: (zone size known data climates) expected.");
                var known = Set(a[2]);
                var data = Set(a[3]);
                var climates = Set(a[4]);
                var doc = AcApp.DocumentManager.MdiActiveDocument;

                using (var tr = doc.Database.TransactionManager.StartTransaction())
                {
                    var zoneEnt = tr.GetObject(zoneId, OpenMode.ForRead) as Entity;
                    var zone = zoneEnt == null ? null : Reader.CurveShape(zoneEnt);
                    if (zone == null) return Text("The simulation zone is not a closed curve.");
                    var space = (BlockTableRecord)tr.GetObject(zoneEnt.OwnerId, OpenMode.ForRead);
                    var srcs = Reader.Read(tr, space, zoneId, zone.Bounds);

                    var regions = new List<Region>();
                    foreach (var s in srcs) regions.Add(s.Region);
                    Detail d;
                    try { d = Detail.Read(zone, regions, size); }
                    catch (ArgumentException ex) { tr.Commit(); return Text(ex.Message); }

                    int nreg = 0, nomat = 0, unknown = 0, nodata = 0, badclim = 0;
                    var bad = new List<Shape>();
                    var mats = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                    for (int r = 0; r < regions.Count; r++)
                    {
                        if (d.CellsOf[r] == 0) continue;
                        var reg = regions[r];
                        bool isBad = false;
                        if (reg.IsClimate)
                        {
                            if (!climates.Contains(reg.Climate)) { badclim++; isBad = true; }
                        }
                        else
                        {
                            nreg++;
                            if (reg.Material.Length == 0) { nomat++; isBad = true; }
                            else
                            {
                                mats.Add(reg.Material);
                                if (!known.Contains(reg.Material)) { unknown++; isBad = true; }
                                else if (!data.Contains(reg.Material)) { nodata++; isBad = true; }
                            }
                        }
                        if (isBad) bad.Add(reg.Shape);
                    }

                    var zb = zone.Bounds;
                    double w = Math.Max(zb.Width, zb.Height) / 400;
                    bool grid = Show.Detail(doc, d, zone, bad, w);
                    tr.Commit();

                    var res = new ResultBuffer();
                    foreach (var n in new long[] { d.Kind.Length - d.Count(CellKind.Outside), d.Grid.Nx, d.Grid.Ny, nreg, nomat, unknown, nodata,
                                                   d.Holes.Count, d.Overlaps, badclim, d.Count(CellKind.Climate), grid ? 1 : 0 })
                        res.Add(new TypedValue((int)LispDataType.Int32, (int)Math.Min(n, int.MaxValue)));
                    res.Add(new TypedValue((int)LispDataType.ListBegin));
                    foreach (var m in mats) res.Add(new TypedValue((int)LispDataType.Text, m));
                    res.Add(new TypedValue((int)LispDataType.ListEnd));
                    return res;
                }
            }
            catch (System.Exception ex)
            {
                return Text("Dyl:SimulationRead: " + ex.Message);
            }
        }

        [LispFunction("Dyl:SimulationClear")]
        public ResultBuffer Clear(ResultBuffer args)
        {
            Show.Clear(AcApp.DocumentManager.MdiActiveDocument);
            return new ResultBuffer(new TypedValue((int)LispDataType.T_atom));
        }

        static ResultBuffer Text(string s) => new ResultBuffer(new TypedValue((int)LispDataType.Text, s));

        // The arguments of a Lisp call: an ObjectId, a double (an integer read as one), a list of
        // texts (List<string>, nil an empty list), in their order:
        static List<object> Args(ResultBuffer rb)
        {
            var res = new List<object>();
            if (rb == null) return res;
            List<string> list = null;
            foreach (var tv in rb)
            {
                switch ((LispDataType)tv.TypeCode)
                {
                    case LispDataType.ListBegin: list = new List<string>(); break;
                    case LispDataType.ListEnd:
                    case LispDataType.DottedPair:
                        if (list != null) { res.Add(list); list = null; }
                        break;
                    case LispDataType.Text:
                        if (list != null) list.Add((string)tv.Value); else res.Add((string)tv.Value);
                        break;
                    case LispDataType.Nil:
                        if (list == null) res.Add(new List<string>());
                        break;
                    case LispDataType.Double: if (list == null) res.Add((double)tv.Value); break;
                    case LispDataType.Int16: if (list == null) res.Add((double)(short)tv.Value); break;
                    case LispDataType.Int32: if (list == null) res.Add((double)(int)tv.Value); break;
                    case LispDataType.ObjectId: if (list == null) res.Add((ObjectId)tv.Value); break;
                }
            }
            return res;
        }

        static HashSet<string> Set(object o)
        {
            var s = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (o is List<string> l) foreach (var x in l) s.Add(x);
            return s;
        }
    }
}
