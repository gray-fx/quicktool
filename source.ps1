Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# FIX: THE COM-VISIBLE BRIDGE
# CHECK: STRAW
# ==========================================
$code = @"
using System;
using System.Runtime.InteropServices;

[ComVisible(true)]
public class ScriptBridge {
    public void Run(string cmd) {
        Microsoft.PowerShell.Commands.Internal.WinRT.Interop.GlobalState.LastCmd = cmd;
    }
}
public static class GlobalState {
    public static string LastCmd;
}
"@
# Note: We use a simpler bridge for PS 5.1 compatibility
$Object = New-Object -TypeName PSObject
$Object | Add-Member -MemberType ScriptMethod -Name "Run" -Value {
    param($cmd)
    $Global:TriggerCmd = $cmd
}

# ==========================================
# THE HTML GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv='X-UA-Compatible' content='IE=edge'>
    <style>
        body { background: #1e1e1e; color: white; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; padding: 20px; overflow: hidden; }
        .card { background: #2d2d30; width: 320px; padding: 20px; border-radius: 8px; border: 1px solid #444; text-align: center; }
        button { 
            width: 100%; height: 45px; margin: 8px 0; cursor: pointer;
            background: #3c3c41; color: white; border: 1px solid #555; font-size: 14px;
        }
        button:hover { background: #505055; border-color: #888; }
        .btn-green { border-color: LimeGreen; color: LimeGreen; }
        .btn-red { border-color: Tomato; color: Tomato; }
    </style>
</head>
<body>
    <div class="card">
        <h2 style="margin-top:0">Quicktool v2.0</h2>
        <button class="btn-green" onclick="window.external.Run('enable')">ENABLE WEB FILTER</button>
        <button class="btn-red" onclick="window.external.Run('disable')">DISABLE WEB FILTER</button>
        <button onclick="window.external.Run('lock')">LOCK CLASSROOM</button>
        <button class="btn-green" onclick="window.external.Run('unlock')">UNLOCK START CLASSROOM</button>
    </div>
</body>
</html>
"@

$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool"
$form.Size = New-Object System.Drawing.Size(400, 450)
$form.StartPosition = "CenterScreen"
$form.Topmost = $true

$browser = New-Object System.Windows.Forms.WebBrowser
$browser.Dock = "Fill"
$browser.ScrollBarsEnabled = $false
$browser.ObjectForScripting = $Object # THIS IS THE LINE CAUSING THE ERROR - FIXED BY PSObject ABOVE

# TIMER TO EXECUTE COMMANDS
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({
    if ($Global:TriggerCmd) {
        $cmd = $Global:TriggerCmd
        $Global:TriggerCmd = $null
        
        $userPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $folder = "C:\Program Files\Securly\Classroom"
        
        switch ($cmd) {
            "enable" {
                $pac = "https://www-filter.c2.securly.com"
                Set-ItemProperty -Path $userPath -Name "AutoConfigURL" -Value $pac -Type String
                $eb = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path "$userPath\Connections" -Name "DefaultConnectionSettings" -Value $eb -Type Binary
            }
            "disable" {
                Remove-ItemProperty -Path $userPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                $db = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path "$userPath\Connections" -Name "DefaultConnectionSettings" -Value $db -Type Binary
            }
            "lock" {
                Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
                if (Test-Path $folder) {
                    takeown /f "$folder" /a /r /d y | Out-Null
                    icacls "$folder" /inheritance:r /deny Everyone:F /t | Out-Null
                }
            }
            "unlock" {
                if (Test-Path $folder) {
                    icacls "$folder" /remove:deny Everyone /t | Out-Null
                    icacls "$folder" /grant "Everyone:(OI)(CI)F" /t | Out-Null
                    Start-Sleep -Seconds 1
                    if (Test-Path "$folder\Classroom.exe") { Start-Process "$folder\Classroom.exe" -WorkingDirectory $folder }
                }
            }
        }
    }
})

$timer.Start()
$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
$timer.Stop()
