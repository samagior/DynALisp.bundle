// StoreTests.cs - the tests of the data files kept for the session (Installer\Core\Data)
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

using System;
using System.IO;
using System.Text;
using DynALisp.Core.Data;
using Xunit;

namespace DynALisp.Core.Tests
{
    public class StoreTests : IDisposable
    {
        readonly string dir = Path.Combine(Path.GetTempPath(), "DynALisp.Core.Tests." + Guid.NewGuid().ToString("N"));
        readonly Store store = new Store(Encoding.Latin1);

        public StoreTests() { Directory.CreateDirectory(dir); }
        public void Dispose() { try { Directory.Delete(dir, true); } catch (Exception) { } }

        string Write(string name, string text)
        {
            var p = Path.Combine(dir, name);
            File.WriteAllText(p, text, Encoding.Latin1);
            return p;
        }

        [Fact]
        public void AFileIsReadOnceWhileItDoesNotChange()
        {
            var p = Write("A.csv", "Id,Name\na,A\n");
            var t1 = store.Get(p);
            var t2 = store.Get(p);
            Assert.Same(t1, t2);
            Assert.Equal(1, store.Reads);
            Assert.Equal(1, store.Hits);
            Assert.Equal(1, store.Files);
        }

        [Fact]
        public void AFileChangedIsReadAgain()
        {
            var p = Write("A.csv", "Id,Name\na,A\n");
            Assert.Single(store.Get(p).Rows);
            Write("A.csv", "Id,Name\na,A\nb,B\n");
            Assert.Equal(2, store.Get(p).Rows.Count);
            // The same size, another date:
            Write("A.csv", "Id,Name\na,X\nb,B\n");
            File.SetLastWriteTimeUtc(p, DateTime.UtcNow.AddSeconds(5));
            Assert.Equal("X", store.Get(p).Rows[0][1]);
            Assert.Equal(3, store.Reads);
        }

        [Fact]
        public void AFileDroppedIsReadAgain()
        {
            var p = Write("A.csv", "Id,Name\na,A\n");
            store.Get(p);
            store.Drop(p);
            store.Get(p);
            store.Drop(null);
            Assert.Equal(0, store.Files);
            store.Get(p);
            Assert.Equal(3, store.Reads);
        }

        [Fact]
        public void AMissingFileIsNullAndForgotten()
        {
            var p = Write("A.csv", "Id,Name\na,A\n");
            store.Get(p);
            File.Delete(p);
            Assert.Null(store.Get(p));
            Assert.Equal(0, store.Files);
            Assert.Null(store.Get(null));
            Assert.Null(store.Get(""));
        }

        [Fact]
        public void TheEncodingIsTheOneGiven()
        {
            var p = Path.Combine(dir, "B.csv");
            File.WriteAllBytes(p, Encoding.Latin1.GetBytes("Id,Name\nmt-Beton,Béton\n"));
            Assert.Equal("Béton", store.Get(p).Rows[0][1]);
        }
    }
}
