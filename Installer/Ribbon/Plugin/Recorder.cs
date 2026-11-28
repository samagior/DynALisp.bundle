// Recorder.cs - DynALisp.Ribbon: a recording in the background, for a bug that comes and goes
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
// Pst-DiagnosticsRecord (DIAG-RECORD) starts it, (Dyl:RibbonRecord "Start"): while the user
// works, for minutes or hours, what AutoCAD and the plugin do is written to a text file of
// %TEMP%\DynALisp Diagnostics, a few lines at a time (nothing is lost if AutoCAD stops):
//   - once a minute, a summary: the drawing current, the time the plugin worked and its
//     longest steps, the Idle events of AutoCAD and the longest time without one, the times
//     AutoCAD did not answer (a thread of its own puts a call on its dispatcher every 50 ms,
//     as the test of Work.cs), the changes of the cursor, the commands run;
//   - at once, each time AutoCAD did not answer for 300 ms or more, with the command running
//     and the steps of the plugin in that time; the commands of 1 s or more; the drawings
//     opened, made current and closed (a time without Idle is only in the summary: AutoCAD
//     gives none while nothing happens, so it is no sign of a bug alone);
//   - each time the user clicks Bug now: a mark, with what the last 15 s were made of.
// While it records, a red badge stays over AutoCAD (top right, it can be dragged): REC, the
// time it has recorded, Bug now and Stop. Stop (or DIAG-RECORD again) ends it, writes the
// summary of the whole recording and opens the file. AutoCAD closed ends it too. The file
// names the drawings by their file name only, never their folder (it may be sent in a public
// GitHub issue, as the reports of Dyl-Diagnostics).

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Markup;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    // The Lisp function of the recording (see LangCommands: a static class cannot hold it).
    public class RecordCommands
    {
        // (Dyl:RibbonRecord "Start"): starts it, returns the file. (Dyl:RibbonRecord "Stop"):
        // ends it, returns the file (nil when none ran). (Dyl:RibbonRecord "Mark"): a mark.
        // (Dyl:RibbonRecord): the file while it records, nil when it does not.
        [LispFunction("Dyl:RibbonRecord")]
        public static object RibbonRecord(ResultBuffer args)
        {
            try
            {
                string which = args?.AsArray().Select(v => v.Value as string).FirstOrDefault(v => v != null);
                if (string.Equals(which, "Start", StringComparison.OrdinalIgnoreCase)) return Recorder.Begin();
                if (string.Equals(which, "Stop", StringComparison.OrdinalIgnoreCase)) return Recorder.Stop(false);
                if (string.Equals(which, "Mark", StringComparison.OrdinalIgnoreCase)) { Recorder.Mark(); return Recorder.File; }
                return Recorder.File;
            }
            catch (System.Exception ex) { return "error: " + ex.Message; }
        }
    }

    public static class Recorder
    {
        public static bool On { get; private set; }
        public static string File { get; private set; }

        static readonly Stopwatch Clock = Stopwatch.StartNew();
        static long Ms(long ticks) => ticks * 1000 / Stopwatch.Frequency;
        static long Now => Clock.ElapsedTicks;
        static long Ticks(int ms) => Stopwatch.Frequency * ms / 1000;

        const int Ping = 50, Stall = 300, SlowCommand = 1000, Recent = 15000;

        static DateTime _began;
        static DispatcherTimer _timer;
        static int _seconds;
        static readonly List<string> Pending = new();

        // ---- what the plugin did: each step (Work.Add calls Step while it records) ----

        sealed class Agg { public int Count; public long Ticks; }
        static readonly Dictionary<string, Agg> Minute = new(StringComparer.Ordinal);
        static readonly Dictionary<string, Agg> Whole = new(StringComparer.Ordinal);
        static readonly Queue<(long At, long Ticks, string Name)> Last = new();
        static long _lastIdle = -1, _noIdleMinute;
        static int _idlesMinute;

        public static void Step(string name, long ticks)
        {
            if (_ui != null && !_ui.CheckAccess()) return;
            long at = Now - ticks;
            Add(Minute, name, ticks);
            Add(Whole, name, ticks);
            Last.Enqueue((at, ticks, name));
            while (Last.Count > 0 && Last.Peek().At < Now - Ticks(Recent)) Last.Dequeue();
            if (name == "AutoCAD idle (events)")
            {
                long now = Now;
                if (_lastIdle >= 0)
                {
                    long gap = now - _lastIdle;
                    if (gap > _noIdleMinute) _noIdleMinute = gap;
                }
                _lastIdle = now;
                _idlesMinute++;
            }
        }

        static void Add(Dictionary<string, Agg> d, string name, long ticks)
        {
            if (!d.TryGetValue(name, out var a)) d[name] = a = new Agg();
            a.Count++;
            a.Ticks += ticks;
        }

        // The command running and the steps of the plugin of 5 ms or more between two times:
        static string During(long from, long to)
        {
            var steps = Last.Where(l => l.At + l.Ticks >= from && l.At <= to && Ms(l.Ticks) >= 5)
                            .GroupBy(l => l.Name).Select(g => g.Key + " " + Ms(g.Sum(x => x.Ticks)) + " ms").ToList();
            return (_command != null ? ", during " + _command : "")
                 + "; steps of the plugin in it: " + (steps.Count == 0 ? "none" : string.Join(", ", steps));
        }

        // ---- the stalls and the cursor, watched by threads of their own ----

        static Dispatcher _ui;
        static volatile bool _run;
        static Thread _pinger, _watcher;
        static readonly ConcurrentQueue<(long At, long Ticks)> Stalls = new();
        static int _stallsMinute, _cursorMinute, _answers;
        static long _stallMaxMinute;
        static int _stallsWhole, _cursorWhole, _marks;
        static long _stallMaxWhole;

        static void Pinger()
        {
            while (_run)
            {
                long sent = Now;
                var done = new ManualResetEventSlim();
                try { _ui.BeginInvoke(DispatcherPriority.Send, new Action(() => done.Set())); }
                catch { break; }
                while (_run && !done.Wait(1000)) { }
                long waited = Now - sent;
                Interlocked.Increment(ref _answers);
                if (Ms(waited) >= 100) Stalls.Enqueue((sent, waited));
                Thread.Sleep(Ping);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        struct CURSORINFO { public int cbSize, flags; public IntPtr hCursor; public int x, y; }
        [DllImport("user32.dll")] static extern bool GetCursorInfo(ref CURSORINFO pci);

        static void Watcher()
        {
            IntPtr last = IntPtr.Zero;
            bool first = true;
            while (_run)
            {
                var ci = new CURSORINFO { cbSize = Marshal.SizeOf<CURSORINFO>() };
                if (GetCursorInfo(ref ci))
                {
                    IntPtr now = (ci.flags & 1) == 0 ? IntPtr.Zero : ci.hCursor;
                    if (!first && now != last) Interlocked.Increment(ref _cursorMinute);
                    last = now;
                    first = false;
                }
                Thread.Sleep(5);
            }
        }

        // ---- the drawings and the commands ----

        static readonly HashSet<Document> Watched = new();
        static string _command;
        static long _commandAt;
        static int _commandsMinute, _commandsWhole;

        static string NameOf(Document d)
        {
            try { return Path.GetFileName(d?.Name ?? "") is string n && n != "" ? n : "?"; }
            catch { return "?"; }
        }

        static int Docs()
        {
            int n = 0;
            try { foreach (var _ in AcApp.DocumentManager) n++; } catch { }
            return n;
        }

        static void OnCreated(object s, DocumentCollectionEventArgs e) { Watch(e.Document); Line("drawing opened: " + NameOf(e.Document) + " (" + Docs() + " open)"); }
        static void OnCurrent(object s, DocumentCollectionEventArgs e) { Watch(e.Document); Line("drawing made current: " + NameOf(e.Document)); }
        static void OnClosing(object s, DocumentCollectionEventArgs e) { Line("drawing closed: " + NameOf(e.Document)); Unwatch(e.Document); }
        static void OnQuit(object s, EventArgs e) { try { Stop(false); } catch { } }

        static void Watch(Document d)
        {
            if (d == null || !Watched.Add(d)) return;
            d.CommandWillStart += OnStart;
            d.CommandEnded += OnEnd;
            d.CommandCancelled += OnEnd;
            d.CommandFailed += OnEnd;
        }

        static void Unwatch(Document d)
        {
            if (d == null || !Watched.Remove(d)) return;
            try
            {
                d.CommandWillStart -= OnStart;
                d.CommandEnded -= OnEnd;
                d.CommandCancelled -= OnEnd;
                d.CommandFailed -= OnEnd;
            }
            catch { }
        }

        static void OnStart(object s, CommandEventArgs e)
        {
            _command = e.GlobalCommandName;
            _commandAt = Now;
            _commandsMinute++;
            _commandsWhole++;
        }

        static void OnEnd(object s, CommandEventArgs e)
        {
            if (_command != null && Ms(Now - _commandAt) >= SlowCommand)
                Line("command " + e.GlobalCommandName + ": " + (Ms(Now - _commandAt) / 1000.0).ToString("0.0") + " s");
            _command = null;
        }

        // ---- the file ----

        static void Line(string text) => Pending.Add(DateTime.Now.ToString("HH:mm:ss") + "  " + text);

        static void Flush()
        {
            if (File == null || Pending.Count == 0) return;
            try { System.IO.File.AppendAllLines(File, Pending); Pending.Clear(); }
            catch { if (Pending.Count > 5000) Pending.RemoveRange(0, Pending.Count - 5000); }
        }

        static string Env(string name)
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General");
                return key?.GetValue(name) as string;
            }
            catch { return null; }
        }

        public static string Begin()
        {
            if (On) return File;
            _ui = Dispatcher.CurrentDispatcher;
            string dir = Path.Combine(Path.GetTempPath(), "DynALisp Diagnostics");
            Directory.CreateDirectory(dir);
            _began = DateTime.Now;
            File = Path.Combine(dir, "Recording " + _began.ToString("yyyy-MM-dd HHmmss") + ".txt");
            Minute.Clear(); Whole.Clear(); Last.Clear(); Pending.Clear();
            while (Stalls.TryDequeue(out _)) { }
            _lastIdle = -1; _noIdleMinute = 0; _idlesMinute = 0; _seconds = 0;
            _stallsMinute = _cursorMinute = _answers = 0; _stallMaxMinute = 0;
            _stallsWhole = _cursorWhole = _marks = _commandsMinute = _commandsWhole = 0; _stallMaxWhole = 0;
            var v = AcApp.Version;
            System.IO.File.WriteAllLines(File, new[]
            {
                "DynALisp recording - started " + _began.ToString("yyyy-MM-dd HH:mm:ss"),
                "AutoCAD " + v.Major + "." + v.Minor + ", " + Docs() + " drawing(s) open, the current one " + NameOf(AcApp.DocumentManager.MdiActiveDocument),
                "Display " + (Env("DynalispDisplayOn") == "1" ? "on" : "off") + ", Interface " + (Env("DynalispInterface") ?? "-")
                    + ", File tabs " + (Env("DynalispFileTabColors") ?? "-") + ", parts of the plugin " + Work.PartsOff(),
                "Each minute: a summary. At once: AutoCAD not answering for " + Stall + " ms or more,",
                "the commands of " + SlowCommand / 1000 + " s or more, the drawings opened and closed, and each Bug now you clicked.",
                "",
            });
            On = true;
            var dm = AcApp.DocumentManager;
            foreach (Document d in dm) Watch(d);
            dm.DocumentCreated += OnCreated;
            dm.DocumentBecameCurrent += OnCurrent;
            dm.DocumentToBeDestroyed += OnClosing;
            AcApp.BeginQuit += OnQuit;
            _run = true;
            _pinger = new Thread(Pinger) { IsBackground = true, Name = "DynALisp recording" };
            _pinger.Start();
            _watcher = new Thread(Watcher) { IsBackground = true, Name = "DynALisp recording cursor" };
            _watcher.Start();
            _timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromSeconds(1) };
            _timer.Tick += OnSecond;
            _timer.Start();
            Badge.Show();
            return File;
        }

        // Each second: the stalls come in, the badge shows the time; each minute, a summary.
        static void OnSecond(object s, EventArgs e)
        {
            _seconds++;
            Drain();
            Badge.Time(DateTime.Now - _began);
            if (_seconds % 60 == 0) Summary();
            Flush();
        }

        static void Drain()
        {
            while (Stalls.TryDequeue(out var st))
            {
                _stallsMinute++; _stallsWhole++;
                if (st.Ticks > _stallMaxMinute) _stallMaxMinute = st.Ticks;
                if (st.Ticks > _stallMaxWhole) _stallMaxWhole = st.Ticks;
                if (Ms(st.Ticks) >= Stall) Line("AutoCAD did not answer for " + Ms(st.Ticks) + " ms" + During(st.At, st.At + st.Ticks));
            }
        }

        static void Summary()
        {
            int cursor = Interlocked.Exchange(ref _cursorMinute, 0);
            _cursorWhole += cursor;
            long work = Minute.Values.Sum(a => a.Ticks);
            var top = Minute.Where(kv => kv.Value.Ticks > 0).OrderByDescending(kv => kv.Value.Ticks).Take(3)
                            .Select(kv => kv.Key + " " + Ms(kv.Value.Ticks) + " ms").ToList();
            Line("[minute] " + NameOf(AcApp.DocumentManager.MdiActiveDocument) + " (" + Docs() + " open)"
                 + " | plugin " + Ms(work) + " ms" + (top.Count > 0 ? " (" + string.Join(", ", top) + ")" : "")
                 + " | " + _idlesMinute + " Idle, the longest without " + Ms(_noIdleMinute) + " ms"
                 + " | not answering 100 ms+ " + _stallsMinute + " x" + (_stallsMinute > 0 ? ", the longest " + Ms(_stallMaxMinute) + " ms" : "")
                 + " | cursor changed " + cursor + " x | " + _commandsMinute + " command(s)");
            Minute.Clear();
            _idlesMinute = 0; _noIdleMinute = 0; _stallsMinute = 0; _stallMaxMinute = 0; _commandsMinute = 0;
        }

        // The user felt the bug: a mark, and what the last 15 s were made of.
        public static void Mark()
        {
            if (!On) return;
            _marks++;
            Drain();
            long from = Now - Ticks(Recent);
            var steps = Last.Where(l => l.At >= from).GroupBy(l => l.Name)
                            .Select(g => (g.Key, Ms(g.Sum(x => x.Ticks)), g.Count())).OrderByDescending(x => x.Item2).ToList();
            Line("");
            Line("*** BUG NOW #" + _marks + " (marked by you) in " + NameOf(AcApp.DocumentManager.MdiActiveDocument) + ", " + Docs() + " drawing(s) open"
                 + (_command != null ? ", command " + _command : "") + " ***");
            Line("    the last 15 s: " + _idlesMinute + " Idle this minute, the longest without " + Ms(_noIdleMinute) + " ms, cursor changed "
                 + _cursorMinute + " x this minute; steps of the plugin:");
            foreach (var (name, ms, n) in steps.Take(12)) Line("      " + (ms + " ms").PadLeft(8) + "  " + n.ToString().PadLeft(6) + " x  " + name);
            if (steps.Count == 0) Line("      none");
            Line("");
            Flush();
            Badge.Marked();
        }

        public static string Stop(bool open)
        {
            if (!On) return null;
            On = false;
            _run = false;
            try { _timer?.Stop(); } catch { }
            _timer = null;
            Drain();
            Summary();
            var span = DateTime.Now - _began;
            long work = Whole.Values.Sum(a => a.Ticks);
            Line("");
            Line("Ended after " + span.ToString(@"h\:mm\:ss") + ": " + _marks + " Bug now, AutoCAD not answering 100 ms+ " + _stallsWhole + " x"
                 + (_stallsWhole > 0 ? " (the longest " + Ms(_stallMaxWhole) + " ms)" : "") + ", cursor changed " + _cursorWhole + " x, "
                 + _commandsWhole + " command(s).");
            Line("The plugin worked " + Ms(work) + " ms in all; its steps, the longest first:");
            foreach (var kv in Whole.OrderByDescending(kv => kv.Value.Ticks).ThenByDescending(kv => kv.Value.Count).Take(25))
                Line("    " + (Ms(kv.Value.Ticks) + " ms").PadLeft(9) + "  " + kv.Value.Count.ToString().PadLeft(8) + " x  " + kv.Key);
            Flush();
            var dm = AcApp.DocumentManager;
            try
            {
                dm.DocumentCreated -= OnCreated;
                dm.DocumentBecameCurrent -= OnCurrent;
                dm.DocumentToBeDestroyed -= OnClosing;
                AcApp.BeginQuit -= OnQuit;
            }
            catch { }
            foreach (var d in Watched.ToList()) Unwatch(d);
            Badge.Close();
            string file = File;
            File = null;
            if (open) try { Process.Start(new ProcessStartInfo(file) { UseShellExecute = true }); } catch { }
            return file;
        }

        // ---- the badge ----

        static class Badge
        {
            static Window _w;
            static TextBlock _time, _note;

            static bool French => (Env("DynalispLanguage") ?? (T.Lang == "fr" ? "French" : "English")) == "French";
            static string S(string en, string fr) => French ? fr : en;

            const string Xaml = @"<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Background='#C62828' CornerRadius='15' Padding='12,5,6,5' Cursor='SizeAll'>
  <Border.Resources>
    <Style TargetType='Button'>
      <Setter Property='Foreground' Value='White'/>
      <Setter Property='Cursor' Value='Hand'/>
      <Setter Property='Template'>
        <Setter.Value>
          <ControlTemplate TargetType='Button'>
            <Border x:Name='b' Background='#33FFFFFF' CornerRadius='10' Padding='10,3' Margin='6,0,0,0'>
              <ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center'/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property='IsMouseOver' Value='True'><Setter TargetName='b' Property='Background' Value='#66FFFFFF'/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Border.Resources>
  <StackPanel Orientation='Horizontal' TextElement.FontFamily='Segoe UI' TextElement.FontSize='12' TextElement.Foreground='White'>
    <Ellipse Name='dot' Width='10' Height='10' Fill='White' VerticalAlignment='Center' Margin='0,0,8,0'/>
    <TextBlock Text='REC' FontWeight='Bold' VerticalAlignment='Center' Margin='0,0,8,0'/>
    <TextBlock Name='time' Text='0:00:00' VerticalAlignment='Center' Margin='0,0,4,0'/>
    <TextBlock Name='note' VerticalAlignment='Center' Margin='4,0,0,0'/>
    <Button Name='mark'/>
    <Button Name='stop'/>
  </StackPanel>
</Border>";

            [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
            [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect r);
            [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
            const uint SWP_NOSIZE = 0x1, SWP_NOZORDER = 0x4, SWP_NOACTIVATE = 0x10;

            public static void Show()
            {
                try
                {
                    var root = (Border)XamlReader.Parse(Xaml);
                    _time = (TextBlock)root.FindName("time");
                    _note = (TextBlock)root.FindName("note");
                    var mark = (Button)root.FindName("mark");
                    var stop = (Button)root.FindName("stop");
                    mark.Content = S("Bug now", "Bogue maintenant");
                    stop.Content = S("Stop", "Arrêter");
                    mark.Click += (s, e) => { try { Recorder.Mark(); } catch { } };
                    stop.Click += (s, e) => { try { Recorder.Stop(true); } catch { } };
                    root.ToolTip = S("DynALisp is recording what AutoCAD and DynALisp do, to find a bug that comes and goes. Click Bug now when you feel it. Stop (or DIAG-RECORD) ends the recording and opens its file.",
                                     "DynALisp enregistre ce que font AutoCAD et DynALisp, pour trouver un bogue intermittent. Cliquez Bogue maintenant quand vous le sentez. Arrêter (ou DIAG-RECORD) termine l'enregistrement et ouvre son fichier.");
                    var dot = (System.Windows.Shapes.Ellipse)root.FindName("dot");
                    dot.BeginAnimation(UIElement.OpacityProperty,
                        new DoubleAnimation(1, 0.2, TimeSpan.FromMilliseconds(700)) { AutoReverse = true, RepeatBehavior = RepeatBehavior.Forever });
                    var w = new Window
                    {
                        WindowStyle = WindowStyle.None,
                        ResizeMode = ResizeMode.NoResize,
                        AllowsTransparency = true,
                        Background = System.Windows.Media.Brushes.Transparent,
                        ShowInTaskbar = false,
                        ShowActivated = false,
                        SizeToContent = SizeToContent.WidthAndHeight,
                        Title = "DynALisp recording",
                        Content = root,
                    };
                    root.MouseLeftButtonDown += (s, e) => { if (!(e.OriginalSource is DependencyObject o && Inside<Button>(o))) try { w.DragMove(); } catch { } };
                    IntPtr main = AcApp.MainWindow.Handle;
                    new WindowInteropHelper(w) { Owner = main };
                    w.Loaded += (s, e) =>
                    {
                        // Top right of AutoCAD, under the title bar and the ribbon, in the pixels of its screen:
                        try
                        {
                            var hwnd = new WindowInteropHelper(w).Handle;
                            if (GetWindowRect(main, out var r) && GetWindowRect(hwnd, out var me))
                                SetWindowPos(hwnd, IntPtr.Zero, r.Right - (me.Right - me.Left) - 60, r.Top + 190, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
                        }
                        catch { }
                    };
                    w.Show();
                    _w = w;
                }
                catch (System.Exception ex) { Host.Log("recording badge: " + ex.Message); }
            }

            static bool Inside<TParent>(DependencyObject o) where TParent : DependencyObject
            {
                for (var n = o; n != null; n = n is System.Windows.Media.Visual ? System.Windows.Media.VisualTreeHelper.GetParent(n) ?? LogicalTreeHelper.GetParent(n) : LogicalTreeHelper.GetParent(n))
                    if (n is TParent) return true;
                return false;
            }

            public static void Time(TimeSpan t) { if (_time != null) _time.Text = t.ToString(@"h\:mm\:ss"); }

            static DispatcherTimer _clear;

            public static void Marked()
            {
                if (_note == null) return;
                _note.Text = S("marked", "noté") + " ✓";
                _clear?.Stop();
                _clear = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
                _clear.Tick += (s, e) => { _clear.Stop(); if (_note != null) _note.Text = ""; };
                _clear.Start();
            }

            public static void Close()
            {
                try { _w?.Close(); } catch { }
                _w = null; _time = null; _note = null;
            }
        }
    }
}
