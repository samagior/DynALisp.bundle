# BuildDocs.py - the languages of the DynALisp docs
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Docs\BuildDocs.py [--missing]
#
# Every docs page (Contents\Modules\<Module>\Docs\**\*.htm) is in English, Page.htm, and may
# have a copy in another language beside it, Page.fr.htm (LANGS below). Run this script after
# adding, translating, moving or deleting a page. In every page it:
#   - writes the language switch at the top right of the header (EN | FR): a link to the page
#     in each language, greyed out for a language the page has no copy in yet
#   - sets <html lang> to the language of the page
#   - points the links of a page to the pages of its own language: Dyl-LayerKeys.fr.htm from
#     a French page once it exists, Dyl-LayerKeys.htm while it does not
# then reports the links that lead nowhere (a missing page or anchor) and the number of pages
# of each language (--missing lists the pages without a copy).
#
# DynALisp opens a page in the language of DynALisp (Language in Dyl-Settings, Dyl:Lang;
# Dyl:DocsLocal of dynalisp.mnl), English when the page has no copy in it. A page is written only when it
# changed, its line endings kept.

import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MODULES = os.path.join(REPO, 'Contents', 'Modules')

# (code, suffix of its pages, label, its name, "not translated" in that language):
LANGS = [('en', '', 'EN', 'English', 'Not translated yet'),
         ('fr', '.fr', 'FR', 'Français', 'Pas encore traduite')]
HEADER = '<p>DynALisp <span>Docs</span></p>'
NAV = re.compile(r'[ \t]*<nav class="lang"[^>]*>.*?</nav>\r?\n', re.S)
LINK = re.compile(r'(href=")([^"#:?]+\.htm)((?:#[^"]*)?")')


def lang_of(path):
    """(code, base) of a page: its language and its English path."""
    for code, suf, *_ in LANGS[1:]:
        if path.lower().endswith(suf + '.htm'):
            return code, path[:-len(suf + '.htm')] + '.htm'
    return 'en', path


def in_lang(base, code):
    suf = next(s for c, s, *_ in LANGS if c == code)
    return base[:-4] + suf + '.htm'


def nav(path, eol, indent):
    code, base = lang_of(path)
    off = next(t for c, _, _, _, t in LANGS if c == code)
    out = []
    for c, _, label, name, _ in LANGS:
        target = in_lang(base, c)
        if c == code:
            out.append('<span class="on" title="%s">%s</span>' % (name, label))
        elif os.path.exists(target):
            out.append('<a href="%s" hreflang="%s" lang="%s" title="%s">%s</a>'
                       % (os.path.basename(target), c, c, name, label))
        else:
            out.append('<span class="off" title="%s">%s</span>' % (off, label))
    return indent + '<nav class="lang" aria-label="Language">' + ''.join(out) + '</nav>' + eol


def fix_links(text, path):
    """The links of the page to the pages of its language (English when there is no copy)."""
    code, _ = lang_of(path)
    here = os.path.dirname(path)

    def sub(m):
        href = m.group(2)
        target = os.path.normpath(os.path.join(here, href))
        tcode, tbase = lang_of(target)
        want = in_lang(tbase, code)
        if not os.path.exists(want):
            want = tbase
        if os.path.normcase(want) == os.path.normcase(target):
            return m.group(0)
        new = os.path.relpath(want, here).replace(os.sep, '/')
        return m.group(1) + new + m.group(3)
    return LINK.sub(sub, text)


def build_page(path):
    with open(path, encoding='utf-8', newline='') as f:
        old = f.read()
    eol = '\r\n' if '\r\n' in old else '\n'
    # the links first, the switch after (its links lead to the other languages on purpose):
    text = fix_links(NAV.sub('', old), path)
    i = text.find(HEADER)
    if i >= 0:
        line_start = text.rfind('\n', 0, i) + 1
        indent = text[line_start:i]
        j = text.find('\n', i) + 1
        text = text[:j] + nav(path, eol, indent) + text[j:]
    code, _ = lang_of(path)
    text = re.sub(r'<html lang="[^"]*">', '<html lang="%s">' % code, text, count=1)
    if text != old:
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(text)
        return True
    return False


def check(path):
    """The links of the page that lead nowhere: [(href, why)]."""
    with open(path, encoding='utf-8') as f:
        text = f.read()
    bad = []
    for href in re.findall(r'(?:href|src|srcset)="([^"]+)"', text):
        if re.match(r'[a-z]+:', href) or href.startswith('#'):
            if href.startswith('#') and len(href) > 1 and ('id="%s"' % href[1:]) not in text:
                bad.append((href, 'no such anchor'))
            continue
        file, _, anchor = href.partition('#')
        target = os.path.normpath(os.path.join(os.path.dirname(path), file))
        if not os.path.exists(target):
            bad.append((href, 'no such file'))
        elif anchor and target.lower().endswith('.htm'):
            with open(target, encoding='utf-8') as f:
                if ('id="%s"' % anchor) not in f.read():
                    bad.append((href, 'no such anchor'))
    return bad


def main():
    pages = sorted(glob.glob(os.path.join(MODULES, '*', 'Docs', '**', '*.htm'), recursive=True))
    changed = [p for p in pages if build_page(p)]
    nbad = 0
    for p in pages:
        for href, why in check(p):
            print('Broken link: %s -> %s (%s)' % (os.path.relpath(p, MODULES), href, why))
            nbad += 1
    print('%d pages written, %d broken links.' % (len(changed), nbad))
    for mod in sorted({os.path.relpath(p, MODULES).split(os.sep)[0] for p in pages}):
        base = [p for p in pages if os.path.relpath(p, MODULES).startswith(mod + os.sep) and lang_of(p)[0] == 'en']
        for c, _, label, *_ in LANGS[1:]:
            have = [p for p in base if os.path.exists(in_lang(p, c))]
            print('%s: %d of %d pages in %s.' % (mod, len(have), len(base), label))
            if '--missing' in sys.argv:
                for p in base:
                    if p not in have:
                        print('   ' + os.path.relpath(p, MODULES))


if __name__ == '__main__':
    main()
