// StartPage.cs - DynALisp.Windows: the Start page of DynALisp, in the Start tab of AutoCAD
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
// Start page (Overrides of Dyl-Settings, the DynalispStartPage user setting, off by default):
// the page of the Start tab of AutoCAD gives way to the page of DynALisp,
// Res\Dyl-StartPage.xaml: what is pinned (drawings, sheet sets, projects), the active time of
// each day (Activity.cs), the recent drawings (with the picture each drawing keeps of
// itself), and a line at its foot on DynALisp (its version, its startup, the problems found).
//
// EXPERIMENT, not supported by Autodesk: the Start tab has no API. Its page is a web page,
// in a browser window (Chrome_WidgetWin_*, CefSharp or WebView2) inside a window of the tab,
// a child of the MDIClient of AutoCAD (a drawing is another child, without a browser). The
// page of DynALisp is a WPF HwndSource made a child of that window of the tab, over its whole
// area, the browser window under it hidden; hidden with the tab (AutoCAD hides the window of
// a tab not shown), destroyed with it. A timer (on the thread of AutoCAD, nothing in a
// command) keeps it the size of the tab and reads the setting every second; the values of
// the page are read again each time the tab is shown, the recent drawings on another thread
// (a drawing on a network drive can be slow to answer). What it does not find leaves the
// Start tab as AutoCAD made it, and is said by (Dyl:StartPage) and Dyl-Diagnostics
// (Interface); (Dyl:StartPage "Tree") writes the windows around the browsers, for another
// version of AutoCAD. Turned off, the browser window is shown again and the page destroyed.
//
// No Lisp runs in the Start tab (no drawing may be open): the values are read here, the
// startup of DynALisp in the last drawing opened given by the Lisp at the end of its startup
// ((Dyl:StartPageInfo ...), Dyl:StartupSummary of dynalisp.mnl), kept in a file of %TEMP%
// for the next session. A button that needs the Lisp (Settings, Run Diagnostics) runs its
// command in a drawing open, greyed out while none is.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: CommandClass(typeof(DynALisp.Windows.StartPageLisp))]

namespace DynALisp.Windows
{
    static class StartPage
    {
        const string Setting = "DynalispStartPage";
        const string PageFile = "Dyl-StartPage.xaml";
        const string Docs = @"Core\Dyl-StartPage.htm";
        // The plugins of DynALisp (PackageContents.xml), by their assembly:
        static readonly string[] Plugins = { "Core", "Ribbon", "Windows", "Startup", "Assistant", "Simulation" };

        static DispatcherTimer _timer;
        static bool _on;
        static int _nextSetting = Environment.TickCount, _nextFind = Environment.TickCount;
        // The window of the Start tab, the window of its browser hidden under the page:
        static IntPtr _frame, _host;
        static HwndSource _src;
        static Session _s;
        static View _view;
        static bool _dark, _neutral, _shown, _reading;
        static string _fail, _found;
        static int _recentCount = -1;
        static string _recentKey;
        static bool _readAgain;

        public static void Init()
        {
            try
            {
                _timer = new DispatcherTimer(DispatcherPriority.Background) { Interval = TimeSpan.FromMilliseconds(200) };
                _timer.Tick += (a, b) => Tick();
                _timer.Start();
            }
            catch (System.Exception e) { _fail = e.Message; }
        }

        // (Dyl:StartPage "Apply"): the setting read again at the next tick.
        internal static void Apply() => _nextSetting = Environment.TickCount;

        // The page is shown (the Start tab is the tab in front): no drawing is worked on.
        internal static bool Showing() => _src != null && _frame != IntPtr.Zero && IsWindowVisible(_frame);

        static void Tick()
        {
            try
            {
                int now = Environment.TickCount;
                if (now - _nextSetting >= 0) { _on = On(); _nextSetting = now + 1000; }
                if (!_on) { Remove(); return; }
                if (_frame != IntPtr.Zero && !IsWindow(_frame)) Forget();
                if (_frame == IntPtr.Zero)
                {
                    if (now - _nextFind < 0) return;
                    _nextFind = now + 1000;
                    if (!Find(out _frame, out _host)) { _frame = _host = IntPtr.Zero; return; }
                    _shown = false;
                }
                bool vis = IsWindowVisible(_frame);
                // The theme of AutoCAD changed: the page made again in it.
                if (_src != null && vis && !_shown && (Dark() != _dark || Theme.Neutral() != _neutral)) Destroy();
                if (_src == null)
                {
                    // (a page that cannot be made, its file missing: tried again in 10 s)
                    try { Build(); }
                    catch (System.Exception e) { _fail = "the page: " + e.Message; Forget(); _nextFind = now + 10000; return; }
                    if (_src == null) return;
                }
                if (vis && !_shown) Refresh();
                _shown = vis;
                if (!vis) return;
                if (_host != IntPtr.Zero && IsWindowVisible(_host)) ShowWindow(_host, SW_HIDE);
                GetClientRect(_frame, out RECT fr);
                GetWindowRect(_src.Handle, out RECT pr);
                int w = fr.Right - fr.Left, h = fr.Bottom - fr.Top;
                if (pr.Right - pr.Left != w || pr.Bottom - pr.Top != h || GetWindow(_frame, GW_CHILD) != _src.Handle)
                    SetWindowPos(_src.Handle, HWND_TOP, 0, 0, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
            }
            catch (System.Exception e) { _fail = e.Message; }
        }

        // ---- the Start tab ----

        static bool IsBrowser(IntPtr h)
        {
            string c = Class(h);
            return c.StartsWith("Chrome_WidgetWin", StringComparison.Ordinal) || c.IndexOf("Cef", StringComparison.OrdinalIgnoreCase) >= 0
                || c.IndexOf("WebView", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        // The MDIClient of AutoCAD, the child of it that holds a browser (the Start tab), and the
        // child of that one the browser is in (hidden under the page):
        static bool Find(out IntPtr frame, out IntPtr host)
        {
            frame = host = IntPtr.Zero;
            IntPtr main = Bridge.MainWindow();
            if (main == IntPtr.Zero) { _found = "no main window"; return false; }
            IntPtr mdi = Children(main).FirstOrDefault(h => Class(h) == "MDIClient");
            if (mdi == IntPtr.Zero) { _found = "no MDIClient in the main window"; return false; }
            var all = Children(mdi);
            var browsers = all.Where(IsBrowser).ToList();
            if (browsers.Count == 0) { _found = "no browser in the MDIClient (Start tab not made yet, or STARTMODE 0)"; return false; }
            // The top of the chain of a browser below the MDIClient, and the child of that one:
            IntPtr best = IntPtr.Zero, bestHost = IntPtr.Zero;
            foreach (var b in browsers)
            {
                IntPtr below = b, top = b;
                for (IntPtr p = GetParent(b); p != IntPtr.Zero && p != mdi; p = GetParent(p)) { below = top; top = p; }
                if (GetParent(top) != mdi) continue;
                IntPtr h = top == b ? b : below;
                if (best == IntPtr.Zero || (IsWindowVisible(top) && !IsWindowVisible(best))) { best = top; bestHost = h; }
            }
            if (best == IntPtr.Zero) { _found = "no window of the MDIClient holds a browser"; return false; }
            // A browser that is the window of the tab itself: the page over it, in its parent.
            if (bestHost == best) { _found = "the browser is the window of the tab: " + Class(best); return false; }
            frame = best;
            host = bestHost;
            _found = "Start tab " + Class(frame) + ", its browser in " + Class(host);
            return true;
        }

        static void Build()
        {
            string path = Path.Combine(Root(), "Contents", "Modules", "Dynalisp", "Res", PageFile);
            _dark = Dark();
            _neutral = Theme.Neutral();
            _s = new Session { Dark = _dark };
            Values(_s);
            _view = _s.Open(path);
            var page = Page.Of(_view.Window);
            Wire();
            Enable();
            GetClientRect(_frame, out RECT r);
            var p = new HwndSourceParameters("DynALisp Start")
            {
                ParentWindow = _frame,
                WindowStyle = WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
                PositionX = 0,
                PositionY = 0,
                Width = Math.Max(1, r.Right - r.Left),
                Height = Math.Max(1, r.Bottom - r.Top),
            };
            _src = new HwndSource(p) { SizeToContent = SizeToContent.Manual, RootVisual = page };
            if (page.Background is SolidColorBrush back && _src.CompositionTarget != null) _src.CompositionTarget.BackgroundColor = back.Color;
            _src.Disposed += (a, b) => { if (ReferenceEquals(a, _src)) { _src = null; _view = null; } };
            _shown = false;
        }

        static void Destroy()
        {
            var src = _src;
            _src = null;
            _view = null;
            try { src?.Dispose(); } catch { }
        }

        static void Forget()
        {
            Destroy();
            _frame = _host = IntPtr.Zero;
            _shown = false;
        }

        // Off: the page destroyed, the browser shown again.
        static void Remove()
        {
            if (_src == null && _host == IntPtr.Zero) return;
            Destroy();
            if (_host != IntPtr.Zero && IsWindow(_host)) ShowWindow(_host, SW_SHOW);
            _frame = _host = IntPtr.Zero;
            _shown = false;
        }

        // ---- the buttons ----

        static void Wire()
        {
            if (_view.Find("new") is Button nw) nw.Click += (a, b) => Do(New);
            if (_view.Find("opn") is Button op) op.Click += (a, b) => Do(OpenAsk);
            if (_view.Find("set") is Button st) st.Click += (a, b) => Do(() => Command("Dyl-Settings"));
            if (_view.Find("dia") is Button dg) dg.Click += (a, b) => Do(() => Command("Dyl-Diagnostics"));
            if (_view.Find("rep") is Button rp) rp.Click += (a, b) => Do(() => { var r = LastReport(); if (r != null) Shell(r); });
            if (_view.Find("pnb") is Button pb) pb.Click += (a, b) => Do(PinAsk);
            if (_view.Find("rec") is RecentDrawings rec)
            {
                rec.Opened += (f, ro) => Do(() => Open(f, ro));
                rec.Folder += f => Do(() => ShowInFolder(f));
                rec.Pin += (f, on) => Do(() => Pin(f, on));
                rec.PinChoices = PinChoices;
            }
            if (_view.Find("pin") is PinnedItems pin)
            {
                pin.Opened += (f, ro) => Do(() => Open(f, ro));
                pin.Folder += f => Do(() => ShowInFolder(f));
                pin.Unpinned += f => Do(() => Pin(f, false));
            }
            if (_view.Find("act") is ActivityGraph act) act.Opened += (f, ro) => Do(() => Open(f, ro));
        }

        // ---- the pins ----

        static string Kind(string path)
        {
            string ext = Path.GetExtension(path).ToLowerInvariant();
            return ext == ".dst" ? "Sheet set" : ext == ".apj" ? "Project" : "Drawing";
        }

        static void Pin(string path, bool on)
        {
            if (!Activity.Pin(path, on)) { Say(Activity.MaxPins + " are pinned already: unpin one first."); return; }
            ReadRows();
        }

        static void PinAsk()
        {
            var dlg = new Microsoft.Win32.OpenFileDialog
            {
                Title = "Pin",
                Filter = "Drawings, sheet sets and projects (*.dwg;*.dst;*.apj)|*.dwg;*.dst;*.apj|All files (*.*)|*.*",
            };
            if (dlg.ShowDialog() == true) Pin(dlg.FileName, true);
        }

        // What a recent drawing can pin: itself, its sheet set, its project (the first .dst and
        // .apj from its folder up, as the colours of the file tabs find them):
        static List<(string Label, string Path, bool Pinned)> PinChoices(string dwg)
        {
            var r = new List<(string, string, bool)> { ("Pin", dwg, Activity.Pinned(dwg)) };
            string dst = Up(dwg, "*.dst"), apj = Up(dwg, "*.apj");
            if (dst != null) r.Add(("Pin sheet set " + Path.GetFileNameWithoutExtension(dst), dst, Activity.Pinned(dst)));
            if (apj != null) r.Add(("Pin project " + Path.GetFileNameWithoutExtension(apj), apj, Activity.Pinned(apj)));
            return r;
        }

        static string Up(string file, string pattern)
        {
            try
            {
                for (var d = Path.GetDirectoryName(file); !string.IsNullOrEmpty(d); d = Path.GetDirectoryName(d))
                {
                    if (!Directory.Exists(d)) continue;
                    var hit = Directory.EnumerateFiles(d, pattern).OrderBy(f => f, StringComparer.OrdinalIgnoreCase).FirstOrDefault();
                    if (hit != null) return hit;
                }
            }
            catch { }
            return null;
        }

        // A sheet set opened in the Sheet Set Manager, by OPENSHEETSET at the command line of a
        // drawing open (as Reopen sheet sets does, SheetSets.cs):
        static void OpenSheetSet(string dst)
        {
            var doc = Drawing();
            if (doc == null) { Say("Open a drawing first: the sheet set opens in the Sheet Set Manager of a drawing."); return; }
            string f = "\"" + dst.Replace("\\", "\\\\").Replace("\"", "") + "\"";
            string lisp = "(progn (setq *dyl:ssopen* (list (getvar \"FILEDIA\") (getvar \"CMDECHO\")))"
                        + " (setvar \"FILEDIA\" 0) (setvar \"CMDECHO\" 0)"
                        + " (vl-catch-all-apply 'command-s (list \"_.OPENSHEETSET\" " + f + "))"
                        + " (setvar \"FILEDIA\" (car *dyl:ssopen*)) (setvar \"CMDECHO\" (cadr *dyl:ssopen*))"
                        + " (setq *dyl:ssopen* nil) (princ))\n";
            AcApp.DocumentManager.MdiActiveDocument = doc;
            doc.SendStringToExecute(lisp, true, false, false);
        }

        static void Do(Action a)
        {
            Say("");
            try { a(); }
            catch (System.Exception e) { Say(e.Message); }
        }

        static void Say(string msg)
        {
            if (_view?.Find("err") is TextBlock t)
            {
                t.Text = msg ?? "";
                t.Visibility = string.IsNullOrEmpty(t.Text) ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible;
            }
        }

        // The template of QNEW, else that of the units of AutoCAD:
        static void New()
        {
            string t = "";
            try { dynamic prefs = AcApp.Preferences; t = (string)prefs.Files.QNewTemplateFile; } catch { }
            if (string.IsNullOrEmpty(t) || !System.IO.File.Exists(t))
            {
                int mi = 0;
                try { mi = Convert.ToInt32(AcApp.GetSystemVariable("MEASUREINIT")); } catch { }
                t = mi == 1 ? "acadiso.dwt" : "acad.dwt";
            }
            AcApp.DocumentManager.Add(t);
        }

        static void OpenAsk()
        {
            var dlg = new Microsoft.Win32.OpenFileDialog
            {
                Title = "Open",
                Filter = "Drawings (*.dwg;*.dxf;*.dws;*.dwt)|*.dwg;*.dxf;*.dws;*.dwt|All files (*.*)|*.*",
                Multiselect = true,
            };
            var first = _s?.Rows.TryGetValue("rec" + RecentDrawings.RowsSuffix, out var rows) == true ? rows.FirstOrDefault() : null;
            if (first != null && first.Length > 0)
            {
                string dir = Path.GetDirectoryName(first[0]);
                if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir)) dlg.InitialDirectory = dir;
            }
            if (dlg.ShowDialog() != true) return;
            foreach (var f in dlg.FileNames) Open(f, dlg.ReadOnlyChecked);
        }

        // A drawing opened (made current when it is open already):
        static void Open(string file, bool readOnly)
        {
            if (!System.IO.File.Exists(file)) { Say("Not found: " + file); return; }
            if (Kind(file) == "Sheet set") { OpenSheetSet(file); return; }
            if (Kind(file) == "Project") { ShowInFolder(file); return; }
            var dm = AcApp.DocumentManager;
            foreach (Document d in dm)
            {
                string n = "";
                try { n = d.Name; } catch { }
                if (string.Equals(Path.GetFullPath(n), Path.GetFullPath(file), StringComparison.OrdinalIgnoreCase)) { dm.MdiActiveDocument = d; return; }
            }
            dm.Open(file, readOnly);
        }

        static void ShowInFolder(string file)
        {
            if (System.IO.File.Exists(file)) Process.Start(new ProcessStartInfo("explorer.exe", "/select,\"" + file + "\"") { UseShellExecute = true });
            else
            {
                string dir = Path.GetDirectoryName(file);
                if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir)) Shell(dir);
                else Say("Not found: " + (dir ?? file));
            }
        }

        static void Shell(string target) => Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });

        // A drawing to run a command of DynALisp in: the current one, else the first open:
        static Document Drawing()
        {
            var dm = AcApp.DocumentManager;
            if (dm.MdiActiveDocument != null) return dm.MdiActiveDocument;
            foreach (Document d in dm) return d;
            return null;
        }

        static void Command(string cmd)
        {
            var doc = Drawing();
            if (doc == null) { Say("Open a drawing first."); return; }
            doc.SendStringToExecute(cmd + "\n", true, false, false);
        }

        // ---- the values of the page ----

        static void Refresh()
        {
            if (_s == null || _view == null) return;
            Values(_s);
            _view.Fill();
            Enable();
            ReadRows();
        }

        // The buttons greyed out by Values, and those enabled again (the engine greys out a key
        // of Session.Off, but never enables it again: a window is filled once):
        static void Enable()
        {
            foreach (var key in new[] { "set", "dia", "rep" })
                if (_view?.Find(key) is Button b) b.IsEnabled = !_s.Off.Contains(key);
            // a note without text takes no room:
            foreach (var key in new[] { "actn", "ftp", "err" })
                if (_view?.Find(key) is TextBlock t) t.Visibility = string.IsNullOrEmpty(t.Text) ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible;
        }

        static void Values(Session s)
        {
            s.Values["ver"] = Foot();
            s.Values["ftp"] = Problems();
            s.Values["actn"] = Env(Activity.Setting) == "1" ? "" : "Active time is off: turn it on in Settings, under Start page.";
            s.Values[Session.DocsKey(Docs)] = DocsTarget();
            bool dwg = Drawing() != null;
            Off(s, "set", !dwg);
            Off(s, "dia", !dwg);
            Off(s, "rep", LastReport() == null);
        }

        static void Off(Session s, string key, bool off)
        {
            if (off) s.Off.Add(key); else s.Off.Remove(key);
        }

        // The foot of the page: DynALisp, its version, the AutoCAD around it and its last startup:
        static string Foot()
        {
            var info = StartPageLisp.Last ?? StartPageLisp.ReadLast();
            return "DynALisp " + Version() + "  \u00b7  " + Product()
                   + (info != null ? "  \u00b7  started in " + info.Ms.ToString(CultureInfo.InvariantCulture) + " ms" : "");
        }

        // What is wrong, in a few words (in red at the foot of the page), "" when nothing is:
        // the plugins not loaded, the warnings of the last startup and the files it could not
        // load, the problems of the last report of Dyl-Diagnostics.
        static string Problems()
        {
            var r = new List<string>();
            var loaded = new HashSet<string>(AppDomain.CurrentDomain.GetAssemblies().Select(a => a.GetName().Name ?? ""), StringComparer.OrdinalIgnoreCase);
            var missing = Plugins.Where(p => !loaded.Contains("DynALisp." + p)).ToList();
            if (missing.Count > 0) r.Add("not loaded: " + string.Join(", ", missing));
            var info = StartPageLisp.Last ?? StartPageLisp.ReadLast();
            if (info != null && info.Warnings.Count > 0) r.Add(Plural(info.Warnings.Count, "startup warning", "startup warnings"));
            if (info != null && info.Errors.Count > 0) r.Add(Plural(info.Errors.Count, "file did not load", "files did not load"));
            int n = ReportProblems();
            if (n > 0) r.Add(Plural(n, "problem", "problems") + " in the last diagnostics");
            return string.Join("  \u00b7  ", r);
        }

        static string Plural(int n, string one, string many) => n.ToString(CultureInfo.InvariantCulture) + " " + (n == 1 ? one : many);

        static int ReportProblems()
        {
            string rep = LastReport();
            if (rep == null) return 0;
            try
            {
                var lines = System.IO.File.ReadLines(rep, Encoding.UTF8).Take(60).ToList();
                var count = lines.Select(l => Regex.Match(l, @"^Problems found: (\d+)")).FirstOrDefault(x => x.Success);
                return count != null ? int.Parse(count.Groups[1].Value, CultureInfo.InvariantCulture)
                                     : lines.Count(l => l.StartsWith("  [!] ", StringComparison.Ordinal));
            }
            catch { return 0; }
        }

        // The Report.txt of the last DynALisp Report <date> folder of %TEMP% (Dyl-Diagnostics):
        static string LastReport()
        {
            try
            {
                return Directory.GetDirectories(Path.GetTempPath(), "DynALisp Report *")
                    .OrderByDescending(d => d, StringComparer.Ordinal)
                    .Select(d => Path.Combine(d, "Report.txt"))
                    .FirstOrDefault(System.IO.File.Exists);
            }
            catch { return null; }
        }

        internal static string When(DateTime t)
        {
            if (t.Date == DateTime.Today) return "today " + t.ToString("HH:mm", CultureInfo.InvariantCulture);
            if (t.Date == DateTime.Today.AddDays(-1)) return "yesterday " + t.ToString("HH:mm", CultureInfo.InvariantCulture);
            return t.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        }

        // ---- the recent drawings ----

        // The rows of the page, read on another thread (a drawing on a network drive can be
        // slow to answer), then given to it: the drawings of the Recent File List of AutoCAD
        // (File1, File2... of the key of the product, then of the profile) with their dates and
        // pictures, the active time kept (with the time not written yet) and the pins:
        static void ReadRows()
        {
            if (_reading) { _readAgain = true; return; }
            string root = HostApplicationServices.Current.UserRegistryProductRootKey;
            string profile = "";
            try { profile = AcApp.GetSystemVariable("CPROFILE") as string ?? ""; } catch { }
            var pending = Activity.Pending();
            var pins = Activity.Pins();
            _reading = true;
            _readAgain = false;
            var disp = Dispatcher.CurrentDispatcher;
            Task.Run(() =>
            {
                List<string[]> rec = null, act = null, pin = null;
                string err = null;
                try { rec = Recent(root, profile); }
                catch (System.Exception e) { err = "recent drawings: " + e.Message; }
                try { act = Activity.Rows(pending); pin = PinRows(pins, act); }
                catch (System.Exception e) { err = "active time: " + e.Message; }
                disp.BeginInvoke(new Action(() =>
                {
                    _reading = false;
                    if (err != null) _fail = err;
                    if (_s != null && _view != null)
                    {
                        if (rec != null) _s.Rows["rec" + StartUi.RowsSuffix] = rec;
                        if (act != null) _s.Rows["act" + StartUi.RowsSuffix] = act;
                        if (pin != null) _s.Rows["pin" + StartUi.RowsSuffix] = pin;
                        _view.Fill();
                    }
                    if (_readAgain) ReadRows();
                }));
            });
        }

        // The cards of the pins: path, name, kind, folder, its active time in the last year (a
        // sheet set or a project: the drawings of its folder and the folders under it),
        // thumbnail, missing:
        static List<string[]> PinRows(List<string> pins, List<string[]> act)
        {
            string from = DateTime.Today.AddDays(-364).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            string cache = Path.Combine(Path.GetTempPath(), "DynALisp Start");
            var rows = new List<string[]>();
            foreach (var p in pins)
            {
                string kind = Kind(p);
                string dir = Path.GetDirectoryName(p) ?? "";
                string under = dir.TrimEnd('\\') + "\\";
                double s = act.Where(r => string.CompareOrdinal(r[0], from) >= 0
                                          && (kind == "Drawing" ? string.Equals(r[2], p, StringComparison.OrdinalIgnoreCase) : r[2].StartsWith(under, StringComparison.OrdinalIgnoreCase)))
                              .Sum(r => double.Parse(r[1], CultureInfo.InvariantCulture));
                bool there = false;
                DateTime t = DateTime.MinValue;
                long size = 0;
                try { var fi = new FileInfo(p); there = fi.Exists; if (there) { t = fi.LastWriteTime; size = fi.Length; } } catch { }
                string thumb = "";
                if (there && kind == "Drawing") try { thumb = Thumbnail(p, t, size, cache) ?? ""; } catch { }
                rows.Add(new[]
                {
                    p, Path.GetFileNameWithoutExtension(p), kind, dir,
                    s > 0 ? StartUi.Dur(s) + " of active time in the last year" : "No active time in the last year",
                    thumb, there ? "" : "1",
                });
            }
            return rows;
        }

        static List<string> RecentFiles(string root, string profile)
        {
            var files = new List<string>();
            foreach (var key in new[] { root + @"\Recent File List", root + @"\Profiles\" + profile + @"\Recent File List" })
            {
                using (var k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(key))
                {
                    if (k == null) continue;
                    var names = k.GetValueNames()
                        .Select(n => new { n, m = Regex.Match(n, @"^File(\d+)$", RegexOptions.IgnoreCase) })
                        .Where(x => x.m.Success)
                        .OrderBy(x => int.Parse(x.m.Groups[1].Value, CultureInfo.InvariantCulture));
                    int before = files.Count;
                    foreach (var x in names)
                        if (k.GetValue(x.n) is string f && f.Length > 0 && !files.Contains(f, StringComparer.OrdinalIgnoreCase)) files.Add(f);
                    if (files.Count > before && _recentKey == null) _recentKey = key;
                }
            }
            return files;
        }

        static List<string[]> Recent(string root, string profile)
        {
            var rows = new List<string[]>();
            var files = RecentFiles(root, profile).Take(48).ToList();
            _recentCount = files.Count;
            string cache = Path.Combine(Path.GetTempPath(), "DynALisp Start");
            foreach (var f in files)
            {
                bool there = false;
                DateTime t = DateTime.MinValue;
                long size = 0;
                try { var fi = new FileInfo(f); there = fi.Exists; if (there) { t = fi.LastWriteTime; size = fi.Length; } } catch { }
                string thumb = "";
                if (there) try { thumb = Thumbnail(f, t, size, cache) ?? ""; } catch { }
                rows.Add(new[]
                {
                    f, Path.GetFileNameWithoutExtension(f), Path.GetDirectoryName(f) ?? "",
                    there ? When(t) : "", thumb, there ? "" : "1",
                });
            }
            return rows;
        }

        // The picture a drawing keeps of itself (its preview, the PNG or the BMP of its header),
        // as a .png of the cache, made once for each date and size of the drawing:
        static string Thumbnail(string dwg, DateTime t, long size, string cache)
        {
            string ext = Path.GetExtension(dwg).ToLowerInvariant();
            if (ext != ".dwg" && ext != ".dwt" && ext != ".dws") return null;
            string key;
            using (var sha = System.Security.Cryptography.SHA1.Create())
                key = BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(dwg.ToUpperInvariant() + "|" + t.Ticks + "|" + size))).Replace("-", "").Substring(0, 20);
            string png = Path.Combine(cache, key + ".png");
            if (System.IO.File.Exists(png)) return png;
            string none = Path.Combine(cache, key + ".none");
            if (System.IO.File.Exists(none)) return null;
            Directory.CreateDirectory(cache);
            byte[] bytes = Preview(dwg);
            if (bytes == null) { System.IO.File.WriteAllBytes(none, new byte[0]); return null; }
            System.IO.File.WriteAllBytes(png, bytes);
            return png;
        }

        // The preview of a DWG (R13 and later): the address of its image data at 0x0D, there a
        // sentinel of 16 bytes, the size, the number of entries, then each entry (its code: 2 a
        // BMP without its file header, 6 a PNG; its start and its size). The PNG as it is, the
        // BMP made a PNG. Null when it has none.
        internal static byte[] Preview(string dwg)
        {
            using (var fs = new FileStream(dwg, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (var br = new BinaryReader(fs))
            {
                if (fs.Length < 0x40) return null;
                string ver = Encoding.ASCII.GetString(br.ReadBytes(6));
                if (!ver.StartsWith("AC10", StringComparison.Ordinal)) return null;
                fs.Position = 0x0D;
                long addr = br.ReadInt32();
                if (addr <= 0 || addr + 21 > fs.Length) return null;
                fs.Position = addr + 16;
                br.ReadInt32();
                int count = br.ReadByte();
                long bmpAt = 0, pngAt = 0;
                int bmpSize = 0, pngSize = 0;
                for (int i = 0; i < count && i < 8; i++)
                {
                    int code = br.ReadByte();
                    int start = br.ReadInt32(), len = br.ReadInt32();
                    if (code == 2) { bmpAt = start; bmpSize = len; }
                    else if (code == 6) { pngAt = start; pngSize = len; }
                }
                const int Max = 8 << 20;
                if (pngAt > 0 && pngSize > 8 && pngSize < Max && pngAt + pngSize <= fs.Length)
                {
                    fs.Position = pngAt;
                    var png = br.ReadBytes(pngSize);
                    if (png.Length > 4 && png[1] == 'P' && png[2] == 'N' && png[3] == 'G') return png;
                }
                if (bmpAt > 0 && bmpSize > 40 && bmpSize < Max && bmpAt + bmpSize <= fs.Length)
                {
                    fs.Position = bmpAt;
                    return BmpToPng(br.ReadBytes(bmpSize));
                }
                return null;
            }
        }

        static byte[] BmpToPng(byte[] dib)
        {
            int hdr = BitConverter.ToInt32(dib, 0);
            if (hdr < 12 || hdr > dib.Length) return null;
            int bits = hdr >= 16 ? BitConverter.ToInt16(dib, 14) : 24;
            int used = hdr >= 36 ? BitConverter.ToInt32(dib, 32) : 0;
            int colors = used > 0 ? used : bits <= 8 ? 1 << bits : 0;
            int offset = 14 + hdr + colors * 4;
            var file = new byte[14 + dib.Length];
            file[0] = (byte)'B'; file[1] = (byte)'M';
            BitConverter.GetBytes(file.Length).CopyTo(file, 2);
            BitConverter.GetBytes(offset).CopyTo(file, 10);
            dib.CopyTo(file, 14);
            var dec = new BmpBitmapDecoder(new MemoryStream(file), BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
            var enc = new PngBitmapEncoder();
            enc.Frames.Add(BitmapFrame.Create(dec.Frames[0]));
            using (var ms = new MemoryStream())
            {
                enc.Save(ms);
                return ms.ToArray();
            }
        }

        // ---- DynALisp and AutoCAD ----

        // The folder of DynALisp.bundle: up from this DLL (Contents\Resources, or its Net10) to
        // the folder of PackageContents.xml:
        static string _root;
        internal static string Root()
        {
            if (_root != null) return _root;
            for (var d = new DirectoryInfo(Path.GetDirectoryName(typeof(StartPage).Assembly.Location) ?? "."); d != null; d = d.Parent)
                if (System.IO.File.Exists(Path.Combine(d.FullName, "PackageContents.xml"))) return _root = d.FullName;
            return _root = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(typeof(StartPage).Assembly.Location) ?? ".", "..", ".."));
        }

        // The AppVersion of PackageContents.xml:
        static string Version()
        {
            try
            {
                var m = Regex.Match(System.IO.File.ReadAllText(Path.Combine(Root(), "PackageContents.xml")), "AppVersion=\"([^\"]+)\"");
                return m.Success ? m.Groups[1].Value : "?";
            }
            catch { return "?"; }
        }

        static string Product()
        {
            string name = null;
            try
            {
                using (var k = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(HostApplicationServices.Current.MachineRegistryProductRootKey))
                    name = k?.GetValue("ProductName") as string;
            }
            catch { }
            return string.IsNullOrEmpty(name) ? "AutoCAD " + AcApp.Version.ToString(2) : name;
        }

        // The page of the docs website (in the language of DynALisp when it has it), as
        // Dyl:DocsTarget of dynalisp.mnl finds it; the file of a git clone when the website
        // does not list it:
        static string DocsTarget()
        {
            const string Web = "https://samagior.github.io/DynALisp.docs/";
            string rel = "Dynalisp/" + Docs.Replace('\\', '/');
            string fr = rel.Substring(0, rel.Length - 4) + ".fr.htm";
            string lang = Env("DynalispLanguage");
            bool french = string.IsNullOrEmpty(lang)
                ? HostApplicationServices.Current.UserRegistryProductRootKey.EndsWith(":40C", StringComparison.OrdinalIgnoreCase)
                : lang == "French";
            List<string> pages;
            try { pages = System.IO.File.ReadAllLines(Path.Combine(Root(), "Contents", "Resources", "DocsPages.txt")).Select(l => l.Split('\t')[0].Trim()).ToList(); }
            catch { pages = new List<string>(); }
            if (french && pages.Contains(fr, StringComparer.OrdinalIgnoreCase)) return Web + fr;
            if (pages.Contains(rel, StringComparer.OrdinalIgnoreCase)) return Web + rel;
            string local = Path.Combine(Root(), "Contents", "Modules", "Dynalisp", "Docs", Docs);
            return System.IO.File.Exists(local) ? local : Web;
        }

        // A user setting (getenv: the FixedProfile\General key of the profile):
        internal static string Env(string name)
        {
            try
            {
                using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(HostApplicationServices.Current.UserRegistryProductRootKey + @"\FixedProfile\General"))
                    return key?.GetValue(name) as string;
            }
            catch { return null; }
        }

        static bool On() => Env(Setting) == "1";

        static bool Dark()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("COLORTHEME")) == 0; }
            catch { return false; }
        }

        // ---- what was found, for (Dyl:StartPage) ----

        internal static List<string> Report()
        {
            var r = new List<string>
            {
                "setting: " + (On() ? "on" : "off"),
                "found: " + (_found ?? "not looked for yet"),
                "page: " + (_src != null ? (IsWindowVisible(_frame) ? "shown" : "made, the Start tab hidden") : "not made"),
            };
            try { r.Add("STARTMODE: " + AcApp.GetSystemVariable("STARTMODE")); } catch { }
            if (_recentCount >= 0) r.Add("recent drawings: " + _recentCount + (_recentKey != null ? " (" + _recentKey + ")" : ""));
            if (_fail != null) r.Add("error: " + _fail);
            return r;
        }

        // The windows of the MDIClient of AutoCAD, and the chain of each browser window up to
        // the main window, into %TEMP%\DynALisp Diagnostics\Start page.txt: "<file> (<n> lines)".
        internal static string Tree()
        {
            var lines = new List<string>();
            IntPtr main = Bridge.MainWindow();
            lines.Add("main " + Describe(main));
            IntPtr mdi = Children(main).FirstOrDefault(h => Class(h) == "MDIClient");
            if (mdi == IntPtr.Zero) lines.Add("no MDIClient");
            else Walk(mdi, 0, lines);
            foreach (var b in Children(main).Where(IsBrowser))
            {
                var chain = new List<string>();
                for (IntPtr p = b; p != IntPtr.Zero && chain.Count < 12; p = GetParent(p)) chain.Add(Class(p));
                lines.Add("browser " + Describe(b) + ": " + string.Join(" < ", chain));
            }
            string dir = Path.Combine(Path.GetTempPath(), "DynALisp Diagnostics");
            Directory.CreateDirectory(dir);
            string file = Path.Combine(dir, "Start page.txt");
            System.IO.File.WriteAllLines(file, lines, Encoding.UTF8);
            return file + " (" + lines.Count + " lines)";
        }

        static void Walk(IntPtr h, int depth, List<string> lines)
        {
            lines.Add(new string(' ', depth * 2) + Describe(h));
            if (depth >= 6 || lines.Count > 400) return;
            foreach (var c in Children(h).Where(c => GetParent(c) == h)) Walk(c, depth + 1, lines);
        }

        static string Describe(IntPtr h)
        {
            GetWindowRect(h, out RECT r);
            return Class(h) + " " + (IsWindowVisible(h) ? "shown" : "hidden") + " " + (r.Right - r.Left) + "x" + (r.Bottom - r.Top)
                   + (h == _src?.Handle ? " (the page of DynALisp)" : "");
        }

        // ---- Win32 ----

        const int WS_CHILD = 0x40000000, WS_VISIBLE = 0x10000000, WS_CLIPCHILDREN = 0x02000000, WS_CLIPSIBLINGS = 0x04000000;
        const int SW_HIDE = 0, SW_SHOW = 5, GW_CHILD = 5;
        const uint SWP_NOACTIVATE = 0x0010, SWP_SHOWWINDOW = 0x0040;
        static readonly IntPtr HWND_TOP = IntPtr.Zero;

        [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
        delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr lParam);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
        [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr hwnd);
        [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, int cmd);
        [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hwnd, int cmd);
        [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out RECT r);
        [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
        [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int w, int h, uint flags);

        static List<IntPtr> Children(IntPtr parent)
        {
            var all = new List<IntPtr>();
            if (parent == IntPtr.Zero) return all;
            EnumChildWindows(parent, (h, _) => { all.Add(h); return true; }, IntPtr.Zero);
            return all;
        }

        static string Class(IntPtr h)
        {
            var sb = new StringBuilder(256);
            GetClassName(h, sb, sb.Capacity);
            return sb.ToString();
        }
    }

    // The startup of DynALisp in the last drawing opened, given by the Lisp:
    sealed class StartupInfo
    {
        public int Ms, Commands, Aliases;
        public string Drawing = "";
        public DateTime Time;
        public bool Earlier;
        public readonly List<string> Warnings = new List<string>(), Errors = new List<string>();
        public readonly List<KeyValuePair<string, int>> Steps = new List<KeyValuePair<string, int>>();
    }

    public class StartPageLisp
    {
        internal static StartupInfo Last;

        static string LastFile => Path.Combine(Path.GetTempPath(), "DynALisp Diagnostics", "Last startup.txt");

        // (Dyl:StartPage): what the Start page found, a line each (Dyl-Diagnostics, Interface);
        // (Dyl:StartPage "Tree"): the windows around the browsers written to a file, its name
        // and its number of lines; (Dyl:StartPage "Apply"): the setting read again at once
        // (Dyl-Settings saved).
        [LispFunction("Dyl:StartPage")]
        public object Report(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                string what = a.Count > 0 ? a[0] as string : null;
                if (string.Equals(what, "Tree", StringComparison.OrdinalIgnoreCase)) return StartPage.Tree();
                if (string.Equals(what, "Apply", StringComparison.OrdinalIgnoreCase)) { StartPage.Apply(); return true; }
                var rb = new ResultBuffer();
                rb.Add(new TypedValue((int)LispDataType.ListBegin));
                foreach (var l in StartPage.Report()) rb.Add(new TypedValue((int)LispDataType.Text, l));
                rb.Add(new TypedValue((int)LispDataType.ListEnd));
                return rb;
            }
            catch (System.Exception e) { return "error: " + e.Message; }
        }

        // (Dyl:StartPageInfo ms commands aliases warnings errors steps drawing), at the end of
        // the startup of DynALisp (Dyl:StartupSummary): its time, its warnings, the files that
        // did not load and the time of each step ((name . ms) ...), kept for the Start page
        // and written for the next session.
        [LispFunction("Dyl:StartPageInfo")]
        public object Info(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                object At(int i) => i < a.Count ? a[i] : null;
                int Int(object o) => o is short s ? s : o is int i ? i : o is double d ? (int)d : 0;
                IEnumerable<object> Items(object o) => o is Lisp.List l ? l : Enumerable.Empty<object>();
                var info = new StartupInfo
                {
                    Ms = Int(At(0)), Commands = Int(At(1)), Aliases = Int(At(2)),
                    Drawing = At(6) as string ?? "", Time = DateTime.Now,
                };
                info.Warnings.AddRange(Items(At(3)).OfType<string>());
                info.Errors.AddRange(Items(At(4)).OfType<string>());
                foreach (var s in Items(At(5)).OfType<Lisp.List>())
                    if (s.Count >= 2 && s[0] is string n) info.Steps.Add(new KeyValuePair<string, int>(n, Int(s[1])));
                Last = info;
                Write(info);
                return true;
            }
            catch { return null; }
        }

        static void Write(StartupInfo i)
        {
            try
            {
                var lines = new List<string>
                {
                    "ms=" + i.Ms, "commands=" + i.Commands, "aliases=" + i.Aliases, "drawing=" + i.Drawing,
                    "time=" + i.Time.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture),
                };
                lines.AddRange(i.Warnings.Select(w => "warning=" + w.Replace("\n", " ")));
                lines.AddRange(i.Errors.Select(e => "error=" + e.Replace("\n", " ")));
                lines.AddRange(i.Steps.Select(s => "step=" + s.Key + "\t" + s.Value.ToString(CultureInfo.InvariantCulture)));
                Directory.CreateDirectory(Path.GetDirectoryName(LastFile));
                System.IO.File.WriteAllLines(LastFile, lines, Encoding.UTF8);
            }
            catch { }
        }

        // The startup written by an earlier session, null when there is none:
        internal static StartupInfo ReadLast()
        {
            try
            {
                if (!System.IO.File.Exists(LastFile)) return null;
                var i = new StartupInfo { Earlier = true };
                foreach (var l in System.IO.File.ReadAllLines(LastFile, Encoding.UTF8))
                {
                    int eq = l.IndexOf('=');
                    if (eq < 1) continue;
                    string k = l.Substring(0, eq), v = l.Substring(eq + 1);
                    int.TryParse(v, NumberStyles.Integer, CultureInfo.InvariantCulture, out int n);
                    switch (k)
                    {
                        case "ms": i.Ms = n; break;
                        case "commands": i.Commands = n; break;
                        case "aliases": i.Aliases = n; break;
                        case "drawing": i.Drawing = v; break;
                        case "time": DateTime.TryParseExact(v, "yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out i.Time); break;
                        case "warning": i.Warnings.Add(v); break;
                        case "error": i.Errors.Add(v); break;
                        case "step":
                            var p = v.Split('\t');
                            if (p.Length == 2 && int.TryParse(p[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out int ms)) i.Steps.Add(new KeyValuePair<string, int>(p[0], ms));
                            break;
                    }
                }
                return i;
            }
            catch { return null; }
        }
    }
}
