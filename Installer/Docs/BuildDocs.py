# BuildDocs.py - the languages of the DynALisp docs
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Docs\BuildDocs.py [--missing] [--check]
#
# The docs are two sets: the User Guide (Contents\Modules\<Module>\Docs\**\*.htm), what each
# tool does and how to use it, opened by the Open Docs buttons, and the Developer docs
# (Contents\Modules\<Module>\DevDocs\**\*.htm, the same group folders and page names), how the
# code works. A guide page is in English, Page.htm, and may have a copy in another language
# beside it, Page.fr.htm (LANGS below); a dev page is in English only. Run this script after
# adding, translating, moving or deleting a page. In every page of both sets it:
#   - writes the language switch at the top right of the header (EN | FR): a link to the page
#     in each language, greyed out for a language the page has no copy in yet
#   - sets <html lang> to the language of the page
#   - points the links of a page to the pages of its own language: Dyl-LayerKeys.fr.htm from
#     a French page once it exists, Dyl-LayerKeys.htm while it does not
# then reports the links that lead nowhere (a missing page or anchor), the LeeMac pages without
# their credit to Lee Mac (LEEMAC_NOTE), the number of guide pages of each language, with a dev
# page and with their pictures (--missing lists the others). A guide page names its pictures
# in placeholders, <!-- picture: images/<Page>-window.png --> (the window) and
# <!-- picture: images/<Page>-use.gif --> (a sample use), shown by BuildSite.py once the file
# is in the images folder beside the page.
#
# It also writes Contents\Resources\DocsPages.txt, the pages of the User Guide on the docs website
# (https://samagior.github.io/DynALisp.docs/, built by BuildSite.py and published by
# .github/workflows/docs.yml): <Module>/<path> of each page, a module index followed by its
# title and the first sentence of its first paragraph (tabs between them). The setup ships
# that list, not the Docs folders: DynALisp opens a page on the website when the list has it
# (Dyl:DocsTarget of dynalisp.mnl), in the language of DynALisp (Language in Dyl-Settings,
# Dyl:Lang), English when the page has no copy in it. The list holds only the pages git knows
# (committed, or new and not ignored): never those of MyTools, ignored, which open from the
# computer.
#
# The windows of a program (the rows <tr class="window"> of the index of its module, under the
# program or naming it in "Window of ...") are shown on the page of the program too, written
# here between <!-- dyl:windows --> and <!-- /dyl:windows --> under "Its Windows": for each
# window, its title, the first paragraph of its page, its pictures (not the GIF) and the section
# of its window (the heading "<Name> Window", "The Window", "Fenêtre <Name>", "La fenêtre"),
# then a link to its page. The block is placed once after the section of the window of the
# program (else before its aliases), then kept where it is; the row Windows of the program
# table links to each window.
#
# A page is written only when it changed, its line endings kept. --check writes nothing: it
# fails (exit code 1) when a page or DocsPages.txt is not up to date, or a LeeMac page has no
# credit to Lee Mac (the docs workflow and Build.ps1 run it).

import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MODULES = os.path.join(REPO, 'Contents', 'Modules')
PAGES = os.path.join(REPO, 'Contents', 'Resources', 'DocsPages.txt')
# Every page of the LeeMac sample module credits Lee Mac in a note that begins with:
LEEMAC_NOTE = '<p class="note">This page is delivered for consistency purposes only'
# The pictures named by a guide page (BuildSite.py shows the ones found):
PICTURE = re.compile(r'<!--\s*picture:\s*(\S+)\s*-->')

# (code, suffix of its pages, label, its name, "not translated" in that language):
LANGS = [('en', '', 'EN', 'English', 'Not translated yet'),
         ('fr', '.fr', 'FR', 'Français', 'Pas encore traduite')]
HEADER = '<p>DynALisp <span>Docs</span></p>'
NAV = re.compile(r'[ \t]*<nav class="lang"[^>]*>.*?</nav>\r?\n', re.S)
LINK = re.compile(r'(href=")([^"#:?]+\.htm)((?:#[^"]*)?")')
# The windows of a program shown on its page (see above):
WINDOWS = re.compile(r'[ \t]*<!-- dyl:windows -->.*?<!-- /dyl:windows -->[ \t]*\r?\n', re.S)
WINDOW_H2 = re.compile(r'<h2[^>]*>(?:[^<]+ Window|(?:La )?[Ff]en\u00eatre[^<]*)</h2>')
WINDOW_TEXTS = {'en': ('Its Windows', 'Windows'), 'fr': ('Ses fen\u00eatres', 'Fen\u00eatres')}
_windows = None


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
    if os.sep + 'DevDocs' + os.sep in path:
        off = 'The developer docs are in English only'
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


def windows_of():
    """{English path of a program page: [English paths of its windows]}, from the index of each
    module: a row <tr class="window"> belongs to the program above it and to the programs its
    "Window of ..." names."""
    global _windows
    if _windows is None:
        _windows = {}
        for idx in sorted(glob.glob(os.path.join(MODULES, '*', 'Docs', 'index.htm'))):
            with open(idx, encoding='utf-8') as f:
                text = f.read()
            here = os.path.dirname(idx)
            rows = re.findall(r'<tr( class="window")?><td><a href="([^"#]+)">(.*?)</a></td>(.*?)</tr>', text, re.S)
            progs = {text_of(name): os.path.normpath(os.path.join(here, href)) for win, href, name, _ in rows if not win}
            last = None
            for win, href, name, rest in rows:
                path = os.path.normpath(os.path.join(here, href))
                if not win:
                    last = path
                    continue
                owners = [last] if last else []
                m = re.search(r'Window of (.*)', text_of(rest))
                for n in re.split(r',\s*|\s+and\s+', m.group(1)) if m else []:
                    if n.strip() in progs and progs[n.strip()] not in owners:
                        owners.append(progs[n.strip()])
                for o in owners:
                    _windows.setdefault(o, []).append(path)
    return _windows


def window_block(prog, wins, code, eol):
    """The windows of the page prog in its language code (see the top of this file)."""
    here = os.path.dirname(prog)
    its, _ = WINDOW_TEXTS.get(code, WINDOW_TEXTS['en'])
    out = ['<!-- dyl:windows -->', '<h2 id="windows">%s</h2>' % its]
    for w in wins:
        src = in_lang(w, code)
        if not os.path.exists(src):
            src = w
        with open(src, encoding='utf-8') as f:
            text = f.read()
        there = os.path.dirname(w)
        body = text.split('<div id="content">', 1)[-1]
        if '<div id="footer">' in body:
            body = body.split('<div id="footer">', 1)[0].rsplit('</div>', 1)[0]
        h1 = re.search(r'<h1>(.*?)</h1>', body, re.S)
        name = h1.group(1).strip() if h1 else os.path.basename(w)[:-4]
        body = body[h1.end():] if h1 else body
        body = re.sub(r'<div class="programs">.*?</div>', '', body, count=1, flags=re.S)

        def move(fragment):
            """The links of a fragment of w pointed from the page prog, without its ids."""
            def sub(m):
                href = m.group(2)
                if href.startswith('#'):
                    return m.group(1) + os.path.basename(w) + href + '"'
                file, _, anchor = href.partition('#')
                if re.match(r'[a-z]+:', file):
                    return m.group(0)
                target = os.path.normpath(os.path.join(there, file))
                if os.path.normcase(lang_of(target)[1]) == os.path.normcase(prog):
                    return m.group(1) + ('#' + anchor if anchor else '#') + '"'
                new = os.path.relpath(target, here).replace(os.sep, '/')
                return m.group(1) + new + ('#' + anchor if anchor else '') + '"'
            fragment = re.sub(r'((?:href|src)=")([^"]*)"', sub, fragment)
            return re.sub(r' id="[^"]*"', '', fragment)
        anchor = 'window-' + re.sub(r'^dyl-', '', os.path.basename(w)[:-4].lower())
        out.append('<h3 id="%s">%s</h3>' % (anchor, name))
        desc = re.search(r'<p>(.*?)</p>', body, re.S)
        if desc:
            out.append(move(desc.group(0)))
        for pic in PICTURE.findall(body):
            if not pic.lower().endswith('.gif'):
                rel = os.path.relpath(os.path.join(there, *pic.split('/')), here).replace(os.sep, '/')
                out.append('<!-- picture: %s -->' % rel)
        m = WINDOW_H2.search(body)
        if m:
            part = re.split(r'<h2[\s>]', body[m.end():], maxsplit=1)[0]
            part = PICTURE.sub('', part)
            part = re.sub(r'<p>(?:(?!</p>).)*&larr;.*?</p>', '', part, flags=re.S)
            part = re.sub(r'<(/?)h3', r'<\1h4', part)
            part = '\n'.join(l for l in part.strip().splitlines() if l.strip())
            if part:
                out.append(move(part))
        out.append('<p class="more"><a href="%s">%s &rarr;</a></p>'
                   % (os.path.relpath(w, here).replace(os.sep, '/'), name))
    out.append('<!-- /dyl:windows -->')
    return eol.join(out) + eol


def show_windows(text, path, eol):
    """The page with the windows of its program (see the top of this file)."""
    code, base = lang_of(path)
    if os.sep + 'Docs' + os.sep not in path:
        return text
    wins = windows_of().get(os.path.normpath(base))
    old = WINDOWS.search(text)
    if not wins:
        return WINDOWS.sub('', text) if old else text
    block = window_block(os.path.normpath(base), wins, code, eol)
    if old:
        text = text[:old.start()] + block + text[old.end():]
    else:
        m = WINDOW_H2.search(text)
        nxt = re.compile(r'<h2[\s>]').search(text, m.end()) if m else None
        at = nxt.start() if nxt else text.find('<!-- dyl:aliases -->')
        if at < 0:
            at = text.find('<div id="footer">')
            at = text.rfind('</div>', 0, at)
        text = text[:at] + block + text[at:]
    # the row Windows of the program table:
    _, label = WINDOW_TEXTS.get(code, WINDOW_TEXTS['en'])
    links = ', '.join('<a href="#window-%s">%s</a>' % (a, n) for a, n in re.findall(r'<h3 id="window-([^"]+)">(.*?)</h3>', block))
    m = re.search(r'(<div class="programs">\s*<table>)(.*?)(</table>)', text, re.S)
    if m:
        rows = [r for r in re.findall(r'<tr[^>]*>.*?</tr>', m.group(2), re.S)
                if not re.search(r'<td>%s</td>' % re.escape(label), r)]
        cells = [re.findall(r'<td>(.*?)</td>', r, re.S) for r in rows]
        at = 1 if cells and cells[0] and cells[0][0] in ('Function Syntax', 'Syntaxe') else 0
        cells[at:at] = [[label, links]]
        inner = eol + eol.join(('<tr class="alt">' if i % 2 == 0 else '<tr>') + eol + eol.join('<td>%s</td>' % c for c in r) + eol + '</tr>'
                               for i, r in enumerate(cells)) + eol
        text = text[:m.start()] + m.group(1) + inner + m.group(3) + text[m.end():]
    return text


def git_files():
    """The files git knows under Contents/Modules (committed, or new and not ignored), as
    normalized full paths."""
    out = subprocess.run(['git', '-C', REPO, '-c', 'core.quotepath=false', 'ls-files', '--cached', '--others',
                          '--exclude-standard', '--', 'Contents/Modules'],
                         capture_output=True, text=True, encoding='utf-8', check=True).stdout
    return {os.path.normcase(os.path.normpath(os.path.join(REPO, f))) for f in out.splitlines() if f}


def build_page(path, write=True):
    with open(path, encoding='utf-8', newline='') as f:
        old = f.read()
    eol = '\r\n' if '\r\n' in old else '\n'
    # the links first, the switch after (its links lead to the other languages on purpose):
    text = fix_links(show_windows(NAV.sub('', old), path, eol), path)
    i = text.find(HEADER)
    if i >= 0:
        line_start = text.rfind('\n', 0, i) + 1
        indent = text[line_start:i]
        j = text.find('\n', i) + 1
        text = text[:j] + nav(path, eol, indent) + text[j:]
    code, _ = lang_of(path)
    text = re.sub(r'<html lang="[^"]*">', '<html lang="%s">' % code, text, count=1)
    if text != old:
        if write:
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


def text_of(html):
    """The text of an html fragment, without its tags, its spaces joined."""
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]*>', '', html)).strip()


def index_info(path):
    """(title, sentence) of a module index: its first h1, the first sentence of the first
    paragraph after it (as Dyl:DocsIndexInfo reads a local index)."""
    with open(path, encoding='utf-8') as f:
        text = f.read()
    title, sentence = '', ''
    m = re.search(r'<h1>(.*?)</h1>', text, re.S)
    if m:
        title = text_of(m.group(1))
        text = text[m.end():]
    m = re.search(r'<p>(.*?)</p>', text, re.S)
    if m:
        sentence = text_of(m.group(1))
        i = sentence.find('. ')
        if i >= 0:
            sentence = sentence[:i + 1]
    return title, sentence


def site_path(page):
    """<Module>/<path> of a page on the website (Contents/Modules/<Module>/Docs/<path>)."""
    mod, _, *rest = os.path.relpath(page, MODULES).split(os.sep)
    return '/'.join([mod] + rest)


def write_pages(pages, write=True):
    """Write DocsPages.txt (only when it changed). Returns True when it changed."""
    lines = ['# DocsPages.txt - the pages of the DynALisp docs website, written by Installer/Docs/BuildDocs.py',
             '# <Module>/<path> of each page; a module index: its title and first sentence after tabs']
    for p in sorted(pages, key=site_path):  # the same order on every system
        line = site_path(p)
        if os.path.basename(lang_of(p)[1]) == 'index.htm' and os.path.dirname(p).endswith(os.sep + 'Docs'):
            line += '\t%s\t%s' % index_info(p)
        lines.append(line)
    new = '\r\n'.join(lines) + '\r\n'
    old = None
    if os.path.exists(PAGES):
        with open(PAGES, encoding='utf-8', newline='') as f:
            old = f.read()
    # (its line endings as git checked it out: CRLF on Windows, LF on the Linux of the workflow)
    if old is None or new.replace('\r\n', '\n') != old.replace('\r\n', '\n'):
        if write:
            with open(PAGES, 'w', encoding='utf-8', newline='') as f:
                f.write(new)
        return True
    return False


def kind_of(path):
    """(module, set, path in the set) of a page: set 'guide' (Docs) or 'dev' (DevDocs)."""
    mod, folder, *rest = os.path.relpath(path, MODULES).split(os.sep)
    return mod, ('dev' if folder == 'DevDocs' else 'guide'), rest


def twin(path):
    """The page of the other set for the same tool (a dev page has no language: the twin of
    a French guide page is the English dev page), whether it exists or not."""
    mod, kind, rest = kind_of(path)
    if kind == 'guide':
        rest = rest[:-1] + [os.path.basename(lang_of(path)[1])]
    return os.path.join(MODULES, mod, 'Docs' if kind == 'dev' else 'DevDocs', *rest)


def pictures(path):
    """[(name, found)] of the pictures a page names."""
    with open(path, encoding='utf-8') as f:
        names = PICTURE.findall(f.read())
    return [(n, os.path.exists(os.path.join(os.path.dirname(path), *n.split('/')))) for n in names]


def main():
    check_only = '--check' in sys.argv
    missing = '--missing' in sys.argv
    pages = sorted(glob.glob(os.path.join(MODULES, '*', 'Docs', '**', '*.htm'), recursive=True)
                   + glob.glob(os.path.join(MODULES, '*', 'DevDocs', '**', '*.htm'), recursive=True))
    changed = [p for p in pages if build_page(p, not check_only)]
    nbad = 0
    ncredit = 0
    for p in pages:
        for href, why in check(p):
            print('Broken link: %s -> %s (%s)' % (os.path.relpath(p, MODULES), href, why))
            nbad += 1
        mod, kind, _ = kind_of(p)
        if mod == 'LeeMac' and kind == 'guide' and os.path.basename(p) != 'index.htm':
            with open(p, encoding='utf-8') as f:
                if LEEMAC_NOTE not in f.read():
                    print('No credit to Lee Mac: %s (a note beginning %s...)' % (os.path.relpath(p, MODULES), LEEMAC_NOTE))
                    ncredit += 1
    # The website has the pages git knows only (never MyTools, ignored); the app opens the
    # guide pages, the ones of DocsPages.txt:
    known = git_files()
    guide = [p for p in pages if kind_of(p)[1] == 'guide' and os.path.normcase(os.path.normpath(p)) in known]
    listed = write_pages(guide, not check_only)
    if check_only:
        for p in changed:
            print('Not up to date: %s' % os.path.relpath(p, MODULES))
        if listed:
            print('Not up to date: Contents/Resources/DocsPages.txt')
        print('%d broken links, %d LeeMac pages without their credit.' % (nbad, ncredit))
        if changed or listed or ncredit:
            print('Run python Installer\\Docs\\BuildDocs.py, then commit what it changed.')
            sys.exit(1)
        print('The docs are up to date (%d guide pages listed for the app).' % len(guide))
        return
    print('%d pages written, %d broken links, %d LeeMac pages without their credit.' % (len(changed), nbad, ncredit))
    print('DocsPages.txt %s: %d guide pages.' % ('written' if listed else 'up to date', len(guide)))
    for mod in sorted({kind_of(p)[0] for p in pages}):
        base = [p for p in pages if kind_of(p)[0] == mod and kind_of(p)[1] == 'guide' and lang_of(p)[0] == 'en']
        dev = [p for p in pages if kind_of(p)[0] == mod and kind_of(p)[1] == 'dev']
        for c, _, label, *_ in LANGS[1:]:
            have = [p for p in base if os.path.exists(in_lang(p, c))]
            print('%s: %d of %d guide pages in %s.' % (mod, len(have), len(base), label))
            if missing:
                for p in base:
                    if p not in have:
                        print('   ' + os.path.relpath(p, MODULES))
        if mod == 'LeeMac':
            print('%s: %d dev pages (the guide pages are Lee Mac\'s own: no dev page each).' % (mod, len(dev)))
            continue
        withdev = [p for p in base if os.path.exists(twin(p))]
        print('%s: %d of %d guide pages with a dev page (%d dev pages).' % (mod, len(withdev), len(base), len(dev)))
        if missing:
            for p in base:
                if p not in withdev:
                    print('   ' + os.path.relpath(p, MODULES))
        pics = [(p, pictures(p)) for p in base]
        done = [p for p, l in pics if l and all(f for _, f in l)]
        print('%s: %d of %d guide pages with their pictures.' % (mod, len(done), len(base)))
        if missing:
            for p, l in pics:
                if p not in done:
                    what = ', '.join(n for n, f in l if not f) if l else 'no picture placeholder'
                    print('   %s (%s)' % (os.path.relpath(p, MODULES), what))


if __name__ == '__main__':
    main()
