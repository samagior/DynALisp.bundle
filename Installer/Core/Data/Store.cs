// Store.cs - DynALisp.Core.Data: the data files read once per session
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
// The files read (Csv.ReadFile) are kept for the whole session of AutoCAD, every drawing
// sharing them, with the date (to the tenth of a microsecond) and the size of each file: a file
// is read again only when one of them changed, in DynALisp, in another drawing or out of it
// (Excel). A file that no longer exists is forgotten. Drop forgets a file at once (its writer
// calls it, so a file written twice in the same instant is read again all the same).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace DynALisp.Core.Data
{
    public sealed class Store
    {
        sealed class Entry
        {
            public long Date, Size;
            public Table Table;
        }

        readonly Encoding enc;
        readonly Dictionary<string, Entry> files = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);
        readonly object gate = new object();

        // What the store did since the session started, for Dyl-Diagnostics:
        public int Reads { get; private set; }
        public int Hits { get; private set; }
        public double ReadMs { get; private set; }
        public int Files { get { lock (gate) return files.Count; } }

        public Store(Encoding enc) { this.enc = enc; }

        // The file at path, read again only when it changed; null when it does not exist or
        // cannot be read:
        public Table Get(string path)
        {
            if (string.IsNullOrEmpty(path)) return null;
            string key;
            try { key = Path.GetFullPath(path); }
            catch (Exception) { return null; }
            var fi = new FileInfo(key);
            lock (gate)
            {
                if (!fi.Exists)
                {
                    files.Remove(key);
                    return null;
                }
                long date = fi.LastWriteTimeUtc.Ticks, size = fi.Length;
                if (files.TryGetValue(key, out var e) && e.Date == date && e.Size == size)
                {
                    Hits++;
                    return e.Table;
                }
                var sw = Stopwatch.StartNew();
                var t = Csv.ReadFile(key, enc);
                ReadMs += sw.Elapsed.TotalMilliseconds;
                Reads++;
                if (t == null)
                {
                    files.Remove(key);
                    return null;
                }
                files[key] = new Entry { Date = date, Size = size, Table = t };
                return t;
            }
        }

        // Forget the file at path (every file when path is null or empty):
        public void Drop(string path)
        {
            lock (gate)
            {
                if (string.IsNullOrEmpty(path)) { files.Clear(); return; }
                try { files.Remove(Path.GetFullPath(path)); }
                catch (Exception) { }
            }
        }
    }
}
