// AssembliesTests.cs - the tests of the assemblies (Installer\Core\Data\Assemblies.cs)
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
// (Apps\Draw\Dyl-QuickDraw.lsp, Remote\Dyl-Materials.lsp); WitnessTests.cs checks the same
// functions against what AutoCAD itself gives.

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class AssembliesTests
    {
        static string[] Row(params string[] cells) => Csv.Fit(cells, 15);

        [Fact]
        public void LayersKeepTheValidOnes()
        {
            var ls = Assemblies.Layers("P:mt-Gypsum:12.7| P : mt-A : 0 |S::10|L:thin:|X:a:1|P::5|P:mt-B:abc|P:mt-C:89::::1:mt-WoodFrame~23");
            Assert.Equal(new[] { "P:mt-Gypsum:12.7", "S", "L", "P:mt-C:89" }, ls.Select(l => l.Kind == "P" ? l.Kind + ":" + l.Ref + ":" + l.Thick : l.Kind));
            Assert.Equal("THIN", ls[2].Ref);
            Assert.Equal("1", ls[3].Bearing);
            Assert.Equal(new[] { "mt-WoodFrame", "23" }, ls[3].Framing);
            Assert.Equal("1", ls[0].Hatch[0]);
            Assert.Null(ls[0].Band);
            Assert.Null(ls[0].Border);
        }

        [Fact]
        public void LayersStrWritesOnlyTheFieldsGiven()
        {
            foreach (var s in new[]
            {
                "P:mt-Gypsum:12.7",
                "P:mt-AbsorptiveMaterial:89::::1:mt-WoodFrame~23",
                "P:mt-A:10:HK",
                "P:mt-A:10::::::1:1",
                "S::10|L:THIN:",
                "P:mt-A:10:~0~0~7~0~CONTINUOUS~0~1~0~25~0~50:::1",
            })
                Assert.Equal(s, Assemblies.LayersStr(Assemblies.Layers(s)));
            Assert.Equal("", Assemblies.LayersStr(Assemblies.Layers("")));
            // a border without overrides kept as its on and key, its key in upper case:
            Assert.Equal("P:mt-A:10:::1~THIN", Assemblies.LayersStr(Assemblies.Layers("P:mt-A:10:::1~thin")));
            // the comma of a color kept, written as a dot:
            Assert.Equal("P:mt-A:10:::1~K~1~1.2.3~0~CONTINUOUS~0~1~0~25~0~50",
                         Assemblies.LayersStr(Assemblies.Layers("P:mt-A:10:::1~k~1~1.2.3~0~continuous~0~1~0~25~0~50")));
        }

        [Fact]
        public void LinesAreOffWithoutAKey()
        {
            Assert.Equal(new[] { "1", "MED" }.Concat(Assemblies.NewOverrides), Assemblies.Lines("1~med"));
            Assert.Equal(new[] { "0", "" }.Concat(Assemblies.NewOverrides), Assemblies.Lines(""));
            Assert.Equal(new[] { "0", "" }.Concat(Assemblies.NewOverrides), Assemblies.Lines("x"));
            Assert.Equal("1~MED", Assemblies.LinesStr(Assemblies.Lines("1~med")));
            Assert.Equal("0~", Assemblies.LinesStr(Assemblies.Lines(null)));
        }

        [Fact]
        public void FixTurnsAnOlderRowIntoLayersAndLines()
        {
            var r = Assemblies.Fix(Row("cu-A", "wall", "A", "L:Thick:|P:mt-X:10|L:Med:|S::5|P:mt-Y:20|L:Thin:", "", "", "last", "MM"),
                                   null, g => g == "wall" ? "Wall" : g);
            Assert.Equal("Wall", r[1]);
            Assert.Equal("P:mt-X:10|P:mt-Void:5|P:mt-Y:20", r[3]);
            Assert.Equal("1~THICK", r[4]);
            Assert.Equal("1~MED", r[5]);
            Assert.Equal("Last", r[6]);
            Assert.Equal("mm", r[7]);
            Assert.Equal("A", r[13]);
        }

        [Fact]
        public void FixGivesTheFamilyOfTheDefault()
        {
            var defs = new List<string[]> { Row("as-W1a", "Wall", "W1a", "P:mt-A:1", "", "", "First", "mm", "", "", "", "", "", "W1", "Wood Studs") };
            var r = Assemblies.Fix(Row("AS-W1A", "Wall", "W1a", "P:mt-A:1"), defs, g => g);
            Assert.Equal("W1", r[13]);
            Assert.Equal("Wood Studs", r[14]);
            Assert.Equal("First", r[6]);
            Assert.Equal("", r[7]);
        }

        [Fact]
        public void TheDefaultsFixedStayAsWritten()
        {
            var b = new Bundle(Path.Combine(Repo.Root, "Contents"), ";", Encoding.Latin1, null);
            var defs = Assemblies.Defs(b);
            Assert.Equal(862, defs.Count);
            var raw = b.Rows(Presets.Default(b, Assemblies.Spec), 15);
            for (int i = 0; i < defs.Count; i++) Assert.Equal(raw[i], defs[i]);
        }

        [Fact]
        public void ScaleConvertsTheMillimetres()
        {
            var r = Row("as-A", "Wall", "A", "P:mt-A:15.9|P:mt-B:89::::1", "", "", "First", "mm");
            double inch = 0.001 / 0.0254;
            Assert.Equal("P:mt-A:0.62598425|P:mt-B:3.50393701::::1", Assemblies.Scale(r, inch, 8, 0)[3]);
            Assert.Equal("P:mt-A:15.9|P:mt-B:89::::1", Assemblies.Scale(Assemblies.Scale(r, inch, 8, 0), 1 / inch, 4, 0)[3]);
            Assert.Same(r, Assemblies.Scale(r, 1.0, 8, 0));
            var u = Row("cu-A", "Wall", "A", "P:mt-A:15.9", "", "", "First", "");
            Assert.Same(u, Assemblies.Scale(u, inch, 8, 0));
        }

        [Fact]
        public void RtosFollowsDimzin()
        {
            Assert.Equal("0.50", Lisp.Rtos(0.5, 2, 0));
            Assert.Equal(".50", Lisp.Rtos(0.5, 2, 4));
            Assert.Equal("0.5", Lisp.Rtos(0.5, 2, 8));
            Assert.Equal("10", Lisp.Rtos(10, 4, 8));
            Assert.Equal("10", Lisp.NumP(10, 4, 0));
            Assert.Equal("2.5", Lisp.NumP(2.5, 4, 0));
            Assert.Equal(new double?[] { 5, 0.5, 5, -1.5, null, null, null }, new[] { "5", ".5", "5.", "-1.5", "1,5", "", "a" }.Select(Lisp.Distof));
        }

        [Fact]
        public void ReadGivesTheDefaultsInTheUnitsOfTheDrawing()
        {
            var b = new Bundle(Path.Combine(Repo.Root, "Contents"), ";", Encoding.Latin1, null);
            var mm = Assemblies.Read(b, 1.0, 8);
            Assert.Equal(862, mm.Count);
            var inch = Assemblies.Read(b, 0.001 / 0.0254, 8);
            Assert.Equal(862, inch.Count);
            Assert.NotEqual(mm[0][3], inch[0][3]);
        }
    }
}
