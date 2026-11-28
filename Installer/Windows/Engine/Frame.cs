// Frame.cs - DynALisp.Windows: a frame placed on a picture, the part of it kept
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
// dyl:PictureFrame (the preview picture of the Start page, Res\Dyl-StartPagePreview.xaml):
// its value is the file of a picture, shown whole in the control, with a frame of the shape
// Aspect (width / height) over it, the rest darkened. The frame is dragged to move it, its
// corner handle dragged (or the mouse wheel turned) to size it, never out of the picture; a
// click outside it brings it there. It opens as large as the picture lets it, in its middle.
// It gives back the part of the picture kept, in its pixels, "x y width height", as the
// value <key>/crop. StartUi.Picture reads a picture turned as its camera says (the
// orientation of a JPEG photo).

using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

namespace DynALisp.Windows
{
    public class PictureFrame : ContentControl
    {
        public static readonly DependencyProperty AspectProperty = DependencyProperty.Register("Aspect", typeof(double), typeof(PictureFrame),
            new PropertyMetadata(1.6, (d, e) => ((PictureFrame)d).Reset()));
        // The shape of the frame, its width divided by its height:
        public double Aspect { get => (double)GetValue(AspectProperty); set => SetValue(AspectProperty, value); }

        const double Handle = 12, MinSide = 32;

        readonly Grid _box = new Grid { ClipToBounds = true };
        readonly Image _image = new Image { Stretch = Stretch.Uniform, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        readonly Canvas _over = new Canvas { Background = Brushes.Transparent };
        readonly Path _mask = new Path { Fill = new SolidColorBrush(Color.FromArgb(0x99, 0, 0, 0)), IsHitTestVisible = false };
        readonly Rectangle _frame = new Rectangle { StrokeThickness = 2, IsHitTestVisible = false };
        readonly Rectangle _grip = new Rectangle { Width = Handle, Height = Handle, Cursor = Cursors.SizeNWSE };
        readonly TextBlock _none = StartUi.Text("No picture", "Dyl.Muted");
        BitmapSource _pic;
        Rect _shown, _crop;               // the picture as shown, the frame (both in the control)
        Point _from;
        Rect _start;
        int _drag;                        // 0 none, 1 moving, 2 sizing
        Action<string> _give;

        public PictureFrame()
        {
            Focusable = false;
            _frame.SetResourceReference(Shape.StrokeProperty, "Dyl.Accent");
            _grip.SetResourceReference(Shape.FillProperty, "Dyl.Accent");
            _box.SetResourceReference(Panel.BackgroundProperty, "Dyl.Input");
            _none.HorizontalAlignment = HorizontalAlignment.Center;
            _none.VerticalAlignment = VerticalAlignment.Center;
            _over.Children.Add(_mask);
            _over.Children.Add(_frame);
            _over.Children.Add(_grip);
            _box.Children.Add(_image);
            _box.Children.Add(_over);
            _box.Children.Add(_none);
            Content = _box;
            _box.SizeChanged += (s, e) => Reset();
            _over.MouseLeftButtonDown += Down;
            _over.MouseMove += Move;
            _over.MouseLeftButtonUp += (s, e) => { _drag = 0; _over.ReleaseMouseCapture(); };
            _over.MouseWheel += Wheel;
            _over.Cursor = Cursors.SizeAll;
        }

        // The picture of file (none: nothing to frame), the crop given to give as it changes:
        public void Attach(string file, Action<string> give)
        {
            _give = give;
            _pic = StartUi.Picture(file);
            _image.Source = _pic;
            _none.Visibility = _pic == null ? Visibility.Visible : Visibility.Collapsed;
            _over.Visibility = _pic == null ? Visibility.Collapsed : Visibility.Visible;
            Reset();
        }

        // The frame as large as the picture lets it, in its middle:
        void Reset()
        {
            if (_pic == null || _box.ActualWidth <= 0 || _box.ActualHeight <= 0) { Give(); return; }
            double s = Math.Min(_box.ActualWidth / _pic.PixelWidth, _box.ActualHeight / _pic.PixelHeight);
            double w = _pic.PixelWidth * s, h = _pic.PixelHeight * s;
            _shown = new Rect((_box.ActualWidth - w) / 2, (_box.ActualHeight - h) / 2, w, h);
            double fw = Math.Min(w, h * Aspect);
            _crop = new Rect(_shown.X + (w - fw) / 2, _shown.Y + (h - fw / Aspect) / 2, fw, fw / Aspect);
            Draw();
        }

        void Draw()
        {
            var g = new GeometryGroup { FillRule = FillRule.EvenOdd };
            g.Children.Add(new RectangleGeometry(_shown));
            g.Children.Add(new RectangleGeometry(_crop));
            _mask.Data = g;
            Canvas.SetLeft(_frame, _crop.X);
            Canvas.SetTop(_frame, _crop.Y);
            _frame.Width = _crop.Width;
            _frame.Height = _crop.Height;
            Canvas.SetLeft(_grip, _crop.Right - Handle / 2 - 1);
            Canvas.SetTop(_grip, _crop.Bottom - Handle / 2 - 1);
            Give();
        }

        // The part kept, in the pixels of the picture:
        void Give()
        {
            if (_give == null) return;
            if (_pic == null || _shown.Width <= 0) { _give(""); return; }
            double k = _pic.PixelWidth / _shown.Width;
            int x = Clamp((int)Math.Round((_crop.X - _shown.X) * k), 0, _pic.PixelWidth - 1);
            int y = Clamp((int)Math.Round((_crop.Y - _shown.Y) * k), 0, _pic.PixelHeight - 1);
            int w = Clamp((int)Math.Round(_crop.Width * k), 1, _pic.PixelWidth - x);
            int h = Clamp((int)Math.Round(_crop.Height * k), 1, _pic.PixelHeight - y);
            _give(string.Join(" ", new[] { x, y, w, h }));
        }

        static int Clamp(int v, int a, int b) => Math.Max(a, Math.Min(b, v));
        static double Clamp(double v, double a, double b) => Math.Max(a, Math.Min(b, v));

        // The frame moved to x, y (its top-left corner), kept on the picture:
        void Place(double x, double y, double w)
        {
            w = Clamp(w, Math.Min(MinSide * Math.Max(1, Aspect), _shown.Width), Math.Min(_shown.Width, _shown.Height * Aspect));
            double h = w / Aspect;
            x = Clamp(x, _shown.X, _shown.Right - w);
            y = Clamp(y, _shown.Y, _shown.Bottom - h);
            _crop = new Rect(x, y, w, h);
            Draw();
        }

        void Down(object sender, MouseButtonEventArgs e)
        {
            var p = e.GetPosition(_over);
            var grip = new Rect(_crop.Right - Handle, _crop.Bottom - Handle, Handle * 1.5, Handle * 1.5);
            if (grip.Contains(p)) _drag = 2;
            else
            {
                // a click outside the frame brings it there (its middle under the mouse):
                if (!_crop.Contains(p)) Place(p.X - _crop.Width / 2, p.Y - _crop.Height / 2, _crop.Width);
                _drag = 1;
            }
            _from = p;
            _start = _crop;
            _over.CaptureMouse();
            e.Handled = true;
        }

        void Move(object sender, MouseEventArgs e)
        {
            if (_drag == 0) return;
            var p = e.GetPosition(_over);
            double dx = p.X - _from.X, dy = p.Y - _from.Y;
            if (_drag == 1) Place(_start.X + dx, _start.Y + dy, _start.Width);
            else
            {
                // the corner follows the mouse, the frame keeping its shape and its top-left:
                double w = Math.Max(_start.Width + dx, (_start.Height + dy) * Aspect);
                w = Math.Min(w, Math.Min(_shown.Right - _start.X, (_shown.Bottom - _start.Y) * Aspect));
                Place(_start.X, _start.Y, w);
            }
        }

        // The wheel sizes the frame about its middle:
        void Wheel(object sender, MouseWheelEventArgs e)
        {
            double w = _crop.Width * Math.Pow(1.1, -e.Delta / 120.0);
            w = Clamp(w, Math.Min(MinSide * Math.Max(1, Aspect), _shown.Width), Math.Min(_shown.Width, _shown.Height * Aspect));
            var c = new Point(_crop.X + _crop.Width / 2, _crop.Y + _crop.Height / 2);
            Place(c.X - w / 2, c.Y - w / Aspect / 2, w);
            e.Handled = true;
        }
    }

    static partial class StartUi
    {
        // A picture read whole (the file left free), turned as the camera that took it says (the
        // EXIF orientation of a photo: 3 upside down, 6 and 8 a quarter turn); null when it cannot:
        public static BitmapSource Picture(string file)
        {
            if (string.IsNullOrEmpty(file) || !System.IO.File.Exists(file)) return null;
            try
            {
                BitmapFrame f;
                using (var fs = new System.IO.FileStream(file, System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.ReadWrite))
                    f = BitmapDecoder.Create(fs, BitmapCreateOptions.IgnoreColorProfile | BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad).Frames[0];
                BitmapSource src = f;
                int turn = 0;
                try
                {
                    if (f.Metadata is BitmapMetadata m && m.ContainsQuery("System.Photo.Orientation"))
                    {
                        object o = m.GetQuery("System.Photo.Orientation");
                        int or = o == null ? 1 : Convert.ToInt32(o, CultureInfo.InvariantCulture);
                        turn = or == 3 ? 180 : or == 6 ? 90 : or == 8 ? 270 : 0;
                    }
                }
                catch { }
                if (turn != 0) src = new TransformedBitmap(src, new RotateTransform(turn));
                src.Freeze();
                return src;
            }
            catch { return null; }
        }
    }
}
