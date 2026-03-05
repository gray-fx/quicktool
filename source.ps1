Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. THE HTML GUI CHECK OCTO
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
    $folder = "C:\Program Files\Securly\Classroom"
    $exePath = "$folder\Classroom.exe"
    $tempExe = "$folder\win_system_service.exe"

    # 1. Kill all Securly processes and disable service
    Get-Process "Classroom", "Securly*", "LogSender", "node" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Service "Securly*" -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled
    Get-Service "Securly*" -ErrorAction SilentlyContinue | Stop-Service -Force
    
    if (Test-Path $folder) {
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        
        # 2. THE RENAMING TRICK: Hide the exe from the Watchdog
        if (Test-Path $exePath) { Rename-Item $exePath "win_system_service.exe" -Force }

        # 3. Apply Hard Deny to the entire folder
        icacls "$folder" /inheritance:r /t /c /q | Out-Null
        icacls "$folder" /grant "Administrators:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "SYSTEM:(OI)(CI)F" /t /c /q | Out-Null
        Write-Host "Classroom Renamed and Deep-Locked." -ForegroundColor Red
    }
}
"unlock" {
    $folder = "C:\Program Files\Securly\Classroom"
    $tempExe = "$folder\win_system_service.exe"
    $exePath = "$folder\Classroom.exe"

    if (Test-Path $folder) {
        # 1. Restore folder access
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null

        # 2. Restore the original name
        if (Test-Path $tempExe) { Rename-Item $tempExe "Classroom.exe" -Force }

        # 3. Clear session cache
        $appData = "C:\ProgramData\Securly"
        if (Test-Path $appData) { Remove-Item "$appData\*" -Recurse -Force -ErrorAction SilentlyContinue }

        # 4. Restart service and app
        Get-Service "Securly*" -ErrorAction SilentlyContinue | Set-Service -StartupType Automatic
        Get-Service "Securly*" -ErrorAction SilentlyContinue | Start-Service
        
        Start-Sleep -Seconds 3
        if (Test-Path $exePath) { Start-Process $exePath -WorkingDirectory $folder }
        Write-Host "Classroom Restored Successfully." -ForegroundColor Green
    }
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
