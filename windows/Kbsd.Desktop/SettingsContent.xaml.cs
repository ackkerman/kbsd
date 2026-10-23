// This file guarantees that Swift-style controls update the existing sound model without retaining typed text.
using Kbsd.Core;
using W = System.Windows;
using C = System.Windows.Controls;
using M = System.Windows.Media;
using Input = System.Windows.Input;
using Automation = System.Windows.Automation.AutomationProperties;

namespace Kbsd.Desktop;

internal partial class SettingsContent : C.UserControl
{
    private readonly TrayApplication model;
    private readonly Dictionary<string, C.RadioButton> cards = [];
    private readonly Dictionary<string, C.Button> previews = [];
    private readonly Dictionary<string, C.CheckBox> toggles = [];
    private bool refreshing = true;

    public SettingsContent(TrayApplication model)
    {
        this.model = model;
        InitializeComponent();
        foreach (var set in SoundBank.Sets) AddSoundCard(set);
        AddToggle(SoundOptions, "Randomized pitching", "A subtle variation with every press.", "random", "\uE8B1");
        AddToggle(SoundOptions, "Spatial sound", "Let the sound follow the left and right of your keyboard.", "stereo", "\uE767");
        AddToggle(SoundOptions, "Modifier keys", "Include Shift, Windows, Alt, and Control.", "modifiers", "\uE765");
        AddToggle(SoundOptions, "Mouse clicks", "A little extra feedback for your clicks.", "mouse", "\uE962", last: true);
        AddToggle(GeneralOptions, "Launch at login", "Ready when you start your day.", "startup", "\uE706", last: true);
        TypingTest.LostKeyboardFocus += (_, _) => TypingTest.Content = "Click here, then start typing…";
        refreshing = false;
    }

    private void AddSoundCard(SwitchSet set)
    {
        var card = new C.Grid { Margin = new W.Thickness(6, 0, 6, 12) };
        var select = new C.RadioButton { GroupName = "SoundSets", Style = (W.Style)FindResource("Card"), MinHeight = 75 };
        Automation.SetName(select, "Select " + set.Name);
        var content = new C.Grid();
        content.ColumnDefinitions.Add(new C.ColumnDefinition { Width = W.GridLength.Auto });
        content.ColumnDefinitions.Add(new C.ColumnDefinition());
        var color = M.Color.FromRgb((byte)(set.Color >> 16), (byte)(set.Color >> 8), (byte)set.Color);
        var chip = new C.Border
        {
            Width = 32,
            Height = 32,
            CornerRadius = new W.CornerRadius(8),
            Margin = new W.Thickness(0, 0, 12, 0),
            Background = new M.LinearGradientBrush(color, M.Color.FromArgb(140, color.R, color.G, color.B), 90),
            BorderBrush = new M.SolidColorBrush(M.Color.FromArgb(70, 255, 255, 255)),
            BorderThickness = new W.Thickness(1.5),
            Child = new C.TextBlock { Text = "+", FontSize = 25, FontWeight = W.FontWeights.Light, Foreground = Brush("#756D65"), HorizontalAlignment = W.HorizontalAlignment.Center, VerticalAlignment = W.VerticalAlignment.Center, Margin = new W.Thickness(0, -3, 0, 0) }
        };
        content.Children.Add(chip);
        var copy = new C.StackPanel { VerticalAlignment = W.VerticalAlignment.Center };
        copy.Children.Add(new C.TextBlock { Text = set.Kind, Foreground = Brush("#818789"), FontSize = 10, Margin = new W.Thickness(0, 0, 0, 4) });
        copy.Children.Add(new C.TextBlock { Text = set.Name, FontWeight = W.FontWeights.SemiBold, FontSize = 12, TextTrimming = W.TextTrimming.CharacterEllipsis, ToolTip = set.Name });
        C.Grid.SetColumn(copy, 1);
        content.Children.Add(copy);
        select.Content = content;
        select.Click += (_, _) => { if (!refreshing) model.Update(model.Settings with { SwitchSet = set.Slug }); };
        card.Children.Add(select);
        var play = new C.Button { Width = 28, Height = 28, Padding = new W.Thickness(0), HorizontalAlignment = W.HorizontalAlignment.Right, VerticalAlignment = W.VerticalAlignment.Center, Margin = new W.Thickness(0, 0, 14, 0), Content = PlayGlyph(), ToolTip = "Preview " + set.Name };
        Automation.SetName(play, "Preview " + set.Name);
        play.Click += (_, _) =>
        {
            if (model.Settings.SwitchSet != set.Slug) model.Update(model.Settings with { SwitchSet = set.Slug });
            model.TogglePreview();
        };
        card.Children.Add(play);
        cards.Add(set.Slug, select);
        previews.Add(set.Slug, play);
        SwitchCards.Children.Add(card);
    }

    private static W.UIElement PlayGlyph(bool playing = false, bool selected = false)
    {
        var grid = new C.Grid { Width = 25, Height = 25 };
        grid.Children.Add(new System.Windows.Shapes.Ellipse { Fill = Brush(selected ? "#18A4AC" : "#929697") });
        grid.Children.Add(new System.Windows.Shapes.Path
        {
            Data = M.Geometry.Parse(playing ? "M8,8 L17,8 L17,17 L8,17 Z" : "M10,7 L18,12.5 L10,18 Z"),
            Fill = M.Brushes.White
        });
        return grid;
    }

    private void AddToggle(C.Panel parent, string title, string detail, string key, string symbol, bool last = false)
    {
        var row = new C.Grid { Margin = new W.Thickness(0, 0, 0, last ? 0 : 15) };
        row.ColumnDefinitions.Add(new C.ColumnDefinition { Width = new W.GridLength(32) });
        row.ColumnDefinitions.Add(new C.ColumnDefinition());
        row.ColumnDefinitions.Add(new C.ColumnDefinition { Width = W.GridLength.Auto });
        row.Children.Add(new C.TextBlock { Text = symbol, FontFamily = new M.FontFamily("Segoe MDL2 Assets"), FontSize = 17, Foreground = Brush("#7C8486"), VerticalAlignment = W.VerticalAlignment.Center });
        var copy = new C.StackPanel { Margin = new W.Thickness(0, 0, 16, 0) };
        copy.Children.Add(new C.TextBlock { Text = title, FontWeight = W.FontWeights.Medium });
        copy.Children.Add(new C.TextBlock { Text = detail, Style = (W.Style)FindResource("Muted"), FontSize = 11, Margin = new W.Thickness(0, 5, 0, 0) });
        C.Grid.SetColumn(copy, 1);
        row.Children.Add(copy);
        var toggle = new C.CheckBox { Style = (W.Style)FindResource("Switch") };
        Automation.SetName(toggle, title);
        C.Grid.SetColumn(toggle, 2);
        row.Children.Add(toggle);
        toggle.Click += (_, _) =>
        {
            if (refreshing) return;
            if (key == "startup") model.SetStartup(toggle.IsChecked == true);
            else ChangeSettings(toggle, new W.RoutedEventArgs());
        };
        toggles.Add(key, toggle);
        parent.Children.Add(row);
        if (!last) parent.Children.Add(new C.Border { Height = 1, Background = Brush("#ECEFF0"), Margin = new W.Thickness(0, 0, 0, 15) });
    }

    public void RefreshSettings()
    {
        refreshing = true;
        try
        {
            var settings = model.Settings;
            EnabledToggle.IsChecked = settings.Enabled;
            VolumeSlider.Value = settings.Volume * 100;
            PitchSlider.Value = settings.Pitch;
            VolumeValue.Text = $"{settings.Volume * 100:0}%";
            PitchValue.Text = $"{settings.Pitch:+0.0;-0.0;0.0}";
            toggles["random"].IsChecked = settings.RandomPitch;
            toggles["stereo"].IsChecked = settings.Stereo;
            toggles["modifiers"].IsChecked = settings.ModifierSounds;
            toggles["mouse"].IsChecked = settings.MouseSounds;
            toggles["startup"].IsChecked = model.GetStartup();
            foreach (var (slug, card) in cards) card.IsChecked = slug == settings.SwitchSet;
            RefreshStatus();
        }
        finally { refreshing = false; }
    }

    public void RefreshStatus()
    {
        SidebarStatus.Text = model.Locked ? "Sound is muted" : !model.CanMonitor ? "Preview only" : model.Settings.Enabled ? "Sound is on" : "Sound is paused";
        StatusDot.Fill = Brush(model.Locked || !model.Settings.Enabled ? "#969D9F" : !model.CanMonitor ? "#E58C36" : "#18A4AC");
        ErrorText.Text = model.Error ?? "";
        ErrorPanel.Visibility = model.Error is null ? W.Visibility.Collapsed : W.Visibility.Visible;
        AccessTitle.Text = model.CanMonitor ? "Keyboard access is enabled" : "Enable keyboard access";
        AccessDetail.Text = model.CanMonitor ? "kbsd is ready to play in your other apps." : "Preview only. Input registration failed; check again to retry.";
        TodayCount.Text = model.Statistics.Today.ToString("N0");
        TotalCount.Text = model.Statistics.Total.ToString("N0");
        SoundPreview.Content = model.Previewing ? "Stop preview" : "Preview sound";
        SoundPreview.IsEnabled = !model.Locked;
        foreach (var (slug, play) in previews)
        {
            var selected = slug == model.Settings.SwitchSet;
            play.Content = PlayGlyph(model.Previewing && selected, selected);
            play.Background = M.Brushes.Transparent;
            play.IsEnabled = !model.Locked;
        }
    }

    private void Navigate(object sender, W.RoutedEventArgs args)
    {
        var index = int.Parse((string)((C.RadioButton)sender).Tag);
        var pages = new[] { SwitchesPage, SoundPage, GeneralPage, StatisticsPage };
        for (var i = 0; i < pages.Length; i++) pages[i].Visibility = i == index ? W.Visibility.Visible : W.Visibility.Collapsed;
        PageTitle.Text = new[] { "Switches", "Sound", "General", "Statistics" }[index];
        PageSubtitle.Text = new[] { "Find your favorite feeling.", "Make every keystroke your own.", "Quietly at home in your notification area.", "A little appreciation for all that typing." }[index];
    }

    private void ChangeSettings(object sender, W.RoutedEventArgs args)
    {
        if (refreshing) return;
        model.Update(model.Settings with
        {
            Enabled = EnabledToggle.IsChecked == true,
            RandomPitch = toggles["random"].IsChecked == true,
            Stereo = toggles["stereo"].IsChecked == true,
            ModifierSounds = toggles["modifiers"].IsChecked == true,
            MouseSounds = toggles["mouse"].IsChecked == true
        });
    }

    private void ChangeSlider(object sender, W.RoutedPropertyChangedEventArgs<double> args)
    {
        if (!refreshing) model.Update(model.Settings with { Volume = VolumeSlider.Value / 100, Pitch = PitchSlider.Value });
    }

    private void PreviewSelected(object sender, W.RoutedEventArgs args) => model.TogglePreview();
    private void Retry(object sender, W.RoutedEventArgs args) => model.Retry();
    private void FocusTypingTest(object sender, W.RoutedEventArgs args) { TypingTest.Focus(); TypingTest.Content = "Type anything. Enjoy the sound."; }
    private void TypingKeyDown(object sender, Input.KeyEventArgs args) { args.Handled = args.Key != Input.Key.Tab; }
    private void TypingKeyUp(object sender, Input.KeyEventArgs args) { args.Handled = args.Key != Input.Key.Tab; }
    private static M.SolidColorBrush Brush(string hex) => new((M.Color)M.ColorConverter.ConvertFromString(hex));
}
