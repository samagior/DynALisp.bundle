// Plugin.cs - DynALisp.Core: the Lisp functions of the core of DynALisp in .NET
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
// The data files of DynALisp (the layer keys, the materials, the hatch presets, the presets,
// the assemblies...) are read here once per session of AutoCAD and kept for every drawing
// (Data\Store.cs), read again only when one changed. Without this plugin, each drawing read and
// divided them again in Lisp. Remote>>Dyl:CsvRead and Remote>>Dyl:CsvHead (Remote\Dyl-Sub.lsp)
// call these functions when they are defined, and read the file themselves when they are not:
//
//   (Dyl:Data path n)
//     The rows of the CSV file at path, its header excluded, each one cut or padded with "" to
//     n cells trimmed of their spaces, as Remote>>Dyl:CsvRead gives them: ((cell ...) ...);
//     nil when the file does not exist or has no row. Without n, each row as it is.
//
//   (Dyl:DataHead path)
//     The names of the header of the file at path, as Remote>>Dyl:CsvHead gives them; nil when
//     the file does not exist or is empty.
//
//   (Dyl:DataCols path i ...)
//     The rows of the file as Dyl:Data gives them, each with only its cells i ... (counted
//     from 0, "" for a cell it does not have): the 4 columns the startup reads of the 9 of
//     StartupSuite.csv, the names and descriptions left in .NET. nil as Dyl:Data.
//
//   (Dyl:DataDrop [path])
//     Forgets the file at path (every file without path): its writers call it, so a file
//     written twice in the same instant is read again all the same. T.
//
//   (Dyl:AsmDefs contents)
//     The default assemblies of Quick Draw, fixed, as Dyl:QuickDrawAsmDefs gives them (the
//     bundle whose Contents folder is contents, *dyl:contents): ((id group name ...) ...); nil
//     for none.
//
//   (Dyl:AsmRead contents factor dimzin)
//     The assemblies read and fixed, the defaults missing added, their thicknesses in
//     millimetres in the units of the drawing (factor: the drawing units in a millimetre,
//     Dyl:QuickDrawAsmFactor; dimzin: DIMZIN, which rtos follows), as
//     Dyl:QuickDrawAsmReadAll gives them; nil when the Lisp reads them itself (a layer of an
//     older file made of a Quick Draw preset, see Data\Assemblies.cs) or there are none.
//
//   (Dyl:DataInfo)
//     What the plugin did in this session, for Dyl-Diagnostics: (("Files" . n) ("Reads" . n)
//     ("Hits" . n) ("ReadMs" . ms)), the files kept, the reads of a file, the calls given a
//     file kept, the time spent reading.

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using DynALisp.Core.Data;

[assembly: CommandClass(typeof(DynALisp.Core.Plugin))]

namespace DynALisp.Core
{
    public class Plugin
    {
        // The files read in the encoding of (open file "r") of AutoLISP: the ANSI code page of
        // Windows (MBCS), the one the Lisp side reads and writes them in:
        static readonly Encoding ansi = Ansi();
        static readonly Store store = new Store(ansi);

        [DllImport("kernel32.dll")]
        static extern int GetACP();

        static Encoding Ansi()
        {
            try
            {
                Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
                return Encoding.GetEncoding(GetACP());
            }
            catch (System.Exception)
            {
                return Encoding.Latin1;
            }
        }

        [LispFunction("Dyl:Data")]
        public ResultBuffer Data(ResultBuffer args)
        {
            var a = Args(args);
            if (a.Count < 1 || !(a[0] is string path)) return null;
            int n = a.Count > 1 ? Int(a[1]) : -1;
            var t = store.Get(path);
            if (t == null || t.Rows.Count == 0) return null;
            var rb = new List<TypedValue>(t.Rows.Count * ((n < 0 ? (t.Header?.Length ?? 0) : n) + 2) + 2);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var row in t.Rows)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var cell in n < 0 ? row : Csv.Fit(row, n))
                    rb.Add(new TypedValue((int)LispDataType.Text, cell));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:DataHead")]
        public ResultBuffer DataHead(ResultBuffer args)
        {
            var a = Args(args);
            if (a.Count < 1 || !(a[0] is string path)) return null;
            var t = store.Get(path);
            if (t == null || t.Header == null) return null;
            var rb = new List<TypedValue>(t.Header.Length + 2);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var cell in t.Header) rb.Add(new TypedValue((int)LispDataType.Text, cell));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:DataCols")]
        public ResultBuffer DataCols(ResultBuffer args)
        {
            var a = Args(args);
            if (a.Count < 2 || !(a[0] is string path)) return null;
            var cols = new List<int>();
            for (int i = 1; i < a.Count; i++) cols.Add(Int(a[i]));
            var t = store.Get(path);
            if (t == null || t.Rows.Count == 0) return null;
            var rb = new List<TypedValue>(t.Rows.Count * (cols.Count + 2) + 2);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var row in t.Rows)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var c in cols)
                    rb.Add(new TypedValue((int)LispDataType.Text, c >= 0 && c < row.Length ? row[c] : ""));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:DataDrop")]
        public object DataDrop(ResultBuffer args)
        {
            var a = Args(args);
            store.Drop(a.Count > 0 ? a[0] as string : null);
            return true;
        }

        // The bundles read, by their Contents folder (the witness points the Lisp at others):
        static readonly Dictionary<string, Bundle> bundles = new Dictionary<string, Bundle>(StringComparer.OrdinalIgnoreCase);

        static Bundle BundleOf(object contents)
        {
            if (!(contents is string c) || c == "") return null;
            if (!bundles.TryGetValue(c, out var b)) bundles[c] = b = new Bundle(c, ",", ansi, store);
            return b;
        }

        [LispFunction("Dyl:AsmDefs")]
        public ResultBuffer AsmDefs(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            return b == null ? null : Rows(Assemblies.Defs(b));
        }

        [LispFunction("Dyl:AsmRead")]
        public ResultBuffer AsmRead(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            if (b == null || a.Count < 3 || !(Real(a[1]) is double f)) return null;
            return Rows(Assemblies.Read(b, f, Int(a[2])));
        }

        // A list of rows as the Lisp gets it, nil for none:
        static ResultBuffer Rows(List<string[]> rows)
        {
            if (rows == null || rows.Count == 0) return null;
            var rb = new List<TypedValue>(rows.Count * 17 + 2);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var row in rows)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var cell in row) rb.Add(new TypedValue((int)LispDataType.Text, cell ?? ""));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:DataInfo")]
        public ResultBuffer DataInfo(ResultBuffer args)
        {
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            Pair(rb, "Files", store.Files);
            Pair(rb, "Reads", store.Reads);
            Pair(rb, "Hits", store.Hits);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Text, "ReadMs"));
            rb.Add(new TypedValue((int)LispDataType.Double, Math.Round(store.ReadMs, 1)));
            rb.Add(new TypedValue((int)LispDataType.DottedPair));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        static void Pair(ResultBuffer rb, string key, int value)
        {
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            rb.Add(new TypedValue((int)LispDataType.Text, key));
            rb.Add(new TypedValue((int)LispDataType.Int32, value));
            rb.Add(new TypedValue((int)LispDataType.DottedPair));
        }

        // The ResultBuffer of the values, made at once from their array, never with an Add for
        // each value (a chain of resbufs grown one by one): the 735 rows of 9 cells of the
        // Startup Suite given that way took longer than dividing the file in Lisp:
        static ResultBuffer Result(List<TypedValue> values)
        {
            return new ResultBuffer(values.ToArray());
        }

        // The arguments of a call, the atoms only (a string, a number, null for nil):
        static List<object> Args(ResultBuffer args)
        {
            var res = new List<object>();
            if (args == null) return res;
            foreach (TypedValue tv in args)
                res.Add((LispDataType)tv.TypeCode == LispDataType.Nil ? null : tv.Value);
            return res;
        }

        static double? Real(object o)
        {
            switch (o)
            {
                case short s: return s;
                case int i: return i;
                case double d: return d;
                default: return null;
            }
        }

        static int Int(object o)
        {
            switch (o)
            {
                case short s: return s;
                case int i: return i;
                case double d: return (int)d;
                default: return -1;
            }
        }
    }
}
