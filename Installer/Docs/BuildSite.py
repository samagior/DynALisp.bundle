# BuildSite.py - the DynALisp docs website
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Docs\BuildSite.py <folder>
#
# Builds the docs website in <folder>, published on GitHub Pages
# (https://samagior.github.io/DynALisp.docs/) by .github/workflows/docs.yml, which pushes it
# to the public repository samagior/DynALisp.docs. The docs are edited only here, in
# Contents\Modules\<Module>\Docs: the website is a copy of them, made again on every push
# to main, never edited in DynALisp.docs.
#
#   <folder>\<Module>\...     the Docs folder of each module (Dynalisp, LeeMac...)
#   <folder>\docs.css         Contents\Resources\docs.css, the pages pointed to it
#   <folder>\index.html       the docs of every module (as Dyl-Docs), index.<code>.html in
#                             each other language of BuildDocs.LANGS (index.fr.html)
#   <folder>\README.md, .nojekyll
#
# A page already in <folder> is kept, even when the docs no longer have it (renamed, moved,
# deleted): an installed DynALisp opens the pages of its own version, which stay on the
# website. Only the pages the docs have are written again.
#
# The pages are the ones git knows (never those of MyTools, ignored) of the modules of
# DocsPages.txt (BuildDocs.py): run BuildDocs.py first. DynALisp opens a page of the list on
# the website (Dyl:DocsTarget of dynalisp.mnl).

import html
import os
import shutil
import sys

import BuildDocs

REPO = BuildDocs.REPO
MODULES = BuildDocs.MODULES
PAGES = BuildDocs.PAGES
CSS = os.path.join(REPO, 'Contents', 'Resources', 'docs.css')
URL = 'https://samagior.github.io/DynALisp.docs/'
VIEWPORT = '<meta name="viewport" content="width=device-width, initial-scale=1">'

# The footer of the home page in each language of BuildDocs.LANGS (English for another one):
FOOTER = {'en': 'DynALisp &ndash; released under the GNU General Public License v3',
          'fr': 'DynALisp &ndash; publi&eacute; sous la licence publique g&eacute;n&eacute;rale GNU v3'}


def home_file(code):
    """The home page of a language: index.html in English, index.<code>.html otherwise (the
    name Dyl:DocsAll opens)."""
    return 'index.html' if code == 'en' else 'index.%s.html' % code


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


def page(text):
    """A page for the website: its stylesheet at the root, a viewport for phones."""
    # ../../../Resources/docs.css (a page at the top of Docs) -> ../docs.css: the module
    # folder is one level under the root, where docs.css is:
    text = text.replace('../../Resources/docs.css', 'docs.css')
    if 'name="viewport"' not in text:
        text = text.replace('<meta charset="utf-8">', '<meta charset="utf-8">\n    ' + VIEWPORT, 1)
    return text


def home(pages, code):
    """The docs of every module in the language code: the Dynalisp module first, the others
    by name, each one its index in that language when it has one."""
    suf = next(s for c, s, *_ in BuildDocs.LANGS if c == code)
    idx = {}
    for path, t, s in pages:
        mod, _, rest = path.partition('/')
        if rest == 'index.htm':
            idx.setdefault(mod, (path, t, s))
        elif suf and rest == 'index%s.htm' % suf:
            idx[mod] = (path, t, s)
    mods = sorted(idx, key=lambda m: (m.upper() != 'DYNALISP', m.upper()))
    nav = ('<nav class="lang" aria-label="Language">'
           + ''.join('<span class="on" title="%s">%s</span>' % (name, label) if c == code
                     else '<a href="%s" hreflang="%s" lang="%s" title="%s">%s</a>' % (home_file(c), c, c, name, label)
                     for c, _, label, name, _ in BuildDocs.LANGS)
           + '</nav>')
    alt = ''.join('    <link rel="alternate" hreflang="%s" href="%s">\n' % (c, home_file(c))
                  for c, *_ in BuildDocs.LANGS if c != code)
    rows = ''.join('<tr><td><a href="%s">%s</a></td><td>%s</td></tr>\n' % (html.escape(idx[m][0]), idx[m][1] or m, idx[m][2])
                   for m in mods)
    return ('<!DOCTYPE html>\n<html lang="%s">\n<head>\n    <meta charset="utf-8">\n    %s\n'
            '    <title>DynALisp Docs</title>\n    <link rel="stylesheet" href="docs.css">\n%s</head>\n<body>\n'
            '    <div id="header">\n        <p>DynALisp <span>Docs</span></p>\n        %s\n    </div>\n'
            '    <div id="content">\n        <h1>DynALisp Docs</h1>\n<div class="programs commands wide">\n<table>\n'
            '<tr><th>Module</th><th>Description</th></tr>\n%s</table>\n</div>\n    </div>\n'
            '    <div id="footer"><p>%s</p></div>\n</body>\n</html>\n'
            % (code, VIEWPORT, alt, nav, rows, FOOTER.get(code, FOOTER['en'])))


README = """# DynALisp Docs

The documentation of [DynALisp](https://github.com/samagior/DynALisp.release), published at
{url}

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
        return os.path.commonpath([os.path.normcase(path), os.path.normcase(folder)]) == os.path.normcase(folder)
    except ValueError:
        return False


def main():
    if len(sys.argv) != 2:
        sys.exit('Usage: python Installer\\Docs\\BuildSite.py <folder>')
    out = os.path.abspath(sys.argv[1])
    releases = os.path.join(REPO, 'Releases')
    # Outside the repository, or in a folder of its own under Releases (never Releases itself,
    # which holds the build of the setup):
    if inside(out, REPO) and not (inside(out, releases) and os.path.normcase(out) != os.path.normcase(releases)):
        sys.exit('Build the website outside the repository, or in a folder under Releases: ' + out)
    pages = read_pages()
    known = BuildDocs.git_files()
    os.makedirs(out, exist_ok=True)
    count = 0
    for mod in sorted({p.split('/')[0] for p, *_ in pages}):
        src = os.path.join(MODULES, mod, 'Docs')
        for root, _, files in os.walk(src):
            for name in files:
                s = os.path.join(root, name)
                if os.path.normcase(os.path.normpath(s)) not in known:
                    continue
                d = os.path.join(out, mod, os.path.relpath(s, src))
                os.makedirs(os.path.dirname(d), exist_ok=True)
                if name.lower().endswith('.htm'):
                    with open(s, encoding='utf-8', newline='') as f:
                        text = f.read()
                    with open(d, 'w', encoding='utf-8', newline='') as f:
                        f.write(page(text))
                    count += 1
                else:
                    shutil.copyfile(s, d)
    shutil.copyfile(CSS, os.path.join(out, 'docs.css'))
    for code, *_ in BuildDocs.LANGS:
        with open(os.path.join(out, home_file(code)), 'w', encoding='utf-8', newline='\n') as f:
            f.write(home(pages, code))
    with open(os.path.join(out, 'README.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(README.format(url=URL))
    open(os.path.join(out, '.nojekyll'), 'w').close()
    print('Docs website built in %s: %d pages written (%d in DocsPages.txt), the pages already there kept.'
          % (out, count, len(pages)))


if __name__ == '__main__':
    main()
