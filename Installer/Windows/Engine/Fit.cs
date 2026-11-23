// Fit.cs - DynALisp.Windows: a window that fits the screen, that the user resizes and snaps
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
// Every window shown over AutoCAD (Session.FitToScreen, Bridge.cs) goes through here, its
// file left as it is written (its lists of a fixed Height in a StackPanel of a fixed Width):
//
//   - Its content is put in a ScrollViewer: what does not fit the window scrolls, never runs
//     off the screen.
//   - Its lists grow with it: every ListBox, Gallery, or TextBox of several lines with a
//     Height (a ListBox with a MinHeight, or none at all, gets one: its MinHeight, 240), not
//     a MaxHeight (the chips of the aliases), or any element with dyl:Win.Grow="1"
//     (dyl:Win.Grow="0": never). Such a window can be resized: by its borders, maximized,
//     snapped to a side of the screen as any window of Windows (Aero Snap, Win+arrows), never
//     minimized (it is modal). The height the window has more or less than its content goes
//     to its lists, shared by the lists one above the other in proportion to their height
//     (each list beside them gets it all), down to 100 (a Gallery 200) and up without end;
//     the width it has more goes to what holds them: the Width of their panels and the
//     column of a Grid of a fixed width they are in (or the ColumnDefinition of that Grid with
//     dyl:Win.Grow="1"), shared the same way by those side by side. It is never narrower
//     than its content.
//   - It opens at the size of its content, but never larger than the work area of the
//     screen of AutoCAD (its lists shorter), centered on the window that opened it and kept
//     inside the screen.
//   - A window that can be resized opens where it was left, at the size it was left
//     (maximized when it was), kept inside a screen: Places, saved by the plugin in one user
//     setting (DynalispWindowPlaces). A window without lists keeps the size of its content
//     (SizeToContent), at most the size of the screen.
//
// The pictures of the docs (Shots\, Session.Open) do not go through here: they show the
// window at the size of its file.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Interop;
using System.Windows.Media;

namespace DynALisp.Windows
{
    // Where the windows were left, by the name of their file ("Dyl-Suite"): "left,top,width,
    // height,maximized" in device-independent units (Bridge.cs keeps them in the registry):
    public interface IPlaces
    {
        string Get(string name);
        void Set(string name, string value);
    }

    internal sealed class Fit
    {
        // A list that grows with the window: its height at the size of the file and its least:
        sealed class Grow
        {
            public FrameworkElement E;
            public double Nat, Min;
            public Rect Box;
            public readonly List<Grow> Stack = new List<Grow>();
        }

        // What grows wider with the window: an element of a fixed Width, or a fixed column:
        sealed class Wide
        {
            public FrameworkElement E;
            public ColumnDefinition C;
            public Grid G;
            public double Nat;
            public Rect Box;
            public readonly List<Wide> Side = new List<Wide>();
        }

        // What Distribute does, for Shots -fit (null in AutoCAD):
        internal static Action<string> Trace;

        const double ListLeast = 100, GalleryLeast = 200, ListDefault = 240;
        static readonly Size Inf = new Size(double.PositiveInfinity, double.PositiveInfinity);

        readonly Window _w;
        readonly string _name;
        readonly IPlaces _places;
        readonly ScrollViewer _sv;
        readonly FrameworkElement _content;
        readonly List<Grow> _grows = new List<Grow>();
        readonly List<Wide> _wides = new List<Wide>();
        double _natW;
        bool _ready, _busy;
        Size _lastFull, _lastView, _lastWant;
        int _runs, _runsSince;

        bool Resizable => _grows.Count > 0;

        // Makes the window w (of the file name, without its extension) fit, before it is shown:
        internal static void Attach(Window w, string name, IPlaces places)
        {
            if (w.Content is FrameworkElement c) new Fit(w, c, name, places);
        }

        Fit(Window w, FrameworkElement content, string name, IPlaces places)
        {
            _w = w;
            _name = name;
            _places = places;
            _content = content;
            w.Content = null;
            _sv = new ScrollViewer
            {
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Focusable = false,
                IsTabStop = false,
                Content = content,
            };
            w.Content = _sv;
            Find(content);
            if (Resizable)
            {
                w.ResizeMode = ResizeMode.CanResize;
                // a list without a Height would be as tall as all its items:
                foreach (var g in _grows)
                    if (double.IsNaN(g.E.Height)) g.E.Height = g.E.MinHeight >= 80 ? g.E.MinHeight : ListDefault;
                _content.LayoutUpdated += (a, b) => Distribute();
            }
            w.SourceInitialized += (a, b) => { try { Place(); } catch { _ready = Resizable; } };
            w.Closing += (a, b) => { try { Save(); } catch { } };
        }

        // ---- What grows ----

        void Find(DependencyObject o)
        {
            if (o is FrameworkElement fe && Growable(fe)) { _grows.Add(new Grow { E = fe }); return; }
            foreach (var c in LogicalTreeHelper.GetChildren(o))
                if (c is DependencyObject d) Find(d);
        }

        static bool Local(DependencyObject o, DependencyProperty p) => o.ReadLocalValue(p) != DependencyProperty.UnsetValue;

        static bool Growable(FrameworkElement fe)
        {
            string g = Win.GetGrow(fe);
            if (g == "0") return false;
            if (g == "1") return true;
            if (!double.IsPositiveInfinity(fe.MaxHeight)) return false;
            bool high = Local(fe, FrameworkElement.HeightProperty) && fe.Height >= 80;
            switch (fe)
            {
                case ListBox _: return high || !Local(fe, FrameworkElement.HeightProperty);
                case Gallery _: return high;
                case TextBox t: return high && t.AcceptsReturn;
                default: return false;
            }
        }

        // Shown: neither it nor what holds it collapsed or hidden (Win.VisibleBy):
        bool Shown(FrameworkElement e)
        {
            for (DependencyObject o = e; o != null; o = LogicalTreeHelper.GetParent(o))
            {
                if (o is UIElement u && u.Visibility != Visibility.Visible) return false;
                if (o == _content) return true;
            }
            return true;
        }

        Rect BoxOf(FrameworkElement e)
        {
            try
            {
                var r = new Rect(0, 0, e.ActualWidth, e.ActualHeight);
                return e == _content ? r : e.TransformToAncestor(_content).TransformBounds(r);
            }
            catch { return Rect.Empty; }
        }

        Rect ColBox(Grid g, ColumnDefinition c)
        {
            var r = BoxOf(g);
            return r.IsEmpty ? r : new Rect(r.X + c.Offset, r.Y, c.ActualWidth, r.Height);
        }

        // What holds the lists and has a fixed width: the Width of a panel, the fixed column
        // of a Grid (or its column marked dyl:Win.Grow="1"), a list of a fixed Width itself:
        void Widen()
        {
            var seen = new HashSet<object>();
            void AddE(FrameworkElement e)
            {
                if (Local(e, FrameworkElement.WidthProperty) && !double.IsNaN(e.Width) && seen.Add(e))
                    _wides.Add(new Wide { E = e, Nat = e.Width, Box = BoxOf(e) });
            }
            void AddC(Grid g, ColumnDefinition c)
            {
                if (c.Width.IsAbsolute && seen.Add(c)) _wides.Add(new Wide { C = c, G = g, Nat = c.Width.Value, Box = ColBox(g, c) });
            }
            foreach (var gr in _grows)
            {
                AddE(gr.E);
                DependencyObject child = gr.E;
                while (child != _content)
                {
                    var p = LogicalTreeHelper.GetParent(child);
                    if (p == null) break;
                    if (p is Grid g && child is UIElement ue && g.ColumnDefinitions.Count > 0)
                    {
                        var marked = g.ColumnDefinitions.FirstOrDefault(c => Win.GetGrow(c) == "1");
                        int col = Grid.GetColumn(ue);
                        if (marked != null) AddC(g, marked);
                        else if (Grid.GetColumnSpan(ue) == 1 && col < g.ColumnDefinitions.Count) AddC(g, g.ColumnDefinitions[col]);
                    }
                    if (p is FrameworkElement pf) AddE(pf);
                    child = p;
                }
            }
        }

        static bool Over(double a0, double a1, double b0, double b1) => a0 < b1 - 0.5 && b0 < a1 - 0.5;

        // The lists one above the other (they share the height) and what is side by side
        // (they share the width):
        void Relate()
        {
            foreach (var a in _grows)
                foreach (var b in _grows)
                    if (a != b && !a.Box.IsEmpty && !b.Box.IsEmpty
                        && Over(a.Box.Left, a.Box.Right, b.Box.Left, b.Box.Right) && !Over(a.Box.Top, a.Box.Bottom, b.Box.Top, b.Box.Bottom))
                        a.Stack.Add(b);
            foreach (var a in _wides)
                foreach (var b in _wides)
                    if (a != b && !a.Box.IsEmpty && !b.Box.IsEmpty
                        && Over(a.Box.Top, a.Box.Bottom, b.Box.Top, b.Box.Bottom) && !Over(a.Box.Left, a.Box.Right, b.Box.Left, b.Box.Right))
                        a.Side.Add(b);
        }

        // ---- The size and the place of the window ----

        void Place()
        {
            var hwnd = new WindowInteropHelper(_w).Handle;
            var src = PresentationSource.FromVisual(_w);
            if (hwnd == IntPtr.Zero || src?.CompositionTarget == null) { _ready = Resizable; return; }
            var m = src.CompositionTarget.TransformFromDevice;
            double sx = m.M11, sy = m.M22;
            if (Resizable) NoMinimize(hwnd);

            _w.UpdateLayout();
            double leastH = 0;
            if (Resizable)
            {
                // a list fills the room its panel gives it (the last one of a DockPanel, the
                // row of a Grid as tall as the column beside it):
                foreach (var g in _grows)
                {
                    var slot = LayoutInformation.GetLayoutSlot(g.E);
                    double room = slot.Height - g.E.Margin.Top - g.E.Margin.Bottom;
                    g.Nat = Math.Max(g.E.Height, double.IsNaN(room) || double.IsInfinity(room) ? 0 : room);
                    g.E.Height = g.Nat;
                    g.Min = Math.Min(g.Nat, g.E is Gallery ? GalleryLeast : ListLeast);
                    g.E.MinHeight = g.Min;
                }
                _w.UpdateLayout();
                foreach (var g in _grows) g.Box = BoxOf(g.E);
                Widen();
                Relate();
                foreach (var g in _grows) g.E.Height = g.Min;
                Remeasure();
                leastH = _content.DesiredSize.Height;
                foreach (var g in _grows) g.E.Height = g.Nat;
            }
            Remeasure();
            var nat = _content.DesiredSize;
            _natW = nat.Width;
            if (!Resizable) leastH = nat.Height;

            // the frame of the window (title bar, borders), the content being the client area:
            GetWindowRect(hwnd, out RECT wr);
            GetClientRect(hwnd, out RECT cr);
            double frameW = Math.Max(0, (wr.Right - wr.Left) - (cr.Right - cr.Left)) * sx;
            double frameH = Math.Max(0, (wr.Bottom - wr.Top) - (cr.Bottom - cr.Top)) * sy;
            double natW = nat.Width + frameW, natH = nat.Height + frameH;

            // the window that opened it (AutoCAD, or the window under a sub-window):
            IntPtr owner = new WindowInteropHelper(_w).Owner;
            if (owner == IntPtr.Zero && _w.Owner != null) owner = new WindowInteropHelper(_w.Owner).Handle;
            RECT ownerRect = default;
            bool hasOwner = owner != IntPtr.Zero && GetWindowRect(owner, out ownerRect) && ownerRect.Right > ownerRect.Left;

            bool max = false;
            Rect? saved = Resizable ? Saved(out max) : null;
            double cx, cy;
            if (saved != null) { cx = saved.Value.Left + saved.Value.Width / 2; cy = saved.Value.Top + saved.Value.Height / 2; }
            else if (hasOwner) { cx = (ownerRect.Left + ownerRect.Right) / 2.0 * sx; cy = (ownerRect.Top + ownerRect.Bottom) / 2.0 * sy; }
            else { cx = (wr.Left + wr.Right) / 2.0 * sx; cy = (wr.Top + wr.Bottom) / 2.0 * sy; }
            var wa = WorkArea(cx / sx, cy / sy, sx, sy);

            if (!Resizable)
            {
                // the size of its content, at most the screen (what is more scrolls):
                _w.MaxWidth = wa.Width;
                _w.MaxHeight = wa.Height;
                double w0 = Math.Min(natW, wa.Width), h0 = Math.Min(natH, wa.Height);
                _w.WindowStartupLocation = WindowStartupLocation.Manual;
                _w.Left = Clamp(cx - w0 / 2, wa.Left, wa.Right - w0);
                _w.Top = Clamp(cy - h0 / 2, wa.Top, wa.Bottom - h0);
                return;
            }

            double minW = Math.Min(natW, wa.Width), minH = Math.Min(leastH + frameH, wa.Height);
            double w = Clamp(saved?.Width ?? natW, minW, wa.Width);
            double h = Clamp(saved?.Height ?? natH, minH, wa.Height);
            double left = saved?.Left ?? cx - w / 2, top = saved?.Top ?? cy - h / 2;
            _w.SizeToContent = SizeToContent.Manual;
            _w.WindowStartupLocation = WindowStartupLocation.Manual;
            _w.MinWidth = minW;
            _w.MinHeight = minH;
            _w.Left = Clamp(left, wa.Left, wa.Right - w);
            _w.Top = Clamp(top, wa.Top, wa.Bottom - h);
            _w.Width = w;
            _w.Height = h;
            if (max) _w.WindowState = WindowState.Maximized;
            _ready = true;
            _w.UpdateLayout();
            Distribute();
        }

        static double Clamp(double v, double lo, double hi) => hi < lo ? lo : Math.Max(lo, Math.Min(hi, v));

        // The place saved, in device-independent units:
        Rect? Saved(out bool max)
        {
            max = false;
            string s = _places?.Get(_name);
            if (string.IsNullOrEmpty(s)) return null;
            var f = s.Split(',');
            if (f.Length < 4) return null;
            var n = new double[4];
            for (int i = 0; i < 4; i++)
                if (!double.TryParse(f[i], NumberStyles.Float, CultureInfo.InvariantCulture, out n[i])) return null;
            if (n[2] < 50 || n[3] < 50) return null;
            max = f.Length > 4 && f[4] == "1";
            return new Rect(n[0], n[1], n[2], n[3]);
        }

        void Save()
        {
            if (!Resizable || !_ready || _places == null) return;
            var r = _w.WindowState == WindowState.Normal ? new Rect(_w.Left, _w.Top, _w.ActualWidth, _w.ActualHeight) : _w.RestoreBounds;
            if (r.IsEmpty || double.IsNaN(r.Left) || r.Width < 50 || r.Height < 50) return;
            string N(double v) => Math.Round(v).ToString(CultureInfo.InvariantCulture);
            _places.Set(_name, string.Join(",", N(r.Left), N(r.Top), N(r.Width), N(r.Height), _w.WindowState == WindowState.Maximized ? "1" : "0"));
        }

        // ---- The lists follow the size of the window ----

        // Measures the content again at once: what holds a list changed is measured again,
        // not only the list (a parent measured before keeps its size until then):
        void Remeasure()
        {
            void Dirty(DependencyObject o)
            {
                for (; o != null; o = VisualTreeHelper.GetParent(o))
                {
                    if (o is UIElement u) u.InvalidateMeasure();
                    if (o == _content) return;
                }
            }
            foreach (var g in _grows) Dirty(g.E);
            foreach (var t in _wides) Dirty((DependencyObject)t.E ?? t.G);
            _content.Measure(Inf);
        }

        // The height and the width the window has more or less than its content go to its
        // lists and to what holds them. The scroll bars are shown only when the content
        // cannot fit, decided from the size of the window alone: a bar shown or hidden by
        // the content itself would change the room it has, and so the content, again.
        void Distribute()
        {
            if (!_ready || _busy) return;
            var full = new Size(_sv.ActualWidth, _sv.ActualHeight);
            var view = new Size(_sv.ViewportWidth, _sv.ViewportHeight);
            if (!(full.Width > 0) || !(full.Height > 0) || !(view.Width > 0) || !(view.Height > 0)) return;
            if (Same(full, _lastFull) && Same(view, _lastView) && Same(_content.DesiredSize, _lastWant)) return;
            // never more than a few times in a row for the same size (a text that wraps
            // otherwise at each width):
            int now = Environment.TickCount;
            if (now - _runsSince > 500 || !Same(full, _lastFull)) { _runs = 0; _runsSince = now; }
            if (++_runs > 8) { Trace?.Invoke("      stopped after 8 runs"); return; }
            _busy = true;
            try
            {
                bool hBar = _sv.ComputedHorizontalScrollBarVisibility == Visibility.Visible;
                bool vBar = _sv.ComputedVerticalScrollBarVisibility == Visibility.Visible;
                double hBarH = hBar ? full.Height - view.Height : SystemParameters.HorizontalScrollBarHeight;
                double vBarW = vBar ? full.Width - view.Width : SystemParameters.VerticalScrollBarWidth;

                // the width: never narrower than the content, a bar under it when it is:
                bool needV = _sv.VerticalScrollBarVisibility == ScrollBarVisibility.Auto && vBar;
                double availW = full.Width - (needV ? vBarW : 0);
                bool needH = _natW > availW + 0.5;
                double dx = Math.Max(0, availW - _natW);
                foreach (var t in _wides)
                {
                    double share = t.Nat / (t.Nat + t.Side.Sum(o => o.Nat));
                    double v = t.Nat + dx * (double.IsNaN(share) ? 1 : share);
                    if (t.C != null) { if (Math.Abs(t.C.Width.Value - v) > 0.5) t.C.Width = new GridLength(v); }
                    else if (Math.Abs(t.E.Width - v) > 0.5) t.E.Width = v;
                }

                // the height: the lists one above the other share it, those at their least
                // leave it to the others:
                double availH = full.Height - (needH ? hBarH : 0);
                var shown = _grows.Where(g => Shown(g.E)).ToList();
                foreach (var g in _grows) Height(g, g.Nat);
                Remeasure();
                double dy = availH - _content.DesiredSize.Height;
                // again while it does not fit: a list beside a taller column changes nothing,
                // the others above or below it take the rest
                for (int pass = 0; pass < 6 && Math.Abs(dy) >= 1; pass++)
                {
                    var from = shown.ToDictionary(g => g, g => g.E.Height);
                    var least = new HashSet<Grow>();
                    double Target(Grow g)
                    {
                        if (least.Contains(g)) return g.Min;
                        var stack = g.Stack.Where(shown.Contains).ToList();
                        double taken = stack.Where(least.Contains).Sum(o => o.Min - from[o]);
                        double free = g.Nat + stack.Where(o => !least.Contains(o)).Sum(o => o.Nat);
                        return from[g] + (dy - taken) * (free > 0 ? g.Nat / free : 1);
                    }
                    for (int k = 0; k < 6; k++)
                    {
                        var under = shown.Where(g => !least.Contains(g) && Target(g) < g.Min).ToList();
                        if (under.Count == 0) break;
                        foreach (var g in under) least.Add(g);
                    }
                    var heights = shown.Select(g => Math.Max(g.Min, Target(g))).ToList();
                    if (!heights.Where((h, k) => Math.Abs(h - from[shown[k]]) > 0.5).Any()) break;
                    double before = _content.DesiredSize.Height;
                    for (int k = 0; k < shown.Count; k++) Height(shown[k], heights[k]);
                    Remeasure();
                    if (Math.Abs(_content.DesiredSize.Height - before) < 0.5)
                    {
                        // nothing changed: the lists hold no room, as they were
                        foreach (var kv in from) Height(kv.Key, kv.Value);
                        Remeasure();
                        break;
                    }
                    dy = availH - _content.DesiredSize.Height;
                }

                // the bars: only for what still does not fit
                needV = _content.DesiredSize.Height > availH + 0.5;
                var hv = needH ? ScrollBarVisibility.Auto : ScrollBarVisibility.Hidden;
                var vv = needV ? ScrollBarVisibility.Auto : ScrollBarVisibility.Hidden;
                if (_sv.HorizontalScrollBarVisibility != hv) _sv.HorizontalScrollBarVisibility = hv;
                if (_sv.VerticalScrollBarVisibility != vv) _sv.VerticalScrollBarVisibility = vv;
                Trace?.Invoke("      run " + _runs + ": full " + full + " view " + view + " needH " + needH + " needV " + needV + " dx " + Math.Round(dx)
                              + " dy " + Math.Round(dy) + " want " + _content.DesiredSize + " lists " + string.Join(" ", shown.Select(g => Math.Round(g.E.Height))));
                _lastFull = full;
                _lastView = view;
                _lastWant = _content.DesiredSize;
            }
            catch { }
            finally { _busy = false; }
        }

        static void Height(Grow g, double h)
        {
            if (Math.Abs(g.E.Height - h) > 0.5) g.E.Height = h;
        }

        static bool Same(Size a, Size b) => Math.Abs(a.Width - b.Width) < 0.5 && Math.Abs(a.Height - b.Height) < 0.5;

        // ---- Windows ----

        [StructLayout(LayoutKind.Sequential)]
        struct RECT { public int Left, Top, Right, Bottom; }

        [StructLayout(LayoutKind.Sequential)]
        struct POINT { public int X, Y; }

        [StructLayout(LayoutKind.Sequential)]
        struct MONITORINFO { public int cbSize; public RECT rcMonitor, rcWork; public int dwFlags; }

        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
        [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out RECT r);
        [DllImport("user32.dll")] static extern IntPtr MonitorFromPoint(POINT pt, uint flags);
        [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO mi);
        [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hwnd, int index);
        [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr hwnd, int index, int value);

        // The work area (the screen but the taskbar) of the screen at the point (device
        // pixels), in device-independent units:
        static Rect WorkArea(double x, double y, double sx, double sy)
        {
            var mi = new MONITORINFO { cbSize = Marshal.SizeOf(typeof(MONITORINFO)) };
            var mon = MonitorFromPoint(new POINT { X = (int)x, Y = (int)y }, 2);
            if (mon == IntPtr.Zero || !GetMonitorInfo(mon, ref mi)) return SystemParameters.WorkArea;
            var r = mi.rcWork;
            return new Rect(r.Left * sx, r.Top * sy, (r.Right - r.Left) * sx, (r.Bottom - r.Top) * sy);
        }

        // A modal window is never minimized: no minimize button.
        static void NoMinimize(IntPtr hwnd)
        {
            const int GWL_STYLE = -16, WS_MINIMIZEBOX = 0x20000;
            SetWindowLong(hwnd, GWL_STYLE, GetWindowLong(hwnd, GWL_STYLE) & ~WS_MINIMIZEBOX);
        }
    }
}
