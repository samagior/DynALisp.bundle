// Hatch.cs - DynALisp.Windows: the preview of a hatch, drawn from its pattern (.pat)
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
// A HatchTile shows a hatch as it plots: at its size on paper, 1:1 on the screen (a WPF
// unit is 1/96 in), from the line families of its pattern in its .pat file (angle, origin,
// offset, dashes). When fewer than about three repeats of the pattern fit in the tile (one
// brick of an elevation), it zooms out just enough and shows the scale it uses in a corner
// (1:100). Its Spec, given by the Lisp, is one band or the bands of an assembly side by
// side, divided by "*", the fields of a band by "?":
//
//   P?width?pattern?file?ppu?angle?scale   a hatch: its pattern, the .pat file defining it,
//                                          the inches on paper of one unit of the pattern,
//                                          its angle (degrees), the drawing scale it is
//                                          divided by (1 when it keeps its size on paper)
//   F?width                                a solid fill
//   S?width                                a space
//   L?0                                    a line between two bands
//   X?width                                a hatch preset missing (crossed out)
//   O                                      (first) the bands outlined: the border of the
//                                          preset, a line around the tile
//
// An AssemblyTile (Assembly.cs) draws the bands of an assembly the other way: one under the
// other, as a wall drawn in plan.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Media;

namespace DynALisp.Windows
{
    // One line family of a pattern, in the units of the pattern:
    public sealed class PatLine
    {
        public double Angle, X, Y, Dx, Dy;
        public double[] Dashes;
    }

    public static class Pat
    {
        static readonly Dictionary<string, Tuple<DateTime, List<PatLine>>> Cache = new Dictionary<string, Tuple<DateTime, List<PatLine>>>(StringComparer.OrdinalIgnoreCase);
        internal static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        // The families of the pattern name in the .pat file, nil when it is not there. Kept
        // while the file is not written again (a pattern rebuilt by Dyl-RebuildPat is read again):
        public static List<PatLine> Read(string file, string name)
        {
            if (string.IsNullOrEmpty(file) || string.IsNullOrEmpty(name)) return null;
            string key = file + "|" + name;
            lock (Cache)
            {
                DateTime stamp = DateTime.MinValue;
                try { if (File.Exists(file)) stamp = File.GetLastWriteTimeUtc(file); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
                if (Cache.TryGetValue(key, out var hit) && hit.Item1 == stamp) return hit.Item2;
                List<PatLine> res = null;
                try { if (stamp != DateTime.MinValue) res = Parse(File.ReadAllLines(file), name); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
                Cache[key] = Tuple.Create(stamp, res);
                return res;
            }
        }

        // *NAME[, description], then a family a line, up to the next *:
        public static List<PatLine> Parse(IEnumerable<string> lines, string name)
        {
            List<PatLine> res = null;
            foreach (var raw in lines)
            {
                string line = raw.Trim();
                if (line.StartsWith("*"))
                {
                    if (res != null) break;
                    int comma = line.IndexOf(',');
                    string n = (comma < 0 ? line.Substring(1) : line.Substring(1, comma - 1)).Trim();
                    if (string.Equals(n, name, StringComparison.OrdinalIgnoreCase)) res = new List<PatLine>();
                    continue;
                }
                if (res == null || line.Length == 0 || line.StartsWith(";")) continue;
                int semi = line.IndexOf(';');
                if (semi >= 0) line = line.Substring(0, semi);
                var v = new List<double>();
                foreach (var f in line.Split(','))
                    if (double.TryParse(f.Trim(), NumberStyles.Float, Inv, out double d)) v.Add(d);
                if (v.Count < 5) continue;
                res.Add(new PatLine { Angle = v[0], X = v[1], Y = v[2], Dx = v[3], Dy = v[4], Dashes = v.Skip(5).ToArray() });
            }
            return res;
        }

        // The size of one repeat of the pattern, in its units: its widest spacing between
        // lines (a course of bricks, the length of a brick by its joints). The dash periods
        // are left out: the dots of a stipple are far apart along their lines, but it reads
        // as a texture at any size:
        public static double Repeat(List<PatLine> fams)
        {
            double r = 0;
            foreach (var f in fams) r = Math.Max(r, Math.Abs(f.Dy));
            return r;
        }
    }

    public class HatchTile : FrameworkElement
    {
        public static readonly DependencyProperty SpecProperty = Reg("Spec", typeof(string), null);
        public static readonly DependencyProperty InkProperty = Reg("Ink", typeof(Brush), Brushes.Black);
        public static readonly DependencyProperty FillProperty = Reg("Fill", typeof(Brush), Brushes.Transparent);
        public static readonly DependencyProperty LabelBackProperty = Reg("LabelBack", typeof(Brush), Brushes.White);
        public static readonly DependencyProperty RadiusProperty = Reg("Radius", typeof(double), 5.0);
        public static readonly DependencyProperty ShowScaleProperty = Reg("ShowScale", typeof(bool), true);

        static DependencyProperty Reg(string n, Type t, object def) =>
            DependencyProperty.Register(n, t, typeof(HatchTile), new FrameworkPropertyMetadata(def, FrameworkPropertyMetadataOptions.AffectsRender));

        public string Spec { get => (string)GetValue(SpecProperty); set => SetValue(SpecProperty, value); }
        public Brush Ink { get => (Brush)GetValue(InkProperty); set => SetValue(InkProperty, value); }
        public Brush Fill { get => (Brush)GetValue(FillProperty); set => SetValue(FillProperty, value); }
        public Brush LabelBack { get => (Brush)GetValue(LabelBackProperty); set => SetValue(LabelBackProperty, value); }
        public double Radius { get => (double)GetValue(RadiusProperty); set => SetValue(RadiusProperty, value); }
        // The scale of a tile zoomed out in its corner (false: a thumbnail too small for it):
        public bool ShowScale { get => (bool)GetValue(ShowScaleProperty); set => SetValue(ShowScaleProperty, value); }

        internal const double Dpi = 96;       // WPF units an inch
        internal const double Repeats = 3;    // repeats of a pattern at least, in the height of the tile
        const int MaxLines = 20000;   // segments of a tile at most (a pattern too fine is grey)
        internal static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
        internal static readonly double[] Steps = { 1, 2, 2.5, 4, 5, 8, 10, 16, 20, 25, 40, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10000 };

        internal sealed class Band
        {
            public string Kind = "X", Pattern, File;
            public double Width, Ppu = 1, Angle, Scale = 1;
            public List<PatLine> Fams;
        }

        internal static double Num(string[] f, int i, double def) =>
            i < f.Length && double.TryParse(f[i], NumberStyles.Float, Inv, out double d) ? d : def;

        internal static List<Band> Bands(string spec)
        {
            var res = new List<Band>();
            foreach (var part in (spec ?? "").Split('*'))
            {
                var f = part.Split('?');
                if (f[0].Length == 0) continue;
                var b = new Band { Kind = f[0].Trim().ToUpperInvariant(), Width = Math.Max(0, Num(f, 1, 1)) };
                if (b.Kind == "P")
                {
                    b.Pattern = f.Length > 2 ? f[2] : null;
                    b.File = f.Length > 3 ? f[3] : null;
                    b.Ppu = Num(f, 4, 1);
                    b.Angle = Num(f, 5, 0);
                    b.Scale = Math.Max(1e-9, Num(f, 6, 1));
                    b.Fams = Pat.Read(b.File, b.Pattern);
                    if (b.Fams == null || b.Fams.Count == 0 || b.Ppu <= 0) b.Kind = "X";
                }
                res.Add(b);
            }
            return res;
        }

        protected override void OnRender(DrawingContext dc)
        {
            var r = new Rect(0, 0, ActualWidth, ActualHeight);
            if (r.Width < 2 || r.Height < 2) return;
            var bands = Bands(Spec);
            bool outline = bands.RemoveAll(b => b.Kind == "O") > 0;
            var pen = new Pen(Ink, 1) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round };
            pen.Freeze();
            dc.PushClip(new RectangleGeometry(r, Radius, Radius));
            dc.DrawRectangle(Fill, null, r);

            // One zoom for the tile: the least that shows every pattern Repeats times:
            double zoom = 1, scale = 1;
            foreach (var b in bands.Where(b => b.Kind == "P"))
            {
                double px = Pat.Repeat(b.Fams) * b.Ppu * Dpi;
                zoom = Math.Max(zoom, px * Repeats / r.Height);
                scale = Math.Max(scale, b.Scale);
            }
            zoom = Steps.FirstOrDefault(s => s >= zoom - 1e-9) is double z && z > 0 ? z : Math.Ceiling(zoom);

            // The bands side by side, as wide as their part of the total (3 units at least):
            var wide = bands.Where(b => b.Kind != "L").ToList();
            double tot = wide.Sum(b => b.Width);
            if (wide.Count == 0 || tot <= 0) { foreach (var b in wide) b.Width = 1; tot = Math.Max(1, wide.Count); }
            var ws = wide.Select(b => Math.Max(3.0, r.Width * b.Width / tot)).ToList();
            double fit = r.Width / ws.Sum();
            double x = 0;
            int i = 0;
            foreach (var b in bands)
            {
                if (b.Kind == "L")
                {
                    double lx = Math.Min(r.Width - 1, Math.Max(1, x));
                    dc.DrawLine(new Pen(Ink, 2), new Point(lx, 0), new Point(lx, r.Height));
                    continue;
                }
                double w = ws[i++] * fit;
                var br = new Rect(x, 0, w, r.Height);
                dc.PushClip(new RectangleGeometry(br));
                Draw(dc, br, b, zoom, pen);
                dc.Pop();
                if (x > 0) dc.DrawLine(pen, new Point(x, 0), new Point(x, r.Height));
                x += w;
            }
            // The border of the preset: a line around the tile, as thick as a line between
            // two bands (thinner in a thumbnail):
            if (outline)
            {
                double t = r.Height < 40 ? 1.5 : 2;
                var o = new Rect(t / 2, t / 2, Math.Max(0, r.Width - t), Math.Max(0, r.Height - t));
                dc.DrawRoundedRectangle(null, new Pen(Ink, t), o, Math.Max(0, Radius - t / 2), Math.Max(0, Radius - t / 2));
            }
            if (zoom > 1 && ShowScale) Label(dc, r, "1:" + (scale * zoom).ToString("0.##", Inv));
            dc.Pop();
        }

        internal void Draw(DrawingContext dc, Rect r, Band b, double zoom, Pen pen)
        {
            switch (b.Kind)
            {
                case "S": return;
                case "F":
                    dc.PushOpacity(0.45);
                    dc.DrawRectangle(Ink, null, r);
                    dc.Pop();
                    return;
                case "X":
                    var muted = new Pen(Ink, 1) { DashStyle = DashStyles.Dash };
                    dc.PushOpacity(0.5);
                    dc.DrawLine(muted, r.TopLeft, r.BottomRight);
                    dc.DrawLine(muted, r.BottomLeft, r.TopRight);
                    dc.Pop();
                    return;
            }
            double k = b.Ppu * Dpi / zoom;        // screen units a unit of the pattern
            double th = b.Angle * Math.PI / 180;
            double diag = Math.Sqrt(r.Width * r.Width + r.Height * r.Height);
            var c = new Point(r.X + r.Width / 2, r.Y + r.Height / 2);
            // The origin of the pattern at the bottom left of the tile, y up:
            double ox0 = 0, oy0 = ActualHeight;
            var g = new StreamGeometry();
            int count = 0;
            bool grey = false;
            using (var ctx = g.Open())
            {
                foreach (var f in b.Fams)
                {
                    double a = (f.Angle * Math.PI / 180) + th;
                    double ux = Math.Cos(a), uy = -Math.Sin(a);     // along the lines, on the screen
                    double vx = -Math.Sin(a), vy = -Math.Cos(a);    // across them (+90 degrees)
                    double px = f.X * Math.Cos(th) - f.Y * Math.Sin(th), py = f.X * Math.Sin(th) + f.Y * Math.Cos(th);
                    double ox = ox0 + px * k, oy = oy0 - py * k;
                    double dx = f.Dx * k, dy = f.Dy * k;
                    if (Math.Abs(dy) < 0.8) { grey = true; continue; }
                    double dist = (c.X - ox) * vx + (c.Y - oy) * vy;
                    int n0 = (int)Math.Floor((dist - diag) / dy), n1 = (int)Math.Ceiling((dist + diag) / dy);
                    if (n1 < n0) { int t = n0; n0 = n1; n1 = t; }
                    var dashes = f.Dashes.Select(d => d * k).ToArray();
                    double period = dashes.Sum(d => Math.Abs(d));
                    bool solid = dashes.Length == 0 || period < 1.0;
                    for (int n = n0; n <= n1; n++)
                    {
                        double bx = ox + n * (dx * ux + dy * vx), by = oy + n * (dx * uy + dy * vy);
                        double t0 = (c.X - bx) * ux + (c.Y - by) * uy - diag, t1 = t0 + 2 * diag;
                        if (solid)
                        {
                            Seg(ctx, bx, by, ux, uy, t0, t1);
                            if (++count > MaxLines) { grey = true; break; }
                            continue;
                        }
                        double t = Math.Floor(t0 / period) * period;
                        while (t < t1 && count <= MaxLines)
                            foreach (var d in dashes)
                            {
                                if (d >= 0 && t + Math.Max(d, 0.01) > t0) { Seg(ctx, bx, by, ux, uy, t, t + Math.Max(d, 0.01)); count++; }
                                t += Math.Abs(d);
                            }
                        if (count > MaxLines) { grey = true; break; }
                    }
                    if (count > MaxLines) break;
                }
            }
            g.Freeze();
            if (count <= MaxLines) dc.DrawGeometry(null, pen, g);
            // A pattern finer than the screen: grey, as it looks on paper:
            if (grey)
            {
                dc.PushOpacity(0.35);
                dc.DrawRectangle(Ink, null, r);
                dc.Pop();
            }
        }

        static void Seg(StreamGeometryContext ctx, double bx, double by, double ux, double uy, double t0, double t1)
        {
            ctx.BeginFigure(new Point(bx + ux * t0, by + uy * t0), false, false);
            ctx.LineTo(new Point(bx + ux * t1, by + uy * t1), true, false);
        }

        // The scale of a tile zoomed out, in its bottom right corner:
        internal void Label(DrawingContext dc, Rect r, string text)
        {
            var ft = LabelText(text);
            DrawLabel(dc, new Rect(r.Right - ft.Width - 12, r.Bottom - ft.Height - 7, ft.Width + 8, ft.Height + 2), ft);
        }

        // The label centred on x, its top at y (under the wall of an AssemblyTile):
        internal void Label(DrawingContext dc, double x, double y, string text)
        {
            var ft = LabelText(text);
            DrawLabel(dc, new Rect(x - ft.Width / 2 - 4, y, ft.Width + 8, ft.Height + 2), ft);
        }

        FormattedText LabelText(string text)
        {
            double ppd = 1;
            try { ppd = VisualTreeHelper.GetDpi(this).PixelsPerDip; } catch { }
            return new FormattedText(text, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight,
                new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.SemiBold, FontStretches.Normal), 10.5, Ink, ppd);
        }

        void DrawLabel(DrawingContext dc, Rect box, FormattedText ft)
        {
            dc.DrawRoundedRectangle(LabelBack, null, box, 3, 3);
            dc.DrawText(ft, new Point(box.X + 4, box.Y + 1));
        }
    }
}
