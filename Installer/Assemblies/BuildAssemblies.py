"""BuildAssemblies.py - the default assemblies of Quick Draw: the typical assemblies of the
building code (NBC Tables 9.10.3.1.-A, walls, and -B, floors), written to
Contents/Modules/Dynalisp/Res/QuickDrawAssemblies.csv, their thicknesses in millimetres.

The rows of the tables are in Walls.txt and Floors.txt beside this script (their values as the
tables give them: ratings, STC, IIC); this script builds the layers of each one from them (the
materials of Res/Materials.csv) and its description. Run it after a change to those files:

    python Installer/Assemblies/BuildAssemblies.py

Copyright (C) 2026  Samuel Martineau. GNU General Public License v3 or later (see LICENSE)."""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))

GX, GR, GP = "mt-GypsumTypeX", "mt-Gypsum", "mt-GypsumSandPlaster"
ABS, VOID = "mt-AbsorptiveMaterial", "mt-Void"
RC, SF = "mt-ResilientChannel", "mt-SteelFurring"
WOOD = "mt-WoodFrame"
PCT = {"400": "23", "600": "20", "400/600": "23"}


def layer(mat, t, bearing=False, framing=None):
    f = ["P", mat, t]
    tail = ["", "", "", "1" if bearing else "", framing or ""]
    while tail and tail[-1] == "":
        tail.pop()
    return ":".join(f + tail)


def boards(spec):
    """'2x15.9X' -> layers (and its text). X Type X, R regular, P gypsum-sand plaster."""
    out = []
    for part in spec.split("+"):
        m = re.fullmatch(r"(\d)x([\d.]+)([XRP])", part)
        if not m:
            raise ValueError(spec)
        n, t, k = int(m.group(1)), m.group(2), m.group(3)
        out += [layer({"X": GX, "R": GR, "P": GP}[k], t)] * n
    return out


def board_text(spec):
    if spec in ("-", ""):
        return "nothing"
    parts = []
    for part in spec.split("+"):
        m = re.fullmatch(r"(\d)x([\d.]+)([XRP])", part)
        n, t, k = int(m.group(1)), m.group(2), m.group(3)
        if k == "P":
            parts.append(f"{t} mm gypsum-sand plaster")
        else:
            kind = "Type X gypsum board" if k == "X" else "regular gypsum board"
            parts.append(f"{n} layer{'s' if n > 1 else ''} of {t} mm {kind}")
    return " + ".join(parts)


def minutes(v):
    """'45 min [1 h(8)]' -> ('45', 'higher text'); '-' or '<30 min' -> ''."""
    v = v.strip()
    note = ""
    m = re.search(r"\[(.*)\]", v)
    if m:
        note = m.group(1)
        v = v[: m.start()].strip()
    m = re.fullmatch(r"(.*?)\((\d+)\)", v)
    if m:
        note = note or f"note {m.group(2)}"
        v = m.group(1).strip()
    if v in ("-", "") or v.startswith("<"):
        return "", note
    m = re.fullmatch(r"([\d.]+) (h|min)", v)
    if not m:
        raise ValueError(v)
    n = float(m.group(1)) * (60 if m.group(2) == "h" else 1)
    return str(int(n)), note


def number(v):
    v = v.strip()
    note = ""
    m = re.search(r"\[(.*)\]", v)
    if m:
        note = m.group(1)
        v = v[: m.start()].strip()
    m = re.fullmatch(r"(\d+)\((\d+)\)", v)
    if m:
        note = f"note {m.group(2)}"
        v = m.group(1)
    return ("" if v in ("-", "") else v), note


def higher(note, what):
    """'1 h(8)' -> ' Higher rating 1 h under note 8.'"""
    if not note:
        return ""
    m = re.fullmatch(r"(.*?)\((\d+)\)", note)
    if m:
        return f" {what} {m.group(1).strip()} under note {m.group(2)}."
    if note.startswith("note "):
        return f" {what[0].upper() + what[1:].split(' ')[0]} under {note}."
    return f" {what} {note}."


def spacing_text(s):
    return {"400": "400 mm", "600": "600 mm", "400/600": "400 or 600 mm"}[s]


def rc_layer(fill=False):
    return layer(ABS if fill else RC, "13")


def wall(r):
    i, kind, studs, ab, rc, s1, s2, lb, nlb, stc = r
    ls, ext, desc = [], "First", ""
    side1 = boards(s1) if s1 not in ("-", "sheathing", "veneer") else []
    rcs = rc if rc != "-" else ""
    if kind == "W":
        core = [layer(ABS if ab == "89" else VOID, "89", True, f"{WOOD}~{PCT[studs]}")]
        desc = f"38x89 wood studs at {spacing_text(studs)} o.c."
    elif kind == "ST":
        core = [layer(ABS if ab == "89" else VOID, "140", True)]
        desc = "Two rows of 38x89 wood studs at 400 or 600 mm o.c., staggered on a 38x140 plate."
    elif kind == "DP":
        a = ab in ("both", "one")
        core = [layer(ABS if a else VOID, "89", True, f"{WOOD}~23"), layer(VOID, "25"),
                layer(ABS if ab == "both" else VOID, "89", True, f"{WOOD}~23")]
        desc = "Two rows of 38x89 wood studs at 400 or 600 mm o.c. on separate 38x89 plates 25 mm apart."
    elif kind in ("EW", "EW140"):
        d = "140" if kind == "EW140" else "89"
        core = [layer(ABS, d, True, f"{WOOD}~{PCT[studs]}")]
        desc = f"Exterior wall, 38x{d} wood studs at {spacing_text(studs)} o.c."
        ext = "Last"
    elif kind.startswith("SN"):
        d = kind[2:]
        core = [layer(ABS if ab != "0" else VOID, d)]
        desc = f"Non-load-bearing steel studs 31x{d} at {spacing_text(studs)} o.c."
    elif kind == "SL":
        core = [layer(ABS if ab != "0" else VOID, "92", True)]
        desc = f"Load-bearing steel studs 41x92 at {spacing_text(studs)} o.c."
    elif kind == "SL2":
        core = [layer(ABS if ab != "0" else VOID, "92", True), layer(ABS if ab != "0" else VOID, "92", True)]
        desc = "Two rows of load-bearing steel studs 41x92 at 400 or 600 mm o.c., cross-braced."
    elif kind.startswith("B"):
        d = kind[1:]
        core = [layer(f"mt-CMU{d}", d, True)]
        desc = f"{d} mm concrete block."
    else:
        raise ValueError(kind)

    # The absorptive material:
    if kind.startswith("B"):
        pass
    elif ab in ("89", "65", "150", "140g", "89g"):
        t = ab.rstrip("g")
        desc += f" {t} mm {'glass fibre' if ab.endswith('g') else 'absorptive material'} in the cavity."
    elif ab == "both":
        desc += " 89 mm absorptive material in each row."
    elif ab == "one":
        desc += " 89 mm absorptive material in one row."
    elif ab == "0":
        desc += " No absorptive material."

    # Furring of the block walls:
    pre, post = [], []
    if kind.startswith("B"):
        fill = ab == "fill"
        if studs == "strap1":
            pre = [layer(VOID, "38")]
            desc += " 38x38 wood strapping at 600 mm o.c. on one side, absorptive material optional."
        elif studs == "strap2":
            pre = post = [layer(ABS, "38")]
            desc += " 38x38 wood strapping at 600 mm o.c. on each side, absorptive material filling the space."
        elif studs == "steel65":
            pre = post = [layer(ABS, "65")]
            desc += " 65 mm steel studs at 600 mm o.c. on each side, absorptive material filling the space."
        elif studs == "wood64":
            pre = post = [layer(ABS, "64", False, f"{WOOD}~20")]
            desc += " 38x64 wood studs at 600 mm o.c. on each side, absorptive material filling the space."
        elif studs == "zbar":
            pre = post = [layer(ABS, "50")]
            desc += " 50 mm metal Z-bars at 600 mm o.c. on each side, absorptive material filling the space."
        if rcs:
            if rcs.startswith("2@"):
                pre = post = [rc_layer()]
                desc += f" Resilient metal channels at {spacing_text(rcs[2:])} o.c. on each side, absorptive material optional."
            else:
                pre = [rc_layer(fill)]
                desc += f" Resilient metal channels at {spacing_text(rcs)} o.c. on one side" + (", absorptive material filling the space." if fill else ".")
        rcs = ""
    if rcs:
        pre = [rc_layer()]
        desc += f" Resilient metal channels at {spacing_text(rcs)} o.c. on one side."

    # The faces:
    if s2 == "sheathing":
        side2 = [layer("mt-OSB", "11")]
        desc += f" {board_text(s1)[0].upper() + board_text(s1)[1:]} on the inside; sheathing and cladding outside (any of Part 9, note 12)."
    elif s2 == "veneer":
        side2 = [layer("mt-OSB", "11"), layer("mt-AirWall20", "25"), layer("mt-Brick", "90")]
        desc += f" {board_text(s1)[0].upper() + board_text(s1)[1:]} on the inside; sheathing and masonry veneer outside (note 13)."
    elif s2.endswith("+osb"):
        side2 = [layer("mt-OSB", "12.7")] + boards(s2[:-4])
        desc += f" {board_text(s1)} on the channel side, 12.7 mm OSB and {board_text(s2[:-4])} on the other."
        desc = desc.replace(". 2 layers", ". 2 layers")
    else:
        side2 = boards(s2) if s2 != "-" else []
        if s1 == "-" and s2 == "-":
            desc += " Bare, painted on both sides (note 5)."
        elif s2 == "-":
            desc += f" {board_text(s1)[0].upper() + board_text(s1)[1:]} on one side only."
        elif s1 == s2:
            desc += f" {board_text(s1)[0].upper() + board_text(s1)[1:]} on each side."
        else:
            desc += f" {board_text(s1)[0].upper() + board_text(s1)[1:]} on one side" + (" (the side of the channels)" if pre and not kind.startswith("B") else "") + f", {board_text(s2)} on the other."
    desc = desc.replace(" (the side of the channels)", ", on the channels")
    ls = side1 + pre + core + post + side2
    lbm, lbn = minutes(lb)
    nlm, nln = minutes(nlb)
    stm, stn = number(stc)
    desc += higher(lbn, "Load-bearing rating") + higher(nln, "Non-load-bearing rating") + higher(stn, "STC")
    desc += " NBC Table 9.10.3.1.-A."
    return [f"as-{i}", "Wall", i, "|".join(ls), "1~MED", "1~THIN", ext, "mm", desc.strip().replace("; ", ", "), lbm, nlm, stm, ""]


def floor(r):
    i, kind, joists, ab, sup, ceil, fire, stc, iic = r
    ls, desc = [], ""
    if kind == "SLAB90":
        ls, desc = [layer("mt-Concrete", "90", True)], "90 mm reinforced concrete slab, 20 mm cover."
    elif kind == "SLAB130":
        ls, desc = [layer("mt-Concrete", "130", True)], "130 mm reinforced concrete slab, 25 mm cover."
    elif kind == "HOLLOW200":
        ls, desc = [layer("mt-HollowCoreSlab", "200", True)], "200 mm precast prestressed hollow core slab, 25 mm cover."
    elif kind == "DECK150":
        ls, desc = [layer("mt-Concrete", "150", True)], "150 mm composite concrete slab on a 75 mm steel deck, with welded wire mesh."
    elif kind == "OWSJ50":
        ls = [layer("mt-Concrete", "50"), layer(VOID, "300", True)]
        desc = "Open web steel joists at 400 mm o.c. with a 50 mm concrete deck; the depth of the joists is not set by the table (300 here)."
    elif kind == "CSJ65":
        ls = [layer("mt-Concrete", "65"), layer(VOID, "300", True)]
        desc = "Composite steel joists at 1250 mm o.c. with 65 mm of concrete (155 kg/m2 at least); the depth of the joists is not set by the table (300 here)."
    elif kind in ("WJ", "WJ2", "WI", "WI2"):
        two = kind.endswith("2")
        ij = kind.startswith("WI")
        sub = [layer("mt-Plywood", "11"), layer("mt-Plywood", "15.5")] if two else [layer("mt-Plywood", "15.5")]
        d = "241" if ij else "235"
        sp = "400" if joists == "400" else "600"
        what = "Wood I-joists" if ij else ("Wood joists" if kind == "WJ2" and joists == "400" else "Wood joists or I-joists")
        ls = sub + [layer(ABS if ab == "abs" else VOID, d, True)]
        desc = f"{what} at {'400 mm o.c.' if joists == '400' else '600 mm o.c. at most'} (depth not set by the table: {d} here), "
        desc += ("11 mm plywood or OSB under 15.5 mm plywood or OSB (or 17 mm T&G) subfloor" if two else "15.5 mm plywood or OSB (or 17 mm T&G) subfloor") + ", "
        desc += ("absorptive material in the cavity." if ab == "abs" else "no absorptive material.")
    else:
        raise ValueError(kind)
    if sup.startswith("RC"):
        s = sup[2:]
        ls.append(rc_layer())
        desc += f" Resilient metal channels at {s.replace('/', ' or ')} mm o.c."
    elif sup.startswith("SF"):
        ls.append(layer(SF, "22"))
        desc += f" Steel furring channels at {sup[2:]} mm o.c."
    elif sup.startswith("FC"):
        ls.append(layer(SF, "22"))
        desc += " Furring channels at 600 mm o.c. at most, wired to the joists."
    if sup == "DRC":
        a, b = ceil.split("+")
        ls += boards(a) + [rc_layer()] + boards(b)
        desc += f" {board_text(a)[0].upper() + board_text(a)[1:]} fixed to the joists, resilient metal channels at 400 or 600 mm o.c., {board_text(b)} on the channels."
    elif ceil != "-":
        ls += boards(ceil)
        desc += f" Ceiling of {board_text(ceil)}."
    fm, fn = minutes(fire)
    sm, sn = number(stc)
    im, inn = number(iic)
    desc += higher(fn, "Rating") + higher(sn, "STC") + " NBC Table 9.10.3.1.-B."
    return [f"as-{i}", "Floor", i, "|".join(ls), "1~MED", "1~THIN", "First", "mm", desc.strip().replace("; ", ", "), fm, "", sm, im]


def rows(name, fn):
    out = []
    for line in open(os.path.join(HERE, name), encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(fn(line.split(";")))
    return out


def csv(v):
    return '"' + v.replace('"', '""') + '"' if (";" in v or '"' in v) else v


if __name__ == "__main__":
    head = ["Id", "Group", "Name", "Layers", "BorderLines", "DividingLines", "Exterior", "Units",
            "Description", "FireRating", "FireRatingNLB", "STC", "IIC"]
    all_rows = rows("Walls.txt", wall) + rows("Floors.txt", floor)
    ids = [r[0] for r in all_rows]
    assert len(ids) == len(set(ids)), "repeated id"
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "Contents", "Modules", "Dynalisp", "Res", "QuickDrawAssemblies.csv")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(";".join(head) + "\n")
        for r in all_rows:
            f.write(";".join(csv(v) for v in r) + "\n")
    print(len(all_rows), "assemblies")
