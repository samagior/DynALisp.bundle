// Materials.cs - DynALisp.Assistant: the tools that read what DynALisp knows, and the view
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
//   get_materials  the regions of a detail (the hatches and closed curves that carry their
//                  material, the DynALisp data of the objects, read here at any time) and
//                  their area, joined to the data of their materials (read by the Lisp side,
//                  Remote>>Dyl:AssistantMaterials: in the command context, so left out, and
//                  said, while a command runs)
//   get_assembly   an assembly of Quick Draw, its layers and data (Remote>>Dyl:AssistantAssembly)
//   list_presets   the presets, materials, hatch presets, layer keys and assemblies, filtered
//                  and a page at a time here (Remote>>Dyl:AssistantPresets, ...Assemblies)
//   capture_view   a picture of the current view (Document.CapturePreviewImage), as an image
//                  of the answer of the tool, with the extent of the view in drawing units

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;

namespace DynALisp.Assistant
{
    static partial class Tools
    {
        const string TagTypes = "HATCH,LWPOLYLINE,POLYLINE,CIRCLE,ELLIPSE,SPLINE";

        // ---- get_materials ----------------------------------------------------------

        static string GetMaterials(Dictionary<string, object> a)
        {
            var sel = Host.OnMain(() => Selection.Of(Host.Doc()));
            var found = Host.Read((doc, tr) => Regions(doc, tr, a, sel));
            var ids = ((List<object>)found["regions"])
                .Select(r => ((Dictionary<string, object>)r).TryGetValue("material", out var m) ? m as string : null)
                .Where(m => !string.IsNullOrEmpty(m)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            if (ids.Count > 0)
            {
                try
                {
                    var v = Host.LispRead("Materials", ids) as Dictionary<string, object>;
                    if (v != null)
                    {
                        found["materials"] = Json.Get(v, "materials");
                        found["material_units"] = Json.Get(v, "units");
                    }
                }
                catch (ToolError e)
                {
                    found["materials"] = null;
                    found["materials_note"] = "The data of the materials could not be read: " + e.Message;
                }
            }
            return Json.Write(found);
        }

        // The regions: the objects of handles, else of the selection, else of the space; the
        // hatches and closed curves only, those with a material or a role unless untagged.
        static Dictionary<string, object> Regions(Document doc, Transaction tr, Dictionary<string, object> a, ObjectId[] sel)
        {
            var db = doc.Database;
            var hs = Strings(Json.Get(a, "handles"));
            IEnumerable<ObjectId> ids;
            string from;
            if (hs.Count > 0) { ids = hs.Select(h => Id(db, h)).Where(i => !i.IsNull); from = "handles"; }
            else if (sel != null && sel.Length > 0 && !(Json.Get(a, "space") is string)) { ids = sel; from = "selection"; }
            else
            {
                var btr = (BlockTableRecord)tr.GetObject(SpaceOf(db, tr, Json.Text(a, "space")), OpenMode.ForRead);
                ids = btr.Cast<ObjectId>();
                from = "space";
            }
            bool untagged = Json.Get(a, "untagged") is bool u ? u : from != "space";
            var w = Nums(Json.Get(a, "window"));
            if (w != null && w.Length < 4) throw new ToolError("window: [xmin, ymin, xmax, ymax]");
            int offset = Math.Max(0, IntOf(a, "offset", 0));
            double m = UnitMetres(db);
            var types = Wild(TagTypes);
            var list = new List<object>();
            var byMat = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
            int total = 0, without = 0;
            foreach (var id in ids)
            {
                if (id.IsErased || id.Database != db || !types.IsMatch(id.ObjectClass.DxfName)) continue;
                if (!(tr.GetObject(id, OpenMode.ForRead) is Entity e)) continue;
                double? area = null;
                if (e is Hatch h) { try { area = h.Area; } catch { } }
                else if (e is Curve c)
                {
                    if (!c.Closed && !(c.StartPoint.DistanceTo(c.EndPoint) < 1e-9)) continue;
                    try { area = c.Area; } catch { }
                }
                var tags = Tags(e);
                tags.TryGetValue("Material", out var mat);
                if (!untagged && mat == null && !tags.ContainsKey("Role")) continue;
                if (w != null)
                {
                    var b = Box(e);
                    if (b == null || b[2] < w[0] || b[0] > w[2] || b[3] < w[1] || b[1] > w[3]) continue;
                }
                total++;
                if (mat == null && !tags.ContainsKey("Role")) without++;
                if (mat != null && area.HasValue) byMat[mat] = (byMat.TryGetValue(mat, out var s) ? s : 0) + area.Value;
                if (total <= offset || list.Count >= Page) continue;
                var r = new Dictionary<string, object>
                {
                    ["handle"] = H(id),
                    ["type"] = id.ObjectClass.DxfName,
                    ["layer"] = e.Layer,
                    ["material"] = mat,
                    ["area"] = area.HasValue ? (object)R(area.Value) : null,
                    ["area_m2"] = area.HasValue ? (object)R(area.Value * m * m) : null,
                    ["box"] = Box(e)?.Select(x => (object)R(x)).ToList(),
                };
                foreach (var kv in tags)
                    if (kv.Key != "Material" && kv.Key != "Format") r[kv.Key.ToLowerInvariant()] = kv.Value;
                list.Add(r);
            }
            return new Dictionary<string, object>
            {
                ["from"] = from,
                ["count"] = total,
                ["offset"] = offset,
                ["next_offset"] = offset + list.Count < total ? (object)(offset + list.Count) : null,
                ["metres_per_drawing_unit"] = m,
                ["without_material"] = without,
                ["area_by_material"] = byMat.ToDictionary(kv => kv.Key, kv => (object)R(kv.Value)),
                ["regions"] = list,
                ["note"] = total == 0
                    ? (from == "space" ? "No hatch or closed curve of this space carries a material: give untagged true to list them all." : "None of these objects is a hatch or a closed curve.")
                    : without > 0 ? without + " of them carry no material: a simulation refuses them (Pst-MaterialAssign gives one, or dynalisp_action assign_material)." : null,
            };
        }

        // The DynALisp data of the object: Material=..., Role=... (extended data DYNALISP).
        static Dictionary<string, string> Tags(Entity e)
        {
            var tags = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var xd = e.GetXDataForApplication("DYNALISP");
            if (xd == null) return tags;
            using (xd)
                foreach (TypedValue tv in xd)
                    if (tv.TypeCode == (int)DxfCode.ExtendedDataAsciiString && tv.Value is string s)
                    {
                        int k = s.IndexOf('=');
                        if (k > 0) tags[s.Substring(0, k)] = s.Substring(k + 1);
                    }
            return tags;
        }

        // The metres of a drawing unit, as Remote>>Dyl:MaterialUnitMetres (INSUNITS, else
        // MEASUREMENT: millimetres or inches).
        static double UnitMetres(Database db)
        {
            switch (db.Insunits)
            {
                case UnitsValue.Inches: return 0.0254;
                case UnitsValue.Feet: return 0.3048;
                case UnitsValue.Millimeters: return 0.001;
                case UnitsValue.Centimeters: return 0.01;
                case UnitsValue.Meters: return 1.0;
                default: return db.Measurement == MeasurementValue.Metric ? 0.001 : 0.0254;
            }
        }

        // ---- get_assembly, list_presets ---------------------------------------------

        static string GetAssembly(Dictionary<string, object> a)
        {
            var id = Json.Text(a, "id");
            if (string.IsNullOrWhiteSpace(id)) throw new ToolError("id: give the id of an assembly (list_presets, kind assemblies).");
            return Json.Write(Host.LispRead("Assembly", id.Trim()));
        }

        static readonly Dictionary<string, (string Op, string Kind, string Key)> Kinds = new Dictionary<string, (string, string, string)>
        {
            ["quick_draw"] = ("Presets", "QuickDraw", "presets"),
            ["quick_shape"] = ("Presets", "QuickShape", "presets"),
            ["materials"] = ("Presets", "Material", "materials"),
            ["hatch_presets"] = ("Presets", "HatchPreset", "hatch_presets"),
            ["layer_keys"] = ("Presets", "LayerKey", "layer_keys"),
            ["assemblies"] = ("Assemblies", null, "assemblies"),
        };

        static string ListPresets(Dictionary<string, object> a)
        {
            var kind = (Json.Text(a, "kind") ?? "").Trim().ToLowerInvariant();
            if (!Kinds.TryGetValue(kind, out var k)) throw new ToolError("kind: " + string.Join(", ", Kinds.Keys) + ".");
            var v = k.Kind == null ? Host.LispRead(k.Op) : Host.LispRead(k.Op, k.Kind);
            var all = (Json.Get(v, k.Key) as List<object>) ?? new List<object>();
            var words = (Json.Text(a, "search") ?? "").ToLowerInvariant().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            var group = Json.Text(a, "group");
            var hits = all.Where(x =>
            {
                if (!(x is Dictionary<string, object> d)) return false;
                if (!string.IsNullOrEmpty(group) && !string.Equals(Json.Text(d, "group"), group, StringComparison.OrdinalIgnoreCase)) return false;
                var text = string.Join(" ", d.Values.OfType<string>()).ToLowerInvariant();
                return words.All(text.Contains);
            }).ToList();
            int offset = Math.Max(0, IntOf(a, "offset", 0));
            var page = hits.Skip(offset).Take(Page).ToList();
            var o = new Dictionary<string, object>
            {
                ["kind"] = kind,
                ["count"] = hits.Count,
                ["offset"] = offset,
                ["next_offset"] = offset + page.Count < hits.Count ? (object)(offset + page.Count) : null,
                ["groups"] = all.OfType<Dictionary<string, object>>().Select(d => Json.Text(d, "group")).Where(g => !string.IsNullOrEmpty(g)).Distinct().ToList<object>(),
                [k.Key] = page,
            };
            if (v is Dictionary<string, object> vd && vd.TryGetValue("units", out var units)) o["units"] = units;
            return Json.Write(o);
        }

        // ---- capture_view -----------------------------------------------------------

        const int ViewMax = 1568;

        static object CaptureView(Dictionary<string, object> a)
        {
            int w = Math.Max(200, Math.Min(ViewMax, IntOf(a, "width", 1280)));
            return Host.OnMain(() =>
            {
                var doc = Host.Doc();
                var vr = doc.Editor.GetCurrentView();
                double vw = vr.Width, vh = vr.Height;
                int h = Math.Max(150, Math.Min(ViewMax, (int)Math.Round(w * (vh > 0 ? vh / vw : 0.75))));
                byte[] png;
                using (var bmp = doc.CapturePreviewImage((uint)w, (uint)h))
                using (var ms = new MemoryStream())
                {
                    bmp.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                    png = ms.ToArray();
                }
                // the view in the coordinates of the drawing: its centre (a plan view of the
                // world: the target plus the centre in the display), its size
                var c = new Point3d(vr.CenterPoint.X, vr.CenterPoint.Y, 0).TransformBy(
                    Matrix3d.PlaneToWorld(vr.ViewDirection).PreMultiplyBy(Matrix3d.Displacement(vr.Target - Point3d.Origin))
                        .PreMultiplyBy(Matrix3d.Rotation(-vr.ViewTwist, vr.ViewDirection, vr.Target)));
                var info = new Dictionary<string, object>
                {
                    ["drawing"] = Path.GetFileName(doc.Name),
                    ["space"] = Convert.ToString(Autodesk.AutoCAD.ApplicationServices.Application.GetSystemVariable("CTAB"), CultureInfo.InvariantCulture),
                    ["width_px"] = w, ["height_px"] = h,
                    ["view_center"] = new List<object> { R(c.X), R(c.Y) },
                    ["view_width"] = R(vw), ["view_height"] = R(vh),
                    ["drawing_units_per_pixel"] = R(vw / w),
                    ["plan_view"] = vr.ViewDirection.IsParallelTo(Vector3d.ZAxis) && Math.Abs(vr.ViewTwist) < 1e-9,
                    ["note"] = "A picture of the screen: the objects as they are drawn, not their data (use the other tools for those).",
                };
                return (object)new List<object>
                {
                    new Dictionary<string, object> { ["type"] = "image", ["data"] = Convert.ToBase64String(png), ["mimeType"] = "image/png" },
                    new Dictionary<string, object> { ["type"] = "text", ["text"] = Json.Write(info) },
                };
            });
        }
    }
}
