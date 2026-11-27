// AsmTabTests.cs - the tests of the Assembly Presets window (Installer\Core\Data\AsmTab.cs)
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
// The expected values are worked out by hand from the data of the case Witness\In\shows and
// from the Lisp functions AsmTab follows (Remote\Dyl-Presets.lsp, Apps\Draw\Dyl-QuickDraw.lsp);
// WitnessTests.cs checks the same functions against what AutoCAD itself gives (sections asmtab).

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class AsmTabTests
    {
        static Bundle Case() =>
            new Bundle(Path.Combine(Repo.Root, "Installer", "Core", "Tests", "Witness", "In", "shows", "Contents"), ";", Encoding.Latin1, null);

        static readonly Units Metric = new Units { CannoScale = 0.02, Measurement = 1, Insunits = 4, Dimzin = 0 };

        static readonly List<string> Keys = new List<string> { "WALL", "HATCH", "THIN", "G-DS-ANNO-STD-TEXT" };

        static AsmTab Open(string select = null, string border = null)
        {
            var t = AsmTab.Open(Case(), Metric, null, select, null, "", "Name", Keys, border, p => ("Imperial", "C:\\Pat\\acad.pat"));
            t.Prep();
            return t;
        }

        [Fact]
        public void TheWindowOpensOnTheAssemblyOfThePresetShown()
        {
            var t = Open();
            Assert.Equal(0, t.Idx);
            var id = t.Lst[2][0];
            t = Open(id, "WALL");
            Assert.Equal(2, t.Idx);
            Assert.Equal(new[] { 2 }, t.Sel);
            Assert.Equal("WALL", t.Bk);
            // a key that is not listed: the first key, in any case:
            Assert.Equal("HATCH", Open("as-NoSuch", "NOSUCHKEY").Bk);
        }

        [Fact]
        public void TheLayerKeysAreThoseDefinedThenThoseUsed()
        {
            var t = Open();
            // (the keys of the annotations left out; MED used by as-B, not defined:)
            Assert.Equal(new[] { "HATCH", "MED", "THIN", "WALL" }, t.Keys);
            var vals = t.Vals(null);
            Assert.Equal(new[] { "HATCH", "MED   (not defined)", "THIN", "WALL" }, vals.First(v => v.Key == "out/list").List);
            Assert.Equal(new[] { "", "HATCH", "MED", "THIN", "WALL" }, vals.First(v => v.Key == "hky/vals").List);
            Assert.Equal(40, vals.First(v => v.Key == "pst/rows").Rows[0].Length);
            Assert.Equal("0.05 mm", vals.First(v => v.Key == "bwt/list").List[1]);
            Assert.Equal(new[] { "0.0393700787", "50" }, vals.First(v => v.Key == "ll/paper/list").List);
            Assert.DoesNotContain(vals, v => v.Key == "lp/off" || v.Key == "out/off");
        }

        // The edits of the witness (WitnessTests.Edits) on the first three rows sent, and why the
        // presets got back are not valid:
        static Dictionary<string, (List<string[]> Out, string Check)> Edited()
        {
            var t = Open();
            t.Vals(null);
            var rs = t.Sent.Take(3).ToList();
            t.Sent = rs;
            t.SentOf = t.SentOf.Take(3).ToList();
            t.Lst0 = t.SentOf;
            var res = new Dictionary<string, (List<string[]>, string)>();
            foreach (var (name, f) in WitnessTests.Edits(t))
            {
                var input = f(rs);
                if (input == null) continue;
                t.Lst = t.Back(input);
                res[name] = (Presets.Ids(t.Lst), t.Check());
            }
            return res;
        }

        [Fact]
        public void ARowNotEditedIsThePresetAsItWasRead()
        {
            var t = Open();
            t.Vals(null);
            var e = Edited()["same"];
            Assert.Null(e.Check);
            Assert.Equal(t.Lst.Take(3).Select(r => string.Join("|", r)), e.Out.Select(r => string.Join("|", r)));
            Assert.Null(t.Write());
        }

        [Fact]
        public void TheValuesEditedAreGotBack()
        {
            var e = Edited();
            var name = e["name"].Out[0];
            Assert.Equal(("Edited name", "A description", "Family", "Short"), (name[2], name[8], name[13], name[14]));
            Assert.Null(e["ratingsok"].Check);
            Assert.Equal("45", e["ratingsok"].Out[0][9]);
            Assert.StartsWith("P:mt-Gyp:12.5|", e["thick"].Out[0][3]);
            Assert.Contains(":mt-Void~23.5", e["framing"].Out[0][3].Split('|')[0]);
            Assert.Equal(2, e["delete"].Out.Count);
            Assert.Equal(new[] { e["same"].Out[1][0], e["same"].Out[0][0] }, e["move"].Out.Take(2).Select(r => r[0]));
            Assert.StartsWith("cu-Added", e["new"].Out[3][0]);
        }

        [Fact]
        public void APresetNotValidSaysWhy()
        {
            var e = Edited();
            string n = e["same"].Out[0][2] + ": ";
            Assert.Equal(n + "No layers: add one.", e["nolayers"].Check);
            Assert.Equal(n + "The thickness must be a number greater than 0.", e["thickbad"].Check);
            Assert.Equal(n + "The thickness must be a number greater than 0.", e["thicktext"].Check);
            Assert.Equal(n + "No material: add one in the Materials window.", e["nomat"].Check);
            Assert.Equal(n + "The framing must be a percentage greater than 0 and less than 100.", e["framingbad"].Check);
            Assert.Equal(n + "The fire-resistance ratings must be whole numbers of minutes.", e["ratings"].Check);
            Assert.Equal(n + "The IIC must be a whole number.", e["sound"].Check);
            Assert.Equal(n + "The extension must be a number, 0 or more (empty: half the width).", e["band"].Check);
            Assert.Equal(n + "The end angle must be a number from -80 to 80 (0: square).", e["bandangle"].Check);
            Assert.Equal(n + "The miter limit must be a number, 1 or more (x the width).", e["bandmiter"].Check);
            Assert.Equal(n + "The width factor must be a number greater than 0.", e["bandfactor"].Check);
            Assert.Equal(n + "The origin X offset must be a number (0: at the start of the segment).", e["bandoffset"].Check);
            Assert.Null(e["bandok"].Check);
            Assert.Equal(n + "No layer key for the border: add one in the Layer Keys window.", e["border"].Check);
            Assert.Null(e["borderok"].Check);
            Assert.StartsWith(n + "A color is", e["borderbad"].Check);
            Assert.Equal(n + "The transparency must be a whole number from 0 to 90.", e["hatchbad"].Check);
            Assert.Null(e["hatchkey"].Check);
            Assert.Equal(n + "Border lines: no layer key, add one in the Layer Keys window.", e["lines"].Check);
            Assert.Null(e["linesok"].Check);
            Assert.StartsWith(n + "A color is", e["linesbad"].Check);
            Assert.Equal("Added: No layers: add one.", e["new"].Check);
            Assert.Equal("New assembly: No layers: add one.", e["newempty"].Check);
        }

        [Fact]
        public void TheColorsAndTheChecksOfOneValue()
        {
            Assert.Equal(new[] { 7 }, AsmTab.ColorParse(" 7 "));
            Assert.Equal(new[] { 1, 2, 3 }, AsmTab.ColorParse("1, 2 ,3"));
            Assert.Null(AsmTab.ColorParse("0"));
            Assert.Null(AsmTab.ColorParse("256,0,0"));
            Assert.Null(AsmTab.DlgCheck("mex", ""));
            Assert.NotNull(AsmTab.DlgCheck("btr", "91"));
            Assert.Null(AsmTab.DlgCheck("btr", "90"));
        }
    }
}
