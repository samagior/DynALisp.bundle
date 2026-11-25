// Plugin.cs - DynALisp.Assistant: the Lisp functions of the Assistant
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
// (Dyl:AssistantShow docs prompt)   shows the Assistant palette: docs, what its Open Docs
//                                   button opens; prompt, the file of the instructions
//                                   added to those of Claude Code (Res\Assistant\Prompt.txt).
//                                   T, or nil when it could not be shown.
// (Dyl:ClaudeRun input system model schema timeout)
//                                   one request, without the palette: input, the text sent;
//                                   system, the instructions (a text, or nil); model
//                                   ("haiku", "sonnet"...); schema, a JSON Schema the answer
//                                   follows (a text, or nil); timeout in seconds (nil: 120).
//                                   (T text) or (nil error): the text of the answer, or the
//                                   JSON of the answer that follows the schema.
// (Dyl:ClaudeInfo)                  what the Diagnostics report: (("path" . p) ("version" . v)
//                                   ("loggedIn" . "1"|"0") ("authMethod" . m) ("apiKey" .
//                                   "1"|"0") ("server" . port)), only path when Claude Code is
//                                   not found; server, the port of the server of the tools of
//                                   the drawing, empty until the palette starts a conversation.
//
// The Lisp checks (if Dyl:ClaudeRun ...) first: the plugin loads in AutoCAD 2025 and later.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: ExtensionApplication(typeof(DynALisp.Assistant.Plugin))]
[assembly: CommandClass(typeof(DynALisp.Assistant.Bridge))]

namespace DynALisp.Assistant
{
    public class Plugin : IExtensionApplication
    {
        // Loaded on the main thread of AutoCAD: its Dispatcher runs the work of the tools
        // (Host.cs), and the selection of each drawing is kept as it changes (Tools.cs).
        public void Initialize()
        {
            Host.Main = System.Windows.Threading.Dispatcher.CurrentDispatcher;
            try { Selection.Watch(); } catch { }
        }

        // AutoCAD closes: Claude Code and the server with it.
        public void Terminate()
        {
            Palette.Close();
            Server.Stop();
        }
    }

    public class Bridge
    {
        [LispFunction("Dyl:AssistantShow")]
        public object AssistantShow(ResultBuffer args)
        {
            try
            {
                var a = Read(args);
                Palette.Show(Arg(a, 0), Arg(a, 1));
                return true;
            }
            catch (System.Exception e)
            {
                Say("\n--> Unable to show the Assistant: " + e.Message);
                return null;
            }
        }

        [LispFunction("Dyl:ClaudeRun")]
        public object ClaudeRun(ResultBuffer args)
        {
            string tmp = null;
            try
            {
                var a = Read(args);
                string input = Arg(a, 0), system = Arg(a, 1), model = Arg(a, 2), schema = Arg(a, 3);
                int timeout = 120;
                if (a.Count > 4 && a[4] != null)
                    timeout = Math.Max(5, (int)Convert.ToDouble(a[4], CultureInfo.InvariantCulture));
                if (string.IsNullOrEmpty(input)) return Answer(false, "Nothing to send.");
                var exe = Cli.Find();
                if (exe == null) return Answer(false, "Claude Code is not installed: open Dyl-Assistant to install it.");
                var cmd = new List<string> { "-p", "--output-format", "json", "--model", string.IsNullOrEmpty(model) ? "haiku" : model };
                cmd.AddRange(Cli.Isolated);
                cmd.Add("--no-session-persistence");
                if (!string.IsNullOrEmpty(system))
                {
                    tmp = Path.Combine(Cli.Workspace(), "System-" + Guid.NewGuid().ToString("N") + ".txt");
                    File.WriteAllText(tmp, system, new System.Text.UTF8Encoding(false));
                    cmd.Add("--system-prompt-file");
                    cmd.Add(tmp);
                }
                if (!string.IsNullOrEmpty(schema)) { cmd.Add("--json-schema"); cmd.Add(schema); }
                var o = Cli.Run(exe, cmd, input, timeout * 1000);
                if (o.TimedOut) return Answer(false, "Claude Code did not answer in " + timeout + " s.");
                var r = Json.TryParse(o.Out.Trim());
                if (r == null)
                {
                    var err = (o.Err.Trim() != "" ? o.Err : o.Out).Trim();
                    return Answer(false, err == "" ? "Claude Code returned nothing (exit code " + o.Exit + ")." : err);
                }
                if (Json.Get(r, "is_error") is bool bad && bad)
                    return Answer(false, Json.Text(r, "result") ?? Json.Text(r, "subtype") ?? "Claude Code returned an error.");
                if (!string.IsNullOrEmpty(schema))
                {
                    var so = Json.Get(r, "structured_output");
                    if (so != null) return Answer(true, Json.Write(so));
                }
                return Answer(true, Json.Text(r, "result") ?? "");
            }
            catch (System.Exception e)
            {
                return Answer(false, e.Message);
            }
            finally
            {
                if (tmp != null) try { File.Delete(tmp); } catch { }
            }
        }

        [LispFunction("Dyl:ClaudeInfo")]
        public object ClaudeInfo(ResultBuffer args)
        {
            var pairs = new List<KeyValuePair<string, string>>();
            var exe = Cli.Find();
            pairs.Add(new KeyValuePair<string, string>("path", exe ?? ""));
            if (exe != null)
            {
                pairs.Add(new KeyValuePair<string, string>("version", Cli.Version(exe) ?? ""));
                var st = Cli.AuthStatus(exe);
                if (st != null)
                {
                    pairs.Add(new KeyValuePair<string, string>("loggedIn", Json.Get(st, "loggedIn") is bool b && b ? "1" : "0"));
                    pairs.Add(new KeyValuePair<string, string>("authMethod", Json.Text(st, "authMethod") ?? ""));
                }
            }
            pairs.Add(new KeyValuePair<string, string>("apiKey", Cli.ApiKeySet() ? "1" : "0"));
            pairs.Add(new KeyValuePair<string, string>("server", Server.Running ? Server.Port.ToString(CultureInfo.InvariantCulture) : ""));
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var kv in pairs)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                rb.Add(new TypedValue((int)LispDataType.Text, kv.Key));
                rb.Add(new TypedValue((int)LispDataType.Text, kv.Value));
                rb.Add(new TypedValue((int)LispDataType.DottedPair));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        static ResultBuffer Answer(bool ok, string text)
        {
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)(ok ? LispDataType.T_atom : LispDataType.Nil)));
            rb.Add(new TypedValue((int)LispDataType.Text, text ?? ""));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        // The arguments of a Lisp function, flat: strings, numbers, null for nil.
        static List<object> Read(ResultBuffer rb)
        {
            var l = new List<object>();
            if (rb == null) return l;
            foreach (TypedValue tv in rb)
            {
                switch ((LispDataType)tv.TypeCode)
                {
                    case LispDataType.Nil: l.Add(null); break;
                    case LispDataType.T_atom: l.Add(true); break;
                    case LispDataType.ListBegin:
                    case LispDataType.ListEnd:
                    case LispDataType.DottedPair: break;
                    default: l.Add(tv.Value); break;
                }
            }
            return l;
        }

        static string Arg(List<object> a, int i) => i < a.Count ? a[i] as string : null;

        internal static void Say(string msg)
        {
            try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage(msg); } catch { }
        }
    }
}
