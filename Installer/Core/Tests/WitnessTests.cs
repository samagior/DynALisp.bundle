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
            o.Rows("strlsort", new[] { names.OrderBy(x => x, StringComparer.Ordinal) });
            o.Rows("sort", new[] { names.OrderBy(x => x, StringComparer.Ordinal) });
            return o.Lines;
        }

        // <case>\Witness.txt, the case copied to root (its files written there):
        static List<string> Case(string name, string root, string sep, Encoding enc, List<string> names)
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
            foreach (var key in Keys)
                o.Put("#" + key + " write" + Us + Cell(Presets.Write(b, Presets.Spec(key), reads[key])));
            o.Put("#groups write" + Us + Cell(Groups.Write(b, Groups.Of(b, null), null)));
            o.Put("#groups material write" + Us + Cell(Groups.Write(b, Groups.Of(b, "Material"), "Material")));
            o.Put("#aliases write" + Us + Cell(Aliases.Write(b, als)));
            return o.Lines;
        }

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
            Same("Probes", ReadLines(Path.Combine(LispDir, "Probes.txt")), Probes(Names(enc)));
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
                    var cs = Case(name, root, info["sep"], enc, names);
                    if (!lisp) continue;
                    var witness = Path.Combine(LispDir, name);
                    Assert.True(Directory.Exists(witness), "No witness of the case " + name + ": run Witness.lsp again.");
                    Same(name, ReadLines(Path.Combine(witness, "Witness.txt")), cs);
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
