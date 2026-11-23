// Check.cs - DynALisp.Simulation: the detail of a simulation zone read and checked
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
// The detail of a simulation zone read from the drawing (Reader) on its grid (Core\Detail.cs),
// and what is wrong with it: the hatches without a material, the materials that no longer
// exist or have no thermal data, the holes, the climate zones of a climate that no longer
// exists, no climate at all. Shown over the drawing (Show.Detail) and given to the Lisp
// (Write) by Dyl:SimulationRead and Dyl:SimulationRun.

using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using DynALisp.Simulation.Core;
using Shape = DynALisp.Simulation.Core.Shape;
using Region = DynALisp.Simulation.Core.Region;

namespace DynALisp.Simulation
{
    class Check
    {
        public Shape Zone;
        public Detail Detail;
        public int Regions, NoMaterial, Unknown, NoData, BadClimates;
        public List<Shape> Bad = new List<Shape>();
        public SortedSet<string> Materials = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        public SortedSet<string> Climates = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        public bool Grid;

        public int ClimateCells => Detail.Count(CellKind.Climate);

        public bool Problems => NoMaterial + Unknown + NoData + BadClimates + Detail.Holes.Count > 0 || ClimateCells == 0;

        // The zone zoneId read with cells of the size h (drawing units): known the ids of every
        // material, data those that have thermal data, climates the ids of every climate. Null
        // (and the error) when it cannot be read:
        public static Check Of(Transaction tr, ObjectId zoneId, double h, HashSet<string> known, HashSet<string> data,
                               HashSet<string> climates, out string error)
        {
            error = null;
            var zoneEnt = tr.GetObject(zoneId, OpenMode.ForRead) as Entity;
            var zone = zoneEnt == null ? null : Reader.CurveShape(zoneEnt);
            if (zone == null) { error = "The simulation zone is not a closed curve."; return null; }
            var space = (BlockTableRecord)tr.GetObject(zoneEnt.OwnerId, OpenMode.ForRead);
            var srcs = Reader.Read(tr, space, zoneId, zone.Bounds);

            var regions = new List<Region>();
            foreach (var s in srcs) regions.Add(s.Region);
            var ck = new Check { Zone = zone };
            try { ck.Detail = Detail.Read(zone, regions, h); }
            catch (ArgumentException ex) { error = ex.Message; return null; }

            var d = ck.Detail;
            for (int r = 0; r < regions.Count; r++)
            {
                if (d.CellsOf[r] == 0) continue;
                var reg = regions[r];
                bool isBad = false;
                if (reg.IsClimate)
                {
                    if (!climates.Contains(reg.Climate)) { ck.BadClimates++; isBad = true; }
                    else ck.Climates.Add(reg.Climate);
                }
                else
                {
                    ck.Regions++;
                    if (reg.Material.Length == 0) { ck.NoMaterial++; isBad = true; }
                    else
                    {
                        ck.Materials.Add(reg.Material);
                        if (!known.Contains(reg.Material)) { ck.Unknown++; isBad = true; }
                        else if (!data.Contains(reg.Material)) { ck.NoData++; isBad = true; }
                    }
                }
                if (isBad) ck.Bad.Add(reg.Shape);
            }
            return ck;
        }

        // The grid and the problems over the drawing:
        public void Show(Document doc)
        {
            var zb = Zone.Bounds;
            Grid = Simulation.Show.Detail(doc, Detail, Zone, Bad, Math.Max(zb.Width, zb.Height) / 400);
        }

        // (cells nx ny regions nomaterial unknown nodata holes overlaps badclimates climatecells
        // grid (material ...) (climate ...)), as a list:
        public void Write(ResultBuffer res)
        {
            var d = Detail;
            res.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var n in new long[] { d.Kind.Length - d.Count(CellKind.Outside), d.Grid.Nx, d.Grid.Ny, Regions, NoMaterial, Unknown, NoData,
                                           d.Holes.Count, d.Overlaps, BadClimates, ClimateCells, Grid ? 1 : 0 })
                res.Add(new TypedValue((int)LispDataType.Int32, (int)Math.Min(n, int.MaxValue)));
            foreach (var set in new[] { Materials, Climates })
            {
                res.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var m in set) res.Add(new TypedValue((int)LispDataType.Text, m));
                res.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            res.Add(new TypedValue((int)LispDataType.ListEnd));
        }
    }
}
