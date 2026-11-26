// CsvTests.cs - the tests of the reading of the data files (Installer\Core\Data)
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
// The expected values are those Remote>>LM:csv->lst, Remote>>Dyl:CsvRead and
// Remote>>Dyl:CsvHead give from the same text (worked out step by step from their code).

using System;
using System.IO;
using System.Linq;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class CsvTests
    {
        static string[] Split(string s, char sep = ',') => Csv.Split(s, sep).ToArray();

        [Fact]
        public void PlainCellsAreDividedAtTheSeparator()
        {
            Assert.Equal(new[] { "a", "b", "c" }, Split("a,b,c"));
            Assert.Equal(new[] { "a", "", "b" }, Split("a,,b"));
            Assert.Equal(new[] { "a", "" }, Split("a,"));
            Assert.Equal(new[] { "", "a" }, Split(",a"));
            Assert.Equal(new[] { "" }, Split(""));
        }

        [Fact]
        public void QuotedCellsKeepTheirSeparatorsAndLoseTheirQuotes()
        {
            Assert.Equal(new[] { "a,b", "c" }, Split("\"a,b\",c"));
            Assert.Equal(new[] { "x", "a,,b" }, Split("x,\"a,,b\""));
            Assert.Equal(new[] { "say \"hi\"", "x" }, Split("\"say \"\"hi\"\"\",x"));
            Assert.Equal(new[] { "a", "", "b" }, Split("a,\"\",b"));
            Assert.Equal(new[] { "a", "\"" }, Split("a,\"\"\"\""));
            Assert.Equal(new[] { "a;b", "c" }, Split("\"a;b\";c", ';'));
        }

        [Fact]
        public void OddCasesAreReadAsLeeMacReadsThem()
        {
            // A quote opened and never closed: the rest of the line is one cell, as it is.
            Assert.Equal(new[] { "\"a,b" }, Split("\"a,b"));
            Assert.Equal(new[] { "x", "\"a,b" }, Split("x,\"a,b"));
            // Quotes only, an odd number: the cell goes on to the next separator.
            Assert.Equal(new[] { "\"\"\",x" }, Split("\"\"\",x"));
            // A quote inside a cell that does not begin with one stays.
            Assert.Equal(new[] { "ab\"c", "d" }, Split("ab\"c,d"));
        }

        [Fact]
        public void TheSeparatorComesFromTheHeader()
        {
            Assert.Equal(new[] { "1", "2,5" }, Csv.Parse("A;B\n1;2,5\n").Rows[0]);
            Assert.Equal(new[] { "1", "2,5" }, Csv.Parse("A\tB\n1\t2,5\n").Rows[0]);
            Assert.Equal(new[] { "1", "2", "5" }, Csv.Parse("A,B\n1,2,5\n").Rows[0]);
        }

        [Fact]
        public void CellsAreTrimmedAndBlankLinesLeftOut()
        {
            var t = Csv.Parse("Id , Name \r\n a , b \r\n\r\n \t \r\nc,d");
            Assert.Equal(new[] { "Id", "Name" }, t.Header);
            Assert.Equal(2, t.Rows.Count);
            Assert.Equal(new[] { "a", "b" }, t.Rows[0]);
            Assert.Equal(new[] { "c", "d" }, t.Rows[1]);
        }

        [Fact]
        public void TheByteOrderMarkLeavesTheHeader()
        {
            // An UTF-8 file read in the ANSI code page, as (open file "r") reads it:
            var bytes = new byte[] { 0xEF, 0xBB, 0xBF }.Concat(Encoding.ASCII.GetBytes("Id,Name\nqd-A,A\n")).ToArray();
            var t = Csv.Parse(Encoding.Latin1.GetString(bytes));
            Assert.Equal(new[] { "Id", "Name" }, t.Header);
            Assert.Equal(new[] { "qd-A", "A" }, t.Rows[0]);
        }

        [Fact]
        public void AnEmptyFileHasNoHeaderAndNoRow()
        {
            var t = Csv.Parse("");
            Assert.Null(t.Header);
            Assert.Empty(t.Rows);
            Assert.Empty(Csv.Parse("Id,Name\n").Rows);
        }

        [Fact]
        public void RowsAreCutOrPadded()
        {
            Assert.Equal(new[] { "a", "", "" }, Csv.Fit(new[] { "a" }, 3));
            Assert.Equal(new[] { "a", "b" }, Csv.Fit(new[] { "a", "b", "c" }, 2));
        }

        [Fact]
        public void LinesAreThoseOfReadLine()
        {
            Assert.Equal(new[] { "a", "b" }, Csv.Lines("a\r\nb\r\n"));
            Assert.Equal(new[] { "a", "b" }, Csv.Lines("a\nb"));
            Assert.Equal(new[] { "a", "", "b" }, Csv.Lines("a\n\nb\n"));
            Assert.Empty(Csv.Lines(""));
        }

        // Every data file of DynALisp is read, each row with no more cells than its header but
        // where a cell holds the separator:
        [Fact]
        public void EveryDataFileOfDynalispIsRead()
        {
            var res = Path.Combine(Root(), "Contents", "Modules", "Dynalisp", "Res");
            var files = Directory.GetFiles(res, "*.csv", SearchOption.AllDirectories);
            Assert.NotEmpty(files);
            foreach (var f in files)
            {
                var t = Csv.ReadFile(f, Encoding.Latin1);
                Assert.NotNull(t);
                var lines = Csv.Lines(File.ReadAllText(f, Encoding.Latin1)).Skip(1).Count(l => l.Trim(' ', '\t').Length > 0);
                Assert.Equal(lines, t.Rows.Count);
            }
            var lk = Csv.ReadFile(Path.Combine(res, "LayerKeys.csv"), Encoding.Latin1);
            Assert.Contains("Key", lk.Header, StringComparer.OrdinalIgnoreCase);
            Assert.All(lk.Rows, r => Assert.True(r.Length <= lk.Header.Length + 1, string.Join("|", r)));
        }

        // The files of the Startup Suite (Contents\Resources), read at the startup of each drawing
        // (Dyl:SuiteCsv of dynalisp.mnl): every row with the cells the startup reads.
        [Fact]
        public void TheStartupSuiteIsRead()
        {
            var dir = Path.Combine(Root(), "Contents", "Resources");
            var suite = Csv.ReadFile(Path.Combine(dir, "StartupSuite.csv"), Encoding.Latin1);
            Assert.Equal(new[] { "Load", "Command", "Name", "Description", "File", "Module", "Group", "Duplicate", "Path" }, suite.Header);
            Assert.True(suite.Rows.Count > 400);
            Assert.All(suite.Rows, r => Assert.EndsWith(".lsp", Csv.Fit(r, 9)[8], StringComparison.OrdinalIgnoreCase));
            Assert.All(suite.Rows, r => Assert.EndsWith("\\" + Csv.Fit(r, 9)[4], Csv.Fit(r, 9)[8], StringComparison.OrdinalIgnoreCase));
            var als = Csv.ReadFile(Path.Combine(dir, "Aliases.csv"), Encoding.Latin1);
            Assert.Equal(new[] { "Alias", "Command" }, als.Header);
            Assert.True(als.Rows.Count > 300);
            Assert.All(als.Rows, r => Assert.StartsWith("C:", Csv.Fit(r, 2)[1], StringComparison.OrdinalIgnoreCase));
        }

        // The folder of DynALisp.bundle, above the folder of the tests:
        public static string Root()
        {
            var d = new DirectoryInfo(AppContext.BaseDirectory);
            while (d != null && !File.Exists(Path.Combine(d.FullName, "PackageContents.xml"))) d = d.Parent;
            Assert.NotNull(d);
            return d.FullName;
        }
    }
}
