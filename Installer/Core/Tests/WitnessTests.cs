// WitnessTests.cs - the C# of DynALisp.Core compared with what the Lisp gives in AutoCAD
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
// Witness\Witness.lsp runs the Lisp, in AutoCAD, on the cases of Witness\In and writes what it
// gives to Witness\Lisp (see its header). Here the C# does the same steps on the same cases, in
// the same order, and writes the same lines: each section must be the same, line for line, and
// each file written the same, byte for byte, with the list separator and the code page of the
// computer the witness was taken on. Without Witness\Lisp (not taken yet), there is nothing to
// compare with: the C# is still run on every case, so it never fails on one.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class WitnessTests
    {
        static readonly string Dir = Path.Combine(Repo.Root, "Installer", "Core", "Tests", "Witness");
        static string In => Path.Combine(Dir, "In");
        static string LispDir => Path.Combine(Dir, "Lisp");
        // The sections whose Lisp is gone (the window code of a tab moved to .NET: asmwin,
        // asmtab), taken by the last witness that had it and kept as they were, compared with
        // the C# as the sections of Lisp are:
        static string KeptDir => Path.Combine(Dir, "Kept");

        const char Us = (char)31, Nil = (char)30;
        static readonly string[] Keys = { "QuickShape", "QuickDrawAssembly", "QuickDraw", "Material", "HatchPreset" };

        // ----- what the C# gives, written as Witness.lsp writes it -----

        static string Cell(string s) => s ?? Nil.ToString();
        static string Cell(bool b) => b ? "T" : Nil.ToString();
        static string Line(IEnumerable<string> cells) => cells == null || !cells.Any() ? Nil.ToString() : string.Join(Us.ToString(), cells.Select(Cell));

        sealed class Out
        {
            public readonly List<string> Lines = new List<string>();
            public void Put(string s) => Lines.Add(s);
            public void Sec(string name) => Put("#" + name);
            public void Rows(string name, IEnumerable<IEnumerable<string>> rows)
            {
                Sec(name);
                if (rows != null) foreach (var r in rows) Put(Line(r));
            }
        }

        static string Rel(string root, string p)
        {
            if (p == null) return null;
            string pre = root + Path.DirectorySeparatorChar;
            string r = p.StartsWith(pre, StringComparison.OrdinalIgnoreCase) ? p.Substring(pre.Length) : p;
            return r.Replace('/', '\\');
        }

        static void Copy(string from, string to)
        {
            Directory.CreateDirectory(to);
            foreach (var f in Directory.GetFiles(from)) File.Copy(f, Path.Combine(to, Path.GetFileName(f)));
            foreach (var d in Directory.GetDirectories(from)) Copy(d, Path.Combine(to, Path.GetFileName(d)));
        }

        static List<string> Names(Encoding enc) =>
            new Bundle(Path.Combine(In, "none"), ",", enc, null).Rows(Path.Combine(In, "Probes.csv"), 1).Select(r => r[0]).ToList();

        // The texts read as numbers, the numbers written, the units of the assemblies of Witness.lsp
        // (wt:nums, wt:reals, wt:dimzins, wt:factors), in the same order:
        static readonly string[] Nums =
        {
            "5", ".5", "5.", "-1.5", "+2", "1,5", "", "a", " 5", "5 ", "1e3", "1E-2", "1/2", "0", "-0",
            "12.70", "007", "1.2.3", "--1", "e5", "5e", "1'", "15.9", "0.62598425", "1 1/2", "2'6\"",
        };
        static readonly double[] Reals =
        {
            0.0, 0.5, -0.5, 1.0, 2.5, 10.0, 0.125, 2.675, 1.005, 15.9, 0.62598425, -0.00001, 123456.789,
            0.1, 0.3, 15.9 * (0.001 / 0.0254), 89.0 * (0.001 / 0.0254), 1.0 / 3.0, 1e-9,
            99.99999999, 0.05, 0.015, 12.7, 38.1, -0.004, 0.0005, 1e15,
        };
        static readonly int[] Dimzins = { 0, 3, 4, 8, 12 };
        static readonly (string, double)[] Factors = { ("inch", 0.001 / 0.0254), ("metre", 0.001 / 1.0) };

        // Probes.txt:
        static List<string> Probes(List<string> names)
        {
            var o = new Out();
            o.Sec("camel");
            foreach (var p in names) o.Put(Line(new[] { p, Presets.Camel(p) }));
            o.Sec("strcase");
            foreach (var p in names) o.Put(Line(new[] { p, Lisp.StrCase(p), p.ToLowerInvariant() }));
            o.Sec("less");
            foreach (var a in names)
                foreach (var b in names) o.Put(Line(new[] { a, b, Cell(string.CompareOrdinal(a, b) < 0) }));
            o.Rows("sort", new[] { names.OrderBy(x => x, StringComparer.Ordinal) });
            o.Sec("distof");
            foreach (var t in Nums) o.Put(Line(new[] { t, Lisp.Distof(t) is double v ? Lisp.Rtos(v, 15, 0) : null }));
            o.Sec("rtos");
            foreach (var dz in Dimzins)
                foreach (var n in new[] { 0, 2, 4, 8 })
                    foreach (var v in Reals)
                        o.Put(Line(new[] { dz.ToString(), n.ToString(), Lisp.Rtos(v, n, dz), Lisp.NumP(v, n, dz) }));
            return o.Lines;
        }

        // acad_strlsort follows the order of the words of Windows (its language, its accents):
        // the C# follows it only for the names of commands (Aliases.Order), so only they are
        // compared, as the witness sorts them (its section strlsort):
        static void Strlsort(List<string> lisp, List<string> names)
        {
            var sorted = Sections(lisp)["strlsort"][0].Split(Us).Where(Aliases.NameOk).ToList();
            Assert.Equal(sorted, names.Where(Aliases.NameOk).OrderBy(x => x, Aliases.Order).ToList());
        }

        // <case>\Witness.txt, the case copied to root (its files written there):
        static List<string> Case(string name, string root, string sep, Encoding enc, List<string> names, List<string> lisp = null)
        {
            Copy(Path.Combine(In, name), root);
            Directory.CreateDirectory(Path.Combine(root, "Contents", "Modules", "Dynalisp", "Res"));
            Directory.CreateDirectory(Path.Combine(root, "Contents", "Resources"));
            var b = new Bundle(Path.Combine(root, "Contents"), sep, enc, null);
            var o = new Out();
            var reads = new Dictionary<string, List<string[]>>();
            o.Put("#case" + Us + name);
            foreach (var key in Keys)
            {
                var s = Presets.Spec(key);
                var fle = Presets.File(b, s);
                o.Put("#" + key + " file" + Us + Cell(Rel(root, fle)));
                o.Rows(key + " head", new[] { b.Head(fle) });
                o.Rows(key + " csv", Presets.Csv(b, s));
                var defs = Presets.DefsOf(b, s, null, null);
                o.Rows(key + " defs", defs);
                o.Rows(key + " clean", Presets.Clean(s, Presets.Csv(b, s), null));
                var read = Presets.Read(b, s, defs, null);
                o.Rows(key + " read", read);
                o.Sec(key + " commands");
                foreach (var r in read) o.Put(Cell(Presets.Command(s, r[0])));
                reads[key] = read;
            }
            o.Rows("groups preset", Groups.Of(b, null).Select(g => new[] { g }));
            o.Rows("groups material", Groups.Of(b, "Material").Select(g => new[] { g }));
            o.Rows("groups defaults preset", Groups.DefaultsOf(b, null).Select(g => new[] { g }));
            o.Rows("groups defaults material", Groups.DefaultsOf(b, "Material").Select(g => new[] { g }));
            o.Sec("groups case");
            foreach (var g in new[] { "wall", "SECTION", "concrete", "INSULATION" }.Concat(names))
                o.Put(Line(new[] { g, Groups.CaseOf(b, g, null), Groups.CaseOf(b, g, "Material") }));
            var als = Aliases.Read(b);
            o.Rows("aliases read", als.Select(p => new[] { p.Key, p.Value }));
            o.Sec("aliases of");
            foreach (var c in als.Select(p => p.Value).Distinct())
                o.Put(Line(new[] { c }.Concat(Aliases.Of(c, als))));
            Assembly(b, o);
            Material(b, o);
            Show(b, o, lisp);
            AsmWin(b, o, lisp);
            AsmTabs(b, o, lisp);
            PresetTabs(b, o, lisp, "hptab", HpEdits, HpTabLisp);
            PresetTabs(b, o, lisp, "mattab", MatEdits, MatTabLisp);
            foreach (var key in Keys)
                o.Put("#" + key + " write" + Us + Cell(Presets.Write(b, Presets.Spec(key), reads[key])));
            o.Put("#groups write" + Us + Cell(Groups.Write(b, Groups.Of(b, null), null)));
            o.Put("#groups material write" + Us + Cell(Groups.Write(b, Groups.Of(b, "Material"), "Material")));
            o.Put("#aliases write" + Us + Cell(Aliases.Write(b, als)));
            return o.Lines;
        }

        // The assemblies of the case (wt:assemblies); a case read by the Lisp (Assemblies.Read
        // gives null: a layer of an older file made of a Quick Draw preset) has a line
        // #assemblies lisp in place of its rows:
        static void Assembly(Bundle b, Out o)
        {
            o.Rows("assemblies defs", Assemblies.Defs(b));
            var read = Assemblies.Read(b, 1.0, 0);
            if (read == null)
            {
                o.Sec(LispRead);
                return;
            }
            o.Rows("assemblies read", read);
            foreach (var dz in new[] { 0, 8 })
                foreach (var (name, f) in Factors)
                {
                    var sc = read.Select(r => Assemblies.Scale(r, f, 8, dz)).ToList();
                    o.Rows("assemblies " + name + " " + dz, sc.Select(r => new[] { r[0], r[3] }));
                    o.Rows("assemblies " + name + " " + dz + " back", sc.Select(r => new[] { r[0], Assemblies.Scale(r, 1.0 / f, 4, dz)[3] }));
                }
        }

        // The hatch presets and the materials of the case (wt:materials); a case read by the
        // Lisp (Materials.HatchDefs, RowDefs or Both give null: a default file missing, a
        // material of an older file in the group Section) has a line #materials lisp in place of
        // its rows:
        static void Material(Bundle b, Out o)
        {
            bool old = Materials.OldP(b);
            o.Put("#materials old" + Us + Cell(old));
            var lines = new Out();
            foreach (var dz in new[] { 0, 4 })
            {
                var hd = Materials.HatchDefs(b, dz);
                var md = Materials.RowDefs(b);
                var both = old ? null : Materials.Both(b, dz);
                if (hd == null || md == null || (!old && both == null))
                {
                    o.Sec(MatLisp);
                    return;
                }
                lines.Rows("materials hatch defs " + dz, hd);
                lines.Rows("materials defs " + dz, md);
                if (old) continue;
                lines.Rows("materials hatch read " + dz, both.Value.Hatches);
                lines.Rows("materials read " + dz, both.Value.Rows);
            }
            o.Lines.AddRange(lines.Lines);
        }

        // The setups of the drawing of Witness.lsp (wt:setups): MEASUREMENT, INSUNITS, LUNITS,
        // LUPREC and DIMZIN:
        static readonly (string Name, int[] Vars)[] Setups = { ("metric", new[] { 1, 4, 2, 4, 0 }), ("imperial", new[] { 0, 1, 2, 3, 8 }) };

        // The units of a pattern in the witness (wt:pat), never those of the computer:
        static (string, string)? Pat(string p) =>
            p.Contains("ISO") || p.StartsWith("AR-") ? ("Metric", "C:\\Pat\\" + p + ".pat")
            : p.StartsWith("NO") ? null
            : ("Imperial", "C:\\Pat\\acad.pat");

        // What the Quick Draw window shows of each assembly of the case (wt:shows), at the drawing
        // scale the witness had (its line #shows scale; 1:50 without a witness), the newlines of
        // a description as (char)29; a case the Lisp makes (Shows.All gives null) has a line
        // #shows lisp in place of its rows:
        static void Show(Bundle b, Out o, List<string> lisp)
        {
            string scale = "0.020000000000000";
            if (lisp != null && Sections(lisp).TryGetValue("shows scale", out var sc) && sc.Count > 0) scale = sc[0];
            o.Put("#shows scale" + Us + scale);
            var lines = new Out();
            foreach (var (name, v) in Setups)
            {
                var u = new Units
                {
                    CannoScale = Lisp.Distof(scale), Measurement = v[0], Insunits = v[1], Lunits = v[2], Luprec = v[3], Dimzin = v[4],
                };
                var pats = Shows.Patterns(b, u);
                var rows = pats == null ? null : Shows.All(b, u, pats.ToDictionary(p => p, p => Pat(p), StringComparer.Ordinal));
                if (rows == null)
                {
                    o.Sec(ShowLisp);
                    return;
                }
                lines.Rows("shows " + name, rows.Select(r => r.Select(c => c.Replace('\n', (char)29))));
            }
            o.Lines.AddRange(lines.Lines);
        }

        // What the Assembly Presets window is given (wt:asmwin), on the assemblies read, in each
        // drawing of the setups; the layer key of new lines is the one of the witness (the layer
        // keys stay in the Lisp; "" without a witness). A case the Lisp makes (a materials file of
        // DynALisp 1.1, AsmWindow.Mats gives null) has a line #asmwin lisp in place of its rows:
        static void AsmWin(Bundle b, Out o, List<string> lisp)
        {
            var secs = lisp != null ? Sections(lisp) : new Dictionary<string, List<string>>();
            var lines = new Out();
            foreach (var (name, v) in Setups)
            {
                var u = new Units { Measurement = v[0], Insunits = v[1], Lunits = v[2], Luprec = v[3], Dimzin = v[4] };
                var read = Materials.OldP(b) ? null : Assemblies.Read(b, 1.0, u.Dimzin);
                var presets = read?.Select(r => new[] { r[3], r[4], r[5] }).ToList();
                var lists = presets == null ? null : AsmWindow.Mats(b, u.Dimzin, presets);
                var data = lists == null ? null : AsmWindow.Data(b, u, lists.Mats.Select(m => m.Id));
                if (data == null)
                {
                    o.Sec(AsmWinLisp);
                    return;
                }
                var rows = Materials.Both(b, u.Dimzin).Value.Rows;
                lines.Rows("asmwin mats " + name, lists.Mats.Select(m => new[] { m.Id, m.Name, m.Row < 0 ? "" : rows[m.Row][0], m.Group }));
                lines.Rows("asmwin groups " + name, lists.Groups.Select(g => new[] { g }));
                lines.Rows("asmwin keys " + name, lists.Used.Select(k => new[] { k }));
                lines.Rows("asmwin data " + name, lists.Mats.Select((m, i) => new[] { m.Id, data.Value.Rsi[i], data.Value.Mass[i] }));
                string bk = secs.TryGetValue("asmwin bk " + name, out var bs) && bs.Count > 0 ? bs[0] : "";
                var def = AsmWindow.Def(lists.Mats, bk);
                lines.Put("#asmwin bk " + name + Us + bk);
                lines.Rows("asmwin def " + name, new[] { def });
                var ext = AsmWindow.Extras(b, u, def, bk, read.Select(r => new[] { r[3], r[4], r[5], Lisp.Nth(r, 7) ?? "" }));
                lines.Rows("asmwin rows " + name, read.Select((r, i) => new[] { r[0] }.Concat(ext[i]).Select(c => c.Replace('\n', (char)29))));
            }
            o.Lines.AddRange(lines.Lines);
        }

        // The Assembly Presets window as the preset engine showed it (wt:asmtab), at the drawing
        // scale and with the layer keys of the witness (the layer keys stay in the Lisp): its
        // values from no Quick Draw preset (manager), from a preset whose border is on the key
        // WALL and whose assembly is the second one read (quickdraw), and from one whose key and
        // assembly no longer exist (unknown); then, from no preset, each edit of wt:edits on the
        // first rows sent: the rows given back (in), the presets got from them (out) and why
        // they are not valid (check). A case the Lisp makes (AsmTab.Open gives null: a materials
        // file of DynALisp 1.1, a default file missing) has a line #asmtab lisp in place of
        // them; a witness taken before them has none of them:
        static void AsmTabs(Bundle b, Out o, List<string> lisp)
        {
            var secs = lisp != null ? Sections(lisp) : new Dictionary<string, List<string>>();
            bool witnessed = secs.TryGetValue("asmtab scale", out var sc) && sc.Count > 0;
            if (witnessed) o.Put("#asmtab scale" + Us + sc[0]);
            if (Materials.OldP(b) || AsmTab.Read(b, 0) == null)
            {
                o.Sec(AsmTabLisp);
                return;
            }
            if (!witnessed) return;
            var keys = secs.TryGetValue("asmtab layerkeys", out var ks) ? ks.Select(k => k.Split(Us)[0]).ToList() : new List<string>();
            o.Rows("asmtab layerkeys", keys.Select(k => new[] { k }));
            var lines = new Out();
            foreach (var (setup, v) in Setups)
            {
                var u = new Units
                {
                    CannoScale = Lisp.Distof(sc[0]), Measurement = v[0], Insunits = v[1], Lunits = v[2], Luprec = v[3], Dimzin = v[4],
                };
                var read = AsmTab.Read(b, u.Dimzin);
                foreach (var (name, bdr, asm) in new[] { ("manager", (string)null, (string)null), ("quickdraw", "WALL", "1"), ("unknown", "NOSUCHKEY", "as-NoSuchAssembly") })
                {
                    string id = asm == "1" ? (read.Count > 1 ? read[1][0] : read.Count > 0 ? read[0][0] : "") : asm;
                    string select = id != null && id != "" && !id.Contains(':') ? id : null;
                    var t = AsmTab.Open(b, u, null, select, null, "", "Name", keys, bdr, p => Pat(p));
                    t.Prep();
                    var vals = t.Vals(null);
                    lines.Sec("asmtab vals " + setup + " " + name);
                    foreach (var x in vals)
                        if (name == "manager" || x.Key == "pst.idx" || x.Key == "pst.sel" || x.Key == "ll/new") Val(lines, x);
                    if (name != "manager") continue;
                    var rs = t.Sent.Take(3).ToList();
                    t.Sent = rs;
                    t.SentOf = t.SentOf.Take(3).ToList();
                    t.Lst0 = t.SentOf;
                    foreach (var (edit, f) in Edits(t))
                    {
                        var input = f(rs);
                        if (input == null) continue;
                        t.Lst = t.Back(input);
                        var msg = t.Check();
                        lines.Rows("asmtab edit " + setup + " " + edit + " in", input.Select(r => r.Select(Nl)));
                        lines.Rows("asmtab edit " + setup + " " + edit + " out", Presets.Ids(t.Lst).Select(r => r.Select(Nl)));
                        lines.Put("#asmtab edit " + setup + " " + edit + " check" + Us + Cell(msg));
                    }
                }
            }
            o.Lines.AddRange(lines.Lines);
        }

        // The patterns the witness finds on the support path (wt:found), sorted as
        // acad_strlsort sorts them (wt:supportfake):
        static readonly string[] Found = { "ANSI31", "AR-CONC", "ACAD_ISO02W100", "BRICK", "ANSI37", "CROSS", "NOFILE", "SOLID", "ZIGZAG",
                                           "AR-B816", "GOST_GLASS", "DOTS" };

        // The Hatch Presets (hptab) and Materials (mattab) windows as the preset engine showed
        // them (wt:tab), at the drawing scale and with the layer keys of the witness, the
        // patterns of Found and the units of Pat: their values opened on no preset (manager), on
        // the second one read (select) and on one that does not exist (unknown: its preset shown
        // only, for both); then, from no preset, each edit of edits on the first rows sent: the
        // rows given back (in), the presets got from them (out) and why they are not valid
        // (check). A case the Lisp makes (a materials file of DynALisp 1.1, a default file
        // missing) has a line #<sec> lisp in place of them; a witness taken before them has none
        // of them, and the C# gives none either:
        static void PresetTabs(Bundle b, Out o, List<string> lisp, string sec,
                               List<(string, Func<PresetTab, List<string[]>, List<string[]>>)> edits, string mark)
        {
            var secs = lisp != null ? Sections(lisp) : new Dictionary<string, List<string>>();
            bool witnessed = secs.TryGetValue(sec + " scale", out var sc) && sc.Count > 0;
            if (lisp != null && !witnessed) return;
            string scale = witnessed ? sc[0] : "0.020000000000000";
            o.Put("#" + sec + " scale" + Us + scale);
            if (Materials.Both(b, 0) == null)
            {
                o.Sec(mark);
                return;
            }
            var keys = secs.TryGetValue(sec + " layerkeys", out var ks) ? ks.Select(k => k.Split(Us)[0]).ToList() : new List<string>();
            o.Rows(sec + " layerkeys", keys.Select(k => new[] { k }));
            var found = Found.OrderBy(p => p, Aliases.Order).ToList();
            o.Rows(sec + " found", found.Select(p => new[] { p }));
            foreach (var (setup, v) in Setups)
            {
                var u = new Units
                {
                    CannoScale = Lisp.Distof(scale), Measurement = v[0], Insunits = v[1], Lunits = v[2], Luprec = v[3], Dimzin = v[4],
                };
                foreach (var (name, sel) in new[] { ("manager", (string)null), ("select", "1"), ("unknown", "zz-NoSuchPreset") })
                {
                    PresetTab Of(string id) => sec == "hptab"
                        ? HatchTab.Open(b, u, id, null, "", "Name", keys, found, p => Pat(p))
                        : MatTab.Open(b, u, id, null, "", "Name", p => Pat(p));
                    var t = Of(null);
                    string id0 = sel == "1" ? (t.Lst.Count > 1 ? t.Lst[1][0] : t.Lst.Count > 0 ? t.Lst[0][0] : null) : sel;
                    if (id0 != null) t = Of(id0);
                    t.Prep();
                    var vals = t.Vals(null);
                    o.Sec(sec + " vals " + setup + " " + name);
                    foreach (var x in vals)
                        if (name == "manager" || x.Key == "pst.idx" || x.Key == "pst.sel") Val(o, x, false);
                    if (name != "manager") continue;
                    var rs = t.Sent.Take(3).ToList();
                    t.Sent = rs;
                    t.SentOf = t.SentOf.Take(3).ToList();
                    t.Lst0 = t.SentOf;
                    foreach (var (edit, f) in edits)
                    {
                        if (rs.Count == 0 && edit != "new" && edit != "newempty") continue;
                        var input = f(t, rs);
                        if (input == null) continue;
                        t.Lst = t.Back(input);
                        var msg = t.Check();
                        o.Rows(sec + " edit " + setup + " " + edit + " in", input.Select(r => r.Select(Nl)));
                        o.Rows(sec + " edit " + setup + " " + edit + " out", Presets.Ids(t.Lst).Select(r => r.Select(Nl)));
                        o.Put("#" + sec + " edit " + setup + " " + edit + " check" + Us + Cell(msg));
                    }
                }
            }
        }

        // wt:hpedits, wt:matedits: the edits made in each window to the first rows sent (rs),
        // null when an edit cannot be made on them:
        static Func<PresetTab, List<string[]>, List<string[]>> First(params (int, string)[] pairs) =>
            (t, rs) => new[] { Cells(rs[0], pairs) }.Concat(rs.Skip(1)).ToList();

        static List<(string, Func<PresetTab, List<string[]>, List<string[]>>)> Common(
            List<(string, Func<PresetTab, List<string[]>, List<string[]>>)> edits, params (int, string)[] added)
        {
            string[] New(PresetTab t) => t.Rows(new[] { t.NewRow })[0];
            return edits.Concat(new (string, Func<PresetTab, List<string[]>, List<string[]>>)[]
            {
                ("new", (t, rs) => rs.Concat(new[] { Cells(New(t), added) }).ToList()),
                ("newempty", (t, rs) => rs.Concat(new[] { New(t) }).ToList()),
                ("delete", (t, rs) => rs.Count > 1 ? new[] { rs[0] }.Concat(rs.Skip(2)).ToList() : null),
                ("move", (t, rs) => rs.Count > 1 ? new[] { rs[1], rs[0] }.Concat(rs.Skip(2)).ToList() : null),
            }).ToList();
        }

        static readonly List<(string, Func<PresetTab, List<string[]>, List<string[]>>)> HpEdits = Common(
            new List<(string, Func<PresetTab, List<string[]>, List<string[]>>)>
            {
                ("same", (t, rs) => rs),
                ("name", First((2, "Edited name"), (1, " section "))),
                ("pattern", First((3, "ansi37"), (4, "2.5"), (6, "30"))),
                ("scalebad", First((4, "0"))),
                ("scaletext", First((4, "1,5"))),
                ("scalefine", First((4, " .5 "))),
                ("anglebad", First((6, "x"))),
                ("keyempty", First((8, ""))),
                ("colorbad", First((22, "1"), (23, "300"))),
                ("coloroff", First((22, "0"), (23, "abc"))),
                ("background", First((24, "1"), (25, " 10, 20 ,30 "))),
                ("bgbad", First((24, "1"), (25, "1,2"))),
                ("existbad", First((41, "1"), (42, "0"))),
                ("weight", First((26, "1"), (27, "35"))),
                ("transbad", First((28, "1"), (29, "95"))),
                ("transtext", First((29, "5.5"))),
                ("linetype", First((47, "1"), (48, "dashed"), (49, "1"), (50, "2.5"))),
                ("ltempty", First((48, ""))),
                ("ltscalebad", First((50, "0"))),
                ("model", First((63, "Model"), (9, "1"), (10, "1"))),
                ("drafting", First((63, "Drafting"), (9, "1"), (10, "1"))),
                ("solid", First((3, "SOLID"))),
                ("none", First((3, ""))),
            },
            (2, "Added"), (3, "ANSI31"));

        static readonly List<(string, Func<PresetTab, List<string[]>, List<string[]>>)> MatEdits = Common(
            new List<(string, Func<PresetTab, List<string[]>, List<string[]>>)>
            {
                ("same", (t, rs) => rs),
                ("name", First((2, "Edited name"), (1, " concrete "))),
                ("cut", First((3, "hp-Brick"))),
                ("cutbad", First((3, "hp-NoSuchHatch"))),
                ("cutnone", First((3, ""))),
                ("surface", First((4, ""))),
                ("surfacebad", First((4, "hp-NoSuchHatch"))),
                ("data", First((5, "0.5"), (6, "1200"), (7, "2"))),
                ("datafine", First((8, "0.0123456"), (9, "123456.7"))),
                ("datablank", First((5, ""), (7, " "))),
                ("dataspaces", First((5, " 0.5 "))),
                ("databad", First((6, "-1"))),
                ("datazero", First((7, "0"))),
                ("datatext", First((8, "abc"))),
                ("datacomma", First((9, "1,5"))),
            },
            (2, "Added"), (3, "hp-Void"), (5, "0.04"));

        static string Nl(string s) => s?.Replace('\n', (char)29);

        // A value of the window on one line (wt:val): S and its text, L and its items, R and the
        // cells of each row (a line each), N and the count of the rows of the presets and of their
        // defaults:
        static void Val(Out o, WinVal v, bool counts = true)
        {
            if (v.Text != null) o.Put(Line(new[] { v.Key, "S", Nl(v.Text) }));
            else if (counts && v.Rows != null && v.Rows.Count > 0 && (v.Key == "pst/rows" || v.Key == "pst/defs"))
                o.Put(Line(new[] { v.Key, "N", v.Rows.Count.ToString() }));
            else if (v.Rows != null && v.Rows.Count > 0)
                foreach (var r in v.Rows) o.Put(Line(new[] { v.Key, "R" }.Concat(r.Select(Nl))));
            else o.Put(Line(new[] { v.Key, "L" }.Concat((v.List ?? new List<string>()).Select(Nl))));
        }

        // (Dyl:QuickDrawAsmEncode rows):
        static string Encode(IEnumerable<string[]> rows) => string.Join("\n", rows.Select(r => string.Join("\t", r)));

        // wt:cells, wt:layer:
        static string[] Cells(string[] r, params (int, string)[] pairs)
        {
            foreach (var (i, x) in pairs) r = Lisp.Subst(r, i, x);
            return r;
        }

        static string[] LayerCells(string[] r, params (int, string)[] pairs)
        {
            var ls = AsmTab.Decode(Lisp.Nth(r, 15) ?? "");
            if (ls.Count == 0) return null;
            return Lisp.Subst(r, 15, Encode(new[] { Cells(ls[0], pairs) }.Concat(ls.Skip(1))));
        }

        // wt:edits: the edits made in the window to the first rows sent, null when an edit
        // cannot be made on them:
        internal static List<(string, Func<List<string[]>, List<string[]>>)> Edits(AsmTab t)
        {
            Func<List<string[]>, List<string[]>> First(Func<string[], string[]> f) =>
                rs => rs.Count == 0 ? null : f(rs[0]) is string[] r ? new[] { r }.Concat(rs.Skip(1)).ToList() : null;
            Func<List<string[]>, List<string[]>> Layer(params (int, string)[] pairs) => First(r => LayerCells(r, pairs));
            Func<List<string[]>, List<string[]>> Row(params (int, string)[] pairs) => First(r => Cells(r, pairs));
            string[] New() => t.Rows(new[] { AsmTab.New })[0];
            return new List<(string, Func<List<string[]>, List<string[]>>)>
            {
                ("same", rs => rs.Count == 0 ? null : rs),
                ("name", Row((2, "Edited name"), (8, "  A description  "), (13, " Family "), (14, " Short "))),
                ("ratings", Row((9, "60"), (10, "45x"))),
                ("sound", Row((9, ""), (10, "90"), (11, "50"), (12, "4.5"))),
                ("ratingsok", Row((9, " 45 "), (10, "120"), (11, "0"), (12, "55"))),
                ("thick", Layer((2, "12.5"))),
                ("thickfine", Layer((2, "0.62598425"))),
                ("thickbad", Layer((2, "0"))),
                ("thicktext", Layer((2, "abc"))),
                ("nomat", Layer((1, ""))),
                ("framing", Layer((44, "mt-Void"), (45, " 23,5 "))),
                ("framingbad", Layer((44, "mt-Void"), (45, "100"))),
                ("band", Layer((5, "1"), (8, "abc"))),
                ("bandangle", Layer((5, "1"), (9, "85"))),
                ("bandmiter", Layer((5, "1"), (11, "0.5"))),
                ("bandfactor", Layer((5, "1"), (38, "1"), (39, "0"))),
                ("bandoffset", Layer((5, "1"), (40, "1"), (41, "x"))),
                ("bandok", Layer((5, "1"), (6, "Edge"), (8, "2"), (9, "30"), (11, "2"), (38, "1"), (39, "1.5"), (40, "1"), (41, "2"), (42, "-1"))),
                ("bandoff", Layer((5, "0"), (6, "Edge"))),
                ("border", Layer((14, "1"), (15, ""))),
                ("borderok", Layer((14, "1"), (15, "hatch"), (19, "1"), (20, "dashed"), (21, "1"), (22, "2"))),
                ("borderbad", Layer((14, "1"), (15, "HATCH"), (17, "1"), (18, "300"))),
                ("borderoff", Layer((14, "0"), (15, "OTHERKEY"))),
                ("hatchbad", Layer((27, "1"), (36, "1"), (37, "95"))),
                ("hatchkey", Layer((27, "1"), (28, "1"), (29, "1,2,3"), (30, "1"), (31, "dashed"), (32, "1"), (33, "2"))),
                ("hatchoff", Layer((27, "0"))),
                ("flags", Layer((16, "1"), (46, "1"), (47, "1"))),
                ("lines", Row((16, "1"), (17, ""))),
                ("linesok", Row((16, "1"), (17, "hatch"), (20, "1"), (21, "dashed"), (28, "1"), (29, "a"))),
                ("linesbad", Row((28, "1"), (29, "A"), (30, "1"), (31, "abc"))),
                ("linesoff", Row((16, "0"), (17, ""), (28, "0"), (29, ""))),
                ("nolayers", Row((15, ""))),
                ("new", rs =>
                {
                    var r = Cells(New(), (2, "Added"));
                    return rs.Concat(new[] { LayerCells(r, (1, "mt-Void"), (2, "25")) ?? r }).ToList();
                }),
                ("newempty", rs => rs.Concat(new[] { New() }).ToList()),
                ("delete", rs => rs.Count > 1 ? new[] { rs[0] }.Concat(rs.Skip(2)).ToList() : null),
                ("move", rs => rs.Count > 1 ? new[] { rs[1], rs[0] }.Concat(rs.Skip(2)).ToList() : null),
            };
        }

        const string LispRead = "assemblies lisp", MatLisp = "materials lisp", ShowLisp = "shows lisp", AsmWinLisp = "asmwin lisp",
                     AsmTabLisp = "asmtab lisp", HpTabLisp = "hptab lisp", MatTabLisp = "mattab lisp";

        // The cases whose assemblies or materials the Lisp reads, the C# giving null: the
        // marker, the cases, the sections of the Lisp then left out (those of its prefix, but
        // the one kept):
        static readonly (string Mark, string[] Cases, string Prefix, string Kept)[] ReadByLisp =
        {
            (LispRead, new[] { "assemblies-preset" }, "assemblies ", "assemblies defs"),
            (MatLisp, new[] { "assemblies", "assemblies-preset", "empty" }, "materials ", "materials old"),
            (ShowLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "shows ", "shows scale"),
            (AsmWinLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "asmwin ", ""),
            (AsmTabLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "asmtab ", "asmtab scale"),
            (HpTabLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "hptab ", "hptab scale"),
            (MatTabLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "mattab ", "mattab scale"),
        };

        // ----- the witness of the Lisp -----

        static Dictionary<string, string> Info()
        {
            var res = new Dictionary<string, string>();
            foreach (var l in ReadLines(Path.Combine(LispDir, "Info.txt")).Skip(1))
            {
                var c = l.Split(Us);
                res[c[0]] = c.Length > 1 ? c[1] : "";
            }
            return res;
        }

        static List<string> ReadLines(string path)
        {
            var text = File.ReadAllText(path, new UTF8Encoding(false)).TrimStart('﻿');
            var lines = Csv.Lines(text);
            if (lines.Count > 0 && lines[lines.Count - 1] == "") lines.RemoveAt(lines.Count - 1);
            return lines;
        }

        static Encoding CodePage(string name)
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
            var digits = new string((name ?? "").Where(char.IsDigit).ToArray());
            return digits.Length > 0 ? Encoding.GetEncoding(int.Parse(digits)) : Encoding.GetEncoding(1252);
        }

        // The sections of both, the first line that differs in each, all of them at once:
        static void Same(string what, List<string> lisp, List<string> cs)
        {
            var bad = new List<string>();
            var a = Sections(lisp);
            var b = Sections(cs);
            foreach (var name in a.Keys.Union(b.Keys))
            {
                a.TryGetValue(name, out var x);
                b.TryGetValue(name, out var y);
                x ??= new List<string>();
                y ??= new List<string>();
                for (int i = 0; i < Math.Max(x.Count, y.Count); i++)
                {
                    string l = i < x.Count ? x[i] : "(none)", c = i < y.Count ? y[i] : "(none)";
                    if (l != c)
                    {
                        bad.Add($"{what} #{name} line {i + 1}:\n  Lisp: {Show(l)}\n  C#:   {Show(c)}");
                        break;
                    }
                }
            }
            Assert.True(bad.Count == 0, string.Join("\n", bad));
        }

        static string Show(string s) => s.Replace(Us, '|').Replace(Nil, '~');

        static Dictionary<string, List<string>> Sections(List<string> lines)
        {
            var res = new Dictionary<string, List<string>>();
            List<string> cur = null;
            foreach (var l in lines)
            {
                if (l.StartsWith("#"))
                {
                    // (a section with its value on its line: #name<US>value)
                    var head = l.Split(Us);
                    res[head[0].Substring(1)] = cur = new List<string>();
                    if (head.Length > 1) cur.Add(string.Join(Us.ToString(), head.Skip(1)));
                }
                else cur?.Add(l);
            }
            return res;
        }

        [Fact]
        public void TheProbesGiveWhatTheLispGives()
        {
            if (!File.Exists(Path.Combine(LispDir, "Probes.txt")))
            {
                Assert.NotEmpty(Probes(Names(CodePage(null))));
                return;
            }
            var enc = CodePage(Info()["codepage"]);
            var lisp = ReadLines(Path.Combine(LispDir, "Probes.txt"));
            var names = Names(enc);
            var sections = Sections(lisp);
            sections.Remove("strlsort");
            Same("Probes", sections.SelectMany(x => new[] { "#" + x.Key }.Concat(x.Value)).ToList(), Probes(names));
            Strlsort(lisp, names);
        }

        [Fact]
        public void EveryCaseGivesWhatTheLispGives()
        {
            bool lisp = File.Exists(Path.Combine(LispDir, "Info.txt"));
            var info = lisp ? Info() : new Dictionary<string, string> { ["sep"] = ",", ["codepage"] = "ANSI_1252" };
            var enc = CodePage(info["codepage"]);
            var names = Names(enc);
            var work = Path.Combine(Path.GetTempPath(), "dyl-witness-" + Guid.NewGuid().ToString("N"));
            try
            {
                foreach (var dir in Directory.GetDirectories(In).OrderBy(d => d, StringComparer.Ordinal))
                {
                    string name = Path.GetFileName(dir), root = Path.Combine(work, name);
                    var witness = Path.Combine(LispDir, name);
                    if (lisp) Assert.True(Directory.Exists(witness), "No witness of the case " + name + ": run Witness.lsp again.");
                    var lines = lisp ? ReadLines(Path.Combine(witness, "Witness.txt")) : null;
                    var keptFile = Path.Combine(KeptDir, name, "Witness.txt");
                    if (lisp)
                    {
                        Assert.True(File.Exists(keptFile), "No kept witness of the case " + name + " (Witness\\Kept): its sections cannot be taken again.");
                        lines.AddRange(ReadLines(keptFile));
                    }
                    var cs = Case(name, root, info["sep"], enc, names, lines);
                    if (!lisp) continue;
                    foreach (var (mark, cases, prefix, kept) in ReadByLisp)
                    {
                        // (a window whose sections came after the witness was taken: neither has them)
                        if (kept != "" && !lines.Contains("#" + kept) && !lines.Any(l => l.StartsWith("#" + kept + Us))
                            && !cs.Any(l => l == "#" + kept || l.StartsWith("#" + kept + Us))) continue;
                        Assert.True(cases.Contains(name) == cs.Contains("#" + mark), name + ": #" + mark + (cases.Contains(name) ? " expected" : " not expected"));
                        if (!cs.Contains("#" + mark)) continue;
                        // (the rows read by the Lisp alone left out, the one kept still compared:)
                        var keep = Sections(lines).Where(x => !(x.Key.StartsWith(prefix) && x.Key != kept));
                        lines = keep.SelectMany(x => new[] { "#" + x.Key }.Concat(x.Value)).ToList();
                        cs = cs.Where(l => l != "#" + mark).ToList();
                    }
                    Same(name, lines, cs);
                    // The files written, byte for byte:
                    var lf = Directory.Exists(Path.Combine(witness, "User"))
                        ? Directory.GetFiles(Path.Combine(witness, "User"), "*", SearchOption.AllDirectories).Select(f => Path.GetRelativePath(witness, f)).ToList()
                        : new List<string>();
                    var cf = Directory.GetFiles(Path.Combine(root, "User"), "*", SearchOption.AllDirectories).Select(f => Path.GetRelativePath(root, f)).ToList();
                    Assert.Equal(lf.OrderBy(x => x, StringComparer.Ordinal), cf.OrderBy(x => x, StringComparer.Ordinal));
                    foreach (var f in lf)
                        Assert.True(File.ReadAllBytes(Path.Combine(witness, f)).SequenceEqual(File.ReadAllBytes(Path.Combine(root, f))),
                                    name + ": " + f + " is not written as the Lisp writes it.");
                }
            }
            finally
            {
                try { Directory.Delete(work, true); } catch (Exception) { }
            }
        }

        // Where the C# lines go when asked (DYL_WITNESS_CS=<folder>), to read them beside the Lisp:
        [Fact]
        public void TheLinesOfTheCSharpCanBeWritten()
        {
            var to = Environment.GetEnvironmentVariable("DYL_WITNESS_CS");
            if (string.IsNullOrEmpty(to)) return;
            var enc = CodePage(null);
            var names = Names(enc);
            Directory.CreateDirectory(to);
            File.WriteAllLines(Path.Combine(to, "Probes.txt"), Probes(names));
            foreach (var dir in Directory.GetDirectories(In))
            {
                string name = Path.GetFileName(dir), root = Path.Combine(to, name + " work");
                if (Directory.Exists(root)) Directory.Delete(root, true);
                File.WriteAllLines(Path.Combine(to, name + ".txt"), Case(name, root, ",", enc, names));
            }
        }
    }
}
