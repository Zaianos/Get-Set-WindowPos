# Define path as needed
Write-Host $PSScriptRoot

$configDir = $PSScriptRoot
$configFile = "$configDir\windowConfig.json"

if (-not (Test-Path -Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    # Set the directory to hidden
    (Get-Item $configDir).Attributes = "Hidden" # Personal preference, remove this line at will.
}

function Get-WindowPositions {
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
        Write-Output "Window type defined successfully."
    } else {
        Write-Output "Window type already exists."
    }

    $runningApps = Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object Id, ProcessName, MainWindowTitle
    $selectedApps = $runningApps | Out-GridView -PassThru -Title "Select Applications to Save Window Positions"

    $windows = @()

    foreach ($app in $selectedApps) {
        $handle = (Get-Process -Id $app.Id).MainWindowHandle
        if ($handle -ne [IntPtr]::Zero) {
            $rect = New-Object -TypeName "Window+RECT"
            [Window]::GetWindowRect($handle, [ref]$rect) | Out-Null
            $windowInfo = [PSCustomObject]@{
                ProcessName = $app.ProcessName
                WindowTitle = $app.MainWindowTitle
                Handle      = $handle.ToInt64()
                Left        = $rect.Left
                Top         = $rect.Top
                Width       = $rect.Right - $rect.Left
                Height      = $rect.Bottom - $rect.Top
            }
            $windows += $windowInfo
        } else {
            Write-Warning "No main window handle found for process $($app.Id) ($($app.ProcessName))."
        }
    }

    return $windows
}

$windowPositions = Get-WindowPositions

if ($windowPositions) {
    $windowPositions | ConvertTo-Json | Set-Content -Path $configFile
    Write-Output "Window positions saved to $configFile"
} else {
    Write-Warning "No windows found for the specified processes."
}
