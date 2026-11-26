// Lisp.cs - DynALisp.Core.Data: the functions of AutoLISP the data of DynALisp is made with
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
// What the C# of the core does as the Lisp code it replaces does, so both give the same rows:
// strcase, a wcmatch of the patterns the data files use, nth on a row that may be short. The
// witness files (Tests\Witness) check them against AutoCAD itself.

using System;

namespace DynALisp.Core.Data
{
    public static class Lisp
    {
        // (strcase s): s in capitals, letters with accents too; nil stays nil:
        public static string StrCase(string s) => s?.ToUpperInvariant();

        // (= (strcase a) (strcase b)): the same names in any case:
        public static bool SameCase(string a, string b) => a != null && b != null && StrCase(a) == StrCase(b);

        // (nth i row): null past its end, as nil (and (/= "" nil) is true, as in Lisp):
        public static string Nth(string[] row, int i) => row != null && i >= 0 && i < row.Length ? row[i] : null;

        // (wcmatch s pattern) for the patterns of the data files: "*" any characters (none
        // too), "?" one character, the others themselves (case counts, as in wcmatch). A pattern
        // with another sign of wcmatch is refused, so it is never matched by mistake:
        public static bool Wcmatch(string s, string pattern)
        {
            if (s == null || pattern == null) return false;
            if (pattern.IndexOfAny("#@.~[]`,".ToCharArray()) >= 0)
                throw new ArgumentException("Wcmatch: only * and ? are kept: " + pattern);
            return Match(s, 0, pattern, 0);
        }

        static bool Match(string s, int i, string p, int j)
        {
            while (j < p.Length)
            {
                char c = p[j];
                if (c == '*')
                {
                    for (int k = i; k <= s.Length; k++)
                        if (Match(s, k, p, j + 1)) return true;
                    return false;
                }
                if (i >= s.Length) return false;
                if (c != '?' && c != s[i]) return false;
                i++;
                j++;
            }
            return i == s.Length;
        }

        // (distof s 2): the number of a text in decimal units, null (nil) for a text that is not
        // one: digits with a point (".5", "5." too), a sign before them, an exponent after them;
        // no space around them, no comma:
        public static double? Distof(string s)
        {
            if (s == null || !System.Text.RegularExpressions.Regex.IsMatch(s, @"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$"))
                return null;
            return double.TryParse(s, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var v)
                ? v : (double?)null;
        }

        // (rtos v 2 n): v with n decimals, the zeros of DIMZIN suppressed (4 the zero before the
        // point, 8 the zeros after the last digit):
        public static string Rtos(double v, int n, int dimzin)
        {
            string s = v.ToString("F" + Math.Max(0, n), System.Globalization.CultureInfo.InvariantCulture);
            if ((dimzin & 8) != 0 && s.Contains('.')) s = s.TrimEnd('0').TrimEnd('.');
            if ((dimzin & 4) != 0)
            {
                if (s.StartsWith("0.")) s = s.Substring(1);
                else if (s.StartsWith("-0.")) s = "-" + s.Substring(2);
            }
            return s;
        }

        // (Remote>>Dyl:MaterialNumP v n): v with n decimals at most, without its trailing zeros
        // (50.0 -> "50", 2.5 -> "2.5"):
        public static string NumP(double v, int n, int dimzin)
        {
            string s = Rtos(v, n, dimzin);
            return s.Contains('.') ? s.TrimEnd('0').TrimEnd('.') : s;
        }

        // (Remote>>Dyl:ListSubst row i v): a copy of row with its cell i made v (unchanged when
        // it has no cell i):
        public static string[] Subst(string[] row, int i, string v)
        {
            var res = (string[])row.Clone();
            if (i >= 0 && i < res.Length) res[i] = v;
            return res;
        }
    }
}
