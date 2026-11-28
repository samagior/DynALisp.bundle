# BuildLogo.py - the logo of DynALisp, drawn from its geometry
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Logo\BuildLogo.py
#
# Writes the logo and the banner in Contents\Resources\Icons, never edited by hand:
#
#   dynalisp-logo.svg          the logo in its colours, its ring dark: on a light background
#   dynalisp-logo-white.svg    the same, its ring white: on a dark background
#   dynalisp-logo-mono.svg     one colour, the colour of the text (currentColor)
#   dynalisp-banner-readme.svg the banner of the README and of the home of the docs website:
#                              the logo over the name (the letters of Wordmark.txt), on navy
#
# The logo: a disc cut on the slant by a ring (a stadium turned 45 degrees). The disc is left as
# two crescents, thick in their middle and thin toward the ring; inside the ring, a lining that
# follows it, turned a little, thick where the crescents are and gone on the other sides. Orange
# up left, teal down right, outside as inside: tones deep enough to stand out on a light page
# as on a dark one (the ribbon icons use the same orange and teal, RibbonIcons.py).
#
# The banner is the head of README.md and of the home of the docs website (BuildSite.py).

import os

ORANGE = '#E07A1F'
TEAL = '#1E9592'
INK = '#1A1A1A'
NAVY = '#18283D'

R = 48          # the disc
L = 24          # half the distance between the centres of the ends of the ring
H = 28.5        # outer half height of the ring
RW = 9.5        # thickness of the ring the drawing is based on
W = 8.0         # thickness of the ring drawn
G = 3.2         # gap around the ring
T_OUT, D_OUT = 12.0, 16.0           # crescents of the disc: thickness in their middle, offset
T_END, T_SIDE, TWIST = 7.0, -0.6, 9  # lining: thickness at the ends, on the sides, its turn
U = 'maskUnits="userSpaceOnUse" x="-60" y="-60" width="120" height="120"'


def pill(l, h):
    """A stadium along x: its ends are half circles of radius h, l from the centre."""
    return 'M%g,%g H%g A%g,%g 0 0 1 %g,%g H%g A%g,%g 0 0 1 %g,%g Z' % (
        -l, -h, l, h, h, l, h, -l, h, h, -l, -h)


def mark(ring, ids='', colors=(ORANGE, TEAL)):
    """The logo in a -50..50 square: (defs, body). ring is the colour of the ring."""
    mid = H - RW / 2
    hole = mid - W / 2 - G
    defs = ''
    for i, s in enumerate((-1, 1)):     # the two crescents of the disc
        defs += ('<mask id="%so%d" %s><circle r="%g" fill="#fff"/><circle cy="%g" r="%g" fill="#000"/>'
                 '<rect x="-60" y="%g" width="120" height="60" fill="#000"/>'
                 '<path d="%s" fill="#000" stroke="#000" stroke-width="%g"/></mask>') % (
            ids, i, U, R, -s * D_OUT, R + D_OUT - T_OUT, 0 if s < 0 else -60, pill(L, mid), W + 2 * G)
    defs += ('<mask id="%sin" %s><path d="%s" fill="#fff"/><path d="%s" fill="#000" transform="rotate(%g)"/>'
             '</mask>') % (ids, U, pill(L, hole), pill(L - T_END + T_SIDE, hole - T_SIDE), TWIST)
    defs += '<mask id="%sl" %s><rect x="-60" y="-60" width="60" height="120" fill="#fff"/></mask>' % (ids, U)
    defs += '<mask id="%sr" %s><rect x="0" y="-60" width="60" height="120" fill="#fff"/></mask>' % (ids, U)
    body = ('<circle r="%g" mask="url(#%so0)" fill="%s"/><circle r="%g" mask="url(#%so1)" fill="%s"/>'
            '<g mask="url(#%sl)"><path d="%s" mask="url(#%sin)" fill="%s"/></g>'
            '<g mask="url(#%sr)"><path d="%s" mask="url(#%sin)" fill="%s"/></g>'
            '<path d="%s" fill="none" stroke="%s" stroke-width="%g"/>') % (
        R, ids, colors[0], R, ids, colors[1], ids, pill(L, hole), ids, colors[0],
        ids, pill(L, hole), ids, colors[1], pill(L, mid), ring, W)
    return defs, '<g transform="rotate(-45)">%s</g>' % body


def logo(ring, colors=(ORANGE, TEAL), ids='dl'):
    defs, body = mark(ring, ids, colors)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100" width="100" height="100">'
            '<title>DynALisp</title><defs>%s</defs>%s</svg>\n') % (defs, body)


def banner(here):
    words = [l.strip() for l in open(os.path.join(here, 'Wordmark.txt'), encoding='utf-8')
             if l.strip() and not l.startswith('#')]
    defs, body = mark('#FFFFFF', 'db')
    letters = ''.join('<path d="%s"/>' % d for d in words)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 975 325" width="975" height="325">'
            '<title>DynALisp</title><defs>%s</defs><rect x="3" y="2" width="973" height="324.6" fill="%s"/>'
            '<g transform="translate(476.5 135) scale(1.57)">%s</g><g fill="#FFFFFF">%s</g></svg>\n') % (
        defs, NAVY, body, letters)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    icons = os.path.join(here, '..', '..', 'Contents', 'Resources', 'Icons')
    files = {
        'dynalisp-logo.svg': logo(INK),
        'dynalisp-logo-white.svg': logo('#FFFFFF'),
        'dynalisp-logo-mono.svg': logo('currentColor', ('currentColor', 'currentColor')).replace(
            ' width="100" height="100"', ' width="100" height="100" fill="currentColor"'),
        'dynalisp-banner-readme.svg': banner(here),
    }
    for name, text in files.items():
        with open(os.path.join(icons, name), 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)
    print('Logo written in Contents\\Resources\\Icons: ' + ', '.join(files))


if __name__ == '__main__':
    main()
