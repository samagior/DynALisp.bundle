// HatchTab.cs - DynALisp.Core.Data: the Hatch Presets window, its values and what it gives back
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
// The Hatch Presets window (Res\Dyl-HatchPresets.xaml, the tab Hatch Presets of the Manager and
// the open buttons of a hatch preset), as the preset engine of Remote\Dyl-Presets.lsp ran it on
// the spec of Remote>>Dyl:HatchPresetDlg (Remote\Dyl-Materials.lsp), shown by
// DynALisp.Windows.dll (Dyl:HatchWindow) without the Lisp. What every preset window does is in
// PresetTab; here the App part, each step named after the Lisp function it gives what of,
// checked by the witness files (sections hptab). That Lisp (the spec of the window and its
// functions in Dyl-Materials.lsp) is gone: what it gave is kept in
// Installer\Core\Tests\Witness\Kept, and git keeps its code:
//   HatchTab.Open      Remote>>Dyl:PresetDialog          the hatch presets read, the one shown
//   HatchTab.Prep      Remote>>Dyl:HatchPresetWinPrep    the patterns (HatchPresetPats), the
//                                                        layer keys
//   HatchTab.More      Remote>>Dyl:HatchPresetWinVals    the lists of the window
//   HatchTab.WinGet    Remote>>Dyl:HatchPresetWinGet     a Model hatch never annotative
//   HatchTab.ValueCheck  Remote>>Dyl:MaterialDlgCheck    why a value is not valid
// What stays in the Lisp: the patterns found on the support path (Remote>>Dyl:SupportDefs) and
// their units (Remote>>Dyl:MaterialPatUnits), the layer keys (their names given), the buttons
// that pick in the drawing or open another window (the codes of Remote>>Dyl:MaterialTabCode).

using System;
using System.Collections.Generic;
using System.Linq;

namespace DynALisp.Core.Data
{
    public sealed class HatchTab : PresetTab
    {
        public static PresetSpec Spec => Presets.HatchPreset;
        public override PresetSpec Tool => Spec;
        protected override string Title => "Hatch Presets";
        protected override string Noun => "hatch presets";
        public override string[] NewRow => New;
        protected override string TilesText => Tiles;

        // *hp:new*: a new hatch preset, ANSI31 on the layer key HATCH:
        public static readonly string[] New =
            new[] { "", "", "New hatch preset", "ANSI31", "1.0", "1.0", "0", "THIN", "HATCH", "1", "0", "1" }.Concat(Materials.Extra).ToArray();

        // *mt:tiles* and their column, the name and the group first (Remote>>Dyl:PresetWinTiles),
        // the pattern, the layer key and the linetype in upper case:
        public const string Tiles = "nam:2,grp:1,pat:3:up,typ:63,simp:4,ang:6,hat:8:up,ano:9,sdw:10,hco:22,hcl:23,hbo:24,hbg:25,"
                                  + "hwo:26,hwt:27,hto:28,htr:29,asc:30,hxo:41,hxb:42,hlo:47,hlt:48:up,hso:49,hsc:50";

        static readonly (string, int)[] TileCols =
        {
            ("pat", 3), ("typ", 63), ("simp", 4), ("ang", 6), ("hat", 8), ("ano", 9), ("sdw", 10), ("hco", 22), ("hcl", 23),
            ("hbo", 24), ("hbg", 25), ("hwo", 26), ("hwt", 27), ("hto", 28), ("htr", 29), ("asc", 30), ("hxo", 41), ("hxb", 42),
            ("hlo", 47), ("hlt", 48), ("hso", 49), ("hsc", 50),
        };

        // *mt:types*:
        public static readonly string[] Types = { "Drafting", "Model" };

        // The patterns found on the support path (mt:found: the names of the .pat files, upper
        // case, sorted), the units of a pattern (Remote>>Dyl:MaterialPatUnits):
        public List<string> Found;
        public readonly Shows.PatUnits Pats;

        // What Prep makes besides the groups: the patterns of the Pattern list (mt:pats, made
        // once for the window), the layer keys (mt:keys):
        public List<string> PatList, Keys;

        HatchTab(Bundle b, Units u, List<string> defined, IEnumerable<string> found, Shows.PatUnits pats) : base(b, u, defined)
        {
            Found = (found ?? Enumerable.Empty<string>()).ToList();
            Pats = pats ?? (p => null);
        }

        // (Remote>>Dyl:PresetDialog "HatchPreset" (Remote>>Dyl:HatchPresetDlg id)) up to the
        // window: the hatch presets read (Remote>>Dyl:HatchPresetRead), the one shown that of id
        // select (else the one shown last, last, else the first), the Show group shw (the
        // DynalispPresetShowHatchPreset setting), the sort srt of the session; the layer keys
        // defined and the patterns found on the support path. null when the Lisp reads the
        // hatch presets (a materials file of DynALisp 1.1, a default file missing):
        public static HatchTab Open(Bundle b, Units u, string select, int? last, string shw, string srt,
                                    List<string> defined, IEnumerable<string> found, Shows.PatUnits pats)
        {
            var both = Materials.Both(b, u.Dimzin);
            if (both == null) return null;
            var t = new HatchTab(b, u, defined, found, pats);
            t.Init(both.Value.Hatches, Materials.HatchDefs(b, u.Dimzin), select, last, shw, srt);
            return t;
        }

        // (Remote>>Dyl:HatchPresetPats): the patterns found, then those of the defaults and of
        // the hatch presets that no .pat file has (each one in front of the list when it is not
        // in it), SOLID and ANSI31 always; sorted as acad_strlsort sorts them, None ("") first:
        public static List<string> PatListOf(IEnumerable<string> found, IEnumerable<string[]> defs, IEnumerable<string[]> lst)
        {
            var pats = found.ToList();
            foreach (var nam in new[] { "SOLID", "ANSI31" }.Concat(defs.Select(r => Lisp.Nth(r, 3))).Concat(lst.Select(r => Lisp.Nth(r, 3))))
                if (nam != null && !pats.Contains(nam)) pats.Insert(0, nam);
            return new[] { "" }.Concat(pats.Where(p => p != "").OrderBy(p => p, Aliases.Order)).ToList();
        }

        // The patterns whose units the window needs (those of the Pattern list, SOLID and none
        // left out), found by the Lisp (Remote>>Dyl:MaterialPatUnits) on the patterns found on
        // its support path; null when the Lisp reads the hatch presets:
        public static List<string> Patterns(Bundle b, int dimzin, IEnumerable<string> found)
        {
            var both = Materials.Both(b, dimzin);
            if (both == null) return null;
            return PatListOf(found ?? Enumerable.Empty<string>(), Materials.HatchDefs(b, dimzin), both.Value.Hatches)
                   .Where(p => p != "" && p != "SOLID").ToList();
        }

        // A pattern added to the Pattern list (a hatch picked in the drawing,
        // Remote>>Dyl:MaterialPickHatch), and one found once it was rebuilt
        // (Remote>>Dyl:MaterialPatRebuild):
        public void AddPat(string p)
        {
            if (string.IsNullOrEmpty(p) || PatList == null || PatList.Contains(p)) return;
            PatList = new[] { "" }.Concat(PatList.Where(x => x != "").Concat(new[] { p }).OrderBy(x => x, Aliases.Order)).ToList();
        }

        public void AddFound(string p)
        {
            if (!string.IsNullOrEmpty(p) && !Found.Contains(p)) Found.Insert(0, p);
        }

        // (Remote>>Dyl:PresetWinPrep) with (Remote>>Dyl:HatchPresetWinPrep): the groups of the
        // Group list, the patterns (once), the layer keys (those defined, then those of the
        // defaults and of the hatch presets that are not):
        public override void Prep()
        {
            PrepGroups();
            if (PatList == null) PatList = PatListOf(Found, Defs, Lst);
            Keys = KeysOf(Defs.Concat(Lst).Select(r => Lisp.Nth(r, 8)));
        }

        // (Remote>>Dyl:MaterialUnitText (list "" "" "" nam)): the line under the scale:
        string UnitText(string nam)
        {
            string u = Pats(nam)?.Units;
            bool m = U.Measurement == 1;
            string pu = nam != "SOLID" ? u : null;
            double f = m && pu == "Imperial" ? 25.4 : !m && pu == "Metric" ? 1.0 / 25.4 : 1.0;
            if (u == null) return "Pattern file not found: scale as is.";
            if (f > 1.0) return u + " pattern: x25.4 here (metric).";
            if (f < 1.0) return u + " pattern: /25.4 here (imperial).";
            return u + " pattern, like this drawing.";
        }

        static bool NoPat(string n) => n == "" || n == "SOLID";

        // The values of Remote>>Dyl:HatchPresetWinVals (wvals), after those of every preset
        // window:
        protected override void More(List<WinVal> res)
        {
            res.Add(WinVal.L("pat/list", PatList.Select(n => n == "" ? "None" : Found.Contains(n) ? n : n + "   (not found on the support path)")));
            res.Add(WinVal.L("pat/vals", PatList));
            res.Add(WinVal.R("sunt/by", PatList.Select(n => new[] { NoPat(n) ? "" : UnitText(n) })));
            res.Add(WinVal.R("pfl/by", PatList.Select(n => new[] { !NoPat(n) && Pats(n) != null ? "1" : "0" })));
            res.Add(WinVal.S("pst/hatch", "3,4,6,9,10,63"));
            res.Add(WinVal.R("pst/pats", PatList.Where(n => !NoPat(n)).Select(n =>
            {
                var pu = Pats(n);
                return new[] { n, pu?.File ?? "", pu?.Units == "Metric" ? "1" : "0" };
            })));
            res.Add(WinVal.S("pst/ds", Lisp.NumP(U.DrawScale, 6, U.Dimzin)));
            res.Add(WinVal.L("typ/list", Types));
            res.Add(WinVal.L("typ/vals", Types));
            res.Add(WinVal.L("hat/list", Marked(Keys)));
            res.Add(WinVal.L("hat/vals", Keys));
            res.Add(WinVal.L("hwt/list", Weights.Select(w => Lisp.Rtos(int.Parse(w) / 100.0, 2, U.Dimzin) + " mm")));
            res.Add(WinVal.L("hwt/vals", Weights));
            res.Add(WinVal.S("sinf", "This drawing is at 1:" + Lisp.NumP(U.DrawScale, 4, U.Dimzin) + ": hatch scale x"
                                     + Lisp.NumP(U.DrawScale, 4, U.Dimzin) + "."));
        }

        // (Remote>>Dyl:HatchPresetWinGet r): a Model hatch is never annotative nor adaptive,
        // whatever its checkboxes, greyed out, still hold:
        protected override string[] WinGet(string[] r) =>
            Lisp.Nth(r, 63) == "Model" ? Lisp.Subst(Lisp.Subst(r, 9, "0"), 10, "0") : r;

        protected override (string Key, int Col)[] Checks => TileCols;

        // (Remote>>Dyl:MaterialDlgCheck key val) for the values of the window:
        protected override string ValueCheck(string key, string val)
        {
            switch (key)
            {
                case "hat": return val == "" ? "The layer key cannot be empty." : null;
                case "simp": return !(Lisp.Distof(val) is double s && s > 0) ? "The scale must be a number greater than 0." : null;
                case "hcl":
                case "hbg":
                case "hxb":
                    return ColorParse(val) == null
                        ? "A color is an AutoCAD color number 1-255 or r,g,b (0-255 each), or use the open button beside it." : null;
                case "hlt": return val == "" ? "The linetype cannot be empty." : null;
                case "hsc": return !Assemblies.ScaleP(val) ? "The linetype scale must be a number greater than 0." : null;
                case "htr":
                    return !(IsDigits(val, 1, 2) && int.Parse(val) <= 90) ? "The transparency must be a whole number from 0 to 90." : null;
                case "ang": return Lisp.Distof(val) == null ? "The angle must be a number." : null;
            }
            return null;
        }
    }
}
