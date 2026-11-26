// PresetsTests.cs - the tests of the presets, groups and aliases (Installer\Core\Data)
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
// The expected values are worked out from the Lisp functions of the same names
// (Remote\Dyl-Presets.lsp, Remote\Dyl-Groups.lsp, dynalisp.mnl); WitnessTests.cs checks the
// same functions against what AutoCAD itself gives. The specs are checked against the Lisp
// files that define them.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class PresetsTests
    {
        static string[] R(params string[] cells) => cells;

        [Fact]
        public void CamelKeepsTheLettersAndDigits()
        {
            Assert.Equal("ModularBrick2", Presets.Camel("Modular brick 2"));
            Assert.Equal("ConcreteBlock", Presets.Camel("concrete-block"));
            Assert.Equal("CMU8", Presets.Camel("cMU 8\""));
            Assert.Equal("BTonCellulaire", Presets.Camel("béton cellulaire"));
            Assert.Equal("", Presets.Camel("--- ()"));
            Assert.Equal("A1b", Presets.Camel("a1b"));
        }

        [Fact]
        public void IdsAreMadeFromTheNamesUniqueInAnyCase()
        {
            var res = Presets.Ids(new List<string[]>
            {
                R("CU-TEST", "G", "x"), R("", "G", "test"), R("", "G", "Test"), R("", "G", "#"), R("qd-A", "G", "a"),
            });
            Assert.Equal(new[] { "CU-TEST", "cu-Test2", "cu-Test3", "cu-Preset", "qd-A" }, res.Select(r => r[0]));
        }

        [Fact]
        public void CleanKeepsDefaultsAndCustomIdsOnce()
        {
            var s = Presets.QuickShape;
            var rows = new List<string[]>
            {
                R("qs-Brick", "Wall", "Brick", "mt-Brick"),
                R("cu-Mine", "Wall", "Mine", "mt-Brick"),
                R("cu-Mine", "Wall", "Mine again", "mt-Brick"),   // a custom id given again: a new id
                R("qs-Brick", "Wall", "Brick 2", "mt-Brick"),     // a default given again: dropped
                R("xx-Odd", "Wall", "Odd", "mt-Brick"),           // not an id: a new one
                R("cu-", "Wall", "Short", "mt-Brick"),            // cu- alone is not one
                R("qs-NoName", "Wall", "", "mt-Brick"),           // no name: dropped
                R("qs-NoMat", "Wall", "No mat", ""),              // no column 3: dropped
            };
            var res = Presets.Clean(s, rows, null);
            Assert.Equal(new[] { "qs-Brick", "cu-Mine", "cu-MineAgain", "cu-Odd", "cu-Short" }, res.Select(r => r[0]));
            // With the defaults of the tool, only they are default ids:
            var defs = new List<string[]> { R("qs-Brick", "Wall", "Brick", "mt-Brick") };
            res = Presets.Clean(s, new List<string[]> { R("qs-Other", "Wall", "Other", "m") }, defs);
            Assert.Equal("cu-Other", res[0][0]);
            // A tool whose column 3 may be empty keeps it:
            res = Presets.Clean(Presets.HatchPreset, new List<string[]> { R("hp-Void", "G", "Void", "") }, null);
            Assert.Single(res);
        }

        [Fact]
        public void CommandsOfThePresets()
        {
            Assert.Equal("Pst-QuickDrawBrick", Presets.Command(Presets.QuickDraw, "qd-Brick"));
            Assert.Equal("Pst-QuickDrawCustomTest", Presets.Command(Presets.QuickDraw, "cu-Test"));
            Assert.Null(Presets.Command(Presets.QuickDraw, ""));
            Assert.Null(Presets.Command(Presets.Material, "mt-Brick"));
        }

        [Fact]
        public void WrittenAsLeeMacWritesThem()
        {
            Assert.Equal("a,\"b,c\",\"say \"\"hi\"\"\",", Csv.Line(new[] { "a", "b,c", "say \"hi\"", "" }, ","));
            Assert.Equal("a;b,c", Csv.Line(new[] { "a", "b,c" }, ";"));
            Assert.Equal("\"a;b\";c", Csv.Line(new[] { "a;b", "c" }, ";"));
            Assert.Equal("Id,Name\r\nx,y\r\n", Csv.Text(new[] { new[] { "Id", "Name" }, new[] { "x", "y" } }, ","));
        }

        [Fact]
        public void WrittenThenReadGivesTheSameRows()
        {
            using var dir = new TempBundle();
            var b = dir.Bundle;
            var s = Presets.QuickShape;
            var rows = new List<string[]>
            {
                Csv.Fit(R("qs-A", "Wall", "A, \"quoted\"", "mt-Brick", "Square", "1"), s.Header.Length),
                Csv.Fit(R("", "Wall", "new one", "mt-Brick"), s.Header.Length),
            };
            Assert.True(Presets.Write(b, s, rows));
            Assert.Equal(Path.Combine(b.User, "Modules", "Dynalisp", "Res", "QuickShape.csv"), Presets.File(b, s));
            var back = Presets.Csv(b, s);
            Assert.Equal("A, \"quoted\"", back[0][2]);
            Assert.Equal("cu-NewOne", back[1][0]);
        }

        [Fact]
        public void AnOlderUserCopyIsNotRead()
        {
            using var dir = new TempBundle();
            var b = dir.Bundle;
            var s = Presets.HatchPreset;
            dir.Default("HatchPresets.csv", "Id,Group,Name,Pattern\nhp-A,G,A,ANSI31\n");
            dir.User("HatchPresets.csv", "Type,Key,Pattname\nx,y,z\n");
            Assert.Equal(Presets.Default(b, s), Presets.File(b, s));
            dir.User("HatchPresets.csv", "id,GROUP,name,pattern,Scale\nhp-B,G,B,DOTS\n");
            Assert.NotEqual(Presets.Default(b, s), Presets.File(b, s));
        }

        [Fact]
        public void ReadAddsTheDefaultsMissing()
        {
            using var dir = new TempBundle();
            var b = dir.Bundle;
            var s = Presets.QuickShape;
            dir.Default("QuickShape.csv", "Id,Group,Name,Material\nqs-A,Wall,A,m\nqs-B,Wall,B,m\n");
            dir.User("QuickShape.csv", "Id,Group,Name,Material\nqs-B,Wall,B mine,m\n,Wall,Mine,m\n");
            var defs = Presets.DefsOf(b, s, null, null);
            Assert.Equal(new[] { "qs-A", "qs-B" }, defs.Select(r => r[0]));
            var res = Presets.Read(b, s, defs, null);
            Assert.Equal(new[] { "qs-B", "cu-Mine", "qs-A" }, res.Select(r => r[0]));
            Assert.Equal("B mine", res[0][2]);
            Assert.Same(res, Presets.Read(b, s, defs, null));
        }

        [Fact]
        public void GroupsAndTheirCase()
        {
            using var dir = new TempBundle();
            var b = dir.Bundle;
            Assert.Equal(Groups.Kinds[0].Defaults, Groups.Of(b, null));
            dir.Default("Groups.csv", "Group\nWall\n\nwall\nSection\nÉquipe\n");
            Assert.Equal(new[] { "Wall", "Section", "Équipe" }, Groups.Of(b, null));
            Assert.Equal("Section", Groups.CaseOf(b, "SECTION", null));
            Assert.Equal("Équipe", Groups.CaseOf(b, "équipe", null));
            Assert.Equal("Other", Groups.CaseOf(b, "Other", null));
            Assert.Equal(Groups.Kinds[1].Defaults, Groups.Of(b, "Material"));
            Assert.True(Groups.Write(b, new[] { "B", "A" }, "Material"));
            Assert.Equal(new[] { "B", "A" }, Groups.Of(b, "Material"));
            Assert.Equal(Groups.Kinds[1].Defaults, Groups.DefaultsOf(b, "Material"));
        }

        [Fact]
        public void AliasesReadAndWritten()
        {
            using var dir = new TempBundle();
            var b = dir.Bundle;
            dir.Resource("Aliases.csv", "Alias;Command\nC:QD-B;C:PST-QUICKDRAWB\nqd-a ; c:Pst-QuickDrawA\nC:BAD!;C:X\nC:QD-B;C:Y\nC:SAME;C:SAME\nC:NONE;\n");
            var als = Aliases.Read(b);
            Assert.Equal(new[] { "QD-B=PST-QUICKDRAWB", "QD-A=PST-QUICKDRAWA" }, als.Select(p => p.Key + "=" + p.Value));
            Assert.True(Aliases.Write(b, als));
            Assert.Equal("Alias,Command\r\nC:QD-A,C:PST-QUICKDRAWA\r\nC:QD-B,C:PST-QUICKDRAWB\r\n",
                         File.ReadAllText(Path.Combine(b.User, "Resources", "Aliases.csv")));
            Assert.Equal(new[] { "QD-A" }, Aliases.Of("PST-QUICKDRAWA", als));
        }

        // The specs of the C# are those of *dyl:presetspecs* in the Lisp files:
        [Fact]
        public void TheSpecsAreThoseOfTheLisp()
        {
            var remote = Path.Combine(Repo.Root, "Contents", "Modules", "Dynalisp", "Remote");
            var specs = new Dictionary<string, Dictionary<string, object>>();
            foreach (var f in new[] { "Dyl-Materials.lsp", "Dyl-QuickDrawPresets.lsp", "Dyl-QuickShapePresets.lsp" })
                foreach (var form in Sexp.ReadAll(File.ReadAllText(Path.Combine(remote, f))))
                    Sexp.FindSpecs(form, specs);
            Assert.Equal(Presets.All.Select(s => s.Key).OrderBy(k => k), specs.Keys.OrderBy(k => k));
            foreach (var s in Presets.All)
            {
                var p = specs[s.Key];
                Assert.Equal((List<object>)p["header"], s.Header.Cast<object>().ToList());
                Assert.Equal(p["file"], s.File);
                Assert.Equal(p["default"], s.Default);
                Assert.Equal(p.ContainsKey("blank3"), s.Blank3);
                Assert.Equal(p.TryGetValue("head", out var h) ? Convert.ToInt32(h) : 0, s.Head);
                Assert.Equal(p.TryGetValue("groups", out var g) ? g : null, s.Groups);
                Assert.Equal(p.TryGetValue("base", out var ba) ? ba : null, s.Base);
                Assert.Equal(p.TryGetValue("cmd", out var c) ? c : null, s.Cmd);
                Assert.Equal(p["title"], s.Title);
            }
        }

        // The groups when their file cannot be read are those of the Lisp:
        [Fact]
        public void TheDefaultGroupsAreThoseOfTheLisp()
        {
            var text = File.ReadAllText(Path.Combine(Repo.Root, "Contents", "Modules", "Dynalisp", "Remote", "Dyl-Groups.lsp"));
            var vals = new Dictionary<string, List<object>>();
            foreach (var form in Sexp.ReadAll(text))
                if (form is List<object> l && l.Count == 3 && Equals(l[0], "#setq") && l[2] is List<object> q && Equals(q[0], "#quote"))
                    vals[(string)l[1]] = q[1] as List<object>;
            Assert.Equal(vals["#*grp:defaults*"], Groups.Kinds[0].Defaults.Cast<object>().ToList());
            Assert.Equal(vals["#*grp:matdefaults*"], Groups.Kinds[1].Defaults.Cast<object>().ToList());
        }
    }

    // The folder of the repository (the tests run from Installer\Core\Tests\bin\...):
    static class Repo
    {
        public static string Root
        {
            get
            {
                var d = new DirectoryInfo(AppContext.BaseDirectory);
                while (d != null && !File.Exists(Path.Combine(d.FullName, "PackageContents.xml"))) d = d.Parent;
                return d?.FullName ?? throw new DirectoryNotFoundException("PackageContents.xml");
            }
        }
    }

    // A bundle of its own in a temporary folder (Contents and User), its files written in UTF-8:
    sealed class TempBundle : IDisposable
    {
        public readonly string Root;
        public readonly Bundle Bundle;

        public TempBundle(string sep = ",")
        {
            Root = Path.Combine(Path.GetTempPath(), "dyl-test-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path.Combine(Root, "Contents", "Modules", "Dynalisp", "Res"));
            Directory.CreateDirectory(Path.Combine(Root, "Contents", "Resources"));
            Bundle = new Bundle(Path.Combine(Root, "Contents"), sep, new UTF8Encoding(false), null);
        }

        void Put(string path, string text)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, text);
            File.SetLastWriteTimeUtc(path, DateTime.UtcNow.AddSeconds(new Random().Next(1, 1000)));
        }

        public void Default(string file, string text) => Put(Path.Combine(Bundle.Res, file), text);
        public void User(string file, string text) => Put(Path.Combine(Bundle.User, "Modules", "Dynalisp", "Res", file), text);
        public void Resource(string file, string text) => Put(Path.Combine(Bundle.Resources, file), text);

        public void Dispose()
        {
            try { Directory.Delete(Root, true); } catch (Exception) { }
        }
    }

    // A reader of the Lisp files, enough for their data: lists, strings, numbers, symbols
    // ("#name", in lower case), 'x as (#quote x), a dotted pair (a . b) as [a, b] with the
    // pair flagged by "#." between them; comments left out:
    static class Sexp
    {
        public static List<object> ReadAll(string text)
        {
            int i = 0;
            var res = new List<object>();
            while (true)
            {
                Skip(text, ref i);
                if (i >= text.Length) return res;
                res.Add(Read(text, ref i));
            }
        }

        static void Skip(string t, ref int i)
        {
            while (i < t.Length)
            {
                if (char.IsWhiteSpace(t[i])) i++;
                else if (t[i] == ';') { while (i < t.Length && t[i] != '\n') i++; }
                else return;
            }
        }

        static object Read(string t, ref int i)
        {
            Skip(t, ref i);
            char c = t[i];
            if (c == '\'') { i++; return new List<object> { "#quote", Read(t, ref i) }; }
            if (c == '(')
            {
                i++;
                var l = new List<object>();
                while (true)
                {
                    Skip(t, ref i);
                    if (t[i] == ')') { i++; return l; }
                    l.Add(Read(t, ref i));
                }
            }
            if (c == '"')
            {
                var sb = new StringBuilder();
                i++;
                while (t[i] != '"')
                {
                    if (t[i] == '\\') { i++; sb.Append(t[i] == 'n' ? '\n' : t[i] == 't' ? '\t' : t[i]); }
                    else sb.Append(t[i]);
                    i++;
                }
                i++;
                return sb.ToString();
            }
            int s = i;
            while (i < t.Length && !char.IsWhiteSpace(t[i]) && t[i] != '(' && t[i] != ')') i++;
            string atom = t.Substring(s, i - s);
            if (int.TryParse(atom, out int n)) return n;
            return "#" + atom.ToLowerInvariant();
        }

        // Each '("Key" (prop . value) (header ...) ...) of a form: its properties:
        public static void FindSpecs(object form, Dictionary<string, Dictionary<string, object>> specs)
        {
            if (!(form is List<object> l)) return;
            if (l.Count == 2 && Equals(l[0], "#quote") && l[1] is List<object> q && q.Count > 1 && q[0] is string key && !key.StartsWith("#")
                && q.Skip(1).All(x => x is List<object> p && p.Count > 0 && p[0] is string ps && ps.StartsWith("#")))
            {
                var props = new Dictionary<string, object>();
                foreach (List<object> p in q.Skip(1))
                {
                    string name = ((string)p[0]).Substring(1);
                    if (p.Count == 3 && Equals(p[1], "#.")) props[name] = p[2] is string sv && sv.StartsWith("#") ? sv.Substring(1) : p[2];
                    else props[name] = p.Skip(1).ToList();
                }
                specs[key] = props;
                return;
            }
            foreach (var x in l) FindSpecs(x, specs);
        }
    }
}
