// This file guarantees a DPI-aware native window around the vector-based settings surface.
using System.Windows.Forms.Integration;

namespace Kbsd.Desktop;

internal sealed class SettingsForm : Form
{
    private readonly SettingsContent content;
    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    internal bool AllowClose { get; set; }

    public SettingsForm(TrayApplication model)
    {
        SuspendLayout();
        AutoScaleDimensions = new SizeF(96, 96);
        AutoScaleMode = AutoScaleMode.Dpi;
        Text = "kbsd — Settings";
        BackColor = Color.White;
        ClientSize = new Size(820, 650);
        MinimumSize = new Size(760, 600);
        StartPosition = FormStartPosition.CenterScreen;
        content = new SettingsContent(model);
        Controls.Add(new ElementHost { Dock = DockStyle.Fill, Child = content });
        FormClosing += (_, args) =>
        {
            if (!AllowClose && args.CloseReason == CloseReason.UserClosing) { args.Cancel = true; Hide(); }
        };
        ResumeLayout(performLayout: true);
    }

    public void RefreshSettings() => content.RefreshSettings();
    public void RefreshStatus() => content.RefreshStatus();
}
