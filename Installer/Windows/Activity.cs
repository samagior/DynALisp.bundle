// Activity.cs - DynALisp.Windows: the active time of each drawing, and the pins of the Start page
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
// Active time (Overrides of Dyl-Settings, under Start page: the DynalispActivity user setting,
// off by default, counted only while the Start page is on too): the time spent working in
// each drawing, shown on the Start page as a graph of the days of the year. A drawing is
// active while it is the current drawing of AutoCAD, AutoCAD is the application in front, and
// the mouse or the keyboard was used in the last 3 minutes; a drawing never saved (no folder
// yet) is not counted. A timer of 15 s adds the time since its last tick (at most a minute:
// AutoCAD busy or asleep is not counted twice); the time is written every 2 minutes, when a
// drawing closes and when AutoCAD quits.
//
// The time is kept on this computer only, in the User folder of DynALisp (never a report):
// User\Start\Activity\<yyyy-MM>.csv, a row per day and drawing, "Date;Seconds;Drawing". Two
// AutoCAD open write the same month: the file is read again under a lock just before it is
// written and the time of this session added to it, never written over.
//
// The pins of the Start page (drawings, sheet sets .dst, projects .apj), a path per line, in
// User\Start\Pinned.txt, at most 6, in their order.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Threading;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Windows.ActivityLisp))]

namespace DynALisp.Windows
{
    static class Activity
    {
        internal const string Setting = "DynalispActivity";
        const int TickMs = 15000, MaxStep = 60000, IdleMs = 180000, FlushMs = 120000;
        public const int MaxPins = 6;
        static readonly Encoding Utf8 = new UTF8Encoding(false);

        static DispatcherTimer _timer;
        static int _last = Environment.TickCount, _lastFlush = Environment.TickCount;
        static bool _on;
        static string _fail, _lastDrawing;
        static DateTime _lastWrite;
        static double _session;
        // The seconds not written yet, by day and drawing:
        static readonly Dictionary<(string Day, string Path), double> _pending = new Dictionary<(string, string), double>();

        internal static string Folder => Path.Combine(StartPage.Root(), "User", "Start");
        static string Dir => Path.Combine(Folder, "Activity");
        static string PinFile => Path.Combine(Folder, "Pinned.txt");

        public static void Init()
        {
            try
            {
                _timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromMilliseconds(TickMs) };
                _timer.Tick += (a, b) => Tick();
                _timer.Start();
                AcApp.DocumentManager.DocumentToBeDestroyed += (a, b) => Flush();
                AcApp.BeginQuit += (a, b) => Flush();
            }
            catch (System.Exception e) { _fail = e.Message; }
        }

        internal static bool On() => StartPage.Env(Setting) == "1" && StartPage.Env("DynalispStartPage") == "1";

        static void Tick()
        {
            try
            {
                int now = Environment.TickCount;
                int step = now - _last;
                _last = now;
                _on = On();
                if (!_on) { Flush(); return; }
                if (step <= 0 || step > MaxStep) step = TickMs;
                string dwg = ActiveDrawing();
                if (dwg != null && Foreground() && Idle() < IdleMs)
                {
                    var key = (DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), dwg);
                    _pending.TryGetValue(key, out double s);
                    _pending[key] = s + step / 1000.0;
                    _session += step / 1000.0;
                    _lastDrawing = dwg;
                }
                if (now - _lastFlush >= FlushMs) Flush();
            }
            catch (System.Exception e) { _fail = e.Message; }
        }

        // The current drawing, saved in a folder; null on the Start tab or a drawing never saved:
        static string ActiveDrawing()
        {
            if (StartPage.Showing()) return null;
            Document doc = null;
            try { doc = AcApp.DocumentManager.MdiActiveDocument; } catch { }
            string name = null;
            try { name = doc?.Name; } catch { }
            if (string.IsNullOrEmpty(name) || !Path.IsPathRooted(name)) return null;
            try { return Path.GetFullPath(name); } catch { return null; }
        }

        static bool Foreground()
        {
            IntPtr fg = GetForegroundWindow();
            if (fg == IntPtr.Zero) return false;
            GetWindowThreadProcessId(fg, out uint pid);
            return pid == (uint)Process.GetCurrentProcess().Id;
        }

        static long Idle()
        {
            var li = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO)) };
            if (!GetLastInputInfo(ref li)) return 0;
            return (uint)Environment.TickCount - li.dwTime;
        }

        // The whole seconds counted written to their month, added to what the file has (read
        // again under its lock: another AutoCAD may have written it); the fractions kept:
        internal static void Flush()
        {
            _lastFlush = Environment.TickCount;
            var whole = _pending.Where(kv => kv.Value >= 1).ToList();
            if (whole.Count == 0) return;
            try
            {
                Directory.CreateDirectory(Dir);
                foreach (var month in whole.GroupBy(kv => kv.Key.Day.Substring(0, 7)))
                {
                    string file = Path.Combine(Dir, month.Key + ".csv");
                    using (var fs = Lock(file))
                    {
                        var rows = Parse(new StreamReader(fs, Utf8, false, 4096, true).ReadToEnd());
                        foreach (var kv in month)
                        {
                            long add = (long)Math.Floor(kv.Value);
                            rows.TryGetValue(kv.Key, out long had);
                            rows[kv.Key] = had + add;
                            _pending[kv.Key] = kv.Value - add;
                        }
                        var sb = new StringBuilder("Date;Seconds;Drawing\r\n");
                        foreach (var r in rows.OrderBy(r => r.Key.Day, StringComparer.Ordinal).ThenBy(r => r.Key.Path, StringComparer.OrdinalIgnoreCase))
                            sb.Append(r.Key.Day).Append(';').Append(r.Value.ToString(CultureInfo.InvariantCulture)).Append(';').Append(r.Key.Path).Append("\r\n");
                        var bytes = Utf8.GetBytes(sb.ToString());
                        fs.Position = 0;
                        fs.SetLength(0);
                        fs.Write(bytes, 0, bytes.Length);
                    }
                }
                foreach (var k in _pending.Where(kv => kv.Value < 0.001).Select(kv => kv.Key).ToList()) _pending.Remove(k);
                _lastWrite = DateTime.Now;
                _cache.Clear();
            }
            catch (System.Exception e) { _fail = "writing: " + e.Message; }
        }

        // The file opened alone (another AutoCAD writing it: tried again for 2 s):
        static FileStream Lock(string file)
        {
            for (int i = 0; ; i++)
            {
                try { return new FileStream(file, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
                catch (IOException) when (i < 40) { Thread.Sleep(50); }
            }
        }

        static Dictionary<(string Day, string Path), long> Parse(string text)
        {
            var rows = new Dictionary<(string, string), long>();
            foreach (var line in text.Split('\n'))
            {
                var l = line.TrimEnd('\r');
                int a = l.IndexOf(';'), b = a < 0 ? -1 : l.IndexOf(';', a + 1);
                if (b < 0 || a != 10) continue;
                if (!long.TryParse(l.Substring(a + 1, b - a - 1), NumberStyles.Integer, CultureInfo.InvariantCulture, out long s)) continue;
                var key = (l.Substring(0, a), l.Substring(b + 1));
                rows.TryGetValue(key, out long had);
                rows[key] = had + s;
            }
            return rows;
        }

        // ---- read for the Start page ----

        static readonly Dictionary<string, (DateTime Time, long Size, Dictionary<(string Day, string Path), long> Rows)> _cache =
            new Dictionary<string, (DateTime, long, Dictionary<(string, string), long>)>(StringComparer.OrdinalIgnoreCase);

        // Every row kept (the months written, and the time of this session not written yet), as
        // the graph of the Start page takes them: date, seconds, drawing. Safe on another thread
        // only for the files: the time not written is read by the caller first (Pending).
        internal static List<string[]> Rows(Dictionary<(string Day, string Path), double> pending)
        {
            var all = new Dictionary<(string, string), long>();
            if (Directory.Exists(Dir))
                foreach (var file in Directory.GetFiles(Dir, "????-??.csv"))
                {
                    try
                    {
                        var fi = new FileInfo(file);
                        Dictionary<(string, string), long> rows;
                        lock (_cache)
                        {
                            if (_cache.TryGetValue(file, out var c) && c.Time == fi.LastWriteTimeUtc && c.Size == fi.Length) rows = c.Rows;
                            else
                            {
                                string text;
                                using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                                using (var sr = new StreamReader(fs, Utf8)) text = sr.ReadToEnd();
                                rows = Parse(text);
                                _cache[file] = (fi.LastWriteTimeUtc, fi.Length, rows);
                            }
                        }
                        foreach (var kv in rows) { all.TryGetValue(kv.Key, out long had); all[kv.Key] = had + kv.Value; }
                    }
                    catch { }
                }
            foreach (var kv in pending)
            {
                all.TryGetValue(kv.Key, out long had);
                all[kv.Key] = had + (long)kv.Value;
            }
            return all.Where(kv => kv.Value > 0)
                      .Select(kv => new[] { kv.Key.Item1, kv.Value.ToString(CultureInfo.InvariantCulture), kv.Key.Item2 })
                      .ToList();
        }

        internal static Dictionary<(string Day, string Path), double> Pending() => new Dictionary<(string, string), double>(_pending);

        // ---- the pins ----

        internal static List<string> Pins()
        {
            try
            {
                if (!File.Exists(PinFile)) return new List<string>();
                return File.ReadAllLines(PinFile, Utf8).Select(l => l.Trim()).Where(l => l.Length > 0)
                           .Distinct(StringComparer.OrdinalIgnoreCase).Take(MaxPins).ToList();
            }
            catch { return new List<string>(); }
        }

        // A path pinned (last), or unpinned; false when 6 are pinned already:
        internal static bool Pin(string path, bool on)
        {
            var pins = Pins();
            pins.RemoveAll(p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));
            if (on)
            {
                if (pins.Count >= MaxPins) return false;
                pins.Add(path);
            }
            Directory.CreateDirectory(Folder);
            File.WriteAllLines(PinFile, pins, Utf8);
            return true;
        }

        internal static bool Pinned(string path) => Pins().Any(p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));

        // ---- for (Dyl:Activity) ----

        internal static List<string> Report()
        {
            var r = new List<string>
            {
                "setting: " + (StartPage.Env(Setting) == "1" ? "on" : "off") + (StartPage.Env(Setting) == "1" && StartPage.Env("DynalispStartPage") != "1" ? " (not counted: the Start page is off)" : ""),
                "timer: " + (_timer != null && _timer.IsEnabled ? "running" : "not running"),
                "this session: " + Dur(_session) + (_lastDrawing != null ? ", last drawing " + Path.GetFileName(_lastDrawing) : ""),
                "written: " + (_lastWrite == DateTime.MinValue ? "not yet this session" : _lastWrite.ToString("HH:mm:ss", CultureInfo.InvariantCulture)),
            };
            try
            {
                var files = Directory.Exists(Dir) ? Directory.GetFiles(Dir, "????-??.csv") : new string[0];
                r.Add("files: " + files.Length + " month(s), " + (files.Sum(f => new FileInfo(f).Length) / 1024) + " KB");
            }
            catch { }
            r.Add("pinned: " + Pins().Count);
            if (_fail != null) r.Add("error: " + _fail);
            return r;
        }

        internal static string Dur(double seconds) => StartUi.Dur(seconds);

        [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
        [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO li);
        [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    }

    public class ActivityLisp
    {
        // (Dyl:Activity): what Active time does, a line each (Dyl-Diagnostics, Interface; no
        // path of the user in it); (Dyl:Activity "Apply"): the time counted written now (the
        // setting saved in Dyl-Settings).
        [LispFunction("Dyl:Activity")]
        public object Report(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                string what = a.Count > 0 ? a[0] as string : null;
                if (string.Equals(what, "Apply", StringComparison.OrdinalIgnoreCase)) { Activity.Flush(); StartPage.Apply(); return true; }
                var rb = new ResultBuffer();
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var l in Activity.Report()) rb.Add(new TypedValue((int)LispDataType.Text, l));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
                return rb;
            }
            catch (System.Exception e) { return "error: " + e.Message; }
        }
    }
}
