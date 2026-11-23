// Lisp.cs - DynALisp.Assistant: the calls of the tools to the Lisp side of DynALisp
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
// What DynALisp knows (its materials, assemblies and presets) and what it does (Quick Draw,
// the material of an object) is in its Lisp: a tool asks it through (Remote>>Dyl:AssistantCall
// op args) of Modules\Dynalisp\Remote\Dyl-Assistant.lsp, made callable by vl-acad-defun,
// called with Application.Invoke on the main thread, in the command context of AutoCAD
// (Host.InCommand), so never while a command runs.
//
//   arguments  a string, a number, true / false (T / nil), null (nil), a list (a Lisp list)
//   answer     a list of pairs (("key" . value) ...) is a JSON object, any other list an array,
//              T true, nil null; (("error" . message)) a ToolError with that message

using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using CoreApp = Autodesk.AutoCAD.ApplicationServices.Core.Application;

namespace DynALisp.Assistant
{
    static class Lisp
    {
        const string Function = "REMOTE>>DYL:ASSISTANTCALL";   // the symbol, as AutoLISP keeps it

        // (Remote>>Dyl:AssistantCall op args), in the command context only (Host.InCommand).
        public static object Call(string op, params object[] args)
        {
            ResultBuffer res;
            using (var rb = new ResultBuffer())
            {
                rb.Add(new TypedValue((int)LispDataType.Text, Function));
                rb.Add(new TypedValue((int)LispDataType.Text, op));
                Add(rb, new List<object>(args));
                try { res = CoreApp.Invoke(rb); }
                catch (System.Exception e)
                {
                    throw new ToolError("The Lisp side of DynALisp did not answer (" + e.Message + "): DynALisp may not be loaded in this drawing.");
                }
            }
            object v;
            using (res) v = res == null ? null : Read(res.AsArray());
            if (v is Dictionary<string, object> d && d.Count == 1 && d.TryGetValue("error", out var err))
                throw new ToolError(Convert.ToString(err, CultureInfo.InvariantCulture));
            return v;
        }

        // ---- to Lisp ----------------------------------------------------------------

        static void Add(ResultBuffer rb, object v)
        {
            switch (v)
            {
                case null: rb.Add(new TypedValue((int)LispDataType.Nil)); break;
                case string s: rb.Add(new TypedValue((int)LispDataType.Text, s)); break;
                case bool b: rb.Add(new TypedValue((int)(b ? LispDataType.T_atom : LispDataType.Nil))); break;
                case int i: rb.Add(new TypedValue((int)LispDataType.Int32, i)); break;
                case long l: rb.Add(new TypedValue((int)LispDataType.Int32, (int)l)); break;
                case double d: rb.Add(new TypedValue((int)LispDataType.Double, d)); break;
                case IEnumerable e:
                    var items = new List<object>();
                    foreach (var x in e) items.Add(x);
                    if (items.Count == 0) { rb.Add(new TypedValue((int)LispDataType.Nil)); break; }
                    rb.Add(new TypedValue((int)LispDataType.ListBegin));
                    foreach (var x in items) Add(rb, x);
                    rb.Add(new TypedValue((int)LispDataType.ListEnd));
                    break;
                default: rb.Add(new TypedValue((int)LispDataType.Text, Convert.ToString(v, CultureInfo.InvariantCulture))); break;
            }
        }

        // ---- from Lisp --------------------------------------------------------------

        // A Lisp list as read: its items, and the cdr of a dotted pair (("a" . 1): a, then 1).
        sealed class LList
        {
            public readonly List<object> Items = new List<object>();
            public bool Dotted;
            public object Tail;
        }

        static object Read(TypedValue[] a)
        {
            int i = 0;
            var all = new List<object>();
            while (i < a.Length) all.Add(Item(a, ref i));
            return Shape(all.Count == 1 ? all[0] : ToList(all));
        }

        static LList ToList(List<object> items)
        {
            var l = new LList();
            l.Items.AddRange(items);
            return l;
        }

        static object Item(TypedValue[] a, ref int i)
        {
            var tv = a[i++];
            switch ((LispDataType)tv.TypeCode)
            {
                case LispDataType.ListBegin:
                    var l = new LList();
                    while (i < a.Length)
                    {
                        var c = (LispDataType)a[i].TypeCode;
                        if (c == LispDataType.ListEnd) { i++; break; }
                        if (c == LispDataType.DottedPair)
                        {
                            // the last item read is the cdr
                            i++;
                            if (l.Items.Count > 0)
                            {
                                l.Tail = l.Items[l.Items.Count - 1];
                                l.Items.RemoveAt(l.Items.Count - 1);
                                l.Dotted = true;
                            }
                            break;
                        }
                        l.Items.Add(Item(a, ref i));
                    }
                    return l;
                case LispDataType.Nil: return null;
                case LispDataType.T_atom: return true;
                case LispDataType.Text: return tv.Value as string;
                case LispDataType.Int16: return Convert.ToInt32(tv.Value, CultureInfo.InvariantCulture);
                case LispDataType.Int32: return Convert.ToInt32(tv.Value, CultureInfo.InvariantCulture);
                case LispDataType.Double:
                case LispDataType.Angle:
                case LispDataType.Orientation:
                    return Tools.R(Convert.ToDouble(tv.Value, CultureInfo.InvariantCulture));
                case LispDataType.Point2d:
                    var p2 = (Point2d)tv.Value;
                    return new List<object> { Tools.R(p2.X), Tools.R(p2.Y) };
                case LispDataType.Point3d:
                    var p3 = (Point3d)tv.Value;
                    return new List<object> { Tools.R(p3.X), Tools.R(p3.Y), Tools.R(p3.Z) };
                case LispDataType.ObjectId:
                    return tv.Value is ObjectId id ? Tools.H(id) : null;
                case LispDataType.ListEnd:
                case LispDataType.DottedPair:
                case LispDataType.Void:
                case LispDataType.None:
                    return null;
                default:
                    return Convert.ToString(tv.Value, CultureInfo.InvariantCulture);
            }
        }

        // A list of pairs whose keys are strings (each key once) is an object, any other list
        // an array; a dotted pair outside an object, [car, cdr].
        static object Shape(object v)
        {
            if (!(v is LList l)) return v;
            if (l.Dotted) return new List<object> { Shape(l.Items.Count > 0 ? l.Items[0] : null), Shape(l.Tail) };
            if (IsObject(l))
            {
                var d = new Dictionary<string, object>();
                foreach (LList p in l.Items)
                {
                    var key = (string)p.Items[0];
                    if (p.Dotted) d[key] = Shape(p.Tail);
                    else if (p.Items.Count == 1) d[key] = null;
                    else
                    {
                        var rest = new LList();
                        for (int k = 1; k < p.Items.Count; k++) rest.Items.Add(p.Items[k]);
                        d[key] = Shape(rest);
                    }
                }
                return d;
            }
            var arr = new List<object>();
            foreach (var x in l.Items) arr.Add(Shape(x));
            return arr;
        }

        static bool IsObject(LList l)
        {
            if (l.Items.Count == 0) return false;
            var keys = new HashSet<string>();
            foreach (var x in l.Items)
            {
                if (!(x is LList p) || p.Items.Count == 0 || !(p.Items[0] is string k) || !keys.Add(k)) return false;
                if (p.Dotted && p.Items.Count != 1) return false;
            }
            return true;
        }
    }
}
