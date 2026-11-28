// PresetTabs.cs - DynALisp.Windows: the preset windows whose data DynALisp.Core.dll makes
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
// The tabs of the Manager moved to .NET, each one a Lisp function of its own, (Dyl:<X>Window file
// ctx), that shows its window (file: its .xaml in Res, full path) on the presets made and read
// back by DynALisp.Core.dll (Data\PresetTab.cs and the class of the tab) with no Lisp in between:
//
//   (Dyl:AsmWindow file ctx)     the Assembly Presets (AsmTab, Res\Dyl-AssemblyPresets.xaml)
//   (Dyl:HatchWindow file ctx)   the Hatch Presets (HatchTab, Res\Dyl-HatchPresets.xaml)
//   (Dyl:MatWindow file ctx)     the Materials (MatTab, Res\Dyl-Materials.xaml)
//
// The 860 assemblies, made into rows by the Core, given to the Lisp, then by the Lisp to
// Dyl:Window, took most of the time of the tab. The Lisp (Dyl:QuickDrawAsmDialog of
// Apps\Draw\Dyl-QuickDraw.lsp, Remote>>Dyl:MaterialTab of Remote\Dyl-Materials.lsp) gives what
// only it has, ctx ((key . value) ...):
//
//   ("contents" . path)          the Contents folder of DynALisp (*dyl:contents)
//   ("vars" cannoscale measurement insunits lunits luprec dimzin)   the system variables
//   ("keys" key ...)             the names of the layer keys defined (Remote>>Dyl:LayerKeyRead)
//   ("select" . id)              the preset to show (absent: the one shown last)
//   ("shw" . group)              the Show group set as default (DynalispPresetShow...)
//   ("pats" (pattern units file) ...)   the units of the patterns of Dyl:AsmTabPats or
//                                Dyl:PresetTabPats ("" when no file has it)
//   ("found" pattern ...)        the Hatch Presets: the patterns of the .pat files of the
//                                support path (Remote>>Dyl:SupportDefs)
//   ("border" . key)             the Assembly Presets: the layer key of the border of the Quick
//                                Draw preset the window is opened from (absent: from no preset)
//   ("rows" (preset) ...)        the Assembly Presets: the assemblies, when the Lisp reads them
//   ("resume" . T)               the window shown again after a status for the Lisp (see
//                                below), on the presets being edited, with what it gives them:
//                                ("renames" (old . new) ...) the groups renamed in the Preset
//                                Groups window, ("put" (column . value) ...) values given to
//                                the presets selected, ("addpat" . pattern) a pattern added to
//                                the Pattern list, ("addfound" . pattern) one found once rebuilt
//   ("vals" (key . value) ...)   the values of Dyl:WinShow: the tabs of the Manager and the
//                                Open Docs buttons
//
// and gets (status ("tab" . "i") ("id" . id) ("written" . "1") ("counts" (GROUP . n) ...)
// ("shown" cell ...) ("sel" (cell ...) ...)):
//
//   nil   the window is shown modeless (the tab of the Manager), nothing to do yet
//   -1    the Lisp reads the assemblies: called again with ("rows" ...)
//   -2    the materials cannot be read (a default file missing)
//   -3    called again with the units of the patterns (pats) and the patterns found (found):
//         asked only when the window opens, so a click of the Manager is answered at once
//   0     Cancel
//   1, 2  OK (the preset selected: id, shown), Save; written when the presets were saved
//   8     the Preset Groups window to show (counts: the presets of each group), then this
//         window again (resume)
//   90    another tab of the Manager picked (tab): saved, as Save
//   other the codes the Lisp runs (an open button, a pick in the drawing): the preset shown
//         (shown) and those selected in the order of the list (sel, the Hatch Presets 7), then
//         this window again (resume); the other codes of 3 or more show it again at once
//
// The rows sent, the presets being edited and the window waiting for a click of the Manager are
// kept here between two calls, for each tab; the sort and the preset shown last for the session.
// The Show group set as default is saved here (setenv), as Remote>>Dyl:PresetWinGet did.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using DynALisp.Core.Data;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Windows.PresetTabs))]

namespace DynALisp.Windows
{
    // The Lisp functions, their types those of this assembly only: a DynALisp.Core.dll not loaded
    // fails the call (caught), never the plugin:
    public class PresetTabs
    {
        [LispFunction("Dyl:AsmWindow")]
        public object Asm(ResultBuffer args) => Show(args, "Dyl:AsmWindow", () => TabRun.Asm);

        [LispFunction("Dyl:HatchWindow")]
        public object Hatch(ResultBuffer args) => Show(args, "Dyl:HatchWindow", () => TabRun.Hatch);

        [LispFunction("Dyl:MatWindow")]
        public object Mat(ResultBuffer args) => Show(args, "Dyl:MatWindow", () => TabRun.Mat);

        static object Show(ResultBuffer args, string name, Func<TabKind> kind)
        {
            string what = "the window";
            try
            {
                var k = kind();
                what = k.What;
                var a = Lisp.Read(args);
                string file = a.Count > 0 ? a[0] as string : null;
                if (string.IsNullOrEmpty(file)) throw new ArgumentException("(" + name + " file ctx): no file given");
                return TabRun.Run(k, file, a.Count > 1 ? a[1] as Lisp.List : null);
            }
            catch (System.Exception e)
            {
                try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n--> Unable to show " + what + ": " + Bridge.Message(e)); } catch { }
                return null;
            }
        }
    }

    // A tab: what it opens, the codes it gives to the Lisp, what it is given back; the window being
    // edited (kept for a click of the Manager and for the Lisp), the units of the patterns, the
    // sort of the list and the preset shown last, for the session:
    abstract class TabKind
    {
        public PresetTab Tab;
        public string Srt = "Name";
        public int? Last;
        public readonly Dictionary<string, (string Units, string File)?> Pats =
            new Dictionary<string, (string Units, string File)?>(StringComparer.Ordinal);

        public abstract string What { get; }
        public abstract string ShowSetting { get; }

        // The presets read and the window opened on them; null with the status to give back:
        public abstract PresetTab Open(Bundle b, Units u, Lisp.List ctx, string select, out int status);

        // The units of the patterns asked before the window opens (status -3):
        public virtual bool NeedsPats => true;

        // The codes the Lisp runs, the window shown again after (resume):
        public virtual bool ForLisp(int status) => status == 8;

        // What the Lisp gives the window shown again after it ran a code:
        public virtual void Resume(PresetTab t, Lisp.List ctx)
        {
            // (the layer keys defined again: the Layer Keys window may have added one)
            if (TabRun.Get(ctx, "keys") is Lisp.List keys) t.Defined = TabRun.Strs(keys);
            var ren = TabRun.Get(ctx, "renames");
            if (ren != null)
                t.Renamed(ren.Skip(1).OfType<Lisp.List>().Where(p => p.Count > 1).Select(p => (Lisp.Str(p[0]), Lisp.Str(p[1]))));
            var put = TabRun.Get(ctx, "put");
            if (put != null)
                foreach (var p in put.Skip(1).OfType<Lisp.List>().Where(p => p.Count > 1))
                    t.Put(TabRun.Int(p[0]), Lisp.Str(p[1]));
        }

        // The presets selected, given with the code (sel):
        public virtual bool WantsSel(int status) => false;

        public Shows.PatUnits PatUnits => p => Pats.TryGetValue(p, out var x) ? x : null;
    }

    sealed class AsmKind : TabKind
    {
        public override string What => "the Assembly Presets";
        public override string ShowSetting => "DynalispPresetShowQuickDrawAssembly";

        public override PresetTab Open(Bundle b, Units u, Lisp.List ctx, string select, out int status)
        {
            List<string[]> rows = null;
            var rl = TabRun.Get(ctx, "rows");
            if (rl != null) rows = rl.Skip(1).OfType<Lisp.List>().Select(r => r.Select(Lisp.Str).ToArray()).ToList();
            var t = AsmTab.Open(b, u, rows, select, select == null ? Last : null, TabRun.One(ctx, "shw") as string ?? "", Srt,
                                TabRun.Strs(TabRun.Get(ctx, "keys")), TabRun.One(ctx, "border") as string, PatUnits);
            status = t != null ? 0 : rows == null && Materials.Both(b, u.Dimzin) != null ? -1 : -2;
            return t;
        }

        // (its pats always given: Dyl:AsmTabPats reads no .pat file of its own)
        public override bool NeedsPats => false;
    }

    sealed class HatchKind : TabKind
    {
        public override string What => "the Hatch Presets";
        public override string ShowSetting => "DynalispPresetShowHatchPreset";

        public override PresetTab Open(Bundle b, Units u, Lisp.List ctx, string select, out int status)
        {
            var t = HatchTab.Open(b, u, select, select == null ? Last : null, TabRun.One(ctx, "shw") as string ?? "", Srt,
                                  TabRun.Strs(TabRun.Get(ctx, "keys")), TabRun.Strs(TabRun.Get(ctx, "found")), PatUnits);
            status = t != null ? 0 : -2;
            return t;
        }

        // 5 the Layer Keys window, 7 Draw legend..., 8 the Preset Groups window, 10 Pick hatch...,
        // 11 to 13 the color window of AutoCAD, 14 the .pat file in Notepad (the codes of
        // Remote>>Dyl:MaterialTab):
        public override bool ForLisp(int status) => status == 5 || status == 7 || status == 8 || (status >= 10 && status <= 14);

        public override bool WantsSel(int status) => status == 7;

        public override void Resume(PresetTab t, Lisp.List ctx)
        {
            base.Resume(t, ctx);
            var h = (HatchTab)t;
            if (TabRun.One(ctx, "addfound") is string f) h.AddFound(f);
            if (TabRun.One(ctx, "addpat") is string p) h.AddPat(p);
        }
    }

    sealed class MatKind : TabKind
    {
        public override string What => "the Materials";
        public override string ShowSetting => "DynalispPresetShowMaterial";

        public override PresetTab Open(Bundle b, Units u, Lisp.List ctx, string select, out int status)
        {
            var t = MatTab.Open(b, u, select, select == null ? Last : null, TabRun.One(ctx, "shw") as string ?? "", Srt, PatUnits);
            status = t != null ? 0 : -2;
            return t;
        }

        // 8 the Preset Groups window, 9 the Hatch Presets window on the Cut hatch preset, 10 on
        // the Surface one:
        public override bool ForLisp(int status) => status >= 8 && status <= 10;
    }

    static class TabRun
    {
        public static readonly TabKind Asm = new AsmKind(), Hatch = new HatchKind(), Mat = new MatKind();

        public static Lisp.List Get(Lisp.List ctx, string key)
        {
            if (ctx == null) return null;
            foreach (var x in ctx)
                if (x is Lisp.List l && l.Count > 0 && l[0] as string == key) return l;
            return null;
        }

        // The value of a pair (key . value), null when absent or nil:
        public static object One(Lisp.List ctx, string key)
        {
            var l = Get(ctx, key);
            return l != null && l.Count > 1 ? l[1] : null;
        }

        public static int Int(object o) => o switch
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

        public static List<string> Strs(Lisp.List l) => l == null ? new List<string>() : l.Skip(1).Select(Lisp.Str).ToList();

        // The units of the patterns of ctx (pats) into those of the tab:
        static bool PatsOf(TabKind k, Lisp.List ctx)
        {
            var pl = Get(ctx, "pats");
            if (pl == null) return false;
            foreach (var x in pl.Skip(1))
                if (x is Lisp.List p && p.Count > 0)
                {
                    string units = p.Count > 1 ? Lisp.Str(p[1]) : "";
                    k.Pats[Lisp.Str(p[0])] = units == "" ? null : ((string, string)?)(units, p.Count > 2 ? Lisp.Str(p[2]) : "");
                }
            return true;
        }

        public static object Run(TabKind k, string file, Lisp.List ctx)
        {
            var b = DynALisp.Core.Plugin.BundleOf(One(ctx, "contents") as string);
            if (b == null) throw new ArgumentException("(Dyl:Window of " + k.What + " file ctx): no Contents folder given");
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
            var vals = Get(ctx, "vals");
            var given = new Lisp.List();
            if (vals != null) given.AddRange(vals.Skip(1));
            bool resume = Lisp.True(One(ctx, "resume"));

            // The tabs of the Manager and their event: shown modeless (Engine\Tabs.cs):
            var probe = NewSession();
            Bridge.Give(probe, given);
            bool tabs = Modeless.Wants(probe);

            PresetTab t = null;
            Session got = null;
            int st = 0;
            if (!resume && tabs && k.Tab != null && (got = Modeless.Take(file, out st)) != null) t = k.Tab;
            else if (resume && k.Tab != null)
            {
                t = k.Tab;
                PatsOf(k, ctx);
                k.Resume(t, ctx);
            }
            else
            {
                if (k.NeedsPats && Get(ctx, "pats") == null) return Code(-3);
                k.Pats.Clear();
                PatsOf(k, ctx);
                string select = One(ctx, "select") as string;
                if (select == "") select = null;
                t = k.Open(b, u, ctx, select, out int status);
                if (t == null) return Code(status);
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
                        k.Tab = t;
                        got = Modeless.Request(s, file, out st);
                        if (got == null) return null;
                    }
                    else
                    {
                        st = s.Show(file);
                        got = s;
                    }
                }
                string tab = Back(k, t, got);
                got = null;
                if (st == 0) return Result(k, 0, t, null, null);
                if ((err = t.Check()) != null) continue;
                if (k.ForLisp(st))
                {
                    k.Tab = t;
                    return Result(k, st, t, null, null);
                }
                if (st >= 3 && st != 90) continue;
                k.Last = t.Idx;
                var written = t.Write();
                if (written == false)
                    try
                    {
                        AcApp.ShowAlertDialog("Error: the presets could not be saved to\n" + Presets.FileW(b, t.Tool) + "\n(is it open in Excel?)");
                    }
                    catch { }
                k.Tab = null;
                return Result(k, st, t, tab, written == true);
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

        // What the window gave back (Remote>>Dyl:PresetWinGet): the presets, the list, the
        // Show group, saved as default when Set default was clicked; the tab picked:
        static string Back(TabKind k, PresetTab t, Session s)
        {
            string V(string key) => s.Values.TryGetValue(key, out var x) ? x : null;
            t.Get(s.Rows.TryGetValue("pst/rows", out var rows) ? rows : null, V("pst.idx"), V("pst.sel"), V("flt"), V("pst.shw"), V("srt"));
            k.Srt = t.Srt;
            if (V("pst.shd") == "1") SetEnv(k.ShowSetting, t.Shw);
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

        static void Cells(ResultBuffer rb, IEnumerable<string> cells)
        {
            foreach (var c in cells) rb.Add(new TypedValue((int)LispDataType.Text, c ?? ""));
        }

        // (status ("tab" . "i") ("id" . id) ("written" . "1") ("counts" (GROUP . n) ...)
        // ("shown" cell ...) ("sel" (cell ...) ...)):
        static ResultBuffer Result(TabKind k, int status, PresetTab t, string tab, bool? written)
        {
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Int16, (short)status));
            var shown = status == 0 ? null : t?.Shown;
            if (status == 90 && tab != null) Pair(rb, "tab", tab);
            if (shown != null && status != 8) Pair(rb, "id", shown[0]);
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
            if (shown != null && status != 8)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                rb.Add(new TypedValue((int)LispDataType.Text, "shown"));
                Cells(rb, shown);
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            if (k.WantsSel(status) && t != null)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                rb.Add(new TypedValue((int)LispDataType.Text, "sel"));
                foreach (var r in t.Selected())
                {
                    rb.Add(new TypedValue((int)LispDataType.ListBegin));
                    Cells(rb, r);
                    rb.Add(new TypedValue((int)LispDataType.ListEnd));
                }
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }
    }
}
