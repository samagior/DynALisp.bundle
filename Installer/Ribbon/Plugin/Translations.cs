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
                if (code != Lang || _map == null)
                {
                    Lang = code;
                    _map = Load(code);
                    Host.Rebuild();     // the drop-downs made again in the language
                }
                Dirty();
            }
            catch (System.Exception ex) { Host.Log(ex.Message); }
            return true;
        }

        // ---- the tab ----

        // id -> (text, title, description) in the language (empty in English):
        static Dictionary<string, (string Text, string Title, string Desc)> _map;
        // id -> the texts of the CUIx (English), kept the first time an item is seen:
        static readonly Dictionary<string, (string Text, string Title, object Content, bool Plain)> Originals = new();
        static bool _dirty;

        public static void Dirty() => _dirty = true;
        public static bool Due => _dirty && _map != null;

        static Dictionary<string, (string, string, string)> Load(string code)
        {
            var map = new Dictionary<string, (string, string, string)>(StringComparer.OrdinalIgnoreCase);
            if (code == "en") return map;
            try
            {
                string path = Path.Combine(Path.GetDirectoryName(typeof(T).Assembly.Location), "DynALisp.Ribbon." + code + ".csv");
                if (!File.Exists(path)) return map;
                foreach (var line in File.ReadAllLines(path).Skip(1))
                {
                    var f = line.Split(';');
                    if (f.Length >= 2 && f[0].Trim() != "")
                        map[f[0].Trim()] = (f[1], f.Length > 2 ? f[2] : "", f.Length > 3 ? f[3] : "");
                }
            }
            catch (System.Exception ex) { Host.Log(ex.Message); }
            return map;
        }

        // The UID of an item without the prefix AutoCAD may give it (DYNALISP.RBN_DYL_...):
        static string Bare(string id) => id == null ? null : id.Substring(id.LastIndexOf('.') + 1);

        // Put the texts of the language on the tab (run by Host.OnIdle). False when the tab is
        // not there yet (tried again later).
        public static bool Apply()
        {
            var ribbon = ComponentManager.Ribbon;
            var tab = ribbon?.Tabs.FirstOrDefault(t => Bare(t.Id) == "RBN_DYL_TAB")
                      ?? ribbon?.Tabs.FirstOrDefault(t => t.Title == "DynALisp");
            if (tab == null) return false;
            foreach (var panel in tab.Panels)
            {
                var src = panel.Source;
                if (src == null) continue;
                string id = Bare(src.Id);
                if (id != null && id.StartsWith("RBN_DYL_"))
                {
                    if (!Originals.ContainsKey(id)) Originals[id] = (src.Title, null, null, true);
                    string title = _map.TryGetValue(id, out var tr) && tr.Text != "" ? tr.Text : Originals[id].Text;
                    if (src.Title != title) src.Title = title;
                }
                Walk(src.Items);
            }
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
            string id = Bare(it.Id);
            if (id == null || !id.StartsWith("RBN_DYL_")) return;   // the drop-downs of the parts
            if (!Originals.TryGetValue(id, out var org))
            {
                org = it.ToolTip is RibbonToolTip tt ? (it.Text, tt.Title, tt.Content, false)
                                                     : (it.Text, it.ToolTip as string, null, true);
                Originals[id] = org;
            }
            bool has = _map.TryGetValue(id, out var tr);
            string text = has && tr.Text != "" ? Lines(tr.Text, org.Text) : org.Text;
            // A split button that follows the item picked last shows the text of that item
            // (translated with it); one that keeps its name (the Quick Draw gallery) shows its own:
            bool follows = it is RibbonListButton lb && lb.IsSynchronizedWithCurrentItem;
            if (!follows && it.Text != text) it.Text = text;
            string title = has && tr.Title != "" ? tr.Title : org.Title;
            object content = has && tr.Desc != "" ? tr.Desc : org.Content;
            if (it.ToolTip is RibbonToolTip t)
            {
                if (t.Title != title) t.Title = title;
                if (!Equals(t.Content, content)) t.Content = content;
            }
            else if (has && (tr.Title != "" || tr.Desc != ""))
                it.ToolTip = new RibbonToolTip { Title = title, Content = content };
            else if (!has && org.Plain && !Equals(it.ToolTip, org.Title))
                it.ToolTip = org.Title;
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
