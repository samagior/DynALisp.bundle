// TransferCombos.cs - the Level, From and To drop-downs, after the Layer Transfer button
// Copyright (C) 2026  Samuel Martineau, GNU General Public License v3 (see Plugin.cs)
//
// A layer of the NCS (United States National CAD Standard) is named
//   discipline designator - major group - minor groups - status:  A-Wall-Full-E
// (see NcsName below). Three drop-downs, each after its label, choose the transfer of the
// Layer Transfer button: the objects selected go from one value of a level (field) of their
// layer name to another, the other levels kept:
//   - Level: Discipline designator, Major group, Minor group or Status,
//   - From: Any, or a value of that field found in the layers of the drawing (None / Unphased:
//     the layers without a minor group / without a status),
//   - To: the values of the drawing, then the other values of the AEC lists of DynALisp
//     (Res\AEC\Standard: Dd1 + Dd2, Major, Phase; the minor groups of the drawing only, the
//     list of Minor.csv being too long), and None / Unphased.
// The lists follow the layers of the current drawing: they are read again when a drawing is
// made current and after each command. Picking a value only chooses it: the Layer Transfer
// button runs Pst-TransferField of Dyl-LayerTransfer.lsp on the objects selected (it asks for
// them when none is selected), which reads the choice with (Dyl:RibbonTransfer).

using System;
using System.Collections.Generic;
using System.Linq;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;

namespace DynALisp.Ribbon
{
    public class TransferCombos : Part
    {
        // After the Layer Transfer button, which runs Pst-TransferField (Ribbon.csv):
        public override string ButtonId => "RBN_DYL_CMD_PST_TRANSFERFIELD";
        public override string Command => "PST-TRANSFERFIELD";

        public static readonly TransferCombos Part = new TransferCombos();

        // (Dyl:RibbonTransfer): the transfer chosen in the drop-downs, (level from to): level
        // "Discipline", "Major", "Minor" or "Status", from nil for any value, "" for the layers
        // without one, to "" to remove the level. nil while no To value is picked.
        [LispFunction("Dyl:RibbonTransfer")]
        public static object RibbonTransfer(ResultBuffer args)
        {
            var p = Part;
            if (p._dst == null) return null;
            return new ResultBuffer(
                new TypedValue((int)LispDataType.Text, p._fld),
                p._src == Any ? new TypedValue((int)LispDataType.Nil) : new TypedValue((int)LispDataType.Text, p._src),
                new TypedValue((int)LispDataType.Text, p._dst));
        }

        const string Any = "\u0001";   // the tag of Any (From)

        static readonly (string Tag, string Text)[] Fields =
        {
            ("Discipline", "Discipline designator"), ("Major", "Major group"), ("Minor", "Minor group"), ("Status", "Status"),
        };

        RibbonCombo _field, _from, _to;
        bool _updating;
        string _fld = "Status";          // the field
        string _src = Any;               // From: Any, "" none, or a value
        string _dst;                     // To: the value picked last (null: none yet)
        string _sig;                     // the layers and lists shown (to rebuild only on a change)
        List<string> _layers = new List<string>();

        public override RibbonRowPanel Build()
        {
            _field = Host.Combo("DYL_TRANSFER_FIELD", "Layer Transfer: the level of the layer names to change.");
            foreach (var f in Fields) _field.Items.Add(Host.Item(f.Text, f.Tag));
            _field.CurrentChanged += OnField;
            _from = Host.Combo("DYL_TRANSFER_FROM", "Layer Transfer: the value of the layers to transfer (Any: every layer).");
            _from.CurrentChanged += OnFrom;
            _to = Host.Combo("DYL_TRANSFER_TO", "Layer Transfer: the value to give the layers. The Layer Transfer button transfers the objects selected.");
            _to.CurrentChanged += OnTo;
            _sig = null;
            var labels = Host.Labels("Level:", "From:", "To:");
            return Host.Rows("DYL_TRANSFER_DROPDOWNS",
                new RibbonItem[] { labels[0], _field }, new RibbonItem[] { labels[1], _from }, new RibbonItem[] { labels[2], _to });
        }

        public override void DocumentChanged() => Refresh();
        public override void CommandEnded() => Refresh();

        // ---- the layer names ----

        // The fields of an NCS layer name: discipline designator (1 or 2 letters), major group
        // (4 characters), minor groups (4 characters each, none or more), status (1 character,
        // optional). False for any other name, and for the layers of the xrefs. Same rule as
        // Dyl-LayTransfer-Ncs of Dyl-LayerTransfer.lsp.
        public static bool NcsName(string lay, out string disc, out string major, out List<string> minors, out string status)
        {
            disc = major = status = null;
            minors = null;
            if (lay.Contains('|')) return false;
            var p = lay.Split('-');
            if (p.Length < 2 || p[0].Length < 1 || p[0].Length > 2 || !p[0].All(char.IsLetter) || p[1].Length != 4) return false;
            int end = p.Length;
            if (p.Length > 2 && p[^1].Length == 1) status = p[--end];
            for (int i = 2; i < end; i++)
                if (p[i].Length != 4) return false;
            disc = p[0];
            major = p[1];
            minors = p.Skip(2).Take(end - 2).ToList();
            return true;
        }

        List<string> ReadLayers()
        {
            var names = new List<string>();
            var doc = Host.Doc;
            if (doc == null) return names;
            using (var tr = doc.Database.TransactionManager.StartOpenCloseTransaction())
            {
                var lt = (LayerTable)tr.GetObject(doc.Database.LayerTableId, OpenMode.ForRead);
                foreach (ObjectId id in lt)
                    if (!id.IsErased) names.Add(((LayerTableRecord)tr.GetObject(id, OpenMode.ForRead)).Name);
                tr.Commit();
            }
            return names;
        }

        // The values of the field in the layers (first spelling found), and whether some
        // layers have none (no minor group, no status):
        List<string> Values(out bool none)
        {
            var seen = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            none = false;
            foreach (var lay in _layers)
            {
                if (!NcsName(lay, out var d, out var mj, out var mn, out var st)) continue;
                IEnumerable<string> vals = _fld switch
                {
                    "Discipline" => new[] { d },
                    "Major" => new[] { mj },
                    "Minor" => mn,
                    _ => st == null ? Array.Empty<string>() : new[] { st },
                };
                if ((_fld == "Minor" && mn.Count == 0) || (_fld == "Status" && st == null)) none = true;
                foreach (var v in vals)
                    if (!seen.ContainsKey(v)) seen[v] = v;
            }
            return seen.Values.ToList();
        }

        // The values of the AEC lists for the field (code, description):
        List<KeyValuePair<string, string>> StandardValues() => _fld switch
        {
            "Discipline" => Host.Standard("Dd1").Concat(Host.Standard("Dd2")).ToList(),
            "Major" => Host.Standard("Major"),
            "Minor" => Host.Standard("Minor"),
            _ => PhaseCombos.Phases,
        };

        string NoneText => _fld == "Status" ? "Unphased" : "None";

        // ---- the drop-downs ----

        public override void Refresh()
        {
            if (Row == null) return;
            try { _layers = ReadLayers(); } catch { }
            var vals = Values(out bool none);
            var std = StandardValues();
            string sig = _fld + "\n" + (none ? "1" : "0") + "\n" + string.Join("\n", vals) + "\n" + std.Count + "\n" +
                         string.Join("\n", std.Select(s => s.Key));
            _updating = true;
            try
            {
                _field.Current = _field.Items.OfType<RibbonItem>().FirstOrDefault(it => (string)it.Tag == _fld);
                if (sig == _sig) return;
                _sig = sig;

                var desc = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                var order = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
                foreach (var s in std)
                {
                    if (!desc.ContainsKey(s.Key)) desc[s.Key] = s.Value;
                    if (!order.ContainsKey(s.Key)) order[s.Key] = order.Count;
                }
                // the values of the drawing in the order of the AEC list, the others after them:
                vals = vals.OrderBy(v => order.TryGetValue(v, out int i) ? i : int.MaxValue)
                           .ThenBy(v => v, StringComparer.OrdinalIgnoreCase).ToList();
                string Label(string v) => desc.TryGetValue(v, out var d) && d != "" ? v + " - " + d : v;

                _from.Items.Clear();
                _from.Items.Add(Host.Item("Any", Any));
                if (none) _from.Items.Add(Host.Item(NoneText, ""));
                foreach (var v in vals) _from.Items.Add(Host.Item(Label(v), v));

                _to.Items.Clear();
                foreach (var v in vals) _to.Items.Add(Host.Item(Label(v), v));
                if (_fld != "Minor")
                    foreach (var s in std)
                        if (!vals.Contains(s.Key, StringComparer.OrdinalIgnoreCase)
                            && !_to.Items.OfType<RibbonItem>().Any(it => string.Equals((string)it.Tag, s.Key, StringComparison.OrdinalIgnoreCase)))
                            _to.Items.Add(Host.Item(Label(s.Key), s.Key));
                if (_fld == "Minor" || _fld == "Status") _to.Items.Add(Host.Item(NoneText, ""));

                // From keeps its value while the drawing has it:
                var from = _from.Items.OfType<RibbonItem>().FirstOrDefault(it => string.Equals((string)it.Tag, _src, StringComparison.OrdinalIgnoreCase));
                if (from == null) { _src = Any; from = _from.Items.OfType<RibbonItem>().First(); }
                _from.Current = from;
                // To keeps the value picked (the transfer may have added layers):
                RibbonItem to = _dst == null ? null
                    : _to.Items.OfType<RibbonItem>().FirstOrDefault(it => string.Equals((string)it.Tag, _dst, StringComparison.OrdinalIgnoreCase));
                if (to == null) _dst = null;
                _to.Current = to;
                Resize();
            }
            catch (System.Exception ex) { Host.Log(ex.Message); }
            finally { _updating = false; }
        }

        void OnField(object sender, RibbonPropertyChangedEventArgs e)
        {
            if (_updating || !(_field.Current is RibbonItem it) || (string)it.Tag == _fld) return;
            _fld = (string)it.Tag;
            _src = Any;
            _dst = null;
            Refresh();
        }

        void OnFrom(object sender, RibbonPropertyChangedEventArgs e)
        {
            if (_updating || !(_from.Current is RibbonItem it)) return;
            _src = (string)it.Tag;
        }

        // A fixed width, 1.5 times the Phase drop-downs (a long item is read whole in the list
        // when it opens):
        public void Resize()
        {
            if (Row != null) Host.FixWidth(Math.Ceiling(1.5 * PhaseCombos.Width), _field, _from, _to);
        }

        void OnTo(object sender, RibbonPropertyChangedEventArgs e)
        {
            if (_updating || !(_to.Current is RibbonItem it)) return;
            _dst = (string)it.Tag;
        }
    }
}
