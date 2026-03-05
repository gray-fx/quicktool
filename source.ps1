Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. THE HTML GUI CHECK OCTO 645789087654345678909876543456789
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
    $backupPath = "C:\Windows\Temp\Classroom_backup.exe"

    # 1. Kill everything and set Service to Disabled
    Get-Process "Classroom", "Securly*", "SecurlyWindowsAgent" -ErrorAction SilentlyContinue | Stop-Process -Force
    sc.exe config "SecurlyClassroomService" start= disabled # Using sc.exe is more forceful
    Stop-Service "SecurlyClassroomService" -Force -ErrorAction SilentlyContinue

    if (Test-Path $folder) {
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null

        # 2. MOVE the exe out of the folder so the watchdog can't find it
        if (Test-Path $exePath) { Move-Item $exePath $backupPath -Force }

        # 3. Create a DUMMY text file named Classroom.exe to confuse the system
        "" | Out-File $exePath -Force

        # 4. Hard Deny
        icacls "$folder" /inheritance:r /t /c /q | Out-Null
        icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "SYSTEM:(OI)(CI)F" /t /c /q | Out-Null
        Write-Host "Classroom Deep-Locked & Moved." -ForegroundColor Red
    }
}
"unlock" {
    $folder = "C:\Program Files\Securly\Classroom"
    $exePath = "$folder\Classroom.exe"
    $backupPath = "C:\Windows\Temp\Classroom_backup.exe"

    if (Test-Path $folder) {
        # 1. Restore folder access
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null

        # 2. DELETE the dummy and RESTORE the real exe
        if (Test-Path $exePath) { Remove-Item $exePath -Force }
        if (Test-Path $backupPath) { Move-Item $backupPath $exePath -Force }

        # 3. Wipe Cache and Re-enable Service
        if (Test-Path "C:\ProgramData\Securly") { Remove-Item "C:\ProgramData\Securly\*" -Recurse -Force -ErrorAction SilentlyContinue }
        sc.exe config "SecurlyClassroomService" start= auto
        Start-Service "SecurlyClassroomService" -ErrorAction SilentlyContinue

        # 4. Launch
        Start-Sleep -Seconds 4
        if (Test-Path $exePath) { Start-Process $exePath -WorkingDirectory $folder }
        Write-Host "Classroom Fully Restored." -ForegroundColor Green
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
