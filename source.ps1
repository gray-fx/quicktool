Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. THE HTML GUI CHECK OCTO  3y2587927386579327
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
    $backupDir = "C:\Users\Public\Documents\SecurlyBackup"

    # 1. Stop Service and Processes
    Get-Service "Securly*" -ErrorAction SilentlyContinue | Stop-Service -Force
    sc.exe config "SecurlyClassroomService" start= disabled | Out-Null
    Get-Process "Classroom", "Securly*", "SecurlyWindowsAgent" -ErrorAction SilentlyContinue | Stop-Process -Force

    if (Test-Path $folder) {
        # 2. Open permissions to allow file move
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        
        # 3. Securely move the EXE
        if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
        if (Test-Path $exePath) { Move-Item $exePath "$backupDir\Classroom.exe" -Force -ErrorAction SilentlyContinue }

        # 4. Create the Dummy
        "DUMMY" | Out-File $exePath -Force

        # 5. Lock it down
        icacls "$folder" /inheritance:r /t /c /q | Out-Null
        icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "SYSTEM:(OI)(CI)F" /t /c /q | Out-Null
        Write-Host "Locked Successfully." -ForegroundColor Red
    }
}
"unlock" {
    $folder = "C:\Program Files\Securly\Classroom"
    $exePath = "$folder\Classroom.exe"
    $backupDir = "C:\Users\Public\Documents\SecurlyBackup"

    if (Test-Path $folder) {
        # 1. Unlock folder
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null

        # 2. DELETE DUMMY & VERIFY RESTORATION
        if (Test-Path $exePath) { Remove-Item $exePath -Force -Recurse -ErrorAction SilentlyContinue }
        
        # Wait until dummy is confirmed gone
        while (Test-Path $exePath) { Start-Sleep -Milliseconds 200 }

        if (Test-Path "$backupDir\Classroom.exe") { 
            Move-Item "$backupDir\Classroom.exe" $exePath -Force 
        }

        # 3. Clean Cache and Re-enable Service
        if (Test-Path "C:\ProgramData\Securly") { Remove-Item "C:\ProgramData\Securly\*" -Recurse -Force -ErrorAction SilentlyContinue }
        sc.exe config "SecurlyClassroomService" start= auto | Out-Null
        Start-Service "SecurlyClassroomService" -ErrorAction SilentlyContinue

        # 4. LAUNCH (Verify file size to ensure it's not the dummy)
        $file = Get-Item $exePath -ErrorAction SilentlyContinue
        if ($file.Length -gt 1000) { # Ensure it's not the 'DUMMY' text file
            Start-Sleep -Seconds 3
            Start-Process $exePath -WorkingDirectory $folder -WindowStyle Normal
            Write-Host "Unlocked and Restored." -ForegroundColor Green
        } else {
            Write-Host "Restore Failed: Dummy file still present." -ForegroundColor Red
        }
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
