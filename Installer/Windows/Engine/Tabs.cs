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
// the window of that tab. Every tab is kept at the one place and size (tab/place). The window
// is modeless (Modeless below): AutoCAD stays free while it is open, and a button that needs
// the Lisp runs it at the command line, the window staying on the screen.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
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
            host.Current = cur;
            host.PickTab = k => Pick(view, s, cur, k);
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
        // when one is not valid it stays on its tab), the tab picked in "tab". A window shown
        // by Modeless stays open, its button given to the Lisp; any other closes:
        static void Pick(View view, Session s, int cur, int index)
        {
            if (index == cur) return;
            s.Values.TryGetValue("tab", out string before);
            s.Values["tab"] = index.ToString(CultureInfo.InvariantCulture);
            if (!view.CloseWith(Status))
            {
                if (before == null) s.Values.Remove("tab"); else s.Values["tab"] = before;
            }
        }

        // The tab shown, and the tab index picked as with a click (a command that opens the
        // Manager on another tab while it is open, Modeless):
        internal int Current;
        internal Action<int> PickTab;

        // The window of this tab is left (Fit.cs saves its place, so the next tab opens there):
        internal Action Leaving;
    }

    // The Manager is modeless: the user draws while it is open. Nothing calls the Lisp back
    // while a window is open, so each call of (Dyl:Window file values) on a window with tabs
    // (the Lisp gives "tab/event", the expression that runs the tab again) is one step:
    //
    //   - no window open: the window is shown, without a modal loop, and the call returns nil
    //     at once (the Lisp of the tab ends, the command ends: AutoCAD is free);
    //   - a button that needs the Lisp clicked (another tab, Save, OK, Draw, an open button):
    //     the window stays on the screen, disabled, and "tab/event" is run in the current
    //     drawing (Run, Bridge.cs: at the command line, the command running cancelled first).
    //     The Lisp of the tab runs again as it did when the window closed; its call of
    //     Dyl:Window on that window gets the button and the values of the window at once;
    //   - the Lisp shows a window with tabs again (the same tab on its new values, another
    //     tab): it is shown over the window, at its place, without the animation of Windows,
    //     and the window under it is closed once it is drawn; the call returns nil;
    //   - the Lisp is done (Dyl:WindowDone, Remote>>Dyl:ManagerEvent): a window whose button
    //     the Lisp took and did not show again is closed (OK, Save, Draw);
    //   - asked again by a command while it is open: the tab asked is picked, as a click.
    //
    // Cancel, Escape and the close box close it with no Lisp. A sub-window opened by the
    // window (Win.Open) or by the Lisp is modal, as before.
    public static class Modeless
    {
        enum State { None, Open, Pending, Taken }

        static State _state;
        static View _view;
        static Session _session;
        static string _file;
        static int _status;
        static DispatcherTimer _timer;

        // Shows a window without a modal loop, over AutoCAD (Bridge.cs):
        public static Action<Window> ShowWindow;
        // Runs a Lisp expression in the current drawing (Bridge.cs); false when it cannot:
        public static Func<string, bool> Run;

        public static bool Shown => _view != null;

        // A window of the Lisp that is shown modeless: one with tabs and an expression to run
        // it again:
        public static bool Wants(Session s) =>
            ShowWindow != null && Run != null && s.Lists.TryGetValue("tab", out var t) && t != null && t.Count > 0
            && s.Values.TryGetValue("tab/event", out string e) && !string.IsNullOrEmpty(e);

        // The call of the Lisp on the window file path with the values of s (see above): the
        // session whose values answer it, with the button in status, or null (shown, nothing
        // to give back):
        public static Session Request(Session s, string path, out int status)
        {
            var got = Take(path, out status);
            if (got != null) return got;
            string full = Path.GetFullPath(path);
            switch (_state)
            {
                case State.Open when _view != null:
                    var host = _view.Window.Content as TabHost;
                    int want = Index(s);
                    if (host != null && want >= 0 && want != host.Current) host.PickTab?.Invoke(want);
                    else Activate(_view.Window);
                    return null;
                default:
                    Show(s, full);
                    return null;
            }
        }

        // The button clicked in the window of path, waiting for the Lisp its event ran: the
        // session whose values answer it, with the button in status, now taken; null when the
        // window of path waits for nothing. The Lisp of a tool asks it first (Dyl:WindowTake),
        // so a tool run again by a click does not make again all the values of a window it
        // would not show (Dyl:WinTaken of dynalisp.mnl):
        public static Session Take(string path, out int status)
        {
            status = 0;
            if (_state != State.Pending || _view == null || string.IsNullOrEmpty(path)) return null;
            if (!string.Equals(_file, Path.GetFullPath(path), StringComparison.OrdinalIgnoreCase)) return null;
            StopTimer();
            _state = State.Taken;
            status = _status;
            return _session;
        }

        // The Lisp is done with the button it took: the window closed when it was not shown again:
        public static void Done()
        {
            if (_state == State.Taken && _view != null) Close(_view.Window);
            else if (_state == State.Pending && _view != null) Free();
        }

        static int Index(Session s)
        {
            if (s.Values.TryGetValue("tab", out string v) && int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i)) return i;
            return -1;
        }

        // The window of path on the values of s, over the window shown (closed once it is drawn):
        static void Show(Session s, string full)
        {
            StopTimer();
            var old = _view;
            // (its place saved first: the new one opens there)
            (old?.Window.Content as TabHost)?.Leaving?.Invoke();
            var view = s.Open(full);
            var w = view.Window;
            string place = w.Content is TabHost h ? h.Place : Path.GetFileNameWithoutExtension(full);
            if (s.FitToScreen) Fit.Attach(w, place, s.Places);
            view.Intercept = st => Clicked(view, st);
            w.SourceInitialized += (a, b) => NoAnimation(w);
            w.Closed += (a, b) =>
            {
                if (_view != view) return;
                StopTimer();
                _view = null;
                _session = null;
                _file = null;
                _state = State.None;
            };
            _view = view;
            _session = s;
            _file = full;
            _state = State.Open;
            // Shown hidden until it is drawn (Reveal.cs), so the Manager never opens white; over
            // the window of the tab left, not active until then (that window would lose its
            // title bar), and that window closed in the moment it is shown: no blank window and
            // no blink between two tabs:
            if (old != null) w.ShowActivated = false;
            Reveal.Attach(w, old == null ? (Action)null : () => { Activate(w); Close(old.Window); });
            if (old != null) w.Closed += (a, b) => Close(old.Window);
            try { ShowWindow(w); }
            catch
            {
                if (old != null) Close(old.Window);
                throw;
            }
        }

        // A button that needs the Lisp clicked in the window: it stays open, disabled, and the
        // Lisp is run (false: not this window, closed as usual):
        static bool Clicked(View view, int status)
        {
            if (view != _view) return false;
            // (a click while the Lisp has the window: nothing)
            if (_state != State.Open) return true;
            if (!_session.Values.TryGetValue("tab/event", out string expr) || string.IsNullOrEmpty(expr)) return false;
            _status = status;
            _state = State.Pending;
            Enable(view.Window, false);
            bool sent;
            try { sent = Run(expr); } catch { sent = false; }
            if (!sent) { Free(); return true; }
            // (the Lisp never ran it: no drawing, AutoCAD busy; the window is given back)
            _timer = new DispatcherTimer(DispatcherPriority.Background, view.Window.Dispatcher) { Interval = TimeSpan.FromSeconds(30) };
            _timer.Tick += (a, b) => { if (_state == State.Pending) Free(); else StopTimer(); };
            _timer.Start();
            return true;
        }

        // The window given back to the user, its button dropped:
        static void Free()
        {
            StopTimer();
            _state = State.Open;
            if (_view != null) { Enable(_view.Window, true); Activate(_view.Window); }
        }

        static void StopTimer()
        {
            if (_timer == null) return;
            _timer.Stop();
            _timer = null;
        }

        static void Close(Window w)
        {
            try { w.Close(); } catch { }
        }

        static void Activate(Window w)
        {
            try
            {
                if (w.WindowState == WindowState.Minimized) w.WindowState = WindowState.Normal;
                w.Activate();
            }
            catch { }
        }

        static void Enable(Window w, bool on)
        {
            try
            {
                var h = new WindowInteropHelper(w).Handle;
                if (h != IntPtr.Zero) EnableWindow(h, on);
            }
            catch { }
        }

        // No animation when the window opens and closes (DWMWA_TRANSITIONS_FORCEDISABLED), so
        // a tab shown over another one does not seem to open:
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

        [DllImport("user32.dll")] static extern bool EnableWindow(IntPtr hwnd, bool enable);
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    }
}
