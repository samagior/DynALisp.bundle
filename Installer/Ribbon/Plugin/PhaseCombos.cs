// PhaseCombos.cs - the Auto-phase and Phase drop-downs of the Layers panel of the DynALisp tab
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
// CUIx only holds buttons: a drop-down that shows a state can only be added at run time. This
// plugin adds, next to the Layer Phase button of the Layers panel, two drop-downs in the style
// of the Layer drop-down of AutoCAD:
//   - Auto-phase On / Off (the DynalispPhaseAuto user setting, every drawing),
//   - the active phase of the current drawing (None, E - Existing To Remain...).
// They always show the current state:
//   - Remote>>Dyl:PhaseStatus (Modules\Dynalisp\Remote\Dyl-LayerPhase.lsp), run on every
//     change of the phase or of auto-phase (commands, Layer Phase window, Settings, reactors
//     switch) and when a drawing is loaded, calls (Dyl:RibbonPhase code auto reactors phases);
//   - each drawing keeps its own phase (Document.UserData): a drawing made current shows its
//     phase, and auto-phase is read again from the user settings (getenv).
// Picking an item runs the Lisp setter (Remote>>Dyl:PhaseSet, Remote>>Dyl:PhaseAutoSet), as a
// button of the ribbon does (^C^C first), and the setter shows the new state.
// The ribbon is rebuilt by AutoCAD when the workspace or the menus are loaded again: the
// drop-downs are added again then.

using System;
using System.Collections.Generic;
using System.Linq;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Ribbon;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;

using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

[assembly: ExtensionApplication(typeof(DynALisp.Ribbon.Plugin))]
[assembly: CommandClass(typeof(DynALisp.Ribbon.PhaseCombos))]

namespace DynALisp.Ribbon
{
    public class Plugin : IExtensionApplication
    {
        public void Initialize()
        {
            try { PhaseCombos.Start(); }
            catch (System.Exception ex) { PhaseCombos.Log("DynALisp ribbon: " + ex.Message); }
        }

        public void Terminate() { }
    }

    public class PhaseCombos
    {
        // Ids of the DynALisp tab, its Layers panel and the Layer Phase button (BuildRibbon.py):
        const string TabId = "RBN_DYL_TAB";
        const string PanelId = "RBN_DYL_PANEL_LAYERS";
        const string ButtonId = "RBN_DYL_CMD_DYL_LAYERPHASE";
        const string RowId = "DYL_PHASE_DROPDOWNS";
        // Document.UserData keys: the phase of the drawing ("" none), the state asked once:
        const string PhaseKey = "DynALisp.Phase";
        const string AskedKey = "DynALisp.PhaseAsked";
        // The smallest width of the drop-downs, and the room of their arrow and margins
        // added to the longest item (see Fit):
        const double ComboWidth = 160;
        const double ComboRoom = 44;

        static readonly List<KeyValuePair<string, string>> Defaults = new List<KeyValuePair<string, string>>
        {
            new("E", "Existing To Remain"), new("D", "Existing To Demolish"), new("N", "New Work"),
            new("T", "Temporary Work"), new("F", "Future Work"),
        };

        static List<KeyValuePair<string, string>> _phases = Defaults;
        static bool _auto, _reactors;
        static RibbonRowPanel _row;
        static RibbonCombo _autoCombo, _phaseCombo;
        static RibbonButton _autoOn, _autoOff;
        static bool _updating, _dirty = true;
        static int _nextTry;

        public static void Start()
        {
            ReadSettings();
            AcApp.DocumentManager.DocumentBecameCurrent += (s, e) => { ReadSettings(); Refresh(); };
            AcApp.Idle += OnIdle;
            ComponentManager.ItemInitialized += (s, e) => _dirty = true;
            if (RibbonServices.RibbonPaletteSet != null) WatchPaletteSet();
            else RibbonServices.RibbonPaletteSetCreated += (s, e) => WatchPaletteSet();
        }

        static void WatchPaletteSet()
        {
            _dirty = true;
            if (RibbonServices.RibbonPaletteSet != null)
                RibbonServices.RibbonPaletteSet.WorkspaceLoaded += (s, e) => _dirty = true;
        }

        public static void Log(string msg)
        {
            try { AcApp.DocumentManager.MdiActiveDocument?.Editor.WriteMessage("\n" + msg); } catch { }
        }

        // (Dyl:RibbonPhase code auto reactors phases): the active phase of the current drawing
        // (nil: none), auto-phase on, the DynALisp reactors on, and the phases of Phase.csv
        // as a flat list ("E" "Existing To Remain" "D" ...). Returns T.
        [LispFunction("Dyl:RibbonPhase")]
        public static object RibbonPhase(ResultBuffer args)
        {
            var v = args?.AsArray() ?? Array.Empty<TypedValue>();
            int i = 0;
            string code = Text(v, ref i);
            _auto = Bool(v, ref i);
            _reactors = Bool(v, ref i);
            var items = new List<string>();
            if (i < v.Length && v[i].TypeCode == (int)LispDataType.ListBegin)
            {
                for (i++; i < v.Length && v[i].TypeCode != (int)LispDataType.ListEnd; i++)
                    if (v[i].TypeCode == (int)LispDataType.Text) items.Add((string)v[i].Value);
            }
            if (items.Count > 1)
            {
                var lst = new List<KeyValuePair<string, string>>();
                for (int k = 0; k + 1 < items.Count; k += 2) lst.Add(new(items[k], items[k + 1]));
                _phases = lst;
            }
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            if (doc != null) doc.UserData[PhaseKey] = code ?? "";
            _dirty = _dirty || !Present();
            Refresh();
            return true;
        }

        static string Text(TypedValue[] v, ref int i)
        {
            if (i >= v.Length) return null;
            var t = v[i++];
            return t.TypeCode == (int)LispDataType.Text && (string)t.Value != "" ? (string)t.Value : null;
        }

        static bool Bool(TypedValue[] v, ref int i)
        {
            if (i >= v.Length) return false;
            return v[i++].TypeCode != (int)LispDataType.Nil;
        }

        // Auto-phase and the reactors switch, read from the user settings (getenv):
        static void ReadSettings()
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General");
                if (key == null) return;
                _auto = (key.GetValue("DynalispPhaseAuto") as string) == "1";
                _reactors = (key.GetValue("DynalispReactors") as string) == "1";
            }
            catch { }
        }

        // The drop-downs are added once the ribbon is there (and again when it is rebuilt).
        // A drawing whose phase is not known yet (made current before the plugin was loaded)
        // asks DynALisp for it once, when AutoCAD waits for a command:
        static void OnIdle(object sender, EventArgs e)
        {
            if (_dirty && Environment.TickCount - _nextTry >= 0)
            {
                _nextTry = Environment.TickCount + 1000;
                if (Ensure()) { _dirty = false; Refresh(); }
            }
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            if (doc == null || doc.UserData[PhaseKey] is string || doc.UserData[AskedKey] != null) return;
            try
            {
                if (!doc.Editor.IsQuiescent) return;
                doc.UserData[AskedKey] = true;
                doc.SendStringToExecute("(if Remote>>Dyl:PhaseStatus (Remote>>Dyl:PhaseStatus))\n", false, false, false);
            }
            catch { }
        }

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

        static bool Present()
        {
            var src = Panel();
            return src != null && _row != null && Contains(src.Items, _row);
        }

        static bool Contains(IEnumerable<RibbonItem> items, RibbonItem item)
        {
            foreach (var it in items)
                if (ReferenceEquals(it, item) || (it is RibbonRowPanel rp && Contains(rp.Items, item))) return true;
            return false;
        }

        // The Layer Phase button: its id, its label or its macro.
        static bool IsPhaseButton(RibbonItem it)
        {
            if (IdIs(it.Id, ButtonId)) return true;
            string text = new string((it.Text ?? "").Where(ch => !char.IsWhiteSpace(ch)).ToArray());
            if (text.Equals("LayerPhase", StringComparison.OrdinalIgnoreCase)) return true;
            return it is RibbonButton b && b.CommandParameter is string m
                   && m.TrimEnd().EndsWith("DYL-LAYERPHASE", StringComparison.OrdinalIgnoreCase);
        }

        // Add the drop-downs after the Layer Phase button (the end of the panel when it is not
        // found). Returns T when they are in the panel.
        static bool Ensure()
        {
            var src = Panel();
            if (src == null) return false;
            if (_row != null && Contains(src.Items, _row)) return true;
            // Left by a former load of the plugin (NETLOAD again):
            foreach (var old in src.Items.Where(it => it.Id == RowId).ToList()) src.Items.Remove(old);
            Build();
            RibbonItemCollection where = src.Items;
            int at = -1;
            for (int k = 0; k < src.Items.Count && at < 0; k++)
            {
                var it = src.Items[k];
                if (IsPhaseButton(it)) at = k + 1;
                else if (it is RibbonRowPanel rp)
                    for (int j = 0; j < rp.Items.Count; j++)
                        if (IsPhaseButton(rp.Items[j])) { where = rp.Items; at = j + 1; break; }
            }
            if (at < 0)
            {
                // the end of the panel, before its slide-out:
                at = src.Items.Count;
                for (int k = 0; k < src.Items.Count; k++)
                    if (src.Items[k] is RibbonPanelBreak) { at = k; break; }
            }
            where.Insert(at, _row);
            return true;
        }

        static RibbonButton Item(string text, string tag) =>
            new RibbonButton { Text = text, ShowText = true, ShowImage = false, Tag = tag };

        static void Build()
        {
            _autoOn = Item("Auto-phase On", "1");
            _autoOff = Item("Auto-phase Off", "0");
            _autoCombo = new RibbonCombo
            {
                Id = "DYL_PHASE_AUTO", Width = ComboWidth, Size = RibbonItemSize.Standard,
                ShowText = false, ShowImage = false, IsEditable = false,
                ToolTip = "Auto-phase: the objects created by a command go to the active phase.",
            };
            _autoCombo.Items.Add(_autoOn);
            _autoCombo.Items.Add(_autoOff);
            _autoCombo.CurrentChanged += OnAutoPicked;

            _phaseCombo = new RibbonCombo
            {
                Id = "DYL_PHASE_ACTIVE", Width = ComboWidth, Size = RibbonItemSize.Standard,
                ShowText = false, ShowImage = false, IsEditable = false,
                ToolTip = "Active phase of the drawing: new objects and phased layer keys go to its layers.",
            };
            _phaseCombo.CurrentChanged += OnPhasePicked;
            _shown = null;

            _row = new RibbonRowPanel { Id = RowId };
            _row.Items.Add(_autoCombo);
            _row.Items.Add(new RibbonRowBreak());
            _row.Items.Add(_phaseCombo);
        }

        static List<KeyValuePair<string, string>> _shown;

        // Both drop-downs as wide as their longest item (the same width, so they line up),
        // measured in the font of the ribbon, plus the room of the arrow:
        static void Fit()
        {
            var texts = new List<string> { "Auto-phase On (reactors off)", _autoOff.Text };
            texts.AddRange(_phaseCombo.Items.OfType<RibbonItem>().Select(it => it.Text ?? ""));
            double w = ComboWidth;
            try
            {
                var face = new System.Windows.Media.Typeface(System.Windows.SystemFonts.MessageFontFamily,
                    System.Windows.FontStyles.Normal, System.Windows.FontWeights.Normal, System.Windows.FontStretches.Normal);
                foreach (var t in texts)
                {
                    var ft = new System.Windows.Media.FormattedText(t, System.Globalization.CultureInfo.CurrentUICulture,
                        System.Windows.FlowDirection.LeftToRight, face, 12, System.Windows.Media.Brushes.Black, 1.0);
                    w = Math.Max(w, Math.Ceiling(ft.WidthIncludingTrailingWhitespace) + ComboRoom);
                }
            }
            catch { w = Math.Max(w, 7.5 * texts.Max(t => t.Length) + ComboRoom); }
            _autoCombo.Width = _phaseCombo.Width = w;
            _autoCombo.MinWidth = _phaseCombo.MinWidth = w;
        }

        // Show the state: auto-phase, and the phase of the current drawing (nothing picked
        // while it is not known).
        static void Refresh()
        {
            if (_dirty)
            {
                if (!Ensure()) return;
                _dirty = false;
            }
            if (_row == null) return;
            _updating = true;
            try
            {
                if (!ReferenceEquals(_shown, _phases))
                {
                    _phaseCombo.Items.Clear();
                    _phaseCombo.Items.Add(Item("None", ""));
                    foreach (var p in _phases) _phaseCombo.Items.Add(Item(p.Key + " - " + p.Value, p.Key));
                    _shown = _phases;
                    Fit();
                }
                // Auto-phase on but the reactors off: it does nothing, the item says so.
                _autoOn.Text = _reactors ? "Auto-phase On" : "Auto-phase On (reactors off)";
                _autoCombo.Current = _auto ? _autoOn : _autoOff;

                var doc = AcApp.DocumentManager.MdiActiveDocument;
                string code = doc?.UserData[PhaseKey] as string;
                RibbonItem cur = null;
                if (code != null)
                {
                    cur = _phaseCombo.Items.OfType<RibbonItem>().FirstOrDefault(it => string.Equals(it.Tag as string, code, StringComparison.OrdinalIgnoreCase));
                    if (cur == null)
                    {
                        // a phase that is no longer in Phase.csv:
                        cur = Item(code, code);
                        _phaseCombo.Items.Add(cur);
                        _shown = null;
                    }
                }
                _phaseCombo.Current = cur;
            }
            catch (System.Exception ex) { Log("DynALisp ribbon: " + ex.Message); }
            finally { _updating = false; }
        }

        static void OnAutoPicked(object sender, RibbonPropertyChangedEventArgs e)
        {
            if (_updating || !(_autoCombo.Current is RibbonButton b)) return;
            bool on = (b.Tag as string) == "1";
            if (on == _auto) return;
            Run("(if Remote>>Dyl:PhaseAutoSet (Remote>>Dyl:PhaseAutoSet " + (on ? "T" : "nil") + "))");
        }

        static void OnPhasePicked(object sender, RibbonPropertyChangedEventArgs e)
        {
            if (_updating || !(_phaseCombo.Current is RibbonButton b)) return;
            string code = b.Tag as string ?? "";
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            if (doc != null && string.Equals(doc.UserData[PhaseKey] as string, code, StringComparison.OrdinalIgnoreCase)) return;
            Run("(if Remote>>Dyl:PhaseSet (Remote>>Dyl:PhaseSet " + (code == "" ? "nil" : "\"" + code.Replace("\"", "") + "\"") + "))");
        }

        // Run a Lisp expression in the current drawing, the command running cancelled first
        // (as the ^C^C of the buttons of the ribbon):
        static void Run(string expr)
        {
            var doc = AcApp.DocumentManager.MdiActiveDocument;
            if (doc == null) return;
            doc.SendStringToExecute("\x03\x03(progn " + expr + " (princ))\n", true, false, false);
        }
    }
}
