# BuildLogo.py - the logo of DynALisp, drawn from its geometry
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
#   python Installer\Logo\BuildLogo.py
#
# Needs the shapely package (pip install shapely).
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


# --- The shapes, worked out as areas, then written as plain paths of lines and arcs ------------
# Each shape is made with shapely (areas cut from each other), then its outline is read back as
# the circles and lines it is made of, so the file holds true arcs, few nodes and no masks or
# transforms: it opens and edits as it is in Inkscape or Illustrator.

import math
from shapely.geometry import Point, LineString, Polygon
from shapely import affinity

Q = 256         # segments per quarter of a circle, to find the outlines


def stadium(l, h, turn=0):
    shape = LineString([(-l, 0), (l, 0)]).buffer(h, quad_segs=Q)
    return affinity.rotate(shape, turn, origin=(0, 0)) if turn else shape


def stadium_parts(l, h, turn=0):
    """The circles and lines of a stadium: ('c', cx, cy, r) and ('l', px, py, dx, dy)."""
    a = math.radians(turn)
    c, s = math.cos(a), math.sin(a)
    rot = lambda x, y: (x * c - y * s, x * s + y * c)
    out = []
    for e in (-1, 1):
        out.append(('c',) + rot(e * l, 0) + (h,))
        out.append(('l',) + rot(0, e * h) + rot(1, 0))
    return out


def geometry():
    """The shapes of the logo, in the frame of the ring (its long axis along x), with their parts."""
    mid = H - RW / 2
    hole = mid - W / 2 - G
    disc = Point(0, 0).buffer(R, quad_segs=Q)
    keep = stadium(L, mid + W / 2 + G)
    shapes = []
    for s, color in ((-1, 0), (1, 1)):      # the crescents of the disc, orange up left
        cut = Point(0, -s * D_OUT).buffer(R + D_OUT - T_OUT, quad_segs=Q)
        area = disc.difference(cut).difference(keep)
        parts = [('c', 0, 0, R), ('c', 0, -s * D_OUT, R + D_OUT - T_OUT)] + stadium_parts(L, mid + W / 2 + G)
        shapes.append((area, parts, color))
    lining = stadium(L, hole).difference(stadium(L - T_END + T_SIDE, hole - T_SIDE, TWIST))
    parts = stadium_parts(L, hole) + stadium_parts(L - T_END + T_SIDE, hole - T_SIDE, TWIST)
    for poly in getattr(lining, 'geoms', [lining]):
        shapes.append((poly, parts, 0 if poly.centroid.x < 0 else 1))
    ring = stadium(L, mid + W / 2).difference(stadium(L, mid - W / 2))
    shapes.append((ring, stadium_parts(L, mid + W / 2) + stadium_parts(L, mid - W / 2), 2))
    return shapes


def _dist(part, x, y):
    if part[0] == 'c':
        return abs(math.hypot(x - part[1], y - part[2]) - part[3])
    _, px, py, dx, dy = part
    return abs((x - px) * dy - (y - py) * dx)


def _meet(a, b, near):
    """Where two parts meet, the point nearest to near."""
    pts = []
    if a[0] == 'l' and b[0] == 'l':
        _, px, py, dx, dy = a
        _, qx, qy, ex, ey = b
        den = dx * ey - dy * ex
        if abs(den) > 1e-12:
            t = ((qx - px) * ey - (qy - py) * ex) / den
            pts.append((px + t * dx, py + t * dy))
    elif a[0] == 'c' and b[0] == 'c':
        _, x0, y0, r0 = a
        _, x1, y1, r1 = b
        d = math.hypot(x1 - x0, y1 - y0)
        if 1e-12 < d <= r0 + r1 and d >= abs(r0 - r1):
            k = (r0 * r0 - r1 * r1 + d * d) / (2 * d)
            h = math.sqrt(max(r0 * r0 - k * k, 0))
            mx, my = x0 + k * (x1 - x0) / d, y0 + k * (y1 - y0) / d
            pts += [(mx + h * (y1 - y0) / d, my - h * (x1 - x0) / d), (mx - h * (y1 - y0) / d, my + h * (x1 - x0) / d)]
    else:
        c, l = (a, b) if a[0] == 'c' else (b, a)
        _, cx, cy, r = c
        _, px, py, dx, dy = l
        fx, fy = px - cx, py - cy
        A, B, C = dx * dx + dy * dy, 2 * (fx * dx + fy * dy), fx * fx + fy * fy - r * r
        disc = B * B - 4 * A * C
        if disc >= 0:
            for t in ((-B - math.sqrt(disc)) / (2 * A), (-B + math.sqrt(disc)) / (2 * A)):
                pts.append((px + t * dx, py + t * dy))
    return min(pts, key=lambda p: math.hypot(p[0] - near[0], p[1] - near[1])) if pts else near


def _ring_path(coords, parts, turn):
    """One closed outline as a path of lines and arcs, turned by turn degrees."""
    pts = list(coords)[:-1]
    n = len(pts)
    # each edge goes to the part its middle lies on (its ends can lie on two parts)
    mids = [((pts[i][0] + pts[(i + 1) % n][0]) / 2, (pts[i][1] + pts[(i + 1) % n][1]) / 2) for i in range(n)]
    tag = [min(range(len(parts)), key=lambda k: _dist(parts[k], x, y)) for x, y in mids]
    start = next((i for i in range(n) if tag[i] != tag[i - 1]), 0)
    runs = []       # [part, the middles of its edges, its first point]
    for j in range(n):
        i = (start + j) % n
        if not runs or runs[-1][0] != tag[i]:
            runs.append([tag[i], [], pts[i]])
        runs[-1][1].append(mids[i])
    m = len(runs)
    # the corners: the first point of each run, set where its part meets the part before it
    corners = [_meet(parts[runs[k - 1][0]], parts[runs[k][0]], runs[k][2]) if m > 1 else runs[k][2] for k in range(m)]
    a = math.radians(turn)
    rot = lambda p: (p[0] * math.cos(a) - p[1] * math.sin(a), p[0] * math.sin(a) + p[1] * math.cos(a))
    num = lambda v: ('%.3f' % v).rstrip('0').rstrip('.')
    f = lambda p: '%s,%s' % tuple(num(v) for v in rot(p))
    d = 'M' + f(corners[0])
    for k in range(m):
        part = parts[runs[k][0]]
        p0, p1 = corners[k], corners[(k + 1) % m]
        if part[0] == 'l':
            d += ' L' + f(p1)
            continue
        _, cx, cy, r = part
        mid_pt = runs[k][1][len(runs[k][1]) // 2]
        ccw = lambda u, v: (v - u) % (2 * math.pi)
        a0, am, a1 = (math.atan2(q[1] - cy, q[0] - cx) for q in (p0, mid_pt, p1))
        grow = ccw(a0, am) < ccw(a0, a1)           # from p0 to p1 through mid, the angle grows
        span = ccw(a0, a1) if grow else ccw(a1, a0)
        if m == 1:                                  # a whole circle: two half arcs
            q = (2 * cx - p0[0], 2 * cy - p0[1])
            d += ' A%s,%s 0 0 1 %s A%s,%s 0 0 1 %s' % (num(r), num(r), f(q), num(r), num(r), f(p0))
            continue
        # turning by -45 degrees keeps the direction of a sweep (a rotation, not a mirror)
        d += ' A%s,%s 0 %d %d %s' % (num(r), num(r), 1 if span > math.pi else 0, 1 if grow else 0, f(p1))
    return d + ' Z'


def paths(turn=-45):
    """The shapes of the logo as (path data, colour index): 0 orange, 1 teal, 2 ring."""
    out = []
    for area, parts, color in geometry():
        for poly in getattr(area, 'geoms', [area]):
            d = _ring_path(poly.exterior.coords, parts, turn)
            for hole in poly.interiors:
                d += ' ' + _ring_path(hole.coords, parts, turn)
            out.append((d, color))
    return out


def mark(ring, colors=(ORANGE, TEAL)):
    """The logo in a -50..50 square, as SVG paths: orange, teal, then the ring."""
    fill = (colors[0], colors[1], ring)
    names = ('orange', 'teal', 'ring')
    groups = {0: [], 1: [], 2: []}
    for d, c in paths():
        groups[c].append(d)
    return ''.join('<g id="%s" fill="%s">%s</g>' % (names[c], fill[c], ''.join(
        '<path d="%s"%s/>' % (d, ' fill-rule="evenodd"' if c == 2 else '') for d in groups[c])) for c in (0, 1, 2))


def logo(ring, colors=(ORANGE, TEAL)):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-50 -50 100 100" width="100" height="100">'
            '<title>DynALisp</title>%s</svg>\n') % mark(ring, colors)


def banner(here):
    words = [l.strip() for l in open(os.path.join(here, 'Wordmark.txt'), encoding='utf-8')
             if l.strip() and not l.startswith('#')]
    letters = ''.join('<path d="%s"/>' % d for d in words)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 975 325" width="975" height="325">'
            '<title>DynALisp</title><rect id="background" x="3" y="2" width="973" height="324.6" fill="%s"/>'
            '<g id="logo" transform="translate(476.5 135) scale(1.57)">%s</g><g id="name" fill="#FFFFFF">%s</g></svg>\n') % (
        NAVY, mark('#FFFFFF'), letters)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    icons = os.path.join(here, '..', '..', 'Contents', 'Resources', 'Icons')
    files = {
        'dynalisp-logo.svg': logo(INK),
        'dynalisp-logo-white.svg': logo('#FFFFFF'),
        'dynalisp-logo-mono.svg': logo('currentColor', ('currentColor', 'currentColor')),
        'dynalisp-banner-readme.svg': banner(here),
    }
    for name, text in files.items():
        with open(os.path.join(icons, name), 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)
    print('Logo written in Contents\\Resources\\Icons: ' + ', '.join(files))


if __name__ == '__main__':
    main()
