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
//   (Dyl:DataDrop [path])
//     Forgets the file at path (every file without path): its writers call it, so a file
//     written twice in the same instant is read again all the same. T.
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
        static readonly Store store = new Store(Ansi());

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
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var row in t.Rows)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var cell in n < 0 ? row : Csv.Fit(row, n))
                    rb.Add(new TypedValue((int)LispDataType.Text, cell));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        [LispFunction("Dyl:DataHead")]
        public ResultBuffer DataHead(ResultBuffer args)
        {
            var a = Args(args);
            if (a.Count < 1 || !(a[0] is string path)) return null;
            var t = store.Get(path);
            if (t == null || t.Header == null) return null;
            var rb = new ResultBuffer();
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var cell in t.Header) rb.Add(new TypedValue((int)LispDataType.Text, cell));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return rb;
        }

        [LispFunction("Dyl:DataDrop")]
        public object DataDrop(ResultBuffer args)
        {
            var a = Args(args);
            store.Drop(a.Count > 0 ? a[0] as string : null);
            return true;
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

        // The arguments of a call, the atoms only (a string, a number, null for nil):
        static List<object> Args(ResultBuffer args)
        {
            var res = new List<object>();
            if (args == null) return res;
            foreach (TypedValue tv in args)
                res.Add((LispDataType)tv.TypeCode == LispDataType.Nil ? null : tv.Value);
            return res;
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
