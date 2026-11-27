// SheetSetPalette.cs - DynALisp.Startup: what the Sheet Set Manager palette shows
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
// The sheet set manager of AutoCAD (AcSmSheetSetMgr) holds every sheet set loaded in the
// session, those the palette shows and those another part of AutoCAD loaded without it (the
// sheet set of the current project of the Project Navigator of AutoCAD Architecture). Only
// the palette knows which ones the user opened, and it has no API. (Dyl:SheetSets "Tree")
// writes what this plugin finds of it, to read its list: every window of AutoCAD whose text
// names the Sheet Set Manager, its children with their class, text and items (combo boxes,
// lists, trees), and the WPF elements of those that are WPF. The palette must be shown.

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

namespace DynALisp.Startup
{
    static class SheetSetPalette
    {
        delegate bool EnumProc(IntPtr h, IntPtr l);

        [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] static extern int GetDlgCtrlID(IntPtr h);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr h, int i);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder l);

        const uint GW_HWNDNEXT = 2, GW_CHILD = 5;
        const int GWL_STYLE = -16;
        static readonly Regex Named = new Regex("sheet ?set|jeux? de feuilles", RegexOptions.IgnoreCase);

        public static string Tree()
        {
            var sb = new StringBuilder();
            sb.AppendLine("DynALisp - the Sheet Set Manager palette as the plugin finds it, " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            sb.AppendLine("AutoCAD " + Autodesk.AutoCAD.ApplicationServices.Application.Version);
            sb.AppendLine();
            uint me = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;
            var tops = new List<IntPtr>();
            EnumWindows((h, l) => { GetWindowThreadProcessId(h, out uint pid); if (pid == me) tops.Add(h); return true; }, IntPtr.Zero);
            var found = new List<IntPtr>();
            foreach (var t in tops) Find(t, found, 0);
            if (found.Count == 0) sb.AppendLine("No window names the Sheet Set Manager: show its palette (SHEETSET) and run it again.");
            var done = new HashSet<IntPtr>();
            foreach (var h in found)
            {
                if (done.Contains(h)) continue;
                sb.AppendLine("==== " + Line(h));
                Dump(h, sb, 1, done);
                sb.AppendLine();
            }
            string path = Path.Combine(Path.GetTempPath(), "DynALisp-SheetSets.txt");
            File.WriteAllText(path, sb.ToString(), new UTF8Encoding(true));
            return path;
        }

        // The windows whose text names the Sheet Set Manager (the palette, its caption, its tab):
        static void Find(IntPtr h, List<IntPtr> found, int depth)
        {
            if (depth > 40) return;
            if (Named.IsMatch(Text(h))) found.Add(h);
            for (var c = GetWindow(h, GW_CHILD); c != IntPtr.Zero; c = GetWindow(c, GW_HWNDNEXT)) Find(c, found, depth + 1);
        }

        static string Class(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
        static string Text(IntPtr h) { var s = new StringBuilder(512); GetWindowText(h, s, 512); return s.ToString(); }

        static string Line(IntPtr h) =>
            Class(h) + " \"" + Text(h) + "\" id=" + GetDlgCtrlID(h) + (IsWindowVisible(h) ? "" : " (hidden)")
            + " style=0x" + ((long)GetWindowLongPtr(h, GWL_STYLE)).ToString("X");

        static void Dump(IntPtr h, StringBuilder sb, int depth, HashSet<IntPtr> done)
        {
            if (depth > 30 || !done.Add(h)) return;
            string pad = new string(' ', depth * 2);
            string cls = Class(h);
            foreach (var it in Items(h, cls)) sb.AppendLine(pad + "  - " + it);
            try
            {
                var src = HwndSource.FromHwnd(h);
                if (src?.RootVisual != null) Wpf(src.RootVisual, sb, depth + 1, 0);
            }
            catch (Exception ex) { sb.AppendLine(pad + "  (WPF: " + ex.Message + ")"); }
            for (var c = GetWindow(h, GW_CHILD); c != IntPtr.Zero; c = GetWindow(c, GW_HWNDNEXT))
            {
                sb.AppendLine(pad + Line(c));
                Dump(c, sb, depth + 1, done);
            }
        }

        // The items of a combo box, a list or a tree:
        static List<string> Items(IntPtr h, string cls)
        {
            var lst = new List<string>();
            long style = (long)GetWindowLongPtr(h, GWL_STYLE);
            try
            {
                if (cls.IndexOf("ComboBoxEx", StringComparison.OrdinalIgnoreCase) >= 0) ComboEx(h, lst);
                else if (cls.IndexOf("ComboBox", StringComparison.OrdinalIgnoreCase) >= 0)
                    Strings(h, lst, 0x146, 0x149, 0x148, (style & 0x30) == 0 || (style & 0x200) != 0);   // CB_GETCOUNT...
                else if (cls.IndexOf("ListBox", StringComparison.OrdinalIgnoreCase) >= 0)
                    Strings(h, lst, 0x18B, 0x18A, 0x189, (style & 0x30) == 0 || (style & 0x40) != 0);    // LB_GETCOUNT...
                else if (cls.IndexOf("TreeView", StringComparison.OrdinalIgnoreCase) >= 0) Tree(h, lst);
                else if (cls.IndexOf("ListView", StringComparison.OrdinalIgnoreCase) >= 0)
                    lst.Add("(a list view of " + (long)SendMessage(h, 0x1004, IntPtr.Zero, IntPtr.Zero) + " items)");
            }
            catch (Exception ex) { lst.Add("(items: " + ex.Message + ")"); }
            return lst;
        }

        static void Strings(IntPtr h, List<string> lst, uint count, uint len, uint text, bool hasStrings)
        {
            int n = (int)SendMessage(h, count, IntPtr.Zero, IntPtr.Zero);
            lst.Add("(" + n + " items" + (hasStrings ? "" : ", owner drawn without strings") + ")");
            if (!hasStrings) return;
            for (int i = 0; i < n && i < 200; i++)
            {
                int l = (int)SendMessage(h, len, (IntPtr)i, IntPtr.Zero);
                if (l < 0 || l > 4000) { lst.Add("#" + i + " (length " + l + ")"); continue; }
                var s = new StringBuilder(l + 1);
                SendMessage(h, text, (IntPtr)i, s);
                lst.Add("#" + i + " " + s);
            }
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct COMBOBOXEXITEM
        {
            public uint mask; public IntPtr iItem; public IntPtr pszText; public int cchTextMax;
            public int iImage, iSelectedImage, iOverlay, iIndent; public IntPtr lParam;
        }

        static void ComboEx(IntPtr h, List<string> lst)
        {
            int n = (int)SendMessage(h, 0x146, IntPtr.Zero, IntPtr.Zero);
            lst.Add("(" + n + " items)");
            IntPtr buf = Marshal.AllocHGlobal(2048);
            IntPtr item = Marshal.AllocHGlobal(Marshal.SizeOf<COMBOBOXEXITEM>());
            try
            {
                for (int i = 0; i < n && i < 200; i++)
                {
                    var it = new COMBOBOXEXITEM { mask = 1 /* CBEIF_TEXT */, iItem = (IntPtr)i, pszText = buf, cchTextMax = 1024 };
                    Marshal.StructureToPtr(it, item, false);
                    SendMessage(h, 0x40D /* CBEM_GETITEMW */, IntPtr.Zero, item);
                    it = Marshal.PtrToStructure<COMBOBOXEXITEM>(item);
                    lst.Add("#" + i + " " + Marshal.PtrToStringUni(it.pszText));
                }
            }
            finally { Marshal.FreeHGlobal(buf); Marshal.FreeHGlobal(item); }
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct TVITEM
        {
            public uint mask; public IntPtr hItem; public uint state, stateMask; public IntPtr pszText;
            public int cchTextMax, iImage, iSelectedImage, cChildren; public IntPtr lParam;
        }

        static void Tree(IntPtr h, List<string> lst)
        {
            IntPtr buf = Marshal.AllocHGlobal(2048);
            IntPtr item = Marshal.AllocHGlobal(Marshal.SizeOf<TVITEM>());
            int count = 0;
            try
            {
                void Walk(IntPtr ti, int depth)
                {
                    for (; ti != IntPtr.Zero && count < 300; ti = SendMessage(h, 0x110A, (IntPtr)1 /* TVGN_NEXT */, ti))
                    {
                        count++;
                        var it = new TVITEM { mask = 0x11 /* TEXT | HANDLE */, hItem = ti, pszText = buf, cchTextMax = 1024 };
                        Marshal.StructureToPtr(it, item, false);
                        SendMessage(h, 0x113E /* TVM_GETITEMW */, IntPtr.Zero, item);
                        lst.Add(new string(' ', depth * 2) + Marshal.PtrToStringUni(buf));
                        if (depth < 3) Walk(SendMessage(h, 0x110A, (IntPtr)4 /* TVGN_CHILD */, ti), depth + 1);
                    }
                }
                Walk(SendMessage(h, 0x110A, IntPtr.Zero /* TVGN_ROOT */, IntPtr.Zero), 0);
            }
            finally { Marshal.FreeHGlobal(buf); Marshal.FreeHGlobal(item); }
        }

        // The WPF elements of a WPF window, with their texts and the items of their lists:
        static void Wpf(DependencyObject o, StringBuilder sb, int depth, int n)
        {
            if (depth > 60) return;
            string pad = new string(' ', depth * 2);
            string what = o.GetType().Name;
            switch (o)
            {
                case System.Windows.Controls.TextBlock tb: what += " \"" + tb.Text + "\""; break;
                case System.Windows.Controls.ItemsControl ic:
                    what += " (" + ic.Items.Count + " items)";
                    if (o is System.Windows.Controls.Primitives.Selector sel) what += " selected=" + sel.SelectedIndex;
                    break;
                case System.Windows.Controls.ContentControl cc when cc.Content is string s: what += " \"" + s + "\""; break;
                case System.Windows.Controls.TextBox tx: what += " \"" + tx.Text + "\""; break;
            }
            if (o is FrameworkElement fe && !string.IsNullOrEmpty(fe.Name)) what += " #" + fe.Name;
            sb.AppendLine(pad + what);
            if (o is System.Windows.Controls.ItemsControl list)
                for (int i = 0; i < list.Items.Count && i < 100; i++)
                    sb.AppendLine(pad + "  - item " + i + ": " + Describe(list.Items[i]));
            int c = VisualTreeHelper.GetChildrenCount(o);
            for (int i = 0; i < c; i++) Wpf(VisualTreeHelper.GetChild(o, i), sb, depth + 1, n + 1);
        }

        // An item of a WPF list: its text, or its type and its string properties:
        static string Describe(object it)
        {
            if (it == null) return "null";
            if (it is string s) return s;
            var sb = new StringBuilder(it.GetType().FullName);
            try
            {
                foreach (var p in it.GetType().GetProperties())
                {
                    if (p.GetIndexParameters().Length > 0) continue;
                    if (p.PropertyType != typeof(string) && p.PropertyType != typeof(bool) && p.PropertyType != typeof(int)) continue;
                    object v = null;
                    try { v = p.GetValue(it); } catch { }
                    if (v != null) sb.Append(" " + p.Name + "=" + v);
                }
            }
            catch { }
            return sb.ToString();
        }
    }
}
