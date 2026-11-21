// Win.cs - DynALisp.Windows: what a window file (.xaml) can say to the engine
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
// A window of DynALisp is a .xaml file with a Window as its root, read when it is shown
// (Session.Show). It has no code: what it does is said with these attached properties
// (xmlns:dyl="clr-namespace:DynALisp.Windows"), the name (x:Name) of a control being its
// key, as the key of a DCL tile:
//
//   dyl:Win.Docs="Core\Dyl-Settings.htm"   on the Window: its docs page, as given to
//                                           Dyl:DocsTile (its button is named "docs")
//   dyl:Win.EnabledBy="rea,!lkk"            enabled while every key is on ("1"), or off with !
//   dyl:Win.VisibleBy="prp"                 shown while every key is on (or off with !)
//   dyl:Win.Excludes="lkk"                  on a checkbox: turning it on turns those off
//   dyl:Win.Close="4"                       on a button: closes the window, the Lisp gets 4
//   dyl:Win.Open="Dyl-Settings-Display.xaml" on a button: opens that window over this one,
//                                           beside this file; its OK keeps its values,
//                                           its Cancel puts them back
//   dyl:Win.SetAll="1"                      on a button: every checkbox of the window on
//                                           ("1") or off ("0")
//   dyl:Win.Check="positive"                on a text box: checked before the window closes
//                                           (number, positive, integer)
//   dyl:Win.CheckMessage="..."              what is shown when it fails, in the text named
//                                           "error"
//
// A button with IsDefault closes the window with 1 (OK, Save), one with IsCancel with 0.

using System.Windows;

namespace DynALisp.Windows
{
    public static class Win
    {
        static DependencyProperty Prop(string name) =>
            DependencyProperty.RegisterAttached(name, typeof(string), typeof(Win), new PropertyMetadata(null));

        public static readonly DependencyProperty DocsProperty = Prop("Docs");
        public static string GetDocs(DependencyObject o) => (string)o.GetValue(DocsProperty);
        public static void SetDocs(DependencyObject o, string v) => o.SetValue(DocsProperty, v);

        public static readonly DependencyProperty EnabledByProperty = Prop("EnabledBy");
        public static string GetEnabledBy(DependencyObject o) => (string)o.GetValue(EnabledByProperty);
        public static void SetEnabledBy(DependencyObject o, string v) => o.SetValue(EnabledByProperty, v);

        public static readonly DependencyProperty VisibleByProperty = Prop("VisibleBy");
        public static string GetVisibleBy(DependencyObject o) => (string)o.GetValue(VisibleByProperty);
        public static void SetVisibleBy(DependencyObject o, string v) => o.SetValue(VisibleByProperty, v);

        public static readonly DependencyProperty ExcludesProperty = Prop("Excludes");
        public static string GetExcludes(DependencyObject o) => (string)o.GetValue(ExcludesProperty);
        public static void SetExcludes(DependencyObject o, string v) => o.SetValue(ExcludesProperty, v);

        public static readonly DependencyProperty CloseProperty = Prop("Close");
        public static string GetClose(DependencyObject o) => (string)o.GetValue(CloseProperty);
        public static void SetClose(DependencyObject o, string v) => o.SetValue(CloseProperty, v);

        public static readonly DependencyProperty OpenProperty = Prop("Open");
        public static string GetOpen(DependencyObject o) => (string)o.GetValue(OpenProperty);
        public static void SetOpen(DependencyObject o, string v) => o.SetValue(OpenProperty, v);

        public static readonly DependencyProperty SetAllProperty = Prop("SetAll");
        public static string GetSetAll(DependencyObject o) => (string)o.GetValue(SetAllProperty);
        public static void SetSetAll(DependencyObject o, string v) => o.SetValue(SetAllProperty, v);

        public static readonly DependencyProperty CheckProperty = Prop("Check");
        public static string GetCheck(DependencyObject o) => (string)o.GetValue(CheckProperty);
        public static void SetCheck(DependencyObject o, string v) => o.SetValue(CheckProperty, v);

        public static readonly DependencyProperty CheckMessageProperty = Prop("CheckMessage");
        public static string GetCheckMessage(DependencyObject o) => (string)o.GetValue(CheckMessageProperty);
        public static void SetCheckMessage(DependencyObject o, string v) => o.SetValue(CheckMessageProperty, v);
    }
}
