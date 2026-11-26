// Presets.cs - DynALisp.Core.Data: the presets of the preset tools, read and written
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
// The preset engine of Remote\Dyl-Presets.lsp, its data part: a preset tool (Quick Draw, Quick
// Shape, the assemblies, the materials, the hatch presets) keeps its presets in a CSV file of
// the Res folder, a preset a row (id group name ...). Each function gives what the Lisp function
// it is named after gives from the same files, step for step:
//   Presets.File      Remote>>Dyl:PresetFile     the file to read (user copy, else default)
//   Presets.Csv       Remote>>Dyl:PresetCsv      its rows, as many cells as the header
//   Presets.Camel     Remote>>Dyl:PresetCamel    a name in CamelCase
//   Presets.Ids       Remote>>Dyl:PresetIds      the presets without id given one (cu-Name)
//   Presets.Clean     Remote>>Dyl:PresetClean    the rows read, cleaned
//   Presets.Read      Remote>>Dyl:PresetRead     the presets, with the defaults missing
//   Presets.DefsOf    Remote>>Dyl:MaterialDefsOf the default presets, from the default file
//   Presets.Write     Remote>>Dyl:PresetWrite    the presets written to the user copy
//   Presets.Command   Remote>>Dyl:PresetCommand  the command of a preset
// The specs are those of *dyl:presetspecs* (Remote\Dyl-QuickDrawPresets.lsp,
// Remote\Dyl-QuickShapePresets.lsp, Remote\Dyl-Materials.lsp); a test checks their headers
// against the Lisp files. What a tool does to each row (its fix: the values in capitals, the
// columns of an older file...) and its defaults are given by the tool.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace DynALisp.Core.Data
{
    // The spec of a preset tool, as its entry of *dyl:presetspecs*:
    public sealed class PresetSpec
    {
        public string Key;          // key of the tool ("QuickDraw")
        public string File;         // (file . "QuickDraw.csv"), in the Res folder
        public string[] Header;     // (header ...)
        public string Default;      // (default . "QD-*"): wcmatch of the default ids (capitals)
        public bool Blank3;         // (blank3 . T): the column 3 may be empty
        public int Head;            // (head . n): 0 without
        public string Groups;       // (groups . "Material"): null for the groups of the presets
        public string Base;         // (base . "Pst-QuickDraw"): command prefix of the defaults
        public string Cmd;          // (cmd . "Pst-QuickDrawCustom"): of the custom presets
        public string Title;        // (title . "Quick Draw")
    }

    public static class Presets
    {
        static readonly string[] Border =
        {
            "BorderColorOn", "BorderColor", "BorderLinetypeOn", "BorderLinetype", "BorderLtScaleOn", "BorderLtScale",
            "BorderLineweightOn", "BorderLineweight", "BorderTransparencyOn", "BorderTransparency",
        };

        static string[] Cols(params object[] parts)
        {
            var res = new List<string>();
            foreach (var p in parts)
                if (p is string s) res.Add(s);
                else res.AddRange((string[])p);
            return res.ToArray();
        }

        public static readonly PresetSpec QuickDraw = new PresetSpec
        {
            Key = "QuickDraw", File = "QuickDraw.csv", Default = "QD-*",
            Base = "Pst-QuickDraw", Cmd = "Pst-QuickDrawCustom", Title = "Quick Draw",
            Header = Cols("Id", "Group", "Name", "Material", "Method", "Override",
                          "Width", "Justify", "Sides", "ScaleWidth", "WidthFactor", "OriginOnLine", "OriginOffset",
                          "ShrinkGap", "ShrinkGapOn", "ShrinkGapMetric", "OriginAlong",
                          "OutlineKey", Border, "NoBorder",
                          "Ends", "EndExtension", "EndAngle", "Corners", "MiterLimit", "LapThrough", "Joints", "HatchFollows",
                          "AssemblyOn", "Assembly", "EndsOn", "CornersOn", "BandOn",
                          "HatchKey", "HatchColorOn", "HatchColor", "HatchLinetypeOn", "HatchLinetype",
                          "HatchLtScaleOn", "HatchLtScale", "HatchLineweightOn", "HatchLineweight",
                          "HatchTransparencyOn", "HatchTransparency", "NoHatch", "View"),
        };

        public static readonly PresetSpec QuickDrawAssembly = new PresetSpec
        {
            Key = "QuickDrawAssembly", File = "QuickDrawAssemblies.csv", Default = "AS-*", Title = "Assembly Presets",
            Header = Cols("Id", "Group", "Name", "Layers", "BorderLines", "DividingLines", "Exterior", "Units", "Description",
                          "FireRating", "FireRatingNLB", "STC", "IIC", "Family", "FamilyDescription"),
        };

        public static readonly PresetSpec QuickShape = new PresetSpec
        {
            Key = "QuickShape", File = "QuickShape.csv", Default = "QS-*",
            Base = "Pst-QuickShape", Cmd = "Pst-QuickShapeCustom", Title = "Quick Shape",
            Header = Cols("Id", "Group", "Name", "Material", "Shape", "Scale", "OutlineKey", Border, "View"),
        };

        public static readonly PresetSpec HatchPreset = new PresetSpec
        {
            Key = "HatchPreset", File = "HatchPresets.csv", Default = "HP-*", Head = 4, Blank3 = true, Title = "Hatch Presets",
            Header = Cols("Id", "Group", "Name", "Pattern", "Scale", "ScaleMetric", "Angle", "OutlineKey", "HatchKey",
                          "Annotative", "ScaleDrawing", "ScaleRef", Border,
                          "HatchColorOn", "HatchColor", "BackgroundOn", "Background", "HatchLineweightOn", "HatchLineweight",
                          "HatchTransparencyOn", "HatchTransparency",
                          "Associative", "NoBorder", "BehindBorder",
                          "Method", "Width", "Justify", "Sides",
                          "ScaleWidth", "WidthFactor", "OriginOnLine", "OriginOffset",
                          "ExistingBackgroundOn", "ExistingBackground",
                          "ShrinkGap", "ShrinkGapOn", "ShrinkGapMetric", "OriginAlong",
                          "HatchLinetypeOn", "HatchLinetype", "HatchLtScaleOn", "HatchLtScale",
                          "Ends", "EndExtension", "EndAngle", "Corners", "MiterLimit", "LapThrough", "Joints", "HatchFollows",
                          "AssemblyOn", "Assembly", "EndsOn", "CornersOn", "Type"),
        };

        public static readonly PresetSpec Material = new PresetSpec
        {
            Key = "Material", File = "Materials.csv", Default = "MT-*", Head = 4, Blank3 = true, Groups = "Material", Title = "Materials",
            Header = Cols("Id", "Group", "Name", "Cut", "Surface", "Conductivity", "Density", "Resistance", "Permeability", "Permeance"),
        };

        // The specs in the order of *dyl:presetspecs* (each Remote file puts its own first, in
        // the order the Remote files load: Dyl-Materials, Dyl-QuickDrawPresets,
        // Dyl-QuickShapePresets), which the stamps of a read follow:
        public static readonly PresetSpec[] All = { QuickShape, QuickDrawAssembly, QuickDraw, Material, HatchPreset };

        // The spec of the tool key, null for none:
        public static PresetSpec Spec(string key) => All.FirstOrDefault(s => s.Key == key);

        // (Remote>>Dyl:PresetDefault key): the default file of the tool:
        public static string Default(Bundle b, PresetSpec s) => Path.Combine(b.Res, s.File);

        // (Remote>>Dyl:PresetFile key): the user copy when there is one, else the default; with
        // Head, a user copy whose header does not begin with the first Head names of the header
        // of the tool (any case) is a file of an older version, and the default is read:
        public static string File(Bundle b, PresetSpec s)
        {
            string def = Default(b, s), fle = b.UserFile(def);
            if (string.Equals(fle, def, StringComparison.OrdinalIgnoreCase) || s.Head == 0) return fle;
            var head = b.Head(fle) ?? new string[0];
            var a = head.Take(s.Head).Select(Lisp.StrCase);
            var c = s.Header.Take(s.Head).Select(Lisp.StrCase);
            return a.SequenceEqual(c) ? fle : def;
        }

        // (Remote>>Dyl:PresetFileW key): the file to write, the user copy:
        public static string FileW(Bundle b, PresetSpec s) => b.UserFileW(Default(b, s));

        // (Remote>>Dyl:PresetCsv key): the rows of the file, as many cells as the header:
        public static List<string[]> Csv(Bundle b, PresetSpec s) => b.Rows(File(b, s), s.Header.Length);

        // (Remote>>Dyl:PresetCamel name): its letters and digits (ASCII) in CamelCase, a letter
        // made a capital after anything else ("Modular brick 2" -> "ModularBrick2"):
        public static string Camel(string name)
        {
            var sb = new System.Text.StringBuilder();
            bool up = true;
            foreach (char c in name ?? "")
            {
                bool lower = c >= 'a' && c <= 'z';
                if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || lower)
                {
                    sb.Append(up && lower ? (char)(c - 32) : c);
                    up = false;
                }
                else up = true;
            }
            return sb.ToString();
        }

        // (Remote>>Dyl:PresetIds lst): the presets without id ("") given a custom id made from
        // their name, unique in lst in any case (cu-Test, cu-Test2...); cu-Preset for a name
        // without letters or digits. The others as they are:
        public static List<string[]> Ids(List<string[]> lst)
        {
            var ids = new HashSet<string>(lst.Select(r => Lisp.StrCase(r[0])), StringComparer.Ordinal);
            var res = new List<string[]>(lst.Count);
            foreach (var r in lst)
            {
                if (r[0] != "") { res.Add(r); continue; }
                string camel = Camel(Lisp.Nth(r, 2));
                string bas = "cu-" + (camel != "" ? camel : "Preset"), id = bas;
                int i = 1;
                while (ids.Contains(Lisp.StrCase(id))) id = bas + (++i);
                ids.Add(Lisp.StrCase(id));
                res.Add(Lisp.Subst(r, 0, id));
            }
            return res;
        }

        // (assoc id lst): the first row of lst whose id is id (case counts), null for none:
        public static string[] Assoc(string id, IEnumerable<string[]> lst)
        {
            if (lst == null) return null;
            foreach (var r in lst) if (r.Length > 0 && r[0] == id) return r;
            return null;
        }

        // (Remote>>Dyl:PresetClean key rows defs): defs are the default presets of the tool (null:
        // the default ids told apart by their pattern). An id that is neither a default nor a
        // custom id (cu-...) given once is cleared; the rows without name, or without column 3
        // (unless Blank3), and the default ids given again are dropped; then the presets without
        // id get one:
        public static List<string[]> Clean(PresetSpec s, IEnumerable<string[]> rows, List<string[]> defs)
        {
            var lst = new List<string[]>();
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var r in rows)
            {
                var row = r;
                string id = row[0];
                bool known = defs != null ? Assoc(id, defs) != null : Lisp.Wcmatch(Lisp.StrCase(id), s.Default);
                if (!known && !(Lisp.Wcmatch(Lisp.StrCase(id), "CU-?*") && !seen.Contains(id)))
                    row = Lisp.Subst(row, 0, "");
                if (Lisp.Nth(row, 2) != "" && (Lisp.Nth(row, 3) != "" || s.Blank3) && (row[0] == "" || !seen.Contains(row[0])))
                {
                    lst.Add(row);
                    seen.Add(row[0]);
                }
            }
            return Ids(lst);
        }

        // (Remote>>Dyl:PresetRead key defs fix): the rows of the file through fix (null: as they
        // are), cleaned, then the default presets missing from it with their default values.
        // Kept while none of the files of the presets and of the groups changed, and given again
        // for the same fix and as many defaults; the rows given are shared: never changed by the
        // caller:
        public static List<string[]> Read(Bundle b, PresetSpec s, List<string[]> defs, Func<string[], string[]> fix)
        {
            string stamp = Stamps(b) + "|" + (defs?.Count ?? 0);
            if (b.Reads.TryGetValue(s.Key, out var o) && o is Kept k && k.Stamp == stamp && k.Fix == fix) return k.Rows;
            var rows = Csv(b, s);
            if (fix != null) rows = rows.Select(fix).ToList();
            var lst = Clean(s, rows, defs);
            if (defs != null)
            {
                var ids = new HashSet<string>(lst.Select(r => r[0]), StringComparer.Ordinal);
                foreach (var d in defs) if (!ids.Contains(d[0])) lst.Add(d);
            }
            b.Reads[s.Key] = new Kept { Stamp = stamp, Fix = fix, Rows = lst };
            return lst;
        }

        sealed class Kept
        {
            public string Stamp;
            public Func<string[], string[]> Fix;
            public List<string[]> Rows;
        }

        // (Remote>>Dyl:PresetStamps): the date and size of the file of every tool and of every
        // kind of groups (a row gets the case of its group), with the count of the writes:
        public static string Stamps(Bundle b)
        {
            var parts = All.Select(s => Bundle.Stamp(b.UserFile(Default(b, s))))
                           .Concat(Groups.Kinds.Select(k => Bundle.Stamp(b.UserFile(Groups.FileOf(b, k.Kind)))));
            return string.Join(";", parts) + "|" + b.Writes;
        }

        // (Remote>>Dyl:MaterialDefsOf key fix cache lst): the rows of the default file of the tool
        // (under Contents, never its user copy) through fix, without the rows that have no id or
        // no name; fallback when the file does not exist or has no such row:
        public static List<string[]> DefsOf(Bundle b, PresetSpec s, Func<string[], string[]> fix, List<string[]> fallback)
        {
            string fle = Default(b, s);
            if (!System.IO.File.Exists(fle)) return fallback;
            var rows = b.Rows(fle, s.Header.Length).Select(fix ?? (r => r))
                        .Where(r => r[0] != "" && Lisp.Nth(r, 2) != "").ToList();
            return rows.Count > 0 ? rows : fallback;
        }

        // (Remote>>Dyl:PresetWrite key lst): the presets written to the user copy of the file,
        // its header first, the new custom presets given their id. True once written, false when
        // it cannot be (open in Excel):
        public static bool Write(Bundle b, PresetSpec s, List<string[]> lst)
        {
            b.Reads.Clear();
            var rows = new List<IList<string>> { s.Header };
            rows.AddRange(Ids(lst));
            return b.Write(rows, FileW(b, s));
        }

        // (Remote>>Dyl:PresetCmd key id): the command of the custom preset id ("cu-Test" ->
        // "Pst-QuickDrawCustomTest"):
        public static string Cmd(PresetSpec s, string id) => s.Cmd + (id.Length > 3 ? id.Substring(3) : "");

        // (Remote>>Dyl:PresetCommand key id): the command of the preset id, default or custom;
        // null for a preset without id yet, or a tool without commands:
        public static string Command(PresetSpec s, string id)
        {
            if (id == "" || s.Cmd == null) return null;
            if (Lisp.Wcmatch(Lisp.StrCase(id), "CU-*")) return Cmd(s, id);
            return s.Base + (id.Length > 3 ? id.Substring(3) : "");
        }
    }
}
