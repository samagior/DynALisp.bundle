// Suite.cs - DynALisp.Windows: the list of the Startup Suite window (Dyl-Suite)
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
// The Startup Suite window (Res\Dyl-Suite.xaml, c:Dyl-Suite of dynalisp.mnl) lists every
// command of the modules: turned on or off, with its aliases, its name, its module and its
// group, the children of a main command folded under it. All of it runs in the window, as
// the DCL dialog did with its callbacks: the filters, the sort, the folding, On/Off, the
// aliases, opening the docs and the Lisp files. The Lisp gives the commands, gets them back
// with the aliases as edited, and saves them.
//
// A window is the Startup Suite window when its list is a ListBox named "lst" and the Lisp
// gives ste/rows (c:Dyl-Suite, Dyl:SuiteWinRow), a row per command, in the order of the list
// (each child right after the main command of its file):
//
//   0 on ("1" / "0")   1 command ("" for a file without command)   2 file   3 module
//   4 group   5 path (from the Modules folder: the file of the command)   6 name
//   7 description   8 the main command of a child ("" else)   9 how many children a main
//   command has ("" none)   10 "1" for a preset child (Pst-*: run by its aliases)
//   11 "1" for a dynamic child (a custom preset: on and off with its main command)
//   12 "1" for the main command of its file   13 what opens its docs page ("" none)
//   14 the page it would have, when it has none   15 its Lisp file, full path ("" missing)
//
//   ste/als     the aliases ((ALIAS COMMAND) ...), upper case
//   ste/taken   the names an alias cannot take ((NAME what-has-it) ...): the commands of
//               the other programs, the aliases of acad.pgp, what has the name of an alias
//               saved (an AutoCAD command)
//   ste.opens   the files whose children are unfolded (their paths, divided by "|")
//   ste.mod     the module listed ("" All), ste.grp its group ("" All), ste.sel the
//               commands selected (their indexes, "0 3 5")
//   srt         the sort (Command, Aliases, Name, Module, Group: srt/list), shw what is
//               shown (All, On, Off, With aliases: shw/list), flt the search, sof Show
//               unloaded commands, sch Show child commands
//
// It gives back ste/rows (column 0 as turned on and off) and ste/als as edited, and the
// state of the list (ste.opens, ste.mod, ste.grp, ste.sel), so that the Lisp opens it again
// as it was (after Open in VS Code). The controls it keeps up to date, by their key:
//
//   lst the list (its items: SuiteItem), mod grp the Module and Group lists, cnt how many
//   are listed, nam des pth the command selected, als aln aad aren adel ams the aliases of
//   the command selected, onf aonf fld fal doc lsp clr the buttons.

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;

namespace DynALisp.Windows
{
    // A line of the list of the Startup Suite window, shown by the ItemTemplate of the list:
    public sealed class SuiteItem : INotifyPropertyChanged
    {
        bool _on;
        string _fold = "", _command = "", _aliases = "";
        internal int Index;
        internal Action<SuiteItem> Toggled;

        // Turned on: its checkbox (a click on it turns the command on or off):
        public bool On
        {
            get => _on;
            set { if (_on == value) return; _on = value; Notify("On"); Toggled?.Invoke(this); }
        }
        internal void SetOn(bool on) { if (_on == on) return; _on = on; Notify("On"); }

        // A dynamic child is turned on and off with its main command:
        public bool CanToggle { get; internal set; }
        // A main command with children: its mark, folded or unfolded ("" else):
        public string Fold { get => _fold; internal set => Set(ref _fold, value, "Fold"); }
        public bool Child { get; internal set; }
        public string Command { get => _command; internal set => Set(ref _command, value, "Command"); }
        public string Aliases { get => _aliases; internal set => Set(ref _aliases, value, "Aliases"); }
        public string Name { get; internal set; }
        public string Module { get; internal set; }
        public string Group { get; internal set; }

        public event PropertyChangedEventHandler PropertyChanged;
        void Notify(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        void Set(ref string field, string value, string name)
        {
            if (field == value) return;
            field = value;
            Notify(name);
        }
    }

    sealed class SuiteEditor
    {
        public const string RowsKey = "ste/rows";
        // The columns of ste/rows:
        const int COn = 0, CCmd = 1, CFile = 2, CMod = 3, CGrp = 4, CPath = 5, CName = 6, CDesc = 7,
                  CMain = 8, CKids = 9, CPreset = 10, CDyn = 11, CIsMain = 12, CDocs = 13, CHint = 14, CLisp = 15;
        static readonly StringComparer Ic = StringComparer.OrdinalIgnoreCase;
        const int MaxOpen = 10;
        const string Folded = "\u25B8", Unfolded = "\u25BE";

        readonly View _v;
        readonly Session _s;
        readonly List<string[]> _rows, _als;
        readonly Dictionary<string, string> _taken = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        readonly SuiteItem[] _items;
        readonly HashSet<string> _opens = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        readonly ListBox _list, _alsList;
        readonly ComboBox _mod, _grp;
        readonly TextBox _aln;

        List<int> _ord = new List<int>();        // the rows in the order of the sort
        List<int> _vis = new List<int>();        // the rows listed
        List<int> _sel = new List<int>();        // the rows selected (listed)
        List<string> _mods = new List<string>(), _grps = new List<string>();
        string _modVal = "", _grpVal = "";
        string _acmd;                            // the command of the aliases panel
        List<string> _alst = new List<string>(); // its aliases
        string _pth;                             // a message in place of the third line of the selection

        public SuiteEditor(View v)
        {
            _v = v;
            _s = v.Session;
            _rows = Table(RowsKey);
            _als = Table("ste/als");
            foreach (var t in Table("ste/taken"))
                if (t.Length > 0 && t[0].Length > 0 && !_taken.ContainsKey(t[0])) _taken[t[0]] = t.Length > 1 ? t[1] : "a command";
            _s.OutRows.Add(RowsKey);
            _s.OutRows.Add("ste/als");

            _list = (ListBox)v.Find("lst");
            _alsList = v.Find("als") as ListBox;
            _mod = v.Find("mod") as ComboBox;
            _grp = v.Find("grp") as ComboBox;
            _aln = v.Find("aln") as TextBox;

            _items = new SuiteItem[_rows.Count];
            for (int i = 0; i < _rows.Count; i++)
            {
                var r = _rows[i];
                _items[i] = new SuiteItem
                {
                    Index = i,
                    CanToggle = Cell(r, CDyn) != "1",
                    Child = Cell(r, CMain).Length > 0,
                    Name = Cell(r, CMain).Length > 0 ? "" : Cell(r, CName),
                    Module = Cell(r, CMod),
                    Group = Cell(r, CGrp),
                    // after the click (the list may be made again):
                    Toggled = it => _v.Window.Dispatcher.BeginInvoke(new Action(() =>
                    {
                        Switch(new List<int> { it.Index }, it.On ? "1" : "0");
                        _v.Refresh();
                    })),
                };
                _items[i].SetOn(Cell(r, COn) == "1");
            }

            _list.SelectionMode = SelectionMode.Extended;
            // A double-click folds or unfolds a main command with children, else opens the
            // docs of the commands selected; a click on the fold mark of a line folds it:
            _list.MouseDoubleClick += (a, e) =>
            {
                if (!(e.OriginalSource is DependencyObject d) || !(ItemsControl.ContainerFromElement(_list, d) is ListBoxItem)) return;
                if (InCheck(d)) return;
                if (_sel.Count == 1 && Kids(_sel[0]) > 0 && ShowKids) Fold(Cell(_rows[_sel[0]], CPath));
                else OpenDocs(_sel);
                _v.Refresh();
                e.Handled = true;
            };
            _list.AddHandler(UIElement.PreviewMouseLeftButtonDownEvent, new MouseButtonEventHandler((a, e) =>
            {
                if (e.OriginalSource is DependencyObject src && Tagged(src, "fold") is FrameworkElement f && f.DataContext is SuiteItem it && it.Fold.Length > 0)
                {
                    Fold(Cell(_rows[it.Index], CPath));
                    _v.Refresh();
                    e.Handled = true;
                }
            }), true);
            // Enter in the search does not Save (it searches as it is typed):
            if (v.Find("flt") is TextBox flt)
                flt.PreviewKeyDown += (a, e) => { if (e.Key == Key.Enter) e.Handled = true; };
            if (_aln != null)
                _aln.PreviewKeyDown += (a, e) =>
                {
                    // Enter adds the alias typed (not Save):
                    if (e.Key == Key.Enter) { AliasAdd(); _v.Refresh(); e.Handled = true; }
                };

            // As the Lisp left them:
            foreach (var p in (Val("ste.opens") ?? "").Split('|')) if (p.Trim().Length > 0) _opens.Add(p.Trim());
            _modVal = Val("ste.mod") ?? "";
            _grpVal = Val("ste.grp") ?? "";
            _sel = (Val("ste.sel") ?? "").Split(' ').Select(x => Int(x, -1)).Where(i => i >= 0 && i < _rows.Count).Distinct().ToList();
        }

        // The element (fe or one of its parents in the line) whose Tag is tag:
        static FrameworkElement Tagged(DependencyObject d, string tag)
        {
            for (; d != null && !(d is ListBoxItem); d = Parent(d))
                if (d is FrameworkElement fe && (fe.Tag as string) == tag) return fe;
            return null;
        }

        static bool InCheck(DependencyObject d)
        {
            for (; d != null && !(d is ListBoxItem); d = Parent(d))
                if (d is ToggleButton) return true;
            return false;
        }

        // The parent of an element of a line (a text run has no visual parent):
        static DependencyObject Parent(DependencyObject d) =>
            d is Visual || d is System.Windows.Media.Media3D.Visual3D ? VisualTreeHelper.GetParent(d) : LogicalTreeHelper.GetParent(d);

        List<string[]> Table(string key) => _s.Rows.TryGetValue(key, out var t) ? t : (_s.Rows[key] = new List<string[]>());
        string Val(string key) => _s.Values.TryGetValue(key, out string v) ? v : null;
        static int Int(string s, int def) =>
            int.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out int i) ? i : def;
        static string Cell(string[] r, int col) => r != null && col >= 0 && col < r.Length ? r[col] ?? "" : "";

        public bool Owns(string key) =>
            key == "lst" || key == "mod" || key == "grp" || key == "als" || key == "aln" ||
            key == "cnt" || key == "nam" || key == "des" || key == "pth" || key == "ams";

        bool ShowKids => Val("sch") == "1";
        bool ShowOff => Val("sof") == "1";
        int Shw => Int(Val("shw"), 0);
        int Sort => Int(Val("srt"), 3);
        string Search => (Val("flt") ?? "").Trim();

        bool IsChild(int i) => Cell(_rows[i], CMain).Length > 0;
        int Kids(int i) => Int(Cell(_rows[i], CKids), 0);
        bool IsDyn(int i) => Cell(_rows[i], CDyn) == "1";
        bool IsOn(int i) => Cell(_rows[i], COn) == "1";
        string Command(int i) => Cell(_rows[i], CCmd);

        List<string> AliasesOf(string cmd) =>
            string.IsNullOrEmpty(cmd) ? new List<string>()
            : _als.Where(p => p.Length > 1 && Ic.Equals(p[1], cmd)).Select(p => p[0]).ToList();

        string AliasText(int i) => string.Join(", ", AliasesOf(Command(i)));

        // ---- The list ----

        public void Fill()
        {
            Sorted();
            Modules();
            List();
            Out();
        }

        // The rows in the order of the sort (Command, Aliases, Name, Module, Group; the order
        // of the file for the same value), a child after its main command:
        void Sorted()
        {
            int k = Sort;
            string Key(int i)
            {
                var r = _rows[i];
                switch (k)
                {
                    case 0: return (Command(i).Length == 0 ? Cell(r, CFile) : Command(i)).ToUpperInvariant();
                    case 1: { string a = AliasText(i); return a.Length == 0 ? "~" : a.ToUpperInvariant(); }
                    case 2: return Cell(r, CName).ToUpperInvariant();
                    case 3: return (Cell(r, CMod) + "\t" + Cell(r, CGrp)).ToUpperInvariant();
                    default: return (Cell(r, CGrp) + "\t" + Cell(r, CMod)).ToUpperInvariant();
                }
            }
            var keys = new string[_rows.Count];
            string cur = null, curPath = null;
            for (int i = 0; i < _rows.Count; i++)
            {
                if (!(cur != null && IsChild(i) && Ic.Equals(Cell(_rows[i], CPath), curPath)))
                {
                    cur = Key(i) + "\t" + i.ToString("D6", CultureInfo.InvariantCulture);
                    curPath = Cell(_rows[i], CPath);
                }
                keys[i] = cur + "\t" + i.ToString("D6", CultureInfo.InvariantCulture);
            }
            _ord = Enumerable.Range(0, _rows.Count).OrderBy(i => keys[i], StringComparer.Ordinal).ToList();
        }

        // A command turned off is listed only with Show unloaded commands, or Show: Off:
        bool Shown(int i) => ShowOff || Shw == 2 || IsOn(i);

        // The Module list: All, then the modules of the commands that can be listed; the
        // module picked kept while it is there, else All:
        void Modules()
        {
            var lst = Enumerable.Range(0, _rows.Count).Where(Shown).Select(i => Cell(_rows[i], CMod))
                                .Where(m => m.Length > 0).Distinct(Ic).OrderBy(m => m, Ic).ToList();
            lst.Insert(0, "All");
            if (_modVal.Length > 0 && !lst.Skip(1).Contains(_modVal, Ic)) { _modVal = ""; _grpVal = ""; }
            _mods = lst;
            _v.Quiet(() =>
            {
                if (_mod == null) return;
                _mod.ItemsSource = _mods;
                _mod.SelectedIndex = _modVal.Length == 0 ? 0 : Math.Max(0, _mods.FindIndex(m => Ic.Equals(m, _modVal)));
            });
            Groups();
        }

        // The Group list: All, then the groups of the module picked ("(root)": the Apps folder):
        void Groups()
        {
            var lst = Enumerable.Range(0, _rows.Count).Select(i => _rows[i])
                                .Where(r => _modVal.Length == 0 || Ic.Equals(Cell(r, CMod), _modVal))
                                .Select(r => Cell(r, CGrp)).Distinct(Ic).OrderBy(g => g, Ic).ToList();
            if (_grpVal.Length > 0 && !lst.Contains(_grpVal, Ic)) _grpVal = "";
            _grps = lst;
            var labels = lst.Select(g => g.Length == 0 ? "(root)" : g).ToList();
            labels.Insert(0, "All");
            _v.Quiet(() =>
            {
                if (_grp == null) return;
                _grp.ItemsSource = labels;
                int gi = _grpVal.Length == 0 ? -1 : _grps.FindIndex(g => Ic.Equals(g, _grpVal));
                _grp.SelectedIndex = gi < 0 ? 0 : gi + 1;
            });
        }

        // The rows listed: those of the module, the group, Show and the search; a child when
        // its main command is unfolded or when searching, unless the children are hidden. The
        // search also finds a command by its aliases:
        bool Listed(int i)
        {
            var r = _rows[i];
            if (_modVal.Length > 0 && !Ic.Equals(Cell(r, CMod), _modVal)) return false;
            if (_grpVal.Length > 0 && !Ic.Equals(Cell(r, CGrp), _grpVal)) return false;
            switch (Shw)
            {
                case 1: if (!IsOn(i)) return false; break;
                case 2: if (IsOn(i)) return false; break;
                case 3: if (AliasesOf(Command(i)).Count == 0) return false; break;
            }
            if (!Shown(i)) return false;
            string txt = Search;
            if (IsChild(i) && !(ShowKids && (txt.Length > 0 || _opens.Contains(Cell(r, CPath))))) return false;
            if (txt.Length == 0) return true;
            return new[] { Command(i), Cell(r, CFile), Cell(r, CName), Cell(r, CDesc), AliasText(i) }
                .Any(s => s.IndexOf(txt, StringComparison.OrdinalIgnoreCase) >= 0);
        }

        // The line of a row: a child shows its name in the Command column, under its main
        // command, and its aliases (or its command when it runs by its own name); a main
        // command with children shows how many it has:
        void Line(int i)
        {
            var r = _rows[i];
            var it = _items[i];
            it.SetOn(IsOn(i));
            it.Fold = !ShowKids || IsChild(i) || Kids(i) == 0 ? "" : _opens.Contains(Cell(r, CPath)) ? Unfolded : Folded;
            it.Command = Command(i).Length == 0 ? "(whole file) " + Cell(r, CFile)
                       : IsChild(i) ? Cell(r, CName)
                       : Kids(i) > 0 ? Command(i) + " (" + Kids(i).ToString(CultureInfo.InvariantCulture) + ")"
                       : Command(i);
            string a = AliasText(i);
            it.Aliases = a.Length > 0 ? a : !IsChild(i) ? "" : Cell(r, CPreset) == "1" ? "(no alias)" : Command(i);
        }

        // The list again, in the order of the sort, the selection still listed kept:
        void List()
        {
            _vis = _ord.Where(Listed).ToList();
            _sel = _sel.Where(_vis.Contains).ToList();
            foreach (int i in _vis) Line(i);
            _v.Quiet(() =>
            {
                _list.ItemsSource = _vis.Select(i => _items[i]).ToList();
                Reselect();
            });
            Info();
        }

        void Reselect()
        {
            _list.SelectedItems.Clear();
            foreach (int i in _sel) _list.SelectedItems.Add(_items[i]);
        }

        // ---- The selection ----

        // How many, the command selected (its name, its description, its main command or its
        // children, the other files of the same command), its aliases:
        void Info()
        {
            int on = _rows.Count(r => Cell(r, COn) == "1");
            Text("cnt", _vis.Count + " listed   |   " + on + " on / " + _rows.Count + " total   |   " + _als.Count + " aliases");
            Aliases();
            if (_sel.Count == 0) { Text("nam", ""); Text("des", ""); Text("pth", _pth ?? ""); }
            else if (_sel.Count > 1) { Text("nam", _sel.Count + " items selected"); Text("des", ""); Text("pth", _pth ?? ""); }
            else
            {
                int i = _sel[0];
                var r = _rows[i];
                string a = AliasText(i);
                Text("nam", Command(i).Length == 0 ? Cell(r, CFile) + " (whole file)"
                          : IsChild(i) ? (a.Length > 0 ? a : Cell(r, CPreset) == "1" ? "(no alias)" : Command(i)) + " - " + Cell(r, CName)
                          : Command(i) + " - " + Cell(r, CName));
                Text("des", Command(i).Length == 0 ? "No command: turning it on loads the whole file." : Cell(r, CDesc));
                var parts = new List<string>();
                if (IsChild(i))
                    parts.Add("Child of " + Cell(r, CMain) + ", runs " + Command(i) + (IsDyn(i) ? " (custom preset, on / off with it)" : ""));
                if (Kids(i) > 0) parts.Add(Kids(i) + (Kids(i) == 1 ? " child command" : " child commands") + ": double-click to fold / unfold");
                // The other files defining the same command:
                if (Command(i).Length > 0)
                {
                    var dup = Enumerable.Range(0, _rows.Count)
                        .Where(j => j != i && Command(j) == Command(i) && !Ic.Equals(Cell(_rows[j], CPath), Cell(r, CPath)))
                        .Select(j => Cell(_rows[j], CMod) + "\\" + Cell(_rows[j], CFile) + (IsOn(j) ? " (on)" : "")).ToList();
                    if (dup.Count > 0) parts.Add("Also defined in: " + string.Join(", ", dup));
                }
                Text("pth", _pth ?? string.Join("   |   ", parts));
            }
            _pth = null;
        }

        void Text(string key, string text)
        {
            _s.Values[key] = text;
            if (_v.Find(key) is TextBlock tb) tb.Text = text;
        }

        // The rows of ids that can be turned on and off (a dynamic child follows its main command):
        List<int> Own(IEnumerable<int> ids) => ids.Where(i => !IsDyn(i)).ToList();

        // Main commands or children selected: the files whose children they fold:
        List<string> FoldPaths(IEnumerable<int> ids) =>
            ids.Where(i => Kids(i) > 0 || IsChild(i)).Select(i => Cell(_rows[i], CPath)).Distinct(Ic).ToList();

        public void Refresh()
        {
            Enable("onf", Own(_sel).Count > 0);
            Enable("aonf", Own(_vis).Count > 0);
            Enable("doc", _sel.Count > 0);
            Enable("lsp", _sel.Count > 0);
            Enable("fld", ShowKids && FoldPaths(_sel).Count > 0);
            Enable("fal", ShowKids && FoldPaths(_vis).Count > 0);
            Enable("aln", _acmd != null);
            Enable("aad", _acmd != null);
            bool picked = _acmd != null && _alsList != null && _alsList.SelectedIndex >= 0;
            Enable("aren", picked);
            Enable("adel", picked);
        }

        void Enable(string key, bool on)
        {
            if (_v.Find(key) is FrameworkElement fe) fe.IsEnabled = on && !_s.Off.Contains(key);
        }

        // What the Lisp gets back (with ste/rows and ste/als, kept up to date as they are):
        void Out()
        {
            _s.Values["ste.opens"] = string.Join("|", _opens);
            _s.Values["ste.mod"] = _modVal;
            _s.Values["ste.grp"] = _grpVal;
            _s.Values["ste.sel"] = string.Join(" ", _sel.Select(i => i.ToString(CultureInfo.InvariantCulture)));
        }

        // ---- Changes ----

        public void Changed(string key)
        {
            switch (key)
            {
                case "lst":
                    _sel = _items.Where(it => _list.SelectedItems.Contains(it)).Select(it => it.Index).ToList();
                    Info();
                    break;
                case "mod":
                    _modVal = _mod.SelectedIndex > 0 && _mod.SelectedIndex < _mods.Count ? _mods[_mod.SelectedIndex] : "";
                    _grpVal = "";
                    Groups();
                    List();
                    break;
                case "grp":
                    _grpVal = _grp.SelectedIndex > 0 && _grp.SelectedIndex <= _grps.Count ? _grps[_grp.SelectedIndex - 1] : "";
                    List();
                    break;
                case "srt":
                    Sorted();
                    List();
                    break;
                case "shw":
                case "sof":
                    Modules();
                    List();
                    break;
                case "flt":
                case "sch":
                    List();
                    break;
                case "als":
                    AliasPicked();
                    break;
                default:
                    return;
            }
            Out();
        }

        public bool Click(Button b)
        {
            switch (b.Name)
            {
                case "onf": Switch(_sel, null); break;
                case "aonf": Switch(_vis, null); break;
                case "fld": FoldSel(); break;
                case "fal": FoldAll(); break;
                case "doc": OpenDocs(_sel); break;
                case "lsp": OpenLisp(_sel); break;
                case "clr": Clear(); break;
                case "aad": AliasAdd(); break;
                case "aren": AliasRename(); break;
                case "adel": AliasRemove(); break;
                default: return false;
            }
            Out();
            return true;
        }

        // Clear: every module, Show All, no search:
        void Clear()
        {
            _modVal = "";
            _grpVal = "";
            _v.Quiet(() =>
            {
                if (_v.Find("shw") is ComboBox shw) shw.SelectedIndex = 0;
                if (_v.Find("flt") is TextBox flt) flt.Text = "";
            });
            _s.Values["shw"] = "0";
            _s.Values["flt"] = "";
            Modules();
            List();
        }

        // On/Off: the commands ids turned on when one of them is off, off when they are all
        // on (to: "1" or "0", the value of a checkbox clicked). A main command gives its value
        // to its dynamic children:
        void Switch(List<int> ids, string to)
        {
            ids = Own(ids);
            if (ids.Count == 0) { List(); return; }
            to = to ?? (ids.Any(i => !IsOn(i)) ? "1" : "0");
            var mains = new HashSet<string>(Ic);
            foreach (int i in ids)
            {
                _rows[i][COn] = to;
                if (Cell(_rows[i], CIsMain) == "1") mains.Add(Cell(_rows[i], CPath));
            }
            for (int j = 0; j < _rows.Count; j++)
                if (IsDyn(j) && mains.Contains(Cell(_rows[j], CPath))) _rows[j][COn] = to;
            // Show: On or Off, or the commands turned off hidden: the list changes; else the
            // lines are updated in place (the list keeps its scroll):
            if (Shw == 1 || Shw == 2 || !ShowOff) List();
            else { foreach (int i in _vis) Line(i); Info(); }
            Out();
        }

        // ---- Folding ----

        // Folds or unfolds the children of the main command of the file path; unfolded, the
        // main command goes to the top of the list, so its children can be seen:
        void Fold(string path)
        {
            bool open = !_opens.Contains(path);
            if (open) _opens.Add(path); else _opens.Remove(path);
            List();
            if (open) Top(MainOf(path));
            Out();
        }

        int MainOf(string path)
        {
            for (int i = 0; i < _rows.Count; i++)
                if (Ic.Equals(Cell(_rows[i], CPath), path) && Kids(i) > 0 && !IsChild(i)) return i;
            return -1;
        }

        // Fold/Unfold: the main commands of the lines selected, a child standing for its main
        // command; folded when one of them is unfolded, unfolded otherwise. The main command
        // is selected too, so it stays selected once its children are folded:
        void FoldSel()
        {
            var paths = FoldPaths(_sel);
            if (paths.Count == 0) return;
            bool open = !paths.Any(_opens.Contains);
            foreach (var p in paths)
            {
                if (open) _opens.Add(p); else _opens.Remove(p);
                int m = MainOf(p);
                if (m >= 0 && !_sel.Contains(m)) _sel.Add(m);
            }
            List();
            var tops = paths.Select(MainOf).Where(_vis.Contains).OrderBy(_vis.IndexOf).ToList();
            if (open && tops.Count > 0) Top(tops[0]);
        }

        // Fold/Unfold All: the main commands listed, unfolded when one of them is folded, else
        // all folded:
        void FoldAll()
        {
            var paths = FoldPaths(_vis);
            if (paths.Count == 0) return;
            if (paths.Any(p => !_opens.Contains(p))) foreach (var p in paths) _opens.Add(p);
            else foreach (var p in paths) _opens.Remove(p);
            List();
        }

        // The row i at the top of the list (the list scrolls by lines):
        void Top(int i)
        {
            if (i < 0 || !_vis.Contains(i)) return;
            _list.UpdateLayout();
            var sv = Scroller(_list);
            if (sv != null && sv.CanContentScroll) sv.ScrollToVerticalOffset(_vis.IndexOf(i));
            else _list.ScrollIntoView(_items[i]);
        }

        static ScrollViewer Scroller(DependencyObject d)
        {
            if (d is ScrollViewer sv) return sv;
            for (int k = 0; k < VisualTreeHelper.GetChildrenCount(d); k++)
                if (Scroller(VisualTreeHelper.GetChild(d, k)) is ScrollViewer s) return s;
            return null;
        }

        // ---- Docs and Lisp files ----

        // The docs pages of the commands ids, each page once; the page the first one without
        // a page would have is said:
        void OpenDocs(List<int> ids)
        {
            var targets = new List<string>();
            string miss = null;
            foreach (int i in ids)
            {
                string t = Cell(_rows[i], CDocs);
                if (t.Length == 0) { if (miss == null) miss = Cell(_rows[i], CHint); }
                else if (!targets.Contains(t, Ic)) targets.Add(t);
            }
            if (miss != null) _pth = "No docs page: " + miss;
            Shell(targets);
            Info();
        }

        // The Lisp files of the commands ids, each file once:
        void OpenLisp(List<int> ids)
        {
            var files = new List<string>();
            foreach (int i in ids)
            {
                string f = Cell(_rows[i], CLisp);
                if (f.Length == 0) { _pth = "File not found: Modules\\" + Cell(_rows[i], CPath); continue; }
                if (!files.Contains(f, Ic)) files.Add(f);
            }
            Shell(files);
            Info();
        }

        // Opens the targets with their Windows association (Notepad when that fails); more
        // than 10 at once is refused (likely a wrong selection):
        void Shell(List<string> targets)
        {
            if (targets.Count > MaxOpen) { _pth = targets.Count + " files to open: select " + MaxOpen + " items or fewer"; return; }
            foreach (var t in targets)
            {
                try { Session.OpenTarget(t); }
                catch
                {
                    if (t.StartsWith("http", StringComparison.OrdinalIgnoreCase)) { _pth = "Unable to open " + t; continue; }
                    try { Process.Start(new ProcessStartInfo("notepad.exe", "\"" + t + "\"") { UseShellExecute = true }); }
                    catch (Exception e) { _pth = "Unable to open " + t + ": " + e.Message; }
                }
            }
        }

        // ---- Aliases ----

        // The panel for the selection: the aliases of the one command selected:
        void Aliases()
        {
            int r = _sel.Count == 1 ? _sel[0] : -1;
            _acmd = r >= 0 && Command(r).Length > 0 ? Command(r) : null;
            _alst = AliasesOf(_acmd);
            var shown = _alst.Select(a => IsCommand(a) ? a + "  (also a command)" : a).ToList();
            _v.Quiet(() =>
            {
                if (_alsList != null) { _alsList.ItemsSource = shown; _alsList.SelectedIndex = -1; }
                if (_aln != null) _aln.Text = "";
            });
            string taken = _alst.Select(a => _taken.TryGetValue(a, out string w) ? a + " is already " + w + ": rename it." : null)
                                .FirstOrDefault(x => x != null);
            Say(_acmd == null ? "Select one command to edit its aliases."
                : _alst.Count == 0 && IsChild(r) && Cell(_rows[r], CPreset) == "1" ? "A child command runs by its aliases: add one."
                : !IsOn(r) ? "Aliases run once the command is turned on."
                : _alst.Count == 0 ? "No alias yet: type one and click Add."
                : taken ?? "Pick an alias to rename or remove it.");
        }

        bool IsCommand(string name) => _rows.Any(x => Ic.Equals(Cell(x, CCmd), name));

        void Say(string msg) => Text("ams", msg);

        void AliasPicked()
        {
            int i = _alsList?.SelectedIndex ?? -1;
            if (i < 0 || i >= _alst.Count) return;
            _v.Quiet(() => { if (_aln != null) _aln.Text = _alst[i]; });
            Say("");
        }

        string Typed()
        {
            string a = (_aln?.Text ?? "").Trim().ToUpperInvariant();
            return a.StartsWith("C:") ? a.Substring(2) : a;
        }

        // Why the alias a cannot be given (old: the alias renamed), null when it can:
        string AliasProblem(string a, string old)
        {
            if (a.Length == 0) return "Type an alias name.";
            if (!a.All(c => (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || c == '-' || c == '_')) return "Use letters, digits, - and _ only.";
            if (a.StartsWith("DYL-") || a.StartsWith("LM-") || a.StartsWith("PST-")) return "An alias is a short name: no Dyl-, LM- or Pst- prefix.";
            if (a == old) return "The name did not change.";
            if (a == _acmd) return "This is the name of the command itself.";
            var x = _als.FirstOrDefault(p => p.Length > 1 && Ic.Equals(p[0], a));
            if (x != null) return a + " is already an alias of " + x[1] + ".";
            var c = _rows.FirstOrDefault(r => Ic.Equals(Cell(r, CCmd), a));
            if (c != null) return a + " is already a command: Modules\\" + Cell(c, CPath);
            if (_taken.TryGetValue(a, out string what)) return a + " is already " + what + ".";
            return null;
        }

        // The aliases of the command changed: its lines and the panel again, the message:
        void AliasDone(string msg)
        {
            string cmd = _acmd;
            if (Sort == 1) Sorted();
            if (Shw == 3) List();
            else { foreach (int i in _vis.Where(i => Ic.Equals(Command(i), cmd))) Line(i); Info(); }
            Say(msg);
        }

        void AliasAdd()
        {
            if (_acmd == null) return;
            string a = Typed(), err = AliasProblem(a, null);
            if (err != null) { Say(err); return; }
            _als.Add(new[] { a, _acmd });
            AliasDone(a + " added.");
        }

        string PickedAlias => _alsList != null && _alsList.SelectedIndex >= 0 && _alsList.SelectedIndex < _alst.Count ? _alst[_alsList.SelectedIndex] : null;

        void AliasRename()
        {
            string old = PickedAlias, a = Typed();
            if (old == null) { Say("Pick the alias to rename."); return; }
            string err = AliasProblem(a, old);
            if (err != null) { Say(err); return; }
            var p = _als.FirstOrDefault(x => x.Length > 1 && Ic.Equals(x[0], old) && Ic.Equals(x[1], _acmd));
            if (p != null) p[0] = a;
            AliasDone(old + " renamed " + a + ".");
        }

        void AliasRemove()
        {
            string old = PickedAlias;
            if (old == null) { Say("Pick the alias to remove."); return; }
            _als.RemoveAll(x => x.Length > 1 && Ic.Equals(x[0], old) && Ic.Equals(x[1], _acmd));
            AliasDone(old + " removed.");
        }
    }
}
