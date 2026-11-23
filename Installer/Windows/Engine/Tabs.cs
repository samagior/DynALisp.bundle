// Tabs.cs - DynALisp.Windows: the tabs of a window that holds several tools (the Manager)
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
// A window of several tools (the Manager of Remote\Dyl-Manager.lsp: Quick Draw, Assembly
// Presets, Quick Shape, Materials, Hatch Presets) is the window of the tool of its tab shown
// under a row of tabs. The Lisp gives, with the values of that window:
//
//   ("tab/list" "Quick Draw" "Materials" ...)   the titles of the tabs
//   ("tab" . "1")                               the tab shown
//   ("tab/title" . "DynALisp - Manager")        the title of the window (else that one)
//   ("tab/place" . "Dyl-Manager")               where the window is kept (Fit.cs, else that)
//
// Each tab is its own window file, run by its own Lisp: nothing calls the Lisp back while a
// window is open, so another tab picked (a click, Ctrl+Tab, Ctrl+Shift+Tab) closes the window
// with Status (its values checked first, as OK), the tab picked in "tab", and the Lisp shows
// the window of that tab. Every tab is kept at the one place and size (tab/place), and the
// picture of the window is left on the screen until the next one is shown (Cover), so the
// window does not seem to close between two tabs.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace DynALisp.Windows
{
    // The content of a window with tabs: the row of tabs on top, the window of the tab under
    // it (Body; Fit.cs puts it in its ScrollViewer, the tabs staying on top):
    public sealed class TabHost : DockPanel
    {
        // The status a window closes with when another tab is picked:
        public const int Status = 90;

        readonly Border _strip;
        UIElement _body;

        public string Place { get; }

        internal UIElement Strip => _strip;

        public UIElement Body
        {
            get => _body;
            set
            {
                if (_body != null) Children.Remove(_body);
                _body = value;
                if (value != null) Children.Add(value);
            }
        }

        TabHost(Border strip, string place)
        {
            _strip = strip;
            Place = place;
            LastChildFill = true;
            SetDock(strip, Dock.Top);
            Children.Add(strip);
        }

        // Puts the tabs of the session on the window of view, when the Lisp gave them:
        internal static void Wrap(View view, Session s)
        {
            if (!s.Lists.TryGetValue("tab", out var titles) || titles == null || titles.Count == 0) return;
            var w = view.Window;
            if (!(w.Content is UIElement body)) return;
            int cur = 0;
            if (s.Values.TryGetValue("tab", out string v)) int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out cur);
            cur = Math.Max(0, Math.Min(titles.Count - 1, cur));
            s.Values.TryGetValue("tab/title", out string title);
            s.Values.TryGetValue("tab/place", out string place);
            w.Title = string.IsNullOrEmpty(title) ? "DynALisp - Manager" : title;

            var row = new StackPanel { Orientation = Orientation.Horizontal };
            for (int i = 0; i < titles.Count; i++) row.Children.Add(Tab(titles[i], i == cur, i, k => Pick(view, s, cur, k)));
            var strip = new Border { Padding = new Thickness(10, 6, 10, 0), BorderThickness = new Thickness(0, 0, 0, 1), Child = row };
            strip.SetResourceReference(Border.BorderBrushProperty, "Dyl.Border");

            w.Content = null;
            var host = new TabHost(strip, string.IsNullOrEmpty(place) ? "Dyl-Manager" : place) { Body = body };
            w.Content = host;

            // Ctrl+Tab, Ctrl+Shift+Tab (and Ctrl+Page Down / Up) show the next and the previous tab:
            w.PreviewKeyDown += (a, e) =>
            {
                if ((Keyboard.Modifiers & ModifierKeys.Control) == 0 || titles.Count < 2) return;
                int step = 0;
                if (e.Key == Key.Tab) step = (Keyboard.Modifiers & ModifierKeys.Shift) != 0 ? -1 : 1;
                else if (e.Key == Key.PageDown) step = 1;
                else if (e.Key == Key.PageUp) step = -1;
                if (step == 0) return;
                e.Handled = true;
                Pick(view, s, cur, (cur + step + titles.Count) % titles.Count);
            };
        }

        static Border Tab(string title, bool on, int index, Action<int> pick)
        {
            var text = new TextBlock { Text = title, FontSize = 13 };
            var tab = new Border
            {
                Padding = new Thickness(12, 6, 12, 7),
                Margin = new Thickness(0, 0, 2, -1),
                BorderThickness = new Thickness(0, 0, 0, 2),
                Background = Brushes.Transparent,
                Child = text,
                Focusable = false,
            };
            if (on)
            {
                text.FontWeight = FontWeights.SemiBold;
                text.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Heading");
                tab.SetResourceReference(Border.BorderBrushProperty, "Dyl.Accent");
                return tab;
            }
            text.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            tab.BorderBrush = Brushes.Transparent;
            tab.Cursor = Cursors.Hand;
            tab.MouseEnter += (a, e) => { text.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Text"); tab.SetResourceReference(Border.BackgroundProperty, "Dyl.Hover"); };
            tab.MouseLeave += (a, e) => { text.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted"); tab.Background = Brushes.Transparent; };
            tab.MouseLeftButtonUp += (a, e) => { e.Handled = true; pick(index); };
            return tab;
        }

        // Another tab picked: the window closes with Status (its values checked first, as
        // OK; when one is not valid it stays on its tab), the picture of the window left on
        // the screen until the window of the tab picked is shown:
        static void Pick(View view, Session s, int cur, int index)
        {
            if (index == cur) return;
            s.Values.TryGetValue("tab", out string before);
            s.Values["tab"] = index.ToString(CultureInfo.InvariantCulture);
            if (!view.CloseWith(Status, () => Cover.Show(view.Window)))
            {
                if (before == null) s.Values.Remove("tab"); else s.Values["tab"] = before;
            }
        }
    }

    // The picture of a window left on the screen while the Lisp shows the next one (another
    // tab): closed when the next window is shown (Session.Show), when AutoCAD is idle again
    // (Bridge.cs: the Lisp showed no other window), or after a few seconds at most.
    public static class Cover
    {
        static Window _cover;
        static DispatcherTimer _timer;

        public static bool Shown => _cover != null;

        internal static void Show(Window w)
        {
            Close();
            try
            {
                var hwnd = new WindowInteropHelper(w).Handle;
                var src = PresentationSource.FromVisual(w);
                if (hwnd == IntPtr.Zero || src?.CompositionTarget == null) return;
                if (DwmGetWindowAttribute(hwnd, 9, out RECT r, Marshal.SizeOf(typeof(RECT))) != 0 && !GetWindowRect(hwnd, out r)) return;
                int wd = r.Right - r.Left, ht = r.Bottom - r.Top;
                if (wd <= 0 || ht <= 0) return;
                var image = Capture(r.Left, r.Top, wd, ht);
                if (image == null) return;
                var m = src.CompositionTarget.TransformFromDevice;
                var cover = new Window
                {
                    WindowStyle = WindowStyle.None,
                    ResizeMode = ResizeMode.NoResize,
                    ShowInTaskbar = false,
                    ShowActivated = false,
                    Focusable = false,
                    IsHitTestVisible = false,
                    WindowStartupLocation = WindowStartupLocation.Manual,
                    Left = r.Left * m.M11,
                    Top = r.Top * m.M22,
                    Width = wd * m.M11,
                    Height = ht * m.M22,
                    Background = w.Background,
                    Content = new Image { Source = image, Stretch = Stretch.Fill },
                };
                // above what the window was above (AutoCAD):
                var owner = new WindowInteropHelper(w).Owner;
                if (owner == IntPtr.Zero && w.Owner != null) owner = new WindowInteropHelper(w.Owner).Handle;
                new WindowInteropHelper(cover).Owner = owner;
                cover.Show();
                // drawn before the window closes:
                cover.Dispatcher.Invoke(DispatcherPriority.Render, new Action(() => { }));
                _cover = cover;
                _timer = new DispatcherTimer(DispatcherPriority.Background, cover.Dispatcher) { Interval = TimeSpan.FromSeconds(4) };
                _timer.Tick += (a, b) => Close();
                _timer.Start();
            }
            catch { Close(); }
        }

        public static void Close()
        {
            var c = _cover;
            _cover = null;
            if (_timer != null) { _timer.Stop(); _timer = null; }
            if (c == null) return;
            try { c.Close(); } catch { }
        }

        static BitmapSource Capture(int x, int y, int w, int h)
        {
            IntPtr screen = GetDC(IntPtr.Zero), mem = IntPtr.Zero, bmp = IntPtr.Zero, old = IntPtr.Zero;
            try
            {
                mem = CreateCompatibleDC(screen);
                bmp = CreateCompatibleBitmap(screen, w, h);
                old = SelectObject(mem, bmp);
                if (!BitBlt(mem, 0, 0, w, h, screen, x, y, 0x00CC0020 | 0x40000000)) return null;
                SelectObject(mem, old);
                old = IntPtr.Zero;
                var image = Imaging.CreateBitmapSourceFromHBitmap(bmp, IntPtr.Zero, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                image.Freeze();
                return image;
            }
            catch { return null; }
            finally
            {
                if (old != IntPtr.Zero) SelectObject(mem, old);
                if (bmp != IntPtr.Zero) DeleteObject(bmp);
                if (mem != IntPtr.Zero) DeleteDC(mem);
                ReleaseDC(IntPtr.Zero, screen);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        struct RECT { public int Left, Top, Right, Bottom; }

        [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT value, int size);
        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
        [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
        [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
        [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
        [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
        [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
        [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, int rop);
        [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
        [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    }
}
