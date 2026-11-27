// AsmWindowTests.cs - the tests of what the Assembly Presets window is given (Installer\Core\Data\AsmWindow.cs)
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
// from the Lisp functions of the same names (Apps\Draw\Dyl-QuickDraw.lsp); WitnessTests.cs
// checks the same functions against what AutoCAD itself gives.

using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class AsmWindowTests
    {
        static Bundle Case() =>
            new Bundle(Path.Combine(Repo.Root, "Installer", "Core", "Tests", "Witness", "In", "shows", "Contents"), ";", Encoding.Latin1, null);

        static readonly Units Metric = new Units { Measurement = 1, Insunits = 4, Dimzin = 0 };

        [Fact]
        public void TheMaterialsAreListedByGroupThenByName()
        {
            var b = Case();
            var read = Assemblies.Read(b, 1.0, 0);
            var l = AsmWindow.Mats(b, 0, read.Select(r => new[] { r[3], r[4], r[5] }));
            Assert.Equal(new[] { "Board", "Insulation", "Wood", "Concrete", "Air", "Masonry", "Metal", "Generic" }, l.Groups);
            Assert.Equal(new[] { "mt-Gone2", "mt-Iso", "mt-NoData" }, l.Mats.Where(m => m.Group == "Generic").Select(m => m.Id));
            // the framing of as-F no longer exists: listed last, marked, without group nor row:
            var gone = l.Mats.Last();
            Assert.Equal(("mt-Gone", "mt-Gone   (missing material)", "", -1), (gone.Id, gone.Name, gone.Group, gone.Row));
            Assert.Equal(new[] { "MED", "THIN" }, l.Used);
        }

        [Fact]
        public void TheRowAddStartsFromIsALayerOfTheFirstMaterial()
        {
            var mats = new[] { new AsmWindow.Mat { Id = "mt-A", Name = "A", Group = "Wall", Row = 0 } }.ToList();
            var d = AsmWindow.Def(mats, "K");
            Assert.Equal(48, d.Length);
            Assert.Equal(new[] { "P", "mt-A", "10", "", "K", "0", "Line" }, d.Take(7));
            Assert.Equal(new[] { "0", "K", "0", "0", "7" }, d.Skip(14).Take(5));
            Assert.Equal(new[] { "Wall", "", "", "0", "0" }, d.Skip(43));
            Assert.Equal(new[] { "P", "", "10" }, AsmWindow.Def(new System.Collections.Generic.List<AsmWindow.Mat>(), "").Take(3));
        }

        [Fact]
        public void AnAssemblyGetsItsRowsAndItsLines()
        {
            var b = Case();
            var mats = AsmWindow.Mats(b, 0, Enumerable.Empty<string[]>());
            var def = AsmWindow.Def(mats.Mats, "");
            // 89 mm in inches, 8 decimals; Line layers off on no key:
            var e = AsmWindow.Extras(b, new Units { Measurement = 0, Insunits = 1, Dimzin = 0 }, def, "",
                                     new[] { new[] { "P:mt-ins:89::::1", "", "1~THIN", "mm" } })[0];
            Assert.Equal(25, e.Length);
            var row = e[0].Split('\t');
            Assert.Equal(48, row.Length);
            Assert.Equal(new[] { "P", "mt-ins", "3.50393701" }, row.Take(3));
            Assert.Equal("1", row[16]);
            Assert.Equal("Insulation", row[43]);
            Assert.Equal(new[] { "0", "" }, e.Skip(1).Take(2));
            Assert.Equal(new[] { "1", "THIN" }, e.Skip(13).Take(2));
            // rows the window gave back not valid stay as they were; a key for lines without one:
            var t = AsmWindow.Extras(b, Metric, def, "MED", new[] { new[] { "P\tmt-A\tx", "", "", "" } })[0];
            Assert.Equal("P\tmt-A\tx", t[0]);
            Assert.Equal(new[] { "0", "MED" }, t.Skip(1).Take(2));
        }

        [Fact]
        public void TheDataOfEachMaterialArePerUnitOfThickness()
        {
            var d = AsmWindow.Data(Case(), Metric, new[] { "MT-GYP", "mt-Air", "mt-Gone" }).Value;
            Assert.Equal(new[] { "0.00625 0", "0 0.17", "" }, d.Rsi);
            Assert.Equal(new[] { "0.8", "", "" }, d.Mass);
        }
    }
}
