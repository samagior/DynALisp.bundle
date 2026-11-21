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
//
// Each row of Shots.csv (Window;Sample;Picture, paths from the root of the repository) is a
// window file opened as the plugin opens it (Session.Open: the same engine, the same theme),
// on the values of its sample file (Samples\, as the Lisp gives them: key=value,
// key/list=item|item, key/off=1), its Open Docs button enabled. Its content is drawn under a
// plain title bar, at twice its size (192 dpi), into the PNG its docs page names
// (<!-- picture: images/<Page>-window.png -->), in the light theme of AutoCAD, and in its dark
// theme beside it (<Page>-window-dark.png, shown by the website in dark mode). Nothing is
// shown on the screen.

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
            var only = new List<string>();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-out" && i + 1 < args.Length) outDir = Path.GetFullPath(args[++i]);
                else only.Add(args[i]);
            }
            int errors = 0, done = 0;
            foreach (var line in File.ReadAllLines(Path.Combine(here, "Shots.csv")))
            {
                if (line.Trim() == "" || line.TrimStart().StartsWith("#")) continue;
                var f = line.Split(';').Select(x => x.Trim()).ToArray();
                if (f.Length < 3) continue;
                if (only.Count > 0 && !only.Any(o => f[0].Contains(o) || f[2].Contains(o))) continue;
                string xaml = Path.Combine(root, f[0]), sample = Path.Combine(here, "Samples", f[1]);
                string png = outDir != null ? Path.Combine(outDir, f[2]) : Path.Combine(root, f[2]);
                try
                {
                    Shot(xaml, sample, png, false);
                    Shot(xaml, sample, Path.ChangeExtension(png, null) + "-dark.png", true);
                    Console.WriteLine("Drawn " + f[2] + " (light, dark)");
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

        // The folder of PackageContents.xml, from the current folder up:
        static string Root()
        {
            for (var d = new DirectoryInfo(Environment.CurrentDirectory); d != null; d = d.Parent)
                if (File.Exists(Path.Combine(d.FullName, "PackageContents.xml"))) return d.FullName;
            return null;
        }

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
                if (key.EndsWith("/list")) s.Lists[key.Substring(0, key.Length - 5)] = value.Split('|').ToList();
                else if (key.EndsWith("/off")) { if (value == "1") s.Off.Add(key.Substring(0, key.Length - 4)); }
                else s.Values[key] = value;
            }
        }

        static void Shot(string xaml, string sample, string png, bool dark)
        {
            var s = new Session { Dark = dark };
            Read(s, sample);
            var view = s.Open(xaml);
            var w = view.Window;
            s.Values[Session.DocsKey(Win.GetDocs(w))] = "https://samagior.github.io/DynALisp.docs/";
            view.Fill();

            // The content of the window under a title bar, with the resources and the text
            // settings of the window (its styles, its theme):
            var content = (UIElement)w.Content;
            w.Content = null;
            var title = new Grid { Height = 32 };
            title.SetResourceReference(Panel.BackgroundProperty, "Dyl.TitleBar");
            var caption = new TextBlock { Text = w.Title, Margin = new Thickness(12, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
            caption.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.TitleText");
            var close = new TextBlock { Text = "\u2715", Margin = new Thickness(0, 0, 14, 0), HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            close.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            title.Children.Add(caption);
            title.Children.Add(close);
            var dock = new DockPanel();
            DockPanel.SetDock(title, Dock.Top);
            dock.Children.Add(title);
            dock.Children.Add(content);
            var frame = new Border
            {
                Child = dock,
                BorderThickness = new Thickness(1),
                UseLayoutRounding = true,
                SnapsToDevicePixels = true,
            };
            TextOptions.SetTextFormattingMode(frame, TextFormattingMode.Ideal);
            frame.Resources = w.Resources;
            TextElement.SetFontFamily(frame, w.FontFamily);
            TextElement.SetFontSize(frame, w.FontSize);
            frame.SetResourceReference(Border.BackgroundProperty, "Dyl.Back");
            frame.SetResourceReference(Border.BorderBrushProperty, "Dyl.BorderStrong");
            frame.SetResourceReference(TextElement.ForegroundProperty, "Dyl.Text");

            frame.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
            frame.Arrange(new Rect(frame.DesiredSize));
            frame.UpdateLayout();
            // the bindings and the templates done:
            Dispatcher.CurrentDispatcher.Invoke(() => { }, DispatcherPriority.ApplicationIdle);
            frame.UpdateLayout();

            const double scale = 2;
            var size = frame.RenderSize;
            var bmp = new RenderTargetBitmap((int)Math.Ceiling(size.Width * scale), (int)Math.Ceiling(size.Height * scale), 96 * scale, 96 * scale, PixelFormats.Pbgra32);
            bmp.Render(frame);
            Directory.CreateDirectory(Path.GetDirectoryName(png));
            var enc = new PngBitmapEncoder();
            enc.Frames.Add(BitmapFrame.Create(bmp));
            using (var fs = File.Create(png)) enc.Save(fs);
        }
    }
}
