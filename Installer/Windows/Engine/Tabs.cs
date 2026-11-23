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
// window is open, so another tab picked (a click, Ctrl+Tab, Ctrl+Shift+Tab) ends the window
// with Status (its values checked first, as OK), the tab picked in "tab", and the Lisp shows
// the window of that tab. Every tab is kept at the one place and size (tab/place), and the
// window of the tab left stays on the screen until the next one is drawn over it (Modal), so
// the window never closes between two tabs.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
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

        // Another tab picked: the window ends with Status (its values checked first, as OK;
        // when one is not valid it stays on its tab), and stays on the screen, its place
        // saved, until the window of the tab picked is shown over it (Modal.Keep):
        static void Pick(View view, Session s, int cur, int index)
        {
            if (index == cur) return;
            s.Values.TryGetValue("tab", out string before);
            s.Values["tab"] = index.ToString(CultureInfo.InvariantCulture);
            var host = view.Window.Content as TabHost;
            if (!view.EndWith(Status, () => host?.Leaving?.Invoke()))
            {
                if (before == null) s.Values.Remove("tab"); else s.Values["tab"] = before;
            }
        }

        // The window of this tab is left (Fit.cs saves its place, so the next tab opens there):
        internal Action Leaving;
    }

    // How a window with tabs is shown over AutoCAD: modal, as ShowDialog (the other windows
    // of AutoCAD disabled until it is closed), but a window of a tab left is not closed: its
    // modal loop ends, the Lisp gets its values (and saves them) while it stays on the
    // screen, disabled, and the window of the next tab is shown over it, at the same place,
    // without the animation of Windows; the window left is closed once the next one is drawn.
    // When the Lisp shows no other window (an error, the Manager ended), the window left is
    // closed when AutoCAD is idle again (Bridge.cs). So the window never seems to close
    // between two tabs, and AutoCAD stays disabled the whole time.
    public static class Modal
    {
        // The windows of AutoCAD a window disabled, enabled again when it closes, unless it
        // handed them to the window of the next tab (List null):
        sealed class Disabled { public List<IntPtr> List; }

        static Window _kept;
        static Disabled _disabled;
        static IntPtr _owner;
        static DispatcherFrame _frame;
        static Window _shown;
        static bool _keep;

        public static bool Kept => _kept != null;

        // Shows w over the window owner (AutoCAD) until it is closed, or ended by Keep:
        internal static void Show(Window w, IntPtr owner)
        {
            var old = _kept;
            var disabled = new Disabled();
            if (old != null)
            {
                // the windows of AutoCAD stay disabled (handed to this window); the window left
                // is closed once this one is drawn:
                disabled.List = _disabled?.List ?? new List<IntPtr>();
                if (_disabled != null) _disabled.List = null;
                // (and one enabled again meanwhile: a message of the Lisp, alert, enables
                // AutoCAD as it closes)
                disabled.List.AddRange(DisableThread());
                _kept = null;
                _disabled = null;
                w.ContentRendered += (a, b) => CloseQuiet(old);
                w.Closed += (a, b) => CloseQuiet(old);
            }
            else
            {
                disabled.List = DisableThread();
                _owner = owner;
            }
            if (_owner != IntPtr.Zero) new WindowInteropHelper(w).Owner = _owner;
            w.SourceInitialized += (a, b) => NoAnimation(w);
            // the windows of AutoCAD enabled again before the window goes (so AutoCAD is
            // active again, not another program), unless it is only left for another tab:
            w.Closing += (a, b) => { if (!b.Cancel) Restore(disabled); };
            var frame = new DispatcherFrame();
            w.Closed += (a, b) => frame.Continue = false;
            var outer = (_frame, _shown, _keep);
            _frame = frame;
            _shown = w;
            _keep = false;
            try
            {
                w.Show();
                Dispatcher.PushFrame(frame);
            }
            catch
            {
                if (old != null) CloseQuiet(old);
                Restore(disabled);
                throw;
            }
            finally
            {
                bool keep = _keep && w.IsVisible;
                (_frame, _shown, _keep) = outer;
                if (keep)
                {
                    _kept = w;
                    _disabled = disabled;
                    // nothing clicked while the Lisp works:
                    var h = new WindowInteropHelper(w).Handle;
                    if (h != IntPtr.Zero) EnableWindow(h, false);
                }
            }
        }

        // Ends the modal loop of w, its window left on the screen (another tab picked). False
        // when w is not shown by Show:
        internal static bool Keep(Window w)
        {
            if (_shown != w || _frame == null) return false;
            _keep = true;
            _frame.Continue = false;
            return true;
        }

        // The window left closed, the windows of AutoCAD enabled again (the Lisp showed no
        // other window, or shows a window without tabs):
        public static void Close()
        {
            var w = _kept;
            var disabled = _disabled;
            _kept = null;
            _disabled = null;
            Restore(disabled);
            if (w == null) return;
            CloseQuiet(w);
            try { if (_owner != IntPtr.Zero) SetForegroundWindow(_owner); } catch { }
        }

        static void CloseQuiet(Window w)
        {
            try { w.Close(); } catch { }
        }

        // Every window of AutoCAD shown and enabled (its main window, its floating palettes)
        // disabled, as ShowDialog does:
        static List<IntPtr> DisableThread()
        {
            var list = new List<IntPtr>();
            try
            {
                EnumThreadWindows(GetCurrentThreadId(), (h, l) =>
                {
                    if (IsWindowVisible(h) && IsWindowEnabled(h)) { EnableWindow(h, false); list.Add(h); }
                    return true;
                }, IntPtr.Zero);
            }
            catch { }
            return list;
        }

        static void Restore(Disabled d)
        {
            var list = d?.List;
            if (list == null) return;
            d.List = null;
            foreach (var h in list)
                try { if (IsWindow(h)) EnableWindow(h, true); } catch { }
        }

        // No animation when the window opens and closes (DWMWA_TRANSITIONS_FORCEDISABLED):
        static void NoAnimation(Window w)
        {
            try
            {
                var h = new WindowInteropHelper(w).Handle;
                int on = 1;
                if (h != IntPtr.Zero) DwmSetWindowAttribute(h, 3, ref on, sizeof(int));
            }
            catch { }
        }

        delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);

        [DllImport("user32.dll")] static extern bool EnumThreadWindows(uint thread, EnumProc proc, IntPtr lParam);
        [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool IsWindowEnabled(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool EnableWindow(IntPtr hwnd, bool enable);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hwnd);
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    }
}
