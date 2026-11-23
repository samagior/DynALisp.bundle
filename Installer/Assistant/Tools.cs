// Tools.cs - DynALisp.Assistant: the tools Claude has on the drawing, and those that read it
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
// The tools of the server "dynalisp" (mcp__dynalisp__<name> for Claude Code):
//   read, allowed without asking (Chat.ReadTools, --allowedTools):
//     drawing_info, get_selection, list_objects, get_object, list_layers, list_blocks
//   write, each one approved by the user in the palette first (Writes.cs):
//     create_entities, modify_entities, erase_entities, set_layers, run_command
//   approve, called by Claude Code itself before a write (--permission-prompt-tool), never by
//     Claude: it shows the approval card and waits for the answer of the user.
// A tool answers a text of JSON; a list gives 200 objects a page at most (Claude Code takes
// 25 000 tokens of a tool at most). Coordinates are in the units of the drawing, angles in
// degrees, rounded to 6 decimals.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Colors;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Assistant
{
    static partial class Tools
    {
        public const string Prefix = "mcp__dynalisp__";
        public const int Page = 200;

        public static readonly string[] Reads = { "drawing_info", "get_selection", "list_objects", "get_object", "list_layers", "list_blocks" };
        public static readonly string[] Writes = { "create_entities", "modify_entities", "erase_entities", "set_layers", "run_command" };

        // ---- the list of tools ------------------------------------------------------

        public static List<object> List()
        {
            var handles = Arr(Str("A handle, as given by the other tools (\"2F1\")"), "The handles of the objects");
            var pt = Arr(Num(), "A point [x, y] or [x, y, z], in drawing units");
            var l = new List<object>
            {
                Tool("drawing_info", "The active drawing: its name, units (INSUNITS, MEASUREMENT), annotation scale, current layer and layout, extents and the number of objects of each type in the current space.",
                    Obj()),
                Tool("get_selection", "The objects the user has selected in the drawing (the selection made before asking): their number by type, and their handles, types and layers (200 at most).",
                    Obj()),
                Tool("list_objects", "Lists the objects of a space of the drawing, filtered, a page at a time: handle, type (DXF name), layer and bounding box. Use get_object for their properties.",
                    Obj(new Dictionary<string, object>
                    {
                        ["types"] = Str("DXF names, divided by commas, * and ? allowed: \"LINE,LWPOLYLINE\", \"*TEXT\", \"INSERT\", \"HATCH\". Empty: every type."),
                        ["layers"] = Str("Layer names, divided by commas, * and ? allowed. Empty: every layer."),
                        ["window"] = Arr(Num(), "[xmin, ymin, xmax, ymax]: only the objects whose bounding box touches it"),
                        ["space"] = Str("\"current\" (default), \"model\", or the name of a layout"),
                        ["offset"] = Int("The first object of the page (0 by default)"),
                        ["limit"] = Int("The number of objects of the page, 200 at most (100 by default)"),
                    })),
                Tool("get_object", "Every property of objects given by their handles (50 at most): layer, color, linetype, geometry (points, vertices and bulges, radius, angles, length, area), text, block and attributes, hatch pattern and loops, and the DynALisp data (material, role).",
                    Obj(new Dictionary<string, object> { ["handles"] = handles }, "handles")),
                Tool("list_layers", "The layers of the drawing and their properties (color, linetype, lineweight, on, frozen, locked, plot, description), the current one marked.",
                    Obj(new Dictionary<string, object>
                    {
                        ["names"] = Str("Layer names, divided by commas, * and ? allowed. Empty: every layer."),
                        ["offset"] = Int("The first layer of the page (0 by default)"),
                    })),
                Tool("list_blocks", "The block definitions of the drawing (not the layouts): name, dynamic or xref, their attribute definitions and how many times each one is inserted.",
                    Obj(new Dictionary<string, object>
                    {
                        ["names"] = Str("Block names, divided by commas, * and ? allowed. Empty: every block but the anonymous ones."),
                        ["offset"] = Int("The first block of the page (0 by default)"),
                    })),

                Tool("create_entities", "Creates objects in the current space of the active drawing, all in one change the user approves first and undoes with one U (500 objects at most). Give everything that goes together in one call. Each item has a type and its geometry, and may have a layer (it must exist: create it with set_layers first), a color (an index 1-255, \"ByLayer\", \"ByBlock\" or \"r,g,b\") and a linetype. Returns the handles made.",
                    Obj(new Dictionary<string, object>
                    {
                        ["items"] = Arr(Obj(new Dictionary<string, object>
                        {
                            ["type"] = Str("line, polyline, circle, arc, point, text, mtext, insert or hatch"),
                            ["layer"] = Str("The layer of the object (default: the current layer)"),
                            ["color"] = Str("1-255, ByLayer, ByBlock or r,g,b (default: ByLayer)"),
                            ["linetype"] = Str("A linetype loaded in the drawing (default: ByLayer)"),
                            ["start"] = pt, ["end"] = pt,
                            ["points"] = Arr(pt, "polyline: its vertices; hatch: the vertices of a closed boundary"),
                            ["bulges"] = Arr(Num(), "polyline: the bulge of each segment (0 straight)"),
                            ["closed"] = Bool("polyline: closed"),
                            ["width"] = Num("polyline: the constant width; mtext: the width of its box"),
                            ["center"] = pt, ["radius"] = Num(),
                            ["start_angle"] = Num("arc: in degrees, counterclockwise from the X axis"),
                            ["end_angle"] = Num("arc: in degrees"),
                            ["position"] = pt,
                            ["text"] = Str("text, mtext: the text (mtext codes such as \\P allowed)"),
                            ["height"] = Num("text, mtext: the height of the text"),
                            ["rotation"] = Num("text, mtext, insert: in degrees"),
                            ["style"] = Str("text, mtext: a text style of the drawing"),
                            ["justify"] = Str("text: Left, Center, Right, Middle, MiddleCenter, TopLeft... (default Left); mtext: TopLeft, MiddleCenter... (default TopLeft)"),
                            ["block"] = Str("insert: the name of a block defined in the drawing"),
                            ["scale"] = Num("insert: its scale; hatch: the scale of its pattern"),
                            ["attributes"] = new Dictionary<string, object> { ["type"] = "object", ["description"] = "insert: the values of its attributes, by tag" },
                            ["boundary"] = Arr(Str(), "hatch: the handles of closed curves that bound it (instead of points)"),
                            ["pattern"] = Str("hatch: the pattern (SOLID, ANSI31, AR-B816...)"),
                            ["angle"] = Num("hatch: the angle of the pattern, in degrees"),
                        }, "type"), "The objects to create"),
                    }, "items")),
                Tool("modify_entities", "Changes objects given by their handles, all in one change the user approves first and undoes with one U (500 objects at most): their layer, color, linetype or lineweight; moves, rotates or scales them; changes the text of a text or mtext, or the attributes of a block.",
                    Obj(new Dictionary<string, object>
                    {
                        ["items"] = Arr(Obj(new Dictionary<string, object>
                        {
                            ["handle"] = Str(),
                            ["layer"] = Str("A layer that exists"),
                            ["color"] = Str("1-255, ByLayer, ByBlock or r,g,b"),
                            ["linetype"] = Str("A linetype loaded, ByLayer or ByBlock"),
                            ["lineweight"] = Str("In hundredths of a mm (25 for 0.25 mm), ByLayer or ByBlock"),
                            ["move"] = Arr(Num(), "[dx, dy] or [dx, dy, dz]"),
                            ["rotate"] = Obj(new Dictionary<string, object> { ["base"] = pt, ["angle"] = Num("In degrees, counterclockwise") }, "base", "angle"),
                            ["scale"] = Obj(new Dictionary<string, object> { ["base"] = pt, ["factor"] = Num() }, "base", "factor"),
                            ["text"] = Str("The new text of a text or mtext"),
                            ["attributes"] = new Dictionary<string, object> { ["type"] = "object", ["description"] = "The new values of the attributes of a block, by tag" },
                        }, "handle"), "The changes, one item per object"),
                    }, "items")),
                Tool("erase_entities", "Erases objects given by their handles, in one change the user approves first and undoes with one U (500 objects at most).",
                    Obj(new Dictionary<string, object> { ["handles"] = handles }, "handles")),
                Tool("set_layers", "Creates layers, changes their properties, or makes one current, in one change the user approves first and undoes with one U. A layer that does not exist is created.",
                    Obj(new Dictionary<string, object>
                    {
                        ["layers"] = Arr(Obj(new Dictionary<string, object>
                        {
                            ["name"] = Str(),
                            ["color"] = Str("1-255 or r,g,b"),
                            ["linetype"] = Str("A linetype, loaded from acad.lin or acadiso.lin when it is not in the drawing"),
                            ["lineweight"] = Str("In hundredths of a mm (25 for 0.25 mm), or Default"),
                            ["description"] = Str(),
                            ["on"] = Bool(), ["frozen"] = Bool(), ["locked"] = Bool(), ["plot"] = Bool(),
                            ["current"] = Bool("Make it the current layer"),
                        }, "name"), "The layers"),
                    }, "layers")),
                Tool("run_command", "Runs one AutoCAD command with all its answers, in the active drawing, after the user approves it (every time); one U undoes it. Give the command by its international name and each keyword with _ (\"_.ZOOM\", \"_E\"), the command-line version of a command that opens a window (\"_.-LAYER\", \"_.-HATCH\", \"_.-INSERT\"), points as \"x,y\", and \"\" for Enter. Every answer the command asks must be given: the user finishes a command left waiting. Commands that leave the drawing (files, scripts, programs, closing AutoCAD) are refused.",
                    Obj(new Dictionary<string, object>
                    {
                        ["command"] = Arr(Str(), "The command, then its answers in order: [\"_.CHPROP\", \"2F1\", \"\", \"_C\", \"1\", \"\"]"),
                    }, "command")),

                Tool("approve", "Asks the user to approve a change of the drawing (called by Claude Code before a tool that writes).",
                    Obj(new Dictionary<string, object>
                    {
                        ["tool_name"] = Str(), ["input"] = new Dictionary<string, object> { ["type"] = "object" }, ["tool_use_id"] = Str(),
                    }, "tool_name", "input")),
            };
            return l;
        }

        static Dictionary<string, object> Tool(string name, string description, Dictionary<string, object> schema) =>
            new Dictionary<string, object> { ["name"] = name, ["description"] = description, ["inputSchema"] = schema };

        static Dictionary<string, object> Obj(Dictionary<string, object> props = null, params string[] required)
        {
            var o = new Dictionary<string, object> { ["type"] = "object", ["properties"] = props ?? new Dictionary<string, object>() };
            if (required.Length > 0) o["required"] = required.ToList<object>();
            return o;
        }

        static Dictionary<string, object> Typed(string type, string description)
        {
            var o = new Dictionary<string, object> { ["type"] = type };
            if (description != null) o["description"] = description;
            return o;
        }

        static Dictionary<string, object> Str(string d = null) => Typed("string", d);
        static Dictionary<string, object> Num(string d = null) => Typed("number", d);
        static Dictionary<string, object> Int(string d = null) => Typed("integer", d);
        static Dictionary<string, object> Bool(string d = null) => Typed("boolean", d);
        static Dictionary<string, object> Arr(object items, string d = null)
        {
            var o = Typed("array", d);
            o["items"] = items;
            return o;
        }

        // ---- the calls --------------------------------------------------------------

        public static string Call(string name, Dictionary<string, object> a, string useId)
        {
            switch (name)
            {
                case "drawing_info": return Host.Read(DrawingInfo);
                case "get_selection": return GetSelection();
                case "list_objects": return Host.Read((d, t) => ListObjects(d, t, a));
                case "get_object": return Host.Read((d, t) => GetObject(d, t, a));
                case "list_layers": return Host.Read((d, t) => ListLayers(d, t, a));
                case "list_blocks": return Host.Read((d, t) => ListBlocks(d, t, a));
                case "approve": return Approve(a);
                default:
                    if (Writes.Contains(name)) return Write(name, a, useId);
                    throw new ToolError("Unknown tool: " + name);
            }
        }

        // ---- reading ----------------------------------------------------------------

        static string DrawingInfo(Document doc, Transaction tr)
        {
            var db = doc.Database;
            var space = (BlockTableRecord)tr.GetObject(db.CurrentSpaceId, OpenMode.ForRead);
            var counts = new SortedDictionary<string, int>();
            int total = 0;
            foreach (ObjectId id in space)
            {
                var t = id.ObjectClass.DxfName;
                counts[t] = counts.TryGetValue(t, out var n) ? n + 1 : 1;
                total++;
            }
            var layouts = new List<object>();
            var ld = (DBDictionary)tr.GetObject(db.LayoutDictionaryId, OpenMode.ForRead);
            foreach (DBDictionaryEntry e in ld) layouts.Add(e.Key);
            var o = new Dictionary<string, object>
            {
                ["name"] = System.IO.Path.GetFileName(doc.Name),
                ["path"] = doc.Name,
                ["modified"] = Sys("DBMOD") is short m && m != 0,
                ["insunits"] = UnitName(db.Insunits),
                ["measurement"] = db.Measurement == MeasurementValue.Metric ? "Metric" : "Imperial",
                ["lunits"] = db.Lunits,
                ["annotation_scale"] = db.Cannoscale?.Name,
                ["current_layer"] = Name(tr, db.Clayer),
                ["current_layout"] = Convert.ToString(Sys("CTAB"), CultureInfo.InvariantCulture),
                ["current_space"] = space.Name == BlockTableRecord.ModelSpace ? "Model" : "Paper",
                ["layouts"] = layouts,
                ["extents"] = new List<object> { R(db.Extmin.X), R(db.Extmin.Y), R(db.Extmax.X), R(db.Extmax.Y) },
                ["objects"] = total,
                ["objects_by_type"] = counts.ToDictionary(kv => kv.Key, kv => (object)kv.Value),
            };
            return Json.Write(o);
        }

        static string GetSelection()
        {
            var ids = Host.OnMain(() =>
            {
                var doc = Host.Doc();
                try
                {
                    var r = doc.Editor.SelectImplied();
                    if (r.Status == PromptStatus.OK && r.Value != null && r.Value.Count > 0) return r.Value.GetObjectIds();
                }
                catch { }
                return Selection.Of(doc);
            });
            return Host.Read((doc, tr) =>
            {
                var counts = new SortedDictionary<string, int>();
                var list = new List<object>();
                foreach (var id in ids ?? new ObjectId[0])
                {
                    if (id.IsErased || id.Database != doc.Database) continue;
                    var t = id.ObjectClass.DxfName;
                    counts[t] = counts.TryGetValue(t, out var n) ? n + 1 : 1;
                    if (list.Count < Page && tr.GetObject(id, OpenMode.ForRead) is Entity e)
                        list.Add(new Dictionary<string, object> { ["handle"] = H(id), ["type"] = t, ["layer"] = e.Layer });
                }
                return Json.Write(new Dictionary<string, object>
                {
                    ["count"] = counts.Values.Sum(),
                    ["by_type"] = counts.ToDictionary(kv => kv.Key, kv => (object)kv.Value),
                    ["objects"] = list,
                    ["note"] = counts.Count == 0 ? "Nothing is selected: ask the user to select the objects (before asking), or use list_objects." : null,
                });
            });
        }

        static string ListObjects(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var db = doc.Database;
            var space = SpaceOf(db, tr, Json.Text(a, "space"));
            var types = Wild(Json.Text(a, "types"));
            var layers = Wild(Json.Text(a, "layers"));
            var w = Nums(Json.Get(a, "window"));
            if (w != null && w.Length < 4) throw new ToolError("window: [xmin, ymin, xmax, ymax]");
            int offset = Math.Max(0, IntOf(a, "offset", 0));
            int limit = Math.Max(1, Math.Min(Page, IntOf(a, "limit", 100)));
            var btr = (BlockTableRecord)tr.GetObject(space, OpenMode.ForRead);
            var list = new List<object>();
            int found = 0;
            foreach (ObjectId id in btr)
            {
                var t = id.ObjectClass.DxfName;
                if (types != null && !types.IsMatch(t)) continue;
                if (!(tr.GetObject(id, OpenMode.ForRead) is Entity e)) continue;
                if (layers != null && !layers.IsMatch(e.Layer)) continue;
                var box = Box(e);
                if (w != null && (box == null || box[2] < Math.Min(w[0], w[2]) || box[0] > Math.Max(w[0], w[2])
                                  || box[3] < Math.Min(w[1], w[3]) || box[1] > Math.Max(w[1], w[3]))) continue;
                if (found >= offset && list.Count < limit)
                    list.Add(new Dictionary<string, object>
                    {
                        ["handle"] = H(id), ["type"] = t, ["layer"] = e.Layer,
                        ["box"] = box?.Select(v => (object)R(v)).ToList(),
                    });
                found++;
            }
            return Json.Write(new Dictionary<string, object>
            {
                ["space"] = btr.Name, ["total"] = found, ["offset"] = offset, ["objects"] = list,
                ["more"] = offset + list.Count < found,
            });
        }

        static string GetObject(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var hs = Strings(Json.Get(a, "handles"));
            if (hs.Count == 0) throw new ToolError("handles: give at least one handle.");
            if (hs.Count > 50) throw new ToolError("handles: 50 at most a call.");
            var list = new List<object>();
            foreach (var h in hs)
            {
                var id = Id(doc.Database, h);
                if (id.IsNull || id.IsErased) { list.Add(new Dictionary<string, object> { ["handle"] = h, ["error"] = "no such object" }); continue; }
                list.Add(Describe(tr.GetObject(id, OpenMode.ForRead), tr));
            }
            return Json.Write(new Dictionary<string, object> { ["objects"] = list });
        }

        static string ListLayers(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var db = doc.Database;
            var names = Wild(Json.Text(a, "names"));
            int offset = Math.Max(0, IntOf(a, "offset", 0));
            var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
            var all = new List<LayerTableRecord>();
            foreach (ObjectId id in lt)
            {
                var r = (LayerTableRecord)tr.GetObject(id, OpenMode.ForRead);
                if (names == null || names.IsMatch(r.Name)) all.Add(r);
            }
            var list = all.OrderBy(r => r.Name, StringComparer.OrdinalIgnoreCase).Skip(offset).Take(Page).Select(r => (object)new Dictionary<string, object>
            {
                ["name"] = r.Name,
                ["current"] = r.ObjectId == db.Clayer ? (object)true : null,
                ["color"] = ColorText(r.Color),
                ["linetype"] = Name(tr, r.LinetypeObjectId),
                ["lineweight"] = Weight(r.LineWeight),
                ["on"] = !r.IsOff, ["frozen"] = r.IsFrozen, ["locked"] = r.IsLocked, ["plot"] = r.IsPlottable,
                ["description"] = string.IsNullOrEmpty(r.Description) ? null : r.Description,
                ["xref"] = r.IsDependent ? (object)true : null,
            }).ToList();
            return Json.Write(new Dictionary<string, object> { ["total"] = all.Count, ["offset"] = offset, ["layers"] = list, ["more"] = offset + list.Count < all.Count });
        }

        static string ListBlocks(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var db = doc.Database;
            var names = Wild(Json.Text(a, "names"));
            int offset = Math.Max(0, IntOf(a, "offset", 0));
            var bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForRead);
            var all = new List<BlockTableRecord>();
            foreach (ObjectId id in bt)
            {
                var b = (BlockTableRecord)tr.GetObject(id, OpenMode.ForRead);
                if (b.IsLayout) continue;
                if (names == null ? b.IsAnonymous : !names.IsMatch(b.Name)) continue;
                all.Add(b);
            }
            var list = new List<object>();
            foreach (var b in all.OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase).Skip(offset).Take(Page))
            {
                var atts = new List<object>();
                foreach (ObjectId id in b)
                    if (id.ObjectClass.DxfName == "ATTDEF" && tr.GetObject(id, OpenMode.ForRead) is AttributeDefinition ad)
                        atts.Add(new Dictionary<string, object> { ["tag"] = ad.Tag, ["prompt"] = ad.Prompt, ["default"] = ad.TextString, ["constant"] = ad.Constant ? (object)true : null });
                int refs = b.GetBlockReferenceIds(true, false).Count;
                if (b.IsDynamicBlock)
                    foreach (ObjectId an in b.GetAnonymousBlockIds())
                        refs += ((BlockTableRecord)tr.GetObject(an, OpenMode.ForRead)).GetBlockReferenceIds(true, false).Count;
                list.Add(new Dictionary<string, object>
                {
                    ["name"] = b.Name,
                    ["dynamic"] = b.IsDynamicBlock ? (object)true : null,
                    ["xref"] = b.IsFromExternalReference ? b.PathName : null,
                    ["description"] = string.IsNullOrEmpty(b.Comments) ? null : b.Comments,
                    ["inserted"] = refs,
                    ["attributes"] = atts.Count > 0 ? atts : null,
                });
            }
            return Json.Write(new Dictionary<string, object> { ["total"] = all.Count, ["offset"] = offset, ["blocks"] = list, ["more"] = offset + list.Count < all.Count });
        }

        // Everything a tool can tell of one object.
        static Dictionary<string, object> Describe(DBObject o, Transaction tr)
        {
            var d = new Dictionary<string, object> { ["handle"] = o.Handle.ToString(), ["type"] = o.ObjectId.ObjectClass.DxfName };
            if (!(o is Entity e)) return d;
            d["layer"] = e.Layer;
            d["color"] = ColorText(e.Color);
            d["linetype"] = e.Linetype;
            d["lineweight"] = Weight(e.LineWeight);
            var box = Box(e);
            if (box != null) d["box"] = box.Select(v => (object)R(v)).ToList();
            switch (e)
            {
                case Line ln:
                    d["start"] = P(ln.StartPoint); d["end"] = P(ln.EndPoint);
                    d["length"] = R(ln.Length); d["angle"] = Deg(ln.Angle);
                    break;
                case Polyline pl:
                    var vs = new List<object>();
                    var bulges = new List<object>();
                    bool anyBulge = false;
                    for (int i = 0; i < pl.NumberOfVertices && i < Page; i++)
                    {
                        vs.Add(P2(pl.GetPoint2dAt(i)));
                        var bu = pl.GetBulgeAt(i);
                        bulges.Add(R(bu));
                        if (bu != 0) anyBulge = true;
                    }
                    d["closed"] = pl.Closed; d["vertices"] = vs;
                    if (anyBulge) d["bulges"] = bulges;
                    if (pl.NumberOfVertices > Page) d["vertices_total"] = pl.NumberOfVertices;
                    if (pl.ConstantWidth != 0) d["width"] = R(pl.ConstantWidth);
                    d["elevation"] = pl.Elevation != 0 ? (object)R(pl.Elevation) : null;
                    d["length"] = R(pl.Length);
                    if (pl.Closed) d["area"] = R(pl.Area);
                    break;
                case Polyline2d p2:
                    d["vertices"] = Vertices(p2, tr); d["closed"] = p2.Closed; d["length"] = R(p2.Length);
                    break;
                case Polyline3d p3:
                    d["vertices"] = Vertices(p3, tr); d["closed"] = p3.Closed; d["length"] = R(p3.Length);
                    break;
                case Circle c:
                    d["center"] = P(c.Center); d["radius"] = R(c.Radius); d["area"] = R(c.Area);
                    break;
                case Arc ar:
                    d["center"] = P(ar.Center); d["radius"] = R(ar.Radius);
                    d["start_angle"] = Deg(ar.StartAngle); d["end_angle"] = Deg(ar.EndAngle);
                    d["start"] = P(ar.StartPoint); d["end"] = P(ar.EndPoint); d["length"] = R(ar.Length);
                    break;
                case Ellipse el:
                    d["center"] = P(el.Center); d["major_axis"] = P(el.MajorAxis); d["radius_ratio"] = R(el.RadiusRatio);
                    break;
                case Spline sp:
                    d["degree"] = sp.Degree; d["closed"] = sp.Closed; d["control_points"] = sp.NumControlPoints; d["fit_points"] = sp.NumFitPoints;
                    d["start"] = P(sp.StartPoint); d["end"] = P(sp.EndPoint);
                    break;
                case DBPoint dp:
                    d["position"] = P(dp.Position);
                    break;
                case AttributeReference atr:
                    d["tag"] = atr.Tag; d["text"] = atr.TextString;
                    break;
                case DBText t:
                    d["text"] = t.TextString; d["position"] = P(t.Position); d["height"] = R(t.Height);
                    d["rotation"] = Deg(t.Rotation); d["style"] = t.TextStyleName; d["justify"] = t.Justify.ToString();
                    if (t.Justify != AttachmentPoint.BaseLeft) d["alignment_point"] = P(t.AlignmentPoint);
                    break;
                case MText mt:
                    d["text"] = mt.Contents; d["plain_text"] = mt.Text; d["position"] = P(mt.Location);
                    d["height"] = R(mt.TextHeight); d["width"] = R(mt.Width); d["rotation"] = Deg(mt.Rotation);
                    d["style"] = mt.TextStyleName; d["attachment"] = mt.Attachment.ToString();
                    break;
                case Dimension dm:
                    d["measurement"] = R(dm.Measurement); d["text_override"] = dm.DimensionText; d["style"] = dm.DimensionStyleName;
                    break;
                case MLeader ml:
                    if (ml.ContentType == ContentType.MTextContent && ml.MText != null) d["text"] = ml.MText.Contents;
                    break;
                case BlockReference br:
                    var def = (BlockTableRecord)tr.GetObject(br.IsDynamicBlock ? br.DynamicBlockTableRecord : br.BlockTableRecord, OpenMode.ForRead);
                    d["block"] = def.Name; d["position"] = P(br.Position);
                    d["scale"] = P(new Point3d(br.ScaleFactors.X, br.ScaleFactors.Y, br.ScaleFactors.Z));
                    d["rotation"] = Deg(br.Rotation);
                    var atts = new Dictionary<string, object>();
                    foreach (ObjectId aid in br.AttributeCollection)
                        if (tr.GetObject(aid, OpenMode.ForRead) is AttributeReference ar2) atts[ar2.Tag] = ar2.TextString;
                    if (atts.Count > 0) d["attributes"] = atts;
                    if (br.IsDynamicBlock)
                    {
                        var props = new Dictionary<string, object>();
                        foreach (DynamicBlockReferenceProperty p in br.DynamicBlockReferencePropertyCollection)
                            if (p.PropertyName != "Origin") props[p.PropertyName] = p.Value is double dv ? R(dv) : (object)Convert.ToString(p.Value, CultureInfo.InvariantCulture);
                        if (props.Count > 0) d["dynamic_properties"] = props;
                    }
                    break;
                case Hatch hh:
                    d["pattern"] = hh.PatternName; d["scale"] = R(hh.PatternScale); d["angle"] = Deg(hh.PatternAngle);
                    d["associative"] = hh.Associative;
                    try { d["area"] = R(hh.Area); } catch { }
                    var loops = new List<object>();
                    for (int i = 0; i < hh.NumberOfLoops && i < 20; i++)
                    {
                        var lp = hh.GetLoopAt(i);
                        var pts = new List<object>();
                        if (lp.IsPolyline)
                            foreach (BulgeVertex bv in lp.Polyline) { if (pts.Count < Page) pts.Add(P2(bv.Vertex)); }
                        else
                            foreach (Curve2d c2 in lp.Curves) { if (pts.Count < Page) pts.Add(P2(c2.StartPoint)); }
                        loops.Add(new Dictionary<string, object> { ["outer"] = (lp.LoopType & HatchLoopTypes.External) != 0, ["points"] = pts });
                    }
                    d["loops"] = loops;
                    break;
                case Region rg:
                    d["area"] = R(rg.Area);
                    break;
            }
            // the DynALisp data of the object: Material=..., Role=...
            var xd = e.GetXDataForApplication("DYNALISP");
            if (xd != null)
            {
                var tags = new Dictionary<string, object>();
                foreach (TypedValue tv in xd)
                    if (tv.TypeCode == (int)DxfCode.ExtendedDataAsciiString && tv.Value is string s)
                    {
                        int k = s.IndexOf('=');
                        if (k > 0) tags[s.Substring(0, k)] = s.Substring(k + 1);
                    }
                xd.Dispose();
                if (tags.Count > 0) d["dynalisp"] = tags;
            }
            return d;
        }

        static List<object> Vertices(Curve pl, Transaction tr)
        {
            var l = new List<object>();
            foreach (ObjectId vid in (System.Collections.IEnumerable)pl)
            {
                if (l.Count >= Page) break;
                if (tr.GetObject(vid, OpenMode.ForRead) is Vertex2d v2) l.Add(P(v2.Position));
                else if (tr.GetObject(vid, OpenMode.ForRead) is PolylineVertex3d v3) l.Add(P(v3.Position));
            }
            return l;
        }

        // ---- helpers ----------------------------------------------------------------

        static object Sys(string name)
        {
            try { return AcApp.GetSystemVariable(name); } catch { return null; }
        }

        internal static double R(double v) => double.IsNaN(v) || double.IsInfinity(v) ? 0 : Math.Round(v, 6);
        static double Deg(double rad) => R(rad * 180 / Math.PI);
        static List<object> P(Point3d p) => p.Z == 0 ? new List<object> { R(p.X), R(p.Y) } : new List<object> { R(p.X), R(p.Y), R(p.Z) };
        static List<object> P(Vector3d v) => P(new Point3d(v.X, v.Y, v.Z));
        static List<object> P2(Point2d p) => new List<object> { R(p.X), R(p.Y) };

        internal static string H(ObjectId id) => id.Handle.ToString();

        static double[] Box(Entity e)
        {
            try
            {
                var x = e.GeometricExtents;
                return new[] { x.MinPoint.X, x.MinPoint.Y, x.MaxPoint.X, x.MaxPoint.Y };
            }
            catch { return null; }
        }

        internal static ObjectId Id(Database db, string h)
        {
            try
            {
                var hd = new Handle(long.Parse((h ?? "").Trim(), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                return db.TryGetObjectId(hd, out var id) ? id : ObjectId.Null;
            }
            catch { return ObjectId.Null; }
        }

        static string Name(Transaction tr, ObjectId id)
        {
            try { return id.IsNull ? null : (tr.GetObject(id, OpenMode.ForRead) as SymbolTableRecord)?.Name; }
            catch { return null; }
        }

        internal static object ColorText(Color c)
        {
            if (c == null) return null;
            if (c.IsByLayer) return "ByLayer";
            if (c.IsByBlock) return "ByBlock";
            if (c.IsByAci) return (int)c.ColorIndex;
            return c.Red + "," + c.Green + "," + c.Blue;
        }

        static object Weight(LineWeight w)
        {
            switch (w)
            {
                case LineWeight.ByLayer: return "ByLayer";
                case LineWeight.ByBlock: return "ByBlock";
                case LineWeight.ByLineWeightDefault: return "Default";
                default: return (int)w;
            }
        }

        static string UnitName(UnitsValue u) => u.ToString();

        static ObjectId SpaceOf(Database db, Transaction tr, string space)
        {
            if (string.IsNullOrEmpty(space) || space.Equals("current", StringComparison.OrdinalIgnoreCase)) return db.CurrentSpaceId;
            var bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForRead);
            if (space.Equals("model", StringComparison.OrdinalIgnoreCase)) return bt[BlockTableRecord.ModelSpace];
            var ld = (DBDictionary)tr.GetObject(db.LayoutDictionaryId, OpenMode.ForRead);
            foreach (DBDictionaryEntry e in ld)
                if (e.Key.Equals(space, StringComparison.OrdinalIgnoreCase))
                    return ((Layout)tr.GetObject(e.Value, OpenMode.ForRead)).BlockTableRecordId;
            throw new ToolError("space: no layout named " + space + ".");
        }

        // "LINE,*TEXT" -> a pattern, the * and ? of AutoCAD, the case ignored; null when empty.
        internal static Regex Wild(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return null;
            var parts = s.Split(',').Select(p => p.Trim()).Where(p => p != "")
                .Select(p => Regex.Escape(p).Replace("\\*", ".*").Replace("\\?", "."));
            return new Regex("^(" + string.Join("|", parts) + ")$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        }

        internal static List<string> Strings(object v) =>
            v is List<object> l ? l.Select(x => Convert.ToString(x, CultureInfo.InvariantCulture)).Where(x => !string.IsNullOrWhiteSpace(x)).ToList()
            : v is string s && s.Trim() != "" ? s.Split(',', ' ').Where(x => x != "").ToList() : new List<string>();

        internal static double[] Nums(object v)
        {
            if (!(v is List<object> l) || l.Count == 0) return null;
            try { return l.Select(x => Convert.ToDouble(x, CultureInfo.InvariantCulture)).ToArray(); }
            catch { throw new ToolError("A list of numbers was expected: " + Json.Write(v)); }
        }

        static int IntOf(Dictionary<string, object> a, string k, int def)
        {
            var v = Json.Get(a, k);
            if (v == null) return def;
            try { return Convert.ToInt32(v, CultureInfo.InvariantCulture); } catch { return def; }
        }
    }

    // The selection of each drawing, kept as it changes: the palette has the focus when Claude
    // asks for it, and SelectImplied may then give nothing.
    static class Selection
    {
        static readonly Dictionary<Document, ObjectId[]> _sel = new Dictionary<Document, ObjectId[]>();
        static bool _on;

        public static void Watch()
        {
            if (_on) return;
            _on = true;
            var dm = AcApp.DocumentManager;
            foreach (Document d in dm) Add(d);
            dm.DocumentCreated += (s, e) => Add(e.Document);
            dm.DocumentToBeDestroyed += (s, e) => { lock (_sel) _sel.Remove(e.Document); };
        }

        static void Add(Document d)
        {
            if (d == null) return;
            d.ImpliedSelectionChanged += (s, e) =>
            {
                ObjectId[] ids = null;
                try
                {
                    var r = d.Editor.SelectImplied();
                    if (r.Status == PromptStatus.OK && r.Value != null) ids = r.Value.GetObjectIds();
                }
                catch { }
                lock (_sel) _sel[d] = ids;
            };
        }

        public static ObjectId[] Of(Document d)
        {
            lock (_sel) return _sel.TryGetValue(d, out var ids) ? ids : null;
        }
    }
}
