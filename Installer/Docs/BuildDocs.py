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
