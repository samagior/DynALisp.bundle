# BuildSite.py - the DynALisp docs website
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Docs\BuildSite.py <folder>
#
# Builds the docs website in <folder>, published on GitHub Pages
# (https://samagior.github.io/DynALisp.docs/) by .github/workflows/docs.yml, which pushes it
# to the public repository samagior/DynALisp.docs. The docs are edited only here: the
# website is a copy of them, made again on every push to main, never edited in DynALisp.docs.
# Needs the markdown package (pip install markdown).
#
# Two sets, a switch between them in the header of every page (User Guide | Developers):
#
#   <folder>\index.html             the User Guide home: the modules (index.fr.html in French,
#                                   index.<code>.html for each language of BuildDocs.LANGS),
#                                   and a search box filtering the tools of every module
#   <folder>\<Module>\...           the User Guide: Contents\Modules\<Module>\Docs
#   <folder>\dev\index.html         the Developer home: README.md
#   <folder>\dev\conventions.html   CONVENTIONS.md
#   <folder>\dev\<Module>\...       the Developer docs: Contents\Modules\<Module>\DevDocs
#   <folder>\dev\licences\...       the licences the README links to
#   <folder>\docs.css, images\, README.md, .nojekyll
#
# Every relative link of a page is pointed to the place of its target on the website (a
# guide page linking to its dev page, the stylesheet...). The switch of a page leads to the
# page of the other set for the same tool when it has one, else to the home of that set.
# The pictures a guide page names (<!-- picture: images/<Page>-window.png -->) are shown once
# their file is in the images folder beside the page; its -dark copy (<Page>-window-dark.png),
# when there is one, in dark mode.
#
# A page already in <folder> is kept, even when the docs no longer have it (renamed, moved,
# deleted): an installed DynALisp opens the pages of its own version, which stay on the
# website. Only the pages the docs have are written again.
#
# The pages are the ones git knows (never those of MyTools, ignored) of the modules of
# DocsPages.txt (BuildDocs.py): run BuildDocs.py first. DynALisp opens a guide page of the
# list on the website (Dyl:DocsTarget of dynalisp.mnl).

import html
import json
import os
import re
import shutil
import sys

import BuildDocs

try:
    import markdown
except ImportError:
    markdown = None

REPO = BuildDocs.REPO
MODULES = BuildDocs.MODULES
PAGES = BuildDocs.PAGES
RESOURCES = os.path.join(REPO, 'Contents', 'Resources')
URL = 'https://samagior.github.io/DynALisp.docs/'
RELEASES = 'https://github.com/samagior/DynALisp.release/releases/latest'
VIEWPORT = '<meta name="viewport" content="width=device-width, initial-scale=1">'

# The Markdown files rendered on the website: (source, page on the website, title):
MARKDOWN = [('README.md', 'dev/index.html', 'DynALisp for Developers'),
            ('CONVENTIONS.md', 'dev/conventions.html', 'DynALisp Conventions'),
            (os.path.join('Contents', 'Modules', 'LeeMac', 'LEE-MAC-LICENCE.md'), 'dev/licences/LEE-MAC-LICENCE.html',
             'Lee Mac Licence')]
# Other files the pages link to, copied to the website:
FILES = [(os.path.join('Contents', 'Resources', 'docs.css'), 'docs.css'),
         (os.path.join('Contents', 'Resources', 'Icons', 'dynalisp-banner-readme.svg'), 'images/dynalisp-banner.svg')]
# The links of the Markdown files to what is not on the website: their address (or None:
# the text is kept, without its link):
OUTSIDE = {'CHANGELOG.MD': RELEASES,
           'LICENSE': 'https://www.gnu.org/licenses/gpl-3.0.html',
           'LICENCES/LEE-MAC-LICENCE.MD': 'dev/licences/LEE-MAC-LICENCE.html'}

# The texts of the site in each language of BuildDocs.LANGS (English for another one):
TEXTS = {'en': {'guide': 'User Guide', 'dev': 'Developers',
                'footer': 'DynALisp &ndash; released under the GNU General Public License v3',
                'search': 'Search the tools', 'hint': 'Name, command, alias or keyword',
                'tool': 'Tool', 'desc': 'Description',
                'found': ['No tool found', '1 tool found', '{n} tools found']},
         'fr': {'guide': 'Guide d\'utilisation', 'dev': 'D&eacute;veloppeurs',
                'footer': 'DynALisp &ndash; publi&eacute; sous la licence publique g&eacute;n&eacute;rale GNU v3',
                'search': 'Rechercher un outil', 'hint': 'Nom, commande, alias ou mot-clé',
                'tool': 'Outil', 'desc': 'Description',
                'found': ['Aucun outil trouvé', '1 outil trouvé', '{n} outils trouvés']}}
HEADER = '<p>DynALisp <span>Docs</span></p>'
LINK = re.compile(r'((?:href|src)=")([^"#:]*)((?:#[^"]*)?")')


def text(code, key):
    return TEXTS.get(code, TEXTS['en'])[key]


def home_file(code):
    """The User Guide home of a language: index.html in English, index.<code>.html otherwise
    (the name Dyl:DocsAll opens)."""
    return 'index.html' if code == 'en' else 'index.%s.html' % code


def norm(path):
    return os.path.normcase(os.path.normpath(path))


def site_of(src):
    """The place on the website (a path with /) of the source file src (a full path), None
    when the website does not have it."""
    rel = os.path.relpath(src, REPO).split(os.sep)
    if len(rel) > 4 and rel[0] == 'Contents' and rel[1] == 'Modules' and rel[3] in ('Docs', 'DevDocs'):
        return '/'.join((['dev'] if rel[3] == 'DevDocs' else []) + [rel[2]] + rel[4:])
    for s, d, *_ in MARKDOWN + FILES:
        if norm(src) == norm(os.path.join(REPO, s)):
            return d
    return None


def relative(target, frm):
    """The link from the page frm to target, both places on the website."""
    return os.path.relpath(target, os.path.dirname(frm) or '.').replace(os.sep, '/')


def fix_links(text_, src, dst, missing):
    """Every relative link of the page src (on the website at dst) pointed to the place of
    its target on the website. A target the website does not have is listed in missing."""
    def sub(m):
        file = m.group(2)
        if not file:
            return m.group(0)
        target = site_of(os.path.normpath(os.path.join(os.path.dirname(src), file)))
        if target is None:
            missing.append((dst, file))
            return m.group(0)
        return m.group(1) + relative(target, dst) + m.group(3)
    return LINK.sub(sub, text_)


def set_nav(dst, code, kind, twin, indent):
    """The switch User Guide | Developers of the page dst (on the website): the page of the
    other set for the same tool (twin, a place on the website or None), else its home."""
    other = twin or ('dev/index.html' if kind == 'guide' else home_file(code))
    items = []
    for k in ('guide', 'dev'):
        label = text(code, k)
        if k == kind:
            items.append('<span class="on">%s</span>' % label)
        else:
            items.append('<a href="%s">%s</a>' % (relative(other, dst), label))
    return indent + '<nav class="set" aria-label="Docs">' + ''.join(items) + '</nav>'


def add_nav(text_, nav):
    """The switch in the header of the page, after its language switch."""
    i = text_.find(HEADER)
    if i < 0:
        return text_
    j = text_.find('</nav>', i)
    k = text_.find('</div>', i)
    at = j + len('</nav>') if 0 <= j < k else i + len(HEADER)
    return text_[:at] + '\n' + nav + text_[at:]


def show_pictures(text_, src):
    """The pictures the page names, shown when their file is beside it."""
    title = re.search(r'<h1>(.*?)</h1>', text_, re.S)
    title = BuildDocs.text_of(title.group(1)) if title else ''

    def sub(m):
        name = m.group(1)
        if not os.path.exists(os.path.join(os.path.dirname(src), *name.split('/'))):
            return m.group(0)
        what = 'sample use' if name.lower().endswith('.gif') else 'window'
        img = '<img src="%s" alt="%s">' % (html.escape(name), html.escape('%s: %s' % (title, what)))
        # The picture of the window in the dark theme beside it (<Page>-window-dark.png, drawn
        # by Installer\Windows\Shots), shown in dark mode:
        dark = name[:-4] + '-dark' + name[-4:]
        if os.path.exists(os.path.join(os.path.dirname(src), *dark.split('/'))):
            img = '<picture><source srcset="%s" media="(prefers-color-scheme: dark)">%s</picture>' % (html.escape(dark), img)
        return '<figure class="shot">%s</figure>' % img
    return BuildDocs.PICTURE.sub(sub, text_)


def page(text_, src, dst, kind, twin, missing):
    """A page of the docs for the website."""
    code = BuildDocs.lang_of(src)[0]
    text_ = fix_links(text_, src, dst, missing)
    if kind == 'guide':
        text_ = show_pictures(text_, src)
    m = re.search(r'\n([ \t]*)' + re.escape(HEADER), text_)
    text_ = add_nav(text_, set_nav(dst, code, kind, twin, m.group(1) if m else '        '))
    if 'name="viewport"' not in text_:
        text_ = text_.replace('<meta charset="utf-8">', '<meta charset="utf-8">\n    ' + VIEWPORT, 1)
    return text_


def template(dst, code, kind, title, body, twin=None, langs=True):
    """A page of the website made here (the homes, the Markdown files)."""
    nav = ''
    if langs:
        if kind == 'guide':
            nav = ('\n        <nav class="lang" aria-label="Language">'
                   + ''.join('<span class="on" title="%s">%s</span>' % (name, label) if c == code
                             else '<a href="%s" hreflang="%s" lang="%s" title="%s">%s</a>'
                             % (home_file(c), c, c, name, label)
                             for c, _, label, name, _ in BuildDocs.LANGS)
                   + '</nav>')
        else:
            nav = ('\n        <nav class="lang" aria-label="Language">'
                   + ''.join('<span class="on" title="%s">%s</span>' % (name, label) if c == 'en'
                             else '<span class="off" title="The developer docs are in English only">%s</span>' % label
                             for c, _, label, name, _ in BuildDocs.LANGS)
                   + '</nav>')
    return ('<!DOCTYPE html>\n<html lang="%s">\n<head>\n    <meta charset="utf-8">\n    %s\n'
            '    <title>%s</title>\n    <link rel="stylesheet" href="%s">\n</head>\n<body>\n'
            '    <div id="header">\n        %s%s\n%s\n    </div>\n'
            '    <div id="content"%s>\n%s\n    </div>\n'
            '    <div id="footer"><p>%s</p></div>\n</body>\n</html>\n'
            % (code, VIEWPORT, html.escape(title), relative('docs.css', dst), HEADER, nav,
               set_nav(dst, code, kind, twin, '        '), ' class="md"' if kind == 'dev' else '', body,
               text(code, 'footer')))


def module_indexes(pages, code):
    """{module: (path, title, sentence)} of the module indexes of DocsPages.txt in the
    language code, the English one for a module without an index in that language."""
    suf = next(s for c, s, *_ in BuildDocs.LANGS if c == code)
    idx = {}
    for path, t, s in pages:
        mod, _, rest = path.partition('/')
        if rest == 'index.htm':
            idx.setdefault(mod, (path, t, s))
        elif suf and rest == 'index%s.htm' % suf:
            idx[mod] = (path, t, s)
    return idx


ROW = re.compile(r'<tr[^>]*><td><a href="([^"#:]+\.htm)[^"]*">(.*?)</a></td>(.*?)</tr>', re.S)
HEADING = re.compile(r'<h([23])>(.*?)</h\1>', re.S)
FIXW = re.compile(r'<span class="fixw">(.*?)</span>', re.S)


def plain(fragment):
    return html.unescape(BuildDocs.text_of(fragment))


def command_names(fragments):
    """The commands and aliases named in fixw in the html fragments, each once (never a
    pattern such as Pst-*, a path or a file)."""
    names = []
    for frag in fragments:
        for n in FIXW.findall(frag):
            n = plain(n)
            if re.fullmatch(r'[\w-]+', n) and n.upper() not in (x.upper() for x in names):
                names.append(n)
    return names


def tools(pages, code):
    """The tools of every module for the search box of the home in the language code:
    [title, link, module, group, commands, description, words], read from the rows of the
    module indexes (the group: their h3, else their h2) and from each page: its h1, its
    commands and aliases (the syntax of its index row, its Function Syntax and its table of
    command names and aliases, whose names go in words), and its description (the paragraphs
    of its first h2; the first paragraph after its h1 when it has no h2)."""
    out, seen = [], set()
    listed = {p for p, *_ in pages}
    for mod, (path, mtitle, _) in sorted(module_indexes(pages, code).items(),
                                         key=lambda i: (i[0].upper() != 'DYNALISP', i[0].upper())):
        src = os.path.join(MODULES, mod, 'Docs', *path.split('/')[1:])
        with open(src, encoding='utf-8') as f:
            index = f.read()
        heads = [(m.start(), plain(m.group(2))) for m in HEADING.finditer(index)]
        for m in ROW.finditer(index):
            link = mod + '/' + m.group(1)
            if link not in listed or link in seen:
                continue
            seen.add(link)
            group = ''
            for at, h in heads:
                if at < m.start():
                    group = h
            with open(os.path.join(MODULES, mod, 'Docs', *m.group(1).split('/')), encoding='utf-8') as f:
                text_ = f.read()
            h1 = re.search(r'<h1>(.*?)</h1>', text_, re.S)
            title = plain(h1.group(1)) if h1 else plain(m.group(2))
            syntax = re.search(r'<td>Function Syntax</td>\s*<td>(.*?)</td>', text_, re.S)
            block = re.search(r'<!-- dyl:aliases -->(.*?)<!-- /dyl:aliases -->', text_, re.S)
            rows = re.findall(r'<tr><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td></tr>', block.group(1), re.S) if block else []
            names = command_names([m.group(3), syntax.group(1) if syntax else ''] + [r[0] + r[1] for r in rows])
            h2 = re.search(r'<h2[^>]*>.*?</h2>(.*?)(?=<h2|$)', text_, re.S)
            paras = [plain(x) for x in re.findall(r'<p>(.*?)</p>', h2.group(1) if h2 else '', re.S)]
            if not paras:
                first = re.search(r'<p>(.*?)</p>', text_[h1.end():] if h1 else text_, re.S)
                paras = [plain(first.group(1))] if first else []
            words = ' '.join(dict.fromkeys(plain(r[2]) for r in rows if plain(r[2]).upper() != title.upper()))
            out.append([title, link, mtitle or mod, group, ' '.join(names), ' '.join(paras), words])
    return out


SEARCH_JS = """(function () {
  var box = document.getElementById('search'), q = document.getElementById('q'),
      found = document.getElementById('found'), res = document.getElementById('results'),
      body = res.querySelector('tbody'), mods = document.getElementById('modules'),
      tools = JSON.parse(document.getElementById('tools').textContent),
      words = JSON.parse(box.getAttribute('data-found'));
  function fold(s) {
    return s.normalize('NFD').replace(/[\\u0300-\\u036f]/g, '').toLowerCase();
  }
  tools.forEach(function (t) {
    t.name = fold(t[0]); t.cmds = fold(t[4]);
    t.all = fold(t.join(' '));
    var i = t[5].search(/[.!?](\\s|$)/);
    t.short = i < 0 ? t[5] : t[5].slice(0, i + 1);
  });
  function cell(tr) {
    var td = document.createElement('td');
    tr.appendChild(td);
    return td;
  }
  function show() {
    var terms = fold(q.value).split(/\\s+/).filter(Boolean);
    body.textContent = '';
    if (!terms.length) {
      res.hidden = true; mods.hidden = false; found.textContent = '';
      return;
    }
    function all(s) { return terms.every(function (w) { return s.indexOf(w) >= 0; }); }
    var hits = tools.filter(function (t) { return all(t.all); }).map(function (t) {
      return [all(t.name) ? 0 : all(t.cmds) ? 1 : 2, t];
    }).sort(function (a, b) { return a[0] - b[0] || a[1][0].localeCompare(b[1][0]); });
    hits.forEach(function (h) {
      var t = h[1], tr = document.createElement('tr'), td = cell(tr), a = document.createElement('a');
      a.href = t[1]; a.textContent = t[0]; td.appendChild(a);
      var where = document.createElement('span');
      where.className = 'where'; where.textContent = t[2] + (t[3] ? ' \\u00b7 ' + t[3] : '');
      td.appendChild(where);
      cell(tr).textContent = t.short;
      body.appendChild(tr);
    });
    var n = hits.length;
    found.textContent = (n > 1 ? words[2] : words[n]).replace('{n}', n);
    res.hidden = !n; mods.hidden = true;
  }
  function keep() {
    try {
      var u = new URL(location.href);
      if (q.value) { u.searchParams.set('q', q.value); } else { u.searchParams.delete('q'); }
      history.replaceState(null, '', u);
    } catch (e) {}
  }
  q.addEventListener('input', function () { show(); keep(); });
  q.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { q.value = ''; show(); keep(); }
    if (e.key === 'Enter') {
      var a = body.querySelector('a');
      if (a) { location.href = a.href; }
    }
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === '/' && document.activeElement !== q && !/INPUT|TEXTAREA/.test(document.activeElement.tagName)) {
      e.preventDefault(); q.focus();
    }
  });
  try { q.value = new URLSearchParams(location.search).get('q') || ''; } catch (e) {}
  box.hidden = false;
  show();
})();"""


def search_box(pages, code):
    """The search box of the home: the tools as JSON in the page, filtered as the user types
    (every word in the name, the commands, the module, the group or the description, accents
    and case ignored), the module table hidden while it shows results. Without JavaScript
    the box stays hidden and the home is the module table alone. (box, script): the script
    goes after the module table, which it hides."""
    data = json.dumps(tools(pages, code), ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    found = html.escape(json.dumps(text(code, 'found'), ensure_ascii=False), quote=True)
    return ('<div class="search" id="search" data-found="%s" hidden>\n'
            '<label for="q">%s</label>\n'
            '<input type="search" id="q" placeholder="%s" autocomplete="off" spellcheck="false" aria-describedby="found">\n'
            '<p class="found" id="found" aria-live="polite"></p>\n</div>\n'
            '<div class="programs commands wide" id="results" hidden>\n<table>\n<thead><tr><th>%s</th><th>%s</th></tr></thead>\n'
            '<tbody></tbody>\n</table>\n</div>\n'
            % (found, text(code, 'search'), html.escape(text(code, 'hint')), text(code, 'tool'), text(code, 'desc')),
            '\n<script type="application/json" id="tools">%s</script>\n<script>\n%s\n</script>' % (data, SEARCH_JS))


def guide_home(pages, code):
    """The User Guide home in the language code: the search box of the tools, then the
    modules, the Dynalisp module first, each one its index in that language when it has one."""
    idx = module_indexes(pages, code)
    mods = sorted(idx, key=lambda m: (m.upper() != 'DYNALISP', m.upper()))
    rows = ''.join('<tr><td><a href="%s">%s</a></td><td>%s</td></tr>\n' % (html.escape(idx[m][0]), idx[m][1] or m, idx[m][2])
                   for m in mods)
    box, script = search_box(pages, code)
    body = ('        <h1>DynALisp Docs</h1>\n%s<div class="programs commands wide" id="modules">\n<table>\n'
            '<tr><th>Module</th><th>Description</th></tr>\n%s</table>\n</div>%s' % (box, rows, script))
    return template(home_file(code), code, 'guide', 'DynALisp Docs', body)


def render_md(src, dst, title, devmods, missing):
    """A Markdown file of the repository as a page of the Developer docs."""
    with open(os.path.join(REPO, src), encoding='utf-8') as f:
        md = f.read()
    body = markdown.markdown(md, extensions=['tables', 'fenced_code', 'toc', 'sane_lists'])

    def sub(m):
        file = m.group(2)
        if not file:
            return m.group(0)
        target = site_of(os.path.normpath(os.path.join(REPO, os.path.dirname(src), file)))
        if target is None:
            target = OUTSIDE.get(file.replace('\\', '/').upper())
            if target and target.startswith('http'):
                return m.group(1) + target + m.group(3)
        if target is None:
            missing.append((dst, file))
            return m.group(1) + '#' + m.group(3)
        return m.group(1) + relative(target, dst) + m.group(3)
    body = LINK.sub(sub, body)
    # A link to nothing on the website keeps its text only:
    body = re.sub(r'<a href="#">(.*?)</a>', r'\1', body)
    box = ('<p class="devnav"><strong>Developer docs</strong> &ndash; <a href="%s">Conventions</a>%s'
           ' &middot; <a href="%s">User Guide</a></p>\n'
           % (relative('dev/conventions.html', dst),
              ''.join(' &middot; <a href="%s">%s</a>' % (relative(p, dst), html.escape(t)) for p, t in devmods),
              relative('index.html', dst)))
    if not body.lstrip().startswith('<h1'):
        body = '<h1>%s</h1>\n%s' % (html.escape(title), body)
    i = body.find('</h1>') + len('</h1>')
    return template(dst, 'en', 'dev', title, body[:i] + '\n' + box + body[i:])


README = """# DynALisp Docs

The documentation of [DynALisp](https://github.com/samagior/DynALisp.release), published at
{url}: the **User Guide** (what each tool does and how to use it) and the **Developer docs**
(`dev/`: how the code works).

This repository is **generated**: every push to the main branch of the DynALisp source
rebuilds it (`Installer/Docs/BuildSite.py`, `.github/workflows/docs.yml`). Do not edit it
here: a change made here is overwritten by the next publication. A page the docs no longer
have is kept, for the versions of DynALisp installed that still open it.

The pages of the LeeMac sample module are copies of the help pages of Lee Mac's programs,
delivered for consistency purposes only: the programs and their descriptions are the work
of Lee Mac (https://www.lee-mac.com), who keeps all the credit for them, and each page
links to its original.
"""


def inside(path, folder):
    """True when path is folder or a folder under it (False on another drive)."""
    try:
        return os.path.commonpath([norm(path), norm(folder)]) == norm(folder)
    except ValueError:
        return False


def write(out, dst, content):
    d = os.path.join(out, *dst.split('/'))
    os.makedirs(os.path.dirname(d), exist_ok=True)
    with open(d, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)


def main():
    if len(sys.argv) != 2:
        sys.exit('Usage: python Installer\\Docs\\BuildSite.py <folder>')
    if markdown is None:
        sys.exit('The markdown package is needed: pip install markdown')
    out = os.path.abspath(sys.argv[1])
    releases = os.path.join(REPO, 'Releases')
    # Outside the repository, or in a folder of its own under Releases (never Releases itself,
    # which holds the build of the setup):
    if inside(out, REPO) and not (inside(out, releases) and norm(out) != norm(releases)):
        sys.exit('Build the website outside the repository, or in a folder under Releases: ' + out)
    pages = read_pages()
    known = BuildDocs.git_files()
    mods = sorted({p.split('/')[0] for p, *_ in pages})
    os.makedirs(out, exist_ok=True)
    missing = []
    count = {'guide': 0, 'dev': 0}
    # The files of both sets, and the twin of each page (the same tool in the other set):
    files = []
    for mod in mods:
        for folder, kind in (('Docs', 'guide'), ('DevDocs', 'dev')):
            src_dir = os.path.join(MODULES, mod, folder)
            for root, _, names in os.walk(src_dir):
                for name in names:
                    s = os.path.join(root, name)
                    if norm(s) in known:
                        files.append((s, kind))
    have = {norm(s) for s, _ in files}
    for s, kind in files:
        dst = site_of(s)
        d = os.path.join(out, *dst.split('/'))
        os.makedirs(os.path.dirname(d), exist_ok=True)
        if not s.lower().endswith('.htm'):
            shutil.copyfile(s, d)
            continue
        t = BuildDocs.twin(s)
        twin = site_of(t) if norm(t) in have else None
        if twin is None:
            # no page of the other set for this tool: the index of its module in that set
            mod = BuildDocs.kind_of(s)[0]
            idx = os.path.join(MODULES, mod, 'DevDocs' if kind == 'guide' else 'Docs', 'index.htm')
            twin = site_of(idx) if norm(idx) in have else None
        with open(s, encoding='utf-8', newline='') as f:
            content = f.read()
        with open(d, 'w', encoding='utf-8', newline='') as f:
            f.write(page(content, s, dst, kind, twin, missing))
        count[kind] += 1
    for s, d in FILES:
        d = os.path.join(out, *d.split('/'))
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copyfile(os.path.join(REPO, s), d)
    for code, *_ in BuildDocs.LANGS:
        write(out, home_file(code), guide_home(pages, code))
    # The dev index of each module, linked from the box of the dev home:
    devmods = []
    for mod in mods:
        idx = os.path.join(MODULES, mod, 'DevDocs', 'index.htm')
        if norm(idx) in have:
            with open(idx, encoding='utf-8') as f:
                h1 = re.search(r'<h1>(.*?)</h1>', f.read(), re.S)
            devmods.append((site_of(idx), html.unescape(BuildDocs.text_of(h1.group(1))) if h1 else mod))
    for src, dst, title in MARKDOWN:
        write(out, dst, render_md(src, dst, title, devmods, missing))
    write(out, 'README.md', README.format(url=URL))
    open(os.path.join(out, '.nojekyll'), 'w').close()
    for dst, file in missing:
        print('Not on the website: %s links to %s' % (dst, file))
    print('Docs website built in %s: %d guide pages, %d dev pages written, the pages already there kept.'
          % (out, count['guide'], count['dev']))


def read_pages():
    """The pages of DocsPages.txt: [(path, title, sentence)], title and sentence for an index."""
    out = []
    with open(PAGES, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\r\n')
            if line and not line.startswith('#'):
                path, *info = line.split('\t')
                out.append((path, *(info + ['', ''])[:2]))
    return out


if __name__ == '__main__':
    main()
