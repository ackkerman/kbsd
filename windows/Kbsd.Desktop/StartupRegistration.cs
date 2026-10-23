// This file guarantees that login startup changes occur only through an explicit user action.
using Microsoft.Win32;

namespace Kbsd.Desktop;

internal static class StartupRegistration
{
    private const string KeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private static string Command => $"\"{Environment.ProcessPath}\" --background";

    public static bool Enabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(KeyPath);
            return string.Equals(key?.GetValue("kbsd") as string, Command, StringComparison.OrdinalIgnoreCase);
        }
    }

    public static void Set(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(KeyPath, writable: true);
        if (enabled) key.SetValue("kbsd", Command);
        else key.DeleteValue("kbsd", throwOnMissingValue: false);
    }
}
