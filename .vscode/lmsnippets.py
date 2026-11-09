"""Regenerate .vscode/LM-LocalSub and LM-RemoteSub code snippets from LM-Sub.lsp.

Usage: python lmsnippets.py <bundle dir>
Existing Remote bodies/descriptions are kept (hand-tuned); Local bodies always
come from LM-Sub.lsp; existing non-empty descriptions are kept.
"""
import json
import re
import sys
from collections import OrderedDict

root = sys.argv[1]
src = f"{root}/Contents/Modules/LeeMac/Remote/LM-Sub.lsp"
loc_out = f"{root}/.vscode/LM-LocalSub.code-snippets"
rem_out = f"{root}/.vscode/LM-RemoteSub.code-snippets"

text = open(src, encoding="utf-8").read().replace("\r\n", "\n")
lines = text.split("\n")
offs = [0]
for l in lines:
    offs.append(offs[-1] + len(l) + 1)


def form_end(pos):
    """Index just past the s-expression starting at text[pos] == '('."""
    depth, i, n = 0, pos, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while text[i] != '"':
                i += 2 if text[i] == "\\" else 1
        elif c == ";":
            if text.startswith(";|", i):
                i = text.index("|;", i + 2) + 1
            else:
                i = text.index("\n", i)
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError(pos)


def line_of(pos):
    lo, hi = 0, len(offs) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if offs[mid] <= pos:
            lo = mid
        else:
            hi = mid - 1
    return lo


SEP = re.compile(r"^;;-*=\{.*\}=-*;;\s*$")


def header(ln):
    """Comment block right above line ln (blank lines between are allowed)."""
    i = ln - 1
    while i >= 0 and not lines[i].strip():
        i -= 1
    out = []
    while i >= 0 and lines[i].lstrip().startswith(";") and not lines[i].startswith(";#") and not SEP.match(lines[i]):
        out.insert(0, lines[i].rstrip())
        i -= 1
    return out


# ---- parse LM-Sub.lsp ------------------------------------------------------
funcs = []  # dicts: name, region, header, code, args
regions = []
for ln, l in enumerate(lines):
    m = re.match(r";#region (.*)", l)
    if m:
        regions.append(m.group(1).strip())
        continue
    if l.startswith(";#endregion"):
        regions.pop()
        continue
    m = re.match(r"\(defun (\S+)\s*(?:\(([^)]*)\)|nil\b)", text[offs[ln]:offs[ln] + 2000]) if l.startswith("(defun") else None
    if not m:
        continue
    name = m.group(1)
    end = form_end(offs[ln])
    code = text[offs[ln]:end]
    if not name.startswith("Remote>>"):
        # Unprefixed helper (md5:*): goes with the function before it in Local
        funcs[-1]["code"] += "\n\n" + code
        funcs[-1]["helpers"].append(name)
        continue
    args = (m.group(2) or "").split("/")[0].split()
    funcs.append(dict(name=name, region=regions[-1] if regions else "", header=header(ln),
                      code=code, args=args, helpers=[]))

# Defined twice: AutoCAD keeps the last definition, so do the snippets
last = {f["name"]: f for f in funcs}
dupes = sorted({f["name"] for f in funcs if last[f["name"]] is not f}, key=str.lower)
funcs = [f for f in funcs if last[f["name"]] is f]
names = set(last)


def title_desc(f):
    # strip the ;; on both sides (boxed headers end their lines with ;;)
    h = [re.sub(r"\s*;;\s*$", "", re.sub(r"^\s*;+", "", x)).strip() for x in f["header"]]
    title = ""
    m = re.search(r"=\{\s*(.*?)\s*\}=", h[0]) if h else None
    if m:
        title = m.group(1)
        h = h[1:]
    elif h and re.search(r"\s-\s+\S", h[0]):
        title = re.sub(r"\s+-\s+.*$", "", h[0]).strip()
        h = h[1:]
    h = [x for x in h if x and not re.fullmatch(r"-+", x)]
    return title or f["name"].split(":", 1)[1], "\n".join(h)


def renumber(body):
    """Old snippets used $name variables; make them numbered ${n:name} tab stops."""
    n = iter(range(1, 100))
    return [re.sub(r"\$([A-Za-z_]\w*)", lambda m: f"${{{next(n)}:{m.group(1)}}}", b) for b in body]


def deps(f):
    used = set(re.findall(r"Remote>>[\w:\-+>~*!?<=.]+", f["code"]))
    used = {u for u in used if u in names and u != f["name"]}
    # nested defuns in the body are not dependencies
    used -= set(re.findall(r"\(defun (Remote>>\S+)", f["code"]))
    return sorted(used, key=str.lower)


# ---- read existing snippets (lenient: tolerate missing commas) -------------
def read_jsonc(path):
    try:
        s = open(path, encoding="utf-8").read()
    except FileNotFoundError:
        return {}
    toks, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == '"':
            j = i + 1
            while s[j] != '"':
                j += 2 if s[j] == "\\" else 1
            tok = s[i:j + 1]
            i = j + 1
        elif s.startswith("//", i):
            i = s.index("\n", i)
            continue
        elif c.isspace():
            i += 1
            continue
        else:
            tok = c
            i += 1
        # missing comma between members / elements
        if toks and toks[-1][-1] in '"}]' and tok[0] in '"{[':
            toks.append(",")
        if tok in "}]" and toks and toks[-1] == ",":
            toks.pop()
        toks.append(tok)
    return json.loads("".join(toks))


def by_prefix(d):
    return {v["prefix"]: v for v in d.values()}


old_loc = by_prefix(read_jsonc(loc_out))
old_rem = by_prefix(read_jsonc(rem_out))


def esc(s):
    return s.replace("$", "\\$")


# ---- build -----------------------------------------------------------------
def write(path, head, entries):
    """entries: list of (region, key, snippet dict)."""
    used, out, reg = set(), [], None
    for region, key, snip in entries:
        if region != reg:
            out.append(("comment", f"// region {region}"))
            reg = region
        k, i = key, 2
        while k in used:
            k, i = f"{key} ({i})", i + 1
        used.add(k)
        out.append(("entry", k, snip))
    buf = head + ["{"]
    last = max(i for i, o in enumerate(out) if o[0] == "entry")
    for i, o in enumerate(out):
        if o[0] == "comment":
            buf.append("\t" + o[1])
            continue
        _, k, snip = o
        body = ",\n".join("\t\t\t" + json.dumps(b, ensure_ascii=False) for b in snip["body"])
        buf.append(f"\t{json.dumps(k)}: {{\n\t\t\"prefix\": {json.dumps(snip['prefix'])},\n"
                   f"\t\t\"body\": [\n{body}\n\t\t],\n"
                   f"\t\t\"description\": {json.dumps(snip['description'], ensure_ascii=False)}\n"
                   f"\t}}{',' if i < last else ''}")
    buf.append("}")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(buf) + "\n")


loc, rem = [], []
for f in funcs:
    title, desc = title_desc(f)
    short = f["name"][len("Remote>>"):]
    dl = deps(f)
    req = ("\nRequires: " + ", ".join("Local>>" + d[len("Remote>>"):] for d in dl)) if dl else ""

    p = "Local>>" + short
    o = old_loc.get(p)
    body = "\n".join(f["header"] + [""] + [f["code"]]).replace("Remote>>", "Local>>").split("\n")
    loc.append((f["region"], title, dict(
        prefix=p, body=[esc(b) for b in body],
        description=((o and o["description"]) or desc).replace("Remote>>", "Local>>") + req)))

    p = "Remote>>" + short
    o = old_rem.get(p)
    call = " ".join([f["name"]] + [f"${{{i}:{a.split('>>')[-1].split(':')[-1]}}}" for i, a in enumerate(f["args"], 1)])
    rem.append((f["region"], title, dict(
        prefix=p, body=renumber(o["body"]) if o else [f"({call})"],
        description=(o and o["description"]) or desc)))
    if f["args"]:
        p += "/a"
        o = old_rem.get(p)
        rem.append((f["region"], f"(Apply) {title}", dict(
            prefix=p, body=renumber(o["body"]) if o else [f"(apply '{f['name']} ${{1:lst}})"],
            description=(o and o["description"]) or f"Apply {short} to an argument list"
                        + (f" ({' '.join(a.split('>>')[-1] for a in f['args'])})" if f["args"] else ""))))

write(loc_out, ["// Dynalisp snippets: local copies of the Lee Mac subfunctions (LM-Sub.lsp)",
                "// Generated from Contents/Modules/LeeMac/Remote/LM-Sub.lsp; the Remote>> prefix is renamed Local>>.",
                "// \"Requires\" in the description lists the other Local>> functions to insert with it."], loc)
write(rem_out, ["// Dynalisp snippets: calls to the built-in Remote Lee Mac subfunctions (LM-Sub.lsp)",
                "// Generated from Contents/Modules/LeeMac/Remote/LM-Sub.lsp; <prefix>/a is the apply form."], rem)

gone = [p for p in list(old_loc) + list(old_rem)
        if p.split("/a")[0].replace("Local>>", "Remote>>") not in names]
print(len(funcs), "functions;", len(loc), "local,", len(rem), "remote snippets")
print("defined more than once (last kept):", [d[len("Remote>>"):] for d in dupes])
print("old prefixes with no function in LM-Sub.lsp:", gone)
