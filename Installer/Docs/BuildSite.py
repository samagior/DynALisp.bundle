# BuildSite.py - the DynALisp docs website
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Docs\BuildSite.py <folder>
#
# Builds the docs website in <folder> (made empty first), published on GitHub Pages
# (https://samagior.github.io/DynALisp.docs/) by .github/workflows/docs.yml, which pushes it
# to the public repository samagior/DynALisp.docs. The docs are edited only here, in
# Contents\Modules\<Module>\Docs: the website is a copy of them, made again on every push
# to main, never edited in DynALisp.docs.
#
#   <folder>\<Module>\...     the Docs folder of each module (Dynalisp, LeeMac...)
#   <folder>\docs.css         Contents\Resources\docs.css, the pages pointed to it
#   <folder>\index.html       the docs of every module (as Dyl-Docs), index.fr.html in French
#   <folder>\README.md, .nojekyll
#
# The pages are the ones of DocsPages.txt (BuildDocs.py): run BuildDocs.py first. DynALisp
# opens a page of the list on the website (Dyl:DocsTarget of dynalisp.mnl).

import html
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MODULES = os.path.join(REPO, 'Contents', 'Modules')
CSS = os.path.join(REPO, 'Contents', 'Resources', 'docs.css')
PAGES = os.path.join(REPO, 'Contents', 'Resources', 'DocsPages.txt')
URL = 'https://samagior.github.io/DynALisp.docs/'
VIEWPORT = '<meta name="viewport" content="width=device-width, initial-scale=1">'

# The texts of the home page, by language: (file, lang, title, Module, Description, footer)
HOME = [('index.html', 'en', 'DynALisp Docs', 'Module', 'Description',
         'DynALisp &ndash; released under the GNU General Public License v3'),
        ('index.fr.html', 'fr', 'DynALisp Docs', 'Module', 'Description',
         'DynALisp &ndash; publi&eacute; sous la licence publique g&eacute;n&eacute;rale GNU v3')]


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


def home(pages, file, lang, title, th1, th2, footer):
    """The docs of every module: the Dynalisp module first, the others by name."""
    suf = '' if lang == 'en' else '.' + lang
    idx = {}
    for path, t, s in pages:
        mod, _, rest = path.partition('/')
        if rest == 'index.htm' or (rest == 'index%s.htm' % suf and suf):
            if rest == 'index.htm':
                idx.setdefault(mod, (path, t, s))
            else:
                idx[mod] = (path, t, s)
    mods = sorted(idx, key=lambda m: (m.upper() != 'DYNALISP', m.upper()))
    other = [h for h in HOME if h[1] != lang][0]
    nav = ('<nav class="lang" aria-label="Language">'
           + ''.join('<span class="on" title="%s">%s</span>' % (h[1], h[1].upper()) if h[1] == lang
                     else '<a href="%s" hreflang="%s" lang="%s">%s</a>' % (h[0], h[1], h[1], h[1].upper())
                     for h in HOME)
           + '</nav>')
    rows = ''.join('<tr><td><a href="%s">%s</a></td><td>%s</td></tr>\n' % (html.escape(idx[m][0]), idx[m][1] or m, idx[m][2])
                   for m in mods)
    return ('<!DOCTYPE html>\n<html lang="%s">\n<head>\n    <meta charset="utf-8">\n    %s\n'
            '    <title>%s</title>\n    <link rel="stylesheet" href="docs.css">\n'
            '    <link rel="alternate" hreflang="%s" href="%s">\n</head>\n<body>\n'
            '    <div id="header">\n        <p>DynALisp <span>Docs</span></p>\n        %s\n    </div>\n'
            '    <div id="content">\n        <h1>%s</h1>\n<div class="programs commands wide">\n<table>\n'
            '<tr><th>%s</th><th>%s</th></tr>\n%s</table>\n</div>\n    </div>\n'
            '    <div id="footer"><p>%s</p></div>\n</body>\n</html>\n'
            % (lang, VIEWPORT, title, other[1], other[0], nav, title, th1, th2, rows, footer))


README = """# DynALisp Docs

The documentation of [DynALisp](https://github.com/samagior/DynALisp.release), published at
{url}

This repository is **generated**: every push to the main branch of the DynALisp source
rebuilds it (`Installer/Docs/BuildSite.py`, `.github/workflows/docs.yml`). Do not edit it
here: a change made here is overwritten by the next publication.

The pages of the LeeMac sample module are copies of the help pages of Lee Mac's programs,
delivered for consistency purposes only: the programs and their descriptions are the work
of Lee Mac (https://www.lee-mac.com), who keeps all the credit for them, and each page
links to its original.
"""


def main():
    if len(sys.argv) != 2:
        sys.exit('Usage: python Installer\\Docs\\BuildSite.py <folder>')
    out = os.path.abspath(sys.argv[1])
    if os.path.commonpath([out, REPO]) == REPO and not os.path.relpath(out, REPO).startswith('Releases'):
        sys.exit('Build the website outside the repository (or under Releases): ' + out)
    pages = read_pages()
    if os.path.isdir(out):
        for name in os.listdir(out):
            if name != '.git':
                p = os.path.join(out, name)
                shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    os.makedirs(out, exist_ok=True)
    count = 0
    for mod in sorted({p.split('/')[0] for p, *_ in pages}):
        src = os.path.join(MODULES, mod, 'Docs')
        for root, _, files in os.walk(src):
            for name in files:
                s = os.path.join(root, name)
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
    for h in HOME:
        with open(os.path.join(out, h[0]), 'w', encoding='utf-8', newline='\n') as f:
            f.write(home(pages, *h))
    with open(os.path.join(out, 'README.md'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(README.format(url=URL))
    open(os.path.join(out, '.nojekyll'), 'w').close()
    print('Docs website built in %s: %d pages (%d in DocsPages.txt).' % (out, count, len(pages)))


if __name__ == '__main__':
    main()
