// AsmPresets.cs - DynALisp.Windows: the Assembly Presets window, (Dyl:AsmWindow file ctx)
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
// (Dyl:AsmWindow file ctx) shows the Assembly Presets window (file: Res\Dyl-AssemblyPresets.xaml,
// full path) on the assemblies, made and read back by DynALisp.Core.dll (Data\AsmTab.cs) with no
// Lisp in between: the 860 assemblies, made into rows by the Core, given to the Lisp, then by
// the Lisp to Dyl:Window, took most of the time of the tab. The Lisp (Dyl:QuickDrawAsmDialog of
// Apps\Draw\Dyl-QuickDraw.lsp) gives what only it has, ctx ((key . value) ...):
//
//   ("contents" . path)          the Contents folder of DynALisp (*dyl:contents)
//   ("vars" cannoscale measurement insunits lunits luprec dimzin)   the system variables
//   ("keys" key ...)             the names of the layer keys defined (Remote>>Dyl:LayerKeyRead)
//   ("border" . key)             the layer key of the border of the Quick Draw preset the
//                                window is opened from (absent: from no preset)
//   ("select" . id)              the assembly to show (absent: the one shown last)
//   ("shw" . group)              the Show group set as default (DynalispPresetShow...)
//   ("pats" (pattern units file) ...)   the units of the patterns of Dyl:AsmTabPats
//   ("rows" (preset) ...)        the assemblies, when the Lisp reads them (absent: the Core)
//   ("resume" . T)               the window shown again after the Preset Groups window, on the
//                                assemblies being edited, with ("renames" (old . new) ...)
//   ("vals" (key . value) ...)   the values of Dyl:WinShow: the tabs of the Manager and the
//                                Open Docs buttons
//
// and gets (status ("tab" . "i") ("id" . id) ("written" . "1") ("counts" (GROUP . n) ...)):
//
//   nil   the window is shown modeless (the tab of the Manager), nothing to do yet
//   -1    the Lisp reads the assemblies: called again with ("rows" ...)
//   -2    the materials cannot be read (a default file missing)
//   0     Cancel
//   1, 2  OK (the assembly selected: id), Save; written when the assemblies were saved
//   8     the Preset Groups window to show (counts: the assemblies of each group), then this
//         window again (resume)
//   90    another tab of the Manager picked (tab): saved, as Save
//
// The rows sent, the assemblies being edited and the window waiting for a click of the Manager
// are kept here between two calls; the sort and the assembly shown last for the session. The
// Show group set as default is saved here (setenv), as Remote>>Dyl:PresetWinGet did.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using DynALisp.Core.Data;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Windows.AsmPresets))]

namespace DynALisp.Windows
{
    // The Lisp function, its types those of this assembly only: a DynALisp.Core.dll not loaded
    // fails the call (caught), never the plugin:
    public class AsmPresets
    {
        [LispFunction("Dyl:AsmWindow")]
        public object Show(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                string file = a.Count > 0 ? a[0] as string : null;
                if (string.IsNullOrEmpty(file)) throw new ArgumentException("(Dyl:AsmWindow file ctx): no file given");
                return AsmRun.Run(file, a.Count > 1 ? a[1] as Lisp.List : null);
            }
            catch (System.Exception e)
            {
                try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n--> Unable to show the Assembly Presets: " + Bridge.Message(e)); } catch { }
                return null;
            }
        }
    }

    static class AsmRun
    {
        // The window being edited (kept for a click of the Manager and for the Preset Groups
        // window), the sort of the list and the assembly shown last, for the session:
        static AsmTab _tab;
        static string _srt = "Name";
        static int? _last;

        const string ShowSetting = "DynalispPresetShowQuickDrawAssembly";

        static Lisp.List Get(Lisp.List ctx, string key)
        {
            if (ctx == null) return null;
            foreach (var x in ctx)
                if (x is Lisp.List l && l.Count > 0 && l[0] as string == key) return l;
            return null;
        }

        // The value of a pair (key . value), null when absent or nil:
        static object One(Lisp.List ctx, string key)
        {
            var l = Get(ctx, key);
            return l != null && l.Count > 1 ? l[1] : null;
        }

        static int Int(object o) => o switch
        {
            short s => s,
            int i => i,
            long l => (int)l,
            double d => (int)d,
            string t when int.TryParse(t, NumberStyles.Integer, CultureInfo.InvariantCulture, out int v) => v,
            _ => 0,
        };

        static double? Real(object o) => o switch
        {
            double d => d,
            short s => s,
            int i => i,
            _ => null,
        };

        static List<string> Strs(Lisp.List l) => l == null ? new List<string>() : l.Skip(1).Select(Lisp.Str).ToList();

        public static object Run(string file, Lisp.List ctx)
        {
            var b = DynALisp.Core.Plugin.BundleOf(One(ctx, "contents") as string);
            if (b == null) throw new ArgumentException("(Dyl:AsmWindow file ctx): no Contents folder given");
            var v = Get(ctx, "vars");
            var u = new Units
            {
                CannoScale = v != null && v.Count > 1 ? Real(v[1]) : null,
                Measurement = v != null && v.Count > 2 ? Int(v[2]) : 1,
                Insunits = v != null && v.Count > 3 ? Int(v[3]) : 4,
                Lunits = v != null && v.Count > 4 ? Int(v[4]) : 2,
                Luprec = v != null && v.Count > 5 ? Int(v[5]) : 4,
                Dimzin = v != null && v.Count > 6 ? Int(v[6]) : 0,
            };
            var pats = new Dictionary<string, (string Units, string File)?>(StringComparer.Ordinal);
            var pl = Get(ctx, "pats");
            if (pl != null)
                foreach (var x in pl.Skip(1))
                    if (x is Lisp.List p && p.Count > 0)
                    {
                        string units = p.Count > 1 ? Lisp.Str(p[1]) : "";
                        pats[Lisp.Str(p[0])] = units == "" ? null : ((string, string)?)(units, p.Count > 2 ? Lisp.Str(p[2]) : "");
                    }
            Shows.PatUnits pu = p => pats.TryGetValue(p, out var x) ? x : null;
            var vals = Get(ctx, "vals");
            var given = new Lisp.List();
            if (vals != null) given.AddRange(vals.Skip(1));
            bool resume = Lisp.True(One(ctx, "resume"));

            // The tabs of the Manager and their event: shown modeless (Engine\Tabs.cs):
            var probe = NewSession();
            Bridge.Give(probe, given);
            bool tabs = Modeless.Wants(probe);

            AsmTab t = null;
            Session got = null;
            int st = 0;
            if (!resume && tabs && _tab != null && (got = Modeless.Take(file, out st)) != null) t = _tab;
            else if (resume && _tab != null)
            {
                t = _tab;
                var ren = Get(ctx, "renames");
                if (ren != null)
                    t.Renamed(ren.Skip(1).OfType<Lisp.List>().Where(p => p.Count > 1).Select(p => (Lisp.Str(p[0]), Lisp.Str(p[1]))));
            }
            else
            {
                List<string[]> rows = null;
                var rl = Get(ctx, "rows");
                if (rl != null) rows = rl.Skip(1).OfType<Lisp.List>().Select(r => r.Select(Lisp.Str).ToArray()).ToList();
                string select = One(ctx, "select") as string;
                if (select == "") select = null;
                t = AsmTab.Open(b, u, rows, select, select == null ? _last : null, One(ctx, "shw") as string ?? "", _srt,
                                Strs(Get(ctx, "keys")), One(ctx, "border") as string, pu);
                if (t == null) return Code(rows == null && Materials.Both(b, u.Dimzin) != null ? -1 : -2);
            }

            string err = null;
            while (true)
            {
                if (got == null)
                {
                    t.Prep();
                    var s = NewSession();
                    Bridge.Give(s, given);
                    foreach (var x in t.Vals(err)) Put(s, x);
                    if (tabs)
                    {
                        _tab = t;
                        got = Modeless.Request(s, file, out st);
                        if (got == null) return null;
                    }
                    else
                    {
                        st = s.Show(file);
                        got = s;
                    }
                }
                string tab = Back(t, got);
                got = null;
                if (st == 0) return Result(0, t, null, null, null);
                if ((err = t.Check()) != null) continue;
                if (st == 8)
                {
                    _tab = t;
                    return Result(8, t, null, null, null);
                }
                if (st >= 3 && st != 90) continue;
                _last = t.Idx;
                var written = t.Write();
                if (written == false)
                    try
                    {
                        AcApp.ShowAlertDialog("Error: the presets could not be saved to\n" + Presets.FileW(b, AsmTab.Spec) + "\n(is it open in Excel?)");
                    }
                    catch { }
                _tab = null;
                return Result(st, t, tab, t.Shown?[0], written == true);
            }
        }

        static Session NewSession() =>
            new Session { ShowRoot = w => AcApp.ShowModalWindow(Bridge.MainWindow(), w, false), Dark = Bridge.DarkTheme(), FitToScreen = true, Places = new Places() };

        // A value of the Core into the session, as Bridge.Give puts the values of the Lisp:
        static void Put(Session s, WinVal v)
        {
            if (v.Rows != null) s.Rows[v.Key] = v.Rows;
            else if (v.List != null)
            {
                if (v.Key.EndsWith("/list", StringComparison.Ordinal)) s.Lists[v.Key.Substring(0, v.Key.Length - 5)] = v.List;
                else s.Lists[v.Key] = v.List;
            }
            else if (v.Key.EndsWith("/off", StringComparison.Ordinal))
            {
                if (v.Text == "1") s.Off.Add(v.Key.Substring(0, v.Key.Length - 4));
            }
            else s.Values[v.Key] = v.Text ?? "";
        }

        // What the window gave back (Remote>>Dyl:PresetWinGet): the assemblies, the list, the
        // Show group, saved as default when Set default was clicked; the tab picked:
        static string Back(AsmTab t, Session s)
        {
            string V(string k) => s.Values.TryGetValue(k, out var x) ? x : null;
            t.Get(s.Rows.TryGetValue("pst/rows", out var rows) ? rows : null, V("pst.idx"), V("pst.sel"), V("flt"), V("pst.shw"), V("srt"));
            _srt = t.Srt;
            if (V("pst.shd") == "1") SetEnv(ShowSetting, t.Shw);
            return V("tab");
        }

        // (setenv name value): the user setting of the FixedProfile of AutoCAD:
        static void SetEnv(string name, string value)
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using (var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(root + @"\FixedProfile\General"))
                    key?.SetValue(name, value ?? "");
            }
            catch { }
        }

        static ResultBuffer Code(int status)
        {
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Int16, (short)status));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        static void Pair(ResultBuffer rb, string key, string value)
        {
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Text, key));
            rb.Add(new TypedValue((int)LispDataType.Text, value ?? ""));
            rb.Add(new TypedValue((int)LispDataType.DottedPair));
        }

        // (status ("tab" . "i") ("id" . id) ("written" . "1") ("counts" (GROUP . n) ...)):
        static ResultBuffer Result(int status, AsmTab t, string tab, string id, bool? written)
        {
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Int16, (short)status));
            if (status == 90 && tab != null) Pair(rb, "tab", tab);
            if (id != null) Pair(rb, "id", id);
            if (written == true) Pair(rb, "written", "1");
            if (status == 8 && t != null)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                rb.Add(new TypedValue((int)LispDataType.Text, "counts"));
                foreach (var (g, n) in t.GroupCounts())
                {
                    rb.Add(new TypedValue((int)LispDataType.ListBegin));
                    rb.Add(new TypedValue((int)LispDataType.Text, g));
                    rb.Add(new TypedValue((int)LispDataType.Int32, n));
                    rb.Add(new TypedValue((int)LispDataType.DottedPair));
                }
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }
    }
}
