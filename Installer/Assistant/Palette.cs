// Palette.cs - DynALisp.Assistant: the Assistant palette, a conversation with Claude Code
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
// A palette of AutoCAD (PaletteSet, dockable left or right) holding a WPF view built in code:
// a conversation changes as it goes, so it is not a window file of Res. It wears the theme of
// the windows of DynALisp (Theme of DynALisp.Windows.dll, found by reflection; plain colours
// when that plugin is not loaded), in the light or dark theme of AutoCAD (COLORTHEME), and
// follows it when it changes.
//
//   top       New chat, the model (Sonnet, Opus: a view choice, kept for the session),
//             Open Docs
//   banner    what to do before the first message: install Claude Code (the installer of
//             Anthropic, in a console the user sees), sign in (claude auth login, in a
//             console), Check again; and a note when ANTHROPIC_API_KEY is set
//   messages  the conversation, its text selectable, code blocks in a fixed font
//   input     Enter sends, Shift+Enter starts a new line; Stop ends the answer

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Autodesk.AutoCAD.Windows;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DynALisp.Assistant
{
    static class Palette
    {
        static PaletteSet _ps;
        static ChatView _view;
        static readonly Guid Id = new Guid("8f0c2a4e-6d1b-4c7a-9e35-2b7d41c0a913");

        public static void Show(string docs, string prompt)
        {
            if (_ps == null)
            {
                _view = new ChatView();
                _ps = new PaletteSet("Assistant", "Dyl-Assistant", Id)
                {
                    Style = PaletteSetStyles.ShowCloseButton | PaletteSetStyles.ShowAutoHideButton | PaletteSetStyles.ShowPropertiesMenu,
                    MinimumSize = new System.Drawing.Size(300, 360),
                    DockEnabled = DockSides.Left | DockSides.Right | DockSides.None,
                    KeepFocus = true,
                };
                _ps.AddVisual("Assistant", _view);
                AcApp.SystemVariableChanged += (s, e) =>
                {
                    if (string.Equals(e.Name, "COLORTHEME", StringComparison.OrdinalIgnoreCase)) _view.SetTheme(Dark());
                };
            }
            _view.Docs = docs;
            _view.Chat.PromptFile = prompt;
            _view.SetTheme(Dark());
            _ps.Visible = true;
            _view.Check(false);
        }

        public static void Close()
        {
            try { _view?.Chat.Reset(); } catch { }
        }

        static bool Dark()
        {
            try { return Convert.ToInt32(AcApp.GetSystemVariable("COLORTHEME")) == 0; }
            catch { return false; }
        }
    }

    sealed class ChatView : UserControl
    {
        public readonly Chat Chat = new Chat();
        public string Docs;

        readonly StackPanel _list = new StackPanel();
        readonly ScrollViewer _scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
        readonly TextBox _input = new TextBox { AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 44, MaxHeight = 140, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        readonly Button _send = new Button { Content = "Send", MinWidth = 64 };
        readonly Button _stop = new Button { Content = "Stop", MinWidth = 64, Visibility = Visibility.Collapsed };
        readonly ComboBox _model = new ComboBox { Width = 90 };
        readonly TextBlock _status = new TextBlock { Margin = new Thickness(0, 4, 0, 0) };
        readonly Border _banner = new Border { Padding = new Thickness(10), Margin = new Thickness(8, 0, 8, 8), CornerRadius = new CornerRadius(4), Visibility = Visibility.Collapsed };
        readonly TextBlock _bannerText = new TextBlock { TextWrapping = TextWrapping.Wrap };
        readonly Button _install = new Button { Content = "Install Claude Code" };
        readonly Button _login = new Button { Content = "Sign in" };
        readonly Button _recheck = new Button { Content = "Check again" };
        readonly TextBlock _keyNote = new TextBlock { TextWrapping = TextWrapping.Wrap, Margin = new Thickness(8, 0, 8, 8), Visibility = Visibility.Collapsed };

        bool _ready, _checking;
        StackPanel _cur;           // the message being written
        readonly StringBuilder _curText = new StringBuilder();

        static readonly (string Label, string Value)[] Models = { ("Sonnet", "sonnet"), ("Opus", "opus") };

        public ChatView()
        {
            SetResourceReference(BackgroundProperty, "Dyl.Back");
            SetResourceReference(ForegroundProperty, "Dyl.Text");
            FontFamily = new FontFamily("Segoe UI");
            FontSize = 12.5;
            TextOptions.SetTextFormattingMode(this, TextFormattingMode.Display);
            UseLayoutRounding = true;

            var root = new Grid();
            for (int i = 0; i < 4; i++) root.RowDefinitions.Add(new RowDefinition { Height = i == 2 ? new GridLength(1, GridUnitType.Star) : GridLength.Auto });

            // top
            var top = new DockPanel { Margin = new Thickness(8), LastChildFill = false };
            var newChat = new Button { Content = "New chat" };
            var docs = new Button { Content = "Open Docs" };
            foreach (var m in Models) _model.Items.Add(m.Label);
            _model.SelectedIndex = 0;
            newChat.Click += (s, e) => NewChat();
            docs.Click += (s, e) => OpenDocs();
            _model.SelectionChanged += (s, e) => ModelChanged();
            DockPanel.SetDock(newChat, Dock.Left);
            DockPanel.SetDock(docs, Dock.Right);
            DockPanel.SetDock(_model, Dock.Right);
            _model.Margin = new Thickness(0, 0, 6, 0);
            top.Children.Add(newChat);
            top.Children.Add(docs);
            top.Children.Add(_model);
            Grid.SetRow(top, 0);
            root.Children.Add(top);

            // banner
            var bp = new StackPanel();
            bp.Children.Add(_bannerText);
            var bb = new WrapPanel { Margin = new Thickness(0, 8, 0, 0) };
            foreach (var b in new[] { _install, _login, _recheck }) { b.Margin = new Thickness(0, 0, 6, 0); bb.Children.Add(b); }
            bp.Children.Add(bb);
            _banner.Child = bp;
            _banner.SetResourceReference(Border.BackgroundProperty, "Dyl.Surface");
            _install.Click += (s, e) => Run(Cli.InstallCommand);
            _login.Click += (s, e) => { var exe = Cli.Find(); if (exe != null) Run(Cli.LoginCommand(exe)); };
            _recheck.Click += (s, e) => Check(true);
            _keyNote.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.ErrorText");
            var heads = new StackPanel();
            heads.Children.Add(_banner);
            heads.Children.Add(_keyNote);
            Grid.SetRow(heads, 1);
            root.Children.Add(heads);

            // messages
            _list.Margin = new Thickness(8, 0, 8, 8);
            _scroll.Content = _list;
            Grid.SetRow(_scroll, 2);
            root.Children.Add(_scroll);

            // input
            var ip = new Grid { Margin = new Thickness(8) };
            ip.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            ip.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            ip.RowDefinitions.Add(new RowDefinition());
            ip.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            var btns = new StackPanel { Margin = new Thickness(6, 0, 0, 0), VerticalAlignment = VerticalAlignment.Bottom };
            btns.Children.Add(_send);
            btns.Children.Add(_stop);
            Grid.SetColumn(btns, 1);
            ip.Children.Add(_input);
            ip.Children.Add(btns);
            _status.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            Grid.SetRow(_status, 1);
            Grid.SetColumnSpan(_status, 2);
            ip.Children.Add(_status);
            Grid.SetRow(ip, 3);
            root.Children.Add(ip);

            _send.Click += (s, e) => Send();
            _stop.Click += (s, e) => { Chat.Stop(); };
            _input.PreviewKeyDown += (s, e) =>
            {
                if (e.Key == Key.Enter && (Keyboard.Modifiers & ModifierKeys.Shift) == 0)
                {
                    e.Handled = true;
                    Send();
                }
            };

            Chat.Delta += t => Ui(() => OnDelta(t));
            Chat.Message += t => Ui(() => OnMessage(t));
            Chat.TurnEnd += (err, login) => Ui(() => OnTurnEnd(err, login));
            Chat.KeySource += src => Ui(() => ShowKeyNote(src));

            Content = root;
            Welcome();
            UpdateState();
        }

        void Ui(Action a) => Dispatcher.BeginInvoke(a);

        // ---- theme ------------------------------------------------------------------

        public void SetTheme(bool dark)
        {
            var md = Resources.MergedDictionaries;
            md.Clear();
            var t = AppDomain.CurrentDomain.GetAssemblies()
                .FirstOrDefault(a => a.GetName().Name == "DynALisp.Windows")?.GetType("DynALisp.Windows.Theme");
            ResourceDictionary brushes = null, styles = null;
            try
            {
                brushes = t?.GetMethod("Brushes", BindingFlags.Public | BindingFlags.Static)?.Invoke(null, new object[] { dark }) as ResourceDictionary;
                styles = t?.GetMethod("Styles", BindingFlags.NonPublic | BindingFlags.Static)?.Invoke(null, null) as ResourceDictionary;
            }
            catch { }
            if (styles != null) md.Add(styles);
            md.Add(brushes ?? Plain(dark));
        }

        // The colours alone, when DynALisp.Windows.dll is not loaded:
        static ResourceDictionary Plain(bool dark)
        {
            var c = dark
                ? new Dictionary<string, string> { ["Back"] = "#252A32", ["Surface"] = "#313844", ["Text"] = "#E6EAF0", ["Muted"] = "#A3ADBC", ["Border"] = "#3C4452", ["ErrorText"] = "#FF8F85" }
                : new Dictionary<string, string> { ["Back"] = "#E9ECEF", ["Surface"] = "#FFFFFF", ["Text"] = "#1F2933", ["Muted"] = "#5F6B7A", ["Border"] = "#D5DAE0", ["ErrorText"] = "#B42318" };
            var d = new ResourceDictionary();
            foreach (var kv in c) d["Dyl." + kv.Key] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(kv.Value));
            return d;
        }

        // ---- set-up -----------------------------------------------------------------

        // Finds Claude Code and asks whether it is signed in, on a thread of its own (it
        // takes a second or two), once, or again when asked (Check again).
        public void Check(bool again)
        {
            if (_checking || (_ready && !again)) return;
            _checking = true;
            _status.Text = "Looking for Claude Code...";
            new Thread(() =>
            {
                string exe = null, version = null;
                Dictionary<string, object> st = null;
                try
                {
                    exe = Cli.Find();
                    if (exe != null) { version = Cli.Version(exe); st = Cli.AuthStatus(exe); }
                }
                catch { }
                Ui(() => Checked(exe, version, st));
            }) { IsBackground = true, Name = "DynALisp Assistant check" }.Start();
        }

        void Checked(string exe, string version, Dictionary<string, object> st)
        {
            _checking = false;
            _ready = false;
            if (exe == null)
                Banner("Claude Code is not installed. Install it, then sign in with your Claude account.", install: true, login: false);
            else if (version == null)
                Banner("Claude Code does not run (" + exe + "). Install it again.", install: true, login: false);
            else if (st != null && !(Json.Get(st, "loggedIn") is bool b && b))
                Banner("Sign in to Claude Code with your Claude account.", install: false, login: true);
            else
            {
                _banner.Visibility = Visibility.Collapsed;
                Chat.Exe = exe;
                _ready = true;
            }
            if (Cli.ApiKeySet()) ShowKeyNote("ANTHROPIC_API_KEY");
            _status.Text = _ready ? "Claude Code " + version : "";
            UpdateState();
            if (_ready) _input.Focus();
        }

        void Banner(string text, bool install, bool login)
        {
            _bannerText.Text = text;
            _install.Visibility = install ? Visibility.Visible : Visibility.Collapsed;
            _login.Visibility = login ? Visibility.Visible : Visibility.Collapsed;
            _banner.Visibility = Visibility.Visible;
        }

        void ShowKeyNote(string src)
        {
            _keyNote.Text = "ANTHROPIC_API_KEY is set: Claude Code uses that API key (billed by the API), not your Claude subscription. Remove the variable to use your subscription.";
            _keyNote.Visibility = Visibility.Visible;
        }

        static void Run(string command)
        {
            try { Cli.Console(command); }
            catch (Exception e) { Bridge.Say("\n--> Unable to open a console: " + e.Message); }
        }

        void OpenDocs()
        {
            if (string.IsNullOrEmpty(Docs)) return;
            try { Process.Start(new ProcessStartInfo(Docs) { UseShellExecute = true }); }
            catch (Exception e) { Bridge.Say("\n--> Unable to open the docs: " + e.Message); }
        }

        // ---- conversation -----------------------------------------------------------

        void Send()
        {
            var text = _input.Text.Trim();
            if (text == "" || !_ready || Chat.Busy) return;
            if (_list.Children.Count == 1 && _list.Children[0] is TextBlock) _list.Children.Clear();
            _list.Children.Add(Bubble(text, user: true));
            _input.Clear();
            try
            {
                Chat.Send(text);
                _status.Text = "Thinking...";
            }
            catch (Exception e)
            {
                Error("Unable to start Claude Code: " + e.Message);
            }
            UpdateState();
            End();
        }

        void OnDelta(string t)
        {
            if (_cur == null)
            {
                _cur = new StackPanel();
                _curText.Clear();
                _list.Children.Add(Frame(_cur, user: false));
            }
            _curText.Append(t);
            _cur.Children.Clear();
            _cur.Children.Add(Para(_curText.ToString(), false));
            _status.Text = "Writing...";
            End();
        }

        void OnMessage(string t)
        {
            if (_cur == null)
            {
                _cur = new StackPanel();
                _list.Children.Add(Frame(_cur, user: false));
            }
            Render(_cur, t);
            _cur = null;
            End();
        }

        void OnTurnEnd(string err, bool login)
        {
            _cur = null;
            _status.Text = "";
            if (err != null)
            {
                Error(err);
                if (login) { _ready = false; Banner("Sign in to Claude Code with your Claude account, then Check again.", install: false, login: true); }
            }
            UpdateState();
            End();
        }

        void Error(string msg)
        {
            var t = new TextBlock { Text = msg, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 4, 0, 4) };
            t.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.ErrorText");
            _list.Children.Add(t);
        }

        void NewChat()
        {
            Chat.Reset();
            _cur = null;
            _list.Children.Clear();
            Welcome();
            UpdateState();
        }

        void ModelChanged()
        {
            int i = _model.SelectedIndex;
            if (i < 0) return;
            Chat.Model = Models[i].Value;
            // an idle process ends: the next message starts the same conversation on this model
            if (!Chat.Busy) Chat.Stop();
        }

        void Welcome()
        {
            var t = new TextBlock
            {
                Text = "Ask about AutoCAD, AutoLISP or DynALisp. This first version answers questions: it does not read or change the drawing yet.",
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 8, 0, 0),
            };
            t.SetResourceReference(TextBlock.ForegroundProperty, "Dyl.Muted");
            _list.Children.Add(t);
        }

        void UpdateState()
        {
            bool busy = Chat.Busy;
            _send.Visibility = busy ? Visibility.Collapsed : Visibility.Visible;
            _stop.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
            _send.IsEnabled = _ready;
            _input.IsEnabled = _ready;
        }

        void End() => _scroll.ScrollToEnd();

        // ---- messages ---------------------------------------------------------------

        UIElement Bubble(string text, bool user)
        {
            var p = new StackPanel();
            Render(p, text);
            return Frame(p, user);
        }

        static UIElement Frame(StackPanel content, bool user)
        {
            var b = new Border
            {
                Child = content,
                Padding = user ? new Thickness(8, 6, 8, 6) : new Thickness(0, 4, 0, 4),
                Margin = user ? new Thickness(32, 8, 0, 4) : new Thickness(0, 4, 0, 4),
                CornerRadius = new CornerRadius(6),
            };
            if (user) b.SetResourceReference(Border.BackgroundProperty, "Dyl.Surface");
            return b;
        }

        // Markdown, simply: code blocks (```) in a fixed font, headings in bold, the **
        // and the ` of the text dropped.
        static void Render(StackPanel p, string md)
        {
            p.Children.Clear();
            var lines = md.Replace("\r\n", "\n").Split('\n');
            var para = new StringBuilder();
            var code = new StringBuilder();
            bool inCode = false;
            void Flush()
            {
                var s = para.ToString().Trim('\n');
                if (s.Trim() != "") p.Children.Add(Para(s, false));
                para.Clear();
            }
            foreach (var raw in lines)
            {
                if (raw.TrimStart().StartsWith("```", StringComparison.Ordinal))
                {
                    if (inCode) { p.Children.Add(Code(code.ToString().TrimEnd('\n'))); code.Clear(); }
                    else Flush();
                    inCode = !inCode;
                    continue;
                }
                if (inCode) { code.Append(raw).Append('\n'); continue; }
                var h = raw.TrimStart();
                if (h.StartsWith("#", StringComparison.Ordinal))
                {
                    Flush();
                    p.Children.Add(Para(Clean(h.TrimStart('#').Trim()), true));
                    continue;
                }
                if (raw.Trim() == "") { Flush(); continue; }
                para.Append(Clean(raw)).Append('\n');
            }
            if (inCode) p.Children.Add(Code(code.ToString().TrimEnd('\n')));
            Flush();
        }

        static string Clean(string s) => s.Replace("**", "").Replace("`", "");

        // A text that can be selected and copied: a TextBox without the look of a box.
        static TextBox Para(string text, bool bold)
        {
            var t = new TextBox
            {
                Style = new Style(typeof(TextBox)),
                Text = text,
                IsReadOnly = true,
                TextWrapping = TextWrapping.Wrap,
                BorderThickness = new Thickness(0),
                Background = Brushes.Transparent,
                Padding = new Thickness(0),
                Margin = new Thickness(0, 2, 0, 4),
                FontWeight = bold ? FontWeights.SemiBold : FontWeights.Normal,
            };
            t.SetResourceReference(ForegroundProperty, "Dyl.Text");
            t.SetResourceReference(TextBox.CaretBrushProperty, "Dyl.Text");
            return t;
        }

        static UIElement Code(string text)
        {
            var t = Para(text, false);
            t.FontFamily = new FontFamily("Consolas");
            t.TextWrapping = TextWrapping.NoWrap;
            t.HorizontalScrollBarVisibility = ScrollBarVisibility.Auto;
            t.Margin = new Thickness(0);
            var b = new Border { Child = t, Padding = new Thickness(8, 6, 8, 6), Margin = new Thickness(0, 2, 0, 6), CornerRadius = new CornerRadius(4), BorderThickness = new Thickness(1) };
            b.SetResourceReference(Border.BackgroundProperty, "Dyl.Surface");
            b.SetResourceReference(Border.BorderBrushProperty, "Dyl.Border");
            return b;
        }
    }
}
