// Chat.cs - DynALisp.Assistant: the conversation of the palette, a Claude Code that stays open
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
// One Claude Code process for the whole conversation, reading the messages of the user on
// its standard input and writing its events on its output, one JSON object a line
// (-p --input-format stream-json --output-format stream-json --verbose
// --include-partial-messages). The events come on a thread of their own: the palette shows
// them on its own thread (Dispatcher).
//
//   system/init       every turn: the session (kept, to resume it) and apiKeySource
//   stream_event      the text as it is written (content_block_delta / text_delta)
//   assistant         a message written whole
//   result            the end of the turn (is_error when it failed)
//
// Stop ends the process; the next message starts it again on the same session (--resume),
// so the conversation goes on. New chat forgets the session.
//
// The drawing: Claude Code is given the server of DynALisp (Server.cs) by --mcp-config, its
// token in DYL_ASSISTANT_TOKEN of its own process only. The tools that read are allowed
// (--allowedTools); those that write are asked to approve (--permission-prompt-tool
// mcp__dynalisp__approve), which shows the approval card of the palette (Writes.cs).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading;

namespace DynALisp.Assistant
{
    sealed class Chat
    {
        public string Exe;
        public string Model = "sonnet";
        public string PromptFile;
        public string SessionId { get; private set; }
        public bool Busy { get; private set; }

        public event Action<string> Delta;         // text written so far added to the message
        public event Action<string> Message;       // a message written whole
        public event Action<string, bool> TurnEnd; // the end of a turn: its error (null when none), sign-in needed
        public event Action<string> KeySource;     // apiKeySource of the session, when not "none"
        public event Action<string> ToolUse;       // a tool of the drawing called by Claude (its short name)

        Process _p;
        readonly object _lock = new object();
        readonly Queue<string> _err = new Queue<string>();

        static readonly string[] LoginWords = { "/login", "log in", "logged in", "login", "authenticat", "oauth", "invalid api key" };

        public void Send(string text)
        {
            lock (_lock)
            {
                if (_p == null || _p.HasExited) Start();
                Busy = true;
                var msg = new Dictionary<string, object>
                {
                    ["type"] = "user",
                    ["message"] = new Dictionary<string, object>
                    {
                        ["role"] = "user",
                        ["content"] = new List<object> { new Dictionary<string, object> { ["type"] = "text", ["text"] = text } },
                    },
                };
                Cli.Write(_p, Json.Write(msg) + "\n");
            }
        }

        public void Stop()
        {
            Process p;
            lock (_lock) { p = _p; _p = null; }
            Cli.Kill(p);
            if (Busy)
            {
                Busy = false;
                TurnEnd?.Invoke(null, false);
            }
        }

        public void Reset()
        {
            Stop();
            SessionId = null;
            Tools.ForgetApprovals();
        }

        void Start()
        {
            var args = new List<string>
            {
                "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
                "--include-partial-messages", "--model", Model,
            };
            args.AddRange(Cli.Isolated);
            Server.Start();
            var mcp = new Dictionary<string, object>
            {
                ["mcpServers"] = new Dictionary<string, object>
                {
                    ["dynalisp"] = new Dictionary<string, object>
                    {
                        ["type"] = "http",
                        ["url"] = Server.Url,
                        ["headers"] = new Dictionary<string, object> { ["Authorization"] = "Bearer ${DYL_ASSISTANT_TOKEN}" },
                        ["timeout"] = 600000,
                    },
                },
            };
            args.Add("--mcp-config"); args.Add(Json.Write(mcp));
            args.Add("--allowedTools"); args.Add(string.Join(",", Tools.Reads.Select(t => Tools.Prefix + t)));
            args.Add("--permission-prompt-tool"); args.Add(Tools.Prefix + "approve");
            if (!string.IsNullOrEmpty(PromptFile)) { args.Add("--append-system-prompt-file"); args.Add(PromptFile); }
            if (!string.IsNullOrEmpty(SessionId)) { args.Add("--resume"); args.Add(SessionId); }
            lock (_err) _err.Clear();
            var psi = Cli.StartInfo(Exe, args);
            psi.EnvironmentVariables["DYL_ASSISTANT_TOKEN"] = Server.Token;
            var p = Process.Start(psi);
            _p = p;
            new Thread(() => ReadOut(p)) { IsBackground = true, Name = "DynALisp Assistant output" }.Start();
            new Thread(() => ReadErr(p)) { IsBackground = true, Name = "DynALisp Assistant errors" }.Start();
        }

        void ReadErr(Process p)
        {
            try
            {
                string line;
                while ((line = p.StandardError.ReadLine()) != null)
                    lock (_err)
                    {
                        _err.Enqueue(line);
                        while (_err.Count > 20) _err.Dequeue();
                    }
            }
            catch { }
        }

        void ReadOut(Process p)
        {
            try
            {
                string line;
                while ((line = p.StandardOutput.ReadLine()) != null) Event(Json.TryParse(line));
            }
            catch { }
            // the process ended in the middle of a turn (not by Stop): say why
            bool mine;
            lock (_lock) { mine = _p == p; if (mine) _p = null; }
            if (mine && Busy)
            {
                Busy = false;
                string err;
                lock (_err) err = string.Join("\n", _err.Where(l => l.Trim() != "")).Trim();
                if (err == "") err = "Claude Code stopped.";
                TurnEnd?.Invoke(err, NeedsLogin(err));
            }
        }

        void Event(object e)
        {
            switch (Json.Text(e, "type"))
            {
                case "system":
                    if (Json.Text(e, "subtype") != "init") break;
                    var sid = Json.Text(e, "session_id");
                    if (!string.IsNullOrEmpty(sid)) SessionId = sid;
                    var src = Json.Text(e, "apiKeySource");
                    if (!string.IsNullOrEmpty(src) && src != "none") KeySource?.Invoke(src);
                    break;
                case "stream_event":
                    if (Json.Text(e, "event", "type") == "content_block_delta" && Json.Text(e, "event", "delta", "type") == "text_delta")
                        Delta?.Invoke(Json.Text(e, "event", "delta", "text") ?? "");
                    break;
                case "assistant":
                    var text = TextOf(Json.Get(e, "message", "content"));
                    if (text != null) Message?.Invoke(text);
                    if (Json.Get(e, "message", "content") is List<object> blocks)
                        foreach (var b in blocks)
                            if (Json.Text(b, "type") == "tool_use")
                            {
                                var n = Json.Text(b, "name") ?? "";
                                ToolUse?.Invoke(n.StartsWith(Tools.Prefix, StringComparison.Ordinal) ? n.Substring(Tools.Prefix.Length) : n);
                            }
                    break;
                case "result":
                    Busy = false;
                    var sid2 = Json.Text(e, "session_id");
                    if (!string.IsNullOrEmpty(sid2)) SessionId = sid2;
                    if (Json.Get(e, "is_error") is bool bad && bad)
                    {
                        var msg = Json.Text(e, "result") ?? Json.Text(e, "subtype") ?? "Claude Code returned an error.";
                        TurnEnd?.Invoke(msg, NeedsLogin(msg));
                    }
                    else TurnEnd?.Invoke(null, false);
                    break;
            }
        }

        // The text blocks of a message, null when it has none (a tool call):
        static string TextOf(object content)
        {
            if (!(content is List<object> blocks)) return content as string;
            var sb = new StringBuilder();
            foreach (var b in blocks)
                if (Json.Text(b, "type") == "text") sb.Append(Json.Text(b, "text"));
            return sb.Length > 0 ? sb.ToString() : null;
        }

        public static bool NeedsLogin(string msg)
        {
            var m = (msg ?? "").ToLowerInvariant();
            return LoginWords.Any(m.Contains);
        }
    }
}
