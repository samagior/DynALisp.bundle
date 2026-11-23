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
//   dyl:Win.Close="4"                       on a button: closes the window, the Lisp gets 4;
//                                           on a ListBox: an item double-clicked closes it;
//                                           on a ComboBox: an item picked closes it
//   dyl:Win.Fills="var:0,val:1"             on a ListBox: the item picked (divided by tabs)
//                                           puts its column 0 in the box var, 1 in val
//   dyl:Win.Filter="lst:0,2"                on a TextBox: lists only the items of lst whose
//                                           columns 0 or 2 hold each word typed (accents and
//                                           case ignored); "lst:4;ind:5": the column 5 while
//                                           the checkbox ind is on
//   dyl:Win.CountOf="lst"                   on a TextBlock: how many items of lst are listed,
//   dyl:Win.CountText="{0} of {1} words"    as this text says (listed, all)
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
// A list of rows edited in the window (Rows.cs: the layers of an assembly, the groups):
//
//   dyl:Win.Rows="1"                        on a ListBox: its rows (key/rows) are edited here
//   dyl:Win.RowsIn="4"                      on that ListBox in a preset window: its rows are
//                                           those of the column 4 of the preset shown
//   dyl:Win.Column="2"                      on a field: the column of the row shown it edits
//   dyl:Win.Unique="message"                on a field: its column unique (any case)
//   dyl:Win.Exclusive="1"                   on a checkbox field: on in one row at most
//   dyl:Win.Toggle="46"                     on a checkbox in the template of the rows: checking
//                                           it sets the column 46 of its row ("1" / "0"), its
//                                           IsChecked bound to {Binding V[46], Converter=
//                                           {x:Static dyl:On.Converter}}
//   dyl:Win.Follows="lp/widths"             on a field: takes the item of that list when the
//                                           field lp changes
//   dyl:Win.ListBy="lg"                     on a list field: lists only its items whose
//                                           key/by is the value of the field lg (a group)
//   dyl:Win.Do="add"                        on a button: add, remove, up, down, flip, reset
//   dyl:Win.Columns="men:7,mex:8"           on a button with Win.Open: the window it opens
//                                           edits those columns of the rows selected (in a
//                                           preset window, of the presets selected), as
//                                           the values of those keys
//   dyl:Win.Summary="{count} rows"          on a TextBlock or a GroupBox: what the rows hold
//   dyl:Win.SummaryEmpty="No rows."         in its place while there is no row
//
// A button with IsDefault closes the window with 1 (OK, Save), one with IsCancel with 0.
//
// The items of a list given by the Lisp (key/list) may hold columns divided by a tab: its
// template shows one with {Binding Converter={x:Static dyl:Cell.Converter},
// ConverterParameter=1} (the second one).

using System.Windows;
using System.Windows.Data;

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
        public static string GetFills(DependencyObject o) => (string)o.GetValue(FillsProperty);
        public static void SetFills(DependencyObject o, string v) => o.SetValue(FillsProperty, v);
        public static readonly DependencyProperty FillsProperty = Prop("Fills");
        public static string GetFilter(DependencyObject o) => (string)o.GetValue(FilterProperty);
        public static void SetFilter(DependencyObject o, string v) => o.SetValue(FilterProperty, v);
        public static readonly DependencyProperty FilterProperty = Prop("Filter");
        public static string GetCountOf(DependencyObject o) => (string)o.GetValue(CountOfProperty);
        public static void SetCountOf(DependencyObject o, string v) => o.SetValue(CountOfProperty, v);
        public static readonly DependencyProperty CountOfProperty = Prop("CountOf");
        public static string GetCountText(DependencyObject o) => (string)o.GetValue(CountTextProperty);
        public static void SetCountText(DependencyObject o, string v) => o.SetValue(CountTextProperty, v);
        public static readonly DependencyProperty CountTextProperty = Prop("CountText");
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

        public static readonly DependencyProperty RowsProperty = Prop("Rows");
        public static string GetRows(DependencyObject o) => (string)o.GetValue(RowsProperty);
        public static void SetRows(DependencyObject o, string v) => o.SetValue(RowsProperty, v);

        public static readonly DependencyProperty RowsInProperty = Prop("RowsIn");
        public static string GetRowsIn(DependencyObject o) => (string)o.GetValue(RowsInProperty);
        public static void SetRowsIn(DependencyObject o, string v) => o.SetValue(RowsInProperty, v);

        public static readonly DependencyProperty ColumnProperty = Prop("Column");
        public static string GetColumn(DependencyObject o) => (string)o.GetValue(ColumnProperty);
        public static void SetColumn(DependencyObject o, string v) => o.SetValue(ColumnProperty, v);

        public static readonly DependencyProperty UniqueProperty = Prop("Unique");
        public static string GetUnique(DependencyObject o) => (string)o.GetValue(UniqueProperty);
        public static void SetUnique(DependencyObject o, string v) => o.SetValue(UniqueProperty, v);

        public static readonly DependencyProperty ToggleProperty = Prop("Toggle");
        public static string GetToggle(DependencyObject o) => (string)o.GetValue(ToggleProperty);
        public static void SetToggle(DependencyObject o, string v) => o.SetValue(ToggleProperty, v);

        public static readonly DependencyProperty ExclusiveProperty = Prop("Exclusive");
        public static string GetExclusive(DependencyObject o) => (string)o.GetValue(ExclusiveProperty);
        public static void SetExclusive(DependencyObject o, string v) => o.SetValue(ExclusiveProperty, v);

        public static readonly DependencyProperty FollowsProperty = Prop("Follows");
        public static string GetFollows(DependencyObject o) => (string)o.GetValue(FollowsProperty);
        public static void SetFollows(DependencyObject o, string v) => o.SetValue(FollowsProperty, v);

        public static readonly DependencyProperty ListByProperty = Prop("ListBy");
        public static string GetListBy(DependencyObject o) => (string)o.GetValue(ListByProperty);
        public static void SetListBy(DependencyObject o, string v) => o.SetValue(ListByProperty, v);

        public static readonly DependencyProperty DoProperty = Prop("Do");
        public static string GetDo(DependencyObject o) => (string)o.GetValue(DoProperty);
        public static void SetDo(DependencyObject o, string v) => o.SetValue(DoProperty, v);

        public static readonly DependencyProperty ColumnsProperty = Prop("Columns");
        public static string GetColumns(DependencyObject o) => (string)o.GetValue(ColumnsProperty);
        public static void SetColumns(DependencyObject o, string v) => o.SetValue(ColumnsProperty, v);

        public static readonly DependencyProperty SummaryProperty = Prop("Summary");
        public static string GetSummary(DependencyObject o) => (string)o.GetValue(SummaryProperty);
        public static void SetSummary(DependencyObject o, string v) => o.SetValue(SummaryProperty, v);

        public static readonly DependencyProperty SummaryEmptyProperty = Prop("SummaryEmpty");
        public static string GetSummaryEmpty(DependencyObject o) => (string)o.GetValue(SummaryEmptyProperty);
        public static void SetSummaryEmpty(DependencyObject o, string v) => o.SetValue(SummaryEmptyProperty, v);
    }

    // "1" as true, anything else as false, for a checkbox bound to a column of a row (see
    // Win.Toggle): {Binding V[46], Converter={x:Static dyl:On.Converter}}:
    public sealed class On : System.Windows.Data.IValueConverter
    {
        public static readonly On Converter = new On();
        public object Convert(object value, System.Type t, object p, System.Globalization.CultureInfo c) => (value as string) == "1";
        public object ConvertBack(object value, System.Type t, object p, System.Globalization.CultureInfo c) => value is bool b && b ? "1" : "0";
    }

    // The column n (ConverterParameter, from 0) of an item divided by tabs ("CC\tChange
    // Color"), "" when it has none: {Binding Converter={x:Static dyl:Cell.Converter},
    // ConverterParameter=1}:
    public sealed class Cell : System.Windows.Data.IValueConverter
    {
        public static readonly Cell Converter = new Cell();
        public object Convert(object value, System.Type t, object p, System.Globalization.CultureInfo c)
        {
            var f = (value as string ?? "").Split('\t');
            int.TryParse(p as string ?? "0", System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture, out int n);
            return n >= 0 && n < f.Length ? f[n] : "";
        }
        public object ConvertBack(object value, System.Type t, object p, System.Globalization.CultureInfo c) => Binding.DoNothing;
    }
}
