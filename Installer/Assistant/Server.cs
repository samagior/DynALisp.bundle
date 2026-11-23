// Server.cs - DynALisp.Assistant: the MCP server that gives Claude Code the tools of the drawing
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
// MCP over local HTTP (Streamable HTTP, JSON answers only, no SSE stream), in AutoCAD itself:
//   - an HttpListener on http://127.0.0.1:<free port>/mcp/, nothing else listens;
//   - every request carries "Authorization: Bearer <token>", a token of 32 random bytes made
//     when the server starts, given to Claude Code only, in the variable DYL_ASSISTANT_TOKEN
//     of its process (Chat.cs), so it is neither on the disk nor on its command line; a
//     request without it gets 401, and a request with an Origin header (a web page) 403;
//   - JSON-RPC 2.0: initialize, ping, tools/list, tools/call; a notification gets 202 and
//     no body, any other method -32601 (server/discover, asked before initialize), a GET
//     405 (the SSE stream Claude Code asks for).
// Each request is answered on a thread of its own: a call waiting for the user (approve)
// never holds the others.

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace DynALisp.Assistant
{
    static class Server
    {
        static HttpListener _http;
        public static int Port { get; private set; }
        public static string Token { get; private set; }
        public static string Url => "http://127.0.0.1:" + Port + "/mcp/";
        public static bool Running => _http != null && _http.IsListening;

        public static void Start()
        {
            if (Running) return;
            var b = new byte[32];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(b);
            Token = BitConverter.ToString(b).Replace("-", "").ToLowerInvariant();
            Exception last = null;
            for (int i = 0; i < 5; i++)
            {
                var port = FreePort();
                var h = new HttpListener();
                h.Prefixes.Add("http://127.0.0.1:" + port + "/mcp/");
                try
                {
                    h.Start();
                    _http = h;
                    Port = port;
                    break;
                }
                catch (Exception e) { last = e; try { h.Close(); } catch { } }
            }
            if (_http == null) throw new InvalidOperationException("Unable to start the server of the Assistant: " + last?.Message);
            new Thread(Loop) { IsBackground = true, Name = "DynALisp Assistant server" }.Start();
        }

        public static void Stop()
        {
            var h = _http;
            _http = null;
            try { h?.Close(); } catch { }
        }

        static int FreePort()
        {
            var l = new TcpListener(IPAddress.Loopback, 0);
            l.Start();
            int p = ((IPEndPoint)l.LocalEndpoint).Port;
            l.Stop();
            return p;
        }

        static void Loop()
        {
            var h = _http;
            while (h != null && h.IsListening)
            {
                HttpListenerContext c;
                try { c = h.GetContext(); }
                catch { break; }
                ThreadPool.QueueUserWorkItem(_ => Handle(c));
            }
        }

        static void Handle(HttpListenerContext c)
        {
            var q = c.Request;
            var r = c.Response;
            try
            {
                if (!string.IsNullOrEmpty(q.Headers["Origin"])) { Status(r, 403); return; }
                if (q.Headers["Authorization"] != "Bearer " + Token) { Status(r, 401); return; }
                if (q.HttpMethod != "POST") { Status(r, 405); return; }
                string body;
                using (var sr = new StreamReader(q.InputStream, new UTF8Encoding(false))) body = sr.ReadToEnd();
                var msg = Json.TryParse(body);
                if (msg == null) { Send(r, Error(null, -32700, "Parse error")); return; }
                if (msg is List<object> batch)
                {
                    var answers = new List<object>();
                    foreach (var m in batch)
                    {
                        var a = Answer(m);
                        if (a != null) answers.Add(a);
                    }
                    if (answers.Count == 0) Status(r, 202);
                    else Send(r, answers);
                    return;
                }
                var one = Answer(msg);
                if (one == null) Status(r, 202);
                else Send(r, one);
            }
            catch (Exception e)
            {
                try { Send(r, Error(null, -32603, e.Message)); } catch { }
            }
        }

        // The answer to one message, null for a notification (no id).
        static object Answer(object m)
        {
            var method = Json.Text(m, "method");
            var id = Json.Get(m, "id");
            bool notification = !(m is Dictionary<string, object> d) || !d.ContainsKey("id");
            if (method == null) return notification ? null : Error(id, -32600, "Invalid request");
            if (notification) return null;
            switch (method)
            {
                case "initialize":
                    return Result(id, new Dictionary<string, object>
                    {
                        ["protocolVersion"] = Json.Text(m, "params", "protocolVersion") ?? "2025-06-18",
                        ["capabilities"] = new Dictionary<string, object> { ["tools"] = new Dictionary<string, object>() },
                        ["serverInfo"] = new Dictionary<string, object> { ["name"] = "dynalisp", ["version"] = "1.0" },
                    });
                case "ping":
                    return Result(id, new Dictionary<string, object>());
                case "tools/list":
                    return Result(id, new Dictionary<string, object> { ["tools"] = Tools.List() });
                case "tools/call":
                    var name = Json.Text(m, "params", "name") ?? "";
                    var args = Json.Get(m, "params", "arguments") as Dictionary<string, object> ?? new Dictionary<string, object>();
                    var useId = Json.Text(m, "params", "_meta", "claudecode/toolUseId");
                    bool isError = false;
                    object answer;
                    try { answer = Tools.Call(name, args, useId); }
                    catch (ToolError e) { answer = e.Message; isError = true; }
                    catch (Exception e) { answer = "Error: " + e.Message; isError = true; }
                    return Result(id, new Dictionary<string, object>
                    {
                        ["content"] = answer as List<object>
                            ?? new List<object> { new Dictionary<string, object> { ["type"] = "text", ["text"] = answer as string ?? "" } },
                        ["isError"] = isError,
                    });
                default:
                    return Error(id, -32601, "Method not found: " + method);
            }
        }

        static object Result(object id, object result) => new Dictionary<string, object>
        {
            ["jsonrpc"] = "2.0", ["id"] = id, ["result"] = result,
        };

        static object Error(object id, int code, string message) => new Dictionary<string, object>
        {
            ["jsonrpc"] = "2.0", ["id"] = id,
            ["error"] = new Dictionary<string, object> { ["code"] = code, ["message"] = message },
        };

        static void Status(HttpListenerResponse r, int code)
        {
            r.StatusCode = code;
            r.ContentLength64 = 0;
            r.Close();
        }

        static void Send(HttpListenerResponse r, object v)
        {
            var b = new UTF8Encoding(false).GetBytes(Json.Write(v));
            r.StatusCode = 200;
            r.ContentType = "application/json; charset=utf-8";
            r.ContentLength64 = b.Length;
            r.OutputStream.Write(b, 0, b.Length);
            r.Close();
        }
    }
}
