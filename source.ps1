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
    $backupDir = "C:\Users\Public\Documents\SecurlyBackup" # Using a safer backup path

    # 1. Kill and Disable Service
    Get-Process "Classroom", "Securly*", "SecurlyWindowsAgent" -ErrorAction SilentlyContinue | Stop-Process -Force
    sc.exe config "SecurlyClassroomService" start= disabled | Out-Null
    Stop-Service "SecurlyClassroomService" -Force -ErrorAction SilentlyContinue

    if (Test-Path $folder) {
        # 2. Permissions & Move
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        
        if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force }
        if (Test-Path $exePath) { Move-Item $exePath "$backupDir\Classroom.exe" -Force }

        # 3. Create Dummy (Forces Watchdog to see a 'file' but not an 'app')
        "DUMMY" | Out-File $exePath -Force

        # 4. Hard Lock
        icacls "$folder" /inheritance:r /t /c /q | Out-Null
        icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "SYSTEM:(OI)(CI)F" /t /c /q | Out-Null
        Write-Host "Locked and Moved." -ForegroundColor Red
    }
}
"unlock" {
    $folder = "C:\Program Files\Securly\Classroom"
    $exePath = "$folder\Classroom.exe"
    $backupDir = "C:\Users\Public\Documents\SecurlyBackup"

    if (Test-Path $folder) {
        # 1. Open the doors
        takeown /f "$folder" /a /r /d y | Out-Null
        icacls "$folder" /reset /t /c /q | Out-Null
        icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null

        # 2. DELETE DUMMY & RESTORE REAL EXE
        if (Test-Path $exePath) { Remove-Item $exePath -Force -ErrorAction SilentlyContinue }
        if (Test-Path "$backupDir\Classroom.exe") { 
            Move-Item "$backupDir\Classroom.exe" $exePath -Force 
        }

        # 3. Clear Cache & Start Service
        if (Test-Path "C:\ProgramData\Securly") { Remove-Item "C:\ProgramData\Securly\*" -Recurse -Force -ErrorAction SilentlyContinue }
        sc.exe config "SecurlyClassroomService" start= auto | Out-Null
        Start-Service "SecurlyClassroomService" -ErrorAction SilentlyContinue

        # 4. Launch (Increased sleep to ensure file system is ready)
        Start-Sleep -Seconds 5
        if (Test-Path $exePath) { 
            Start-Process $exePath -WorkingDirectory $folder 
        }
        Write-Host "Unlocked and Restored." -ForegroundColor Green
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
