// Cover.cs - DynALisp.Ribbon: a dark cover over AutoCAD while the interface takes its colours
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
// The main window of AutoCAD is already shown when the plugin loads (AutoCAD loads its bundles
// after), and the theme of the ribbon can be changed only about 3 s later (it is frozen until
// then, Skin.cs): the interface was seen in the blue-greys of AutoCAD, then changing one part
// after the other. While the Interface of Dyl-Settings is on and AutoCAD dark, a window of the
// dark of the look, owned by the main window and over all of it, hides that time: shown as the
// plugin loads, taken away (faded out in 150 ms) once the ribbon and the palettes are in the
// look, or after 6 s whatever happens. It takes no focus and no click goes through it while it
// shows; the window of a startup step (What's new) shows over it.

using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    public static class Cover
    {
        static Window _w;
        static int _until;
        const int Longest = 6000;

        public static bool Shown => _w != null;

        [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect r);
        [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
        const uint SWP_NOACTIVATE = 0x10, SWP_SHOWWINDOW = 0x40;

        // Shown over the main window, in the dark of the look (its title bar, #1A1A1A under
        // DynALisp Dark):
        public static void Show(Look look)
        {
            if (_w != null) return;
            try
            {
                IntPtr main = AcApp.MainWindow.Handle;
                if (main == IntPtr.Zero || IsIconic(main) || !GetWindowRect(main, out var r)) return;
                var back = Skin.Map(Color.FromRgb(0x22, 0x29, 0x33), look);
                var w = new Window
                {
                    WindowStyle = WindowStyle.None,
                    ResizeMode = ResizeMode.NoResize,
                    ShowInTaskbar = false,
                    ShowActivated = false,
                    AllowsTransparency = true,
                    Focusable = false,
                    Background = new SolidColorBrush(back),
                    Title = "DynALisp",
                };
                var h = new WindowInteropHelper(w) { Owner = main };
                IntPtr hwnd = h.EnsureHandle();
                // In the pixels of the screen (the main window may be on a screen of another scale):
                SetWindowPos(hwnd, IntPtr.Zero, r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top, SWP_NOACTIVATE | SWP_SHOWWINDOW);
                _w = w;
                _until = Environment.TickCount + Longest;
                Skin.Mark("cover shown");
            }
            catch (System.Exception ex) { Skin.Mark("cover: " + ex.Message); _w = null; }
        }

        // Taken away when done, or after Longest:
        public static void Check(bool done)
        {
            if (_w == null) return;
            if (!done && Environment.TickCount - _until < 0) return;
            var w = _w;
            _w = null;
            Skin.Mark(done ? "cover taken away" : "cover taken away after " + Longest + " ms");
            try
            {
                var fade = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(150));
                fade.Completed += (s, e) => { try { w.Close(); } catch { } };
                w.BeginAnimation(UIElement.OpacityProperty, fade);
            }
            catch { try { w.Close(); } catch { } }
        }
    }
}
