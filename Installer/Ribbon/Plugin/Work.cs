// Work.cs - DynALisp.Ribbon: what the plugin does while AutoCAD is slow (a diagnostic)
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
// The plugin works when AutoCAD is idle and on timers of its dispatcher (the colours of the
// interface, the file tabs, the drop-downs of the ribbon), none of it seen by the reactor
// events of Pst-DiagnosticsReactorEvents. Each of those steps is timed here, always (a
// Stopwatch read, nothing more), and (Dyl:RibbonWork "Start") starts a test: the counts are
// set back to 0, and a thread of its own asks the thread of AutoCAD every 25 ms to answer,
// which shows each moment AutoCAD did not answer for 100 ms or more (a stall: a pan or a
// zoom that jerks). (Dyl:RibbonWork) ends the test and gives the report, one string a line:
// the stalls, the steps of the plugin by their time, and those that ran during a stall.
// During the test, another thread reads the cursor of Windows every 5 ms (GetCursorInfo): each
// time it changes (a cursor that blinks during a pan) is listed with the steps of the plugin
// that ended just before it.
//
// (Dyl:RibbonWork "Off" "<part>") turns a part of the plugin off at once and (Dyl:RibbonWork
// "On" "<part>") back on, to find which one slows AutoCAD: "idle" (the Idle event of AutoCAD
// no longer handled), the parts of the colours of the interface, their colours given back to
// AutoCAD ("themes": the ribbon and the palettes, "native": the palettes in C++, "cpp": the
// lists, buttons and title bar in C++, "hosted": the file tabs and the palettes with a theme
// of their own, "web": the Start page; "colours" for the five), "filetabs" (the bands of the
// file tabs), "ribbon" (the drop-downs and the translation of the tab), "timers" (the timers
// of the colours stopped), "commands" (nothing done at the end of a command), "all". The
// parts off are kept in DynalispRibbonOff, so a slowness that comes and goes can be watched
// for a whole session or more, until they are turned on again. (Dyl:RibbonWork "Parts") gives
// the parts turned off.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Threading;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    // The Lisp function of the test (see LangCommands: a static class cannot hold it).
    public class WorkCommands
    {
        // (Dyl:RibbonWork "Start"): starts the test, returns T. (Dyl:RibbonWork): ends it and
        // returns the report, a list of strings (nil when no test was started).
        [LispFunction("Dyl:RibbonWork")]
        public static object RibbonWork(ResultBuffer args)
        {
            try
            {
                string which = args?.AsArray().Select(v => v.Value as string).FirstOrDefault(v => v != null);
                if (string.Equals(which, "Start", StringComparison.OrdinalIgnoreCase)) { Work.Begin(); return true; }
                if (string.Equals(which, "Off", StringComparison.OrdinalIgnoreCase) || string.Equals(which, "On", StringComparison.OrdinalIgnoreCase))
                {
                    var part = args.AsArray().Skip(1).Select(v => v.Value as string).FirstOrDefault(v => v != null);
                    return Work.Switch(part, string.Equals(which, "Off", StringComparison.OrdinalIgnoreCase));
                }
                if (string.Equals(which, "Parts", StringComparison.OrdinalIgnoreCase)) return Work.PartsOff();
                var lines = Work.End();
                if (lines == null) return null;
                var rb = new ResultBuffer();
                foreach (var l in lines) rb.Add(new TypedValue((int)LispDataType.Text, l));
                return rb;
            }
            catch (System.Exception ex) { return "error: " + ex.Message; }
        }
    }

    public static class Work
    {
        sealed class Stat { public int Count; public long Ticks, Max; }

        static readonly Dictionary<string, Stat> Stats = new(StringComparer.Ordinal);
        static readonly Stopwatch Clock = Stopwatch.StartNew();
        static long _since;
        static bool _testing;

        // The steps of 5 ms or more during a test, to find those that ran in a stall:
        static readonly List<(long At, long Ticks, string Name)> Long = new();
        const int LongMax = 5000;

        static long Ms(long ticks) => ticks * 1000 / Stopwatch.Frequency;

        // ---- the parts turned off for a test ----

        public static readonly string[] Colours = { "themes", "native", "cpp", "hosted", "web" };
        public static readonly string[] Parts = { "idle", "themes", "native", "cpp", "hosted", "web", "filetabs", "ribbon", "timers", "commands" };
        static readonly HashSet<string> Off = new(StringComparer.OrdinalIgnoreCase);
        const string Setting = "DynalispRibbonOff";

        public static bool IsOff(string part) => Off.Contains(part);

        public static string PartsOff() => Off.Count == 0 ? "none off" : string.Join(" ", Parts.Where(Off.Contains)) + " off";

        // The parts left off by a former session, turned off as the plugin loads (before Host.Start):
        static void ReadOff()
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General");
                foreach (var p in ((key?.GetValue(Setting) as string) ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries))
                    if (Parts.Contains(p, StringComparer.OrdinalIgnoreCase)) Off.Add(p);
            }
            catch { }
        }

        static void WriteOff()
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(root + @"\FixedProfile\General");
                key?.SetValue(Setting, string.Join(" ", Parts.Where(Off.Contains)));
            }
            catch { }
        }

        // Returns the parts turned off after the change, or what the parts are:
        public static string Switch(string part, bool off)
        {
            var which = string.Equals(part, "all", StringComparison.OrdinalIgnoreCase) ? Parts
                : string.Equals(part, "colours", StringComparison.OrdinalIgnoreCase) ? Colours
                : Parts.Where(p => string.Equals(p, part, StringComparison.OrdinalIgnoreCase)).ToArray();
            if (which.Length == 0) return "parts: " + string.Join(" ", Parts) + " colours all";
            foreach (var p in which)
            {
                if (off) Off.Add(p); else Off.Remove(p);
                if (p == "idle") Host.Listen(!off);
                if (p == "timers") { Skin.Timer(!off); WebPages.Timer(!off); }
            }
            WriteOff();
            // The colours put on or given back at the next idle:
            Skin.Due();
            return PartsOff();
        }

        // One step timed (and counted), what it throws thrown again:
        public static void Time(string name, Action step)
        {
            long t0 = Clock.ElapsedTicks;
            try { step(); }
            finally { Add(name, Clock.ElapsedTicks - t0, t0); }
        }

        // One time a thing happened (an event, a window repainted):
        public static void Count(string name) => Add(name, 0, Clock.ElapsedTicks);

        // Every step during a test (its end), to find those just before a change of the cursor:
        static readonly List<(long End, string Name)> Ends = new();
        const int EndsMax = 300000;

        static void Add(string name, long ticks, long at)
        {
            if (!Stats.TryGetValue(name, out var s)) Stats[name] = s = new Stat();
            s.Count++;
            s.Ticks += ticks;
            if (ticks > s.Max) s.Max = ticks;
            if (Recorder.On) Recorder.Step(name, ticks);
            if (!_testing) return;
            if (Ms(ticks) >= 5 && Long.Count < LongMax) Long.Add((at, ticks, name));
            if (Ends.Count < EndsMax) lock (Ends) Ends.Add((at + ticks, name));
        }

        // ---- the cursor ----

        [StructLayout(LayoutKind.Sequential)]
        struct CURSORINFO { public int cbSize, flags; public IntPtr hCursor; public int x, y; }
        [DllImport("user32.dll")] static extern bool GetCursorInfo(ref CURSORINFO pci);
        [DllImport("user32.dll")] static extern IntPtr LoadCursor(IntPtr hInstance, IntPtr name);

        static Thread _watcher;
        static readonly List<(long At, IntPtr From, IntPtr To)> Cursors = new();
        static readonly Dictionary<IntPtr, string> CursorNames = new();

        static string CursorName(IntPtr h)
        {
            if (CursorNames.Count == 0)
                foreach (var (id, n) in new[] { (32512, "arrow"), (32513, "I-beam"), (32514, "wait"), (32515, "cross"), (32516, "up arrow"),
                                                 (32642, "size NW-SE"), (32643, "size NE-SW"), (32644, "size W-E"), (32645, "size N-S"),
                                                 (32646, "size all"), (32648, "no"), (32649, "hand"), (32650, "arrow and wait"), (32651, "help") })
                {
                    var c = LoadCursor(IntPtr.Zero, (IntPtr)id);
                    if (c != IntPtr.Zero) CursorNames[c] = n;
                }
            if (h == IntPtr.Zero) return "hidden";
            return CursorNames.TryGetValue(h, out var name) ? name : "cursor 0x" + h.ToInt64().ToString("X");
        }

        static void Watch()
        {
            IntPtr last = IntPtr.Zero;
            bool first = true;
            while (_ping)
            {
                var ci = new CURSORINFO { cbSize = Marshal.SizeOf<CURSORINFO>() };
                if (GetCursorInfo(ref ci))
                {
                    IntPtr now = (ci.flags & 1) == 0 ? IntPtr.Zero : ci.hCursor;
                    if (!first && now != last)
                        lock (Cursors) if (Cursors.Count < 20000) Cursors.Add((Clock.ElapsedTicks, last, now));
                    last = now;
                    first = false;
                }
                Thread.Sleep(5);
            }
        }

        // ---- the stalls: the thread of AutoCAD not answering ----

        static Dispatcher _ui;
        static Thread _pinger;
        static volatile bool _ping;
        static readonly object Lock = new();
        static readonly List<(long At, long Ticks)> Stalls = new();
        static long _worst, _answers;
        const int Every = 25, Stall = 100;

        // Called on the thread of AutoCAD when the plugin loads:
        public static void Start()
        {
            _ui = Dispatcher.CurrentDispatcher;
            ReadOff();
        }

        // What was left off, once each part has started (Plugin.Initialize):
        public static void Started()
        {
            if (Off.Contains("idle")) Host.Listen(false);
            if (Off.Contains("timers")) { Skin.Timer(false); WebPages.Timer(false); }
        }

        public static void Begin()
        {
            Stats.Clear();
            Long.Clear();
            lock (Ends) Ends.Clear();
            lock (Cursors) Cursors.Clear();
            lock (Lock) { Stalls.Clear(); _worst = 0; _answers = 0; }
            _since = Clock.ElapsedTicks;
            _testing = true;
            if (_ui == null || _pinger != null) return;
            _ping = true;
            _pinger = new Thread(Ping) { IsBackground = true, Name = "DynALisp work test" };
            _pinger.Start();
            _watcher = new Thread(Watch) { IsBackground = true, Name = "DynALisp cursor test" };
            _watcher.Start();
        }

        // Every 25 ms, a call put on the dispatcher of AutoCAD: the time it waited is the time
        // AutoCAD did not read its messages (busy drawing, or in code of its own or of a plugin).
        static void Ping()
        {
            while (_ping)
            {
                long sent = Clock.ElapsedTicks;
                var done = new ManualResetEventSlim();
                try { _ui.BeginInvoke(DispatcherPriority.Send, new Action(() => done.Set())); }
                catch { break; }
                // Waited for as long as it takes (a stall of several seconds is a stall too):
                while (_ping && !done.Wait(1000)) { }
                long waited = Clock.ElapsedTicks - sent;
                lock (Lock)
                {
                    _answers++;
                    if (waited > _worst) _worst = waited;
                    if (Ms(waited) >= Stall && Stalls.Count < 10000) Stalls.Add((sent, waited));
                }
                Thread.Sleep(Every);
            }
        }

        public static List<string> End()
        {
            if (!_testing) return null;
            _testing = false;
            _ping = false;
            _pinger?.Join(2000);
            _pinger = null;
            _watcher?.Join(1000);
            _watcher = null;
            long span = Clock.ElapsedTicks - _since;
            List<(long At, long Ticks)> stalls;
            long worst, answers;
            lock (Lock) { stalls = Stalls.ToList(); worst = _worst; answers = _answers; }
            var r = new List<string>();
            int docs = 0;
            try { foreach (var _ in AcApp.DocumentManager) docs++; } catch { }
            r.Add("DynALisp.Ribbon.dll, during the test (" + (Ms(span) / 1000.0).ToString("0.0") + " s, " + docs + " drawing(s) open):");
            long stallMs = stalls.Sum(s => Ms(s.Ticks));
            r.Add("  AutoCAD did not answer for 100 ms or more " + stalls.Count + " time(s), " + (stallMs / 1000.0).ToString("0.0")
                  + " s in all; the longest " + Ms(worst) + " ms (" + answers + " checks)");
            // The time of the plugin, the longest first:
            long total = Stats.Values.Sum(s => s.Ticks);
            r.Add("  The plugin worked " + Ms(total) + " ms in all (" + (span > 0 ? (100.0 * total / span).ToString("0.0") : "0") + " % of the test). Its steps, the longest first:");
            foreach (var kv in Stats.OrderByDescending(kv => kv.Value.Ticks).ThenByDescending(kv => kv.Value.Count))
            {
                var s = kv.Value;
                r.Add(s.Ticks == 0
                    ? "    " + s.Count.ToString().PadLeft(6) + " x  " + kv.Key
                    : "    " + (Ms(s.Ticks) + " ms").PadLeft(9) + "  " + s.Count.ToString().PadLeft(6) + " x, longest " + Ms(s.Max) + " ms  " + kv.Key);
            }
            if (Stats.Count == 0) r.Add("    none");
            // The stalls, each with the steps of 5 ms or more that ran in it:
            if (stalls.Count > 0)
            {
                r.Add("  The stalls (the 40 longest), from the start of the test, and the steps of the plugin of 5 ms or more in each:");
                foreach (var st in stalls.OrderByDescending(s => s.Ticks).Take(40).OrderBy(s => s.At))
                {
                    var inIt = Long.Where(l => l.At + l.Ticks >= st.At && l.At <= st.At + st.Ticks).ToList();
                    string what = inIt.Count == 0 ? "none of the plugin"
                        : string.Join(", ", inIt.GroupBy(l => l.Name).Select(g => g.Key + " " + Ms(g.Sum(x => x.Ticks)) + " ms"));
                    r.Add("    at " + (Ms(st.At - _since) / 1000.0).ToString("0.00").PadLeft(6) + " s, " + (Ms(st.Ticks) + " ms").PadLeft(7) + ": " + what);
                }
            }
            Cursor(r);
            return r;
        }

        // The changes of the cursor, and the steps that ended in the 40 ms before each:
        static void Cursor(List<string> r)
        {
            List<(long At, IntPtr From, IntPtr To)> changes;
            List<(long End, string Name)> ends;
            lock (Cursors) changes = Cursors.ToList();
            lock (Ends) ends = Ends.OrderBy(e => e.End).ToList();
            r.Add("  The cursor changed " + changes.Count + " time(s) during the test" + (changes.Count == 0 ? "." : ", the most frequent first:"));
            foreach (var g in changes.GroupBy(c => CursorName(c.From) + " -> " + CursorName(c.To)).OrderByDescending(g => g.Count()).Take(12))
                r.Add("    " + g.Count().ToString().PadLeft(6) + " x  " + g.Key);
            if (changes.Count < 2) return;
            // How often: the time between two changes (a rhythm tells which timer).
            var gaps = changes.Zip(changes.Skip(1), (a, b) => Ms(b.At - a.At)).OrderBy(x => x).ToList();
            r.Add("  Time between two changes: median " + gaps[gaps.Count / 2] + " ms, shortest " + gaps[0] + " ms, longest " + gaps[^1] + " ms");
            long window = Stopwatch.Frequency * 40 / 1000;
            var before = new Dictionary<string, int>(StringComparer.Ordinal);
            int none = 0;
            foreach (var c in changes)
            {
                // The first step that ended in the window (the ends sorted), then the others after it:
                int lo = 0, hi = ends.Count;
                while (lo < hi) { int mid = (lo + hi) / 2; if (ends[mid].End < c.At - window) lo = mid + 1; else hi = mid; }
                var names = new List<string>();
                for (int k = lo; k < ends.Count && ends[k].End <= c.At; k++)
                    if (!names.Contains(ends[k].Name)) names.Add(ends[k].Name);
                if (names.Count == 0) none++;
                foreach (var n in names) before[n] = before.GetValueOrDefault(n) + 1;
            }
            r.Add("  The steps of the plugin that ended in the 40 ms before a change of the cursor (changes / runs of the step):");
            foreach (var kv in before.OrderByDescending(kv => kv.Value))
                r.Add("    " + kv.Value.ToString().PadLeft(6) + " / " + (Stats.TryGetValue(kv.Key, out var s) ? s.Count : 0).ToString().PadRight(6) + " " + kv.Key);
            r.Add("    " + none.ToString().PadLeft(6) + " change(s) with no step of the plugin just before");
            // The first changes, as they came:
            r.Add("  The first 30 changes, from the start of the test:");
            foreach (var c in changes.Take(30))
                r.Add("    at " + (Ms(c.At - _since) / 1000.0).ToString("0.000").PadLeft(7) + " s  " + CursorName(c.From) + " -> " + CursorName(c.To));
        }
    }
}
