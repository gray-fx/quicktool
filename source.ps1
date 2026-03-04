# ==========================================
# 1. LOAD STANDARD WINDOWS FORMS
# ==========================================
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 2. THE HTML & CSS GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv='X-UA-Compatible' content='IE=edge'>
    <style>
        body { background: #1e1e1e; color: white; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; padding: 20px; overflow: hidden; }
        .card { background: #2d2d30; width: 300px; padding: 20px; border-radius: 8px; border: 1px solid #444; text-align: center; }
        button { 
            width: 100%; height: 45px; margin: 8px 0; cursor: pointer;
            background: #3c3c41; color: white; border: 1px solid #555; font-size: 14px;
        }
        button:hover { background: #505055; border-color: #888; }
        .btn-green { border-color: LimeGreen; color: LimeGreen; }
        .btn-red { border-color: Tomato; color: Tomato; }
        #status { font-size: 12px; color: #888; margin-top: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <h2 style="margin-top:0">Quicktool v1.5</h2>
        <button class="btn-green" onclick="window.external.Run('enable')">ENABLE WEB FILTER</button>
        <button class="btn-red" onclick="window.external.Run('disable')">DISABLE WEB FILTER</button>
        <button onclick="window.external.Run('lock')">LOCK CLASSROOM</button>
        <button class="btn-green" onclick="window.external.Run('unlock')">UNLOCK START</button>
        <div id="status">Ready.</div>
    </div>
</body>
</html>
"@

# ==========================================
# 3. CREATE THE WINDOW
# ==========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool"
$form.Size = New-Object System.Drawing.Size(400, 450)
$form.StartPosition = "CenterScreen"
$form.Topmost = $true

$browser = New-Object System.Windows.Forms.WebBrowser
$browser.Dock = "Fill"
$browser.ScrollBarsEnabled = $false
$browser.IsWebBrowserContextMenuEnabled = $false
$browser.AllowWebBrowserDrop = $false

# THE BRIDGE: This lets the HTML buttons talk to PowerShell
$Object = New-Object -TypeName PSObject
$Object | Add-Member -MemberType ScriptMethod -Name "Run" -Value {
    param($cmd)
    $userSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $classroomFolder = "C:\Program Files\Securly\Classroom"
    
    switch ($cmd) {
        "enable" {
            $url = "https://www-filter.c2.securly.com"
            Set-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -Value $url -Type String
            $eb = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $eb -Type Binary
        }
        "disable" {
            Remove-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
            $db = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $db -Type Binary
        }
        "lock" {
            Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
            icacls "$classroomFolder" /inheritance:r /deny Everyone:F /t | Out-Null
        }
        "unlock" {
            icacls "$classroomFolder" /remove:deny Everyone /t | Out-Null
            icacls "$classroomFolder" /grant "Everyone:(OI)(CI)F" /t | Out-Null
        }
    }
}

$browser.ObjectForScripting = $Object
$browser.DocumentText = $html
$form.Controls.Add($browser)

[void]$form.ShowDialog()
