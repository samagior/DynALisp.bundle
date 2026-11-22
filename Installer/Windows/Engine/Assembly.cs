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
// thickness of the layers is as drawn.
//
// It follows a list of rows (Rows.cs): the editor of the list named by Rows gives it its
// Spec each time the rows or the selection change, from these properties:
//
//   Rows      the key of the list (ll)
//   Columns   the columns of a row: kind, preset, thickness, band settings on, ends,
//             extension, end angle, border on, justification ("0 1 2 5 7 8 9 14 16")
//   Specs     a list of the Lisp: the preview of each preset (as HatchTile draws it), one
//             for each item of the field of the preset column (its width replaced by the
//             thickness of the row; its ppu "w0.0005": the ppu of a unit of thickness, a
//             hatch scale from the thickness)
//   Ends      a list of the Lisp: the ends of the whole band (ends extension angle)
//   Paper     a list of the Lisp: the inches of a drawing unit (1, 1/25.4) and the drawing
//             scale (50); without it, the wall fills the tile and its hatches are drawn as
//             HatchTile draws them
//
// Spec: the bands divided by "*", each a band of HatchTile (P, F, S, L, X) then, divided by
// "~": its ends, extension ("": half its width), end angle (degrees), own ("1": across its
// own thickness), border ("1": its own border), selected ("1"), justification (Edge: its own
// line on its border nearer to the line of the band, else in its middle: what its Angled
// ends turn around).

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
        public string Columns { get; set; } = "0 1 2 5 7 8 9 14 16";
        public string Specs { get; set; }
        public string Ends { get; set; }
        public string Paper { get; set; }

        // The inches of a drawing unit and the drawing scale (0: not given), set by the editor:
        internal double Unit, DrawScale;

        sealed class Layer
        {
            public HatchTile.Band B;
            public string End = "Square";
            public double? Ext;
            public double Angle = 45;
            public bool Own, Border, Sel, Edge;
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

            const double padY = 16, padR = 60;
            double avail = r.Height - 2 * padY;
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
            for (int i = 0; i < wide.Count; i++) { wide[i].Top = y; y += hs[i]; wide[i].Bottom = y; }

            // How far each end goes past the end of the line, so the longest one fits:
            // The whole band, ending as the layers without their own band settings (its Line
            // layers end with it):
            var whole = new Layer { Top = wide[0].Top, Bottom = wide[wide.Count - 1].Bottom, B = new HatchTile.Band { Width = tot } };
            var common = wide.FirstOrDefault(l => !l.Own);
            if (common != null) { whole.End = common.End; whole.Ext = common.Ext; whole.Angle = common.Angle; }
            foreach (var l in wide) l.Reach = Reach(l, whole, k);
            double reach = Math.Min(r.Width * 0.3, wide.Max(l => l.Reach));
            double x0 = r.Width - padR - reach;

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
                for (double cx = 0; cx < r.Width; cx += cw)
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
            // Their borders, then the borders of their own over them:
            foreach (var l in wide) dc.DrawGeometry(null, pen, Outline(l, whole, x0, yc, k, false));
            foreach (var l in wide.Where(l => l.Border)) dc.DrawGeometry(null, accent, Outline(l, whole, x0, yc, k, false));
            // The Line layers, between the layers they are after:
            int at = 0;
            var dash = new Pen(Ink, 2) { DashStyle = DashStyles.Dash };
            dash.Freeze();
            foreach (var l in all)
            {
                if (l.B.Kind != "L") { at++; continue; }
                double ly = at == 0 ? wide[0].Top : wide[Math.Min(at, wide.Count) - 1].Bottom;
                dc.DrawLine(dash, new Point(0, ly), new Point(x0 + EndAt(whole, whole, ly, yc, k), ly));
            }
            if (Math.Abs(zoom - 1) > 1e-9 && ShowScale) Label(dc, r, "1:" + label.ToString("0.##", Inv));
            dc.Pop();
        }

        // The ends of the layer l: its own (across its own thickness), else those of the band
        // (across the whole band w):
        Layer Across(Layer l, Layer w) => l.Own ? l : w;

        // How far past the end of the line the end of l reaches, on the screen:
        double Reach(Layer l, Layer w, double k)
        {
            var a = Across(l, w);
            double yc = (w.Top + w.Bottom) / 2;
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
        // those of the band w; yc: the line, the middle of the band):
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

        // The outline of the layer l, from the left of the tile to its end at x0 (closed: the
        // shape to hatch; else its border: its two sides and its end, but Open):
        Geometry Outline(Layer l, Layer w, double x0, double yc, double k, bool closed)
        {
            double xt = x0 + EndAt(l, w, l.Top, yc, k), xb = x0 + EndAt(l, w, l.Bottom, yc, k);
            var g = new StreamGeometry();
            using (var ctx = g.Open())
            {
                bool end = closed || l.End != "Open";
                ctx.BeginFigure(new Point(-2, l.Top), closed, closed);
                ctx.LineTo(new Point(xt, l.Top), true, true);
                if (l.End == "Round")
                {
                    var a = Across(l, w);
                    double rr = (a.Bottom - a.Top) / 2;
                    ctx.ArcTo(new Point(xb, l.Bottom), new Size(rr, rr), 0, false, SweepDirection.Clockwise, end, true);
                }
                else ctx.LineTo(new Point(xb, l.Bottom), end, true);
                ctx.LineTo(new Point(-2, l.Bottom), true, true);
            }
            g.Freeze();
            return g;
        }
    }
}
