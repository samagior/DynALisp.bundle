// Groups.cs - DynALisp.Core.Data: the groups of the presets and of the materials
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
// The groups of Remote\Dyl-Groups.lsp, each kind a file of the Res folder (its user copy, else
// the default), a group a row:
//   null        Groups.csv          the groups of the presets (Quick Draw, Quick Shape, the
//                                   assemblies, the hatch presets)
//   "Material"  MaterialGroups.csv  the groups of the materials
//   Groups.Read        Remote>>Dyl:GroupsRead        the groups of a file
//   Groups.Of          Remote>>Dyl:GroupsOf          the groups of a kind
//   Groups.DefaultsOf  Remote>>Dyl:GroupsDefaultsOf  its default groups
//   Groups.CaseOf      Remote>>Dyl:GroupCaseOf       a group as written in them
//   Groups.Write       Remote>>Dyl:GroupsWriteOf     the groups of a kind written

using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace DynALisp.Core.Data
{
    public sealed class GroupKind
    {
        public string Kind, File, Noun;
        public string[] Defaults;
    }

    public static class Groups
    {
        // *grp:kinds*, with *grp:defaults* and *grp:matdefaults*, the groups when the file cannot
        // be read:
        public static readonly GroupKind[] Kinds =
        {
            new GroupKind
            {
                Kind = null, File = "Groups.csv", Noun = "preset",
                Defaults = new[] { "Floor", "Wall", "Ceiling", "Roof", "Finish", "Structural", "Site",
                                   "Elevation", "Section", "Detail", "Annotation", "Phase", "Area", "Generic" },
            },
            new GroupKind
            {
                Kind = "Material", File = "MaterialGroups.csv", Noun = "material",
                Defaults = new[] { "Concrete", "Masonry", "Metal", "Wood", "Board", "Insulation", "Finish",
                                   "Roofing", "Site", "Air", "Phase", "Generic" },
            },
        };

        // (Remote>>Dyl:GroupsKind k): the kind k, the groups of the presets for any other k:
        public static GroupKind KindOf(string k) => (k != null ? Kinds.FirstOrDefault(x => x.Kind == k) : null) ?? Kinds[0];

        // (Remote>>Dyl:GroupsFileOf k): the default file of the kind k:
        public static string FileOf(Bundle b, string k) => Path.Combine(b.Res, KindOf(k).File);

        // (Remote>>Dyl:GroupsRead f): the groups of the file f, its rows without the empty and
        // the repeated ones (any case); empty when it has none:
        public static List<string> Read(Bundle b, string f)
        {
            var res = new List<string>();
            var seen = new HashSet<string>();
            if (f == null || !File.Exists(f)) return res;
            foreach (var r in b.Rows(f, 1))
                if (r[0] != "" && seen.Add(Lisp.StrCase(r[0]))) res.Add(r[0]);
            return res;
        }

        // (Remote>>Dyl:GroupsOf k): the groups of the kind k (the user copy of its file, else the
        // default), its defaults when it has none:
        public static List<string> Of(Bundle b, string k)
        {
            var d = KindOf(k);
            var res = Read(b, b.UserFile(FileOf(b, d.Kind)));
            return res.Count > 0 ? res : d.Defaults.ToList();
        }

        // (Remote>>Dyl:GroupsDefaultsOf k): the default groups of the kind k (its file as shipped):
        public static List<string> DefaultsOf(Bundle b, string k)
        {
            var res = Read(b, FileOf(b, k));
            return res.Count > 0 ? res : KindOf(k).Defaults.ToList();
        }

        // (Remote>>Dyl:GroupCaseOf g k): g as written in the groups of the kind k (any case),
        // else g itself:
        public static string CaseOf(Bundle b, string g, string k) => Of(b, k).FirstOrDefault(x => Lisp.SameCase(x, g)) ?? g;

        // (Remote>>Dyl:GroupsWriteOf lst k): the groups lst of the kind k written to the user copy
        // of its file. True once written, false when it cannot be:
        public static bool Write(Bundle b, IEnumerable<string> lst, string k)
        {
            var rows = new List<IList<string>> { new[] { "Group" } };
            rows.AddRange(lst.Select(g => (IList<string>)new[] { g }));
            return b.Write(rows, b.UserFileW(FileOf(b, k)));
        }
    }
}
