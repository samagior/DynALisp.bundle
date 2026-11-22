// Assembly.cs - DynALisp.Windows: the preview of an assembly, its layers one under the other
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
// An AssemblyTile shows an assembly as a wall drawn in plan: its line from left to right,
// its layers one under the other from its left border (at the top) to its right one, each
// hatched as its preset, ending at the right as it ends (Square, Open, Extended, Round,
// Angled). A layer with its own band settings ends across its own thickness; the others
// together, across the whole band. A layer with its own border is outlined in the accent
// colour; the layers selected in the list are tinted. It is drawn at a scale (1:20) that
// fits the wall in the tile, its hatches at the same scale, so their size against the
// thickness of the layers is as drawn. The wall is in the middle of the tile, its left
// side open (it goes on), the scale centred under it.
//
// It follows a list of rows (Rows.cs): the editor of the list named by Rows gives it its
// Spec each time the rows or the selection change, from these properties:
//
//   Rows      the key of the list (ll)
//   Columns   the columns of a row: kind, material, thickness, band settings on, ends,
//             extension, end angle, border on, hatch aligned to (Edge: the line of the layer
//             on its edge), structural, has a hatch ("0": drawn as a space, its border
//             kept), scale by width and width factor of its band settings (the hatch scaled
//             by the thickness: with Paper only) ("0 1 2 5 7 8 9 14 6 16 27 38 39")
//   Line      the key of the justification of the assembly (Center, Edge, Structural): the
//             line drawn, in the accent colour, in the middle of the band, on the border of
//             its first layer, or in the middle of its structural layer; what the Angled ends
//             of the band turn around
//   Specs     a list of the Lisp: the preview of each material (as HatchTile draws it), one
//             for each item of the field of the material column (its width replaced by the
//             thickness of the row; its ppu "w0.0005": the ppu of a unit of thickness, a
//             hatch scale from the thickness)
//   Ends      a list of the Lisp: the ends of the whole band (ends extension angle)
//   BorderLines    the key of a checkbox of the window: its lines along its first and last
//                  layers and across its ends drawn ("1", or no key), else not
//   DividingLines  the key of a checkbox of the window: its lines between two layers drawn
//                  ("1", or no key), else not (a layer with its own border is outlined all
//                  the same)
//   Paper     a list of the Lisp: the inches of a drawing unit (1, 1/25.4) and the drawing
//             scale (50); without it, the wall fills the tile and its hatches are drawn as
//             HatchTile draws them
//
// Spec: the bands divided by "*", each a band of HatchTile (P, F, S, L, X) then, divided by
// "~": its ends, extension ("": half its width), end angle (degrees), own ("1": across its
// own thickness), border ("1": its own border), selected ("1"), its own line (Edge: on its
// border nearer to the line of the band, else in its middle: what its Angled ends turn
// around), structural ("1": the structural layer).

using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Media;

namespace DynALisp.Windows
{
    public class AssemblyTile : HatchTile
    {
        public static readonly DependencyProperty AccentProperty = DependencyProperty.Register("Accent", typeof(Brush), typeof(AssemblyTile),
            new FrameworkPropertyMetadata(Brushes.SteelBlue, FrameworkPropertyMetadataOptions.AffectsRender));

        public Brush Accent { get => (Brush)GetValue(AccentProperty); set => SetValue(AccentProperty, value); }
        public string Rows { get; set; }
        public string Columns { get; set; } = "0 1 2 5 7 8 9 14 6 16";
        public string Line { get; set; }
        public string BorderLines { get; set; }
        public string DividingLines { get; set; }

        // Its border lines and dividing lines drawn (the values of BorderLines and
        // DividingLines), set by the editor:
        internal bool BorderOn = true, DividingOn = true;

        // The justification of the assembly (the value of Line), set by the editor:
        internal string Justify = "";
        public string Specs { get; set; }
        public string Ends { get; set; }
        public string Paper { get; set; }

        // The inches of a drawing unit and the drawing scale (0: not given), set by the editor:
        internal double Unit, DrawScale;

        // Where the wall starts on the left (its open side), on the screen:
        double _xs;

        sealed class Layer
        {
            public HatchTile.Band B;
            public string End = "Square";
            public double? Ext;
            public double Angle = 45;
            public bool Own, Border, Sel, Edge, Core;
            public double Top, Bottom;     // on the screen
            public double Reach;           // how far its end goes past the end of the line
        }

        static List<Layer> Parse(string spec)
        {
            var res = new List<Layer>();
            foreach (var part in (spec ?? "").Split('*'))
            {
                var f = part.Split('~');
                var bs = Bands(f[0]);
                if (bs.Count == 0) continue;
                var l = new Layer { B = bs[0] };
                if (f.Length > 1 && f[1].Trim().Length > 0) l.End = f[1].Trim();
                if (f.Length > 2 && double.TryParse(f[2], System.Globalization.NumberStyles.Float, Inv, out double e) && e >= 0) l.Ext = e;
                if (f.Length > 3 && double.TryParse(f[3], System.Globalization.NumberStyles.Float, Inv, out double a)) l.Angle = Math.Max(-80, Math.Min(80, a));
                l.Own = f.Length > 4 && f[4] == "1";
                l.Border = f.Length > 5 && f[5] == "1";
                l.Sel = f.Length > 6 && f[6] == "1";
                l.Edge = f.Length > 7 && f[7] == "Edge";
                l.Core = f.Length > 8 && f[8] == "1";
                res.Add(l);
            }
            return res;
        }

        protected override void OnRender(DrawingContext dc)
        {
            var r = new Rect(0, 0, ActualWidth, ActualHeight);
            if (r.Width < 20 || r.Height < 20) return;
            dc.PushClip(new RectangleGeometry(r, Radius, Radius));
            dc.DrawRectangle(Fill, null, r);
            var all = Parse(Spec);
            var wide = all.Where(l => l.B.Kind != "L").ToList();
            if (wide.Count == 0 || wide.Sum(l => l.B.Width) <= 0) { dc.Pop(); return; }

            // The wall in the middle of the tile, as far from its left and its right sides, its
            // scale under it (the room of the label kept, so the wall does not move with it):
            const double padY = 12, padX = 28, labelH = 20;
            double avail = r.Height - 2 * padY - (ShowScale ? labelH : 0);
            double tot = wide.Sum(l => l.B.Width);
            double zoom, label;
            bool real = Unit > 0 && DrawScale > 0;
            if (real)
            {
                // The scale that fits the wall in the tile (a step of Steps), the hatches at it:
                double paper = tot * Unit / DrawScale * Dpi;
                double s = DrawScale * paper / avail;
                label = Steps.FirstOrDefault(x => x >= s - 1e-9);
                if (label <= 0) label = Math.Ceiling(s);
                zoom = label / DrawScale;
            }
            else
            {
                zoom = 1;
                foreach (var l in wide.Where(l => l.B.Kind == "P"))
                    zoom = Math.Max(zoom, Pat.Repeat(l.B.Fams) * l.B.Ppu * Dpi * Repeats / avail);
                zoom = Steps.FirstOrDefault(x => x >= zoom - 1e-9) is double z && z > 0 ? z : Math.Ceiling(zoom);
                label = wide.Where(l => l.B.Kind == "P").Select(l => l.B.Scale).DefaultIfEmpty(1).Max() * zoom;
            }
            // The thickness of each layer on the screen (2 at least), the screen units a unit:
            double k = real ? Unit / DrawScale * Dpi / zoom : avail / tot;
            var hs = wide.Select(l => Math.Max(2.0, l.B.Width * k)).ToList();
            double h = hs.Sum();
            if (!real && h > avail) { hs = hs.Select(x => x * avail / h).ToList(); h = avail; }
            double y = padY + (avail - h) / 2, yc = y + h / 2;
            double yLabel = y + h + 6;
            for (int i = 0; i < wide.Count; i++) { wide[i].Top = y; y += hs[i]; wide[i].Bottom = y; }
            // The line drawn (Line): what the ends of the band turn around:
            var core = wide.FirstOrDefault(l => l.Core && l.B.Kind == "P");
            if (Justify == "Edge") yc = wide[0].Top;
            else if (Justify == "Structural" && core != null) yc = (core.Top + core.Bottom) / 2;

            // How far each end goes past the end of the line, so the longest one fits:
            // The whole band, ending as the layers without their own band settings (its Line
            // layers end with it):
            var whole = new Layer { Top = wide[0].Top, Bottom = wide[wide.Count - 1].Bottom, B = new HatchTile.Band { Width = tot } };
            var common = wide.FirstOrDefault(l => !l.Own);
            if (common != null) { whole.End = common.End; whole.Ext = common.Ext; whole.Angle = common.Angle; }
            foreach (var l in wide) l.Reach = Reach(l, whole, yc, k);
            double reach = Math.Min(r.Width * 0.3, wide.Max(l => l.Reach));
            _xs = padX;
            double x0 = r.Width - padX - reach;

            var pen = new Pen(Ink, 1) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round, LineJoin = PenLineJoin.Round };
            var accent = new Pen(Accent, 2) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round, LineJoin = PenLineJoin.Round };
            pen.Freeze();
            accent.Freeze();
            var shapes = wide.Select(l => Outline(l, whole, x0, yc, k, true)).ToList();

            // The hatches, each in its layer:
            for (int i = 0; i < wide.Count; i++)
            {
                var l = wide[i];
                // in pieces about as wide as tall, so a long thin layer is not drawn as grey
                // (HatchTile.Draw covers the circle around its box):
                dc.PushClip(shapes[i]);
                double lh = Math.Max(1, l.Bottom - l.Top), cw = Math.Max(120, 2 * lh);
                for (double cx = _xs; cx < r.Width; cx += cw)
                {
                    var box = new Rect(cx, l.Top, Math.Min(cw, r.Width - cx), lh);
                    dc.PushClip(new RectangleGeometry(box));
                    Draw(dc, box, l.B, zoom, pen);
                    dc.Pop();
                }
                dc.Pop();
                if (l.Sel)
                {
                    dc.PushOpacity(0.18);
                    dc.DrawGeometry(Accent, null, shapes[i]);
                    dc.Pop();
                }
            }
            // Their borders (the border lines: around the band, the dividing lines: between two
            // layers, each one when it is on), then the borders of their own over them:
            if (BorderOn)
            {
                // without the dividing lines: thin strips along the joins left out, to the end
                // of the shorter of the two layers (the rest is the border of the longer one)
                if (!DividingOn)
                {
                    var keep = new GeometryGroup { FillRule = FillRule.EvenOdd };
                    keep.Children.Add(new RectangleGeometry(r));
                    for (int i = 0; i + 1 < wide.Count; i++)
                    {
                        double jy = wide[i].Bottom;
                        double end = x0 + Math.Min(EndAt(wide[i], whole, jy, yc, k), EndAt(wide[i + 1], whole, jy, yc, k));
                        keep.Children.Add(new RectangleGeometry(new Rect(0, jy - 1.5, Math.Max(0, end - 0.5), 3)));
                    }
                    dc.PushClip(keep);
                }
                foreach (var l in wide) dc.DrawGeometry(null, pen, Outline(l, whole, x0, yc, k, false));
                if (!DividingOn) dc.Pop();
            }
            else if (DividingOn)
                for (int i = 0; i + 1 < wide.Count; i++)
                {
                    double jy = wide[i].Bottom;
                    dc.DrawLine(pen, new Point(_xs, jy), new Point(x0 + Math.Min(EndAt(wide[i], whole, jy, yc, k), EndAt(wide[i + 1], whole, jy, yc, k)), jy));
                }
            foreach (var l in wide.Where(l => l.Border)) dc.DrawGeometry(null, accent, Outline(l, whole, x0, yc, k, false));
            // The Line layers, between the layers they are after:
            int at = 0;
            var dash = new Pen(Ink, 2) { DashStyle = DashStyles.Dash };
            dash.Freeze();
            foreach (var l in all)
            {
                if (l.B.Kind != "L") { at++; continue; }
                double ly = at == 0 ? wide[0].Top : wide[Math.Min(at, wide.Count) - 1].Bottom;
                dc.DrawLine(dash, new Point(_xs, ly), new Point(x0 + EndAt(whole, whole, ly, yc, k), ly));
            }
            // The line drawn, to its end (Line given):
            if (Line != null)
            {
                var lp = new Pen(Accent, 1.5) { DashStyle = new DashStyle(new double[] { 8, 3, 1.5, 3 }, 0) };
                lp.Freeze();
                dc.DrawLine(lp, new Point(_xs, yc), new Point(x0, yc));
                dc.DrawEllipse(Accent, null, new Point(x0, yc), 3, 3);
            }
            if (Math.Abs(zoom - 1) > 1e-9 && ShowScale) Label(dc, (_xs + x0 + reach) / 2, yLabel, "1:" + label.ToString("0.##", Inv));
            dc.Pop();
        }

        // The ends of the layer l: its own (across its own thickness), else those of the band
        // (across the whole band w):
        Layer Across(Layer l, Layer w) => l.Own ? l : w;

        // How far past the end of the line the end of l reaches, on the screen:
        double Reach(Layer l, Layer w, double yc, double k)
        {
            var a = Across(l, w);
            switch (l.End)
            {
                case "Extended": return Ext(l, a, k);
                case "Round":
                    double c = (a.Top + a.Bottom) / 2, rr = (a.Bottom - a.Top) / 2;
                    double near = Math.Max(l.Top, Math.Min(l.Bottom, c));
                    return Math.Sqrt(Math.Max(0, rr * rr - (near - c) * (near - c)));
                case "Angled":
                    double t = Math.Tan(l.Angle * Math.PI / 180), yl = Pivot(l, yc);
                    return Math.Max(0, Math.Max((yl - l.Top) * t, (yl - l.Bottom) * t));
                default: return 0;
            }
        }

        // The line an Angled end turns around: that of the band (yc), or the own line of a
        // layer with its own band settings: its middle, or its border nearer to yc (Edge):
        static double Pivot(Layer l, double yc)
        {
            if (!l.Own) return yc;
            double mid = (l.Top + l.Bottom) / 2;
            if (!l.Edge) return mid;
            return Math.Abs(l.Top - yc) < Math.Abs(l.Bottom - yc) ? l.Top : l.Bottom;
        }

        // The extension of Extended (half the width across which it ends when it has none):
        static double Ext(Layer l, Layer a, double k) => l.Ext.HasValue ? l.Ext.Value * k : (a.Bottom - a.Top) / 2;

        // Where the end of l is at the height y, past the end of the line (its own ends or
        // those of the band w; yc: the line drawn):
        double EndAt(Layer l, Layer w, double y, double yc, double k)
        {
            var a = Across(l, w);
            switch (l.End)
            {
                case "Extended": return Ext(l, a, k);
                case "Angled": return (Pivot(l, yc) - y) * Math.Tan(l.Angle * Math.PI / 180);
                case "Round":
                    double c = (a.Top + a.Bottom) / 2, rr = (a.Bottom - a.Top) / 2;
                    return Math.Sqrt(Math.Max(0, rr * rr - (y - c) * (y - c)));
                default: return 0;
            }
        }

        // The outline of the layer l, from the left of the wall (_xs) to its end at x0 (closed: the
        // shape to hatch; else its border: its two sides and its end, but Open):
        Geometry Outline(Layer l, Layer w, double x0, double yc, double k, bool closed)
        {
            double xt = x0 + EndAt(l, w, l.Top, yc, k), xb = x0 + EndAt(l, w, l.Bottom, yc, k);
            var g = new StreamGeometry();
            using (var ctx = g.Open())
            {
                bool end = closed || l.End != "Open";
                ctx.BeginFigure(new Point(_xs, l.Top), closed, closed);
                ctx.LineTo(new Point(xt, l.Top), true, true);
                if (l.End == "Round")
                {
                    var a = Across(l, w);
                    double rr = (a.Bottom - a.Top) / 2;
                    ctx.ArcTo(new Point(xb, l.Bottom), new Size(rr, rr), 0, false, SweepDirection.Clockwise, end, true);
                }
                else ctx.LineTo(new Point(xb, l.Bottom), end, true);
                ctx.LineTo(new Point(_xs, l.Bottom), true, true);
            }
            g.Freeze();
            return g;
        }
    }
}
