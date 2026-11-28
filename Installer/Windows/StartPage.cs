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
// itself) in its middle; New, Open and the templates at its left; the tasks of the projects
// pinned at its right (Tasks.cs), and Report a problem; a line at its foot on DynALisp (its
// version, its startup, the problems found).
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
// for the next session. Settings runs its command in a drawing open, in a new drawing while
// none is (the window of the Lisp needs one). Report a problem asks only what happened: the
// report of Dyl-Diagnostics is made in a drawing open (the last one made while none is), then
// the new issue page of DynALisp.bundle opens with it, its zip on the clipboard to paste.

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
            if (_view.Find("new") is Button nw) nw.Click += (a, b) => Do(() => New(null));
            if (_view.Find("opn") is Button op) op.Click += (a, b) => Do(OpenAsk);
            if (_view.Find("osh") is Button os) os.Click += (a, b) => Do(OpenSheetSetAsk);
            if (_view.Find("set") is Button st) st.Click += (a, b) => Do(Settings);
            if (_view.Find("rep") is Button rp) rp.Click += (a, b) => Do(() => ReportPanel(true));
            if (_view.Find("rno") is Button rn) rn.Click += (a, b) => Do(() => ReportPanel(false));
            if (_view.Find("rgo") is Button rg) rg.Click += (a, b) => Do(ReportGo);
            if (_view.Find("tpl") is TemplateList tpl)
            {
                tpl.New += f => Do(() => New(f));
                tpl.Browse += () => Do(BrowseTemplates);
            }
            if (_view.Find("tsk") is ProjectTasks tsk)
            {
                tsk.Added += (pj, t) => Do(() => { ProjectTasksFile.Add(pj, t); ReadRows(); });
                tsk.Checked += (pj, id, on) => Do(() => { ProjectTasksFile.Check(pj, id, on); ReadRows(); });
                tsk.Removed += (pj, id) => Do(() => { ProjectTasksFile.Remove(pj, id); ReadRows(); });
            }
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
            if (dst != null) r.Add(("Pin sheet set " + SheetTitle(dst), dst, Activity.Pinned(dst)));
            if (apj != null) r.Add(("Pin project " + Path.GetFileNameWithoutExtension(apj), apj, Activity.Pinned(apj)));
            return r;
        }

        // The title of a sheet set (the name the Sheet Set Manager shows, not the name of its
        // file), kept with the date of the file: read again only once it changed. Its file name
        // when it cannot be read. On the thread of AutoCAD (the manager is a COM object of it).
        static readonly Dictionary<string, (DateTime Stamp, string Title)> _titles =
            new Dictionary<string, (DateTime, string)>(StringComparer.OrdinalIgnoreCase);

        static string SheetTitle(string dst)
        {
            DateTime t = DateTime.MinValue;
            try { if (System.IO.File.Exists(dst)) t = System.IO.File.GetLastWriteTimeUtc(dst); } catch { }
            if (_titles.TryGetValue(dst, out var c) && c.Stamp == t) return c.Title;
            string title = null;
            if (t != DateTime.MinValue) try { title = DynALisp.Startup.SheetSetMgr.TitleOf(dst); } catch { }
            if (string.IsNullOrWhiteSpace(title)) title = Path.GetFileNameWithoutExtension(dst);
            _titles[dst] = (t, title.Trim());
            return title.Trim();
        }

        // The name shown of a pin: the title of a sheet set, else the name of its file:
        static string NameOf(string pin, Dictionary<string, string> titles) =>
            titles != null && titles.TryGetValue(pin, out var n) ? n : Path.GetFileNameWithoutExtension(pin);

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
            var doc = Drawing() ?? New(null);
            if (doc == null) return;
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
        static Document New(string template)
        {
            string t = string.IsNullOrEmpty(template) ? QNew() : template;
            if (string.IsNullOrEmpty(t) || !System.IO.File.Exists(t))
            {
                int mi = 0;
                try { mi = Convert.ToInt32(AcApp.GetSystemVariable("MEASUREINIT")); } catch { }
                t = mi == 1 ? "acadiso.dwt" : "acad.dwt";
            }
            return AcApp.DocumentManager.Add(t);
        }

        static string QNew()
        {
            try { dynamic prefs = AcApp.Preferences; return (string)prefs.Files.QNewTemplateFile; } catch { return ""; }
        }

        static string TemplateFolder()
        {
            try { dynamic prefs = AcApp.Preferences; return (string)prefs.Files.TemplateDwgPath; } catch { return ""; }
        }

        static void BrowseTemplates()
        {
            var dlg = new Microsoft.Win32.OpenFileDialog { Title = "New", Filter = "Templates (*.dwt)|*.dwt|Drawings (*.dwg)|*.dwg" };
            string dir = TemplateFolder();
            if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir)) dlg.InitialDirectory = dir;
            if (dlg.ShowDialog() == true) New(dlg.FileName);
        }

        static void OpenSheetSetAsk()
        {
            var dlg = new Microsoft.Win32.OpenFileDialog { Title = "Open sheet set", Filter = "Sheet sets (*.dst)|*.dst" };
            if (dlg.ShowDialog() == true) OpenSheetSet(dlg.FileName);
        }

        // Dyl-Settings, in a new drawing while none is open (its window is made by the Lisp,
        // which runs only in a drawing):
        static void Settings()
        {
            var doc = Drawing() ?? New(null);
            if (doc == null) return;
            AcApp.DocumentManager.MdiActiveDocument = doc;
            doc.SendStringToExecute("Dyl-Settings\n", true, false, false);
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
            if (!System.IO.File.Exists(file)) { Say("Not found: " + System.IO.Path.GetFileName(file)); return; }
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
                else Say("Not found: " + System.IO.Path.GetFileName((dir ?? file).TrimEnd('\\', '/')));
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
            foreach (var key in new[] { "set", "rep" })
                if (_view?.Find(key) is Button b) b.IsEnabled = !_s.Off.Contains(key);
            // a note without text takes no room:
            foreach (var key in new[] { "actn", "err" })
                if (_view?.Find(key) is TextBlock t) t.Visibility = string.IsNullOrEmpty(t.Text) ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible;
        }

        static void Values(Session s)
        {
            s.Values["ver"] = Foot();
            s.Values["actn"] = Env(Activity.Setting) == "1" ? "" : "Active time is off: turn it on in Settings, under Start page.";
            s.Values[Session.DocsKey(Docs)] = DocsHome();
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
            string tdir = TemplateFolder(), qnew = QNew();
            var titles = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in pins)
                if (string.Equals(Path.GetExtension(p), ".dst", StringComparison.OrdinalIgnoreCase)) titles[p] = SheetTitle(p);
            _reading = true;
            _readAgain = false;
            var disp = Dispatcher.CurrentDispatcher;
            Task.Run(() =>
            {
                List<string[]> rec = null, act = null, pin = null, tpl = null, tsk = null;
                string err = null;
                try { tpl = Templates(tdir, qnew); } catch { tpl = new List<string[]>(); }
                try { tsk = TaskRows(pins, titles); } catch (System.Exception e) { err = "tasks: " + e.Message; }
                try { rec = Recent(root, profile); }
                catch (System.Exception e) { err = "recent drawings: " + e.Message; }
                try { act = Activity.Rows(pending); pin = PinRows(pins, act, titles); }
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
                        if (tpl != null) _s.Rows["tpl" + StartUi.RowsSuffix] = tpl;
                        if (tsk != null) _s.Rows["tsk" + StartUi.RowsSuffix] = tsk;
                        _view.Fill();
                    }
                    if (_readAgain) ReadRows();
                }));
            });
        }

        // The templates of the template folder of AutoCAD (Files of Options), the one of QNEW
        // first (marked default, wherever it is), then the others by name, 12 at most:
        static List<string[]> Templates(string dir, string qnew)
        {
            var rows = new List<string[]>();
            if (!string.IsNullOrEmpty(qnew) && System.IO.File.Exists(qnew))
                rows.Add(new[] { qnew, Path.GetFileNameWithoutExtension(qnew), "1" });
            if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir))
                foreach (var f in Directory.GetFiles(dir, "*.dwt").OrderBy(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase))
                    if (rows.Count < 12 && !string.Equals(f, qnew, StringComparison.OrdinalIgnoreCase))
                        rows.Add(new[] { f, Path.GetFileNameWithoutExtension(f), "" });
            return rows;
        }

        // The tasks of the projects and sheet sets pinned: project, name, kind, id, done, text,
        // error (a row without id for a project without a task):
        static List<string[]> TaskRows(List<string> pins, Dictionary<string, string> titles)
        {
            var rows = new List<string[]>();
            foreach (var p in pins)
            {
                string kind = Kind(p);
                if (kind == "Drawing") continue;
                string name = NameOf(p, titles);
                List<ProjectTasksFile.Item> items;
                string err = "";
                try { items = ProjectTasksFile.Read(p); }
                catch (System.Exception e) { items = new List<ProjectTasksFile.Item>(); err = "Tasks not read: " + e.Message; }
                if (items.Count == 0) rows.Add(new[] { p, name, kind, "", "", "", err });
                foreach (var t in items) rows.Add(new[] { p, name, kind, t.Id, t.Done ? "1" : "", t.Text, err });
            }
            return rows;
        }

        // ---- report a problem ----

        const string IssueRepo = "samagior/DynALisp.bundle";   // *dyl:gitrepo* of dynalisp.mnl
        static string _issueText;

        static void ReportPanel(bool show)
        {
            if (_view?.Find("rpp") is FrameworkElement p) p.Visibility = show ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed;
            ReportSay("");
            if (show && _view?.Find("rtx") is TextBox t) t.Focus();
        }

        static void ReportSay(string msg)
        {
            if (_view?.Find("rst") is TextBlock t) t.Text = msg ?? "";
        }

        // What happened, kept; the report made in a drawing open, which gives it back by
        // (Dyl:StartPageIssue report zip): the issue opened then. While no drawing is open, or
        // Dyl-Diagnostics is turned off, the last report made.
        static void ReportGo()
        {
            string text = (_view?.Find("rtx") as TextBox)?.Text?.Trim() ?? "";
            if (text.Length == 0) { ReportSay("Describe the problem first."); return; }
            _issueText = text;
            var doc = Drawing();
            if (doc == null) { Issue(null, null); return; }
            ReportSay("Making the report...");
            AcApp.DocumentManager.MdiActiveDocument = doc;
            doc.SendStringToExecute("(if c:Dyl-Diagnostics (progn (setq *dg:forissue* T) (c:Dyl-Diagnostics)) (if Dyl:StartPageIssue (Dyl:StartPageIssue nil nil)))\n", true, false, false);
        }

        // The new issue page of DynALisp.bundle, filled in: what happened, a summary, the
        // problems found and as much of the report as a link holds (the whole of it is in its
        // zip, put on the clipboard: Ctrl+V in the issue attaches it).
        internal static void Issue(string rep, string zip)
        {
            bool fresh = rep != null;
            if (rep == null)
            {
                rep = LastReport();
                if (rep != null)
                {
                    string z = Path.GetDirectoryName(rep) + ".zip";
                    zip = System.IO.File.Exists(z) ? z : null;
                }
            }
            string text = _issueText ?? "";
            var lines = new List<string>();
            try { if (rep != null) lines = System.IO.File.ReadAllLines(rep, Encoding.UTF8).ToList(); } catch { }
            var probs = lines.Where(l => l.StartsWith("  [!] ", StringComparison.Ordinal)).Select(l => l.Substring(6)).ToList();
            var head = new StringBuilder();
            head.Append("**What happened:**\n\n").Append(text).Append("\n\n");
            if (zip != null) head.Append("**Report:** `").Append(Path.GetFileName(zip)).Append("` is on the clipboard: paste it here (Ctrl+V) to attach it.\n\n");
            head.Append("### Summary\n- DynALisp ").Append(Version()).Append("\n- ").Append(Product()).Append(", .NET ").Append(Environment.Version.ToString(2)).Append('\n');
            if (rep == null) head.Append("- No report of Dyl-Diagnostics yet\n");
            else if (!fresh) head.Append("- The last report of Dyl-Diagnostics (no drawing was open): ").Append(Path.GetFileName(Path.GetDirectoryName(rep))).Append('\n');
            var probText = new StringBuilder("\n### Problems found (" + probs.Count + ")\n");
            foreach (var p in probs.Take(15)) probText.Append("- ").Append(p).Append('\n');
            if (probs.Count > 15) probText.Append("- ... (").Append(probs.Count - 15).Append(" more in the report)\n");
            string title = "Problem: " + (text.Split('\n')[0].Trim() is string t1 && t1.Length > 60 ? t1.Substring(0, 57) + "..." : text.Split('\n')[0].Trim());
            // as many lines of the report as the link holds (GitHub refuses a link much longer):
            int keep = lines.Count;
            string url;
            while (true)
            {
                var body = new StringBuilder(head.ToString()).Append(probText);
                if (keep > 0)
                {
                    body.Append("\n<details><summary>Report").Append(keep < lines.Count ? " (its beginning: the whole of it is in the zip)" : "").Append("</summary>\n\n```\n");
                    foreach (var l in lines.Take(keep)) body.Append(l).Append('\n');
                    body.Append("```\n</details>\n");
                }
                url = "https://github.com/" + IssueRepo + "/issues/new?title=" + Uri.EscapeDataString(title) + "&body=" + Uri.EscapeDataString(body.ToString());
                if (url.Length <= 7500 || keep == 0) break;
                keep = Math.Max(0, Math.Min(keep - 5, (int)(keep * 7500.0 / url.Length)));
            }
            if (zip != null)
                try { System.Windows.Clipboard.SetFileDropList(new System.Collections.Specialized.StringCollection { zip }); } catch { }
            Shell(url);
            if (_view?.Find("rtx") is TextBox tb) tb.Text = "";
            ReportPanel(false);
            Say(zip != null ? "Issue opened in your browser: paste the report (Ctrl+V), check it, then Submit." : "Issue opened in your browser: check it, then Submit.");
        }

        // The cards of the pins: path, name, kind, folder, its active time in the last year (a
        // sheet set or a project: the drawings of its folder and the folders under it),
        // thumbnail, missing:
        static List<string[]> PinRows(List<string> pins, List<string[]> act, Dictionary<string, string> titles)
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
                    p, NameOf(p, titles), kind, dir,
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

        // The home page of the User Guide on the docs website, in French when DynALisp is:
        static string DocsHome()
        {
            const string Web = "https://samagior.github.io/DynALisp.docs/";
            string lang = Env("DynalispLanguage");
            bool french = string.IsNullOrEmpty(lang)
                ? HostApplicationServices.Current.UserRegistryProductRootKey.EndsWith(":40C", StringComparison.OrdinalIgnoreCase)
                : lang == "French";
            return Web + (french ? "index.fr.html" : "");
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

        // (Dyl:StartPageIssue report zip): the report Dyl-Diagnostics just made for Report a
        // problem of the Start page (nil: none could be made), the issue opened with it.
        [LispFunction("Dyl:StartPageIssue")]
        public object Issue(ResultBuffer args)
        {
            try
            {
                var a = Lisp.Read(args);
                StartPage.Issue(a.Count > 0 ? a[0] as string : null, a.Count > 1 ? a[1] as string : null);
                return true;
            }
            catch (System.Exception e) { return "error: " + e.Message; }
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
