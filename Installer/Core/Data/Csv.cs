// Csv.cs - DynALisp.Core.Data: the reading of a CSV file of DynALisp, as the Lisp side reads it
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
// A file read here gives exactly what Remote>>Dyl:CsvRead and Remote>>Dyl:CsvHead
// (Remote\Dyl-Sub.lsp) give from the same file, so the Lisp side can use either one:
//   - the file is read in the encoding of (open file "r"), the ANSI code page of Windows (the
//     plugin gives it), its lines divided at each line feed, a carriage return before it left out;
//   - the separator is ";" when the first line (the header) has one, else a tab when it has one,
//     else ",";
//   - each line is divided as Remote>>LM:csv->lst (Remote\Dyl-Basics.lsp, Lee Mac) divides it,
//     step for step, its odd cases too (an unbalanced quote);
//   - each cell is trimmed of its spaces; a line of spaces and tabs only is left out;
//   - the header is the first line, an UTF-8 byte order mark left out of it.
// A file written here is the file Remote>>LM:writecsv (Remote\Dyl-Basics.lsp, Lee Mac) writes
// from the same rows, byte for byte (Tests\Witness):
//   - each row a line, its cells joined by the list separator of Windows (sList, the plugin
//     gives it; "," without one), a cell that holds it or a quote put between quotes, its
//     quotes doubled (Remote>>LM:lst->csv, Remote>>LM:csv-addquotes);
//   - each line ended as write-line ends it, a carriage return and a line feed, the file in
//     the encoding of (open file "w"), the ANSI code page of Windows, without byte order mark.

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace DynALisp.Core.Data
{
    // A CSV file read: its header (null when the file is empty) and its rows, header excluded:
    public sealed class Table
    {
        public string[] Header;
        public List<string[]> Rows = new List<string[]>();
    }

    public static class Csv
    {
        // The file at path read in the encoding enc; null when it cannot be opened:
        public static Table ReadFile(string path, Encoding enc)
        {
            string text;
            try
            {
                // Shared as Excel shares a file it has open: the Lisp side reads it too.
                using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (var sr = new StreamReader(fs, enc, false))
                    text = sr.ReadToEnd();
            }
            catch (IOException) { return null; }
            catch (UnauthorizedAccessException) { return null; }
            return Parse(text);
        }

        // The text of a file, divided as above:
        public static Table Parse(string text)
        {
            var t = new Table();
            var lines = Lines(text);
            if (lines.Count == 0) return t;
            string head = lines[0];
            char sep = head.IndexOf(';') >= 0 ? ';' : head.IndexOf('\t') >= 0 ? '\t' : ',';
            t.Header = Trim(Split(head.TrimStart('ï', '»', '¿', '﻿'), sep));
            for (int i = 1; i < lines.Count; i++)
            {
                if (lines[i].Trim(' ', '\t').Length == 0) continue;
                t.Rows.Add(Trim(Split(lines[i], sep)));
            }
            return t;
        }

        // The lines of read-line: divided at each line feed, a carriage return before it left
        // out, the last one when the file does not end with a line feed:
        public static List<string> Lines(string text)
        {
            var res = new List<string>();
            int start = 0;
            while (start < text.Length)
            {
                int nl = text.IndexOf('\n', start);
                int end = nl < 0 ? text.Length : nl;
                int len = end - start;
                if (len > 0 && text[end - 1] == '\r') len--;
                res.Add(text.Substring(start, len));
                if (nl < 0) break;
                start = nl + 1;
            }
            return res;
        }

        static string[] Trim(List<string> cells)
        {
            var res = new string[cells.Count];
            for (int i = 0; i < res.Length; i++) res[i] = cells[i].Trim(' ');
            return res;
        }

        // A line divided at the separator sep, as Remote>>LM:csv->lst divides it (its recursion
        // made a loop, its 1-based positions 0-based): a cell between quotes loses them and has
        // its doubled quotes made single; a cell that opens a quote and does not close it before
        // the separator (or is quotes only, an odd number of them) goes on to the next
        // separator, the search starting two characters after the one found as in Lee Mac's:
        public static List<string> Split(string str, char sep)
        {
            var res = new List<string>();
            int from = 0;
            while (true)
            {
                int pos = from <= str.Length ? str.IndexOf(sep, from) : -1;
                if (pos < 0)
                {
                    res.Add(Quoted(str) ? Unquote(str.Substring(1, str.Length - 2)) : str);
                    return res;
                }
                string s = str.Substring(0, pos);
                if (Opens(s) || (QuotesOnly(s) && (pos & 1) == 1))
                {
                    from = pos + 2;
                    continue;
                }
                res.Add(Quoted(s) ? Unquote(s.Substring(1, pos - 2)) : s);
                str = str.Substring(pos + 1);
                from = 0;
            }
        }

        // (wcmatch s "\"*\""): a quote first and last, two characters at least:
        static bool Quoted(string s) => s.Length >= 2 && s[0] == '"' && s[s.Length - 1] == '"';

        // (wcmatch s "\"*[~\"]"): a quote first, another character last:
        static bool Opens(string s) => s.Length >= 2 && s[0] == '"' && s[s.Length - 1] != '"';

        // (wcmatch s "~*[~\"]*"): no character but quotes (none at all too):
        static bool QuotesOnly(string s)
        {
            foreach (char c in s) if (c != '"') return false;
            return true;
        }

        // Remote>>LM:csv-replacequotes: each "" made ", from the left:
        static string Unquote(string s) => s.Replace("\"\"", "\"");

        // The end of a line written by write-line:
        public const string LineEnd = "\r\n";

        // (Remote>>LM:csv-addquotes cell sep): between quotes, its quotes doubled, when it holds
        // a character of the separator or a quote ((wcmatch cell "*[`<sep>\"]*")):
        public static string Quote(string cell, string sep)
        {
            if (cell.IndexOfAny((sep + "\"").ToCharArray()) < 0) return cell;
            return "\"" + cell.Replace("\"", "\"\"") + "\"";
        }

        // (Remote>>LM:lst->csv row sep): the line of a row:
        public static string Line(IList<string> row, string sep)
        {
            var sb = new StringBuilder();
            for (int i = 0; i < row.Count; i++)
            {
                if (i > 0) sb.Append(sep);
                sb.Append(Quote(row[i] ?? "", sep));
            }
            return sb.ToString();
        }

        // The text of a file of these rows (header first), as Remote>>LM:writecsv writes it:
        public static string Text(IEnumerable<IList<string>> rows, string sep)
        {
            var sb = new StringBuilder();
            foreach (var row in rows) sb.Append(Line(row, sep)).Append(LineEnd);
            return sb.ToString();
        }

        // Write these rows (header first) to the file at path in the encoding enc, as
        // Remote>>LM:writecsv: true once written, false when it cannot be opened (open in Excel,
        // its folder missing):
        public static bool WriteFile(string path, IEnumerable<IList<string>> rows, string sep, Encoding enc)
        {
            try
            {
                var bytes = enc.GetBytes(Text(rows, sep));
                using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.ReadWrite))
                    fs.Write(bytes, 0, bytes.Length);
                return true;
            }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }
        }

        // The cells of a row cut or padded with "" to n, as Remote>>Dyl:CsvRead gives them:
        public static string[] Fit(string[] row, int n)
        {
            if (row.Length == n) return row;
            var res = new string[n];
            for (int i = 0; i < n; i++) res[i] = i < row.Length ? row[i] : "";
            return res;
        }
    }
}
