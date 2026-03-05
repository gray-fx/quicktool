Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. REFRESH LOGIC (Pre-Loaded) yi529htg7hbv7 83eg9v89 rwnvw
# ==========================================
$sig = '[DllImport("wininet.dll", SetLastError = true)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
if (-not ([PowerShell].Assembly.GetType('Win32.WinInet'))) {
    Add-Type -MemberDefinition $sig -Name WinInet -Namespace Win32 -ErrorAction SilentlyContinue
}

# ==========================================
# 2. THE HTML GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html>
<head><meta http-equiv='X-UA-Compatible' content='IE=edge'>
<style>
    body { background: #1e1e1e; color: white; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; padding: 20px; overflow: hidden; }
    .card { background: #2d2d30; width: 320px; padding: 20px; border-radius: 8px; border: 1px solid #444; text-align: center; }
    button { width: 100%; height: 45px; margin: 8px 0; cursor: pointer; background: #3c3c41; color: white; border: 1px solid #555; font-size: 14px; }
    button:hover { background: #505055; border-color: #888; }
</style>
</head>
<body>
    <div class="card">
        <h2 style="margin-top:0">Quicktool v3.4</h2>
        <button onclick="window.location='cmd://enable'">ENABLE WEB FILTER</button>
        <button onclick="window.location='cmd://disable'">DISABLE WEB FILTER</button>
        <button onclick="window.location='cmd://lock'">LOCK CLASSROOM</button>
        <button onclick="window.location='cmd://unlock'">UNLOCK CLASSROOM</button>
    </div>
</body>
</html>
"@

$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool"; $form.Size = New-Object System.Drawing.Size(400, 450); $form.Topmost = $true
$browser = New-Object System.Windows.Forms.WebBrowser; $browser.Dock = "Fill"; $browser.ScriptErrorsSuppressed = $true

# ==========================================
# 3. FUNCTIONAL LOGIC (The Fixed Version)
# ==========================================
$browser.add_Navigating({
    param($s, $e)
    if ($e.Url.ToString() -like "cmd://*") {
        $e.Cancel = $true
        $cmd = $e.Url.ToString().Replace("cmd://", "").TrimEnd("/")
        
        # Using HKCU directly as it's the most stable path for Proxy settings
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $conPath = "$regPath\Connections"
        $folder  = "C:\Program Files\Securly\Classroom"

        switch ($cmd) {
            "enable" {
                $pac = "https://www-filter.c2.securly.com"
                Set-ItemProperty -Path $regPath -Name "AutoConfigURL" -Value $pac -Type String
                Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value 0 -Type DWord
                
                # Binary '05' is the mandatory bit for the checkbox
                $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path $conPath -Name "DefaultConnectionSettings" -Value $bin -Type Binary
                [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
            }
            "disable" {
                Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                # Binary '01' unchecks all boxes
                $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path $conPath -Name "DefaultConnectionSettings" -Value $bin -Type Binary
                [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
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
