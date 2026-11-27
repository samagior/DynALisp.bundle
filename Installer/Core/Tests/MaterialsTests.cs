// MaterialsTests.cs - the tests of the materials and hatch presets (Installer\Core\Data\Materials.cs)
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
// (Remote\Dyl-Materials.lsp); WitnessTests.cs checks the same functions against what AutoCAD
// itself gives.

using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class MaterialsTests
    {
        static string[] Hp(params string[] cells) => Csv.Fit(cells, 64);

        static string[] Fix(string[] row, int dimzin = 0) => Materials.Fix(row, dimzin, g => g == "wall" ? "Wall" : g);

        [Fact]
        public void TheDefaultsOfTheCodeMatchTheLisp()
        {
            var lsp = File.ReadAllText(Path.Combine(Repo.Root, "Contents", "Modules", "Dynalisp", "Remote", "Dyl-Materials.lsp"), Encoding.Latin1);
            int i = lsp.IndexOf("(setq *mt:extra* '(");
            int j = lsp.IndexOf("\n)", i);
            var cells = System.Text.RegularExpressions.Regex.Matches(lsp.Substring(i, j - i), "\"([^\"]*)\"").Select(m => m.Groups[1].Value);
            Assert.Equal(Materials.Extra, cells);
            Assert.Contains("(setq *mt:toggles* '(" + string.Join(" ", Materials.Toggles) + "))", lsp);
            // the id and group of each material of *mt:defaults*:
            i = lsp.IndexOf("(setq *mt:defaults*");
            j = lsp.IndexOf("\n)", i);
            var defs = System.Text.RegularExpressions.Regex.Matches(lsp.Substring(i, j - i), "\\(\"([^\"]*)\" \"([^\"]*)\"")
                                                             .Select(m => (m.Groups[1].Value, m.Groups[2].Value));
            Assert.Equal(defs, Materials.CodeGroups);
        }

        [Fact]
        public void AShortRowGetsTheDefaults()
        {
            var r = Fix(new[] { "hp-A", "wall", "A", "ansi31" });
            Assert.Equal(64, r.Length);
            Assert.Equal("Wall", r[1]);
            Assert.Equal("ANSI31", r[3]);
            Assert.Equal("1", r[4]);
            Assert.Equal("", r[5]);
            Assert.Equal("1", r[11]);
            Assert.Equal("Drafting", r[63]);
            Assert.Equal("0", r[61]);
            Assert.Equal("0", r[62]);
            Assert.Equal("Center", r[35]);
        }

        [Fact]
        public void ARowSetForAnotherScaleIsSetForOneToOne()
        {
            var r = Hp("hp-A", "G", "A", "X", "1", "", "0", "MED", "HATCH", "0", "1", "2");
            Assert.Equal("0.5", Fix(r)[4]);
            Assert.Equal(".5", Fix(r, 4)[4]);
            Assert.Equal("0.333333", Fix(Lisp.Subst(r, 11, "3"))[4]);
            Assert.Equal("1", Fix(Lisp.Subst(r, 10, "0"))[4]);
            Assert.Equal("1", Fix(r)[11]);
            // a Model hatch is never annotative nor scaled with the drawing:
            var m = Fix(Lisp.Subst(Lisp.Subst(r, 9, "1"), 63, "model"));
            Assert.Equal(new[] { "0", "0", "1" }, new[] { m[9], m[10], m[4] });
            Assert.Equal("Model", m[63]);
        }

        [Fact]
        public void TheBandsAndBehaviorsAreFixed()
        {
            var r = Hp("hp-A", "G", "A", "X", "1", "", "0", "g-ds-anno-std-text", "HATCH", "yes", "0", "1");
            r[51] = "extended"; r[52] = "-2"; r[53] = "100"; r[54] = "lapped"; r[55] = "0.5"; r[56] = "second"; r[57] = "x"; r[58] = "ORIGIN";
            r[43] = "-1"; r[45] = "5"; r[38] = "0"; r[40] = "abc"; r[46] = "1,5";
            r[33] = "linear"; r[34] = "100, 150"; r[35] = "left"; r[36] = "2000";
            r[60] = "P:mt-A:10|S::5"; r[15] = "dashed";
            var f = Fix(r);
            Assert.Equal(new[] { "Extended", "", "45", "Lapped", "4", "Second", "Interrupted", "Origin" }, f.Skip(51).Take(8));
            Assert.Equal(new[] { "1", "1" }, new[] { f[61], f[62] });
            Assert.Equal(new[] { "5", "", "1", "0", "0" }, new[] { f[43], f[45], f[38], f[40], f[46] });
            Assert.Equal(new[] { "Linear", "100, 150", "Edge", "" }, f.Skip(33).Take(4));
            Assert.Equal("P:mt-A:10|S::5", f[60]);
            Assert.Equal(new[] { "HATCH", "DASHED", "0" }, new[] { f[7], f[15], f[9] });
            Assert.Equal("7", f[13]);
            Assert.Equal("08", Fix(Lisp.Subst(r, 36, "08"))[36]);
            Assert.Equal("as-Wall", Fix(Lisp.Subst(r, 60, "as-Wall"))[60]);
        }

        [Fact]
        public void TheDataOfAMaterialAreNumbersGreaterThanZero()
        {
            var b = new Bundle(Path.Combine(Path.GetTempPath(), "dyl-none"), ";", Encoding.Latin1, null);
            var r = Materials.RowFix(b, new[] { "mt-A", "concrete", "A", "hp-A", "", "2,5", "-1", "0", "abc", "1/2" });
            Assert.Equal(new[] { "mt-A", "Concrete", "A", "hp-A", "", "2.5", "", "", "", "1/2" }, r);
            Assert.Equal(10, Materials.RowFix(b, new[] { "mt-A", "G", "A" }).Length);
            // the row read is never changed (the rows read are shared):
            var raw = new[] { "mt-A", "concrete", "A", "hp-A", "", "2,5", "", "", "", "" };
            Materials.RowFix(b, raw);
            Assert.Equal("concrete", raw[1]);
            Assert.Equal("2,5", raw[5]);
            // a default material of an older file in the group Section gets its default group
            // (its id as written); any other one keeps it:
            Assert.Equal("Concrete", Materials.RowFix(b, new[] { "mt-Concrete", "section" })[1]);
            Assert.Equal("section", Materials.RowFix(b, new[] { "MT-CONCRETE", "section" })[1]);
            Assert.Equal("Elevation", Materials.RowFix(b, new[] { "mt-A", "Elevation" })[1]);
        }

        [Fact]
        public void TheDefaultsFixedAreThoseOfTheFiles()
        {
            var b = new Bundle(Path.Combine(Repo.Root, "Contents"), ";", Encoding.Latin1, null);
            var hps = Materials.HatchDefs(b, 0);
            var mats = Materials.RowDefs(b);
            Assert.NotNull(hps);
            Assert.NotNull(mats);
            Assert.All(hps, r => Assert.Equal(64, r.Length));
            var both = Materials.Both(b, 0);
            Assert.NotNull(both);
            Assert.Equal(hps.Count, both.Value.Hatches.Count);
            Assert.Equal(mats.Count, both.Value.Rows.Count);
            Assert.Same(both.Value.Rows, Materials.Both(b, 0).Value.Rows);
            Assert.False(Materials.OldP(b));
        }
    }
}
