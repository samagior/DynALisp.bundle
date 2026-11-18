# BuildRibbon.py - build the DynALisp ribbon: Contents\Resources\DynALisp.cuix
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Ribbon\BuildRibbon.py [--sheet <icons.png>]
#
# Writes the DynALisp tab of the ribbon from:
#   - Ribbon.csv (this folder): its panels and buttons, in their order. Columns:
#       Panel        the panel of the button (the panels follow the order of the file)
#       Stack        empty: a large button; a number: a small button, stacked with the
#                    buttons of the same number that follow it (3 at most); a number
#                    after > (>1): a row of small buttons in the slide-out of the panel
#                    (under its title), for the tools used less often
#       Command      the command, without C: (DYL-QUICKDRAW)
#       Children     the child commands (Pst-*) listed under its arrow: * every child,
#                    or patterns divided by | (PST-SHOW*|PST-HIDE*); empty: none. Or
#                    @<variable>=<value>|<value>...: items labelled by the values, each
#                    setting the Lisp variable to its value, then running the command
#                    (@*qd:gallerygroup*=All|Phase|Section: the gallery on a group); the
#                    button keeps its name and runs the item picked last
#       Name         the label (empty: the Name of StartupSuite.csv)
#       Description  the tooltip (empty: the Description of StartupSuite.csv)
#       Selection    1: the command works on the objects selected, so its macro has no ^C^C,
#                    which would drop them (as the context menus); empty: ^C^C first
#   - Contents\Resources\StartupSuite.csv: the names, descriptions and children of the
#     commands (a child is a Pst-* command of the same file as its main command).
#   - RibbonIcons.py (this folder): the icon of each command, drawn at 16 and 32 px and
#     stored in the CUIx. A child without an icon uses the icon of its main command.
#   - ContextMenus.csv (this folder): the commands added to the right-click menus of
#     AutoCAD. Columns: Menu (the alias of an object menu: OBJECT_MTEXT for one mtext
#     selected, OBJECTS_MTEXT for several; AutoCAD adds the items of a partial CUIx to its
#     own menu of that alias), Command, Name (empty: the Name of StartupSuite.csv). Their
#     macros keep the selection (no ^C^C): the command works on the objects selected.
#
# A CUIx holds no drop-down of its own: the drop-downs (Auto-phase and Phase after the
# Layer Phase button, Level, From and To after the Layer Transfer button) are added at run
# time by DynALisp.Ribbon.dll (Plugin, this folder: dotnet build Installer\Ribbon\Plugin -c
# Release), which finds the tab, the panel and the buttons by their UIDs (RBN_DYL_TAB,
# RBN_DYL_PANEL_LAYERS, RBN_DYL_CMD_DYL_LAYERPHASE, RBN_DYL_CMD_PST_TRANSFERFIELD): keep them.
#
# The parts of the CUIx that hold no command (Header.cui, the empty roots...) are kept
# from the current DynALisp.cuix. Never edit DynALisp.cuix in the CUI editor: run this
# script again. Needs Python 3 and Pillow (pip install pillow).

import csv
import datetime
import fnmatch
import io
import os
import re
import sys
import zipfile
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SUITE = os.path.join(REPO, 'Contents', 'Resources', 'StartupSuite.csv')
LAYOUT = os.path.join(HERE, 'Ribbon.csv')
CONTEXT = os.path.join(HERE, 'ContextMenus.csv')
CUIX = os.path.join(REPO, 'Contents', 'Resources', 'DynALisp.cuix')

sys.path.insert(0, HERE)
import RibbonIcons  # noqa: E402

MENUGROUP = 'DYNALISP'
TAB = 'DynALisp'
MODULE = 'Dynalisp'
REV = '<ModifiedRev MajorVersion="24" MinorVersion="1" UserVersion="1" />'
WARNING = '''<!--
Warning! This file is written by Installer\\Ribbon\\BuildRibbon.py of DynALisp.
Do not edit it in the Customize User Interface dialog: edit Ribbon.csv or
RibbonIcons.py, then run BuildRibbon.py again.
-->'''
GENERATED = {'MenuGroup.cui', 'RibbonRoot.cui', 'PopMenuRoot.cui', '[Content_Types].xml', '_rels/.rels', 'Menu_Package_Info.xml'}


def read_csv(path):
    with open(path, encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f, delimiter=';'))


def suite_commands():
    """{COMMAND: row} of StartupSuite.csv, and {file: [COMMAND...]} in the order of the file."""
    cmds, files = {}, {}
    for r in read_csv(SUITE):
        c = (r.get('Command') or '').upper()
        if not c.startswith('C:'):
            continue
        c = c[2:]
        cmds[c] = r
        files.setdefault(r.get('File') or '', []).append(c)
    return cmds, files


def children_of(cmd, pats, cmds, files):
    """The children of cmd matching the patterns pats ('*': all), in the order of the suite."""
    if not pats or cmd not in cmds:
        return []
    kids = [c for c in files.get(cmds[cmd].get('File') or '', []) if c.startswith('PST-')]
    pats = [p.strip().upper() for p in pats.split('|') if p.strip()]
    return [c for c in kids if any(fnmatch.fnmatchcase(c, p) for p in pats)]


def short_names(names):
    """The names of the children without the words they all start with (Quick Draw ...)."""
    if len(names) < 2:
        return names
    words = [n.split(' ') for n in names]
    k = 0
    while all(len(w) > k + 1 and w[k] == words[0][k] for w in words):
        k += 1
    return [' '.join(w[k:]) for w in words]


def two_lines(text):
    """The label of a large button on two lines, cut at the space nearest the middle."""
    sp = [i for i, ch in enumerate(text) if ch == ' ']
    if not sp:
        return text
    i = min(sp, key=lambda i: abs(i - len(text) / 2))
    return text[:i] + '\r' + text[i + 1:]


def attr(s):
    return escape(s, {'"': '&quot;', '\r': '&#xD;'})


def image_name(cmd, size):
    return re.sub(r'[^A-Z0-9]', '_', cmd.upper()) + '_%d.png' % size


class Builder:
    def __init__(self):
        self.n = 0
        self.macros = []      # MenuMacro XML
        self.macro_ids = {}   # command -> macro UID
        self.images = {}      # file name -> PNG bytes
        self.warnings = []
        self.buttons = set()  # the UIDs of the command buttons

    def uid(self, kind='RBN'):
        self.n += 1
        return '%s_DYL_%04d' % (kind, self.n)

    def icon(self, cmd, parent=None):
        """The image names (small, large) of cmd: its own icon, the icon of its main
        command, or a placeholder."""
        own = cmd if RibbonIcons.render(cmd, 16) is not None else None
        src = own or (parent if parent and RibbonIcons.render(parent, 16) is not None else None)
        if not src:
            self.warnings.append('No icon for %s: a placeholder is used (add it to RibbonIcons.py).' % cmd)
            src = cmd
        names = []
        for size in (16, 32):
            name = image_name(src, size)
            if name not in self.images:
                im = RibbonIcons.render(src, size) or placeholder(src, size)
                buf = io.BytesIO()
                im.save(buf, 'PNG', optimize=True)
                self.images[name] = buf.getvalue()
            names.append(name)
        return names

    def macro(self, cmd, name, desc, parent=None, command=None, cancel=True):
        """The macro running cmd (or the text command, cmd then being its key); cancel:
        ^C^C first (ends the command running; a context menu keeps the selection)."""
        if cmd in self.macro_ids:
            return self.macro_ids[cmd]
        uid = 'MM_DYL_' + re.sub(r'[^A-Z0-9]', '_', cmd.upper())
        small, large = self.icon(cmd, parent)
        self.macros.append('\n'.join([
            '    <MenuMacro UID="%s">' % uid,
            '      <Macro type="Any">',
            '        <Revision MajorVersion="16" MinorVersion="2" UserVersion="1" />',
            '        ' + REV,
            '        <Name xlate="true" UID="%s">%s</Name>' % (self.uid('XLS'), escape(name)),
            '        <Command>%s%s</Command>' % ('^C^C' if cancel else '', escape(command or cmd)),
            '        <HelpString xlate="true" UID="%s">%s</HelpString>' % (self.uid('XLS'), escape(desc)),
            '        <SmallImage Name="%s" />' % small,
            '        <LargeImage Name="%s" />' % large,
            '        <CLICommand xlate="true" UID="%s">%s</CLICommand>' % (self.uid('XLS'), escape(parent if command else cmd)),
            '      </Macro>',
            '    </MenuMacro>']))
        self.macro_ids[cmd] = uid
        return uid

    def button(self, cmd, text, title, style, ind):
        """A command button. The first button of a command has the UID RBN_DYL_CMD_<command>,
        so that the ribbon plugin finds it (Plugin\\PhaseCombos.cs adds its drop-downs after
        the Layer Phase button)."""
        sp = ' ' * ind
        uid = 'RBN_DYL_CMD_' + re.sub(r'[^A-Z0-9]', '_', cmd.upper())
        if uid in self.buttons:
            uid = self.uid()
        self.buttons.add(uid)
        return '\n'.join([
            sp + '<RibbonCommandButton UID="%s" Id="AcRibbonCommandButton" Text="%s" ButtonStyle="%s" '
                 'MenuMacroID="%s" KeyTip="">' % (uid, attr(text), style, self.macro_ids[cmd]),
            sp + '  <TooltipTitle xlate="true" UID="%s">%s</TooltipTitle>' % (self.uid('XLS'), escape(title)),
            sp + '  ' + REV,
            sp + '</RibbonCommandButton>'])

    def item(self, it, large, ind):
        """A button of the panel: a command button, or a split button with its children.
        The split button follows the item picked last (the main command first): its face
        shows the image of that item's macro. A split button that does not follow shows its
        own SmallImage / LargeImage, which AutoCAD reads only from its resources, never
        from the images stored in a partial CUIx (its face would have no icon)."""
        style = 'LargeWithText' if large else 'SmallWithText'
        text = two_lines(it['name']) if large else it['name']
        if not it['kids']:
            return self.button(it['cmd'], text, it['name'], style, ind)
        sp = ' ' * ind
        # The items of a variable (@): the button keeps its name (their icon is the same)
        # and runs the item picked last; no main command above them:
        static = it.get('static')
        out = [sp + '<RibbonSplitButton UID="%s" Id="AcRibbonSplitButton" Text="%s" KeyTip="" SmallImage="" '
                    'LargeImage="" Behavior="%s" ListStyle="IconText" ButtonStyle="%s" '
                    'Grouping="false">' % (self.uid(), attr(text), 'SplitFollowStaticText' if static else 'SplitFollow',
                                           style),
               sp + '  ' + REV]
        if not static:
            out += [self.button(it['cmd'], text, it['name'], style, ind + 2),
                    sp + '  <RibbonSeparator UID="%s" Id="AcRibbonSeparator" SeparatorStyle="Line">' % self.uid(),
                    sp + '    ' + REV,
                    sp + '  </RibbonSeparator>']
        for (kid, label, title) in it['kids']:
            out.append(self.button(kid, label, title, 'SmallWithText', ind + 2))
        out.append(sp + '</RibbonSplitButton>')
        return '\n'.join(out)

    def panel(self, name, items):
        uid = 'RBN_DYL_PANEL_' + re.sub(r'[^A-Z0-9]', '_', name.upper())
        out = ['    <RibbonPanelSource UID="%s" Text="%s" HiddenInEditor="false">' % (uid, attr(name)),
               '      ' + REV,
               '      <Name xlate="true" UID="%s">%s - %s</Name>' % (self.uid('XLS'), TAB, escape(name)),
               '      <RibbonRow UID="%s">' % self.uid(),
               '        ' + REV]
        main = [it for it in items if not it['stack'].startswith('>')]
        slide = [it for it in items if it['stack'].startswith('>')]
        i = 0
        items = main
        while i < len(items):
            it = items[i]
            if not it['stack']:
                out.append(self.item(it, True, 8))
                i += 1
                continue
            stack = [it]
            i += 1
            while i < len(items) and items[i]['stack'] == it['stack'] and len(stack) < 3:
                stack.append(items[i])
                i += 1
            out += ['        <RibbonRowPanel UID="%s">' % self.uid(), '          ' + REV]
            for s in stack:
                out += ['          <RibbonRow UID="%s">' % self.uid(), '            ' + REV,
                        self.item(s, False, 12), '          </RibbonRow>']
            out.append('        </RibbonRowPanel>')
        out.append('      </RibbonRow>')
        # the slide-out: a row per stack, under the panel break
        if slide:
            out += ['      <RibbonPanelBreak UID="%s" Id="AcRibbonPanelBreak">' % self.uid(),
                    '        ' + REV, '      </RibbonPanelBreak>']
            rows = []
            for it in slide:
                if not rows or rows[-1][0] != it['stack']:
                    rows.append((it['stack'], []))
                rows[-1][1].append(it)
            for _, its in rows:
                out += ['      <RibbonRow UID="%s">' % self.uid(), '        ' + REV]
                out += [self.item(it, False, 8) for it in its]
                out.append('      </RibbonRow>')
        out.append('    </RibbonPanelSource>')
        return uid, '\n'.join(out)


def placeholder(cmd, size):
    """A grey tile with the first letter of the command, for a command without an icon."""
    c = RibbonIcons.Ic(size)
    c.rect(2, 2, 30, 30, RibbonIcons.GRAY_L, RibbonIcons.INK, r=4)
    c.text(16, 16.5, cmd.split('-')[-1][:1], 18, RibbonIcons.INK)
    return c.result()


def part_xml(root):
    return '<?xml version="1.0"?>\r\n' + WARNING.replace('\n', '\r\n') + '\r\n' + root.replace('\n', '\r\n') + '\r\n'


def build():
    cmds, files = suite_commands()
    b = Builder()
    panels = []   # (name, [items])
    for r in read_csv(LAYOUT):
        cmd = (r.get('Command') or '').strip().upper()
        if not cmd:
            continue
        row = cmds.get(cmd, {})
        name = (r.get('Name') or '').strip() or row.get('Name') or ''
        desc = (r.get('Description') or '').strip() or row.get('Description') or ''
        if not name:
            b.warnings.append('%s is not in StartupSuite.csv and has no Name in Ribbon.csv: skipped.' % cmd)
            continue
        b.macro(cmd, name, desc, cancel=(r.get('Selection') or '').strip() != '1')
        spec = (r.get('Children') or '').strip()
        items = []
        if spec.startswith('@') and '=' in spec:
            # @<variable>=<value>|...: each item sets the variable, then runs the command:
            var, vals = spec[1:].split('=', 1)
            for v in [v.strip() for v in vals.split('|') if v.strip()]:
                key = '%s=%s' % (cmd, v)
                b.macro(key, '%s: %s' % (name, v), desc, cmd, '(setq %s "%s") %s' % (var.strip(), v, cmd))
                items.append((key, v, '%s: %s' % (name, v)))
        else:
            kids = children_of(cmd, spec, cmds, files)
            labels = short_names([cmds[k].get('Name') or k for k in kids])
            for k, label in zip(kids, labels):
                b.macro(k, cmds[k].get('Name') or k, cmds[k].get('Description') or '', cmd)
                items.append((k, label, cmds[k].get('Name') or k))
        panel = (r.get('Panel') or '').strip() or 'DynALisp'
        if not panels or panels[-1][0] != panel:
            if any(p[0] == panel for p in panels):
                b.warnings.append('The rows of panel %s are not together in Ribbon.csv.' % panel)
            panels.append((panel, []))
        panels[-1][1].append({'cmd': cmd, 'name': name, 'stack': (r.get('Stack') or '').strip(), 'kids': items,
                              'static': spec.startswith('@')})

    # main commands of the module that are not on the ribbon:
    on = {it['cmd'] for _, its in panels for it in its}
    for c, r in cmds.items():
        if c.startswith('DYL-') and (r.get('Module') or '') == MODULE and c not in on:
            b.warnings.append('%s (%s) is not on the ribbon: add it to Ribbon.csv.' % (c, r.get('Name')))

    srcs = [b.panel(name, items) for name, items in panels]
    refs = ['      <RibbonPanelSourceReference UID="RBN_DYL_REF_%s" PanelId="%s" ResizeStyle="Default">\n'
            '        %s\n      </RibbonPanelSourceReference>' % (uid[len('RBN_DYL_PANEL_'):], uid, REV)
            for uid, _ in srcs]
    ribbon = '\n'.join(
        ['<RibbonRoot>',
         '  <RibbonPanelSourceCollection xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
         'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">']
        + [x for _, x in srcs]
        + ['  </RibbonPanelSourceCollection>',
           '  <RibbonTabSourceCollection>',
           # WorkspaceBehavior: the tab of a partial CUIx is added to the workspaces of the
           # main CUIx (without it, it is never shown nor offered in Show Tabs):
           '    <RibbonTabSource Text="%s" UID="RBN_DYL_TAB" KeyTip="DY" WorkspaceBehavior="MergeOrAddTab">' % TAB,
           '      ' + REV,
           '      <Name xlate="true" UID="XLS_DYL_TAB">%s</Name>' % TAB]
        + refs
        + ['    </RibbonTabSource>', '  </RibbonTabSourceCollection>', '</RibbonRoot>'])
    popmenus = context_menus(b, cmds)
    menugroup = '\n'.join(
        ['<MenuGroup xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
         'Name="%s" DisplayName="%s">' % (MENUGROUP, MENUGROUP),
         '  <MacroGroup Name="DynALisp">']
        + b.macros + ['  </MacroGroup>', '</MenuGroup>'])
    return part_xml(menugroup), part_xml(ribbon), part_xml(popmenus), b


def context_menus(b, cmds):
    """PopMenuRoot.cui: a menu per alias of ContextMenus.csv, with its commands."""
    menus = []   # (alias, [(macro uid, name)])
    for r in (read_csv(CONTEXT) if os.path.exists(CONTEXT) else []):
        alias = (r.get('Menu') or '').strip().upper()
        cmd = (r.get('Command') or '').strip().upper()
        if not alias or not cmd:
            continue
        row = cmds.get(cmd, {})
        name = (r.get('Name') or '').strip() or row.get('Name') or ''
        if not name:
            b.warnings.append('%s (context menu %s) is not in StartupSuite.csv and has no Name: skipped.' % (cmd, alias))
            continue
        uid = b.macro('CTX-' + cmd, name, row.get('Description') or '', cmd, cmd, cancel=False)
        if not menus or menus[-1][0] != alias:
            menus.append((alias, []))
        menus[-1][1].append((uid, name))
    out = ['<PopMenuRoot xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">']
    # Each context menu has a POPnnn alias first (500 and over: the context menus, as those of
    # acad.cuix: POP507 + OBJECT_MTEXT), then its object alias; without it AutoCAD crashed on
    # the right click (to confirm, see ContextMenus.csv):
    for n, (alias, items) in enumerate(menus):
        out += ['  <PopMenu hasDiesel="false" UID="PM_DYL_%s">' % re.sub(r'[^A-Z0-9]', '_', alias),
                '    ' + REV,
                '    <Alias>POP%d</Alias>' % (900 + n),
                '    <Alias>%s</Alias>' % escape(alias),
                '    <Name xlate="true" UID="%s">%s - %s</Name>' % (b.uid('XLS'), TAB, escape(alias))]
        for uid, name in items:
            out += ['    <PopMenuItem IsSeparator="false" hasDiesel="false" UID="%s">' % b.uid('PMI'),
                    '      ' + REV,
                    '      <NameRef UID="%s" xlate="true">%s</NameRef>' % (b.uid('XLS'), escape(name)),
                    '      <MenuItem>',
                    '        <MacroRef MenuMacroID="%s" />' % uid,
                    '      </MenuItem>',
                    '    </PopMenuItem>']
        out.append('  </PopMenu>')
    out.append('</PopMenuRoot>')
    return '\n'.join(out)


def write_cuix(menugroup, ribbon, popmenus, images):
    old = zipfile.ZipFile(CUIX)
    keep = [(i.filename, old.read(i.filename)) for i in old.infolist()
            if i.filename not in GENERATED and i.filename.endswith('.cui')]
    old.close()
    parts = keep + [('MenuGroup.cui', menugroup.encode('utf-8')), ('RibbonRoot.cui', ribbon.encode('utf-8')),
                    ('PopMenuRoot.cui', popmenus.encode('utf-8'))]
    parts.sort(key=lambda p: p[0].lower())
    imgs = sorted(images.items())
    bom = '﻿'
    ctypes = (bom + '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/'
              'content-types"><Default Extension="cui" ContentType="text/xml" /><Default Extension="rels" ContentType='
              '"application/vnd.openxmlformats-package.relationships+xml" /><Default Extension="png" ContentType='
              '"image/png" /><Default Extension="xml" ContentType="text/xml" /></Types>')
    rels = [bom + '<?xml version="1.0" encoding="utf-8"?><Relationships xmlns="http://schemas.openxmlformats.org/'
            'package/2006/relationships">']
    for i, (n, _) in enumerate(parts):
        rels.append('<Relationship Type="CUI" Target="/%s" Id="R%016x" />' % (n, 0xd71a000000000000 + i))
    for i, (n, _) in enumerate(imgs):
        rels.append('<Relationship Type="Image" Target="/%s" Id="R%016x" />' % (n, 0xd71b000000000000 + i))
    rels.append('</Relationships>')
    now = datetime.datetime.now().astimezone().isoformat(timespec='microseconds')
    info = [bom + '<?xml version="1.0" encoding="utf-8"?>', '<MenuPackageParts>']
    for n, _ in parts + imgs:
        info.append('  <PartData PartData_Name="/%s" PartData_Modified="%s" />' % (n, now))
    info += ['  <PartData PartData_Name="/VirtualMNRRoot" PartData_Modified="%s" />' % now,
             '  <PartData PartData_Name="/Menu_Package_Info.xml" PartData_Modified="%s" />' % now,
             '</MenuPackageParts>']
    tmp = CUIX + '.tmp'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', ctypes.encode('utf-8'))
        z.writestr('_rels/.rels', ''.join(rels).encode('utf-8'))
        for n, data in parts:
            z.writestr(n, data)
        for n, data in imgs:
            z.writestr(n, data)
        z.writestr('Menu_Package_Info.xml', '\r\n'.join(info).encode('utf-8'))
    os.replace(tmp, CUIX)


def icon_sheet(path):
    """Every icon at 32 and 16 px, on the light and the dark ribbon backgrounds."""
    from PIL import Image, ImageDraw
    names = list(RibbonIcons.ICONS)
    cols, cw, ch = 8, 150, 64
    im = Image.new('RGBA', (cols * cw, ((len(names) + cols - 1) // cols) * ch), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    for i, n in enumerate(names):
        x, y = (i % cols) * cw, (i // cols) * ch
        for j, bg in enumerate([(245, 245, 245, 255), (59, 68, 83, 255)]):
            d.rectangle((x + j * 56, y, x + j * 56 + 55, y + 40), fill=bg)
            im.alpha_composite(RibbonIcons.render(n, 32), (x + j * 56 + 3, y + 4))
            im.alpha_composite(RibbonIcons.render(n, 16), (x + j * 56 + 37, y + 4))
        d.text((x + 2, y + 44), n[:24], fill=(0, 0, 0, 255))
    im.save(path)
    print('Icons:', path)


def main():
    args = sys.argv[1:]
    if '--sheet' in args:
        icon_sheet(args[args.index('--sheet') + 1])
        return
    menugroup, ribbon, popmenus, b = build()
    write_cuix(menugroup, ribbon, popmenus, b.images)
    for w in b.warnings:
        print('Warning:', w)
    print('Wrote %s: %d commands, %d images.' % (CUIX, len(b.macro_ids), len(b.images)))


if __name__ == '__main__':
    main()
