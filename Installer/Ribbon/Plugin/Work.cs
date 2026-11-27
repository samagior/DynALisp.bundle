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

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
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

        // One step timed (and counted), what it throws thrown again:
        public static void Time(string name, Action step)
        {
            long t0 = Clock.ElapsedTicks;
            try { step(); }
            finally { Add(name, Clock.ElapsedTicks - t0, t0); }
        }

        // One time a thing happened (an event, a window repainted):
        public static void Count(string name) => Add(name, 0, Clock.ElapsedTicks);

        static void Add(string name, long ticks, long at)
        {
            if (!Stats.TryGetValue(name, out var s)) Stats[name] = s = new Stat();
            s.Count++;
            s.Ticks += ticks;
            if (ticks > s.Max) s.Max = ticks;
            if (_testing && Ms(ticks) >= 5 && Long.Count < LongMax) Long.Add((at, ticks, name));
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
        public static void Start() => _ui = Dispatcher.CurrentDispatcher;

        public static void Begin()
        {
            Stats.Clear();
            Long.Clear();
            lock (Lock) { Stalls.Clear(); _worst = 0; _answers = 0; }
            _since = Clock.ElapsedTicks;
            _testing = true;
            if (_ui == null || _pinger != null) return;
            _ping = true;
            _pinger = new Thread(Ping) { IsBackground = true, Name = "DynALisp work test" };
            _pinger.Start();
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
            return r;
        }
    }
}
