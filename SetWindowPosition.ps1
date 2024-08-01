# Define path as needed
Write-Host $PSScriptRoot

$configDir = $PSScriptRoot
$configFile = "$configDir\windowConfig.json"

if (-not (Test-Path -Path $configFile)) {
    Write-Error "Config file not found: $configFile"
    exit # exit if config not created by GetWindowPosition.ps1
}

# else load the config file
$config = Get-Content -Path $configFile | ConvertFrom-Json

if (-not ([type]::GetType("Window"))) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    
    public class Window {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
        
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
        
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }
    }
"@
    Write-Host "Window type defined successfully."
} else {
    Write-Host "Window type already exists."
}

function Set-Window {
    param (
        [IntPtr]$Handle,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    [Window]::MoveWindow($Handle, $X, $Y, $Width, $Height, $true)
}

# Get all running processes with a main window
$runningApps = Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object Id, ProcessName, MainWindowTitle, MainWindowHandle

foreach ($window in $config) {
    $matchedApp = $runningApps | Where-Object {
        $_.ProcessName -eq $window.ProcessName -and $_.MainWindowTitle -eq $window.WindowTitle
    }

    if ($matchedApp) {
        $handle = $matchedApp.MainWindowHandle
        Set-Window -Handle $handle -X $window.Left -Y $window.Top -Width $window.Width -Height $window.Height
        Write-Output "Moved window '$($window.WindowTitle)' to position X:$($window.Left) Y:$($window.Top)"
    } else {
        Write-Warning "No matching window found for process '$($window.ProcessName)' with title '$($window.WindowTitle)'."
    }
}
