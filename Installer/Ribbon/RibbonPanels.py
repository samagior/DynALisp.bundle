# RibbonPanels.py - the pictures of the DynALisp ribbon for its docs page
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
# Run by BuildRibbon.py each time it writes DynALisp.cuix, from the same panels (Ribbon.csv)
# and icons (RibbonIcons.py), so the pictures always show the ribbon as it is built:
#   - Docs\Plugins\Ribbon\<Panel>.png and <Panel>-dark.png: each panel, its slide-out open
#     under it, on the light and the dark ribbon of AutoCAD
#   - Docs\Plugins\Ribbon\Tab.png and Tab-dark.png: every panel side by side
#   - the Panels section of Docs\Plugins\Ribbon.htm and of its copy in each language of TEXT
#     (Ribbon.fr.htm), between their two BuildRibbon comments: a picture and the tools of each
#     panel, linked to their pages in the language of the page
# The drop-downs added at run time by DynALisp.Ribbon.dll are drawn after their button
# (PLUGIN below, with sample values): keep it in step with Plugin\PhaseCombos.cs and
# Plugin\TransferCombos.cs. A picture is only written when it changed, so git sees no change
# when the ribbon is the same. Drawn at twice their size (sharp on a high-DPI screen),
# shown at their size by the page.

import csv
import html
import io
import os
import re

from PIL import Image, ImageDraw, ImageFont

import RibbonIcons

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DOCS = os.path.join(REPO, 'Contents', 'Modules', 'Dynalisp', 'Docs')
PAGE = os.path.join(DOCS, 'Plugins', 'Ribbon.htm')
OUT = os.path.join(DOCS, 'Plugins', 'Ribbon')
PHASES = os.path.join(REPO, 'Contents', 'Modules', 'Dynalisp', 'Res', 'AEC', 'Standard', 'Phase.csv')
BEGIN, END = '<!-- BuildRibbon: panels -->', '<!-- /BuildRibbon: panels -->'

S = 2                      # drawn at twice the size
FONT = 'C:/Windows/Fonts/segoeui.ttf'
ROW = 22                   # a row of small buttons
PAD = 4                    # the margin of the buttons
CONTENT = 3 * ROW + 2 * PAD
TITLE = 20                 # the title bar of a panel

THEMES = {
    '': dict(bg=(245, 245, 245, 255), title=(226, 228, 231, 255), border=(200, 204, 210, 255),
             text=(30, 30, 30, 255), muted=(85, 90, 98, 255), combo=(255, 255, 255, 255),
             cborder=(165, 170, 178, 255), line=(196, 200, 206, 255)),
    '-dark': dict(bg=(59, 68, 83, 255), title=(47, 54, 66, 255), border=(34, 40, 50, 255),
                  text=(238, 240, 243, 255), muted=(196, 202, 210, 255), combo=(43, 50, 62, 255),
                  cborder=(96, 105, 120, 255), line=(88, 97, 112, 255)),
}

# The drop-downs of DynALisp.Ribbon.dll, after the button of their tool: (label, value shown).
# In each language of the plugin (Plugin\Translations.cs); the phases are the descriptions of
# Phase.csv, which has them in English only:
PLUGIN = {
    'DYL-LAYERPHASE': ({'en': 'Auto-phase and Phase', 'fr': 'Auto-phase et Phase'},
                       {'en': [('', 'Auto-phase On'), ('', 'N - New Work')],
                        'fr': [('', 'Auto-phase activée'), ('', 'N - New Work')]}),
    'PST-TRANSFERFIELD': ({'en': 'Level, From and To', 'fr': 'Niveau, De et À'},
                          {'en': [('Level:', 'Status'), ('From:', 'E - Existing To Remain'), ('To:', 'N - New Work')],
                           'fr': [('Niveau :', 'Statut'), ('De :', 'E - Existing To Remain'), ('À :', 'N - New Work')]}),
}

# The pages of the core commands (not in StartupSuite.csv), relative to Docs\Plugins:
CORE = {
    'DYL-SETTINGS': '../Core/Dyl-Settings.htm', 'DYL-SUITE': '../Core/Dyl-Suite.htm',
    'DYL-USERFILES': '../Core/Dyl-Info.htm', 'DYL-INFO': '../Core/Dyl-Info.htm',
    'DYL-DOCS': '../Core/Dyl-Info.htm', 'DYL-RELOAD': '../Core/Dyl-Suite.htm',
}

_fonts = {}


def font(px):
    if px not in _fonts:
        _fonts[px] = ImageFont.truetype(FONT, px * S)
    return _fonts[px]


def tw(s, px=12):
    return font(px).getlength(s) / S


def icon(cmd, size):
    im = RibbonIcons.render(cmd, size * S)
    if im is None:
        im = Image.new('RGBA', (size * S, size * S), (0, 0, 0, 0))
        ImageDraw.Draw(im).rounded_rectangle((2, 2, size * S - 3, size * S - 3), radius=4 * S,
                                             fill=RibbonIcons.GRAY_L, outline=RibbonIcons.INK, width=S)
    return im


def combo_width():
    """The width of the drop-downs, as Host.FitWidth of Plugin.cs measures it."""
    texts = ['Auto-phase On (reactors off)', 'Auto-phase Off', 'None']
    try:
        with open(PHASES, encoding='utf-8-sig', newline='') as f:
            texts += ['%s - %s' % (r['Abbreviation'], r['Description']) for r in csv.DictReader(f)]
    except (OSError, KeyError):
        pass
    return max([160] + [tw(t) + 44 for t in texts])


class Draw:
    """A canvas in units of the ribbon (drawn S times larger)."""

    def __init__(self, w, h):
        self.im = Image.new('RGBA', (int(round(w * S)), int(round(h * S))), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, r=0):
        box = [v * S for v in (x0, y0, x1, y1)]
        if r:
            self.d.rounded_rectangle(box, radius=r * S, fill=fill, outline=outline, width=S if outline else 0)
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=S if outline else 0)

    def line(self, x0, y0, x1, y1, color):
        self.d.line([x0 * S, y0 * S, x1 * S, y1 * S], fill=color, width=S)

    def text(self, x, y, s, color, px=12, anchor='lm'):
        self.d.text((x * S, y * S), s, font=font(px), fill=color, anchor=anchor)

    def arrow(self, x, y, color):
        """The small arrow of a split button or a drop-down, its top at y."""
        self.d.polygon([(x * S, y * S), ((x + 6) * S, y * S), ((x + 3) * S, (y + 3.5) * S)], fill=color)

    def paste(self, im, x, y):
        self.im.alpha_composite(im, (int(round(x * S)), int(round(y * S))))


def two_lines(text):
    """The label of a large button on two lines, as two_lines of BuildRibbon.py cuts it."""
    sp = [i for i, ch in enumerate(text) if ch == ' ']
    if not sp:
        return [text]
    i = min(sp, key=lambda i: abs(i - len(text) / 2))
    return [text[:i], text[i + 1:]]


# ---- the blocks of a panel: (width, draw(canvas, x, y, theme)) ----

def large(it):
    lines = two_lines(it['name'])
    arrow = bool(it['kids'])
    w = max(32, max(tw(t) for t in lines) + (9 if arrow else 0)) + 10

    def draw(c, x, y, t):
        c.paste(icon(it['cmd'], 32), x + (w - 32) / 2, y + PAD + 2)
        for i, s in enumerate(lines):
            last = i == len(lines) - 1
            lw = tw(s) + (9 if arrow and last else 0)
            c.text(x + (w - lw) / 2, y + PAD + 44 + i * 14, s, t['text'])
            if arrow and last:
                c.arrow(x + (w + lw) / 2 - 6, y + PAD + 43 + i * 14, t['text'])
    return w, draw


def small_width(it):
    return 3 + 16 + 5 + tw(it['name']) + (11 if it['kids'] else 0) + 5


def small(c, it, x, y, t):
    c.paste(icon(it['cmd'], 16), x + 3, y + 3)
    c.text(x + 24, y + ROW / 2, it['name'], t['text'])
    if it['kids']:
        c.arrow(x + 24 + tw(it['name']) + 4, y + ROW / 2 - 1.5, t['text'])


def stack(items):
    w = max(small_width(it) for it in items)

    def draw(c, x, y, t):
        for i, it in enumerate(items):
            small(c, it, x, y + PAD + i * ROW, t)
    return w, draw


def separator():
    def draw(c, x, y, t):
        c.line(x + 4, y + PAD + 2, x + 4, y + CONTENT - PAD - 2, t['line'])
    return 9, draw


def combos(rows, cw):
    lw = max([tw(l) for l, _ in rows] + [0])
    lw = lw + 6 if lw else 0

    def draw(c, x, y, t):
        for i, (label, value) in enumerate(rows):
            yy = y + PAD + i * ROW
            if label:
                c.text(x + 2, yy + ROW / 2, label, t['text'])
            x0 = x + lw + 2
            c.rect(x0, yy + 1, x0 + cw, yy + ROW - 2, t['combo'], t['cborder'], r=2)
            c.text(x0 + 6, yy + ROW / 2, value, t['text'])
            c.arrow(x0 + cw - 13, yy + ROW / 2 - 1.5, t['muted'])
    return lw + cw + 4, draw


def blocks(items, lang='en'):
    """The blocks of the main row of a panel, as Builder.panel of BuildRibbon.py lays it out."""
    out, i, cw = [], 0, combo_width()
    while i < len(items):
        it = items[i]
        if it.get('sep'):
            out.append(separator())
            i += 1
            continue
        if not it['stack']:
            out.append(large(it))
            i += 1
            group = [it]
        else:
            group = [it]
            i += 1
            while i < len(items) and items[i]['stack'] == it['stack'] and len(group) < 3 and not items[i].get('sep'):
                group.append(items[i])
                i += 1
            out.append(stack(group))
        for g in group:
            if g['cmd'] in PLUGIN:
                out.append(combos(PLUGIN[g['cmd']][1][lang], cw))
    return out


def slide_rows(items):
    rows = []
    for it in items:
        if it.get('sep'):
            continue
        if not rows or rows[-1][0] != it['stack']:
            rows.append((it['stack'], []))
        rows[-1][1].append(it)
    return [r for _, r in rows]


def panel_image(name, items, t, slide=True, lang='en'):
    main = [it for it in items if not it['stack'].startswith('>')]
    rows = slide_rows([it for it in items if it['stack'].startswith('>')]) if slide else []
    has_slide = any(it['stack'].startswith('>') for it in items)
    bl = blocks(main, lang)
    pw = max(sum(w for w, _ in bl) + 2 * PAD, tw(name, 11) + 36)
    sw = max([sum(small_width(it) + 2 for it in r) + 2 * PAD for r in rows] + [0])
    w = max(pw, sw)
    h = CONTENT + TITLE + ((6 + len(rows) * ROW + 2 * PAD) if rows else 0)
    c = Draw(w, h)
    c.rect(0, 0, pw - 1, CONTENT + TITLE - 1, t['bg'], t['border'])
    c.rect(1, CONTENT, pw - 2, CONTENT + TITLE - 2, t['title'])
    x = PAD + (pw - 2 * PAD - sum(w for w, _ in bl)) / 2
    for bw, draw in bl:
        draw(c, x, 0, t)
        x += bw
    c.text(pw / 2 - (6 if has_slide else 0), CONTENT + TITLE / 2 - 1, name, t['muted'], 11, 'mm')
    if has_slide:
        c.arrow(pw / 2 + tw(name, 11) / 2 - 2, CONTENT + TITLE / 2 - 2.5, t['muted'])
    if rows:
        y0 = CONTENT + TITLE + 6
        c.rect(0, y0, sw - 1, h - 1, t['bg'], t['border'])
        for j, r in enumerate(rows):
            x = PAD
            for it in r:
                small(c, it, x, y0 + PAD + j * ROW, t)
                x += small_width(it) + 2
    return c.im


def tab_image(panels, t, lang='en'):
    ims = [panel_image(n, its, t, slide=False, lang=lang) for n, its in panels]
    gap = 3 * S
    out = Image.new('RGBA', (sum(i.width for i in ims) + gap * (len(ims) - 1), max(i.height for i in ims)), (0, 0, 0, 0))
    x = 0
    for i in ims:
        out.alpha_composite(i, (x, 0))
        x += i.width + gap
    return out


def save(im, path):
    """Write the PNG only when it changed; returns True when written."""
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    data = buf.getvalue()
    if os.path.exists(path):
        with open(path, 'rb') as f:
            if f.read() == data:
                return False
    with open(path, 'wb') as f:
        f.write(data)
    return True


def slug(name):
    return ''.join(w[:1].upper() + w[1:] for w in re.split(r'[^A-Za-z0-9]+', name))


# ---- the page ----

def doc_link(cmd, cmds):
    """The page of cmd relative to Docs\\Plugins: the page named as the command (a Pst-* child
    with a page of its own, Dyl-QuickDrawGallery.htm), else the page of its file."""
    if cmd in CORE:
        return CORE[cmd]
    r = cmds.get(cmd)
    if not r or not r.get('Path'):
        return None
    d = os.path.join(DOCS, os.path.dirname(r['Path']).split('\\Apps\\', 1)[-1].replace('\\', os.sep))
    group = os.path.basename(d)
    names = {f.lower(): f for f in os.listdir(d)} if os.path.isdir(d) else {}
    for base in ('DYL-' + cmd[4:] if cmd.startswith('PST-') else cmd, os.path.splitext(r.get('File') or '')[0]):
        f = names.get(base.lower() + '.htm')
        if f:
            return '../%s/%s' % (group, f)
    return None


# The words of the Panels section in each language of the docs (the names of the panels and
# the buttons stay as the ribbon shows them, in English):
TEXT = {
    'en': dict(intro='The whole tab, then each panel with its slide-out open under its title. '
                     'The drop-downs show sample values.',
               tab='The DynALisp tab of the ribbon', panel='The %s panel', slide='In the slide-out:',
               drops=' and its %s drop-downs'),
    'fr': dict(intro="L'onglet entier, puis chaque groupe de fonctions avec sa partie déroulante ouverte "
                     "sous son titre. Les listes déroulantes montrent des valeurs d'exemple.",
               tab="L'onglet DynALisp du ruban", panel='Le groupe de fonctions %s',
               slide='Dans la partie déroulante :', drops=' et ses listes déroulantes %s'),
}


def localized(link, lang):
    """The link to the page in lang when it has a copy in it (Dyl-LayerKeys.fr.htm)."""
    if not link or lang == 'en':
        return link
    loc = link[:-4] + '.' + lang + '.htm'
    return loc if os.path.exists(os.path.normpath(os.path.join(DOCS, 'Plugins', loc))) else link


def tool(it, cmds, lang):
    name = html.escape(it['name'])
    link = localized(doc_link(it['cmd'], cmds), lang)
    s = '<a href="%s">%s</a>' % (link, name) if link else name
    if it['cmd'] in PLUGIN:
        s += TEXT[lang]['drops'] % PLUGIN[it['cmd']][0][lang]
    return s


def picture(base, w, alt):
    return ('<p><picture><source srcset="Ribbon/%s-dark.png" media="(prefers-color-scheme: dark)">'
            '<img src="Ribbon/%s.png" width="%d" alt="%s"></picture></p>' % (base, base, w, html.escape(alt)))


def localized_panels(panels, lang, panel_tr):
    """[(title, items, base)] of the panels in lang: their titles and the labels of their
    buttons translated (BuildRibbon.py, Ribbon.<lang>.csv); base: the name of their pictures
    (Draw, Draw-fr)."""
    out = []
    for name, items in panels:
        its = []
        for it in items:
            it = dict(it)
            if not it.get('sep') and lang in it.get('tr', {}):
                it['name'] = it['tr'][lang]['name']
            its.append(it)
        title = (panel_tr or {}).get(lang, {}).get(name, name) if lang != 'en' else name
        out.append((title, its, slug(name) + ('' if lang == 'en' else '-' + lang)))
    return out


def section(panels, sizes, cmds, lang, panel_tr=None):
    w = TEXT[lang]
    tab = 'Tab' + ('' if lang == 'en' else '-' + lang)
    out = [BEGIN, '<p>%s</p>' % html.escape(w['intro'], quote=False), picture(tab, sizes[tab], w['tab'])]
    for (name, _), (title, items, base) in zip(panels, localized_panels(panels, lang, panel_tr)):
        main = [tool(it, cmds, lang) for it in items if not it.get('sep') and not it['stack'].startswith('>')]
        more = [tool(it, cmds, lang) for it in items if not it.get('sep') and it['stack'].startswith('>')]
        out.append('<h3 id="panel-%s">%s</h3>' % (slug(name).lower(), html.escape(title)))
        out.append(picture(base, sizes[base], w['panel'] % title))
        p = ', '.join(main) + '.'
        if more:
            p += ' ' + w['slide'] + ' ' + ', '.join(more) + '.'
        out.append('<p>' + p + '</p>')
    out.append(END)
    return '\n'.join(out)


def write(panels, cmds, panel_tr=None):
    """The pictures and the Panels section of the page, in each language of TEXT (the French
    pictures: Draw-fr.png, Draw-fr-dark.png); returns the files written."""
    os.makedirs(OUT, exist_ok=True)
    written, sizes, keep = [], {}, set()
    for lang in TEXT:
        lp = localized_panels(panels, lang, panel_tr)
        tab = 'Tab' + ('' if lang == 'en' else '-' + lang)
        for suffix, t in THEMES.items():
            jobs = [(tab, lambda: tab_image([(ti, its) for ti, its, _ in lp], t, lang))]
            jobs += [(base, (lambda ti=ti, its=its: panel_image(ti, its, t, lang=lang))) for ti, its, base in lp]
            for base, draw in jobs:
                im = draw()
                sizes[base] = im.width // S
                f = '%s%s.png' % (base, suffix)
                keep.add(f.lower())
                if save(im, os.path.join(OUT, f)):
                    written.append(f)
    for f in os.listdir(OUT):
        if f.endswith('.png') and f.lower() not in keep:
            os.remove(os.path.join(OUT, f))
            written.append(f + ' (removed)')
    for lang in TEXT:
        path = PAGE if lang == 'en' else PAGE[:-4] + '.' + lang + '.htm'
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8', newline='') as f:
            page = f.read()
        i, j = page.find(BEGIN), page.find(END)
        if i < 0 or j < 0:
            written.append('(no %s in %s: its Panels section is not written)' % (BEGIN, os.path.basename(path)))
            continue
        eol = '\r\n' if '\r\n' in page else '\n'
        new = page[:i] + section(panels, sizes, cmds, lang, panel_tr).replace('\n', eol) + page[j + len(END):]
        if new != page:
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(new)
            written.append(os.path.basename(path))
    return written
