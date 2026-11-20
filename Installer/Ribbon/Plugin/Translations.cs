// Translations.cs - the DynALisp ribbon tab in the language of DynALisp
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
// A CUIx holds one language: DynALisp.cuix is in English. The Lisp side gives the language
// of DynALisp (Language in Dyl-Settings, Dyl:Lang of dynalisp.mnl) with (Dyl:RibbonLang
// "fr") when DynALisp loads and when the language is saved. In another language than
// English, the labels and tooltips of the tab are replaced by those of
// Contents\Resources\DynALisp.Ribbon.<code>.csv, written by BuildRibbon.py from
// Installer\Ribbon\Ribbon.<code>.csv (Id;Text;Title;Description, the items found by their
// UID); in English, the texts of the CUIx are put back. The drop-downs of the parts are
// made again in the language (T.S, the strings of the plugin below). As every change of
// the ribbon, it is done only when AutoCAD is idle with no command running (Host.OnIdle),
// and again when AutoCAD makes the ribbon again (workspace or menus loaded).

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;

namespace DynALisp.Ribbon
{
    public static class T
    {
        // The language of DynALisp: en, fr...
        public static string Lang { get; private set; } = "en";

        // The strings of the plugin itself (the drop-downs), by language:
        static readonly Dictionary<string, Dictionary<string, string>> Strings = new()
        {
            ["fr"] = new()
            {
                ["Auto-phase On"] = "Auto-phase activée",
                ["Auto-phase Off"] = "Auto-phase désactivée",
                ["Auto-phase On (reactors off)"] = "Auto-phase activée (réacteurs désactivés)",
                ["None"] = "Aucune",
                ["Unphased"] = "Sans phase",
                ["Any"] = "Toutes",
                ["Select replacement..."] = "Choisir la valeur...",
                ["Level:"] = "Niveau :",
                ["From:"] = "De :",
                ["To:"] = "À :",
                ["Discipline designator"] = "Désignation de discipline",
                ["Major group"] = "Groupe principal",
                ["Minor group"] = "Groupe secondaire",
                ["Status"] = "Statut",
                ["Auto-phase: the objects created by a command go to the active phase."] =
                    "Auto-phase : les objets créés par une commande vont dans la phase active.",
                ["Active phase of the drawing: new objects and phased layer keys go to its layers."] =
                    "Phase active du dessin : les nouveaux objets et les clés de calque en phase vont sur ses calques.",
                ["Layer Transfer: the level of the layer names to change."] =
                    "Transfert de calques : le niveau des noms de calques à changer.",
                ["Layer Transfer: the value of the layers to transfer (Any: every layer)."] =
                    "Transfert de calques : la valeur des calques à transférer (Toutes : chaque calque).",
                ["Layer Transfer: the value to give the layers. The Transfer button transfers the objects selected."] =
                    "Transfert de calques : la valeur à donner aux calques. Le bouton Transférer transfère les objets sélectionnés.",
            },
        };

        // A string of the plugin in the language:
        public static string S(string en) =>
            Strings.TryGetValue(Lang, out var d) && d.TryGetValue(en, out var s) ? s : en;

        // (Dyl:RibbonLang "fr"): the language of DynALisp. Returns T.
        [LispFunction("Dyl:RibbonLang")]
        public static object RibbonLang(ResultBuffer args)
        {
            try
            {
                string code = args?.AsArray().Select(v => v.Value as string).FirstOrDefault(v => v != null);
                code = string.IsNullOrWhiteSpace(code) ? "en" : code.Trim().ToLowerInvariant();
                _asked = true;
                if (code != Lang || _entries == null)
                {
                    Lang = code;
                    Load(code);
                    Host.Rebuild();     // the drop-downs made again in the language
                }
                Dirty();
            }
            catch (System.Exception ex) { Host.Log(ex.Message); }
            return true;
        }

        // (Dyl:RibbonLangInfo): what the translation of the tab found, to see why an item is not
        // translated: the language, the texts read, the items of the tab and how they were found,
        // and a few items not found (their id | label | macro).
        [LispFunction("Dyl:RibbonLangInfo")]
        public static object RibbonLangInfo(ResultBuffer args)
        {
            return string.Format(
                "Language: {0} (given: {1}); texts: {2} ({3}); tab: {4}; panels: {5} of {6}; items: {7} of {8} " +
                "(by id {9}, by macro {10}, by label {11}); not found: {12}",
                Lang, _asked ? "yes" : "no", _entries?.Count ?? 0, _file ?? "none",
                _tab ? "found" : "not found", _panelsDone, _panels, _itemsDone, _items, _byId, _byMacro, _byText,
                _missed.Count == 0 ? "none" : string.Join(" ; ", _missed));
        }

        // ---- the tab ----

        sealed class Entry
        {
            public string Id, Macro, English, Text, Title, Desc;
        }

        // The texts of the language (none in English), found by the UID of an item, else by its
        // macro (AutoCAD may not give an item of a partial CUIx its UID), else by its English label:
        static List<Entry> _entries;
        static Dictionary<string, Entry> _byIdMap, _byEnglish;
        static List<Entry> _byMacroList;
        static string _file;
        static bool _dirty, _asked, _tab;
        static int _panels, _panelsDone, _items, _itemsDone, _byId, _byMacro, _byText;
        static readonly List<string> _missed = new();

        // The texts of the CUIx (English) of each item, kept on the item itself the first time it
        // is seen (a ribbon made again has new items, in English again):
        sealed class Original
        {
            public string Text, Title;
            public object Content, Tip;
        }
        static readonly System.Runtime.CompilerServices.ConditionalWeakTable<object, Original> Originals = new();

        public static void Dirty() => _dirty = true;
        public static bool Due => _dirty && _entries != null;

        static void Load(string code)
        {
            _entries = new List<Entry>();
            _file = null;
            if (code != "en")
            {
                try
                {
                    string path = Path.Combine(Path.GetDirectoryName(typeof(T).Assembly.Location), "DynALisp.Ribbon." + code + ".csv");
                    _file = File.Exists(path) ? Path.GetFileName(path) : Path.GetFileName(path) + " missing";
                    if (File.Exists(path))
                        foreach (var line in File.ReadAllLines(path).Skip(1))
                        {
                            var f = line.Split(';');
                            if (f.Length >= 6 && f[0].Trim() != "")
                                _entries.Add(new Entry { Id = f[0].Trim(), Macro = f[1].Trim(), English = Norm(f[2]), Text = f[3], Title = f[4], Desc = f[5] });
                        }
                }
                catch (System.Exception ex) { Host.Log(ex.Message); }
            }
            _byIdMap = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);
            _byEnglish = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);
            foreach (var e in _entries)
            {
                _byIdMap[e.Id] = e;
                if (e.English != "" && !_byEnglish.ContainsKey(e.English)) _byEnglish[e.English] = e;
            }
            // the longest macro first: the items of the Quick Draw gallery all end with its command
            _byMacroList = _entries.Where(e => e.Macro != "").OrderByDescending(e => e.Macro.Length).ToList();
        }

        // A label with its spaces and line breaks made one space:
        static string Norm(string s) => string.Join(" ", (s ?? "").Split(new[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries));

        // The UID of an item without the prefix AutoCAD may give it (DYNALISP.RBN_DYL_...):
        static string Bare(string id) => id == null ? null : id.Substring(id.LastIndexOf('.') + 1);

        static Entry Find(string id, string macro, string english, out int how)
        {
            how = 0;
            if (_entries.Count == 0) return null;
            string bare = Bare(id);
            if (bare != null && _byIdMap.TryGetValue(bare, out var e)) { how = 1; return e; }
            if (!string.IsNullOrWhiteSpace(macro))
            {
                string m = macro.TrimEnd(' ', '\r', '\n', ';');
                foreach (var x in _byMacroList)
                    if (m.EndsWith(x.Macro, StringComparison.OrdinalIgnoreCase)) { how = 2; return x; }
            }
            if (_byEnglish.TryGetValue(Norm(english), out e)) { how = 3; return e; }
            return null;
        }

        // Put the texts of the language on the tab (run by Host.OnIdle). False when the tab is
        // not there yet (tried again later).
        public static bool Apply()
        {
            var ribbon = ComponentManager.Ribbon;
            var tab = ribbon?.Tabs.FirstOrDefault(t => Bare(t.Id) == "RBN_DYL_TAB")
                      ?? ribbon?.Tabs.FirstOrDefault(t => t.Title == "DynALisp");
            _tab = tab != null;
            if (tab == null) return false;
            _panels = _panelsDone = _items = _itemsDone = _byId = _byMacro = _byText = 0;
            _missed.Clear();
            foreach (var panel in tab.Panels)
            {
                var src = panel.Source;
                if (src == null) continue;
                _panels++;
                var org = Originals.GetValue(src, _ => new Original { Text = src.Title });
                var e = Find(src.Id, null, org.Text, out _);
                if (e != null) _panelsDone++;
                string title = e != null && e.Text != "" ? e.Text : org.Text;
                if (src.Title != title) src.Title = title;
                Walk(src.Items);
            }
            if (Lang != "en" && _entries.Count > 0 && _itemsDone == 0)
                Host.Log("the tab could not be translated: no item found, see (Dyl:RibbonLangInfo).");
            _dirty = false;
            return true;
        }

        static void Walk(IEnumerable<RibbonItem> items)
        {
            foreach (var it in items)
            {
                if (it == null) continue;
                Item(it);
                if (it is RibbonRowPanel rp) Walk(rp.Items);
                else if (it is RibbonListButton lb) Walk(lb.Items.OfType<RibbonItem>());
            }
        }

        static void Item(RibbonItem it)
        {
            // Only the buttons of the CUIx: not the separators, breaks, labels and drop-downs:
            if (!(it is RibbonButton)) return;
            if (it.Id != null && it.Id.StartsWith("DYL_")) return;   // the items of the parts
            var org = Originals.GetValue(it, _ =>
                it.ToolTip is RibbonToolTip t0 ? new Original { Text = it.Text, Title = t0.Title, Content = t0.Content }
                                               : new Original { Text = it.Text, Tip = it.ToolTip });
            string macro = (it as RibbonButton)?.CommandParameter as string;
            _items++;
            var e = Find(it.Id, macro, org.Text, out int how);
            if (e != null)
            {
                _itemsDone++;
                if (how == 1) _byId++; else if (how == 2) _byMacro++; else _byText++;
            }
            else if (Lang != "en" && _missed.Count < 6)
                _missed.Add((it.Id ?? "") + " | " + Norm(org.Text) + " | " + (macro ?? "").Trim());
            string text = e != null && e.Text != "" ? Lines(e.Text, org.Text) : org.Text;
            // A split button that follows the item picked last shows the text of that item
            // (translated with it); one that keeps its name (the Quick Draw gallery) shows its own:
            bool follows = it is RibbonListButton lb && lb.IsSynchronizedWithCurrentItem;
            if (!follows && it.Text != text) it.Text = text;
            if (it.ToolTip is RibbonToolTip tt)
            {
                string title = e != null && e.Title != "" ? e.Title : org.Title;
                object content = e != null && e.Desc != "" ? e.Desc : org.Content;
                if (tt.Title != title) tt.Title = title;
                if (!Equals(tt.Content, content)) tt.Content = content;
            }
            else if (e != null && (e.Title != "" || e.Desc != ""))
                it.ToolTip = new RibbonToolTip { Title = e.Title != "" ? e.Title : text, Content = e.Desc };
            else if (e == null && !Equals(it.ToolTip, org.Tip))
                it.ToolTip = org.Tip;
        }

        // The label on two lines when the label of the CUIx is (a large button), cut at the
        // space nearest its middle, as two_lines of BuildRibbon.py:
        static string Lines(string text, string org)
        {
            if (org == null) return text;
            string br = org.Contains("\r\n") ? "\r\n" : org.Contains('\r') ? "\r" : org.Contains('\n') ? "\n" : null;
            if (br == null || text.Contains('\r') || text.Contains('\n')) return text;
            int best = -1;
            for (int i = 0; i < text.Length; i++)
                if (text[i] == ' ' && (best < 0 || Math.Abs(i - text.Length / 2.0) < Math.Abs(best - text.Length / 2.0))) best = i;
            return best < 0 ? text : text.Substring(0, best) + br + text.Substring(best + 1);
        }
    }
}
