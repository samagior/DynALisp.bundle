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

        const string LispRead = "assemblies lisp", MatLisp = "materials lisp", ShowLisp = "shows lisp", AsmWinLisp = "asmwin lisp";

        // The cases whose assemblies or materials the Lisp reads, the C# giving null: the
        // marker, the cases, the sections of the Lisp then left out (those of its prefix, but
        // the one kept):
        static readonly (string Mark, string[] Cases, string Prefix, string Kept)[] ReadByLisp =
        {
            (LispRead, new[] { "assemblies-preset" }, "assemblies ", "assemblies defs"),
            (MatLisp, new[] { "assemblies", "assemblies-preset", "empty" }, "materials ", "materials old"),
            (ShowLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "shows ", "shows scale"),
            (AsmWinLisp, new[] { "assemblies", "assemblies-preset", "edges", "empty" }, "asmwin ", ""),
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
                    var cs = Case(name, root, info["sep"], enc, names, lines);
                    if (!lisp) continue;
                    foreach (var (mark, cases, prefix, kept) in ReadByLisp)
                    {
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
