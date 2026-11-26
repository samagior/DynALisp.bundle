// Bundle.cs - DynALisp.Core.Data: the folders of DynALisp and the user copies of its files
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
// The folders the data files are read from, as the Lisp side names them:
//   Contents   *dyl:contents  DynALisp.bundle\Contents, the defaults (in git)
//   User       *dyl:user      DynALisp.bundle\User, the user's copies (out of git)
//   Res        *dyl:dylres    Contents\Modules\Dynalisp\Res, the data files of the Dynalisp module
//   Resources  *dyl:res       Contents\Resources, the files of the core (Aliases.csv)
// A file under Contents is read from its copy at the same path under User when there is one
// (Dyl:UserFile of dynalisp.mnl), and always written there (Dyl:UserFileW). The files are read
// through the store of the session (Store.cs), and written as Remote>>LM:writecsv writes them
// (Csv.WriteFile), with the list separator of Windows and the ANSI code page the plugin gives.

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace DynALisp.Core.Data
{
    public sealed class Bundle
    {
        public readonly string Contents, User, Res, Resources;
        public readonly string Sep;
        public readonly Encoding Enc;
        public readonly Store Store;

        // The files written by DynALisp in the session (Remote>>Dyl:CsvWrite counts them in
        // *dyl:datawrites*): what is made from them is made again after a write:
        public int Writes { get; private set; }

        // The presets read (Presets.Read), dropped by each write:
        internal readonly Dictionary<string, object> Reads = new Dictionary<string, object>(StringComparer.Ordinal);

        // The bundle whose Contents folder is contents (its User folder beside it):
        public Bundle(string contents, string sep, Encoding enc, Store store)
        {
            Contents = Path.GetFullPath(contents).TrimEnd('\\', '/');
            User = Path.Combine(Path.GetDirectoryName(Contents), "User");
            Res = Path.Combine(Contents, "Modules", "Dynalisp", "Res");
            Resources = Path.Combine(Contents, "Resources");
            Sep = string.IsNullOrEmpty(sep) ? "," : sep;
            Enc = enc;
            Store = store ?? new Store(enc);
        }

        // (Dyl:UserPath path): the user copy of a path under Contents (any case), null for a path
        // that is not under it:
        public string UserPath(string path)
        {
            string pre = Contents + Path.DirectorySeparatorChar;
            if (path == null || !path.StartsWith(pre, StringComparison.OrdinalIgnoreCase)) return null;
            return User + path.Substring(Contents.Length);
        }

        // (Dyl:UserFile path): the file to read, its user copy when it exists, else path:
        public string UserFile(string path)
        {
            string usr = UserPath(path);
            return usr != null && File.Exists(usr) ? usr : path;
        }

        // (Dyl:UserFileW path): the file to write, its user copy, its folders made:
        public string UserFileW(string path)
        {
            string usr = UserPath(path);
            if (usr == null) return path;
            try { Directory.CreateDirectory(Path.GetDirectoryName(usr)); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            return usr;
        }

        // The file at path read (kept for the session), null when it does not exist:
        public Table Read(string path) => Store.Get(path);

        // (Remote>>Dyl:CsvHead path): its header, null when it has none:
        public string[] Head(string path) => Read(path)?.Header;

        // (Remote>>Dyl:CsvRead path n): its rows, each cut or padded to n cells:
        public List<string[]> Rows(string path, int n)
        {
            var res = new List<string[]>();
            var t = Read(path);
            if (t != null) foreach (var r in t.Rows) res.Add(Csv.Fit(r, n));
            return res;
        }

        // (Remote>>Dyl:CsvWrite rows path): the rows (header first) written to path, then the
        // file dropped from the store and what was made from the files dropped. True once
        // written, false when it cannot be (open in Excel):
        public bool Write(IEnumerable<IList<string>> rows, string path)
        {
            bool ok = Csv.WriteFile(path, rows, Sep, Enc);
            Store.Drop(path);
            Reads.Clear();
            Writes++;
            return ok;
        }

        // The date and size of the file at path ("" when it does not exist), for what is kept
        // while none of its files changed:
        public static string Stamp(string path)
        {
            var fi = new FileInfo(path);
            return fi.Exists ? fi.LastWriteTimeUtc.Ticks + ":" + fi.Length : "";
        }
    }
}
