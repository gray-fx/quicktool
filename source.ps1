Add-Type -AssemblyName System.Windows.Forms, System.Drawing
# Bansgvbew kidsugb voewds
# 1. FIND YOUR ACTUAL USER SID (Fixes Admin elevation issues)
$userSID = (Get-Process explorer | Select-Object -First 1 -ExpandProperty Id | Get-WmiObject -Query "Select * from Win32_Process Where ProcessId = $($_)" | ForEach-Object { $_.GetOwner().User } | ForEach-Object { (New-Object System.Security.Principal.NTAccount($_)).Translate([System.Security.Principal.SecurityIdentifier]).Value })
$regPath = "Registry::HKEY_USERS\$userSID\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$folder = "C:\Program Files\Securly\Classroom"

# 2. THE FORCE REFRESH FUNCTION
function Refresh-WinInet {
    $sig = '[DllImport("wininet.dll", SetLastError = true)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
    $type = Add-Type -MemberDefinition $sig -Name WinInet -Namespace Win32 -PassThru -ErrorAction SilentlyContinue
    $type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    $type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
}

# 3. GUI CODE
$html = @"
<!DOCTYPE html>
<html>
<head><meta http-equiv='X-UA-Compatible' content='IE=edge'>
<style>
    body { background: #1e1e1e; color: white; font-family: 'Segoe UI'; display: flex; flex-direction: column; align-items: center; padding: 20px; }
    button { width: 300px; height: 45px; margin: 10px; cursor: pointer; background: #333; color: white; border: 1px solid #555; }
    button:hover { background: #444; }
</style>
</head>
<body>
    <h2>Quicktool v3.3</h2>
    <button onclick="window.location='cmd://enable'">ENABLE WEB FILTER</button>
    <button onclick="window.location='cmd://disable'">DISABLE WEB FILTER</button>
    <button onclick="window.location='cmd://lock'">LOCK CLASSROOM</button>
    <button onclick="window.location='cmd://unlock'">UNLOCK CLASSROOM</button>
</body>
</html>
"@

$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool"; $form.Size = New-Object System.Drawing.Size(400, 450); $form.Topmost = $true
$browser = New-Object System.Windows.Forms.WebBrowser; $browser.Dock = "Fill"; $browser.ScriptErrorsSuppressed = $true

$browser.add_Navigating({
    param($s, $e)
    if ($e.Url.ToString() -like "cmd://*") {
        $e.Cancel = $true
        $cmd = $e.Url.ToString().Replace("cmd://", "").TrimEnd("/")
        
        switch ($cmd) {
            "enable" {
                # Update Text URL
                $pac = "https://www-filter.c2.securly.com"
                Set-ItemProperty -Path $regPath -Name "AutoConfigURL" -Value $pac -Type String
                # Update Binary (05 = Enabled)
                $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path "$regPath\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary
                Refresh-WinInet
            }
            "disable" {
                Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                # Update Binary (01 = Disabled)
                $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path "$regPath\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary
                Refresh-WinInet
            }
            "lock" {
                Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
                takeown /f "$folder" /a /r /d y | Out-Null
                icacls "$folder" /inheritance:r /deny Everyone:F /t /q | Out-Null
            }
            "unlock" {
                icacls "$folder" /remove:deny Everyone /t /q | Out-Null
                icacls "$folder" /grant Everyone:F /t /q | Out-Null
                if (Test-Path "$folder\Classroom.exe") { Start-Process "$folder\Classroom.exe" -WorkingDirectory $folder }
            }
        }
    }
})

$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
