// PhaseCombos.cs - the Auto-phase and Phase drop-downs, after the Layer Phase button
// Copyright (C) 2026  Samuel Martineau, GNU General Public License v3 (see Plugin.cs)
//
// Two drop-downs in the style of the Layer drop-down of AutoCAD:
//   - Auto-phase On / Off (the DynalispPhaseAuto user setting, every drawing),
//   - the active phase of the current drawing (None, E - Existing To Remain...).
// They always show the current state:
//   - Remote>>Dyl:PhaseStatus (Modules\Dynalisp\Remote\Dyl-LayerPhase.lsp), run on every
//     change of the phase or of auto-phase (commands, Layer Phase window, Settings, reactors
//     switch) and when a drawing is loaded, calls (Dyl:RibbonPhase code auto reactors phases);
//   - each drawing keeps its own phase (Document.UserData): a drawing made current shows its
//     phase, and auto-phase is read again from the user settings (getenv).
// Picking an item runs the Lisp setter (Remote>>Dyl:PhaseSet, Remote>>Dyl:PhaseAutoSet), and
// the setter shows the new state. Only an item picked by the user runs it (Host.Picks): the
// ribbon also changes the item shown on its own, which only shows the state again.

using System;
using System.Collections.Generic;
using System.Linq;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;

namespace DynALisp.Ribbon
{
    public class PhaseCombos
    {
        // Document.UserData keys: the phase of the drawing ("" none), the state asked once:
        const string PhaseKey = "DynALisp.Phase";
        const string AskedKey = "DynALisp.PhaseAsked";

        static readonly List<KeyValuePair<string, string>> Defaults = new List<KeyValuePair<string, string>>
        {
            new("E", "Existing To Remain"), new("D", "Existing To Demolish"), new("N", "New Work"),
            new("T", "Temporary Work"), new("F", "Future Work"),
        };

        // The phases of Phase.csv (sent by DynALisp), also used by the Status of Layer Transfer:
        public static List<KeyValuePair<string, string>> Phases = Defaults;
        static bool _auto, _reactors;

        // The phases with their descriptions in the language of the AutoCAD installed (T.Lang): the Description.<lang>
        // column of Phase.csv, read by the plugin (Host.Standard, in UTF-8; the Lisp side reads
        // the file in the code page of Windows and sends the English descriptions). The English
        // one for a phase the column does not have:
        public static List<KeyValuePair<string, string>> Localized()
        {
            if (T.Lang == "en") return Phases;
            var local = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var s in Host.Standard("Phase"))
                if (!local.ContainsKey(s.Key) && s.Value != "") local[s.Key] = s.Value;
            return Phases.Select(p => new KeyValuePair<string, string>(p.Key, local.TryGetValue(p.Key, out var d) ? d : p.Value)).ToList();
        }

        // The width of the Auto-phase and Phase drop-downs: their longest item (the Layer
        // Transfer drop-downs have the same width):
        public static double Width => Host.FitWidth(
            new[] { T.S("Auto-phase On (reactors off)"), T.S("Auto-phase Off"), T.S("None") }.Concat(Localized().Select(p => p.Key + " - " + p.Value)));

        public static readonly Combos Part = new Combos();

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
                if (!lst.SequenceEqual(Phases)) Phases = lst;
            }
            var doc = Host.Doc;
            if (doc != null) doc.UserData[PhaseKey] = code ?? "";
            // called while DynALisp loads, from reactors and in the middle of commands: the
            // ribbon is changed later, when AutoCAD is idle
            Part.Later();
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

        // A drawing whose phase is not known yet (made current before the plugin was loaded)
        // asks DynALisp for it once, when AutoCAD waits for a command:
        public static void AskOnIdle()
        {
            var doc = Host.Doc;
            if (doc == null || doc.UserData[PhaseKey] is string || doc.UserData[AskedKey] != null) return;
            try
            {
                if (!doc.Editor.IsQuiescent) return;
                doc.UserData[AskedKey] = true;
                doc.SendStringToExecute("(if Remote>>Dyl:PhaseStatus (Remote>>Dyl:PhaseStatus))\n", false, false, false);
            }
            catch { }
        }

        public class Combos : Part
        {
            public override string ButtonId => "RBN_DYL_CMD_DYL_LAYERPHASE";
            public override string Command => "DYL-LAYERPHASE";
            public override string PanelId => "RBN_DYL_PANEL_DRAWING_BEHAVIORS";
            public override string PanelTitle => "Drawing Behaviors";

            RibbonCombo _autoCombo, _phaseCombo;
            RibbonButton _autoOn, _autoOff;
            Host.Picks _autoPicks, _phasePicks;
            List<KeyValuePair<string, string>> _shown;
            bool _updating;

            public Combos() => ReadSettings();

            public override RibbonRowPanel Build()
            {
                _autoOn = Host.Item(T.S("Auto-phase On"), "1");
                _autoOff = Host.Item(T.S("Auto-phase Off"), "0");
                _autoCombo = Host.Combo("DYL_PHASE_AUTO", T.S("Auto-phase: the objects created by a command go to the active phase."));
                _autoCombo.Items.Add(_autoOn);
                _autoCombo.Items.Add(_autoOff);
                _autoCombo.CurrentChanged += OnAutoPicked;
                _autoPicks = new Host.Picks(_autoCombo);
                _phaseCombo = Host.Combo("DYL_PHASE_ACTIVE", T.S("Active phase of the drawing: new objects and phased layer keys go to its layers."));
                _phaseCombo.CurrentChanged += OnPhasePicked;
                _phasePicks = new Host.Picks(_phaseCombo);
                _shown = null;
                return Host.Stack("DYL_PHASE_DROPDOWNS", _autoCombo, _phaseCombo);
            }

            public override void DocumentChanged()
            {
                ReadSettings();
                Later();
            }

            // Show the state: auto-phase, and the phase of the current drawing (nothing picked
            // while it is not known).
            public override void Refresh()
            {
                if (Row == null) return;
                _updating = true;
                try
                {
                    if (!ReferenceEquals(_shown, Phases))
                    {
                        _phaseCombo.Items.Clear();
                        _phaseCombo.Items.Add(Host.Item(T.S("None"), ""));
                        foreach (var p in Localized()) _phaseCombo.Items.Add(Host.Item(p.Key + " - " + p.Value, p.Key));
                        _shown = Phases;
                        Host.FixWidth(Width, _autoCombo, _phaseCombo);
                        TransferCombos.Part.Resize();
                    }
                    // Auto-phase on but the reactors off: it does nothing, the item says so.
                    string on = _reactors ? T.S("Auto-phase On") : T.S("Auto-phase On (reactors off)");
                    if (_autoOn.Text != on) _autoOn.Text = on;
                    var auto = _auto ? _autoOn : _autoOff;
                    if (!ReferenceEquals(_autoCombo.Current, auto)) _autoCombo.Current = auto;

                    string code = Host.Doc?.UserData[PhaseKey] as string;
                    RibbonItem cur = null;
                    if (code != null)
                    {
                        cur = _phaseCombo.Items.OfType<RibbonItem>().FirstOrDefault(it => string.Equals(it.Tag as string, code, StringComparison.OrdinalIgnoreCase));
                        if (cur == null)
                        {
                            // a phase that is no longer in Phase.csv:
                            cur = Host.Item(code, code);
                            _phaseCombo.Items.Add(cur);
                            _shown = null;
                        }
                    }
                    if (!ReferenceEquals(_phaseCombo.Current, cur)) _phaseCombo.Current = cur;
                }
                finally { _updating = false; }
            }

            // A change made by the ribbon itself (not picked by the user) shows the state
            // again, at idle time, once a second at most:
            void ShowAgain() => Later(1000);

            void OnAutoPicked(object sender, RibbonPropertyChangedEventArgs e)
            {
                if (_updating) return;
                var b = _autoCombo.Current as RibbonButton;
                bool on = (b?.Tag as string) == "1";
                if (b == null || !_autoPicks.ByUser)
                {
                    if (b == null || on != _auto) ShowAgain();
                    return;
                }
                if (on == _auto) return;
                Host.Run("(progn (if Remote>>Dyl:PhaseAutoSet (Remote>>Dyl:PhaseAutoSet " + (on ? "T" : "nil") + ")) (princ))");
            }

            void OnPhasePicked(object sender, RibbonPropertyChangedEventArgs e)
            {
                if (_updating) return;
                var b = _phaseCombo.Current as RibbonButton;
                string code = b?.Tag as string ?? "";
                string cur = Host.Doc?.UserData[PhaseKey] as string;
                if (b == null || !_phasePicks.ByUser)
                {
                    if (cur != null && (b == null || !string.Equals(cur, code, StringComparison.OrdinalIgnoreCase))) ShowAgain();
                    return;
                }
                if (string.Equals(cur, code, StringComparison.OrdinalIgnoreCase)) return;
                Host.Run("(progn (if Remote>>Dyl:PhaseSet (Remote>>Dyl:PhaseSet " + (code == "" ? "nil" : "\"" + code.Replace("\"", "") + "\"") + ")) (princ))");
            }
        }
    }
}
