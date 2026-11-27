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
// own style sheets: neither the managed themes nor the native ones reach it. In AutoCAD 2027 its
// browser (WebView2) is made in C++ by AcWebView.dll, whose AcBrowserEngineProxy lists its
// browser windows and runs a script in one (executeScript): those functions are found in its
// export table by their full C++ names (as in NativeThemes.cs: a name not exactly the one
// expected is never called), the windows listed (an iterator AcWebView makes; listed again
// every 30 s at most, since it is not freed), then found again by their names. When it is shown
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
        // The filter of Skin.Map, in JavaScript (the same constants), for the look $NAME (a page
        // in another look is given back first):
        const string Template = @"(function(){
if (window.__dyl === '$NAME') return;
if (window.__dyl && window.__dylUndo) window.__dylUndo();
window.__dyl = '$NAME';
var H=$HUE,MIN=$MIN,MS=$MAX,DK=$DARK,G=0.35,LI=0.6;
var P=['background-color','color','border-top-color','border-right-color','border-bottom-color','border-left-color','outline-color'];
var done=[], given=new WeakMap();
function parse(v){var m=/rgba?\(([^)]+)\)/.exec(v); if(!m) return null; var a=m[1].split(/[\s,\/]+/).filter(Boolean).map(parseFloat); return {r:a[0],g:a[1],b:a[2],a:a.length>3?a[3]:1};}
function map(c){ if(!(c.a>0)) return null;
 var r=c.r/255,g=c.g/255,b=c.b/255,mx=Math.max(r,g,b),mn=Math.min(r,g,b),l=(mx+mn)/2,d=mx-mn,s=0;
 if(d>1e-9) s=l>0.5?d/(2-mx-mn):d/(mx+mn);
 if(s>G&&l>0.08&&l<0.92) return null;
 if(l<LI) l*=DK; s=Math.min(Math.max(s,MIN),MS);
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

        static Look _look = Look.DynALisp;
        static string _script;
        static string Script => _script ??= Template.Replace("$NAME", _look.Name)
            .Replace("$HUE", N(_look.Hue)).Replace("$MIN", N(_look.MinSat)).Replace("$MAX", N(_look.MaxSat)).Replace("$DARK", N(_look.Darker));
        static string N(double v) => v.ToString(System.Globalization.CultureInfo.InvariantCulture);

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
        public static void Apply(bool on, Look look)
        {
            try
            {
                // Another look chosen: the pages given back, then put in the new one.
                if (look != _look) { Undo(); _look = look; _script = null; }
                if (!on) { _timer?.Stop(); _timer = null; Undo(); return; }
                if (_timer == null)
                {
                    // The browsers of AcWebView, often: a page shows its own colours until the
                    // script has run in it.
                    _timer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(Fast) };
                    _timer.Tick += (s, e) => { try { Work.Time("colours: script of the web pages (timer)", () => Native(Script)); } catch (System.Exception ex) { _nFail = ex.Message; } };
                    _timer.Start();
                    Native(Script);
                }
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
            if (_hooked.Count > 0) { try { Native(UndoScript); } catch { } _hooked.Clear(); }
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

        // ---- the browsers of AcWebView.dll (C++) ----

        const string NameInstance = "?Instance@AcBrowserEngineProxy@WebView@Autodesk@@SAPEAV123@XZ";
        const string NameIterator = "?newWindowIterator@AcBrowserEngineProxy@WebView@Autodesk@@QEAAPEAVAcBrowserWindowProxyIterator@23@XZ";
        const string NameDone = "?done@AcBrowserWindowProxyIterator@WebView@Autodesk@@QEAA_NXZ";
        const string NameCurrent = "?current@AcBrowserWindowProxyIterator@WebView@Autodesk@@QEAAPEAVAcBrowserWindowProxy@23@XZ";
        const string NameNext = "?next@AcBrowserWindowProxyIterator@WebView@Autodesk@@QEAAXXZ";
        const string NameIterEnd = "??1AcBrowserWindowProxyIterator@WebView@Autodesk@@QEAA@XZ";
        const string NameFind = "?findBrowserWindowByName@AcBrowserEngineProxy@WebView@Autodesk@@QEAAPEAVAcBrowserWindowProxy@23@PEB_W@Z";
        const string NameFindUrl = "?findBrowserWindowByUrl@AcBrowserEngineProxy@WebView@Autodesk@@QEAAPEAVAcBrowserWindowProxy@23@PEB_W@Z";
        const string NameExecute = "?executeScript@AcBrowserWindowProxy@WebView@Autodesk@@QEAA_NPEB_W@Z";
        const string NameName = "?name@AcBrowserWindowProxy@WebView@Autodesk@@QEBAPEB_WXZ";
        const string NameUrl = "?url@AcBrowserWindowProxy@WebView@Autodesk@@QEBAPEB_WXZ";

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr StaticFn();
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate IntPtr PtrFn(IntPtr self);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate byte BoolFn(IntPtr self);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall)] delegate void VoidFn(IntPtr self);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall, CharSet = CharSet.Unicode)] delegate IntPtr FindFn(IntPtr self, string name);
        [UnmanagedFunctionPointer(CallingConvention.ThisCall, CharSet = CharSet.Unicode)] delegate byte ExecFn(IntPtr self, string script);

        static bool _nLooked;
        static string _nFail;
        static IntPtr _engine;
        static PtrFn _iterator, _current, _name, _url;
        static BoolFn _done;
        static VoidFn _nextWin, _iterEnd;
        static FindFn _find, _findUrl;
        static ExecFn _exec;
        // The browser windows, by name, listed at most every 30 s; those given the script:
        static readonly List<string> _windows = new();
        static readonly HashSet<string> _hooked = new(StringComparer.Ordinal);
        static int _nextList = Environment.TickCount;
        static readonly Dictionary<string, string> _last = new(StringComparer.Ordinal);

        static System.Windows.Threading.DispatcherTimer _timer;
        // How often the script is run in the browsers of AcWebView (it does nothing a second time
        // in a page), and their windows looked for again (the windows of Chrome of AutoCAD):
        const int Fast = 150, LookEvery = 1000;
        static int _nextFind = Environment.TickCount, _nextLook = Environment.TickCount;
        static string _chrome = "";

        static bool NativeFind()
        {
            if (_nLooked) return _nFail == null;
            if (Environment.TickCount - _nextFind < 0) return false;    // AcWebView.dll not loaded yet: asked every 2 s
            _nextFind = Environment.TickCount + 2000;
            _nLooked = true;
            var mod = System.Diagnostics.Process.GetCurrentProcess().Modules.Cast<System.Diagnostics.ProcessModule>()
                .FirstOrDefault(m => m.ModuleName.Equals("AcWebView.dll", StringComparison.OrdinalIgnoreCase));
            if (mod == null) { _nFail = "no AcWebView.dll"; _nLooked = false; return false; }   // asked again: it may load later
            var ex = new Dictionary<string, IntPtr>();
            NativeThemes.Exports(mod.BaseAddress, ex, n => n.Contains("@WebView@Autodesk@@"));
            var need = new[] { NameInstance, NameIterator, NameDone, NameCurrent, NameNext, NameIterEnd, NameFind, NameFindUrl, NameExecute, NameName, NameUrl };
            var missing = need.Where(n => !ex.ContainsKey(n)).ToList();
            if (missing.Count > 0) { _nFail = "AcWebView functions " + string.Join(" ", missing.Select(n => n.TrimStart('?').Split('@')[0])); return false; }
            T Fn<T>(string n) => Marshal.GetDelegateForFunctionPointer<T>(ex[n]);
            _iterator = Fn<PtrFn>(NameIterator); _current = Fn<PtrFn>(NameCurrent); _name = Fn<PtrFn>(NameName); _url = Fn<PtrFn>(NameUrl);
            _done = Fn<BoolFn>(NameDone); _nextWin = Fn<VoidFn>(NameNext); _iterEnd = Fn<VoidFn>(NameIterEnd);
            _find = Fn<FindFn>(NameFind); _findUrl = Fn<FindFn>(NameFindUrl); _exec = Fn<ExecFn>(NameExecute);
            _engine = Fn<StaticFn>(NameInstance)();
            if (_engine == IntPtr.Zero) { _nFail = "no browser engine"; _nLooked = false; return false; }
            _nFail = null;
            return true;
        }

        // The names of the browser windows (an iterator of AcWebView, ended but not freed):
        static void List()
        {
            _windows.Clear();
            _last.Clear();
            IntPtr it = _iterator(_engine);
            if (it == IntPtr.Zero) return;
            for (int i = 0; i < 100 && _done(it) == 0; i++, _nextWin(it))
            {
                IntPtr w = _current(it);
                if (w == IntPtr.Zero) continue;
                // By its name, or by its page when it has none ("url:..."):
                string url = Marshal.PtrToStringUni(_url(w)) ?? "";
                string n = Marshal.PtrToStringUni(_name(w)) ?? "";
                if (n.Length == 0) n = "url:" + url;
                if (n != "url:" && !_windows.Contains(n)) _windows.Add(n);
                _last[n] = url;
            }
            _iterEnd(it);
        }

        // The script run in each browser window of AcWebView (it does nothing a second time in
        // the same page, so it is run every 2 s: a page loaded again gets it again).
        static void Native(string script)
        {
            if (!NativeFind()) return;
            // Listed again when the windows of Chrome of AutoCAD change (a browser made or
            // closed), and every 30 s:
            bool relist = Environment.TickCount - _nextList >= 30000;
            if (Environment.TickCount - _nextLook >= 0)
            {
                _nextLook = Environment.TickCount + LookEvery;
                string chrome = string.Join(",", Children(AcApp.MainWindow.Handle).Where(h => Class(h) == "Chrome_WidgetWin_0").Select(h => h.ToInt64()));
                if (chrome != _chrome) { _chrome = chrome; relist = true; }
            }
            if (relist)
            {
                _nextList = Environment.TickCount;
                List();
            }
            foreach (var n in _windows)
            {
                IntPtr w = n.StartsWith("url:", StringComparison.Ordinal) ? _findUrl(_engine, n.Substring(4)) : _find(_engine, n);
                if (w == IntPtr.Zero) continue;
                Work.Count("colours: script run in a browser of AutoCAD");
                if (_exec(w, script) != 0 && script == Script) _hooked.Add(n);
            }
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
            try
            {
                if (!NativeFind()) r.Add("AcWebView: " + _nFail);
                else
                {
                    List();
                    _nextList = Environment.TickCount;
                    r.Add("AcWebView: " + _windows.Count + " browser windows");
                    foreach (var n in _windows)
                        r.Add("browser " + n + ": " + _last.GetValueOrDefault(n, "") + (_hooked.Contains(n) ? ", in the colours of DynALisp" : ""));
                }
            }
            catch (System.Exception ex) { r.Add("AcWebView: " + ex.Message); }
            return r;
        }
    }
}
