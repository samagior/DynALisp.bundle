// Program.cs - DynALisp.Windows.Shots: the pictures of the windows for the docs, without AutoCAD
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
//   dotnet run -c Release                 every window of Shots.csv
//   dotnet run -c Release -- Dyl-Settings  the rows whose window or picture has that text
//   ... -- -out <folder>                  the pictures in that folder (GitHub Actions)
//   ... -- -fit                           no pictures: shows each window on the screen as
//                                         AutoCAD does (Engine\Fit.cs), smallest, larger,
//                                         maximized and opened again, and prints its sizes
//                                         and those of its lists (the Windows workflow)
//   ... -- -fit -trace <window>           the same, with each step of the fit of its lists
//
// Each row of Shots.csv (Window;Sample;Picture[;Section[;Rows]], paths from the root of the
// repository) is a window file opened as the plugin opens it (Session.Open: the same engine, the same theme),
// on the values of its sample file (Samples\, as the Lisp gives them: key=value,
// key/list=item|item, key/vals=value|value, key/off=1, +key=field\\tfield a row of the table
// key (the presets of a preset window: +pst/rows=...); {samples} the folder of the samples,
// \\t a tab, \\T a tab inside a field of a row, \\n a new line), its Open Docs
// button enabled. Its content is drawn without the title bar of the window and without a frame,
// at twice its size (192 dpi, shown at its true size by the website), into the PNG its docs
// page names (<!-- picture: images/<Page>-window.png -->), in DynALisp Dark,
// the default look of DynALisp (the dark theme of AutoCAD, in its neutral greys): one picture
// for every page, in light mode as in dark mode. Nothing is shown on the screen.
//
// A large window of several sections gets a picture per section, its page describing each one
// in a section of its own: the Section column names the part of the window drawn, the rest cut
// away (a margin of the window around it):
//   Presets          the GroupBox of that header, else the element of that x:Name
//   GroupBox:nam     the nearest GroupBox (or any type) that holds the element named nam
//   Presets+Preview  the parts joined, and what lies between them
// and the Rows column, when it has a number, keeps that many rows of each long list of the
// section, the section as high as what it then holds: a list of repeated rows shows what it is
// in a few of them, and the page stays short.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace DynALisp.Windows
{
    static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            string root = Root();
            if (root == null) { Console.Error.WriteLine("PackageContents.xml not found above " + Environment.CurrentDirectory); return 2; }
            string here = Path.Combine(root, "Installer", "Windows", "Shots");
            string outDir = null;
            bool fit = false;
            var only = new List<string>();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-out" && i + 1 < args.Length) outDir = Path.GetFullPath(args[++i]);
                else if (args[i] == "-fit") fit = true;
                else only.Add(args[i]);
            }
            if (fit && only.Contains("-trace")) { only.Remove("-trace"); Fit.Trace = Console.WriteLine; }
            // Every picture in DynALisp Dark (the neutral greys of Theme):
            Theme.LookOf = () => "DynALisp Dark";
            if (fit) Console.WriteLine("Work area " + Sz(SystemParameters.WorkArea.Size) + ", screen " + SystemParameters.PrimaryScreenWidth + "x" + SystemParameters.PrimaryScreenHeight);
            int errors = 0, done = 0;
            foreach (var line in File.ReadAllLines(Path.Combine(here, "Shots.csv")))
            {
                if (line.Trim() == "" || line.TrimStart().StartsWith("#")) continue;
                var f = line.Split(';').Select(x => x.Trim()).ToArray();
                if (f.Length < 3) continue;
                string section = f.Length > 3 ? f[3] : "";
                int rows = f.Length > 4 && int.TryParse(f[4], out var n) ? n : 0;
                if (only.Count > 0 && !only.Any(o => f[0].Contains(o) || f[2].Contains(o))) continue;
                string xaml = Path.Combine(root, f[0]), sample = Path.Combine(here, "Samples", f[1]);
                string png = outDir != null ? Path.Combine(outDir, f[2]) : Path.Combine(root, f[2]);
                if (fit)
                {
                    try { FitCheck(xaml, sample); done++; }
                    catch (Exception e) { Console.Error.WriteLine("--> " + f[0] + ": " + e); errors++; }
                    continue;
                }
                try
                {
                    Shot(xaml, sample, png, true, section, rows);
                    Console.WriteLine("Drawn " + f[2]);
                    done++;
                }
                catch (Exception e)
                {
                    Console.Error.WriteLine("--> " + f[0] + ": " + e);
                    errors++;
                }
            }
            Console.WriteLine(done + " pictures drawn" + (errors > 0 ? ", " + errors + " failed" : "") + ".");
            return errors > 0 ? 1 : 0;
        }

        // ---- -fit: the windows as AutoCAD shows them (Engine\Fit.cs) ----

        sealed class MemPlaces : IPlaces
        {
            readonly Dictionary<string, string> _d = new Dictionary<string, string>();
            public string Get(string name) => _d.TryGetValue(name, out string v) ? v : null;
            public void Set(string name, string value) => _d[name] = value;
            public string First => _d.Keys.FirstOrDefault();
        }

        static void FitCheck(string xaml, string sample)
        {
            Console.WriteLine(Path.GetFileName(xaml) + ":");
            var places = new MemPlaces();
            var s = new Session { FitToScreen = true, Places = places };
            Read(s, sample);
            s.ShowRoot = w =>
            {
                w.Show();
                Pump(500);
                Report("opened", w);
                if (w.ResizeMode == ResizeMode.CanResize)
                {
                    w.Width = w.MinWidth; w.Height = w.MinHeight; Pump(300); Report("smallest", w);
                    w.Width = w.MinWidth + 300; w.Height = w.MinHeight + 250; Pump(300); Report("larger", w);
                    w.WindowState = WindowState.Maximized; Pump(300); Report("maximized", w);
                    w.WindowState = WindowState.Normal; Pump(300);
                }
                w.Close();
                return true;
            };
            s.Show(xaml);
            // (by the name of its file, or the place of its tabs: Dyl-Manager)
            string kept = places.First;
            Console.WriteLine("    place kept: " + (kept != null ? kept + " " + places.Get(kept) : "none"));
            if (kept == null) return;
            s.ShowRoot = w => { w.Show(); Pump(500); Report("reopened", w); w.Close(); return true; };
            s.Show(xaml);
        }

        static string Sz(Size z) => Math.Round(z.Width) + "x" + Math.Round(z.Height);

        static void Report(string label, Window w)
        {
            var sv = w.Content as ScrollViewer;
            var sb = new System.Text.StringBuilder();
            sb.Append("    " + label.PadRight(10) + " window " + Math.Round(w.Left) + "," + Math.Round(w.Top) + " " + Sz(new Size(w.ActualWidth, w.ActualHeight))
                      + " (min " + Sz(new Size(w.MinWidth, w.MinHeight)) + ", " + w.ResizeMode + ")");
            if (sv != null)
            {
                sb.Append(" view " + Sz(new Size(sv.ViewportWidth, sv.ViewportHeight)) + " content " + Sz(new Size(sv.ExtentWidth, sv.ExtentHeight)));
                if (sv.ExtentHeight > sv.ViewportHeight + 1) sb.Append(" SCROLLS-V");
                if (sv.ExtentWidth > sv.ViewportWidth + 1) sb.Append(" SCROLLS-H");
            }
            var lists = new List<string>();
            void Walk(DependencyObject o)
            {
                if ((o is ListBox || o is Gallery) && o is FrameworkElement fe && !string.IsNullOrEmpty(fe.Name))
                    lists.Add(fe.Name + " " + Sz(new Size(fe.ActualWidth, fe.ActualHeight)));
                foreach (var c in LogicalTreeHelper.GetChildren(o)) if (c is DependencyObject d) Walk(d);
            }
            Walk(w);
            if (lists.Count > 0) sb.Append("; " + string.Join(", ", lists));
            Console.WriteLine(sb.ToString());
        }

        static void Pump(int ms)
        {
            var frame = new DispatcherFrame();
            var t = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(ms) };
            t.Tick += (a, b) => { t.Stop(); frame.Continue = false; };
            t.Start();
            Dispatcher.PushFrame(frame);
        }

        // The folder of PackageContents.xml, from the current folder up:
        static string Root()
        {
            for (var d = new DirectoryInfo(Environment.CurrentDirectory); d != null; d = d.Parent)
                if (File.Exists(Path.Combine(d.FullName, "PackageContents.xml"))) return d.FullName;
            return null;
        }

        // The items of a list, divided by |; \| is a | inside an item (a shape of Quick Shape,
        // Library|Block):
        static List<string> Items(string value) =>
            value.Replace("\\|", "\u0001").Split('|').Select(x => x.Replace("\u0001", "|")).ToList();

        // The values of a sample file, as the Lisp gives them:
        static void Read(Session s, string sample)
        {
            if (!File.Exists(sample)) throw new FileNotFoundException("Sample values not found: " + sample);
            foreach (var raw in File.ReadAllLines(sample))
            {
                string line = raw.Trim();
                if (line == "" || line.StartsWith("#")) continue;
                int eq = line.IndexOf('=');
                if (eq < 1) continue;
                string key = line.Substring(0, eq).Trim(), value = line.Substring(eq + 1).Trim();
                // {samples}: the folder of the sample (its .pat files); \t: a tab:
                // (\T: a tab inside a field of a row, as the rows of a column that holds rows:
                // Win.RowsIn)
                value = value.Replace("\\n", "\n").Replace("{samples}", Path.GetDirectoryName(Path.GetFullPath(sample))).Replace("\\t", "\t");
                if (key.EndsWith("/list")) s.Lists[key.Substring(0, key.Length - 5)] = Items(value);
                else if (key.EndsWith("/vals")) s.Lists[key] = Items(value);
                else if (key.StartsWith("+"))
                {
                    string table = key.Substring(1);
                    if (!s.Rows.TryGetValue(table, out var rows)) s.Rows[table] = rows = new List<string[]>();
                    rows.Add(value.Split('\t').Select(f => f.Replace("\\T", "\t")).ToArray());
                }
                else if (key.EndsWith("/off")) { if (value == "1") s.Off.Add(key.Substring(0, key.Length - 4)); }
                else s.Values[key] = value;
            }
        }

        // The part of a window a Section names (see the top of this file):
        static FrameworkElement Part(DependencyObject root, string spec)
        {
            int colon = spec.IndexOf(':');
            string type = colon > 0 ? spec.Substring(0, colon) : null, name = colon > 0 ? spec.Substring(colon + 1) : spec;
            FrameworkElement First(Func<FrameworkElement, bool> match)
            {
                FrameworkElement found = null;
                void Walk(DependencyObject o)
                {
                    if (found != null) return;
                    if (o is FrameworkElement fe && match(fe)) { found = fe; return; }
                    foreach (var c in LogicalTreeHelper.GetChildren(o)) if (c is DependencyObject d) Walk(d);
                }
                Walk(root);
                return found;
            }
            // A header first, then a name:
            var el = (type == null ? First(fe => fe is GroupBox gb && gb.Header is string h && h == name) : null)
                     ?? First(fe => fe.Name == name);
            if (el == null || type == null) return el;
            for (DependencyObject o = el; o != null; o = LogicalTreeHelper.GetParent(o) ?? VisualTreeHelper.GetParent(o))
                if (o.GetType().Name == type && o is FrameworkElement up) return up;
            return null;
        }

        // Every element of a type below root, in the visual tree:
        static IEnumerable<T> Below<T>(DependencyObject root) where T : DependencyObject
        {
            for (int i = 0; i < VisualTreeHelper.GetChildrenCount(root); i++)
            {
                var c = VisualTreeHelper.GetChild(root, i);
                if (c is T t) yield return t;
                foreach (var d in Below<T>(c)) yield return d;
            }
        }

        // The margin of the window kept around a section:
        const double SectionPad = 12;

        static void Shot(string xaml, string sample, string png, bool dark, string section, int rows = 0)
        {
            var s = new Session { Dark = dark };
            Read(s, sample);
            var view = s.Open(xaml);
            var w = view.Window;
            s.Values[Session.DocsKey(Win.GetDocs(w))] = "https://samagior.github.io/DynALisp.docs/";
            view.Fill();

            // The content of the window, without its title bar nor a frame, with the resources and
            // the text settings of the window (its styles, its theme):
            var content = (UIElement)w.Content;
            w.Content = null;
            var frame = new Border
            {
                Child = content,
                UseLayoutRounding = true,
                SnapsToDevicePixels = true,
            };
            TextOptions.SetTextFormattingMode(frame, TextFormattingMode.Ideal);
            frame.Resources = w.Resources;
            TextElement.SetFontFamily(frame, w.FontFamily);
            TextElement.SetFontSize(frame, w.FontSize);
            frame.SetResourceReference(Border.BackgroundProperty, "Dyl.Back");
            frame.SetResourceReference(TextElement.ForegroundProperty, "Dyl.Text");

            frame.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
            frame.Arrange(new Rect(frame.DesiredSize));
            frame.UpdateLayout();
            // the bindings and the templates done:
            Dispatcher.CurrentDispatcher.Invoke(() => { }, DispatcherPriority.ApplicationIdle);
            frame.UpdateLayout();
            if (section != "" && rows > 0)
            {
                // A long list shows its first rows only, the section as high as what it holds:
                foreach (var spec in section.Split('+').Select(x => x.Trim()))
                {
                    var part = Part(frame, spec);
                    if (part == null) continue;
                    foreach (var list in Below<ItemsControl>(part).Where(l => !(l is ComboBox) && !(l is System.Windows.Controls.Primitives.MenuBase) && l.Items.Count > rows))
                    {
                        var first = list.ItemContainerGenerator.ContainerFromIndex(0) as FrameworkElement;
                        if (first == null || first.ActualHeight <= 0) continue;
                        double top = first.TransformToAncestor(list).Transform(new Point(0, 0)).Y;
                        var height = top + rows * first.ActualHeight + Math.Max(top, 2);
                        if (height < list.ActualHeight) list.Height = height;
                    }
                    part.VerticalAlignment = VerticalAlignment.Top;
                }
                frame.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
                frame.Arrange(new Rect(frame.DesiredSize));
                frame.UpdateLayout();
                Dispatcher.CurrentDispatcher.Invoke(() => { }, DispatcherPriority.ApplicationIdle);
                frame.UpdateLayout();
            }

            const double scale = 2;
            var size = frame.RenderSize;
            var bmp = new RenderTargetBitmap((int)Math.Ceiling(size.Width * scale), (int)Math.Ceiling(size.Height * scale), 96 * scale, 96 * scale, PixelFormats.Pbgra32);
            bmp.Render(frame);
            BitmapSource picture = bmp;
            if (section != "")
            {
                // Only the section, with a margin around it:
                Rect? r = null;
                foreach (var spec in section.Split('+').Select(x => x.Trim()))
                {
                    var part = Part(frame, spec) ?? throw new InvalidOperationException("Section not found in " + Path.GetFileName(xaml) + ": " + spec);
                    var b = part.TransformToAncestor(frame).TransformBounds(new Rect(part.RenderSize));
                    r = r == null ? b : Rect.Union(r.Value, b);
                }
                // the section alone, set on the background of the window: a margin taken from the
                // window would show the edges of the sections beside it.
                var cut = r.Value;
                cut.Intersect(new Rect(size));
                int x = (int)Math.Floor(cut.X * scale), y = (int)Math.Floor(cut.Y * scale);
                int cw = Math.Min(bmp.PixelWidth - x, (int)Math.Ceiling(cut.Width * scale)), ch = Math.Min(bmp.PixelHeight - y, (int)Math.Ceiling(cut.Height * scale));
                var crop = new CroppedBitmap(bmp, new Int32Rect(x, y, cw, ch));
                int pad = (int)Math.Round(SectionPad * scale);
                var dv = new DrawingVisual();
                using (var dc = dv.RenderOpen())
                {
                    dc.DrawRectangle(frame.Background, null, new Rect(0, 0, (cw + 2 * pad) / scale, (ch + 2 * pad) / scale));
                    dc.DrawImage(crop, new Rect(pad / scale, pad / scale, cw / scale, ch / scale));
                }
                var shot = new RenderTargetBitmap(cw + 2 * pad, ch + 2 * pad, 96 * scale, 96 * scale, PixelFormats.Pbgra32);
                shot.Render(dv);
                picture = shot;
            }
            Directory.CreateDirectory(Path.GetDirectoryName(png));
            var enc = new PngBitmapEncoder();
            enc.Frames.Add(BitmapFrame.Create(picture));
            using (var fs = File.Create(png)) enc.Save(fs);
        }
    }
}
