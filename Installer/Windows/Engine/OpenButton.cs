// OpenButton.cs - DynALisp.Windows: the square open button beside a setting
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
// <dyl:OpenButton x:Name="dsm" dyl:Win.Open="..."/>: the button that opens the window editing
// a setting (Windows convention), the same icon as Dyl:MoreTile draws in a DCL window: a box
// open at its top-right corner, an arrow coming out of it. Its look is the Dyl.OpenButton
// style of Theme.xaml; the icon takes the colour of the text, greyed out with the button.

using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Shapes;

namespace DynALisp.Windows
{
    public class OpenButton : Button
    {
        public OpenButton()
        {
            SetResourceReference(StyleProperty, "Dyl.OpenButton");
            ToolTip = "Open";
            var icon = new Path
            {
                Data = Geometry.Parse("M9,3 H3 V13 H13 V7 M7.5,8.5 L13,3 M9.5,3 H13 V6.5"),
                StrokeThickness = 1.4,
                StrokeStartLineCap = PenLineCap.Round,
                StrokeEndLineCap = PenLineCap.Round,
                StrokeLineJoin = PenLineJoin.Round,
                Width = 16,
                Height = 16,
                Stretch = Stretch.None,
                SnapsToDevicePixels = true,
            };
            icon.SetBinding(Shape.StrokeProperty, new Binding("Foreground") { Source = this });
            Content = icon;
        }
    }
}
