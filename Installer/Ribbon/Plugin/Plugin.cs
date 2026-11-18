// Plugin.cs - DynALisp.Ribbon: the live drop-downs of the DynALisp ribbon tab
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
// The DynALisp tab is generated into DynALisp.cuix (Installer\Ribbon\BuildRibbon.py), but a
// CUIx only holds buttons: a drop-down that shows a state can only be added at run time. Each
// group of drop-downs (a Part: PhaseCombos, TransferCombos) is a stack of drop-downs that the
// Host puts after the button of its tool (found by its UID RBN_DYL_CMD_<command>), and again
// when AutoCAD rebuilds the ribbon (workspace or menus loaded again).

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Ribbon;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: ExtensionApplication(typeof(DynALisp.Ribbon.Plugin))]
[assembly: CommandClass(typeof(DynALisp.Ribbon.PhaseCombos))]
[assembly: CommandClass(typeof(DynALisp.Ribbon.TransferCombos))]

namespace DynALisp.Ribbon
{
    public class Plugin : IExtensionApplication
    {
        public void Initialize()
        {
            try
            {
                Host.Add(PhaseCombos.Part);
                Host.Add(TransferCombos.Part);
                Host.Start();
            }
            catch (System.Exception ex) { Host.Log(ex.Message); }
        }

        public void Terminate() { }
    }

    // A stack of drop-downs added after the button of a tool.
    public abstract class Part
    {
        public abstract string ButtonId { get; }      // RBN_DYL_CMD_DYL_LAYERPHASE
        public abstract string Command { get; }       // DYL-LAYERPHASE (to find the button by its macro)
        public abstract RibbonRowPanel Build();       // the stack, made again for each ribbon
        public abstract void Refresh();               // show the state
        public virtual void DocumentChanged() { }     // a drawing made current
        public virtual void CommandEnded() { }        // a command or Lisp expression ended
        public RibbonRowPanel Row;
    }

    public static class Host
    {
        const string TabId = "RBN_DYL_TAB";
        const string PanelId = "RBN_DYL_PANEL_LAYERS";

        static readonly List<Part> Parts = new List<Part>();
        static bool _dirty = true;
        static int _nextTry;
        static readonly HashSet<Document> Watched = new HashSet<Document>();

        public static void Add(Part p) => Parts.Add(p);

        public static void Start()
        {
            var dm = AcApp.DocumentManager;
            dm.DocumentBecameCurrent += (s, e) => { Watch(e.Document); Each(p => p.DocumentChanged()); };
            dm.DocumentToBeDestroyed += (s, e) => Watched.Remove(e.Document);
            foreach (Document d in dm) Watch(d);
            AcApp.Idle += OnIdle;
            ComponentManager.ItemInitialized += (s, e) => _dirty = true;
            if (RibbonServices.RibbonPaletteSet != null) WatchPaletteSet();
            else RibbonServices.RibbonPaletteSetCreated += (s, e) => WatchPaletteSet();
        }

        static void Watch(Document d)
        {
            if (d == null || !Watched.Add(d)) return;
            d.CommandEnded += (s, e) => Each(p => p.CommandEnded());
            d.CommandCancelled += (s, e) => Each(p => p.CommandEnded());
            d.LispEnded += (s, e) => Each(p => p.CommandEnded());
        }

        static void WatchPaletteSet()
        {
            _dirty = true;
            if (RibbonServices.RibbonPaletteSet != null)
                RibbonServices.RibbonPaletteSet.WorkspaceLoaded += (s, e) => _dirty = true;
        }

        static void Each(Action<Part> a)
        {
            foreach (var p in Parts)
                try { a(p); } catch (System.Exception ex) { Log(ex.Message); }
        }

        public static void Log(string msg)
        {
            try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\nDynALisp ribbon: " + msg); } catch { }
        }

        public static Document Doc => AcApp.DocumentManager.MdiActiveDocument;

        static void OnIdle(object sender, EventArgs e)
        {
            if (_dirty && Environment.TickCount - _nextTry >= 0)
            {
                _nextTry = Environment.TickCount + 1000;
                if (Ensure()) _dirty = false;
            }
            PhaseCombos.AskOnIdle();
        }

        // ---- the ribbon ----

        static bool IdIs(string id, string want) =>
            id != null && (id == want || id.EndsWith("." + want, StringComparison.OrdinalIgnoreCase));

        static RibbonPanelSource Panel()
        {
            var ribbon = ComponentManager.Ribbon;
            var tab = ribbon?.Tabs.FirstOrDefault(t => IdIs(t.Id, TabId))
                      ?? ribbon?.Tabs.FirstOrDefault(t => t.Title == "DynALisp");
            var panel = tab?.Panels.FirstOrDefault(p => p.Source != null && IdIs(p.Source.Id, PanelId))
                        ?? tab?.Panels.FirstOrDefault(p => p.Source != null && p.Source.Title == "Layers");
            return panel?.Source;
        }

        static bool Contains(IEnumerable<RibbonItem> items, RibbonItem item)
        {
            foreach (var it in items)
                if (ReferenceEquals(it, item) || (it is RibbonRowPanel rp && Contains(rp.Items, item))) return true;
            return false;
        }

        // The button of a part: its id, its label (the name of the command) or its macro.
        static bool IsButton(RibbonItem it, Part p)
        {
            if (IdIs(it.Id, p.ButtonId)) return true;
            string text = new string((it.Text ?? "").Where(ch => !char.IsWhiteSpace(ch)).ToArray());
            string name = p.Command.Substring(p.Command.IndexOf('-') + 1);
            if (text.Equals(name, StringComparison.OrdinalIgnoreCase)) return true;
            return it is RibbonButton b && b.CommandParameter is string m
                   && m.TrimEnd().EndsWith(p.Command, StringComparison.OrdinalIgnoreCase);
        }

        // Put every part in the panel (after its button, the end of the panel when it is not
        // found) and show its state. True when they are all there.
        public static bool Ensure()
        {
            var src = Panel();
            if (src == null) return false;
            foreach (var p in Parts)
            {
                if (p.Row != null && Contains(src.Items, p.Row)) continue;
                var row = p.Build();
                // Left by a former load of the plugin (NETLOAD again):
                foreach (var old in src.Items.Where(it => it.Id == row.Id).ToList()) src.Items.Remove(old);
                RibbonItemCollection where = src.Items;
                int at = -1;
                for (int k = 0; k < src.Items.Count && at < 0; k++)
                {
                    var it = src.Items[k];
                    if (IsButton(it, p)) at = k + 1;
                    else if (it is RibbonRowPanel rp)
                        for (int j = 0; j < rp.Items.Count; j++)
                            if (IsButton(rp.Items[j], p)) { where = rp.Items; at = j + 1; break; }
                }
                if (at < 0)
                {
                    at = src.Items.Count;
                    for (int k = 0; k < src.Items.Count; k++)
                        if (src.Items[k] is RibbonPanelBreak) { at = k; break; }
                }
                where.Insert(at, row);
                p.Row = row;
                try { p.Refresh(); } catch (System.Exception ex) { Log(ex.Message); }
            }
            return true;
        }

        public static void Dirty() => _dirty = true;

        public static RibbonButton Item(string text, object tag) =>
            new RibbonButton { Text = text, ShowText = true, ShowImage = false, Tag = tag };

        public static RibbonCombo Combo(string id, string tip) => new RibbonCombo
        {
            Id = id, Width = MinWidth, Size = RibbonItemSize.Standard,
            ShowText = false, ShowImage = false, IsEditable = false, ToolTip = tip,
        };

        // A drop-down whose Current is acted on only when the user picks an item: its list is
        // open, or has just closed. The ribbon also changes Current on its own (to the first
        // item, when it makes the control again: tab shown, panel resized, ribbon rebuilt),
        // which must never run a setter (it turned auto-phase back on).
        public sealed class Picks
        {
            bool _open;
            int _closed = Environment.TickCount - 60000;

            public Picks(RibbonCombo c)
            {
                c.DropDownOpened += (s, e) => _open = true;
                c.DropDownClosed += (s, e) => { _open = false; _closed = Environment.TickCount; };
            }

            public bool ByUser => _open || unchecked(Environment.TickCount - _closed) < 750;
        }

        // A stack of drop-downs, one under the other:
        public static RibbonRowPanel Stack(string id, params RibbonItem[] items) =>
            Rows(id, items.Select(it => new[] { it }).ToArray());

        // A stack of rows, each of its items side by side (a label and its drop-down):
        public static RibbonRowPanel Rows(string id, params RibbonItem[][] rows)
        {
            var panel = new RibbonRowPanel { Id = id };
            for (int i = 0; i < rows.Length; i++)
            {
                if (i > 0) panel.Items.Add(new RibbonRowBreak());
                foreach (var it in rows[i]) panel.Items.Add(it);
            }
            return panel;
        }

        // Labels before the drop-downs of a stack (Level:, From:, To:), all as wide as the
        // longest one, so that the drop-downs line up:
        public static RibbonLabel[] Labels(params string[] texts)
        {
            double w = Math.Ceiling(texts.Max(t => TextWidth(t))) + 6;
            return texts.Select(t => new RibbonLabel { Text = t, Width = w, MinWidth = w, Size = RibbonItemSize.Standard }).ToArray();
        }

        // The width of a text in the font of the ribbon:
        public static double TextWidth(string t)
        {
            try
            {
                var face = new System.Windows.Media.Typeface(System.Windows.SystemFonts.MessageFontFamily,
                    System.Windows.FontStyles.Normal, System.Windows.FontWeights.Normal, System.Windows.FontStretches.Normal);
                var ft = new System.Windows.Media.FormattedText(t ?? "", System.Globalization.CultureInfo.CurrentUICulture,
                    System.Windows.FlowDirection.LeftToRight, face, 12, System.Windows.Media.Brushes.Black, 1.0);
                return ft.WidthIncludingTrailingWhitespace;
            }
            catch { return 7.5 * (t ?? "").Length; }
        }

        // The smallest width of a drop-down, and the room of its arrow and margins added to
        // its longest item:
        const double MinWidth = 160;
        const double Room = 44;

        // The drop-downs of a stack as wide as their longest item (the same width, so that they
        // line up), measured in the font of the ribbon; texts: items that are not in them yet.
        public static void Fit(IEnumerable<string> texts, params RibbonCombo[] combos)
        {
            double w = FitWidth(combos.SelectMany(c => c.Items.OfType<RibbonItem>().Select(it => it.Text ?? "")).Concat(texts));
            foreach (var c in combos) { c.Width = w; c.MinWidth = w; }
        }

        // The width of a drop-down that shows the longest of the texts:
        public static double FitWidth(IEnumerable<string> texts)
        {
            double w = MinWidth;
            foreach (var t in texts) w = Math.Max(w, Math.Ceiling(TextWidth(t)) + Room);
            return w;
        }

        // Drop-downs of a fixed width; their list opens as wide as their longest item, so that
        // a long item is read whole there:
        public static void FixWidth(double w, params RibbonCombo[] combos)
        {
            foreach (var c in combos)
            {
                c.Width = w;
                c.MinWidth = w;
                c.DropDownWidth = Math.Max(w, FitWidth(c.Items.OfType<RibbonItem>().Select(it => it.Text ?? "")));
            }
        }

        // Run a Lisp expression (or a macro) in the current drawing. The command running is
        // cancelled first (as the ^C^C of the buttons of the ribbon); with no command running,
        // nothing is cancelled, so the objects selected stay selected for a command that uses
        // them.
        public static void Run(string text)
        {
            var doc = Doc;
            if (doc == null) return;
            bool busy = false;
            try { busy = Convert.ToInt32(AcApp.GetSystemVariable("CMDACTIVE")) != 0; } catch { }
            doc.SendStringToExecute((busy ? "\x03\x03" : "") + text + "\n", true, false, false);
        }

        // ---- the data files ----

        // The folder of the bundle (DynALisp.bundle): Contents\Resources\DynALisp.Ribbon.dll.
        static string Bundle => Path.GetFullPath(Path.Combine(Path.GetDirectoryName(typeof(Host).Assembly.Location), "..", ".."));

        // A data file of Contents (rel: Modules\Dynalisp\Res\...), its user copy when there is
        // one (DynALisp.bundle\User\..., see Dyl:UserFile):
        public static string UserFile(string rel)
        {
            string usr = Path.Combine(Bundle, "User", rel);
            return File.Exists(usr) ? usr : Path.Combine(Bundle, "Contents", rel);
        }

        // The (code, description) rows of a list of Res\AEC\Standard: the first column and the
        // last one (Description). Separator: ; tab or , (whichever the header uses).
        public static List<KeyValuePair<string, string>> Standard(string name)
        {
            var lst = new List<KeyValuePair<string, string>>();
            try
            {
                string path = UserFile(Path.Combine("Modules", "Dynalisp", "Res", "AEC", "Standard", name + ".csv"));
                if (!File.Exists(path)) return lst;
                var lines = File.ReadAllLines(path);
                if (lines.Length == 0) return lst;
                char sep = lines[0].Contains(';') ? ';' : lines[0].Contains('\t') ? '\t' : ',';
                var head = lines[0].Split(sep);
                int desc = Array.FindIndex(head, h => h.Trim().Trim('﻿').Equals("Description", StringComparison.OrdinalIgnoreCase));
                foreach (var line in lines.Skip(1))
                {
                    var f = line.Split(sep);
                    string code = f[0].Trim();
                    if (code == "") continue;
                    lst.Add(new KeyValuePair<string, string>(code, desc >= 0 && desc < f.Length ? f[desc].Trim() : ""));
                }
            }
            catch { }
            return lst;
        }
    }
}
