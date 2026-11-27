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
//   (Dyl:HatchDefs contents dimzin)
//     The default hatch presets fixed, as Remote>>Dyl:HatchPresetDefs gives them (dimzin:
//     DIMZIN, which rtos follows); nil when the Lisp reads them itself (the default file
//     missing, see Data\Materials.cs).
//
//   (Dyl:MatDefs contents)
//     The default materials fixed, as Remote>>Dyl:MaterialRowDefs gives them; nil as
//     Dyl:HatchDefs.
//
//   (Dyl:MatBoth contents dimzin)
//     The hatch presets and the materials read and fixed, the defaults missing added, as
//     Remote>>Dyl:MaterialBoth gives them: (hatch-presets materials); nil when the Lisp reads
//     them itself (a materials file of DynALisp 1.1 to split, see Data\Materials.cs).
//
//   (Dyl:AsmPats contents cannoscale measurement insunits lunits luprec dimzin)
//     The patterns of the hatch presets (upper case, SOLID left out) whose units
//     Dyl:AsmShows needs, found by the Lisp (Remote>>Dyl:MaterialPatUnits); the system
//     variables of the drawing (CANNOSCALEVALUE, MEASUREMENT, INSUNITS, LUNITS, LUPREC,
//     DIMZIN). nil when the Lisp makes what is shown itself (see Data\Shows.cs).
//
//   (Dyl:AsmShows contents cannoscale measurement insunits lunits luprec dimzin [pattern units file] ...)
//     What the Quick Draw window shows of each assembly read (Dyl:AsmRead, in its order), as
//     Dyl:QuickDrawAsmShow gives it: ((id layers width preview description) ...); then, for
//     each pattern of Dyl:AsmPats, its units ("Imperial", "Metric", "" when no file defines
//     it) and its file. nil as Dyl:AsmPats.
//
//   (Dyl:AsmTabPats contents dimzin)
//     The patterns of the materials (upper case, SOLID left out) whose units the Assembly
//     Presets window needs for the previews of its Material list, found by the Lisp
//     (Remote>>Dyl:MaterialPatUnits) and given to Dyl:AsmWindow (DynALisp.Windows.dll). nil
//     when the Lisp reads the materials (see Data\AsmTab.cs).
//
//   (Dyl:AsmWinMats contents dimzin ((layers border dividing) ...))
//     What the Assembly Presets window lists for the presets given (their columns 3, 4 and 5),
//     as Dyl:QuickDrawAsmWinMats gives it: (mats groups keys), mats ((id name row group) ...)
//     where row is the index of the material among those of Dyl:MatBoth (-1 for a material
//     missing), groups the groups of the Group list, keys the layer keys the presets use; nil
//     when the Lisp reads the materials (see Data\AsmWindow.cs).
//
//   (Dyl:AsmRows contents measurement insunits dimzin bk def ((layers border dividing units) ...))
//     The columns the Assembly Presets window adds to each preset given (its columns 3, 4, 5
//     and 7), as Dyl:QuickDrawAsmExtra gives them: ((rows border-lines... dividing-lines...)
//     ...), bk the layer key of new lines (qa:bk) and def the row Add starts from (qa:def).
//     nil as Dyl:AsmWinMats.
//
//   (Dyl:MatData contents measurement insunits dimzin (id ...))
//     The data of each material id, as Remote>>Dyl:MaterialDataLists gives them: (resistances
//     masses). nil as Dyl:AsmWinMats.
//
//   (Dyl:DataInfo)
//     What the plugin did in this session, for Dyl-Diagnostics: (("Files" . n) ("Reads" . n)
//     ("Hits" . n) ("ReadMs" . ms)), the files kept, the reads of a file, the calls given a
//     file kept, the time spent reading.

using System;
using System.Collections.Generic;
using System.Linq;
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

        // The bundle of the Contents folder contents, kept for the session (the files it reads
        // shared by every drawing); also the bundle of the windows of DynALisp.Windows.dll that
        // read the data (Dyl:AsmWindow):
        public static Bundle BundleOf(object contents)
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

        [LispFunction("Dyl:HatchDefs")]
        public ResultBuffer HatchDefs(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            return b == null || a.Count < 2 ? null : Rows(Materials.HatchDefs(b, Int(a[1])));
        }

        [LispFunction("Dyl:MatDefs")]
        public ResultBuffer MatDefs(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            return b == null ? null : Rows(Materials.RowDefs(b));
        }

        [LispFunction("Dyl:MatBoth")]
        public ResultBuffer MatBoth(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            var both = b == null || a.Count < 2 ? null : Materials.Both(b, Int(a[1]));
            if (both == null) return null;
            var (hps, mats) = both.Value;
            var rb = new List<TypedValue>((hps.Count + mats.Count) * 66 + 6);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            AddRows(rb, hps);
            AddRows(rb, mats);
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        // The system variables of the drawing, from the argument i on (see Data\Shows.cs):
        static Units UnitsOf(List<object> a, int i) => a.Count < i + 6 ? null : new Units
        {
            CannoScale = Real(a[i]),
            Measurement = Int(a[i + 1]),
            Insunits = Int(a[i + 2]),
            Lunits = Int(a[i + 3]),
            Luprec = Int(a[i + 4]),
            Dimzin = Int(a[i + 5]),
        };

        [LispFunction("Dyl:AsmPats")]
        public ResultBuffer AsmPats(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            var u = UnitsOf(a, 1);
            var pats = b == null || u == null ? null : Shows.Patterns(b, u);
            if (pats == null) return null;
            var rb = new List<TypedValue>(pats.Count + 2);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var p in pats) rb.Add(new TypedValue((int)LispDataType.Text, p));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:AsmTabPats")]
        public ResultBuffer AsmTabPats(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            var pats = b == null || a.Count < 2 ? null : AsmTab.Patterns(b, Int(a[1]));
            if (pats == null) return null;
            var rb = new List<TypedValue>(pats.Count + 2);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var p in pats) rb.Add(new TypedValue((int)LispDataType.Text, p));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:AsmShows")]
        public ResultBuffer AsmShows(ResultBuffer args)
        {
            var a = Args(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            var u = UnitsOf(a, 1);
            if (b == null || u == null) return null;
            var pats = new Dictionary<string, (string Units, string File)?>(StringComparer.Ordinal);
            for (int i = 7; i + 2 < a.Count; i += 3)
            {
                string p = a[i] as string, units = a[i + 1] as string, file = a[i + 2] as string;
                if (p != null) pats[p] = string.IsNullOrEmpty(units) ? null : ((string, string)?)(units, file ?? "");
            }
            return Rows(Shows.All(b, u, pats));
        }

        [LispFunction("Dyl:AsmWinMats")]
        public ResultBuffer AsmWinMats(ResultBuffer args)
        {
            var a = Tree(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            if (b == null || a.Count < 2) return null;
            var lists = AsmWindow.Mats(b, Int(a[1]), Strings(a.Count > 2 ? a[2] : null));
            if (lists == null) return null;
            var rb = new List<TypedValue>(lists.Mats.Count * 6 + lists.Groups.Count + lists.Used.Count + 8);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            if (lists.Mats.Count == 0) rb.Add(new TypedValue((int)LispDataType.Nil));
            else
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var m in lists.Mats)
                {
                    rb.Add(new TypedValue((int)LispDataType.ListBegin));
                    rb.Add(new TypedValue((int)LispDataType.Text, m.Id));
                    rb.Add(new TypedValue((int)LispDataType.Text, m.Name));
                    rb.Add(new TypedValue((int)LispDataType.Int32, m.Row));
                    rb.Add(new TypedValue((int)LispDataType.Text, m.Group));
                    rb.Add(new TypedValue((int)LispDataType.ListEnd));
                }
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            AddList(rb, lists.Groups);
            AddList(rb, lists.Used);
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        [LispFunction("Dyl:AsmRows")]
        public ResultBuffer AsmRows(ResultBuffer args)
        {
            var a = Tree(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            if (b == null || a.Count < 7 || !(a[4] is string bk) || !(a[5] is List<object> def)) return null;
            var u = new Units { Measurement = Int(a[1]), Insunits = Int(a[2]), Dimzin = Int(a[3]) };
            var d = def.Select(x => x as string ?? "").ToArray();
            return Rows(AsmWindow.Extras(b, u, d, bk, Strings(a[6])));
        }

        [LispFunction("Dyl:MatData")]
        public ResultBuffer MatData(ResultBuffer args)
        {
            var a = Tree(args);
            var b = BundleOf(a.Count > 0 ? a[0] : null);
            if (b == null || a.Count < 5 || !(a[4] is List<object> ids)) return null;
            var u = new Units { Measurement = Int(a[1]), Insunits = Int(a[2]), Dimzin = Int(a[3]) };
            var data = AsmWindow.Data(b, u, ids.Select(x => x as string ?? ""));
            if (data == null) return null;
            var rb = new List<TypedValue>(data.Value.Rsi.Count * 2 + 6);
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            AddList(rb, data.Value.Rsi);
            AddList(rb, data.Value.Mass);
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
            return Result(rb);
        }

        // The strings of a list as one list (nil for none):
        static void AddList(List<TypedValue> rb, List<string> lst)
        {
            if (lst.Count == 0)
            {
                rb.Add(new TypedValue((int)LispDataType.Nil));
                return;
            }
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var s in lst) rb.Add(new TypedValue((int)LispDataType.Text, s ?? ""));
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
        }

        // A list of lists of strings given by the Lisp ((s ...) ...), nil and other atoms as "":
        static List<string[]> Strings(object o)
        {
            var res = new List<string[]>();
            if (o is List<object> lst)
                foreach (var x in lst)
                    res.Add(x is List<object> r ? r.Select(y => y as string ?? "").ToArray() : new string[0]);
            return res;
        }

        // A list of rows as the Lisp gets it, nil for none:
        static ResultBuffer Rows(List<string[]> rows)
        {
            if (rows == null || rows.Count == 0) return null;
            var rb = new List<TypedValue>(rows.Count * 17 + 2);
            AddRows(rb, rows);
            return Result(rb);
        }

        // The rows added to rb as one list (nil for none):
        static void AddRows(List<TypedValue> rb, List<string[]> rows)
        {
            if (rows == null || rows.Count == 0)
            {
                rb.Add(new TypedValue((int)LispDataType.Nil));
                return;
            }
            rb.Add(new TypedValue((int)LispDataType.ListBegin));
            foreach (var row in rows)
            {
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var cell in row) rb.Add(new TypedValue((int)LispDataType.Text, cell ?? ""));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
            }
            rb.Add(new TypedValue((int)LispDataType.ListEnd));
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

        // The arguments of a call as they are written, a list given as a List<object> (its
        // atoms a string, a number, null for nil):
        static List<object> Tree(ResultBuffer args)
        {
            var root = new List<object>();
            if (args == null) return root;
            var stack = new Stack<List<object>>();
            var cur = root;
            foreach (TypedValue tv in args)
            {
                switch ((LispDataType)tv.TypeCode)
                {
                    case LispDataType.ListBegin:
                        var l = new List<object>();
                        cur.Add(l);
                        stack.Push(cur);
                        cur = l;
                        break;
                    case LispDataType.ListEnd:
                    case LispDataType.DottedPair:
                        if (stack.Count > 0) cur = stack.Pop();
                        break;
                    case LispDataType.Nil:
                        cur.Add(null);
                        break;
                    default:
                        cur.Add(tv.Value);
                        break;
                }
            }
            return root;
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
