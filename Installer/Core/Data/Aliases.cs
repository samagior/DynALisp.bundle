// Aliases.cs - DynALisp.Core.Data: the aliases of the commands (Resources\Aliases.csv)
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
// The aliases of the Command aliases region of dynalisp.mnl: Aliases.csv (its user copy, else
// the default), a row (Alias ; Command), both with "C:" as in StartupSuite.csv. An alias is a
// pair (ALIAS, COMMAND), in capitals without "C:":
//   Aliases.Read    Dyl:AliasRead     the aliases of the file, in its order
//   Aliases.Write   Dyl:AliasWrite    the aliases written, sorted by command then alias
//   Aliases.Of      Dyl:AliasesOf     the aliases of a command, sorted
//   Aliases.NameOk  Dyl:AliasName-p   a name a command can have

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace DynALisp.Core.Data
{
    public static class Aliases
    {
        // *dyl:alias, the default file:
        public static string File(Bundle b) => Path.Combine(b.Resources, "Aliases.csv");

        // (Dyl:SuiteKey name): a name of the header, its letters only, in capitals:
        public static string Key(string s) => new string(Lisp.StrCase(s).Where(c => c > 64 && c < 91).ToArray());

        // (Dyl:SuiteCmd cell): a command cell in capitals, trimmed, without its "C:":
        public static string Cmd(string s)
        {
            s = Lisp.StrCase((s ?? "").Trim(' '));
            return Lisp.Wcmatch(s, "C:*") ? s.Substring(2) : s;
        }

        // (Dyl:AliasName-p name): letters (capitals), digits, "-" and "_", one at least:
        public static bool NameOk(string s) =>
            !string.IsNullOrEmpty(s) && s.All(c => (c > 47 && c < 58) || (c > 64 && c < 91) || c == 45 || c == 95);

        // (Dyl:AliasRead): the aliases of the file in its order; an alias that is not a name, of
        // no command, of itself, or given again is left out; none without the file or its columns:
        public static List<KeyValuePair<string, string>> Read(Bundle b)
        {
            var res = new List<KeyValuePair<string, string>>();
            var t = b.Read(b.UserFile(File(b)));
            if (t?.Header == null) return res;
            var keys = t.Header.Select(Key).ToList();
            int ial = keys.IndexOf("ALIAS"), icm = keys.IndexOf("COMMAND");
            if (ial < 0 || icm < 0) return res;
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var r in t.Rows)
            {
                var row = Csv.Fit(r, keys.Count);
                string ali = Cmd(row[ial]), cmd = Cmd(row[icm]);
                if (NameOk(ali) && cmd != "" && ali != cmd && seen.Add(ali))
                    res.Add(new KeyValuePair<string, string>(ali, cmd));
            }
            return res;
        }

        // (Dyl:AliasWrite lst): the aliases written to the user copy of the file, sorted by
        // command then by alias (< of AutoLISP: the codes of the characters). True once written:
        public static bool Write(Bundle b, IEnumerable<KeyValuePair<string, string>> lst)
        {
            var rows = new List<IList<string>> { new[] { "Alias", "Command" } };
            foreach (var p in lst.OrderBy(p => p.Value, StringComparer.Ordinal).ThenBy(p => p.Key, StringComparer.Ordinal))
                rows.Add(new[] { "C:" + p.Key, "C:" + p.Value });
            return b.Write(rows, b.UserFileW(File(b)));
        }

        // (Dyl:AliasesOf cmd lst): the aliases of the command cmd, sorted (acad_strlsort):
        public static List<string> Of(string cmd, IEnumerable<KeyValuePair<string, string>> lst) =>
            lst.Where(p => p.Value == cmd).Select(p => p.Key).OrderBy(a => a, StringComparer.Ordinal).ToList();
    }
}
