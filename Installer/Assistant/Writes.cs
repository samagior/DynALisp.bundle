// Writes.cs - DynALisp.Assistant: the tools that change the drawing, and their approval
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
// Nothing changes the drawing without a click of the user:
//   1. Claude Code calls approve (--permission-prompt-tool) with the tool and its input;
//      approve checks the input, says in one sentence what it will do (Summary), and shows
//      the approval card of the palette (Allow, Deny, Allow for this chat), the objects it
//      changes highlighted in the drawing while the card is open. Allow for this chat answers
//      the next calls of the same tool without a card, until New chat; never for
//      run_command, asked every time.
//   2. approve keeps the drawing approved for that call (its tool_use_id) and answers
//      {"behavior":"allow","updatedInput":...} or {"behavior":"deny","message":...}.
//   3. the tool runs (its _meta gives the same tool_use_id), in the drawing approved only,
//      in one undo group (Host.Write): one U undoes it.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Colors;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Assistant
{
    static partial class Tools
    {
        const int MaxItems = 500;

        // The commands run_command refuses: they leave the drawing (files, programs, scripts),
        // close it, or would run code.
        static readonly HashSet<string> Refused = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "SHELL", "SH", "QUIT", "EXIT", "CLOSE", "CLOSEALL", "NETLOAD", "APPLOAD", "ARX", "SCRIPT", "RSCRIPT",
            "VLIDE", "VLISP", "VBAIDE", "VBARUN", "VBALOAD", "VBAMAN", "-VBARUN", "SAVE", "SAVEAS", "QSAVE", "SAVEALL",
            "WBLOCK", "-WBLOCK", "EXPORT", "-EXPORT", "EXPORTPDF", "PLOT", "-PLOT", "PUBLISH", "-PUBLISH", "ETRANSMIT",
            "OPEN", "NEW", "QNEW", "RECOVER", "AUDIT", "PURGE", "-PURGE", "BROWSER", "HYPERLINK", "OPTIONS", "CUI",
            "CUILOAD", "CUIUNLOAD", "MENU", "MENULOAD", "MENUUNLOAD", "SECURELOAD", "TRUSTEDPATHS", "ACTSTOP", "ACTRECORD",
            "ACTUSERMESSAGE", "LISP", "UNDO", "U", "REDO", "MREDO",
        };

        // tool_use_id -> the drawing approved for that call
        static readonly Dictionary<string, Document> _approved = new Dictionary<string, Document>();
        // the tools allowed for this chat (Allow for this chat), until New chat
        static readonly HashSet<string> _always = new HashSet<string>();

        public static void ForgetApprovals()
        {
            lock (_approved) { _approved.Clear(); _always.Clear(); }
        }

        // ---- approve ----------------------------------------------------------------

        static string Approve(Dictionary<string, object> a)
        {
            var full = Json.Text(a, "tool_name") ?? "";
            var input = Json.Get(a, "input") as Dictionary<string, object> ?? new Dictionary<string, object>();
            var useId = Json.Text(a, "tool_use_id");
            var tool = full.StartsWith(Prefix, StringComparison.Ordinal) ? full.Substring(Prefix.Length) : null;
            if (tool == null || !Writes.Contains(tool))
                return Deny("Only the tools of the drawing are allowed here.");
            Card card;
            try { card = Host.Read((doc, tr) => Summary(tool, input, doc, tr)); }
            catch (ToolError e) { return Deny(e.Message); }
            Document target = Host.OnMain(() => Host.Doc());
            bool always;
            lock (_approved) always = _always.Contains(tool);
            string answer = always ? "allow" : Palette.Ask(card);
            if (answer == "always" && tool != "run_command") { lock (_approved) _always.Add(tool); answer = "allow"; }
            else if (answer == "always") answer = "allow";
            if (answer != "allow") return Deny(answer == "busy" ? "The palette is not open: nothing was changed." : "The user refused this change. Do not try it again unless they ask.");
            lock (_approved) _approved[useId ?? ("tool:" + tool)] = target;
            return Json.Write(new Dictionary<string, object> { ["behavior"] = "allow", ["updatedInput"] = input });
        }

        static string Deny(string why) => Json.Write(new Dictionary<string, object> { ["behavior"] = "deny", ["message"] = why });

        // What the approval card shows: one sentence, the drawing, the objects highlighted, and
        // the command itself for run_command.
        public sealed class Card
        {
            public string Tool, Title, Drawing, Code;
            public List<ObjectId> Objects = new List<ObjectId>();
            public bool AllowAlways => Tool != "run_command";
        }

        static Card Summary(string tool, Dictionary<string, object> a, Document doc, Transaction tr)
        {
            var c = new Card { Tool = tool, Drawing = System.IO.Path.GetFileName(doc.Name) };
            var db = doc.Database;
            switch (tool)
            {
                case "create_entities":
                {
                    var items = Items(a, "items");
                    var kinds = items.GroupBy(i => (Json.Text(i, "type") ?? "?").ToLowerInvariant())
                        .Select(g => Count(g.Count(), Noun(g.Key)));
                    var layers = items.Select(i => Json.Text(i, "layer")).Where(l => !string.IsNullOrEmpty(l)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
                    c.Title = "Create " + Join(kinds) + (layers.Count == 1 ? " on " + layers[0] : layers.Count > 1 ? " on " + layers.Count + " layers" : "");
                    break;
                }
                case "modify_entities":
                {
                    var items = Items(a, "items");
                    var what = new List<string>();
                    foreach (var k in new[] { "layer", "color", "linetype", "lineweight", "move", "rotate", "scale", "text", "attributes" })
                        if (items.Any(i => i.ContainsKey(k))) what.Add(k == "move" ? "move" : k == "rotate" ? "rotate" : k == "scale" ? "scale" : k);
                    c.Title = "Change " + Count(items.Count, "object") + (what.Count > 0 ? ": " + string.Join(", ", what) : "");
                    foreach (var i in items) AddObject(c, db, Json.Text(i, "handle"));
                    break;
                }
                case "erase_entities":
                {
                    var hs = Strings(Json.Get(a, "handles"));
                    if (hs.Count == 0) throw new ToolError("handles: give at least one handle.");
                    if (hs.Count > MaxItems) throw new ToolError("handles: " + MaxItems + " at most a call.");
                    foreach (var h in hs) AddObject(c, db, h);
                    c.Title = "Erase " + Count(hs.Count, "object");
                    break;
                }
                case "set_layers":
                {
                    var items = Items(a, "layers");
                    var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
                    var made = items.Select(i => Json.Text(i, "name") ?? "").Where(n => !lt.Has(n)).ToList();
                    var changed = items.Count - made.Count;
                    var parts = new List<string>();
                    if (made.Count > 0) parts.Add("create " + (made.Count == 1 ? "layer " + made[0] : made.Count + " layers"));
                    if (changed > 0) parts.Add("change " + Count(changed, "layer"));
                    var cur = items.FirstOrDefault(i => Json.Get(i, "current") is bool b && b);
                    if (cur != null) parts.Add("make " + Json.Text(cur, "name") + " current");
                    var s = string.Join(", ", parts);
                    c.Title = s.Length > 0 ? char.ToUpperInvariant(s[0]) + s.Substring(1) : "Change layers";
                    break;
                }
                case "run_command":
                {
                    var cmd = CommandArgs(a);
                    c.Title = "Run the command " + cmd[0];
                    c.Code = string.Join(" ", cmd.Select(x => x == "" ? "\"\"" : x.Contains(" ") ? "\"" + x + "\"" : x));
                    break;
                }
            }
            return c;
        }

        static void AddObject(Card c, Database db, string h)
        {
            var id = Id(db, h);
            if (id.IsNull || id.IsErased) throw new ToolError("No object has the handle " + h + ".");
            if (c.Objects.Count < MaxItems) c.Objects.Add(id);
        }

        static string Noun(string type)
        {
            switch (type)
            {
                case "polyline": return "polyline";
                case "mtext": return "mtext";
                case "insert": return "block";
                case "hatch": return "hatch";
                default: return type;
            }
        }

        static string Count(int n, string noun) =>
            n + " " + (n == 1 ? noun : noun.EndsWith("ch", StringComparison.Ordinal) || noun.EndsWith("x", StringComparison.Ordinal) ? noun + "es" : noun + "s");

        static string Join(IEnumerable<string> parts)
        {
            var l = parts.ToList();
            return l.Count <= 1 ? string.Join("", l) : string.Join(", ", l.Take(l.Count - 1)) + " and " + l.Last();
        }

        static List<Dictionary<string, object>> Items(Dictionary<string, object> a, string key)
        {
            if (!(Json.Get(a, key) is List<object> l) || l.Count == 0) throw new ToolError(key + ": give at least one item.");
            if (l.Count > MaxItems) throw new ToolError(key + ": " + MaxItems + " at most a call.");
            var r = new List<Dictionary<string, object>>();
            foreach (var x in l)
                r.Add(x as Dictionary<string, object> ?? throw new ToolError(key + ": each item is an object."));
            return r;
        }

        static List<string> CommandArgs(Dictionary<string, object> a)
        {
            if (!(Json.Get(a, "command") is List<object> l) || l.Count == 0) throw new ToolError("command: give the command and its answers.");
            if (l.Count > 100) throw new ToolError("command: 100 answers at most.");
            var cmd = l.Select(x => x is double d ? d.ToString("R", CultureInfo.InvariantCulture) : Convert.ToString(x, CultureInfo.InvariantCulture) ?? "").ToList();
            var name = cmd[0].Trim().TrimStart('_', '.', '\'').TrimStart('_', '.');
            if (name == "" || cmd[0].Contains(" ")) throw new ToolError("command: its first item is the name of a command alone.");
            if (Refused.Contains(name)) throw new ToolError("The command " + name + " is not allowed to the Assistant: it leaves the drawing, or would undo work outside the change.");
            if (cmd.Any(x => x.TrimStart().StartsWith("(", StringComparison.Ordinal)))
                throw new ToolError("command: an answer that starts with ( would run AutoLISP, which the Assistant does not do.");
            return cmd;
        }

        // ---- the writes -------------------------------------------------------------

        static string Write(string tool, Dictionary<string, object> a, string useId)
        {
            Document doc;
            lock (_approved)
            {
                var key = useId != null && _approved.ContainsKey(useId) ? useId : "tool:" + tool;
                if (!_approved.TryGetValue(key, out doc))
                    throw new ToolError("This change was not approved by the user: nothing was changed.");
                _approved.Remove(key);
            }
            switch (tool)
            {
                case "create_entities": return Host.Write(doc, (d, tr) => Create(d, tr, a));
                case "modify_entities": return Host.Write(doc, (d, tr) => Modify(d, tr, a));
                case "erase_entities": return Host.Write(doc, (d, tr) => Erase(d, tr, a));
                case "set_layers": return Host.Write(doc, (d, tr) => SetLayers(d, tr, a));
                case "run_command": return RunCommand(doc, a);
            }
            throw new ToolError("Unknown tool: " + tool);
        }

        static string Create(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var db = doc.Database;
            var items = Items(a, "items");
            var space = (BlockTableRecord)tr.GetObject(db.CurrentSpaceId, OpenMode.ForWrite);
            var made = new List<object>();
            int n = 0;
            foreach (var i in items)
            {
                n++;
                try
                {
                    var type = (Json.Text(i, "type") ?? "").ToLowerInvariant();
                    if (type == "hatch") { made.Add(H(MakeHatch(db, tr, space, i))); continue; }
                    Entity e = MakeEntity(db, tr, type, i);
                    Common(db, tr, e, i);
                    space.AppendEntity(e);
                    tr.AddNewlyCreatedDBObject(e, true);
                    if (e is BlockReference br) AddAttributes(tr, br, i);
                    made.Add(H(e.ObjectId));
                }
                catch (ToolError e) { throw new ToolError("Item " + n + ": " + e.Message + " Nothing was created."); }
                catch (Exception e) { throw new ToolError("Item " + n + ": " + e.Message + " Nothing was created."); }
            }
            return Json.Write(new Dictionary<string, object> { ["created"] = made, ["note"] = "One U in AutoCAD undoes this change." });
        }

        static Entity MakeEntity(Database db, Transaction tr, string type, Dictionary<string, object> i)
        {
            switch (type)
            {
                case "line":
                    return new Line(Pt(i, "start"), Pt(i, "end"));
                case "polyline":
                {
                    var pts = Points(i, "points");
                    if (pts.Count < 2) throw new ToolError("points: a polyline has 2 vertices at least.");
                    var bulges = Nums(Json.Get(i, "bulges"));
                    var pl = new Polyline(pts.Count);
                    for (int k = 0; k < pts.Count; k++)
                        pl.AddVertexAt(k, new Point2d(pts[k].X, pts[k].Y), bulges != null && k < bulges.Length ? bulges[k] : 0, 0, 0);
                    pl.Closed = Json.Get(i, "closed") is bool b && b;
                    if (Json.Get(i, "width") != null) pl.ConstantWidth = NumOf(i, "width");
                    if (pts[0].Z != 0) pl.Elevation = pts[0].Z;
                    return pl;
                }
                case "circle":
                    return new Circle(Pt(i, "center"), Vector3d.ZAxis, Positive(i, "radius"));
                case "arc":
                    return new Arc(Pt(i, "center"), Positive(i, "radius"), Rad(NumOf(i, "start_angle")), Rad(NumOf(i, "end_angle")));
                case "point":
                    return new DBPoint(Pt(i, "position"));
                case "text":
                {
                    var t = new DBText { TextString = Text(i), Height = Positive(i, "height"), Rotation = Rad(NumOr(i, "rotation", 0)) };
                    t.SetDatabaseDefaults(db);
                    Style(db, tr, i, id => t.TextStyleId = id);
                    var p = Pt(i, "position");
                    var j = TextJustify(Json.Text(i, "justify"));
                    t.Position = p;
                    if (j != AttachmentPoint.BaseLeft) { t.Justify = j; t.AlignmentPoint = p; }
                    return t;
                }
                case "mtext":
                {
                    var m = new MText();
                    m.SetDatabaseDefaults(db);
                    m.Location = Pt(i, "position");
                    m.Contents = Text(i);
                    m.TextHeight = Positive(i, "height");
                    if (Json.Get(i, "width") != null) m.Width = NumOf(i, "width");
                    m.Rotation = Rad(NumOr(i, "rotation", 0));
                    m.Attachment = MTextAttach(Json.Text(i, "justify"));
                    Style(db, tr, i, id => m.TextStyleId = id);
                    return m;
                }
                case "insert":
                {
                    var name = Json.Text(i, "block") ?? "";
                    var bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForRead);
                    if (!bt.Has(name)) throw new ToolError("No block named " + name + " in the drawing.");
                    var br = new BlockReference(Pt(i, "position"), bt[name]);
                    double s = NumOr(i, "scale", 1);
                    if (s == 0) throw new ToolError("scale: not 0.");
                    br.ScaleFactors = new Scale3d(s);
                    br.Rotation = Rad(NumOr(i, "rotation", 0));
                    return br;
                }
            }
            throw new ToolError("type: one of line, polyline, circle, arc, point, text, mtext, insert or hatch, not \"" + type + "\".");
        }

        static void AddAttributes(Transaction tr, BlockReference br, Dictionary<string, object> i)
        {
            var values = Json.Get(i, "attributes") as Dictionary<string, object>;
            var def = (BlockTableRecord)tr.GetObject(br.BlockTableRecord, OpenMode.ForRead);
            if (!def.HasAttributeDefinitions) return;
            foreach (ObjectId id in def)
            {
                if (!(tr.GetObject(id, OpenMode.ForRead) is AttributeDefinition ad) || ad.Constant) continue;
                var ar = new AttributeReference();
                ar.SetAttributeFromBlock(ad, br.BlockTransform);
                var v = values?.FirstOrDefault(kv => kv.Key.Equals(ad.Tag, StringComparison.OrdinalIgnoreCase)).Value;
                if (v != null) ar.TextString = Convert.ToString(v, CultureInfo.InvariantCulture);
                br.AttributeCollection.AppendAttribute(ar);
                tr.AddNewlyCreatedDBObject(ar, true);
            }
        }

        static ObjectId MakeHatch(Database db, Transaction tr, BlockTableRecord space, Dictionary<string, object> i)
        {
            var h = new Hatch();
            h.SetDatabaseDefaults(db);
            Common(db, tr, h, i);
            space.AppendEntity(h);
            tr.AddNewlyCreatedDBObject(h, true);
            var pattern = Json.Text(i, "pattern");
            if (string.IsNullOrEmpty(pattern)) pattern = "SOLID";
            h.PatternAngle = Rad(NumOr(i, "angle", 0));
            h.PatternScale = NumOr(i, "scale", 1);
            h.SetHatchPattern(HatchPatternType.PreDefined, pattern.ToUpperInvariant());
            var bound = Strings(Json.Get(i, "boundary"));
            if (bound.Count > 0)
            {
                var ids = new ObjectIdCollection();
                foreach (var hd in bound)
                {
                    var id = Id(db, hd);
                    if (id.IsNull || id.IsErased || !(tr.GetObject(id, OpenMode.ForRead) is Curve cv) || !cv.Closed)
                        throw new ToolError("boundary: " + hd + " is not a closed curve.");
                    ids.Add(id);
                }
                h.Associative = true;
                h.AppendLoop(HatchLoopTypes.Outermost, ids);
            }
            else
            {
                var pts = Points(i, "points");
                if (pts.Count < 3) throw new ToolError("A hatch needs boundary handles, or 3 points at least.");
                var vs = new Point2dCollection();
                var bs = new DoubleCollection();
                foreach (var p in pts) { vs.Add(new Point2d(p.X, p.Y)); bs.Add(0); }
                vs.Add(vs[0]);
                bs.Add(0);
                h.Associative = false;
                h.AppendLoop(HatchLoopTypes.Polyline | HatchLoopTypes.External, vs, bs);
            }
            h.EvaluateHatch(true);
            return h.ObjectId;
        }

        // The layer, color and linetype of an item, checked before anything is made.
        static void Common(Database db, Transaction tr, Entity e, Dictionary<string, object> i)
        {
            e.SetDatabaseDefaults(db);
            var layer = Json.Text(i, "layer");
            if (!string.IsNullOrEmpty(layer))
            {
                var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
                if (!lt.Has(layer)) throw new ToolError("The layer " + layer + " does not exist: create it with set_layers first.");
                e.Layer = layer;
            }
            var color = Json.Get(i, "color");
            if (color != null) e.Color = ColorOf(color);
            var ltype = Json.Text(i, "linetype");
            if (!string.IsNullOrEmpty(ltype)) e.Linetype = Linetype(db, tr, ltype);
        }

        static string Modify(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var db = doc.Database;
            var items = Items(a, "items");
            int n = 0;
            foreach (var i in items)
            {
                n++;
                var hd = Json.Text(i, "handle");
                try
                {
                    var id = Id(db, hd);
                    if (id.IsNull || id.IsErased) throw new ToolError("no object has the handle " + hd + ".");
                    if (!(tr.GetObject(id, OpenMode.ForWrite) is Entity e)) throw new ToolError(hd + " is not an object of the drawing.");
                    var layer = Json.Text(i, "layer");
                    if (!string.IsNullOrEmpty(layer))
                    {
                        var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
                        if (!lt.Has(layer)) throw new ToolError("the layer " + layer + " does not exist: create it with set_layers first.");
                        e.Layer = layer;
                    }
                    if (Json.Get(i, "color") != null) e.Color = ColorOf(Json.Get(i, "color"));
                    var ltype = Json.Text(i, "linetype");
                    if (!string.IsNullOrEmpty(ltype)) e.Linetype = Linetype(db, tr, ltype);
                    if (Json.Get(i, "lineweight") != null) e.LineWeight = WeightOf(Json.Get(i, "lineweight"), entity: true);
                    var mv = Nums(Json.Get(i, "move"));
                    if (mv != null)
                    {
                        if (mv.Length < 2) throw new ToolError("move: [dx, dy].");
                        e.TransformBy(Matrix3d.Displacement(new Vector3d(mv[0], mv[1], mv.Length > 2 ? mv[2] : 0)));
                    }
                    if (Json.Get(i, "rotate") is Dictionary<string, object> ro)
                        e.TransformBy(Matrix3d.Rotation(Rad(NumOf(ro, "angle")), Vector3d.ZAxis, Pt(ro, "base")));
                    if (Json.Get(i, "scale") is Dictionary<string, object> sc)
                    {
                        var f = NumOf(sc, "factor");
                        if (f <= 0) throw new ToolError("scale: a factor more than 0.");
                        e.TransformBy(Matrix3d.Scaling(f, Pt(sc, "base")));
                    }
                    var text = Json.Text(i, "text");
                    if (text != null)
                    {
                        if (e is MText mt) mt.Contents = text;
                        else if (e is DBText t) t.TextString = text;
                        else throw new ToolError("text: " + hd + " is not a text or an mtext.");
                    }
                    if (Json.Get(i, "attributes") is Dictionary<string, object> av)
                    {
                        if (!(e is BlockReference br)) throw new ToolError("attributes: " + hd + " is not a block.");
                        foreach (ObjectId aid in br.AttributeCollection)
                        {
                            var ar = (AttributeReference)tr.GetObject(aid, OpenMode.ForWrite);
                            var v = av.FirstOrDefault(kv => kv.Key.Equals(ar.Tag, StringComparison.OrdinalIgnoreCase)).Value;
                            if (v != null) ar.TextString = Convert.ToString(v, CultureInfo.InvariantCulture);
                        }
                    }
                }
                catch (Exception e) { throw new ToolError("Item " + n + " (" + hd + "): " + e.Message + " Nothing was changed."); }
            }
            return Json.Write(new Dictionary<string, object> { ["changed"] = items.Count, ["note"] = "One U in AutoCAD undoes this change." });
        }

        static string Erase(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var hs = Strings(Json.Get(a, "handles"));
            if (hs.Count > MaxItems) throw new ToolError("handles: " + MaxItems + " at most a call.");
            foreach (var hd in hs)
            {
                var id = Id(doc.Database, hd);
                if (id.IsNull || id.IsErased) throw new ToolError("No object has the handle " + hd + ": nothing was erased.");
                try { tr.GetObject(id, OpenMode.ForWrite).Erase(); }
                catch (Exception e) { throw new ToolError(hd + ": " + e.Message + " Nothing was erased."); }
            }
            return Json.Write(new Dictionary<string, object> { ["erased"] = hs.Count, ["note"] = "One U in AutoCAD undoes this change." });
        }

        static string SetLayers(Document doc, Transaction tr, Dictionary<string, object> a)
        {
            var db = doc.Database;
            var items = Items(a, "layers");
            var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
            var made = new List<object>();
            var changed = new List<object>();
            ObjectId current = ObjectId.Null;
            foreach (var i in items)
            {
                var name = (Json.Text(i, "name") ?? "").Trim();
                try { SymbolUtilityServices.ValidateSymbolName(name, false); }
                catch { throw new ToolError("\"" + name + "\" is not a valid layer name. Nothing was changed."); }
                LayerTableRecord r;
                if (lt.Has(name)) { r = (LayerTableRecord)tr.GetObject(lt[name], OpenMode.ForWrite); changed.Add(r.Name); }
                else
                {
                    r = new LayerTableRecord { Name = name };
                    if (!lt.IsWriteEnabled) lt.UpgradeOpen();
                    lt.Add(r);
                    tr.AddNewlyCreatedDBObject(r, true);
                    made.Add(name);
                }
                try
                {
                    if (Json.Get(i, "color") != null) r.Color = ColorOf(Json.Get(i, "color"));
                    var ltype = Json.Text(i, "linetype");
                    if (!string.IsNullOrEmpty(ltype)) r.LinetypeObjectId = LinetypeId(db, tr, ltype);
                    if (Json.Get(i, "lineweight") != null) r.LineWeight = WeightOf(Json.Get(i, "lineweight"), entity: false);
                    if (Json.Get(i, "description") is string ds) r.Description = ds;
                    if (Json.Get(i, "on") is bool on) r.IsOff = !on;
                    if (Json.Get(i, "locked") is bool lk) r.IsLocked = lk;
                    if (Json.Get(i, "plot") is bool pl) r.IsPlottable = pl;
                    bool cur = Json.Get(i, "current") is bool c && c;
                    if (Json.Get(i, "frozen") is bool fr)
                    {
                        if (fr && (cur || r.ObjectId == db.Clayer)) throw new ToolError("the current layer cannot be frozen.");
                        r.IsFrozen = fr;
                    }
                    if (cur)
                    {
                        if (r.IsFrozen) throw new ToolError("a frozen layer cannot be made current.");
                        current = r.ObjectId;
                    }
                }
                catch (Exception e) { throw new ToolError(name + ": " + e.Message + " Nothing was changed."); }
            }
            if (!current.IsNull) db.Clayer = current;
            return Json.Write(new Dictionary<string, object>
            {
                ["created"] = made, ["changed"] = changed,
                ["current"] = current.IsNull ? null : Name(tr, current),
                ["note"] = "One U in AutoCAD undoes this change.",
            });
        }

        static string RunCommand(Document doc, Dictionary<string, object> a)
        {
            var cmd = CommandArgs(a);
            return Host.WriteAsync(doc, async (d, ed) =>
            {
                await ed.CommandAsync(cmd.Cast<object>().ToArray());
                var still = Convert.ToString(AcApp.GetSystemVariable("CMDNAMES"), CultureInfo.InvariantCulture) ?? "";
                var name = cmd[0].Trim().TrimStart('_', '.', '\'').TrimStart('_', '.').ToUpperInvariant();
                return Json.Write(new Dictionary<string, object>
                {
                    ["ran"] = string.Join(" ", cmd),
                    ["still_waiting"] = still.ToUpperInvariant().Contains(name) ? (object)("The command " + name + " still waits for answers: the user can finish it.") : null,
                    ["note"] = "One U in AutoCAD undoes this command.",
                });
            });
        }

        // ---- values -----------------------------------------------------------------

        static double Rad(double deg) => deg * Math.PI / 180;

        static double NumOf(Dictionary<string, object> i, string k)
        {
            var v = Json.Get(i, k);
            if (v == null) throw new ToolError(k + ": a number is needed.");
            try { return Convert.ToDouble(v, CultureInfo.InvariantCulture); }
            catch { throw new ToolError(k + ": a number is needed, not " + Json.Write(v) + "."); }
        }

        static double NumOr(Dictionary<string, object> i, string k, double def) => Json.Get(i, k) == null ? def : NumOf(i, k);

        static double Positive(Dictionary<string, object> i, string k)
        {
            var v = NumOf(i, k);
            if (v <= 0) throw new ToolError(k + ": more than 0.");
            return v;
        }

        static Point3d Pt(Dictionary<string, object> i, string k)
        {
            var n = Nums(Json.Get(i, k));
            if (n == null || n.Length < 2) throw new ToolError(k + ": a point [x, y] is needed.");
            return new Point3d(n[0], n[1], n.Length > 2 ? n[2] : 0);
        }

        static List<Point3d> Points(Dictionary<string, object> i, string k)
        {
            if (!(Json.Get(i, k) is List<object> l)) throw new ToolError(k + ": a list of points [[x, y], ...] is needed.");
            return l.Select(p =>
            {
                var n = Nums(p);
                if (n == null || n.Length < 2) throw new ToolError(k + ": each point is [x, y].");
                return new Point3d(n[0], n[1], n.Length > 2 ? n[2] : 0);
            }).ToList();
        }

        static string Text(Dictionary<string, object> i)
        {
            var t = Json.Text(i, "text");
            if (string.IsNullOrEmpty(t)) throw new ToolError("text: the text is needed.");
            return t;
        }

        static Color ColorOf(object v)
        {
            var s = Convert.ToString(v, CultureInfo.InvariantCulture)?.Trim() ?? "";
            if (s.Equals("ByLayer", StringComparison.OrdinalIgnoreCase)) return Color.FromColorIndex(ColorMethod.ByLayer, 256);
            if (s.Equals("ByBlock", StringComparison.OrdinalIgnoreCase)) return Color.FromColorIndex(ColorMethod.ByBlock, 0);
            var p = s.Split(',');
            if (p.Length == 3 && p.All(x => byte.TryParse(x.Trim(), out _)))
                return Color.FromRgb(byte.Parse(p[0].Trim()), byte.Parse(p[1].Trim()), byte.Parse(p[2].Trim()));
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) && d >= 1 && d <= 255 && d == Math.Floor(d))
                return Color.FromColorIndex(ColorMethod.ByAci, (short)d);
            throw new ToolError("color: 1-255, ByLayer, ByBlock or r,g,b, not \"" + s + "\".");
        }

        static LineWeight WeightOf(object v, bool entity)
        {
            var s = Convert.ToString(v, CultureInfo.InvariantCulture)?.Trim() ?? "";
            if (entity && s.Equals("ByLayer", StringComparison.OrdinalIgnoreCase)) return LineWeight.ByLayer;
            if (entity && s.Equals("ByBlock", StringComparison.OrdinalIgnoreCase)) return LineWeight.ByBlock;
            if (s.Equals("Default", StringComparison.OrdinalIgnoreCase)) return LineWeight.ByLineWeightDefault;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var d))
            {
                var w = (int)Math.Round(d);
                if (Enum.IsDefined(typeof(LineWeight), w) && w >= 0) return (LineWeight)w;
            }
            throw new ToolError("lineweight: one of 0, 5, 9, 13, 15, 18, 20, 25, 30, 35, 40, 50, 53, 60, 70, 80, 90, 100, 106, 120, 140, 158, 200, 211" + (entity ? ", ByLayer, ByBlock" : "") + " or Default, not \"" + s + "\".");
        }

        static string Linetype(Database db, Transaction tr, string name)
        {
            if (name.Equals("ByLayer", StringComparison.OrdinalIgnoreCase)) return "ByLayer";
            if (name.Equals("ByBlock", StringComparison.OrdinalIgnoreCase)) return "ByBlock";
            var lt = (LinetypeTable)tr.GetObject(db.LinetypeTableId, OpenMode.ForRead);
            if (!lt.Has(name)) throw new ToolError("The linetype " + name + " is not loaded in the drawing: give it to a layer with set_layers, which loads it.");
            return name;
        }

        static ObjectId LinetypeId(Database db, Transaction tr, string name)
        {
            var lt = (LinetypeTable)tr.GetObject(db.LinetypeTableId, OpenMode.ForRead);
            if (!lt.Has(name))
            {
                try { db.LoadLineTypeFile(name, db.Measurement == MeasurementValue.Metric ? "acadiso.lin" : "acad.lin"); }
                catch { }
                lt = (LinetypeTable)tr.GetObject(db.LinetypeTableId, OpenMode.ForRead);
                if (!lt.Has(name)) throw new ToolError("the linetype " + name + " is neither in the drawing nor in " + (db.Measurement == MeasurementValue.Metric ? "acadiso.lin" : "acad.lin") + ".");
            }
            return lt[name];
        }

        static void Style(Database db, Transaction tr, Dictionary<string, object> i, Action<ObjectId> set)
        {
            var s = Json.Text(i, "style");
            if (string.IsNullOrEmpty(s)) return;
            var st = (TextStyleTable)tr.GetObject(db.TextStyleTableId, OpenMode.ForRead);
            if (!st.Has(s)) throw new ToolError("No text style named " + s + " in the drawing.");
            set(st[s]);
        }

        static AttachmentPoint TextJustify(string s)
        {
            switch ((s ?? "").Replace(" ", "").ToLowerInvariant())
            {
                case "": case "left": case "baseleft": return AttachmentPoint.BaseLeft;
                case "center": case "basecenter": return AttachmentPoint.BaseCenter;
                case "right": case "baseright": return AttachmentPoint.BaseRight;
                case "middle": case "middlecenter": return AttachmentPoint.MiddleCenter;
                case "middleleft": return AttachmentPoint.MiddleLeft;
                case "middleright": return AttachmentPoint.MiddleRight;
                case "topleft": return AttachmentPoint.TopLeft;
                case "topcenter": return AttachmentPoint.TopCenter;
                case "topright": return AttachmentPoint.TopRight;
                case "bottomleft": return AttachmentPoint.BottomLeft;
                case "bottomcenter": return AttachmentPoint.BottomCenter;
                case "bottomright": return AttachmentPoint.BottomRight;
            }
            throw new ToolError("justify: Left, Center, Right, Middle, TopLeft, MiddleCenter, BottomRight..., not \"" + s + "\".");
        }

        static AttachmentPoint MTextAttach(string s)
        {
            switch ((s ?? "").Replace(" ", "").ToLowerInvariant())
            {
                case "": case "topleft": return AttachmentPoint.TopLeft;
                case "topcenter": return AttachmentPoint.TopCenter;
                case "topright": return AttachmentPoint.TopRight;
                case "middleleft": return AttachmentPoint.MiddleLeft;
                case "middle": case "middlecenter": return AttachmentPoint.MiddleCenter;
                case "middleright": return AttachmentPoint.MiddleRight;
                case "bottomleft": return AttachmentPoint.BottomLeft;
                case "bottomcenter": return AttachmentPoint.BottomCenter;
                case "bottomright": return AttachmentPoint.BottomRight;
            }
            throw new ToolError("justify: TopLeft, TopCenter, MiddleCenter, BottomRight..., not \"" + s + "\".");
        }
    }
}
