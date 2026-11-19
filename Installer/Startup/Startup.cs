// Startup.cs - DynALisp.Startup: the clean startup of the command line
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
// Clean startup (Overrides of Dyl-Settings, the DynalispCleanStartup user setting, off by
// default): once AutoCAD has started (DynALisp loaded, no command running and the command
// line quiet for 2 seconds), the lines AutoCAD and its verticals printed while starting
// (Loading AEC..., Customization file loaded..., the palettes and startup commands of the
// workspace) are removed from the command line. Kept: the "Drawing created using..." line,
// the lines of DynALisp (DynALisp loaded..., -->) and every line that reports an error or a
// warning. The F2 text window keeps the whole log.
//
// AutoCAD has no API for this: the lines are blanked in the list the command line shows
// (CommandLineViewModel.HistoryCollection of AcWindows.dll, a view of the native history,
// found by reflection; the same in AutoCAD 2015, 2026 and 2027), the lines kept moved to
// its end. In a version where it is not found, or is not a list, nothing is done. Built for
// .NET 8 (AutoCAD 2025 and later) and .NET Framework 4.8 (AutoCAD 2015 to 2024), see
// DynALisp.Startup.csproj.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Windows.Threading;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: ExtensionApplication(typeof(DynALisp.Startup.Plugin))]
[assembly: CommandClass(typeof(DynALisp.Startup.Plugin))]

namespace DynALisp.Startup
{
    public class Plugin : IExtensionApplication
    {
        const string Setting = "DynalispCleanStartup";
        const int Quiet = 2000;          // ms without a new line, no command running
        const int WaitDynALisp = 30000;  // ms to wait for "DynALisp loaded" (then clean anyway)
        const int GiveUp = 120000;       // ms after which nothing is done

        static DispatcherTimer _timer;
        static int _start, _changed, _count = -1;

        public void Initialize()
        {
            try
            {
                if (!On()) return;
                _start = _changed = Environment.TickCount;
                // A timer on the thread of AutoCAD (its WPF dispatcher): the Idle event
                // is not raised again while nothing happens, the timer is.
                _timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromMilliseconds(500) };
                _timer.Tick += OnTick;
                _timer.Start();
            }
            catch { }
        }

        public void Terminate() { }

        // (Dyl:CleanStartup): T, the plugin is loaded. Dyl-Settings greys out Clean startup
        // when it is not defined (an AutoCAD older than 2015).
        [LispFunction("Dyl:CleanStartup")]
        public static object CleanStartup(ResultBuffer args) => true;

        // The user setting (setenv / getenv: the FixedProfile\General key of the profile):
        static bool On()
        {
            string root = HostApplicationServices.Current.UserRegistryProductRootKey;
            using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General"))
                return key != null && (key.GetValue(Setting) as string) == "1";
        }

        static void Stop()
        {
            if (_timer == null) return;
            _timer.Stop();
            _timer.Tick -= OnTick;
            _timer = null;
        }

        static void OnTick(object sender, EventArgs e)
        {
            try
            {
                int now = Environment.TickCount;
                if (now - _start > GiveUp) { Stop(); return; }
                var doc = AcApp.DocumentManager.MdiActiveDocument;
                if (doc == null) return;
                bool quiet = doc.Editor.IsQuiescent;
                var hist = History(out IList temp);
                if (hist == null) return;
                // the startup goes on while lines come or a command runs:
                if (!quiet || hist.Count != _count) { _count = hist.Count; _changed = now; return; }
                if (now - _changed < Quiet) return;
                bool loaded = hist.Cast<object>().Any(it => Text(it).TrimStart().StartsWith("DynALisp loaded", StringComparison.OrdinalIgnoreCase));
                if (!loaded && now - _start < WaitDynALisp) return;
                Stop();
                Clean(hist, temp);
            }
            catch { Stop(); }
        }

        // The lines of the command line (and the temporary lines shown over a floating
        // command line), nil while it is not made yet or in a version where they are not found:
        static IList History(out IList temp)
        {
            temp = null;
            var asm = AppDomain.CurrentDomain.GetAssemblies()
                .FirstOrDefault(a => string.Equals(a.GetName().Name, "AcWindows", StringComparison.OrdinalIgnoreCase));
            var t = asm?.GetType("Autodesk.AutoCAD.ViewModel.CommandLine.CommandLineViewModel");
            if (t == null) return null;
            const BindingFlags all = BindingFlags.Static | BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
            // the instance AutoCAD made (Instance would make one while it is not there yet):
            object vm = t.GetField("mInstance", all)?.GetValue(null);
            if (vm == null && t.GetField("mInstance", all) == null) vm = t.GetProperty("Instance", all)?.GetValue(null, null);
            if (vm == null) return null;
            temp = t.GetProperty("TempPromptCollection", all)?.GetValue(vm, null) as IList;
            return t.GetProperty("HistoryCollection", all)?.GetValue(vm, null) as IList;
        }

        // The text of a line (CommandHistory.Command):
        static string Text(object it)
        {
            if (it == null) return "";
            var p = it.GetType().GetProperty("Command", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            return (p?.GetValue(it, null) as string) ?? it.ToString() ?? "";
        }

        static readonly string[] Reports =
        {
            "error", "warning", "exception", "failed", "unable", "cannot", "can't", "not found",
            "invalid", "unknown command", "missing",
        };

        // A line kept: the drawing created, the lines of DynALisp, an error or a warning.
        static bool Keep(string t)
        {
            string l = (t ?? "").Trim().ToLowerInvariant();
            if (l.StartsWith("command:")) l = l.Substring(8).Trim();
            if (l == "") return false;
            return l.Contains("drawing created using")
                   || l.StartsWith("dynalisp") || l.StartsWith("dyl-settings to change") || l.StartsWith("-->")
                   || Reports.Any(r => l.Contains(r));
        }

        // The lines kept go to the end of the list (the command line shows its last lines),
        // in their order, the others become blank lines before them. The list keeps its
        // number of lines: AutoCAD adds the next lines from its native history after that
        // number (CommandEditor.UpdateHistory), so a shorter list would get the old lines
        // back. The native history itself cannot be cleaned (setMaxLineCount leaves it).
        static void Clean(IList hist, IList temp)
        {
            if (hist.IsReadOnly || hist.IsFixedSize || hist.Count == 0) return;
            var items = hist.Cast<object>().ToList();
            var kept = items.Where(it => Keep(Text(it))).ToList();
            if (kept.Count == items.Count) return;
            // every blank line made before the list is changed (nothing changed if one fails):
            var blanks = new List<object>();
            for (int i = kept.Count; i < items.Count; i++)
            {
                object b = Blank(items[0].GetType());
                if (b == null) return;
                blanks.Add(b);
            }
            hist.Clear();
            foreach (var b in blanks) hist.Add(b);
            foreach (var k in kept) hist.Add(k);
            if (temp != null && !temp.IsReadOnly && !temp.IsFixedSize) temp.Clear();
        }

        // A blank line: a CommandHistory of "" (its constructor is internal):
        static object Blank(Type t)
        {
            var ctor = t.GetConstructor(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, new[] { typeof(string) }, null);
            return ctor?.Invoke(new object[] { "" });
        }
    }
}
