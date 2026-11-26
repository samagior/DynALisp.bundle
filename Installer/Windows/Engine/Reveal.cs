// Reveal.cs - DynALisp.Windows: a window shown only once it is drawn
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
// Every window of the engine (Session.Show, the modeless Manager of Tabs.cs, a question of a
// preset window) is shown hidden: cloaked by Windows (DWMWA_CLOAK, Windows 8 and later), drawn
// but not on the screen, from the moment it has a handle until its layout has settled, then
// shown at once. A window shown at once is seen white, then placed and sized by Fit.cs, its
// lists given their heights and its previews drawn over the next frames: the Manager opened
// white and its tabs blinked. Settled: its first frame drawn (ContentRendered), then 80 ms
// without a layout (LayoutUpdated), then nothing left for the dispatcher to do
// (ApplicationIdle). Never left hidden: shown 1.5 s after it has its handle whatever happens.
// Nothing changes on an older Windows (the cloak is refused: the window is shown as before).

using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;

namespace DynALisp.Windows
{
    public static class Reveal
    {
        // Keeps the window w, not shown yet, hidden until it is drawn and settled; shown (null:
        // nothing) is run in the moment it is shown, before the next frame (the Manager closes
        // the window of the tab left there):
        public static void Attach(Window w, Action shown = null)
        {
            bool done = false, rendered = false;
            var settle = new DispatcherTimer(DispatcherPriority.Background, w.Dispatcher) { Interval = TimeSpan.FromMilliseconds(80) };
            var late = new DispatcherTimer(DispatcherPriority.Normal, w.Dispatcher) { Interval = TimeSpan.FromMilliseconds(1500) };
            void Again(object a, EventArgs b)
            {
                if (!rendered || done) return;
                settle.Stop();
                settle.Start();
            }
            void Stop()
            {
                late.Stop();
                settle.Stop();
                w.LayoutUpdated -= Again;
            }
            void Show()
            {
                if (done) return;
                done = true;
                Stop();
                Cloak(w, false);
                try { shown?.Invoke(); } catch { }
            }
            settle.Tick += (a, b) =>
            {
                settle.Stop();
                w.Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, (Action)Show);
            };
            late.Tick += (a, b) => Show();
            w.LayoutUpdated += Again;
            w.ContentRendered += (a, b) => { rendered = true; settle.Start(); };
            w.SourceInitialized += (a, b) => { Cloak(w, true); late.Start(); };
            w.Closed += (a, b) => { done = true; Stop(); };
        }

        // The window w hidden (true) or shown again by Windows; nothing when it cannot be:
        public static void Cloak(Window w, bool on)
        {
            try
            {
                var h = new WindowInteropHelper(w).Handle;
                int v = on ? 1 : 0;
                if (h != IntPtr.Zero) DwmSetWindowAttribute(h, 13, ref v, sizeof(int));
            }
            catch { }
        }

        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    }
}
