// SheetSetMgr.cs - DynALisp.Startup: the sheet set manager of AutoCAD, called through its type
// library
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
// The objects of the Sheet Set Manager (AcSmComponents) do not implement IDispatch: they
// cannot be called late bound (InvokeMember, dynamic: "COM target does not implement
// IDispatch"), and their interop assembly (ACSMCOMPONENTS<nn>Lib) is versioned with AutoCAD
// and not in the NuGet package. So the methods are called through their virtual tables, as
// the type library of the installed AutoCAD describes them: the interface found by its name
// (IAcSmSheetSetMgr...), its id asked of the object (QueryInterface), and the slot of each
// method read from its FUNCDESC (oVft), the bases of the interface included. Nothing is
// guessed: a name or a library not found is an error, and the caller does nothing.

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32;
using ComTypes = System.Runtime.InteropServices.ComTypes;

namespace DynALisp.Startup
{
    static class SheetSetMgr
    {
        [DllImport("oleaut32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        static extern ComTypes.ITypeLib LoadRegTypeLib(ref Guid rguid, short wVerMajor, short wVerMinor, int lcid);

        [DllImport("oleaut32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        static extern ComTypes.ITypeLib LoadTypeLibEx(string szFile, int regkind);

        // HRESULT f(this, [out] IUnknown**)
        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate int OutPtr(IntPtr self, out IntPtr result);

        // HRESULT f(this, [out] BSTR*)
        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate int OutBstr(IntPtr self, out IntPtr bstr);

        // HRESULT OpenDatabase(this, BSTR filename, VARIANT_BOOL bFailIfAlreadyOpen, [out] IAcSmDatabase**)
        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate int OpenDb(IntPtr self, [MarshalAs(UnmanagedType.BStr)] string file, short failIfOpen, out IntPtr db);

        static ComTypes.ITypeLib _lib;
        static readonly Dictionary<string, (Guid Iid, Dictionary<string, int> Slots)> _ifaces =
            new Dictionary<string, (Guid, Dictionary<string, int>)>(StringComparer.OrdinalIgnoreCase);
        static IntPtr _mgr;      // IAcSmSheetSetMgr*, kept for the session
        public static string ProgId, Library;

        // ---- the manager ----

        // IAcSmSheetSetMgr* of the manager (one for the session, the one of the palette):
        static IntPtr Mgr()
        {
            if (_mgr != IntPtr.Zero) return _mgr;
            var v = Autodesk.AutoCAD.ApplicationServices.Application.Version;
            Type t = null;
            foreach (var id in new[] { "AcSmComponents.AcSmSheetSetMgr", "AcSmComponents.AcSmSheetSetMgr." + v.Major,
                                       "AcSmComponents.AcSmSheetSetMgr." + v.Major + "." + v.Minor })
            {
                t = Type.GetTypeFromProgID(id);
                if (t != null) { ProgId = id; break; }
            }
            if (t == null) throw new InvalidOperationException("AcSmComponents.AcSmSheetSetMgr is not registered");
            Lib(t.GUID);
            object o = Activator.CreateInstance(t);
            IntPtr unk = Marshal.GetIUnknownForObject(o);
            try { _mgr = Query(unk, "IAcSmSheetSetMgr"); }
            finally { Marshal.Release(unk); }
            return _mgr;
        }

        // A database open in the manager: its file, its IAcSmDatabase* and its IUnknown*, as
        // numbers only (released: the manager keeps them), to be found in the palette:
        public struct Db
        {
            public string File, Name;     // its file, the name of its sheet set
            public long Ptr, Unk;         // IAcSmDatabase*, IUnknown*
            public long Ss, SsUnk;        // IAcSmSheetSet* of its sheet set, IUnknown*
            public bool Has(long v) => v != 0 && (v == Ptr || v == Unk || v == Ss || v == SsUnk);
        }

        // The files of the sheet sets open in the manager, in its order:
        public static List<string> OpenFiles()
        {
            var lst = new List<string>();
            foreach (var d in OpenDbs()) lst.Add(d.File);
            return lst;
        }

        public static List<Db> OpenDbs()
        {
            var lst = new List<Db>();
            IntPtr en = CallPtr(Mgr(), "IAcSmSheetSetMgr", "GetDatabaseEnumerator");
            if (en == IntPtr.Zero) return lst;
            try
            {
                for (int i = 0; i < 1000; i++)
                {
                    IntPtr db = CallPtr(en, "IAcSmEnumDatabase", "Next");
                    if (db == IntPtr.Zero) break;
                    try
                    {
                        string f = FileOf(db);
                        long unk = 0;
                        Guid iu = new Guid("00000000-0000-0000-C000-000000000046");
#pragma warning disable CS9191
                        if (Marshal.QueryInterface(db, ref iu, out IntPtr u) >= 0 && u != IntPtr.Zero) { unk = (long)u; Marshal.Release(u); }
#pragma warning restore CS9191
                        var d = new Db { File = f, Ptr = (long)db, Unk = unk };
                        SheetSetOf(db, ref d);
                        if (!string.IsNullOrWhiteSpace(f)) lst.Add(d);
                    }
                    finally { Marshal.Release(db); }
                }
            }
            finally { Marshal.Release(en); }
            return lst;
        }

        // A sheet set opened in the manager (not failing when it is open already):
        public static void OpenDatabase(string file)
        {
            IntPtr m = Mgr();
            var f = Method<OpenDb>(m, "IAcSmSheetSetMgr", "OpenDatabase");
            Check(f(m, file, 0, out IntPtr db), "OpenDatabase");
            if (db != IntPtr.Zero) Marshal.Release(db);
        }

        // HRESULT Close(this, IAcSmDatabase*)
        [UnmanagedFunctionPointer(CallingConvention.StdCall)]
        delegate int CloseDb(IntPtr self, IntPtr db);

        // The title of the sheet set of a file (the name the Sheet Set Manager shows), read
        // from the database open in the manager, else opened for the moment and closed again;
        // null when it cannot be read. Also compiled into DynALisp.Windows.dll (the cards of the
        // Start page). On the thread of AutoCAD only.
        public static string TitleOf(string file)
        {
            foreach (var d in OpenDbs())
                if (string.Equals(d.File, file, StringComparison.OrdinalIgnoreCase)) return d.Name;
            IntPtr m = Mgr();
            var open = Method<OpenDb>(m, "IAcSmSheetSetMgr", "OpenDatabase");
            Check(open(m, file, 0, out IntPtr db), "OpenDatabase");
            if (db == IntPtr.Zero) return null;
            try
            {
                var d = new Db();
                SheetSetOf(db, ref d);
                return d.Name;
            }
            finally
            {
                try { Method<CloseDb>(m, "IAcSmSheetSetMgr", "Close")(m, db); } catch { }
                Marshal.Release(db);
            }
        }

        // The sheet set of a database (GetSheetSet): its address and its name (GetName of
        // IAcSmComponent), what the palette knows it by. Nothing when it cannot be read:
        static void SheetSetOf(IntPtr db, ref Db d)
        {
            IntPtr ss = IntPtr.Zero;
            try
            {
                ss = CallPtr(db, "IAcSmDatabase", "GetSheetSet");
                if (ss == IntPtr.Zero) return;
                d.Ss = (long)ss;
                Guid iu = new Guid("00000000-0000-0000-C000-000000000046");
#pragma warning disable CS9191
                if (Marshal.QueryInterface(ss, ref iu, out IntPtr u) >= 0 && u != IntPtr.Zero) { d.SsUnk = (long)u; Marshal.Release(u); }
#pragma warning restore CS9191
                var f = Method<OutBstr>(ss, "IAcSmSheetSet", "GetName");
                if (f(ss, out IntPtr b) >= 0 && b != IntPtr.Zero)
                {
                    try { d.Name = Marshal.PtrToStringBSTR(b); } finally { Marshal.FreeBSTR(b); }
                }
            }
            catch { }
            finally { if (ss != IntPtr.Zero) Marshal.Release(ss); }
        }

        // GetFileName of a database (IAcSmDatabase*, the method of one of its bases):
        static string FileOf(IntPtr db)
        {
            var f = Method<OutBstr>(db, "IAcSmDatabase", "GetFileName");
            Check(f(db, out IntPtr b), "GetFileName");
            if (b == IntPtr.Zero) return null;
            try { return Marshal.PtrToStringBSTR(b); }
            finally { Marshal.FreeBSTR(b); }
        }

        // ---- calls through the virtual table ----

        static IntPtr CallPtr(IntPtr self, string iface, string name)
        {
            var f = Method<OutPtr>(self, iface, name);
            int hr = f(self, out IntPtr r);
            Check(hr, name);
            return r;   // S_FALSE with nothing: the end of an enumerator
        }

        static T Method<T>(IntPtr self, string iface, string name) where T : Delegate
        {
            if (!Iface(iface).Slots.TryGetValue(name, out int slot))
                throw new MissingMethodException(iface + "." + name + " is not in " + Library);
            IntPtr vtbl = Marshal.ReadIntPtr(self);
            IntPtr fn = Marshal.ReadIntPtr(vtbl, slot * IntPtr.Size);
            return Marshal.GetDelegateForFunctionPointer<T>(fn);
        }

        static void Check(int hr, string name)
        {
            if (hr < 0) throw new COMException(name + " failed (0x" + hr.ToString("X8") + ")", hr);
        }

        // The interface iface of the object unk (AddRef'd):
        static IntPtr Query(IntPtr unk, string iface)
        {
            Guid iid = Iface(iface).Iid;
#pragma warning disable CS9191   // ref in .NET 8, in in .NET 10: the same code for both builds
            int hr = Marshal.QueryInterface(unk, ref iid, out IntPtr p);
#pragma warning restore CS9191
            if (hr < 0 || p == IntPtr.Zero) throw new InvalidCastException(iface + " not given by the object (0x" + hr.ToString("X8") + ")");
            return p;
        }

        // ---- the type library ----

        // The type library of the class clsid: the one its key names, or else a file
        // AcSmComponents*.tlb beside acad.exe:
        static void Lib(Guid clsid)
        {
            if (_lib != null) return;
            using (var k = Registry.ClassesRoot.OpenSubKey(@"CLSID\{" + clsid + @"}\TypeLib"))
            {
                string libid = k?.GetValue(null) as string;
                if (libid != null && Guid.TryParse(libid, out Guid g))
                {
                    using (var vk = Registry.ClassesRoot.OpenSubKey(@"CLSID\{" + clsid + @"}\Version"))
                    {
                        foreach (var ver in Versions(g, vk?.GetValue(null) as string))
                        {
                            try
                            {
                                _lib = LoadRegTypeLib(ref g, ver.Item1, ver.Item2, 0);
                                Library = "{" + g + "} " + ver.Item1 + "." + ver.Item2;
                                return;
                            }
                            catch { }
                        }
                    }
                }
            }
            string dir = Path.GetDirectoryName(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName);
            foreach (var f in Directory.GetFiles(dir, "AcSmComponents*.tlb"))
            {
                try { _lib = LoadTypeLibEx(f, 2 /* REGKIND_NONE */); Library = f; return; }
                catch { }
            }
            throw new FileNotFoundException("The type library of AcSmComponents is not found");
        }

        // The versions of the library libid to try: the one of the class first, then those
        // registered, the newest first:
        static List<(short, short)> Versions(Guid libid, string first)
        {
            var lst = new List<(short, short)>();
            void Add(string s)
            {
                var p = (s ?? "").Split('.');
                if (p.Length >= 2 && short.TryParse(p[0], System.Globalization.NumberStyles.HexNumber, null, out short a)
                    && short.TryParse(p[1], System.Globalization.NumberStyles.HexNumber, null, out short b) && !lst.Contains((a, b)))
                    lst.Add((a, b));
            }
            Add(first);
            using (var k = Registry.ClassesRoot.OpenSubKey(@"TypeLib\{" + libid + "}"))
            {
                var names = new List<string>(k?.GetSubKeyNames() ?? new string[0]);
                names.Sort((x, y) => string.CompareOrdinal(y, x));
                foreach (var n in names) Add(n);
            }
            return lst;
        }

        // The id and the slots (method name -> index in the virtual table) of the interface
        // named iface, its bases included:
        static (Guid Iid, Dictionary<string, int> Slots) Iface(string iface)
        {
            if (_ifaces.TryGetValue(iface, out var known)) return known;
            if (_lib == null) Mgr();
            ComTypes.ITypeInfo ti = null;
            for (int i = 0, n = _lib.GetTypeInfoCount(); i < n; i++)
            {
                _lib.GetDocumentation(i, out string name, out _, out _, out _);
                if (string.Equals(name, iface, StringComparison.OrdinalIgnoreCase)) { _lib.GetTypeInfo(i, out ti); break; }
            }
            if (ti == null) throw new MissingMemberException(iface + " is not in " + Library);
            ti = VtableInfo(ti);
            var slots = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            Guid iid = Attr(ti).guid;
            for (var t = ti; t != null; t = Base(t)) Slots(t, slots);
            var r = (iid, slots);
            _ifaces[iface] = r;
            return r;
        }

        // The vtable interface of a dual one (its TKIND_DISPATCH half), else itself:
        static ComTypes.ITypeInfo VtableInfo(ComTypes.ITypeInfo ti)
        {
            if (Attr(ti).typekind != ComTypes.TYPEKIND.TKIND_DISPATCH) return ti;
            try { ti.GetRefTypeOfImplType(-1, out int h); ti.GetRefTypeInfo(h, out var v); return v; }
            catch { return ti; }
        }

        static ComTypes.ITypeInfo Base(ComTypes.ITypeInfo ti)
        {
            if (Attr(ti).cImplTypes < 1) return null;
            try { ti.GetRefTypeOfImplType(0, out int h); ti.GetRefTypeInfo(h, out var b); return b; }
            catch { return null; }
        }

        static ComTypes.TYPEATTR Attr(ComTypes.ITypeInfo ti)
        {
            ti.GetTypeAttr(out IntPtr p);
            try { return Marshal.PtrToStructure<ComTypes.TYPEATTR>(p); }
            finally { ti.ReleaseTypeAttr(p); }
        }

        // The methods of one interface (not its bases): the slot of each, from its oVft (bytes):
        static void Slots(ComTypes.ITypeInfo ti, Dictionary<string, int> slots)
        {
            var a = Attr(ti);
            for (int i = 0; i < a.cFuncs; i++)
            {
                ti.GetFuncDesc(i, out IntPtr p);
                try
                {
                    var fd = Marshal.PtrToStructure<ComTypes.FUNCDESC>(p);
                    var names = new string[1];
                    ti.GetNames(fd.memid, names, 1, out int got);
                    if (got > 0 && names[0] != null && !slots.ContainsKey(names[0]))
                        slots[names[0]] = fd.oVft / IntPtr.Size;
                }
                finally { ti.ReleaseFuncDesc(p); }
            }
        }
    }
}
