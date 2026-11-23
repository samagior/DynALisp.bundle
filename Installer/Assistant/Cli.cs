// Cli.cs - DynALisp.Assistant: finds and runs Claude Code
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
// Claude Code is the command line of Anthropic (claude.exe), installed by the user and
// signed in with their own Claude account. DynALisp runs it as it is, never a copy or a
// modified one, and never reads its credentials: the subscription of the user is used only
// because the program of Anthropic runs. It is run:
//   - with no tool of its own (--tools ""), no MCP server but those DynALisp gives
//     (--strict-mcp-config), no settings, hooks or plugins of the user but those of its
//     working folder (--setting-sources project, --disable-slash-commands), so a request
//     of DynALisp does only what DynALisp asked;
//   - in its own working folder, %LOCALAPPDATA%\DynALisp\Assistant (Workspace), where Claude
//     Code keeps nothing of DynALisp but its conversations (in its own folder of projects);
//   - without the CLAUDE_CODE_* variables of a Claude app that started AutoCAD, which would
//     make it run as a child of that app. ANTHROPIC_API_KEY is kept: when it is set, Claude
//     Code bills that key instead of the subscription, and the palette says so.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DynALisp.Assistant
{
    static class Cli
    {
        // The options every run of DynALisp gives (see above):
        public static readonly string[] Isolated =
        {
            "--tools", "", "--strict-mcp-config", "--setting-sources", "project", "--disable-slash-commands",
        };

        // The folders where the installers of Anthropic put claude.exe, after the PATH: the
        // native installer (%USERPROFILE%\.local\bin) and WinGet (its Links folder).
        public static string Find()
        {
            var dirs = new List<string>();
            dirs.AddRange((Environment.GetEnvironmentVariable("PATH") ?? "").Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries));
            // the PATH of the user, when AutoCAD started before the installer changed it:
            dirs.AddRange((Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.User) ?? "").Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries));
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            dirs.Add(Path.Combine(home, ".local", "bin"));
            dirs.Add(Path.Combine(local, "Microsoft", "WinGet", "Links"));
            foreach (var d in dirs)
            {
                try
                {
                    var f = Path.Combine(Environment.ExpandEnvironmentVariables(d.Trim().Trim('"')), "claude.exe");
                    if (File.Exists(f)) return f;
                }
                catch { }
            }
            return null;
        }

        public static string Workspace()
        {
            var d = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DynALisp", "Assistant");
            Directory.CreateDirectory(d);
            return d;
        }

        public static bool ApiKeySet() =>
            !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ANTHROPIC_API_KEY"));

        // An argument quoted as a program of Windows reads it (CommandLineToArgvW): .NET
        // Framework has no ArgumentList.
        public static string Quote(string a)
        {
            if (a.Length > 0 && a.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0) return a;
            var sb = new StringBuilder("\"");
            for (int i = 0; ; i++)
            {
                int bs = 0;
                while (i < a.Length && a[i] == '\\') { bs++; i++; }
                if (i == a.Length) { sb.Append('\\', bs * 2); break; }
                if (a[i] == '"') sb.Append('\\', bs * 2 + 1).Append('"');
                else sb.Append('\\', bs).Append(a[i]);
            }
            return sb.Append('"').ToString();
        }

        public static ProcessStartInfo StartInfo(string exe, IEnumerable<string> args)
        {
            var psi = new ProcessStartInfo(exe, string.Join(" ", args.Select(Quote)))
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = new UTF8Encoding(false),
                StandardErrorEncoding = new UTF8Encoding(false),
                WorkingDirectory = Workspace(),
            };
            var env = psi.EnvironmentVariables;
            foreach (var k in env.Keys.Cast<string>().ToList())
            {
                var u = k.ToUpperInvariant();
                if (u.StartsWith("CLAUDE_CODE_", StringComparison.Ordinal) || u == "CLAUDECODE") env.Remove(k);
            }
            return psi;
        }

        // The text written to Claude Code: UTF-8 without BOM, on the stream itself (.NET
        // Framework writes stdin in the code page of Windows).
        public static void Write(Process p, string text)
        {
            var b = new UTF8Encoding(false).GetBytes(text);
            p.StandardInput.BaseStream.Write(b, 0, b.Length);
            p.StandardInput.BaseStream.Flush();
        }

        public sealed class Output
        {
            public int Exit = -1;
            public string Out = "", Err = "";
            public bool TimedOut;
        }

        // Runs Claude Code to its end, its input written then closed:
        public static Output Run(string exe, IEnumerable<string> args, string input, int timeoutMs)
        {
            var o = new Output();
            using (var p = Process.Start(StartInfo(exe, args)))
            {
                var so = p.StandardOutput.ReadToEndAsync();
                var se = p.StandardError.ReadToEndAsync();
                try
                {
                    if (!string.IsNullOrEmpty(input)) Write(p, input);
                    p.StandardInput.Close();
                }
                catch (IOException) { }
                if (!p.WaitForExit(timeoutMs))
                {
                    o.TimedOut = true;
                    Kill(p);
                }
                Task.WaitAll(new Task[] { so, se }, 5000);
                o.Out = so.IsCompleted ? so.Result : "";
                o.Err = se.IsCompleted ? se.Result : "";
                if (!o.TimedOut) o.Exit = p.ExitCode;
            }
            return o;
        }

        public static void Kill(Process p)
        {
            try
            {
                if (p == null || p.HasExited) return;
#if NET
                p.Kill(true);
#else
                p.Kill();
#endif
            }
            catch { }
        }

        // "2.1.330 (Claude Code)" -> "2.1.330"; null when it does not run:
        public static string Version(string exe)
        {
            try
            {
                var o = Run(exe, new[] { "--version" }, null, 15000);
                var v = o.Out.Trim().Split(' ').FirstOrDefault();
                return string.IsNullOrEmpty(v) ? null : v;
            }
            catch { return null; }
        }

        // What `claude auth status --json` says (loggedIn, authMethod...): never the token,
        // which it does not give. null when it does not answer.
        public static Dictionary<string, object> AuthStatus(string exe)
        {
            try
            {
                var o = Run(exe, new[] { "auth", "status", "--json" }, null, 20000);
                return Json.TryParse(o.Out.Trim()) as Dictionary<string, object>;
            }
            catch { return null; }
        }

        // Opens a console that runs a command the user sees (the installer of Anthropic, the
        // sign-in of Claude Code), left open when it ends so its result can be read.
        public static void Console(string command)
        {
            Process.Start(new ProcessStartInfo("cmd.exe", "/k " + command)
            {
                UseShellExecute = true,
                WorkingDirectory = Workspace(),
            });
        }

        public const string InstallCommand =
            "powershell -NoProfile -ExecutionPolicy Bypass -Command \"irm https://claude.ai/install.ps1 | iex\"";

        public static string LoginCommand(string exe) => "\"\"" + exe + "\" auth login --claudeai\"";
    }
}
