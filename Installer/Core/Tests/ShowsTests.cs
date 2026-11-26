// ShowsTests.cs - the tests of what the Quick Draw window shows of each assembly (Installer\Core\Data\Shows.cs)
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
// The expected values are worked out by hand from the data of the case Witness\In\shows (the
// thermal resistance of a framed layer by the parallel path); WitnessTests.cs checks the same
// functions against what AutoCAD itself gives.

using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class ShowsTests
    {
        static Bundle Case() =>
            new Bundle(Path.Combine(Repo.Root, "Installer", "Core", "Tests", "Witness", "In", "shows", "Contents"), ";", Encoding.Latin1, null);

        static readonly Units Metric = new Units { CannoScale = 0.02, Measurement = 1, Insunits = 4, Lunits = 2, Luprec = 4, Dimzin = 0 };

        [Fact]
        public void SigKeepsFourDigits()
        {
            Assert.Equal("0.2357", Shows.Sig(0.23574, 0));
            Assert.Equal("1235", Shows.Sig(1234.5, 0));
            Assert.Equal("3.52", Shows.Sig(3.52, 0));
            Assert.Equal("0", Shows.Sig(0.0, 0));
            Assert.Equal(".5", Shows.Sig(0.5, 4));
        }

        [Fact]
        public void AFramedWallIsShownWithItsData()
        {
            var b = Case();
            var pats = Shows.Patterns(b, Metric);
            Assert.Equal(new[] { "ANSI37", "AR-CONC", "BRICK", "GENERAL_TEXTURE", "ISO02W100", "NOPAT" }, pats);
            var rows = Shows.All(b, Metric, pats.ToDictionary(p => p, p => ((string, string)?)("Imperial", "acad.pat")));
            var a = rows.First(r => r[0] == "as-A");
            Assert.Equal("3 layers", a[1]);
            Assert.Equal("114.4", a[2]);
            Assert.StartsWith("O*P?12.7?GENERAL_TEXTURE?acad.pat?0.5?0?1?Drafting*L?0*", a[3]);
            // gypsum 2 x 0.0127 / 0.16; studs at 23 % in parallel with the wool, 0.089 thick;
            // the gypsum alone continuous:
            Assert.Contains("Mineral Wool + Wood Stud 23%  89.0000  (load-bearing)", a[4]);
            Assert.Contains("Thermal resistance  RSI 1.683\nMass  32.61 kg/m2\nContinuous layers  RSI 0.1588", a[4]);
            Assert.EndsWith("Fire-resistance rating 45 min, STC 50\n\nWood studs 400 o.c.", a[4]);
            Assert.Same(rows, Shows.All(b, Metric, pats.ToDictionary(p => p, p => ((string, string)?)("Imperial", "acad.pat"))));
        }

        [Fact]
        public void LengthsThatAreNotDecimalAreLeftToTheLisp()
        {
            var u = new Units { CannoScale = 1.0, Measurement = 0, Insunits = 1, Lunits = 4, Luprec = 4, Dimzin = 0 };
            Assert.Null(Shows.Patterns(Case(), u));
            Assert.Null(Shows.All(Case(), u, new System.Collections.Generic.Dictionary<string, (string, string)?>()));
        }
    }
}
