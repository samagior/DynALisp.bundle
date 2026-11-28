// Previews.cs - DynALisp.Windows: the pictures the user chose for the drawings of the Start page
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
// The Start page shows the preview a drawing keeps of itself, the view it was last saved in;
// right-click a drawing (a recent tile or a pin) to show another picture in its place:
//   - Choose preview picture...: an image file (PNG, JPEG, BMP, GIF, TIFF), copied; of
//     another shape than the pictures of the page (StartUi.PreviewAspect, 1.6), the part
//     to keep framed on it first (Res\Dyl-StartPagePreview.xaml, Engine\Frame.cs), so
//     every picture fills its frame;
//   - Set preview area...: the drawing opened, two corners picked in it, and the picture of
//     that area made at once and again after each save of the drawing (QSAVE, SAVE, SAVEAS),
//     while the drawing is on the layout of the area: its view zoomed to the area for the
//     picture and given back, the area widened to the shape of the pictures of the page;
//   - Use its own preview: the picture of DynALisp forgotten.
// A sheet set or a project pinned takes a picture too (not an area).
//
// What the user chose is theirs, kept on this computer only (CONVENTIONS.md, User Files):
// User\Start\Previews\<key>-<stamp>.png, a picture made at most 960 pixels wide or high, and
// User\Start\Previews.csv, a row per drawing, "Picture;Layout;Space;X1;Y1;X2;Y2;Drawing" (the
// drawing last: its path can hold a ;): the layout (Model, or a layout's name), the space of
// the area (Model, Paper, or Viewport: the model space of a viewport of a layout) and its
// corners in the world coordinates (WCS); the layout empty for a picture chosen. A new picture
// gets a new stamp, so the page reads it again (it keeps a picture by its file).

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Media.Imaging;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Windows.PreviewsLisp))]

namespace DynALisp.Windows
{
    static class Previews
    {
        const int MaxSide = 960;
        static readonly Encoding Utf8 = new UTF8Encoding(false);
        const string Head = "Picture;Layout;Space;X1;Y1;X2;Y2;Drawing";

        internal sealed class Row
        {
            public string Picture = "", Layout = "", Space = "", Drawing = "";
            public double X1, Y1, X2, Y2;
            public bool HasArea => Layout.Length > 0;
        }

        static string Dir => Path.Combine(Activity.Folder, "Previews");
        static string Index => Path.Combine(Activity.Folder, "Previews.csv");
        static readonly object Gate = new object();
        static DateTime _readTime;
        static long _readSize = -1;
        static Dictionary<string, Row> _rows = new Dictionary<string, Row>(StringComparer.OrdinalIgnoreCase);
        static string _fail, _lastMade;

        // ---- the index ----

        // The rows, read again when the file changed (read on the thread of the page too):
        static Dictionary<string, Row> Rows()
        {
            lock (Gate)
            {
                DateTime t = DateTime.MinValue;
                long size = -1;
                try { var fi = new FileInfo(Index); if (fi.Exists) { t = fi.LastWriteTimeUtc; size = fi.Length; } } catch { }
                if (t == _readTime && size == _readSize) return _rows;
                var rows = new Dictionary<string, Row>(StringComparer.OrdinalIgnoreCase);
                if (size >= 0)
                    try
                    {
                        using (var fs = new FileStream(Index, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                        using (var sr = new StreamReader(fs, Utf8))
                            foreach (var r in Parse(sr.ReadToEnd())) rows[r.Drawing] = r;
                    }
                    catch (System.Exception e) { _fail = "reading: " + e.Message; }
                _rows = rows;
                _readTime = t;
                _readSize = size;
                return rows;
            }
        }

        static List<Row> Parse(string text)
        {
            var rows = new List<Row>();
            foreach (var line in text.Split('\n'))
            {
                var f = line.TrimEnd('\r').Split(new[] { ';' }, 8);
                if (f.Length < 8 || f[0] == "Picture" || f[7].Length == 0) continue;
                var r = new Row { Picture = f[0], Layout = f[1], Space = f[2], Drawing = f[7] };
                double.TryParse(f[3], NumberStyles.Float, CultureInfo.InvariantCulture, out r.X1);
                double.TryParse(f[4], NumberStyles.Float, CultureInfo.InvariantCulture, out r.Y1);
                double.TryParse(f[5], NumberStyles.Float, CultureInfo.InvariantCulture, out r.X2);
                double.TryParse(f[6], NumberStyles.Float, CultureInfo.InvariantCulture, out r.Y2);
                rows.Add(r);
            }
            return rows;
        }

        static string N(double v) => v.ToString("R", CultureInfo.InvariantCulture);

        // The index changed under its lock (read again first: another AutoCAD may have written
        // it), the pictures no row names any more deleted:
        static void Change(Action<Dictionary<string, Row>> change)
        {
            lock (Gate)
            {
                Directory.CreateDirectory(Dir);
                using (var fs = Activity.Lock(Index))
                {
                    var rows = new Dictionary<string, Row>(StringComparer.OrdinalIgnoreCase);
                    foreach (var r in Parse(new StreamReader(fs, Utf8, false, 4096, true).ReadToEnd())) rows[r.Drawing] = r;
                    change(rows);
                    var sb = new StringBuilder(Head + "\r\n");
                    foreach (var r in rows.Values.OrderBy(r => r.Drawing, StringComparer.OrdinalIgnoreCase))
                        sb.Append(r.Picture).Append(';').Append(r.Layout).Append(';').Append(r.Space).Append(';')
                          .Append(N(r.X1)).Append(';').Append(N(r.Y1)).Append(';').Append(N(r.X2)).Append(';').Append(N(r.Y2)).Append(';')
                          .Append(r.Drawing).Append("\r\n");
                    var bytes = Utf8.GetBytes(sb.ToString());
                    fs.Position = 0;
                    fs.SetLength(0);
                    fs.Write(bytes, 0, bytes.Length);
                    var keep = new HashSet<string>(rows.Values.Select(r => r.Picture), StringComparer.OrdinalIgnoreCase);
                    try
                    {
                        foreach (var f in Directory.GetFiles(Dir, "*.png"))
                            if (!keep.Contains(Path.GetFileName(f))) try { File.Delete(f); } catch { }
                    }
                    catch { }
                }
                _readSize = -1;
            }
        }

        static string Key(string path)
        {
            using (var sha = System.Security.Cryptography.SHA1.Create())
                return BitConverter.ToString(sha.ComputeHash(Utf8.GetBytes(path.ToUpperInvariant()))).Replace("-", "").Substring(0, 16);
        }

        static string Full(string path)
        {
            try { return Path.GetFullPath(path); } catch { return path; }
        }

        // ---- for the Start page ----

        // The picture chosen for a drawing (a sheet set, a project), null when it has none:
        internal static string Of(string path)
        {
            if (!Rows().TryGetValue(Full(path), out var r) || r.Picture.Length == 0) return null;
            string png = Path.Combine(Dir, r.Picture);
            return File.Exists(png) ? png : null;
        }

        internal static bool Has(string path) => Of(path) != null || Rows().ContainsKey(Full(path));

        // An image file made the picture of a drawing: the part kept (crop, "x y width height"
        // in its pixels, given by the frame of Dyl-StartPagePreview.xaml; null: all of it, of
        // the shape of the page already), made a PNG of at most MaxSide:
        internal static void Choose(string path, string image, string crop)
        {
            BitmapSource src = StartUi.Picture(image) ?? throw new InvalidDataException("Not a picture: " + Path.GetFileName(image));
            var c = (crop ?? "").Split(' ');
            if (c.Length == 4 && c.All(x => int.TryParse(x, NumberStyles.Integer, CultureInfo.InvariantCulture, out _)))
            {
                var r = c.Select(x => int.Parse(x, CultureInfo.InvariantCulture)).ToArray();
                int x0 = Math.Max(0, Math.Min(src.PixelWidth - 1, r[0])), y0 = Math.Max(0, Math.Min(src.PixelHeight - 1, r[1]));
                src = new CroppedBitmap(src, new System.Windows.Int32Rect(x0, y0,
                    Math.Max(1, Math.Min(src.PixelWidth - x0, r[2])), Math.Max(1, Math.Min(src.PixelHeight - y0, r[3]))));
            }
            double scale = Math.Min(1.0, MaxSide / (double)Math.Max(src.PixelWidth, src.PixelHeight));
            if (scale < 1) src = new TransformedBitmap(src, new System.Windows.Media.ScaleTransform(scale, scale));
            var enc = new PngBitmapEncoder();
            enc.Frames.Add(BitmapFrame.Create(src));
            byte[] bytes;
            using (var ms = new MemoryStream()) { enc.Save(ms); bytes = ms.ToArray(); }
            Save(Full(path), bytes, null);
        }

        // The picture of a drawing written, with its area (null: a picture chosen, no area):
        static void Save(string path, byte[] png, Row area)
        {
            string name = Key(path) + "-" + DateTime.UtcNow.Ticks.ToString(CultureInfo.InvariantCulture) + ".png";
            Directory.CreateDirectory(Dir);
            File.WriteAllBytes(Path.Combine(Dir, name), png);
            Change(rows =>
            {
                var r = area ?? new Row();
                r.Drawing = path;
                r.Picture = name;
                rows[path] = r;
            });
            _lastMade = DateTime.Now.ToString("HH:mm:ss", CultureInfo.InvariantCulture);
        }

        // Its own preview again:
        internal static void Forget(string path)
        {
            string p = Full(path);
            Change(rows => rows.Remove(p));
        }

        // ---- the area, in AutoCAD ----

        // After each save of a drawing with an area, its picture made again (once AutoCAD is
        // idle: the save over, its view free to change), while the Start page is on:
        internal static void Init()
        {
            try
            {
                var dm = AcApp.DocumentManager;
                foreach (Document d in dm) Watch(d);
                dm.DocumentCreated += (s, e) => Watch(e.Document);
            }
            catch (System.Exception e) { _fail = e.Message; }
        }

        static void Watch(Document doc)
        {
            if (doc == null) return;
            doc.CommandEnded += (s, e) =>
            {
                string cmd = (e.GlobalCommandName ?? "").ToUpperInvariant();
                if (cmd != "QSAVE" && cmd != "SAVE" && cmd != "SAVEAS") return;
                if (StartPage.Env("DynalispStartPage") != "1") return;
                string name = null;
                try { name = doc.Name; } catch { }
                if (string.IsNullOrEmpty(name) || !Path.IsPathRooted(name)) return;
                if (!Rows().TryGetValue(Full(name), out var r) || !r.HasArea) return;
                EventHandler idle = null;
                idle = (a, b) =>
                {
                    AcApp.Idle -= idle;
                    try
                    {
                        if (!ReferenceEquals(AcApp.DocumentManager.MdiActiveDocument, doc)) return;
                        using (doc.LockDocument())
                            if (Make(doc, r, out string why)) StartPage.Reread();
                            else if (why != null) _fail = why;
                    }
                    catch (System.Exception ex) { _fail = "after a save: " + ex.Message; }
                };
                AcApp.Idle += idle;
            };
        }

        // The space the user is drawing in: Model; on a layout, Paper or Viewport (CVPORT 1 is
        // the paper space of the layout):
        static string SpaceNow(out string layout)
        {
            layout = Convert.ToString(AcApp.GetSystemVariable("CTAB"), CultureInfo.InvariantCulture) ?? "";
            if (Convert.ToInt32(AcApp.GetSystemVariable("TILEMODE"), CultureInfo.InvariantCulture) == 1) { layout = "Model"; return "Model"; }
            return Convert.ToInt32(AcApp.GetSystemVariable("CVPORT"), CultureInfo.InvariantCulture) == 1 ? "Paper" : "Viewport";
        }

        // The picture of the area of a drawing made and kept: its view zoomed to the area, the
        // picture taken (Capture, the size of the viewport, its area cut
        // out of it), the view given back. False, with why, when the drawing is not on the
        // layout and space of the area (made at its next save there).
        internal static bool Make(Document doc, Row area, out string why)
        {
            why = null;
            string space = SpaceNow(out string layout);
            if (!string.Equals(layout, area.Layout, StringComparison.OrdinalIgnoreCase) || space != area.Space)
                return false;
            var ed = doc.Editor;
            var before = ed.GetCurrentView();
            try
            {
                using (var view = ed.GetCurrentView())
                {
                    // the corners in the coordinates of the view (DCS):
                    var wcs2dcs = (Matrix3d.Rotation(-view.ViewTwist, view.ViewDirection, view.Target)
                                 * Matrix3d.Displacement(view.Target - Point3d.Origin)
                                 * Matrix3d.PlaneToWorld(view.ViewDirection)).Inverse();
                    var a = new Point3d(area.X1, area.Y1, 0).TransformBy(wcs2dcs);
                    var b = new Point3d(area.X2, area.Y2, 0).TransformBy(wcs2dcs);
                    double w = Math.Abs(b.X - a.X), h = Math.Abs(b.Y - a.Y);
                    if (w <= 0 && h <= 0) { why = "the area has no width or height"; return false; }
                    // widened about its middle to the shape of the pictures of the page, so its
                    // picture fills them (more of the drawing around it):
                    if (w < h * StartUi.PreviewAspect) w = h * StartUi.PreviewAspect;
                    else h = w / StartUi.PreviewAspect;
                    var screen = (Point2d)AcApp.GetSystemVariable("SCREENSIZE");
                    double aspect = screen.Y > 0 ? screen.X / screen.Y : 1.5;
                    // the view as wide as the area or as high (the viewport keeps its shape):
                    double vw = w, vh = h;
                    if (w / h > aspect) vh = w / aspect; else vw = h * aspect;
                    view.CenterPoint = new Point2d((a.X + b.X) / 2, (a.Y + b.Y) / 2);
                    view.Width = vw;
                    view.Height = vh;
                    ed.SetCurrentView(view);
                    AcApp.UpdateScreen();
                    double s = Math.Min(1.0, MaxSide / Math.Max(screen.X, screen.Y));
                    int pw = Math.Max(16, (int)Math.Round(screen.X * s)), ph = Math.Max(16, (int)Math.Round(screen.Y * s));
                    byte[] shot = Capture(doc, (uint)pw, (uint)ph);
                    if (shot == null) { why = "AutoCAD gave no picture"; return false; }
                    // the area cut out of the middle of the viewport:
                    var full = BitmapDecoder.Create(new MemoryStream(shot), BitmapCreateOptions.IgnoreColorProfile, BitmapCacheOption.OnLoad).Frames[0];
                    int cw = Math.Max(1, Math.Min(full.PixelWidth, (int)Math.Round(full.PixelWidth * w / vw)));
                    int ch = Math.Max(1, Math.Min(full.PixelHeight, (int)Math.Round(full.PixelHeight * h / vh)));
                    var cut = new CroppedBitmap(full, new System.Windows.Int32Rect((full.PixelWidth - cw) / 2, (full.PixelHeight - ch) / 2, cw, ch));
                    var enc = new PngBitmapEncoder();
                    enc.Frames.Add(BitmapFrame.Create(cut));
                    byte[] png;
                    using (var ms = new MemoryStream()) { enc.Save(ms); png = ms.ToArray(); }
                    Save(Full(doc.Name), png, area);
                    return true;
                }
            }
            finally
            {
                try { ed.SetCurrentView(before); } catch { }
                before.Dispose();
            }
        }

        // The picture of the current view of a drawing, as a PNG (Document.CapturePreviewImage
        // gives a System.Drawing.Bitmap: called by reflection, this DLL has no WinForms):
        static byte[] Capture(Document doc, uint width, uint height)
        {
            var m = typeof(Document).GetMethod("CapturePreviewImage", new[] { typeof(uint), typeof(uint) });
            if (m == null) return null;
            var bmp = m.Invoke(doc, new object[] { width, height }) as IDisposable;
            if (bmp == null) return null;
            using (bmp)
            {
                var t = bmp.GetType();
                var fmt = t.Assembly.GetType("System.Drawing.Imaging.ImageFormat")?.GetProperty("Png")?.GetValue(null);
                var save = fmt == null ? null : t.GetMethod("Save", new[] { typeof(Stream), fmt.GetType() });
                if (save == null) return null;
                using (var ms = new MemoryStream())
                {
                    save.Invoke(bmp, new[] { ms, fmt });
                    return ms.ToArray();
                }
            }
        }

        // The area picked in the current drawing (Set preview area... of the Start page, which
        // opens the drawing and runs (Dyl:StartPagePreviewArea)): two corners, kept, and its
        // picture made at once.
        internal static string Pick()
        {
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            if (doc == null) return "No drawing.";
            string name = doc.Name;
            if (string.IsNullOrEmpty(name) || !Path.IsPathRooted(name)) return "Save the drawing first: its preview is kept by its file.";
            var ed = doc.Editor;
            var p1 = ed.GetPoint(new PromptPointOptions("\nFirst corner of the preview area: "));
            if (p1.Status != PromptStatus.OK) return null;
            var p2 = ed.GetCorner(new PromptCornerOptions("\nOther corner: ", p1.Value));
            if (p2.Status != PromptStatus.OK) return null;
            var ucs = ed.CurrentUserCoordinateSystem;
            var a = p1.Value.TransformBy(ucs);
            var b = p2.Value.TransformBy(ucs);
            string space = SpaceNow(out string layout);
            var area = new Row
            {
                Layout = layout, Space = space,
                X1 = Math.Min(a.X, b.X), Y1 = Math.Min(a.Y, b.Y), X2 = Math.Max(a.X, b.X), Y2 = Math.Max(a.Y, b.Y),
            };
            if (!Make(doc, area, out string why)) return "Preview not made: " + (why ?? "the drawing changed of layout") + ".";
            StartPage.Reread();
            return "Preview area kept: its picture is shown on the Start page and made again each time the drawing is saved on the " + (layout == "Model" ? "Model tab" : "layout " + layout) + ".";
        }

        // For (Dyl:Activity), in Dyl-Diagnostics (no path of the user):
        internal static List<string> Report()
        {
            var r = new List<string>();
            try
            {
                var rows = Rows().Values.ToList();
                r.Add("previews chosen: " + rows.Count(x => !x.HasArea) + " picture(s), " + rows.Count(x => x.HasArea) + " area(s)"
                      + (_lastMade != null ? ", last made " + _lastMade : ""));
                int lost = rows.Count(x => x.Picture.Length == 0 || !File.Exists(Path.Combine(Dir, x.Picture)));
                if (lost > 0) r.Add("previews without their picture: " + lost);
            }
            catch (System.Exception e) { r.Add("previews: " + e.Message); }
            if (_fail != null) r.Add("previews error: " + _fail);
            return r;
        }
    }

    public class PreviewsLisp
    {
        // (Dyl:StartPagePreviewArea): the preview area of the current drawing picked (sent by
        // the Start page once the drawing is open), what was done said on the command line.
        [LispFunction("Dyl:StartPagePreviewArea")]
        public object Area(ResultBuffer args)
        {
            try
            {
                string msg = Previews.Pick();
                if (msg != null) AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n" + msg);
                return msg == null || msg.StartsWith("Preview area kept", StringComparison.Ordinal);
            }
            catch (System.Exception e)
            {
                AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\nPreview area: " + e.Message);
                return null;
            }
        }
    }
}
