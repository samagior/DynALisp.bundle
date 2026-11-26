// WebPages.cs - DynALisp.Ribbon: the web pages of AutoCAD (Start) in the dark of DynALisp (experiment)
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
// EXPERIMENT, not supported by Autodesk. The Start tab of AutoCAD is a web page, drawn by its
// own style sheets: neither the managed themes nor the native ones reach it. When it is shown
// by a managed browser control (WebView2, in WPF or Windows Forms, or CefSharp), found by its
// type name and used only by reflection (no reference to either), a script is run in its pages
// that puts the colours of each element (background, text, borders) through the same filter as
// Skin.Map, and those of the elements added after (a MutationObserver); with WebView2 it is
// also added to the pages it opens next. What it changed is given back when Palettes is turned
// off. (Dyl:RibbonSkin "Web") says what was found: the browser modules and assemblies loaded,
// the browser windows and the controls.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    public static class WebPages
    {
        // The filter of Skin.Map, in JavaScript (the same constants):
        const string Script = @"(function(){
if (window.__dyl) return; window.__dyl = 1;
var H=217,MS=0.16,DK=0.78,G=0.35,LI=0.6;
var P=['background-color','color','border-top-color','border-right-color','border-bottom-color','border-left-color','outline-color'];
var done=[], given=new WeakMap();
function parse(v){var m=/rgba?\(([^)]+)\)/.exec(v); if(!m) return null; var a=m[1].split(/[\s,\/]+/).filter(Boolean).map(parseFloat); return {r:a[0],g:a[1],b:a[2],a:a.length>3?a[3]:1};}
function map(c){ if(!(c.a>0)) return null;
 var r=c.r/255,g=c.g/255,b=c.b/255,mx=Math.max(r,g,b),mn=Math.min(r,g,b),l=(mx+mn)/2,d=mx-mn,s=0;
 if(d>1e-9) s=l>0.5?d/(2-mx-mn):d/(mx+mn);
 if(s>G&&l>0.08&&l<0.92) return null;
 if(l<LI) l*=DK; s=Math.min(Math.max(s,0.10),MS);
 var q=l<0.5?l*(1+s):l+s-l*s,p=2*l-q,k=H/360;
 function ch(t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<0.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}
 function B(v){return Math.round(Math.min(Math.max(v,0),1)*255);}
 return 'rgba('+B(ch(k+1/3))+','+B(ch(k))+','+B(ch(k-1/3))+','+c.a+')';}
function fix(el){ if(!(el instanceof Element)) return; var cs=getComputedStyle(el), g=given.get(el)||{};
 for(var i=0;i<P.length;i++){ var p=P[i], v=cs.getPropertyValue(p); if(g[p]===v) continue;
  var c=parse(v); if(!c) continue; var m=map(c); if(!m) continue;
  done.push([el,p,el.style.getPropertyValue(p),el.style.getPropertyPriority(p)]);
  el.style.setProperty(p,m,'important'); g[p]=getComputedStyle(el).getPropertyValue(p); }
 given.set(el,g); }
function all(root){ fix(root); var w=root.querySelectorAll?root.querySelectorAll('*'):[]; for(var i=0;i<w.length;i++) fix(w[i]); }
var mo=new MutationObserver(function(ms){ ms.forEach(function(m){
 if(m.type==='childList') m.addedNodes.forEach(function(n){ if(n.nodeType===1) all(n); }); else fix(m.target); }); });
function go(){ all(document.documentElement); mo.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['class']}); }
window.__dylUndo=function(){ mo.disconnect(); for(var i=done.length-1;i>=0;i--){ var d=done[i]; d[0].style.setProperty(d[1],d[2],d[3]); } done=[]; given=new WeakMap(); window.__dyl=0; };
if (document.readyState==='loading') document.addEventListener('DOMContentLoaded',go); else go();
})();";

        const string UndoScript = "window.__dylUndo && window.__dylUndo();";

        // A browser control the script was given: the control, its CoreWebView2 (WebView2) and
        // the task of AddScriptToExecuteOnDocumentCreatedAsync (its result is the id to remove).
        sealed class Hooked
        {
            public WeakReference Control;
            public object Core;
            public object AddTask;
        }
        static readonly List<Hooked> Done = new();
        static string _fail;
        static int _next = Environment.TickCount;

        // Run by Skin.OnIdle: on (the palettes wanted, AutoCAD dark) or off; every 2 s at most.
        public static void Apply(bool on)
        {
            try
            {
                if (!on) { Undo(); return; }
                if (Environment.TickCount - _next < 0) return;
                _next = Environment.TickCount + 2000;
                Done.RemoveAll(h => !h.Control.IsAlive);
                if (!BrowserLoaded()) return;
                foreach (var c in Controls()) Hook(c);
            }
            catch (System.Exception ex) { _fail = ex.Message; }
        }

        static void Hook(object ctl)
        {
            if (Done.Any(h => ReferenceEquals(h.Control.Target, ctl))) return;
            var core = Get(ctl, "CoreWebView2");
            if (core != null)
            {
                Call(core, "ExecuteScriptAsync", Script);
                var add = Call(core, "AddScriptToExecuteOnDocumentCreatedAsync", Script);
                Done.Add(new Hooked { Control = new WeakReference(ctl), Core = core, AddTask = add });
                return;
            }
            if (ctl.GetType().FullName.StartsWith("CefSharp", StringComparison.Ordinal) && Cef(ctl, Script))
                Done.Add(new Hooked { Control = new WeakReference(ctl) });
            // A WebView2 not ready yet (no CoreWebView2): tried again at the next call.
        }

        static void Undo()
        {
            foreach (var h in Done)
            {
                try
                {
                    object ctl = h.Control.Target;
                    if (ctl == null) continue;
                    if (h.Core != null)
                    {
                        Call(h.Core, "ExecuteScriptAsync", UndoScript);
                        if (h.AddTask != null && Get(h.AddTask, "IsCompleted") is true && Get(h.AddTask, "Result") is string id)
                            Call(h.Core, "RemoveScriptToExecuteOnDocumentCreated", id);
                    }
                    else Cef(ctl, UndoScript);
                }
                catch { }
            }
            Done.Clear();
        }

        // CefSharp: WebBrowserExtensions.ExecuteScriptAsync(browser, script), when there.
        static bool Cef(object ctl, string script)
        {
            var ext = ctl.GetType().Assembly.GetReferencedAssemblies()
                .Select(n => { try { return Assembly.Load(n); } catch { return null; } })
                .Append(ctl.GetType().Assembly)
                .Where(a => a != null)
                .Select(a => a.GetType("CefSharp.WebBrowserExtensions"))
                .FirstOrDefault(t => t != null);
            var m = ext?.GetMethods(BindingFlags.Public | BindingFlags.Static).FirstOrDefault(x =>
                x.Name == "ExecuteScriptAsync" && x.GetParameters().Length == 2
                && x.GetParameters()[1].ParameterType == typeof(string)
                && x.GetParameters()[0].ParameterType.IsInstanceOfType(ctl));
            if (m == null) return false;
            m.Invoke(null, new[] { ctl, script });
            return true;
        }

        static object Get(object o, string prop)
        {
            try { return o.GetType().GetProperty(prop, BindingFlags.Public | BindingFlags.Instance)?.GetValue(o); }
            catch { return null; }
        }

        static object Call(object o, string name, string arg)
        {
            var m = o.GetType().GetMethod(name, BindingFlags.Public | BindingFlags.Instance, null, new[] { typeof(string) }, null);
            return m?.Invoke(o, new object[] { arg });
        }

        // ---- finding them ----

        static bool IsBrowserName(string n) =>
            n.IndexOf("WebView2", StringComparison.OrdinalIgnoreCase) >= 0 || n.IndexOf("CefSharp", StringComparison.OrdinalIgnoreCase) >= 0;

        static bool BrowserLoaded() => AppDomain.CurrentDomain.GetAssemblies().Any(a => IsBrowserName(a.GetName().Name ?? ""));

        static bool IsBrowser(object o)
        {
            string n = o.GetType().FullName ?? "";
            return n.StartsWith("Microsoft.Web.WebView2.", StringComparison.Ordinal) && n.EndsWith(".WebView2", StringComparison.Ordinal)
                || n.StartsWith("CefSharp.", StringComparison.Ordinal) && n.EndsWith("ChromiumWebBrowser", StringComparison.Ordinal);
        }

        // The browser controls of the WPF windows (their visual trees, a WindowsFormsHost
        // included) and of the Windows Forms controls of the child windows of AutoCAD.
        static List<object> Controls()
        {
            var found = new List<object>();
            foreach (PresentationSource src in PresentationSource.CurrentSources)
                if (src?.RootVisual is DependencyObject root) Walk(root, found);
            var fromHandle = FromHandle();
            if (fromHandle != null)
                foreach (var hwnd in Children(AcApp.MainWindow.Handle))
                {
                    object c = null;
                    try { c = fromHandle.Invoke(null, new object[] { hwnd }); } catch { }
                    if (c != null && IsBrowser(c) && !found.Contains(c)) found.Add(c);
                }
            return found;
        }

        static void Walk(DependencyObject d, List<object> found)
        {
            if (IsBrowser(d)) { found.Add(d); return; }
            int n = d is Visual || d is System.Windows.Media.Media3D.Visual3D ? VisualTreeHelper.GetChildrenCount(d) : 0;
            for (int i = 0; i < n; i++) Walk(VisualTreeHelper.GetChild(d, i), found);
            if (d.GetType().Name == "WindowsFormsHost" && Get(d, "Child") is object child && IsBrowser(child)) found.Add(child);
        }

        static MethodInfo FromHandle()
        {
            var t = AppDomain.CurrentDomain.GetAssemblies().FirstOrDefault(a => a.GetName().Name == "System.Windows.Forms")?.GetType("System.Windows.Forms.Control");
            return t?.GetMethod("FromHandle", BindingFlags.Public | BindingFlags.Static, null, new[] { typeof(IntPtr) }, null);
        }

        delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr lParam);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
        [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);

        static List<IntPtr> Children(IntPtr parent)
        {
            var all = new List<IntPtr>();
            EnumChildWindows(parent, (h, _) => { all.Add(h); return true; }, IntPtr.Zero);
            return all;
        }

        static string Class(IntPtr h)
        {
            var sb = new StringBuilder(256);
            GetClassName(h, sb, sb.Capacity);
            return sb.ToString();
        }

        // What AutoCAD gives to reach its browser, for (Dyl:RibbonSkin "Web" "Detail"): the
        // functions AcWebView.dll exports (the browser of the Start tab is made there, in C++),
        // and the types and members of AppHomeInterop (managed).
        static void Detail(List<string> r)
        {
            foreach (System.Diagnostics.ProcessModule m in System.Diagnostics.Process.GetCurrentProcess().Modules)
            {
                if (!m.ModuleName.Equals("AcWebView.dll", StringComparison.OrdinalIgnoreCase)
                    && !m.ModuleName.Equals("AppHomeInterop.dll", StringComparison.OrdinalIgnoreCase)) continue;
                var ex = new Dictionary<string, IntPtr>();
                try { NativeThemes.Exports(m.BaseAddress, ex, n => true); } catch (System.Exception e) { r.Add(m.ModuleName + ": " + e.Message); }
                r.Add(m.ModuleName + ": " + ex.Count + " exports");
                r.AddRange(ex.Keys.OrderBy(k => k, StringComparer.Ordinal).Take(600));
            }
            foreach (var a in AppDomain.CurrentDomain.GetAssemblies().Where(a => a.GetName().Name == "AppHomeInterop"))
            {
                r.Add("assembly " + a.FullName + " (" + a.Location + ")");
                Type[] types;
                try { types = a.GetTypes(); } catch (ReflectionTypeLoadException e) { types = e.Types.Where(t => t != null).ToArray(); }
                const BindingFlags all = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;
                foreach (var t in types.OrderBy(t => t.FullName))
                {
                    if (t.Name.Contains("<")) continue;
                    var members = t.GetMembers(all)
                        .Where(x => !x.Name.Contains("<") && !(x is MethodInfo mi && mi.IsSpecialName))
                        .Select(x => x switch
                        {
                            MethodInfo mi => (mi.IsStatic ? "static " : "") + mi.Name + "(" + string.Join(", ", mi.GetParameters().Select(p => p.ParameterType.Name)) + ")",
                            PropertyInfo pi => pi.PropertyType.Name + " " + pi.Name,
                            FieldInfo fi => (fi.IsStatic ? "static " : "") + fi.FieldType.Name + " " + fi.Name,
                            EventInfo ei => "event " + ei.Name,
                            ConstructorInfo ci => "new(" + string.Join(", ", ci.GetParameters().Select(p => p.ParameterType.Name)) + ")",
                            _ => x.Name
                        });
                    r.Add((t.IsPublic ? "type " : "internal type ") + t.FullName + (t.BaseType != null ? " : " + t.BaseType.Name : "") + " { " + string.Join("; ", members) + " }");
                }
            }
        }

        // What was found, one line each, for (Dyl:RibbonSkin "Web"):
        public static List<string> Report(bool detail = false)
        {
            var r = new List<string>();
            if (detail) { Detail(r); return r; }
            if (_fail != null) r.Add("error: " + _fail);
            var mods = new List<string>();
            foreach (System.Diagnostics.ProcessModule m in System.Diagnostics.Process.GetCurrentProcess().Modules)
            {
                string n = m.ModuleName;
                if (n.IndexOf("cef", StringComparison.OrdinalIgnoreCase) >= 0 || n.IndexOf("webview", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("EmbeddedBrowser", StringComparison.OrdinalIgnoreCase) >= 0 || n.IndexOf("chrom", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("browser", StringComparison.OrdinalIgnoreCase) >= 0 || n.IndexOf("home", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("start", StringComparison.OrdinalIgnoreCase) >= 0)
                    mods.Add(n);
            }
            r.Add("modules: " + (mods.Count > 0 ? string.Join(", ", mods) : "none"));
            var asms = AppDomain.CurrentDomain.GetAssemblies().Select(a => a.GetName().Name ?? "")
                .Where(n => IsBrowserName(n) || n.IndexOf("Browser", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("Home", StringComparison.OrdinalIgnoreCase) >= 0 || n.IndexOf("Start", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("Web", StringComparison.OrdinalIgnoreCase) >= 0)
                .Distinct().OrderBy(n => n).ToList();
            r.Add("assemblies: " + (asms.Count > 0 ? string.Join(", ", asms) : "none"));
            // The browser windows, with the classes of their parents (who holds them):
            foreach (var h in Children(AcApp.MainWindow.Handle))
            {
                string c = Class(h);
                if (c.IndexOf("Chrome", StringComparison.OrdinalIgnoreCase) < 0 && c.IndexOf("Cef", StringComparison.OrdinalIgnoreCase) < 0
                    && c.IndexOf("WebView", StringComparison.OrdinalIgnoreCase) < 0) continue;
                var chain = new List<string>();
                for (IntPtr p = GetParent(h); p != IntPtr.Zero && chain.Count < 5; p = GetParent(p)) chain.Add(Class(p));
                r.Add("window " + c + (IsWindowVisible(h) ? " (shown)" : " (hidden)") + " in " + string.Join(" < ", chain));
            }
            List<object> ctls;
            try { ctls = Controls(); } catch (System.Exception ex) { ctls = new List<object>(); r.Add("controls: " + ex.Message); }
            foreach (var c in ctls)
            {
                var core = Get(c, "CoreWebView2");
                string src = (core != null ? Get(core, "Source") : Get(c, "Address") ?? Get(c, "Source"))?.ToString();
                bool hooked = Done.Any(h => ReferenceEquals(h.Control.Target, c));
                r.Add("control " + c.GetType().FullName + ": " + (src ?? "no page") + (hooked ? ", in the colours of DynALisp" : core == null && c.GetType().FullName.Contains("WebView2") ? ", not ready" : ""));
            }
            if (ctls.Count == 0) r.Add("no browser control found");
            return r;
        }
    }
}
