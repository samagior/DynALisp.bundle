// Host.cs - DynALisp.Assistant: runs the work of the tools on the thread of AutoCAD
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
// The calls of Claude Code come on threads of the server; the drawing is only read or changed
// on the main thread of AutoCAD, through the Dispatcher kept when the plugin loads:
//   Read    a reading, at any time (even while a command waits for a point): the active
//           drawing, in a transaction that changes nothing.
//   Write   a change, in the command context of AutoCAD (ExecuteInCommandContextAsync,
//           AutoCAD 2016), between _.UNDO _Begin and _.UNDO _End: one U undoes it. Refused
//           while a command runs (CMDACTIVE: a command waiting for a point, a window of
//           DynALisp open), or when the active drawing is not the one the user approved.

using System;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Threading;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Assistant
{
    sealed class ToolError : Exception
    {
        public ToolError(string msg) : base(msg) { }
    }

    static class Host
    {
        public static Dispatcher Main;

        const int ReadTimeout = 60000, WriteTimeout = 120000;

        // f on the main thread; a ToolError when AutoCAD does not take it in time.
        public static T OnMain<T>(Func<T> f, int timeout = ReadTimeout)
        {
            var d = Main ?? throw new ToolError("The Assistant plugin is not ready.");
            if (d.CheckAccess()) return f();
            T r = default(T);
            Exception err = null;
            var op = d.BeginInvoke(new Action(() =>
            {
                try { r = f(); }
                catch (Exception e) { err = e; }
            }));
            if (op.Wait(TimeSpan.FromMilliseconds(timeout)) != DispatcherOperationStatus.Completed)
            {
                op.Abort();
                throw new ToolError("AutoCAD is busy: it did not answer in " + timeout / 1000 + " s.");
            }
            if (err != null) throw err is ToolError ? err : new ToolError(err.Message);
            return r;
        }

        public static Document Doc() =>
            AcApp.DocumentManager.MdiActiveDocument ?? throw new ToolError("No drawing is open.");

        // A reading of the active drawing: f gets the drawing and a transaction.
        public static T Read<T>(Func<Document, Transaction, T> f) => OnMain(() =>
        {
            var doc = Doc();
            using (var tr = doc.Database.TransactionManager.StartOpenCloseTransaction())
            {
                var r = f(doc, tr);
                tr.Commit();
                return r;
            }
        });

        public static bool CommandActive()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("CMDACTIVE")) != 0; }
            catch { return false; }
        }

        // A change of the drawing doc (the one the user approved), in one undo group. f runs
        // in the command context, with the document locked; run gets the editor of the
        // drawing for the commands of AutoCAD (run_command).
        public static string Write(Document doc, Func<Document, Transaction, string> f) =>
            WriteAsync(doc, async (d, ed) =>
            {
                using (d.LockDocument())
                using (var tr = d.Database.TransactionManager.StartTransaction())
                {
                    var r = f(d, tr);
                    tr.Commit();
                    return await Task.FromResult(r);
                }
            });

        public static string WriteAsync(Document doc, Func<Document, Editor, Task<string>> f)
        {
            var done = new TaskCompletionSource<string>();
            OnMain(() =>
            {
                var cur = AcApp.DocumentManager.MdiActiveDocument;
                if (cur == null || doc == null || cur != doc)
                    throw new ToolError("The active drawing is no longer the one the user approved: nothing was changed.");
                if (CommandActive())
                    throw new ToolError("AutoCAD is busy (a command or a window is open): nothing was changed. Ask the user to finish it, then try again.");
                AcApp.DocumentManager.ExecuteInCommandContextAsync(async _ =>
                {
                    var ed = doc.Editor;
                    bool begun = false;
                    try
                    {
                        await ed.CommandAsync("_.UNDO", "_Begin");
                        begun = true;
                        var r = await f(doc, ed);
                        done.TrySetResult(r);
                    }
                    catch (Exception e)
                    {
                        done.TrySetException(e);
                    }
                    finally
                    {
                        if (begun)
                            try { await ed.CommandAsync("_.UNDO", "_End"); } catch { }
                    }
                }, null);
                return true;
            });
            if (!done.Task.Wait(WriteTimeout))
                throw new ToolError("AutoCAD did not finish the change in " + WriteTimeout / 1000 + " s.");
            if (done.Task.IsFaulted)
            {
                var e = done.Task.Exception?.InnerException;
                throw e is ToolError ? e : new ToolError(e?.Message ?? "The change failed.");
            }
            return done.Task.Result;
        }
    }
}
