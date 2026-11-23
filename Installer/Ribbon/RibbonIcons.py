# RibbonIcons.py - the icons of the DynALisp ribbon, drawn with Pillow
# Copyright (C) 2026  Samuel Martineau, GNU General Public License v3
#
# Each icon is a function drawing on a 32 x 32 unit canvas (Ic), rendered at 16 and 32
# pixels (supersampled, then reduced). Strokes and pattern spacings are given in pixels
# of the size drawn, so the 16 px icons keep readable lines. ICONS maps a command name
# (as in Ribbon.csv, without C:) to its function; a child command without an icon of its
# own uses the icon of its main command (see BuildRibbon.py).
#
# Flat colours as the AutoCAD icons: dark outlines, light fills and the DynALisp colours
# (the orange and teal of the logo), readable on the light and the dark ribbon themes.

import math
import random
from PIL import Image, ImageDraw, ImageFont

INK = (58, 64, 76, 255)
PAPER = (255, 255, 255, 255)
TEAL = (30, 160, 160, 255)
TEAL_L = (120, 218, 217, 255)
ORANGE = (240, 135, 35, 255)
ORANGE_L = (252, 190, 120, 255)
RED = (214, 58, 50, 255)
GREEN = (52, 158, 78, 255)
BLUE = (45, 118, 205, 255)
BLUE_L = (150, 195, 240, 255)
YELLOW = (246, 198, 48, 255)
PURPLE = (140, 92, 196, 255)
GRAY = (140, 147, 158, 255)
GRAY_L = (212, 217, 224, 255)
GRAY_D = (98, 105, 118, 255)
NONE = (0, 0, 0, 0)

FONT_BOLD = 'C:/Windows/Fonts/arialbd.ttf'


class Ic:
    """A 32 x 32 unit canvas drawn at size pixels (SS times larger, reduced at the end)."""
    SS = 8

    def __init__(self, size):
        self.size = size
        self.small = size <= 16
        self.S = size * self.SS
        self.k = self.S / 32.0
        self.im = Image.new('RGBA', (self.S, self.S), NONE)
        self.d = ImageDraw.Draw(self.im)

    # --- units
    def p(self, x, y):
        return (x * self.k, y * self.k)

    def pts(self, ps):
        return [self.p(x, y) for x, y in ps]

    def w(self, px=None):
        """A stroke of px pixels of the size drawn (default: the outline)."""
        if px is None:
            px = 1.0 if self.small else 1.5
        return max(1, int(round(px * self.SS)))

    def u(self, px):
        """px pixels of the size drawn, in units."""
        return px * 32.0 / self.size

    # --- shapes
    def line(self, ps, color=INK, px=None, caps=True):
        ps = self.pts(ps)
        wd = self.w(px)
        self.d.line(ps, fill=color, width=wd, joint='curve')
        if caps:
            r = wd / 2.0
            for x, y in (ps[0], ps[-1]):
                self.d.ellipse((x - r, y - r, x + r, y + r), fill=color)

    def dashed(self, p0, p1, color=INK, px=None, dash=3, gap=2):
        """A dashed line, dash and gap in pixels of the size drawn."""
        (x0, y0), (x1, y1) = p0, p1
        ln = math.hypot(x1 - x0, y1 - y0)
        if ln == 0:
            return
        ux, uy = (x1 - x0) / ln, (y1 - y0) / ln
        dl, gl = self.u(dash), self.u(gap)
        t = 0.0
        while t < ln:
            t1 = min(ln, t + dl)
            self.line([(x0 + ux * t, y0 + uy * t), (x0 + ux * t1, y0 + uy * t1)], color, px, caps=False)
            t = t1 + gl

    def poly(self, ps, fill=None, outline=INK, px=None):
        if fill:
            self.d.polygon(self.pts(ps), fill=fill)
        if outline:
            self.line(list(ps) + [ps[0]], outline, px)

    def rect(self, x0, y0, x1, y1, fill=PAPER, outline=INK, px=None, r=0):
        box = (x0 * self.k, y0 * self.k, x1 * self.k, y1 * self.k)
        if r:
            self.d.rounded_rectangle(box, radius=r * self.k, fill=fill,
                                     outline=outline, width=self.w(px) if outline else 0)
        else:
            if fill:
                self.d.rectangle(box, fill=fill)
            if outline:
                self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], None, outline, px)

    def circle(self, cx, cy, r, fill=PAPER, outline=INK, px=None):
        box = ((cx - r) * self.k, (cy - r) * self.k, (cx + r) * self.k, (cy + r) * self.k)
        self.d.ellipse(box, fill=fill, outline=outline, width=self.w(px) if outline else 0)

    def arc(self, cx, cy, r, a0, a1, color=INK, px=None):
        box = ((cx - r) * self.k, (cy - r) * self.k, (cx + r) * self.k, (cy + r) * self.k)
        self.d.arc(box, a0, a1, fill=color, width=self.w(px))

    def text(self, x, y, s, h, color=INK, font=FONT_BOLD):
        f = ImageFont.truetype(font, int(h * self.k))
        self.d.text(self.p(x, y), s, fill=color, font=f, anchor='mm')

    # --- clipping: draw into a blank canvas, keep it inside a polygon or rectangle
    def sub(self):
        return Ic(self.size)

    def paste(self, other, clip_ps):
        mask = Image.new('L', (self.S, self.S), 0)
        ImageDraw.Draw(mask).polygon(self.pts(clip_ps), fill=255)
        layer = Image.new('RGBA', (self.S, self.S), NONE)
        layer.paste(other.im, (0, 0), mask)
        self.im.alpha_composite(layer)

    def result(self):
        return self.im.resize((self.size, self.size), Image.LANCZOS)


def box(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


# ---------------------------------------------------------------- glyphs

def arrow(c, p0, p1, color=INK, px=None, head=None):
    """A line from p0 to p1 with a filled head at p1."""
    (x0, y0), (x1, y1) = p0, p1
    ln = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / ln, (y1 - y0) / ln
    h = head or (6 if c.small else 5)
    bx, by = x1 - ux * h, y1 - uy * h
    c.line([p0, (bx, by)], color, px if px else (1.5 if c.small else 2))
    c.poly([(x1, y1), (bx - uy * h * 0.6, by + ux * h * 0.6), (bx + uy * h * 0.6, by - ux * h * 0.6)], color, None)


def plate(c, x, y, w, h, fill, outline=INK, dashed=False):
    """A layer: a flat rhombus, its left corner at (x, y)."""
    ps = [(x, y), (x + w / 2, y - h / 2), (x + w, y), (x + w / 2, y + h / 2)]
    if dashed:
        c.poly(ps, fill, None)
        for i in range(4):
            c.dashed(ps[i], ps[(i + 1) % 4], outline, None, 2.5, 1.5)
    else:
        c.poly(ps, fill, outline)


def layers(c, x=2, y=22, w=24, h=11, dy=5, fills=(GRAY_L, TEAL_L, PAPER), n=3, dashed=()):
    """A stack of layers, the bottom one first (fills), from its left corner (x, y)."""
    for i in range(n):
        plate(c, x, y - i * dy, w, h, fills[i % len(fills)], dashed=(i in dashed))


def key(c, cx, cy, s=1.0, color=ORANGE):
    """A key, its bow centred at (cx, cy), pointing right-down."""
    r = 4.2 * s
    c.circle(cx, cy, r, color, INK)
    c.circle(cx, cy, r * 0.38, PAPER, None)
    a = math.radians(40)
    ex, ey = cx + math.cos(a) * 11 * s, cy + math.sin(a) * 11 * s
    sx, sy = cx + math.cos(a) * r, cy + math.sin(a) * r
    c.line([(sx, sy), (ex, ey)], INK, 2.6 if not c.small else 1.8)
    c.line([(sx, sy), (ex, ey)], color, 1.2 if not c.small else 0.6)
    # teeth
    nx, ny = -math.sin(a), math.cos(a)
    for t in (0.72, 0.92):
        tx, ty = cx + math.cos(a) * 11 * s * t, cy + math.sin(a) * 11 * s * t
        c.line([(tx, ty), (tx + nx * 3 * s, ty + ny * 3 * s)], INK, 1.6 if not c.small else 1.2)


def pencil(c, tip, length=15, ang=-45, color=ORANGE):
    """A pencil, its tip at tip, going up-right at ang degrees."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    hw = 2.6
    tx, ty = tip
    b0 = (tx + ux * 5, ty + uy * 5)
    e0 = (tx + ux * length, ty + uy * length)
    body = [(b0[0] + nx * hw, b0[1] + ny * hw), (e0[0] + nx * hw, e0[1] + ny * hw),
            (e0[0] - nx * hw, e0[1] - ny * hw), (b0[0] - nx * hw, b0[1] - ny * hw)]
    c.poly(body, color, INK)
    c.poly([tip, (b0[0] + nx * hw, b0[1] + ny * hw), (b0[0] - nx * hw, b0[1] - ny * hw)], (250, 225, 180, 255), INK)
    c.circle(tx + ux * 1.3, ty + uy * 1.3, 1.1, INK, None)
    er = (e0[0] - ux * 3, e0[1] - uy * 3)
    c.line([(er[0] + nx * hw, er[1] + ny * hw), (er[0] - nx * hw, er[1] - ny * hw)], INK)


def gear(c, cx, cy, r, fill=GRAY_L, teeth=8, hole=PAPER):
    ps = []
    ri = r * 0.74
    n = teeth * 4
    for i in range(n):
        a = 2 * math.pi * i / n + math.pi / n
        rr = r if (i % 4) in (0, 1) else ri
        ps.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    c.poly(ps, fill, INK)
    c.circle(cx, cy, r * 0.34, hole, INK)


def plus(c, cx, cy, r=5, color=GREEN):
    c.circle(cx, cy, r, color, PAPER, 1 if c.small else 1.2)
    c.line([(cx - r * 0.55, cy), (cx + r * 0.55, cy)], PAPER, 1.4 if c.small else 2)
    c.line([(cx, cy - r * 0.55), (cx, cy + r * 0.55)], PAPER, 1.4 if c.small else 2)


def check(c, cx, cy, r=5, color=GREEN):
    c.circle(cx, cy, r, color, PAPER, 1 if c.small else 1.2)
    c.line([(cx - r * 0.5, cy), (cx - r * 0.12, cy + r * 0.4), (cx + r * 0.55, cy - r * 0.42)], PAPER,
           1.4 if c.small else 2)


def sheet(c, x0, y0, x1, y1, fill=PAPER, fold=5):
    c.poly([(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)], fill, INK)
    c.poly([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)], GRAY_L, INK)


def text_lines(c, x0, y0, x1, n, dy=4, color=GRAY):
    for i in range(n):
        xe = x1 if i < n - 1 else x0 + (x1 - x0) * 0.6
        c.line([(x0, y0 + i * dy), (xe, y0 + i * dy)], color, 1 if c.small else 1.5)


def folder(c, x0, y0, x1, y1, fill=ORANGE_L, open_=False):
    tab = (x1 - x0) * 0.38
    c.poly([(x0, y0 + 3), (x0, y0), (x0 + tab, y0), (x0 + tab + 3, y0 + 3)], fill, INK)
    if open_:
        c.poly([(x0, y0 + 3), (x1 - 3, y0 + 3), (x1 - 3, y0 + 7), (x0, y0 + 7)], PAPER, None)
        c.poly([(x0, y0 + 3), (x1 - 3, y0 + 3), (x1 - 3, y0 + 7)], None, INK)
        c.poly([(x0, y1), (x0 + 4, y0 + 8), (x1 + 1, y0 + 8), (x1 - 3, y1)], fill, INK)
        c.line([(x0, y0 + 3), (x0, y1)])
    else:
        c.rect(x0, y0 + 3, x1, y1, fill, INK)


def funnel(c, cx, top, w=13, h=13, color=ORANGE):
    c.poly([(cx - w / 2, top), (cx + w / 2, top), (cx + 1.6, top + h * 0.55), (cx + 1.6, top + h),
            (cx - 1.6, top + h - 1.6), (cx - 1.6, top + h * 0.55)], color, INK)


def eye(c, cx, cy, w=24, mode='open'):
    """An eye: open (shown), closed (hidden, slashed) or half (screened)."""
    h = w * 0.36
    ps = []
    for i in range(25):
        t = i / 24.0
        ps.append((cx - w / 2 + w * t, cy - math.sin(math.pi * t) * h))
    for i in range(25):
        t = 1 - i / 24.0
        ps.append((cx - w / 2 + w * t, cy + math.sin(math.pi * t) * h))
    c.poly(ps, PAPER if mode != 'half' else GRAY_L, INK)
    iris = TEAL if mode == 'open' else (GRAY if mode == 'half' else GRAY_L)
    c.circle(cx, cy, h * 0.8, iris, INK)
    c.circle(cx, cy, h * 0.32, INK, None)
    if mode == 'closed':
        c.line([(cx - w / 2 + 2, cy + h + 2), (cx + w / 2 - 2, cy - h - 2)], PAPER, 3.5 if not c.small else 2.5)
        c.line([(cx - w / 2 + 2, cy + h + 2), (cx + w / 2 - 2, cy - h - 2)], RED, 2 if not c.small else 1.4)


def table(c, x0, y0, x1, y1, rows=3, cols=3, head=TEAL_L):
    c.rect(x0, y0, x1, y1, PAPER, None)
    dy = (y1 - y0) / rows
    c.rect(x0, y0, x1, y0 + dy, head, None)
    for i in range(1, rows):
        c.line([(x0, y0 + i * dy), (x1, y0 + i * dy)], INK, 1 if c.small else 1.2, caps=False)
    for j in range(1, cols):
        x = x0 + (x1 - x0) * j / cols
        c.line([(x, y0 + dy), (x, y1)], INK, 1 if c.small else 1.2, caps=False)
    c.rect(x0, y0, x1, y1, None, INK)


def curved_arrow(c, cx, cy, r, a0, a1, color=TEAL, px=None):
    """An arc from a0 to a1 degrees (clockwise in the image) with a head at a1."""
    px = px or (1.6 if c.small else 2.2)
    c.arc(cx, cy, r, a0, a1, color, px)
    a = math.radians(a1)
    ex, ey = cx + math.cos(a) * r, cy + math.sin(a) * r
    tx, ty = -math.sin(a), math.cos(a)  # tangent, clockwise
    h = 5.5 if c.small else 4.5
    c.poly([(ex + tx * h, ey + ty * h), (ex - math.cos(a) * h * 0.6, ey - math.sin(a) * h * 0.6),
            (ex + math.cos(a) * h * 0.6, ey + math.sin(a) * h * 0.6)], color, None)


# ---------------------------------------------------------------- hatch patterns

def pat_lines(c, ang, sp, color=INK, px=None, dash=None, offset=0.0):
    """Parallel lines at ang degrees, sp pixels apart, over the whole canvas."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    s = c.u(sp)
    for i in range(-30, 31):
        o = i * s + offset * s
        cx, cy = 16 + nx * o, 16 + ny * o
        p0, p1 = (cx - ux * 48, cy - uy * 48), (cx + ux * 48, cy + uy * 48)
        if dash:
            c.dashed(p0, p1, color, px, dash[0], dash[1])
        else:
            c.line([p0, p1], color, px, caps=False)


def pattern(c, kind, x0, y0, x1, y1, bg, fg=INK, clip=None):
    """Fill the rectangle (or the polygon clip) with the hatch pattern kind."""
    s = c.sub()
    lw = 0.7 if c.small else 0.9
    rnd = random.Random(7)
    s.rect(0, 0, 32, 32, bg, None)
    if kind == 'ansi31':
        pat_lines(s, -45, 4, fg, lw)
    elif kind == 'ansi32':
        pat_lines(s, -45, 5, fg, lw)
        pat_lines(s, -45, 5, fg, lw, offset=0.3)
    elif kind == 'ansi33':
        pat_lines(s, -45, 5, fg, lw)
        pat_lines(s, -45, 5, fg, lw, dash=(2, 1.5), offset=0.5)
    elif kind == 'ansi34':
        pat_lines(s, -45, 7, fg, lw)
        pat_lines(s, -45, 7, fg, lw, offset=0.2)
        pat_lines(s, -45, 7, fg, lw, offset=0.4)
    elif kind == 'ansi35':
        pat_lines(s, -45, 5, fg, lw)
        pat_lines(s, -45, 5, fg, lw, dash=(1, 1), offset=0.5)
    elif kind == 'ansi36':
        pat_lines(s, -45, 4, fg, lw, dash=(4, 1.5))
    elif kind == 'ansi37':
        pat_lines(s, -45, 4, fg, lw)
        pat_lines(s, 45, 4, fg, lw)
    elif kind == 'ansi38':
        pat_lines(s, -45, 4, fg, lw)
        pat_lines(s, 45, 8, fg, lw, dash=(2, 4))
    elif kind in ('concrete', 'lwconcrete'):
        n = 10 if c.small else 22
        for i in range(n):
            x, y = rnd.uniform(0, 32), rnd.uniform(0, 32)
            if kind == 'concrete' and i % 3 == 0:
                r = s.u(1.4)
                s.poly([(x, y - r), (x + r, y + r * 0.8), (x - r, y + r * 0.8)], None, fg, lw)
            else:
                s.circle(x, y, s.u(0.55), fg, None)
    elif kind in ('stipple', 'texture', 'sand'):
        n = {'stipple': (14, 34), 'texture': (20, 60), 'sand': (24, 70)}[kind][0 if c.small else 1]
        for i in range(n):
            s.circle(rnd.uniform(0, 32), rnd.uniform(0, 32), s.u(0.5), fg, None)
    elif kind == 'wood':      # plank: grain
        for i in range(-2, 12):
            y = i * s.u(4)
            ps = [(x, y + math.sin(x / 32 * 2 * math.pi + i) * s.u(1)) for x in range(-2, 35, 2)]
            s.line(ps, fg, lw, caps=False)
    elif kind == 'brick':     # running bond, in elevation
        hgt, wid = s.u(4), s.u(8)
        for j in range(0, 12):
            y = j * hgt
            s.line([(0, y), (32, y)], fg, lw, caps=False)
            for i in range(-1, 10):
                x = i * wid + (wid / 2 if j % 2 else 0)
                s.line([(x, y), (x, y + hgt)], fg, lw, caps=False)
    elif kind == 'plywood':
        for i in range(0, 12):
            y = i * s.u(3)
            s.line([(0, y), (32, y)], fg, lw, caps=False)
    elif kind == 'woodframe':
        s.line([(x0, y0), (x1, y1)], fg, lw)
        s.line([(x0, y1), (x1, y0)], fg, lw)
    elif kind == 'net':
        pat_lines(s, 0, 4, fg, lw)
        pat_lines(s, 60, 4, fg, lw)
        pat_lines(s, -60, 4, fg, lw)
    elif kind == 'honey':
        r = s.u(3)
        for j in range(-1, 12):
            for i in range(-1, 12):
                cx = i * r * 1.732 + (j % 2) * r * 0.866
                cy = j * r * 1.5
                ps = [(cx + math.cos(math.radians(30 + 60 * k)) * r, cy + math.sin(math.radians(30 + 60 * k)) * r)
                      for k in range(6)]
                s.poly(ps, None, fg, lw)
    elif kind == 'insulation':
        amp, per = s.u(3), s.u(4)
        for row in range(-1, 4):
            yc = 4 + row * s.u(8)
            ps = []
            x = -per
            k = 0
            while x < 36:
                ps.append((x, yc + (amp if k % 2 else -amp)))
                x += per / 2
                k += 1
            s.line(ps, fg, lw, caps=False)
    elif kind in ('earth', 'topsoil', 'undisturbed'):
        g = s.u(6)
        for j in range(-1, 8):
            for i in range(-1, 8):
                ox, oy = i * g, j * g
                for t in (0.2, 0.5, 0.8):
                    if (i + j) % 2 == 0:
                        s.line([(ox + g * t, oy), (ox + g * t, oy + g * 0.9)], fg, lw, caps=False)
                    else:
                        s.line([(ox, oy + g * t), (ox + g * 0.9, oy + g * t)], fg, lw, caps=False)
    elif kind == 'asphalt':
        for i in range(16 if c.small else 34):
            x, y = rnd.uniform(0, 32), rnd.uniform(0, 32)
            if i % 2:
                s.circle(x, y, s.u(0.5), fg, None)
            else:
                s.line([(x, y), (x + s.u(2), y)], fg, lw, caps=False)
    elif kind in ('gravel', 'crushed'):
        for i in range(8 if c.small else 16):
            x, y = rnd.uniform(0, 32), rnd.uniform(0, 32)
            r = s.u(rnd.uniform(1.2, 2.0))
            if kind == 'gravel':
                s.circle(x, y, r, None, fg, lw)
            else:
                s.poly([(x - r, y), (x, y - r), (x + r * 1.1, y + r * 0.3), (x - r * 0.2, y + r)], None, fg, lw)
    elif kind == 'solid':
        pass
    s_clip = clip or box(x0, y0, x1, y1)
    c.paste(s, s_clip)


# The swatch of each material of Quick Draw (its pattern, background, line colour):
MATERIALS = {
    'DEMOLITION': ('ansi31', PAPER, RED),
    'NOTINCONTRACT': ('ansi31', PAPER, GRAY),
    'EXISTING': ('solid', GRAY_L, INK),
    'CONCRETE': ('concrete', (228, 228, 222, 255), INK),
    'LIGHTWEIGHTCONCRETE': ('lwconcrete', (238, 238, 232, 255), INK),
    'MORTAR': ('stipple', (236, 232, 220, 255), INK),
    'BRICK': ('ansi31', (240, 170, 140, 255), INK),
    'STONE': ('ansi33', (215, 210, 200, 255), INK),
    'CMU': ('ansi37', (210, 214, 218, 255), INK),
    'FIREBRICK': ('ansi35', (232, 140, 110, 255), INK),
    'MARBLE': ('ansi36', (245, 242, 236, 255), INK),
    'GROUT': ('stipple', (226, 222, 210, 255), INK),
    'IRON': ('ansi31', (175, 180, 188, 255), INK),
    'STEEL': ('ansi32', (190, 205, 225, 255), INK),
    'BRONZE': ('ansi33', (225, 180, 110, 255), INK),
    'LEAD': ('ansi37', (160, 165, 175, 255), INK),
    'ALUMINIUM': ('ansi38', (215, 222, 230, 255), INK),
    'PLYWOOD': ('plywood', (240, 205, 150, 255), (150, 100, 50, 255)),
    'WOODPLANK': ('wood', (240, 205, 150, 255), (150, 100, 50, 255)),
    'WOODFRAME': ('woodframe', (245, 215, 165, 255), (150, 100, 50, 255)),
    'PARTICLEBOARD': ('texture', (235, 205, 160, 255), (120, 80, 40, 255)),
    'HARDBOARD': ('ansi31', (210, 170, 120, 255), (110, 70, 30, 255)),
    'PLASTIC': ('ansi34', (200, 230, 240, 255), INK),
    'LOOSEINSULATION': ('net', (255, 230, 150, 255), INK),
    'SPRAYINSULATION': ('honey', (255, 236, 170, 255), INK),
    'RIGIDINSULATION': ('insulation', (250, 200, 215, 255), INK),
    'GYPSUM': ('texture', (246, 246, 246, 255), INK),
    'PLASTER': ('texture', (240, 236, 226, 255), INK),
    'COMPACTEDSOIL': ('earth', (200, 165, 120, 255), (90, 60, 30, 255)),
    'TOPSOIL': ('earth', (150, 115, 80, 255), (60, 40, 20, 255)),
    'UNDISTURBEDSOIL': ('earth', (180, 140, 95, 255), (70, 45, 20, 255)),
    'SAND': ('sand', (240, 220, 160, 255), (140, 110, 50, 255)),
    'ASPHALT': ('asphalt', (110, 115, 122, 255), (230, 232, 235, 255)),
    'GRAVEL': ('gravel', (215, 210, 195, 255), INK),
    'CRUSHEDSTONE': ('crushed', (205, 205, 200, 255), INK),
}


def swatch(c, mat, x0=3, y0=3, x1=29, y1=29):
    kind, bg, fg = MATERIALS[mat]
    pattern(c, kind, x0, y0, x1, y1, bg, fg)
    if mat in ('DEMOLITION', 'NOTINCONTRACT'):
        col = RED if mat == 'DEMOLITION' else GRAY_D
        for p0, p1 in [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]:
            c.dashed(p0, p1, col, None, 3, 2)
    else:
        c.rect(x0, y0, x1, y1, None, INK)


# ---------------------------------------------------------------- core

def i_settings(c):
    gear(c, 16, 16, 14, TEAL_L, 8)


def i_suite(c):
    c.rect(3, 3, 14.5, 14.5, TEAL, INK, r=2)
    c.rect(17.5, 3, 29, 14.5, ORANGE_L, INK, r=2)
    c.rect(3, 17.5, 14.5, 29, GRAY_L, INK, r=2)
    c.rect(17.5, 17.5, 29, 29, TEAL_L, INK, r=2)


def i_userfiles(c):
    folder(c, 2, 5, 26, 25)
    c.circle(22.5, 22.5, 8, TEAL, PAPER, 1 if c.small else 1.3)
    c.circle(22.5, 19.8, 2.6, PAPER, None)
    c.d.pieslice(c.p(22.5 - 5, 22.5) + c.p(22.5 + 5, 22.5 + 9.5), 180, 360, fill=PAPER)


def i_info(c):
    c.circle(16, 16, 14, TEAL, INK)
    c.circle(16, 9, 2.2, PAPER, None)
    c.line([(16, 14), (16, 24)], PAPER, 3 if not c.small else 2.2)


def i_docs(c):
    c.poly([(16, 8), (16, 28), (3, 25), (3, 5)], PAPER, INK)
    c.poly([(16, 8), (16, 28), (29, 25), (29, 5)], PAPER, INK)
    c.line([(16, 8), (16, 28)], ORANGE, 2 if c.small else 2.5)
    if not c.small:
        for i in range(3):
            c.line([(6, 11 + i * 4), (13, 12.5 + i * 4)], GRAY, 1.2)
            c.line([(19, 12.5 + i * 4), (26, 11 + i * 4)], GRAY, 1.2)


def i_reload(c):
    curved_arrow(c, 16, 16, 11, 200, 330, TEAL)
    curved_arrow(c, 16, 16, 11, 20, 150, ORANGE)


# ---------------------------------------------------------------- draw

def i_quickdraw(c):
    pattern(c, 'ansi31', 2, 13, 24, 29, ORANGE_L, INK)
    c.rect(2, 13, 24, 29, None, INK)
    pencil(c, (22, 14), 15, -45)


def i_quickdrawgallery(c):
    # the gallery: four material tiles
    swatch(c, 'CONCRETE', 2, 2, 15, 15)
    swatch(c, 'BRICK', 17, 2, 30, 15)
    swatch(c, 'RIGIDINSULATION', 2, 17, 15, 30)
    swatch(c, 'STEEL', 17, 17, 30, 30)


# ---------------------------------------------------------------- gallery groups
# The items under the arrow of the Quick Draw button (the groups of the gallery, see the
# @ items of Ribbon.csv): their key is PST-QUICKDRAWGALLERY=<group>.

def g_all(c):
    # every preset: a grid of nine tiles
    fills = [ORANGE_L, GRAY_L, TEAL_L, BLUE_L, PAPER, ORANGE_L, GRAY_L, TEAL_L, (245, 160, 150, 255)]
    for i, f in enumerate(fills):
        x, y = 2 + (i % 3) * 10, 2 + (i // 3) * 10
        c.rect(x, y, x + 8, y + 8, f, INK, 0.8 if c.small else 1.1)


def g_phase(c):
    # existing (grey), demolition (red, dashed), new (teal)
    c.rect(2, 2, 18, 18, GRAY_L, INK)
    c.rect(8, 8, 24, 24, (245, 160, 150, 255), None)
    for p0, p1 in [((8, 8), (24, 8)), ((24, 8), (24, 24)), ((24, 24), (8, 24)), ((8, 24), (8, 8))]:
        c.dashed(p0, p1, RED, None, 2.5, 1.5)
    c.rect(14, 14, 30, 30, TEAL_L, INK)


def g_section(c):
    # a wall cut: brick, insulation, gypsum
    pattern(c, 'ansi31', 2, 3, 13, 29, (240, 170, 140, 255), INK)
    pattern(c, 'insulation', 13, 3, 24, 29, (250, 200, 215, 255), INK)
    pattern(c, 'texture', 24, 3, 30, 29, PAPER, INK)
    for x in (13, 24):
        c.line([(x, 3), (x, 29)], INK, None, caps=False)
    c.rect(2, 3, 30, 29, None, INK)


def g_detail(c):
    # a hatched corner under a magnifier
    pattern(c, 'ansi31', 2, 2, 22, 22, ORANGE_L, INK, clip=[(2, 2), (22, 2), (22, 9), (9, 9), (9, 22), (2, 22)])
    c.poly([(2, 2), (22, 2), (22, 9), (9, 9), (9, 22), (2, 22)], None, INK)
    c.line([(21, 21), (29, 29)], ORANGE, 4 if not c.small else 3)
    c.circle(16, 16, 8, (255, 255, 255, 170), BLUE, 2 if not c.small else 1.4)


def g_elevation(c):
    # a facade: brick courses, a window and a door, on the ground
    pattern(c, 'brick', 4, 6, 28, 27, (240, 170, 140, 255), INK)
    c.rect(4, 6, 28, 27, None, INK)
    c.rect(7, 10, 14, 17, BLUE_L, INK)
    c.rect(18, 15, 24, 27, GRAY_D, INK)
    c.line([(1, 28), (31, 28)], GREEN, 2 if not c.small else 1.6)


def g_floor(c):
    # a plan: thick walls and a door swing
    w = 3.5 if not c.small else 4.5
    c.rect(3, 3, 29, 29, (235, 238, 242, 255), None)
    c.line([(3, 3), (29, 3), (29, 29), (17, 29)], GRAY, w, caps=False)
    c.line([(7, 29), (3, 29), (3, 3)], GRAY, w, caps=False)
    c.line([(17, 29), (17, 19)], BLUE, 1.2 if c.small else 1.5)
    c.arc(17, 29, 10, 180, 270, BLUE, 1 if c.small else 1.2)


def g_ceiling(c):
    # a reflected ceiling: a tile grid and a light
    c.rect(2, 2, 30, 30, PAPER, INK)
    for t in (11.33, 20.66):
        c.line([(t, 2), (t, 30)], GRAY, 1 if c.small else 1.2, caps=False)
        c.line([(2, t), (30, t)], GRAY, 1 if c.small else 1.2, caps=False)
    c.rect(12.5, 12.5, 19.5, 19.5, YELLOW, INK)
    c.line([(12.5, 12.5), (19.5, 19.5)], INK, 0.8 if c.small else 1, caps=False)
    c.line([(12.5, 19.5), (19.5, 12.5)], INK, 0.8 if c.small else 1, caps=False)


def g_roof(c):
    # a pitched roof with its shingles, on a wall
    c.rect(7, 18, 25, 29, GRAY_L, INK)
    roof = [(1, 19), (16, 4), (31, 19)]
    pattern(c, 'plywood', 1, 4, 31, 19, ORANGE, (150, 70, 20, 255), clip=roof)
    c.poly(roof, None, INK)


def g_finish(c):
    # a paint roller over a painted band
    c.rect(2, 20, 30, 29, TEAL_L, None)
    c.rect(4, 3, 24, 11, ORANGE, INK, r=2)
    c.line([(24, 7), (28, 7), (28, 14), (15, 14), (15, 19)], GRAY, 1.6 if c.small else 2, caps=False)
    c.rect(13, 18, 17, 30, GRAY_D, INK, r=1)


def g_structural(c):
    # a steel beam (I section)
    c.poly([(4, 3), (28, 3), (28, 8), (19, 8), (19, 24), (28, 24), (28, 29), (4, 29), (4, 24), (13, 24), (13, 8),
            (4, 8)], BLUE_L, INK)


def g_site(c):
    # a tree on the ground (earth hatch)
    pattern(c, 'earth', 2, 22, 30, 30, (200, 165, 120, 255), (90, 60, 30, 255))
    c.line([(2, 22), (30, 22)], GREEN, 1.6 if c.small else 2)
    c.rect(14.5, 14, 17.5, 23, (150, 100, 50, 255), INK)
    c.circle(16, 10, 8, GREEN, INK)


def g_wall(c):
    # a wall in plan: an L of brick hatch with its faces
    ps = [(3, 3), (29, 3), (29, 12), (12, 12), (12, 29), (3, 29)]
    pattern(c, 'ansi31', 3, 3, 29, 29, (240, 170, 140, 255), INK, clip=ps)
    c.poly(ps, None, INK)


def g_area(c):
    # an area: a shaded room outline, dashed, its corners marked
    ps = [(4, 6), (24, 3), (29, 20), (14, 29), (3, 22)]
    c.poly(ps, TEAL_L, None)
    for i in range(len(ps)):
        c.dashed(ps[i], ps[(i + 1) % len(ps)], TEAL, 1.2 if c.small else 1.6, 3, 2)
    for x, y in ps:
        c.rect(x - 1.8, y - 1.8, x + 1.8, y + 1.8, BLUE, None)
    if not c.small:
        c.text(16, 16, 'm²', 10, INK)


def g_annotation(c):
    # a note: a leader pointing to a text
    c.line([(4, 28), (12, 16), (16, 16)], BLUE, 1.4 if c.small else 1.8, caps=False)
    c.poly([(3, 30), (3.5, 24.5), (7.5, 27.5)], BLUE, None)
    c.rect(16, 3, 30, 22, PAPER, INK, r=1.5)
    text_lines(c, 19, 8, 27, 3, 5)


def g_generic(c):
    # any hatch: a plain grey swatch
    pattern(c, 'ansi37', 4, 4, 28, 28, GRAY_L, INK)
    c.rect(4, 4, 28, 28, None, INK)


def i_quickshape(c):
    # a wood stud (section) and a steel tube
    c.rect(3, 4, 14, 28, (245, 215, 165, 255), INK)
    c.line([(3, 4), (14, 28)], (150, 100, 50, 255), 1 if c.small else 1.2)
    c.line([(3, 28), (14, 4)], (150, 100, 50, 255), 1 if c.small else 1.2)
    c.rect(17, 10, 29, 22, BLUE_L, INK, r=2.5)
    c.rect(20, 13, 26, 19, PAPER, INK, r=1)


def i_shrinkwrap(c):
    c.circle(10, 11, 4.5, GRAY_L, INK)
    c.rect(15, 6, 25, 14, GRAY_L, INK)
    c.poly([(9, 20), (17, 20), (13, 27)], GRAY_L, INK)
    c.rect(19, 18, 25, 25, GRAY_L, INK)
    c.poly([(4.5, 10), (6, 5.5), (14, 4.5), (27.5, 4), (28, 27.5), (13, 29.5), (6, 21)], None, TEAL,
           1.6 if c.small else 2.2)


def i_materials(c):
    swatch(c, 'CONCRETE', 2, 2, 18, 18)
    swatch(c, 'STEEL', 8, 8, 24, 24)
    swatch(c, 'BRICK', 14, 14, 30, 30)


def i_hatchpresets(c):
    # one hatch (Rigid Insulation) shared by three materials
    kind, bg, fg = MATERIALS['RIGIDINSULATION']
    pattern(c, kind, 2, 3, 18, 29, bg, fg)
    c.rect(2, 3, 18, 29, None, INK)
    lw = 1 if c.small else 1.3
    for y0 in (3, 12.5, 22):
        c.line([(18, y0 + 3.5), (22, y0 + 3.5)], TEAL, lw)
        c.rect(22, y0, 30, y0 + 7, TEAL_L, INK)


# ---------------------------------------------------------------- layers

def i_layerkeys(c):
    layers(c, 1, 22, 22, 10, 5)
    key(c, 22, 19, 0.85)


def i_objectlayerkeys(c):
    # a dimension over a layer
    c.line([(3, 3), (3, 10)], INK, 1 if c.small else 1.2)
    c.line([(25, 3), (25, 10)], INK, 1 if c.small else 1.2)
    arrow(c, (14, 6.5), (3.5, 6.5), BLUE, 1 if c.small else 1.3, 3.5)
    arrow(c, (14, 6.5), (24.5, 6.5), BLUE, 1 if c.small else 1.3, 3.5)
    layers(c, 1, 25, 22, 10, 5, (GRAY_L, TEAL_L), 2)
    key(c, 23, 21, 0.75)


def i_layerphase(c):
    layers(c, 3, 24, 26, 12, 6, (GRAY_L, (245, 160, 150, 255), TEAL_L), 3, dashed=(1,))


def i_layertransfer(c):
    plate(c, 1, 9, 18, 9, GRAY_L)
    plate(c, 13, 24, 18, 9, TEAL_L)
    arrow(c, (19, 7), (25, 17.5), ORANGE)


def i_layertransfermanager(c):
    # the list of the transfers, with the transfer arrow
    table(c, 2, 2, 22, 26, 4, 2)
    arrow(c, (18, 16), (28, 28), ORANGE)


def i_layermake(c):
    layers(c, 1, 22, 22, 10, 5)
    plus(c, 24, 23, 7)


def i_layerimportfromcsv(c):
    sheet(c, 2, 2, 17, 20)
    if not c.small:
        c.text(9.5, 13.5, 'CSV', 5.5, GREEN)
    else:
        table(c, 4, 7, 14, 17, 3, 2, (190, 230, 200, 255))
    arrow(c, (12, 22), (17, 26), ORANGE)
    layers(c, 14, 26, 17, 8, 4, (GRAY_L, TEAL_L), 2)


def i_layerexporttocsv(c):
    layers(c, 1, 12, 17, 8, 4, (GRAY_L, TEAL_L), 2)
    arrow(c, (12, 15), (16, 20), ORANGE)
    sheet(c, 15, 12, 30, 30)
    if not c.small:
        c.text(22.5, 23.5, 'CSV', 5.5, GREEN)
    else:
        table(c, 17, 17, 27, 27, 3, 2, (190, 230, 200, 255))


def i_layerfilter(c):
    layers(c, 1, 24, 20, 9, 5)
    funnel(c, 23, 9, 14, 17)


def i_layergroup(c):
    folder(c, 2, 4, 30, 28)
    layers(c, 7, 22, 18, 8, 4, (GRAY_L, TEAL_L, PAPER), 3)


def i_layerimportfiltersfromdwg(c):
    sheet(c, 2, 2, 17, 21)
    if not c.small:
        c.text(9.5, 14, 'DWG', 4.6, BLUE)
    else:
        c.rect(4.5, 9, 14, 17, BLUE_L, INK)
    funnel(c, 22, 12, 16, 18)


def i_layerlist(c):
    cols = [RED, YELLOW, GREEN, BLUE]
    n = 3 if c.small else 4
    dy = 8 if c.small else 6.5
    for i in range(n):
        y = 5 + i * dy
        c.line([(3, y), (11, y)], cols[i], 2.2 if c.small else 2.6)
        c.line([(15, y), (29 - (i % 2) * 5, y)], GRAY, 1.2 if c.small else 1.6)


def i_layerpencolors(c):
    cols = [RED, YELLOW, GREEN, BLUE]
    for i, col in enumerate(cols):
        x = 3 + i * 7
        c.poly([(x, 30), (x, 12), (x + 2.75, 6), (x + 5.5, 12), (x + 5.5, 30)], col, INK)
        c.poly([(x + 1.6, 9.5), (x + 2.75, 6), (x + 3.9, 9.5)], INK, None)


def i_layercolorweight(c):
    for i, (col, wd) in enumerate([(BLUE, 1.0), (GREEN, 2.2), (RED, 3.6)]):
        y = 7 + i * 9
        c.line([(3, y), (29, y)], col, wd * (0.8 if c.small else 1.2))


def i_draworder(c):
    c.rect(3, 12, 19, 28, GRAY_L, INK)
    c.rect(10, 4, 26, 20, TEAL_L, INK)
    c.poly([(23, 30), (23, 24), (20, 24), (25.5, 18), (31, 24), (28, 24), (28, 30)], ORANGE, INK)


# ---------------------------------------------------------------- cleaning

def i_colorbylayer(c):
    cx, cy, r = 10, 10, 8.5
    for a0, col in ((0, RED), (120, YELLOW), (240, BLUE)):
        c.d.pieslice(c.p(cx - r, cy - r) + c.p(cx + r, cy + r), a0, a0 + 120, fill=col)
    c.circle(cx, cy, r, None, INK)
    arrow(c, (14, 17), (19, 22), ORANGE)
    layers(c, 8, 27, 22, 9, 4, (GRAY_L, TEAL_L), 2)


def i_datalinks(c):
    table(c, 2, 4, 24, 22, 3, 3, (190, 230, 200, 255))
    # a chain link
    for (x, y) in ((17, 24), (23, 20)):
        c.d.rounded_rectangle(c.p(x - 4.5, y - 2.6) + c.p(x + 4.5, y + 2.6), radius=2.6 * c.k,
                              outline=INK, width=c.w(2.8 if not c.small else 2))
    for (x, y) in ((17, 24), (23, 20)):
        c.d.rounded_rectangle(c.p(x - 4.5, y - 2.6) + c.p(x + 4.5, y + 2.6), radius=2.6 * c.k,
                              outline=TEAL, width=c.w(1.4 if not c.small else 1))


def i_setbyblock(c):
    # a cube (block), its faces white: ByBlock
    top = [(16, 3), (28, 9), (16, 15), (4, 9)]
    left = [(4, 9), (16, 15), (16, 29), (4, 23)]
    right = [(16, 15), (28, 9), (28, 23), (16, 29)]
    c.poly(left, GRAY_L, INK)
    c.poly(right, PAPER, INK)
    c.poly(top, TEAL_L, INK)


# ---------------------------------------------------------------- navigate / output / setup

def i_switchdrawingscale(c):
    # a scale bar under a double arrow
    n = 4
    for i in range(n):
        x = 3 + i * 6.5
        c.rect(x, 20, x + 6.5, 26, BLUE if i % 2 == 0 else PAPER, None)
    c.rect(3, 20, 29, 26, None, INK)
    arrow(c, (16, 11), (3.5, 11), TEAL)
    arrow(c, (16, 11), (28.5, 11), TEAL)


def i_prepdrawing(c):
    c.rect(8, 3, 24, 12, PAPER, INK)
    c.rect(3, 11, 29, 23, GRAY_L, INK, r=2)
    c.rect(8, 19, 24, 29, PAPER, INK)
    text_lines(c, 11, 22.5, 21, 2, 3.5)
    check(c, 24, 24, 7)


def cloud(c, x0, y0, x1, y1, n=3, m=2, color=ORANGE, fill=ORANGE_L):
    """A revision cloud: n bumps along the top and bottom of the box, m along its sides."""
    c.rect(x0, y0, x1, y1, fill, None)
    rx, ry = (x1 - x0) / (2.0 * n), (y1 - y0) / (2.0 * m)
    px = 1.0 if c.small else 1.6
    for i in range(n):
        cx = x0 + rx * (2 * i + 1)
        c.d.pieslice(((cx - rx) * c.k, (y0 - ry * 0.8) * c.k, (cx + rx) * c.k, (y0 + ry * 0.8) * c.k), 180, 360, fill=fill)
        c.d.pieslice(((cx - rx) * c.k, (y1 - ry * 0.8) * c.k, (cx + rx) * c.k, (y1 + ry * 0.8) * c.k), 0, 180, fill=fill)
        c.d.arc(((cx - rx) * c.k, (y0 - ry * 0.8) * c.k, (cx + rx) * c.k, (y0 + ry * 0.8) * c.k), 180, 360, fill=color, width=c.w(px))
        c.d.arc(((cx - rx) * c.k, (y1 - ry * 0.8) * c.k, (cx + rx) * c.k, (y1 + ry * 0.8) * c.k), 0, 180, fill=color, width=c.w(px))
    for j in range(m):
        cy = y0 + ry * (2 * j + 1)
        c.d.pieslice(((x0 - rx * 0.8) * c.k, (cy - ry) * c.k, (x0 + rx * 0.8) * c.k, (cy + ry) * c.k), 90, 270, fill=fill)
        c.d.pieslice(((x1 - rx * 0.8) * c.k, (cy - ry) * c.k, (x1 + rx * 0.8) * c.k, (cy + ry) * c.k), 270, 450, fill=fill)
        c.d.arc(((x0 - rx * 0.8) * c.k, (cy - ry) * c.k, (x0 + rx * 0.8) * c.k, (cy + ry) * c.k), 90, 270, fill=color, width=c.w(px))
        c.d.arc(((x1 - rx * 0.8) * c.k, (cy - ry) * c.k, (x1 + rx * 0.8) * c.k, (cy + ry) * c.k), 270, 450, fill=color, width=c.w(px))


def rev_tag(c, cx, cy, s=5.5):
    """The revision tag: a triangle around its number."""
    h = s * math.sqrt(3)
    c.poly([(cx - s, cy + h / 3), (cx + s, cy + h / 3), (cx, cy - 2 * h / 3)], TEAL_L, INK)


def i_revisions(c):
    # a sheet with its title block of revision rows, a revision cloud and its tag
    c.rect(2, 4, 30, 28, PAPER, INK)
    c.rect(21, 4, 30, 28, GRAY_L, INK)
    for y in (18, 22):
        c.line([(21, y), (30, y)], INK, 1 if c.small else 1.2, caps=False)
    cloud(c, 6, 9, 16, 19, n=3, m=2)
    rev_tag(c, 16, 23, 5)


def i_revisioncloud(c):
    # a revision cloud and its tag
    cloud(c, 5, 6, 25, 20, n=4, m=2)
    rev_tag(c, 23, 24, 6)


def i_cmdoptimizer(c):
    # a floppy disk and a bolt
    c.rect(3, 3, 25, 25, BLUE, INK, r=2)
    c.rect(8, 3, 20, 10, PAPER, INK)
    c.rect(7, 15, 21, 25, PAPER, INK)
    c.poly([(23, 12), (17, 22), (22, 22), (19, 31), (29, 19), (24, 19), (27, 12)], YELLOW, INK)


def i_setfileprefs(c):
    folder(c, 2, 4, 28, 25)
    gear(c, 22, 22, 8.5, GRAY_L, 7)


def i_setunits(c):
    ps = [(2, 22), (22, 2), (30, 10), (10, 30)]
    c.poly(ps, YELLOW, INK)
    for i in range(1, 8 if not c.small else 5):
        t = i / (8.0 if not c.small else 5.0)
        x, y = 2 + 20 * t, 22 - 20 * t
        ln = 4.5 if i % 2 == 0 else 2.8
        c.line([(x, y), (x + ln * 0.7071, y + ln * 0.7071)], INK, 1 if c.small else 1.2, caps=False)


def i_standardgrid(c):
    c.rect(3, 3, 29, 29, PAPER, INK)
    for t in (11.66, 20.33):
        c.line([(t, 3), (t, 29)], GRAY, 1 if c.small else 1.2, caps=False)
        c.line([(3, t), (29, t)], GRAY, 1 if c.small else 1.2, caps=False)
    for x in (3, 11.66, 20.33, 29):
        for y in (3, 11.66, 20.33, 29):
            c.circle(x, y, 1.8 if not c.small else 2.4, TEAL, None)


def i_sysvars(c):
    for i, (pos, col) in enumerate(((20, ORANGE), (9, TEAL), (16, GRAY_L))):
        y = 7 + i * 9
        c.line([(3, y), (29, y)], GRAY, 1.4 if c.small else 2)
        c.rect(pos - 3, y - 3.5, pos + 3, y + 3.5, col, INK, r=1.2)


# ---------------------------------------------------------------- utilities

def i_addprefixsuffix(c):
    c.text(13, 17, 'Ab', 17 if not c.small else 19, BLUE)
    plus(c, 25, 9, 6, ORANGE)


def i_quickaddprefixsuffix(c):
    c.line([(3, 19), (3, 29)], INK, 1 if c.small else 1.2)
    c.line([(29, 19), (29, 29)], INK, 1 if c.small else 1.2)
    arrow(c, (16, 25), (3.5, 25), BLUE, 1 if c.small else 1.3, 3.5)
    arrow(c, (16, 25), (28.5, 25), BLUE, 1 if c.small else 1.3, 3.5)
    c.text(16, 11, '\u00b1', 18 if not c.small else 22, ORANGE)


def i_batchinsert(c):
    for i in range(3):
        sheet(c, 2 + i * 6, 2 + i * 3, 13 + i * 6, 15 + i * 3, PAPER, 3.5)
    c.rect(3, 22, 29, 30, TEAL_L, INK)


def sparkle(c, cx, cy, r, color=ORANGE):
    ps = []
    for i in range(8):
        a = math.radians(i * 45 - 90)
        rr = r if i % 2 == 0 else r * 0.32
        ps.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    c.poly(ps, color, INK, 0.8 if c.small else 1)


def i_assistant(c):
    # a speech bubble, its lines of text, and the sparkle of Text Fix
    c.poly([(2, 4), (24, 4), (24, 20), (12, 20), (6, 27), (7, 20), (2, 20)], PAPER, INK)
    text_lines(c, 5.5, 9, 20, 2 if c.small else 3, 5 if c.small else 4)
    sparkle(c, 24, 21, 8)


def i_claudetextfix(c):
    sheet(c, 2, 2, 22, 28)
    text_lines(c, 5.5, 11, 18, 3 if c.small else 4, 4.5 if not c.small else 6)
    sparkle(c, 23, 21, 9)


def i_countbylayers(c):
    c.text(12, 14, '\u03a3', 24 if not c.small else 28, TEAL)
    layers(c, 13, 27, 17, 8, 4, (GRAY_L, ORANGE_L), 2)


def i_dictionary(c):
    c.rect(5, 2, 27, 30, ORANGE, INK, r=1.5)
    c.rect(5, 25, 27, 30, PAPER, INK)
    c.line([(9, 2), (9, 25)], INK, 1 if c.small else 1.2, caps=False)
    c.text(18, 13.5, 'A', 13 if not c.small else 17, PAPER)


def i_groupcluster(c):
    for (cx, cy, col) in ((10, 11, TEAL), (22, 21, ORANGE)):
        c.circle(cx, cy, 8, None, None)
        for i in range(24):
            a0 = i * 15
            if i % 2 == 0:
                c.arc(cx, cy, 8, a0, a0 + 9, col, 1.2 if c.small else 1.5)
        for (dx, dy) in ((-3, -2), (2.5, -3), (0, 3)):
            c.circle(cx + dx, cy + dy, 1.9 if not c.small else 2.3, col, None)


def i_layercolortoobject(c):
    layers(c, 1, 12, 20, 9, 4, (GRAY_L, TEAL_L), 2)
    arrow(c, (14, 15), (18, 20), ORANGE)
    c.circle(22, 23, 7.5, RED, INK)


def i_linetopolyline(c):
    ps = [(3, 26), (10, 8), (19, 22), (28, 5)]
    c.line(ps, TEAL, 1.6 if c.small else 2.2)
    for x, y in ps:
        c.rect(x - 2.2, y - 2.2, x + 2.2, y + 2.2, BLUE, INK, 0.8 if c.small else 1)


def i_multileaderlist(c):
    c.circle(22, 9, 7, PAPER, INK)
    c.text(22, 9.4, '3', 9 if not c.small else 11, INK)
    c.line([(16, 13), (5, 25)], BLUE, 1.2 if c.small else 1.6)
    c.poly([(3, 28), (4.2, 22.5), (7.6, 25.6)], BLUE, None)
    text_lines(c, 15, 22, 29, 3 if not c.small else 2, 3.5 if not c.small else 5)


def i_openfolder(c):
    folder(c, 2, 4, 29, 27, ORANGE_L, open_=True)


def i_quickselectsimilar(c):
    for p0, p1 in [((2, 2), (26, 2)), ((26, 2), (26, 22)), ((26, 22), (2, 22)), ((2, 22), (2, 2))]:
        c.dashed(p0, p1, BLUE, 1 if c.small else 1.3, 3, 2)
    c.circle(8, 9, 3.5, TEAL_L, INK)
    c.circle(18, 14, 3.5, TEAL_L, INK)
    c.rect(6, 15, 11, 19, GRAY_L, INK) if not c.small else None
    c.poly([(16, 16), (16, 31), (19.5, 27.5), (22.5, 31.5), (25, 30), (22, 26.2), (27, 26)], PAPER, INK)


def i_rebuildpat(c):
    swatch(c, 'BRICK', 2, 2, 22, 22)
    # a wrench
    c.line([(14, 28), (24, 18)], INK, 5 if not c.small else 4)
    c.line([(14, 28), (24, 18)], GRAY_L, 3 if not c.small else 2.2)
    c.circle(25.5, 16.5, 5, GRAY_L, INK)
    c.poly([(25, 10), (29, 14), (27, 16), (23, 12)], NONE, None)
    c.circle(27, 15, 2.4, PAPER, None)


def i_resetlinetypescale(c):
    c.dashed((3, 8), (29, 8), BLUE, 1.6 if c.small else 2, 6, 2)
    c.dashed((3, 15), (29, 15), BLUE, 1.6 if c.small else 2, 2, 2)
    c.text(16, 24.5, '1.0', 10 if not c.small else 12, TEAL)


def i_ungroupnext(c):
    c.circle(9, 11, 5, TEAL_L, INK)
    c.rect(18, 17, 28, 27, ORANGE_L, INK)
    for p0, p1 in [((2, 3), (15, 3)), ((2, 3), (2, 18)), ((30, 29), (14, 29)), ((30, 29), (30, 13))]:
        c.dashed(p0, p1, GRAY_D, 1 if c.small else 1.3, 2.5, 1.5)


def i_viewporttopaperspace(c):
    sheet(c, 2, 2, 30, 30)
    c.rect(6, 8, 23, 24, PAPER, TEAL, 1.6 if c.small else 2.2)
    c.circle(12, 15, 3.5, GRAY_L, INK)
    c.rect(15, 15, 20, 21, GRAY_L, INK)


# ---------------------------------------------------------------- children

PHASES = {
    'EXISTING': (GRAY_L, False),
    'DEMOLITION': ((245, 160, 150, 255), True),
    'NEWWORK': (TEAL_L, False),
    'FUTUREWORK': ((205, 180, 235, 255), True),
    'TEMPORARYWORK': (ORANGE_L, True),
    'NONE': (PAPER, False),
}


def phase_icon(ph):
    def f(c):
        fill, dash = PHASES[ph]
        plate(c, 2, 22, 28, 13, GRAY_L if ph != 'NONE' else PAPER)
        plate(c, 2, 14, 28, 13, fill, dashed=dash)
        if ph == 'DEMOLITION':
            c.line([(11, 10), (21, 18)], RED, 1.6 if c.small else 2)
            c.line([(11, 18), (21, 10)], RED, 1.6 if c.small else 2)
    return f


def i_phasenext(c):
    plate(c, 2, 22, 28, 13, GRAY_L)
    plate(c, 2, 14, 28, 13, TEAL_L)
    arrow(c, (8, 14), (24, 14), ORANGE)


def i_phaseauto(c):
    plate(c, 2, 26, 28, 10, GRAY_L)
    c.rect(4, 3, 28, 17, TEAL, INK, r=7)
    c.circle(21, 10, 5, PAPER, INK)
    c.text(10.5, 10.5, 'A', 9 if not c.small else 11, PAPER)


def eye_icon(mode):
    def f(c):
        layers(c, 4, 29, 24, 8, 4, (GRAY_L, TEAL_L), 2)
        eye(c, 16, 11, 28 if not c.small else 30, mode)
    return f


def i_changecolor(c):
    cx, cy, r = 16, 16, 13.5
    cols = [RED, ORANGE, YELLOW, GREEN, TEAL, BLUE, PURPLE]
    for i, col in enumerate(cols):
        a0 = i * 360 / len(cols)
        c.d.pieslice(c.p(cx - r, cy - r) + c.p(cx + r, cy + r), a0, a0 + 360 / len(cols), fill=col)
    c.circle(cx, cy, r, None, INK)
    c.circle(cx, cy, 4.5, PAPER, INK)


def i_purgedatalinks(c):
    i_datalinks(c)
    c.circle(25, 8, 6, RED, PAPER, 1 if c.small else 1.2)
    c.line([(22.3, 5.3), (27.7, 10.7)], PAPER, 1.4 if c.small else 2)
    c.line([(22.3, 10.7), (27.7, 5.3)], PAPER, 1.4 if c.small else 2)


# ---------------------------------------------------------------- troubleshooting

def i_diagnostics(c):
    """A report looked at through a magnifier, a pulse line in its lens."""
    sheet(c, 3, 2, 21, 28)
    text_lines(c, 6.5, 8, 17.5, 2 if c.small else 3, 4 if c.small else 3.5)
    c.line([(25.5, 25.5), (29.5, 29.5)], ORANGE, 2.6 if c.small else 3.6)
    c.circle(21, 21, 7.5, TEAL_L, INK)
    c.line([(15.5, 21.5), (18.5, 21.5), (20, 17.5), (22, 25), (23.5, 21.5), (26.5, 21.5)], INK,
           1 if c.small else 1.3)


def i_simulation(c):
    """A section of a wall in a gradient from cold (blue) to warm (red), its cells drawn: the
    temperatures of a simulation over a 2D detail."""
    cols = (BLUE, BLUE_L, ORANGE_L, RED)
    x0, x1, y0, y1 = 4, 28, 4, 28
    w = (x1 - x0) / len(cols)
    for k, col in enumerate(cols):
        c.rect(x0 + k * w, y0, x0 + (k + 1) * w, y1, col, None)
    if not c.small:
        for y in (12, 20):
            c.line([(x0, y), (x1, y)], PAPER, 0.8, caps=False)
    c.rect(x0, y0, x1, y1, None, INK)


ICONS = {
    # core
    'DYL-SETTINGS': i_settings,
    'DYL-SUITE': i_suite,
    'DYL-USERFILES': i_userfiles,
    'DYL-INFO': i_info,
    'DYL-DOCS': i_docs,
    'DYL-RELOAD': i_reload,
    # draw
    'DYL-QUICKDRAW': i_quickdraw,
    'PST-QUICKDRAWGALLERY': i_quickdrawgallery,
    'DYL-QUICKSHAPE': i_quickshape,
    'DYL-SHRINKWRAP': i_shrinkwrap,
    'DYL-MATERIALS': i_materials,
    'DYL-HATCHPRESETS': i_hatchpresets,
    # layers
    'DYL-LAYERKEYS': i_layerkeys,
    'DYL-OBJECTLAYERKEYS': i_objectlayerkeys,
    'DYL-LAYERPHASE': i_layerphase,
    'PST-TRANSFERFIELD': i_layertransfer,
    'DYL-LAYERTRANSFER': i_layertransfermanager,
    'DYL-LAYERMAKE': i_layermake,
    'DYL-LAYERIMPORTFROMCSV': i_layerimportfromcsv,
    'DYL-LAYEREXPORTTOCSV': i_layerexporttocsv,
    'DYL-LAYERFILTER': i_layerfilter,
    'DYL-LAYERGROUP': i_layergroup,
    'DYL-LAYERIMPORTFILTERSFROMDWG': i_layerimportfiltersfromdwg,
    'DYL-LAYERLIST': i_layerlist,
    'DYL-LAYERPENCOLORS': i_layerpencolors,
    'DYL-LAYERCOLORWEIGHT': i_layercolorweight,
    'DYL-DRAWORDER': i_draworder,
    # cleaning
    'DYL-COLORBYLAYER': i_colorbylayer,
    'DYL-DATALINKS': i_datalinks,
    'DYL-SETBYBLOCK': i_setbyblock,
    # navigate, output, setup
    'DYL-SWITCHDRAWINGSCALE': i_switchdrawingscale,
    'DYL-PREPDRAWING': i_prepdrawing,
    'DYL-CMDOPTIMIZER': i_cmdoptimizer,
    'DYL-REVISIONS': i_revisions,
    'PST-REVISIONCLOUD': i_revisioncloud,
    'DYL-SETFILEPREFS': i_setfileprefs,
    'DYL-SETUNITS': i_setunits,
    'DYL-STANDARDGRID': i_standardgrid,
    'DYL-SYSVARS': i_sysvars,
    # utilities
    'DYL-ADDPREFIXSUFFIX': i_addprefixsuffix,
    'DYL-QUICKADDPREFIXSUFFIX': i_quickaddprefixsuffix,
    'DYL-BATCHINSERT': i_batchinsert,
    'DYL-ASSISTANT': i_assistant,
    'DYL-CLAUDETEXTFIX': i_claudetextfix,
    'DYL-COUNTBYLAYERS': i_countbylayers,
    'DYL-DICTIONARY': i_dictionary,
    'DYL-GROUPCLUSTER': i_groupcluster,
    'DYL-LAYERCOLORTOOBJECT': i_layercolortoobject,
    'DYL-LINETOPOLYLINE': i_linetopolyline,
    'DYL-MULTILEADERLIST': i_multileaderlist,
    'DYL-OPENFOLDER': i_openfolder,
    'DYL-QUICKSELECTSIMILAR': i_quickselectsimilar,
    'DYL-REBUILDPAT': i_rebuildpat,
    'DYL-RESETLINETYPESCALE': i_resetlinetypescale,
    'DYL-UNGROUPNEXT': i_ungroupnext,
    'DYL-VIEWPORTTOPAPERSPACE': i_viewporttopaperspace,
    # analysis
    'DYL-SIMULATION': i_simulation,
    # troubleshooting
    'DYL-DIAGNOSTICS': i_diagnostics,
    # children with an icon of their own
    'PST-CHANGECOLOR': i_changecolor,
    'PST-DATALINKPURGE': i_purgedatalinks,
    'PST-PHASENEXT': i_phasenext,
    'PST-PHASEAUTOTOGGLE': i_phaseauto,
    'PST-OPENPATTERNSFOLDER': i_openfolder,
}
for _g, _f in (('All', g_all), ('Phase', g_phase), ('Section', g_section), ('Detail', g_detail),
               ('Elevation', g_elevation), ('Floor', g_floor), ('Ceiling', g_ceiling), ('Roof', g_roof),
               ('Finish', g_finish), ('Structural', g_structural), ('Site', g_site), ('Wall', g_wall),
               ('Area', g_area), ('Annotation', g_annotation), ('Generic', g_generic)):
    ICONS['PST-QUICKDRAWGALLERY=' + _g] = _f
for _p in PHASES:
    ICONS['PST-PHASE' + _p] = phase_icon(_p)
for _cmd, _mode in (('PST-SHOWALLLAYERS', 'open'), ('PST-HIDEALLLAYERS', 'closed'),
                    ('PST-SCREENEXISTINGLAYERS', 'half')):
    ICONS[_cmd] = eye_icon(_mode)


def eye_for(cmd):
    """The icon of a Show / Hide layer filter preset."""
    if cmd.startswith('PST-SHOW'):
        return eye_icon('open')
    if cmd.startswith('PST-HIDE'):
        return eye_icon('closed')
    if cmd.startswith('PST-SCREEN'):
        return eye_icon('half')
    return None


def render(cmd, size):
    """The icon of cmd at size pixels (an RGBA image), or None when it has none."""
    fn = ICONS.get(cmd) or eye_for(cmd)
    if not fn:
        return None
    c = Ic(size)
    fn(c)
    return c.result()
