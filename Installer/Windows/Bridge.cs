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
//   ("docs/Core\\Dyl-Settings.htm" . "https://...")   what the Open Docs button of the
//                                 window of that page opens (Dyl:WinShow gives them)
//
// It returns (status (key . value) ...): the button that closed it (0 Cancel, 1 OK / Save, or
// its Win.Close) and the value of every key, as get_tile gives it, nil when the window
// could not be shown (the reason on the command line). Called through Dyl:WinShow of
// dynalisp.mnl, which finds the file and the docs; the Lisp checks (if Dyl:Window ...) first.
//
// The window is the only thing running while it is open: no callback to the Lisp. A button
// that must run Lisp (a command, another window of the Lisp) closes it with its number
// (Win.Close), and the Lisp opens it again, as a DCL window does with done_dialog.

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
        }

        public void Terminate() { }

        static Assembly Resolve(object sender, ResolveEventArgs e)
        {
            var me = typeof(Plugin).Assembly;
            return new AssemblyName(e.Name).Name == me.GetName().Name ? me : null;
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
                var s = new Session { ShowRoot = w => AcApp.ShowModalWindow(w), Dark = DarkTheme() };
                if (a.Count > 1 && a[1] is Lisp.List vals) Give(s, vals);
                int status = s.Show(file);
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
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
                return rb;
            }
            catch (System.Exception e)
            {
                try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n--> Unable to show the window: " + Message(e)); } catch { }
                return null;
            }
        }

        // The theme of AutoCAD: COLORTHEME 0 dark, 1 light:
        static bool DarkTheme()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("COLORTHEME")) == 0; }
            catch { return false; }
        }

        static string Message(System.Exception e)
        {
            // the message of each exception down to the first one (a file that does not read
            // says which line, its inner exception why):
            string msg = e.Message;
            for (var i = e.InnerException; i != null; i = i.InnerException)
                if (!(i is TargetInvocationException)) msg += " " + i.Message;
            return msg;
        }

        // The values of the Lisp into the session:
        static void Give(Session s, Lisp.List vals)
        {
            foreach (var item in vals)
            {
                if (!(item is Lisp.List p) || p.Count == 0 || !(p[0] is string key)) continue;
                if (key.EndsWith("/list", StringComparison.Ordinal))
                    s.Lists[key.Substring(0, key.Length - 5)] = p.Skip(1).Select(Lisp.Str).ToList();
                else if (key.EndsWith("/off", StringComparison.Ordinal))
                {
                    if (p.Count > 1 && Lisp.True(p[1])) s.Off.Add(key.Substring(0, key.Length - 4));
                }
                else
                    s.Values[key] = p.Count > 1 ? Lisp.Str(p[1]) : "";
            }
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
