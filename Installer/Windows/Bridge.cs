// Bridge.cs - DynALisp.Windows: the Lisp function that shows a window, (Dyl:Window file values)
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
// (Dyl:Window file values) shows the window file (a .xaml of a Res folder, full path) over
// AutoCAD, modal, on the values ((key . value) ...):
//
//   ("rea" . "1")                 the value of a key, a string as set_tile takes it
//   ("lng/list" "English" ...)    the items of a list
//   ("csu/off" . "1")             the key greyed out (mode_tile 1)
//   ("mth/vals" "" "Polyline" ...) the values stored for the items of a list (its rules,
//                                 a preset window)
//   ("pst/rows" ("a" "b") ...)    rows of strings, a table (the presets of a preset window,
//                                 Engine\Presets.cs)
//   ("docs/Core\\Dyl-Settings.htm" . "https://...")   what the Open Docs button of the
//                                 window of that page opens (Dyl:WinShow gives them)
//
// It returns (status (key . value) ...): the button that closed it (0 Cancel, 1 OK / Save, or
// its Win.Close) and the value of every key, as get_tile gives it, then the tables the window
// gives back as (key row ...) (the presets edited: ("pst/rows" ("a" "b") ...)), nil when the
// window could not be shown (the reason on the command line). Called through Dyl:WinShow of
// dynalisp.mnl, which finds the file and the docs; the Lisp checks (if Dyl:Window ...) first.
//
// The window is the only thing running while it is open: no callback to the Lisp. A button
// that must run Lisp (a command, another window of the Lisp) closes it with its number
// (Win.Close), and the Lisp opens it again, as a DCL window does with done_dialog.
//
// A window with tabs given its event ("tab/event": the Manager) is modeless instead, so the
// user can draw while it is open (Modeless of Engine\Tabs.cs): Dyl:Window shows it and
// returns nil at once. A button that needs the Lisp leaves it open, disabled, and runs its
// event at the command line; the Lisp shows the window again, and that call returns the
// button and the values of the window (as a modal one would), then the window shown again
// replaces it in place. (Dyl:WindowDone) closes it when the Lisp did not show it again.
// (Dyl:WindowTake file) gives that button before the Lisp makes the values of the window.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: ExtensionApplication(typeof(DynALisp.Windows.Plugin))]
[assembly: CommandClass(typeof(DynALisp.Windows.Bridge))]

namespace DynALisp.Windows
{
    public class Plugin : IExtensionApplication
    {
        // The window files name this assembly by its name only (Win.*, OpenButton): found
        // here whatever folder AutoCAD loaded it from.
        public void Initialize()
        {
            AppDomain.CurrentDomain.AssemblyResolve += Resolve;
            // The windows with tabs (the Manager) are modeless (Engine\Tabs.cs): shown over
            // AutoCAD without a modal loop, and a button that needs the Lisp runs its event at
            // the command line of the current drawing (the command running cancelled first):
            // (shown without the size and the place AutoCAD keeps for its own windows: Fit.cs
            // places every window, a window of tabs the same way for every tab)
            Modeless.ShowWindow = w => AcApp.ShowModelessWindow(Bridge.MainWindow(), w, false);
            Modeless.Run = Run;
            // The dark windows in the colours of the Interface of Dyl-Settings > Display:
            Theme.LookOf = Bridge.InterfaceLook;
            // The Start page of DynALisp in the Start tab, while it is on (StartPage.cs):
            StartPage.Init();
            // The active time of each drawing, while it is on (Activity.cs):
            Activity.Init();
            // The previews chosen for the drawings of the Start page, made again at a save (Previews.cs):
            Previews.Init();
        }

        static bool Run(string expr)
        {
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            if (doc == null) return false;
            bool busy = false;
            try { busy = Convert.ToInt32(AcApp.GetSystemVariable("CMDACTIVE")) != 0; } catch { }
            doc.SendStringToExecute((busy ? "\x03\x03" : "") + expr + "\n", true, false, false);
            return true;
        }

        public void Terminate()
        {
            try { Activity.Flush(); } catch { }
        }

        // This assembly by its name; DynALisp.Core (the data of the windows that read it,
        // PresetTabs.cs) the one AutoCAD loaded, else the one beside this DLL:
        static Assembly Resolve(object sender, ResolveEventArgs e)
        {
            var me = typeof(Plugin).Assembly;
            string name = new AssemblyName(e.Name).Name;
            if (name == me.GetName().Name) return me;
            if (name != "DynALisp.Core") return null;
            var got = AppDomain.CurrentDomain.GetAssemblies().FirstOrDefault(x => x.GetName().Name == name);
            if (got != null) return got;
            try
            {
                string f = System.IO.Path.Combine(System.IO.Path.GetDirectoryName(me.Location) ?? "", name + ".dll");
                return System.IO.File.Exists(f) ? Assembly.LoadFrom(f) : null;
            }
            catch { return null; }
        }
    }

    public class Bridge
    {
        [LispFunction("Dyl:Window")]
        public object Window(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                string file = a.Count > 0 ? a[0] as string : null;
                if (string.IsNullOrEmpty(file)) throw new ArgumentException("(Dyl:Window file values): no file given");
                var s = new Session { ShowRoot = w => AcApp.ShowModalWindow(MainWindow(), w, false), Dark = DarkTheme(), FitToScreen = true, Places = new Places() };
                if (a.Count > 1 && a[1] is Lisp.List vals) Give(s, vals);
                // A window with tabs and its event: modeless (nil once shown), or the values
                // of the button that ran its event:
                if (Modeless.Wants(s))
                {
                    var got = Modeless.Request(s, file, out int st);
                    return got == null ? null : Result(got, st);
                }
                return Result(s, s.Show(file));
            }
            catch (System.Exception e)
            {
                try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n--> Unable to show the window: " + Message(e)); } catch { }
                return null;
            }
        }

        // The main window of AutoCAD, the owner of the windows shown:
        internal static IntPtr MainWindow()
        {
            try { return AcApp.MainWindow.Handle; }
            catch { return IntPtr.Zero; }
        }

        // (Dyl:WindowTake file): the button clicked in the modeless window of file and the
        // values of the window, as Dyl:Window gives them, when the Lisp its event ran asks for
        // them (Engine\Tabs.cs); nil when that window waits for nothing. Asked before the
        // values of the window are made (Dyl:WinTaken of dynalisp.mnl), it spares a tool run
        // again by a click making every value of a window it will not show.
        [LispFunction("Dyl:WindowTake")]
        public object Take(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                string file = a.Count > 0 ? a[0] as string : null;
                var got = Modeless.Take(file, out int st);
                return got == null ? null : Result(got, st);
            }
            catch { return null; }
        }

        // (Dyl:WindowDone): the Lisp is done with the button of a modeless window it took
        // (Engine\Tabs.cs): the window is closed when the Lisp did not show it again.
        [LispFunction("Dyl:WindowDone")]
        public object Done(ResultBuffer args)
        {
            try { Modeless.Done(); } catch { }
            return null;
        }

        // (status (key . value) ... (table row ...) ...) of the window of s:
        static ResultBuffer Result(Session s, int status)
        {
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Int16, (short)status));
            foreach (var kv in s.Values.Where(kv => kv.Key.IndexOf('/') < 0))
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                rb.Add(new TypedValue((int)LispDataType.Text, kv.Key));
                rb.Add(new TypedValue((int)LispDataType.Text, kv.Value ?? ""));
                rb.Add(new TypedValue((int)LispDataType.DottedPair));
            }
            foreach (var key in s.OutRows)
            {
                if (!s.Rows.TryGetValue(key, out var rows)) continue;
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                rb.Add(new TypedValue((int)LispDataType.Text, key));
                foreach (var row in rows)
                {
                    rb.Add(new TypedValue((int)LispDataType.ListBegin));
                    foreach (var cell in row) rb.Add(new TypedValue((int)LispDataType.Text, cell ?? ""));
                    rb.Add(new TypedValue((int)LispDataType.ListEnd));
                }
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        // The Interface of Dyl-Settings > Display (DynalispInterface, the former
        // DynalispPaletteColors while it is not set), with Display on, null when it is off or
        // not set: the user settings (getenv) of the FixedProfile of AutoCAD. The former names
        // DynALisp Neutral and DynALisp are given as DynALisp Dark and Midnight.
        internal static string InterfaceLook()
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General"))
                {
                    if (key == null || key.GetValue("DynalispDisplayOn") as string != "1") return null;
                    string v = key.GetValue("DynalispInterface") as string;
                    if (string.IsNullOrEmpty(v)) v = key.GetValue("DynalispPaletteColors") as string;
                    if (v == "DynALisp Neutral") return "DynALisp Dark";
                    if (v == "DynALisp") return "Midnight";
                    return string.IsNullOrEmpty(v) ? null : v;
                }
            }
            catch { return null; }
        }

        // The theme of AutoCAD: COLORTHEME 0 dark, 1 light:
        internal static bool DarkTheme()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("COLORTHEME")) == 0; }
            catch { return false; }
        }

        internal static string Message(System.Exception e)
        {
            // the message of each exception down to the first one (a file that does not read
            // says which line, its inner exception why):
            string msg = e.Message;
            for (var i = e.InnerException; i != null; i = i.InnerException)
                if (!(i is TargetInvocationException)) msg += " " + i.Message;
            return msg;
        }

        // The values of the Lisp into the session:
        internal static void Give(Session s, Lisp.List vals)
        {
            foreach (var item in vals)
            {
                if (!(item is Lisp.List p) || p.Count == 0 || !(p[0] is string key)) continue;
                if (key.EndsWith("/list", StringComparison.Ordinal))
                    s.Lists[key.Substring(0, key.Length - 5)] = p.Skip(1).Select(Lisp.Str).ToList();
                else if (key.EndsWith("/vals", StringComparison.Ordinal))
                    s.Lists[key] = p.Skip(1).Select(Lisp.Str).ToList();
                else if (p.Count > 1 && p[1] is Lisp.List)
                    s.Rows[key] = p.Skip(1).Select(r => r is Lisp.List l ? l.Select(Lisp.Str).ToArray() : new[] { Lisp.Str(r) }).ToList();
                // a table without rows (no presets yet, no layers): a table all the same
                else if (p.Count == 1 && (key.EndsWith("/rows", StringComparison.Ordinal) || key.EndsWith("/defs", StringComparison.Ordinal) || key.EndsWith("/als", StringComparison.Ordinal)))
                    s.Rows[key] = new List<string[]>();
                else if (key.EndsWith("/off", StringComparison.Ordinal))
                {
                    if (p.Count > 1 && Lisp.True(p[1])) s.Off.Add(key.Substring(0, key.Length - 4));
                }
                else
                    s.Values[key] = p.Count > 1 ? Lisp.Str(p[1]) : "";
            }
        }
    }

    // Where the windows that can be resized were left (Engine\Fit.cs): the user setting
    // DynalispWindowPlaces (getenv / setenv: the FixedProfile\General key of the profile),
    // "Dyl-Suite:left,top,width,height,maximized|Dyl-Info:...". A setting of this computer
    // (its screens): never saved with the settings (*dyl:setslocal* of dynalisp.mnl,
    // LocalSettings of DynALisp.iss), removed by the uninstall as every Dynalisp* setting.
    sealed class Places : IPlaces
    {
        const string Setting = "DynalispWindowPlaces";

        static string KeyPath => HostApplicationServices.Current.UserRegistryProductRootKey + @"\FixedProfile\General";

        static Dictionary<string, string> Read()
        {
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(KeyPath))
                foreach (var item in ((key?.GetValue(Setting) as string) ?? "").Split('|'))
                {
                    int c = item.IndexOf(':');
                    if (c > 0) d[item.Substring(0, c)] = item.Substring(c + 1);
                }
            return d;
        }

        public string Get(string name)
        {
            try { return Read().TryGetValue(name, out string v) ? v : null; }
            catch { return null; }
        }

        public void Set(string name, string value)
        {
            try
            {
                var d = Read();
                d[name] = value;
                using (var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(KeyPath))
                    key?.SetValue(Setting, string.Join("|", d.Select(kv => kv.Key + ":" + kv.Value)));
            }
            catch { }
        }
    }

    // A Lisp value read from a ResultBuffer: a string, a number, true (T), null (nil) or a
    // List (Dotted for a dotted pair, (a . b)):
    static class Lisp
    {
        public sealed class List : List<object> { public bool Dotted; }

        public static List Read(ResultBuffer rb)
        {
            var root = new List();
            if (rb == null) return root;
            var stack = new Stack<List>();
            var cur = root;
            foreach (TypedValue tv in rb)
            {
                switch ((LispDataType)tv.TypeCode)
                {
                    case LispDataType.ListBegin:
                        var l = new List();
                        cur.Add(l);
                        stack.Push(cur);
                        cur = l;
                        break;
                    case LispDataType.ListEnd:
                        if (stack.Count > 0) cur = stack.Pop();
                        break;
                    case LispDataType.DottedPair:
                        cur.Dotted = true;
                        if (stack.Count > 0) cur = stack.Pop();
                        break;
                    case LispDataType.Nil:
                        cur.Add(null);
                        break;
                    case LispDataType.T_atom:
                        cur.Add(true);
                        break;
                    default:
                        cur.Add(tv.Value);
                        break;
                }
            }
            return root;
        }

        public static string Str(object o)
        {
            switch (o)
            {
                case null: return "";
                case string s: return s;
                case bool b: return b ? "1" : "0";
                case double d: return d.ToString(CultureInfo.InvariantCulture);
                case IFormattable f: return f.ToString(null, CultureInfo.InvariantCulture);
                default: return o.ToString();
            }
        }

        public static bool True(object o) =>
            o != null && !(o is bool b && !b) && !(o is string s && (s == "" || s == "0")) && !(o is IList l && l.Count == 0);
    }
}
