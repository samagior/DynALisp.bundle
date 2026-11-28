// SheetSets.cs - DynALisp.Startup: the sheet sets open in the Sheet Set Manager, opened again
// at the next startup
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
// Reopen sheet sets (Overrides of Dyl-Settings, the DynalispSheetSetReopen user setting, off
// by default): the Sheet Set Manager of AutoCAD forgets the sheet sets (.dst) it had open
// when AutoCAD closes. While the setting is on, the plugin keeps the list of the sheet sets
// open in it (the DynalispSheetSets user setting of this computer, the paths divided by |)
// and opens them again when AutoCAD starts, until the user closes them in the manager.
//
//   - What is open is read from the sheet set manager of AutoCAD (AcSmSheetSetMgr, the
//     COM object of the Sheet Set Manager, one for the whole session: its open databases,
//     GetDatabaseEnumerator), called through its type library (SheetSetMgr.cs: its objects
//     have no IDispatch, so no late binding), and written when a command
//     ends, a drawing is made current or closed, and when AutoCAD quits: a sheet set the
//     user closed in the manager is no longer open at the next of them, so it is forgotten.
//   - At startup, once a drawing is open and AutoCAD has been idle for 2 seconds, each sheet
//     set remembered is opened with the command of AutoCAD (OPENSHEETSET, FILEDIA 0, so it
//     asks for its file at the command line), which loads it into the palette. One that is
//     still not open then is opened in the manager itself (OpenDatabase). A file that no
//     longer exists is dropped, and said on the command line; one that exists but could not
//     be opened is kept for the next startup.
//   - Only the sheet sets the user opened are remembered: the manager also holds those
//     another part of AutoCAD loaded without the palette (the sheet set of the current
//     project of the Project Navigator of AutoCAD Architecture). They are the ones whose
//     database is an item of the list of the palette (SheetSetPalette.cs); when the palette
//     cannot tell (not made in this session, or another version of AutoCAD), every sheet
//     set of the manager but those beside a project (a .apj in their folder).
//   - Nothing is written before the sheet sets are opened again: AutoCAD closed before
//     that (or started without a drawing and closed) keeps the list as it was.
// (Dyl:SheetSets) says what it did, (Dyl:SheetSets "Open") lists the sheet sets open in the
// manager now, (Dyl:SheetSets "Save") writes them at once (the setting just turned on),
// (Dyl:SheetSets "Tree") writes what it finds of the palette (SheetSetPalette.cs).

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows.Threading;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Startup
{
    public class SheetSets
    {
        const string Setting = "DynalispSheetSetReopen";
        const string ListSetting = "DynalispSheetSets";
        const int Quiet = 2000;      // ms idle, no command running, before they are opened
        const int Verify = 1000;     // ms idle after the command, before they are checked

        static DispatcherTimer _timer;
        static int _phase;           // 0 waiting for a drawing, 1 the command sent, 2 done
        static int _quietSince = Environment.TickCount;
        static bool _ready;          // the list may be written (the sheet sets reopened)
        static bool _quitting;       // AutoCAD quits: the list is kept as it was written
        static string _status = "off";
        static List<string> _asked = new List<string>();   // sent to OPENSHEETSET
        static readonly List<string> _kept = new List<string>();  // could not be opened: kept
        static readonly HashSet<Document> Watched = new HashSet<Document>();

        public static void Start()
        {
            var dm = AcApp.DocumentManager;
            dm.DocumentBecameCurrent += (s, e) => { Watch(e.Document); Save(); };
            dm.DocumentToBeDestroyed += (s, e) => { Watched.Remove(e.Document); Save(); };
            foreach (Document d in dm) Watch(d);
            // Written once as AutoCAD quits, then no more while it closes its drawings (the
            // manager may close its sheet sets before the last one), again if the quit is cancelled:
            AcApp.BeginQuit += (s, e) => { Save(); _quitting = true; };
            AcApp.QuitAborted += (s, e) => _quitting = false;
            if (!On()) { _ready = true; return; }
            _status = "waiting for a drawing";
            // A timer on the thread of AutoCAD (its WPF dispatcher), as the clean startup: the
            // Idle event is not raised again while nothing happens, the timer is.
            _timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromMilliseconds(500) };
            _timer.Tick += OnTick;
            _timer.Start();
        }

        static void Watch(Document d)
        {
            if (d == null || !Watched.Add(d)) return;
            d.CommandEnded += (s, e) => Save();
            d.CommandCancelled += (s, e) => Save();
            d.CommandFailed += (s, e) => Save();
        }

        // ---- the settings (setenv / getenv: the FixedProfile\General key of the profile) ----

        static string Key => HostApplicationServices.Current.UserRegistryProductRootKey + @"\FixedProfile\General";

        static string Get(string name)
        {
            using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(Key))
                return key?.GetValue(name) as string;
        }

        static void Set(string name, string value)
        {
            using (var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(Key))
                key?.SetValue(name, value ?? "");
        }

        static bool On() => Get(Setting) == "1";

        static List<string> Remembered() =>
            (Get(ListSetting) ?? "").Split('|').Select(p => p.Trim()).Where(p => p != "").ToList();

        // ---- the sheet set manager of AutoCAD ----

        static string _mgrError;

        // The files of the sheet sets open in the manager, without the same file twice, in its
        // order; null when it cannot be read (SheetSetMgr.cs, _mgrError says why):
        static List<string> Open()
        {
            try
            {
                var lst = new List<string>();
                foreach (var f in SheetSetMgr.OpenFiles())
                    if (!lst.Any(x => Same(x, f))) lst.Add(f);
                _mgrError = null;
                return lst;
            }
            catch (System.Exception ex) { _mgrError = (ex.InnerException ?? ex).Message; return null; }
        }

        static bool Same(string a, string b)
        {
            try { return string.Equals(Path.GetFullPath(a), Path.GetFullPath(b), StringComparison.OrdinalIgnoreCase); }
            catch { return string.Equals(a, b, StringComparison.OrdinalIgnoreCase); }
        }

        static bool BesideProject(string f)
        {
            try { return Directory.GetFiles(Path.GetDirectoryName(f), "*.apj").Length > 0; }
            catch { return false; }
        }

        static bool IsOpen(List<string> open, string f) => open != null && open.Any(x => Same(x, f));

        // ---- the list remembered ----

        // Write the sheet sets open now (and those that could not be opened at startup), once
        // they were opened again, only while the setting is on and only when it changed:
        static void Save()
        {
            try
            {
                if (!_ready || _quitting || !On()) return;
                var open = Open();
                if (open == null) return;
                // Only the sheet sets the user opened: those the palette shows. When it cannot
                // tell, those of the manager, but a sheet set beside a project of the Project
                // Navigator (a .apj in its folder), which loads it without the palette:
                HashSet<string> shown = null;
                try { shown = SheetSetPalette.Shown(SheetSetMgr.OpenDbs()); } catch { }
                open = open.Where(f => shown != null ? shown.Contains(f) : !BesideProject(f)).ToList();
                var lst = new List<string>();
                // the order remembered first, then the ones opened since:
                foreach (var f in Remembered().Concat(open))
                    if ((IsOpen(open, f) || _kept.Any(k => Same(k, f))) && !lst.Any(x => Same(x, f))) lst.Add(f);
                string val = string.Join("|", lst);
                if (val != (Get(ListSetting) ?? "")) Set(ListSetting, val);
            }
            catch { }
        }

        static void Stop()
        {
            if (_timer == null) return;
            _timer.Stop();
            _timer.Tick -= OnTick;
            _timer = null;
        }

        static void Say(string msg)
        {
            try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n" + msg); } catch { }
        }

        static void OnTick(object sender, EventArgs e)
        {
            try
            {
                int now = Environment.TickCount;
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                if (doc == null || !doc.Editor.IsQuiescent) { _quietSince = now; return; }
                if (_phase == 0 && now - _quietSince >= Quiet) Reopen(doc);
                else if (_phase == 1 && now - _quietSince >= Verify) Check();
            }
            catch (System.Exception ex) { Done("error: " + ex.Message); }
        }

        // The sheet sets remembered, opened by OPENSHEETSET at the command line:
        static void Reopen(Document doc)
        {
            if (!On()) { Done("off"); return; }
            var open = Open();
            if (open == null) { Done("the sheet set manager cannot be reached: " + _mgrError); return; }
            var missing = new List<string>();
            _asked = new List<string>();
            foreach (var f in Remembered())
            {
                if (!File.Exists(f)) missing.Add(f);
                else if (!IsOpen(open, f)) _asked.Add(f);
            }
            foreach (var f in missing) Say("DynALisp: sheet set not found, no longer reopened: " + f);
            _dropped = missing.Count;
            if (_asked.Count == 0) { Done(null); return; }
            // FILEDIA 0: the command asks for the file at the command line; CMDECHO 0: quietly.
            string files = string.Join(" ", _asked.Select(f => "\"" + f.Replace("\\", "\\\\").Replace("\"", "") + "\""));
            string lisp = "(progn (setq *dyl:ssreopen* (list (getvar \"FILEDIA\") (getvar \"CMDECHO\")))"
                        + " (setvar \"FILEDIA\" 0) (setvar \"CMDECHO\" 0)"
                        + " (foreach f (list " + files + ") (vl-catch-all-apply 'command-s (list \"_.OPENSHEETSET\" f)))"
                        + " (setvar \"FILEDIA\" (car *dyl:ssreopen*)) (setvar \"CMDECHO\" (cadr *dyl:ssreopen*))"
                        + " (setq *dyl:ssreopen* nil) (princ))\n";
            _phase = 1;
            _quietSince = Environment.TickCount;
            _status = "opening " + _asked.Count + " sheet set(s)";
            doc.SendStringToExecute(lisp, true, false, false);
        }

        static int _dropped, _byManager;

        // After the command: a sheet set it did not open is opened in the manager itself; one
        // that still cannot be opened is kept for the next startup:
        static void Check()
        {
            var open = Open() ?? new List<string>();
            foreach (var f in _asked)
            {
                if (IsOpen(open, f)) continue;
                try { SheetSetMgr.OpenDatabase(f); _byManager++; }
                catch (System.Exception ex)
                {
                    _kept.Add(f);
                    Say("DynALisp: sheet set not reopened (" + (ex.InnerException ?? ex).Message + "): " + f);
                }
            }
            Done(null);
        }

        static void Done(string status)
        {
            Stop();
            _phase = 2;
            _ready = true;
            int n = _asked.Count - _kept.Count;
            _status = status ?? (n + " sheet set(s) reopened at startup"
                                 + (_byManager > 0 ? " (" + _byManager + " by the manager, not OPENSHEETSET)" : "")
                                 + (_kept.Count > 0 ? ", " + _kept.Count + " could not be opened (kept)" : "")
                                 + (_dropped > 0 ? ", " + _dropped + " not found (dropped)" : ""));
            if (status == null && n > 0) Say("DynALisp: " + _status + ".");
            Save();
        }

        // (Dyl:SheetSets): what the plugin did, as a text. (Dyl:SheetSets "Open"): the files of
        // the sheet sets open in the manager now (nil when it cannot be reached).
        // (Dyl:SheetSets "Save"): the list written at once (the setting just turned on).
        [LispFunction("Dyl:SheetSets")]
        public static object Lisp(ResultBuffer args)
        {
            var all = args?.AsArray();
            string what = all != null && all.Length > 0 ? all[0].Value as string : null;
            if (string.Equals(what, "Open", StringComparison.OrdinalIgnoreCase))
            {
                var open = Open();
                if (open == null) return "error: " + _mgrError;
                if (open.Count == 0) return null;
                return new ResultBuffer(open.Select(f => new TypedValue((int)LispDataType.Text, f)).ToArray());
            }
            // The palette as the plugin finds it, written to %TEMP%\DynALisp-SheetSets.txt:
            if (string.Equals(what, "Tree", StringComparison.OrdinalIgnoreCase))
            {
                try { return SheetSetPalette.Tree(); }
                catch (System.Exception ex) { return "error: " + ex.Message; }
            }
            if (string.Equals(what, "Save", StringComparison.OrdinalIgnoreCase))
            {
                // not while the sheet sets remembered are still to be opened again:
                if (_timer == null) _ready = true;
                Save();
            }
            if (!On()) return "off";
            return _status == "off" ? "on since this session: reopened from the next startup" : _status;
        }
    }
}
