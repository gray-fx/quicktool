Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. THE HTML GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html>
<head><meta http-equiv='X-UA-Compatible' content='IE=edge'>
<style>
    body { background: #1e1e1e; color: white; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; padding: 20px; }
    .card { background: #2d2d30; width: 320px; padding: 20px; border-radius: 8px; border: 1px solid #444; text-align: center; }
    button { width: 100%; height: 45px; margin: 8px 0; cursor: pointer; background: #3c3c41; color: white; border: 1px solid #555; font-size: 14px; }
    button:hover { background: #505055; border-color: #888; }
    .btn-red { border-color: Tomato; color: Tomato; }
    .btn-green { border-color: LimeGreen; color: LimeGreen; }
</style>
</head>
<body>
    <div class="card">
        <h2>Quicktool v5.0</h2>
        <button class="btn-green" onclick="window.location='cmd://enable'">ENABLE WEB FILTER</button>
        <button class="btn-red" onclick="window.location='cmd://disable'">DISABLE WEB FILTER</button>
        <button class="btn-red" onclick="window.location='cmd://lock'">LOCK CLASSROOM</button>
        <button class="btn-green" onclick="window.location='cmd://unlock'">UNLOCK CLASSROOM</button>
    </div>
</body>
</html>
"@

$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool"; $form.Size = New-Object System.Drawing.Size(400, 480); $form.Topmost = $true
$browser = New-Object System.Windows.Forms.WebBrowser; $browser.Dock = "Fill"; $browser.ScriptErrorsSuppressed = $true

# ==========================================
# 2. FUNCTIONAL LOGIC
# ==========================================
$browser.add_Navigating({
    param($s, $e)
    if ($e.Url.ToString() -like "cmd://*") {
        $e.Cancel = $true
        $cmd = $e.Url.ToString().Replace("cmd://", "").TrimEnd("/")
        
        $folder = "C:\Program Files\Securly\Classroom"
        $appData = "C:\ProgramData\Securly"

        switch ($cmd) {
            "lock" {
                # 1. Stop and DISABLE the service so it can't restart itself
                Get-Service "Securly*" -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled
                Get-Service "Securly*" -ErrorAction SilentlyContinue | Stop-Service -Force
                
                # 2. Kill all active processes
                Get-Process "Classroom", "Securly*", "SecurlyWindowsAgent" -ErrorAction SilentlyContinue | Stop-Process -Force
                
                # 3. Hard lock the folder
                if (Test-Path $folder) {
                    takeown /f "$folder" /a /r /d y | Out-Null
                    icacls "$folder" /inheritance:r /t /c /q | Out-Null
                    icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
                }
                Write-Host "Service Disabled & Folder Locked." -ForegroundColor Red
            }
            "unlock" {
                # 1. Restore folder access
                if (Test-Path $folder) {
                    takeown /f "$folder" /a /r /d y | Out-Null
                    icacls "$folder" /reset /t /c /q | Out-Null
                    icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null
                }
                
                # 2. Wipe the local "Block" state files
                if (Test-Path $appData) { Remove-Item "$appData\*" -Recurse -Force -ErrorAction SilentlyContinue }
                
                # 3. Re-enable and Start the service
                Get-Service "Securly*" -ErrorAction SilentlyContinue | Set-Service -StartupType Automatic
                Get-Service "Securly*" -ErrorAction SilentlyContinue | Start-Service
                
                # 4. Launch with a delay to let the Service warm up
                Start-Sleep -Seconds 4
                if (Test-Path "$folder\Classroom.exe") { 
                    Start-Process "$folder\Classroom.exe" -WorkingDirectory $folder
                }
                Write-Host "Service Restored & App Launched." -ForegroundColor Green
            }
            "enable" {
                $policyPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
                if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
                Set-ItemProperty -Path $policyPath -Name "ProxySettingsPerUser" -Value 1 -Type DWord
                Set-ItemProperty -Path $policyPath -Name "AutoConfigURL" -Value "https://www-filter.c2.securly.com" -Type String
            }
            "disable" {
                $policyPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
                Remove-ItemProperty -Path $policyPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
            }
        }
    }
})

$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
