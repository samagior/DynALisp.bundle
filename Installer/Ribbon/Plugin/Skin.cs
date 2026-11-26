// Skin.cs - DynALisp.Ribbon: the ribbon of AutoCAD in the dark of the DynALisp windows (experiment)
// Copyright (C) 2026  Samuel Martineau
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// EXPERIMENT, not supported by Autodesk. AutoCAD lets a user pick only its Dark or Light theme
// (COLORTHEME). Its ribbon (AdWindows.dll) takes its colours from a theme object,
// ComponentManager.CurrentTheme (Autodesk.Internal.Windows.Theme): the brushes of the ribbon,
// its tabs and panels (Ribbon, Ribbon.MainTab), the application menu and the frame, which the
// controls of the ribbon are bound to (CurrentTheme.Ribbon.TabBarBackground...). While the
// skin is on and AutoCAD is in its dark theme, every colour of that theme goes through a
// filter (Map): the greys and blue-greys of the surfaces take the hue of the DynALisp windows
// (Installer\Windows\Engine\Session.cs) and get darker, the light ones (the texts) take their
// hue, the saturated ones (the blue of what is picked) and the icons stay as they are.
//
// The theme is changed in place when AutoCAD left it unfrozen (its controls follow at once),
// or as a copy made current when it is frozen. Turned off, the colours it had are given back.
// Everything is done when AutoCAD is idle with no command running (Host.OnIdle), at most once
// a second; anything not found (another version of AdWindows) leaves the ribbon as it is and
// says why in (Dyl:RibbonSkin).
//
// On while Display is on in Dyl-Settings (DynalispDisplayOn) and its Ribbon is DynALisp
// (DynalispRibbonColors), read here from the registry when the plugin loads, and again when
// the Lisp side calls (Dyl:RibbonSkin) after the settings are saved.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Windows;
using System.Windows.Media;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Ribbon
{
    // The Lisp function of the skin (see LangCommands: a static class cannot hold it).
    public class SkinCommands
    {
        // (Dyl:RibbonSkin): reads the settings again, applies or removes the skin the next time
        // AutoCAD is idle, and returns what it does: "DynALisp", "off", "waiting for the dark
        // theme", "not found: ..." (Dyl-Settings, Dyl-Diagnostics).
        [LispFunction("Dyl:RibbonSkin")]
        public static object RibbonSkin(ResultBuffer args)
        {
            try { Skin.Read(); return Skin.Status(); }
            catch (System.Exception ex) { return "error: " + ex.Message; }
        }
    }

    public static class Skin
    {
        // The hue and the most saturation of the greys of the DynALisp windows (#252A32, #313844:
        // 217 degrees, 15 %), and how much darker the surfaces get: AutoCAD's dark panels (a
        // lightness of about 28 %) come near the cards of the windows (#313844, 23 %).
        const double Hue = 217, MaxSat = 0.16, Darker = 0.78;
        // A colour more saturated than this is a colour, not a grey: it stays.
        const double Grey = 0.35;
        // A colour lighter than this is a text or a light line: it only takes the hue.
        const double Light = 0.6;

        public static bool Wanted { get; private set; }
        static bool _due = true;
        static int _next = Environment.TickCount;
        static string _fail;

        // The theme changed in place: (object, property, value it had), to give them back.
        static readonly List<(object Node, PropertyInfo Prop, object Was)> Changed = new();
        static object _inPlace;        // the theme changed in place
        static object _copy, _orig;    // the copy made current, and the theme it was made from
        static int _count;             // the colours changed

        public static void Start()
        {
            Read();
            AcApp.SystemVariableChanged += (s, e) =>
            {
                if (string.Equals(e.Name, "COLORTHEME", StringComparison.OrdinalIgnoreCase)) _due = true;
            };
        }

        // The settings, from the registry (setenv / getenv: FixedProfile\General):
        public static void Read()
        {
            Wanted = Env("DynalispDisplayOn") == "1" && Env("DynalispRibbonColors") == "DynALisp";
            _due = true;
            _next = Environment.TickCount;
        }

        static string Env(string name)
        {
            try
            {
                string root = HostApplicationServices.Current.UserRegistryProductRootKey;
                using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(root + @"\FixedProfile\General");
                return key?.GetValue(name) as string;
            }
            catch { return null; }
        }

        static bool Dark()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("COLORTHEME")) == 0; }
            catch { return true; }
        }

        public static string Status()
        {
            if (!Wanted) return "off";
            if (_fail != null) return "not found: " + _fail;
            if (!Dark()) return "waiting for the dark theme";
            if (_inPlace != null) return "DynALisp (" + _count + " colours)";
            if (_copy != null) return "DynALisp (" + _count + " colours, copy of the theme)";
            return "DynALisp (on the next idle)";
        }

        // Run by Host.OnIdle: the skin put on, kept on (AutoCAD makes another theme current when
        // COLORTHEME changes or the ribbon is made again) or taken off, once a second at most.
        public static void OnIdle()
        {
            if (!_due && !Wanted && _inPlace == null && _copy == null) return;
            if (Environment.TickCount - _next < 0) return;
            _next = Environment.TickCount + 1000;
            _due = false;
            try { Apply(); }
            catch (System.Exception ex) { _fail = ex.Message; Host.Log("ribbon colours: " + ex.Message); }
        }

        static void Apply()
        {
            object cur = Current();
            if (cur == null) { _fail = "ComponentManager.CurrentTheme"; return; }
            _fail = null;
            bool on = Wanted && Dark();
            if (on)
            {
                if (ReferenceEquals(cur, _inPlace) || ReferenceEquals(cur, _copy)) return;
                // Another theme made current by AutoCAD: the former one given back first.
                Undo();
                if (Unfrozen(cur))
                {
                    _count = Filter(cur, true);
                    _inPlace = cur;
                }
                else
                {
                    var copy = ((Freezable)cur).Clone();
                    _count = Filter(copy, false);
                    _orig = cur;
                    _copy = copy;
                    SetCurrent(copy);
                }
            }
            else Undo();
        }

        // The colours given back: the theme changed in place, or the theme the copy was made from
        // made current again (when AutoCAD has not made another one current since).
        static void Undo()
        {
            foreach (var (node, prop, was) in Enumerable.Reverse(Changed))
                try { prop.SetValue(node, was); } catch { }
            Changed.Clear();
            _inPlace = null;
            if (_copy != null)
            {
                if (ReferenceEquals(Current(), _copy)) SetCurrent(_orig);
                _copy = null;
                _orig = null;
            }
            _count = 0;
        }

        static object Current() => ComponentManager.CurrentTheme;

        static void SetCurrent(object theme) => ComponentManager.CurrentTheme = (Autodesk.Internal.Windows.Theme)theme;

        // ---- the walk of the theme ----

        // The parts of a theme are Freezable objects of Autodesk (RibbonTheme, TabTheme,
        // ApplicationMenuTheme...); their colours are its Brush and Color properties.
        static bool IsPart(Type t) =>
            typeof(Freezable).IsAssignableFrom(t) && !typeof(Brush).IsAssignableFrom(t)
            && (t.Namespace ?? "").StartsWith("Autodesk", StringComparison.Ordinal);

        static IEnumerable<PropertyInfo> Props(object node) =>
            node.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.CanRead && p.GetIndexParameters().Length == 0);

        static bool Unfrozen(object theme)
        {
            var seen = new HashSet<object>(ReferenceEqualityComparer.Instance);
            return Unfrozen(theme, seen);
        }

        static bool Unfrozen(object node, HashSet<object> seen)
        {
            if (node == null || !seen.Add(node)) return true;
            if (node is Freezable f && f.IsFrozen) return false;
            foreach (var p in Props(node))
                if (IsPart(p.PropertyType))
                {
                    object v;
                    try { v = p.GetValue(node); } catch { continue; }
                    if (!Unfrozen(v, seen)) return false;
                }
            return true;
        }

        // Every colour of the theme through Map; keep: remember what it was (in place). Returns
        // how many were changed.
        static int Filter(object theme, bool keep)
        {
            var seen = new HashSet<object>(ReferenceEqualityComparer.Instance);
            return Filter(theme, keep, seen);
        }

        static int Filter(object node, bool keep, HashSet<object> seen)
        {
            if (node == null || !seen.Add(node)) return 0;
            int n = 0;
            foreach (var p in Props(node))
            {
                object v;
                try { v = p.GetValue(node); } catch { continue; }
                if (v == null) continue;
                if (IsPart(p.PropertyType) || (v is Freezable && IsPart(v.GetType()))) { n += Filter(v, keep, seen); continue; }
                if (!p.CanWrite || p.SetMethod == null || !p.SetMethod.IsPublic) continue;
                object nv = v is Brush b ? MapBrush(b) : v is Color c ? Map(c) : null;
                if (nv == null || Equals(nv, v)) continue;
                try
                {
                    p.SetValue(node, nv);
                    if (keep) Changed.Add((node, p, v));
                    n++;
                }
                catch { }
            }
            return n;
        }

        static Brush MapBrush(Brush b)
        {
            switch (b)
            {
                case SolidColorBrush s:
                    var c = Map(s.Color);
                    if (c == s.Color) return null;
                    var ns = new SolidColorBrush(c) { Opacity = s.Opacity };
                    ns.Freeze();
                    return ns;
                case GradientBrush g:
                    var ng = g.Clone();
                    bool any = false;
                    foreach (var stop in ng.GradientStops)
                    {
                        var m = Map(stop.Color);
                        if (m != stop.Color) { stop.Color = m; any = true; }
                    }
                    if (!any) return null;
                    ng.Freeze();
                    return ng;
                default:
                    return null;    // images and drawings: left as they are
            }
        }

        // ---- the filter ----

        // A colour of AutoCAD's dark theme in the dark of the DynALisp windows: a grey (not
        // saturated) takes their hue; a dark one gets darker; a saturated one stays.
        public static Color Map(Color c)
        {
            if (c.A == 0) return c;
            ToHsl(c, out double h, out double s, out double l);
            if (s > Grey && l > 0.08 && l < 0.92) return c;
            if (l < Light) l *= Darker;
            return FromHsl(c.A, Hue, Math.Min(Math.Max(s, 0.10), MaxSat), l);
        }

        static void ToHsl(Color c, out double h, out double s, out double l)
        {
            double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
            double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b));
            l = (max + min) / 2;
            double d = max - min;
            if (d < 1e-9) { h = 0; s = 0; return; }
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max == r) h = (g - b) / d + (g < b ? 6 : 0);
            else if (max == g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h *= 60;
        }

        static Color FromHsl(byte a, double h, double s, double l)
        {
            double q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
            double k = h / 360;
            static double Ch(double p, double q, double t)
            {
                if (t < 0) t += 1;
                if (t > 1) t -= 1;
                if (t < 1.0 / 6) return p + (q - p) * 6 * t;
                if (t < 0.5) return q;
                if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6;
                return p;
            }
            static byte B(double v) => (byte)Math.Round(Math.Clamp(v, 0, 1) * 255);
            return Color.FromArgb(a, B(Ch(p, q, k + 1.0 / 3)), B(Ch(p, q, k)), B(Ch(p, q, k - 1.0 / 3)));
        }
    }
}
