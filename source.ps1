Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. THE HTML GUI  qpwihgboq3buewgpqvepwbin
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
        <h2>Quicktool v5.5</h2>
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
# 2. THE MASTER LOGIC
# ==========================================
$browser.add_Navigating({
    param($s, $e)
    if ($e.Url.ToString() -like "cmd://*") {
        $e.Cancel = $true
        $cmd = $e.Url.ToString().Replace("cmd://", "").TrimEnd("/")
        
        $folder = "C:\Program Files\Securly\Classroom"
        $backupDir = "C:\Users\Public\Documents\SecurlyBackup"

        switch ($cmd) {
            "enable" {
                $pac = "https://www-filter.c2.securly.com"
                $hives = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings", 
                           "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings")
                foreach ($path in $hives) {
                    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
                    Set-ItemProperty -Path $path -Name "AutoConfigURL" -Value $pac -Type String
                    if ($path -like "HKLM*") { Set-ItemProperty -Path $path -Name "ProxySettingsPerUser" -Value 1 -Type DWord }
                    $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                    Set-ItemProperty -Path "$path\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary -ErrorAction SilentlyContinue
                }
                Write-Host "Filter Enabled." -ForegroundColor Green
            }
            "disable" {
                $hives = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings", 
                           "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings")
                foreach ($path in $hives) {
                    Remove-ItemProperty -Path $path -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                    $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                    Set-ItemProperty -Path "$path\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary -ErrorAction SilentlyContinue
                }
                Write-Host "Filter Disabled." -ForegroundColor Yellow
            }
            "lock" {
                Get-Service "Securly*" -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled
                Get-Service "Securly*" -ErrorAction SilentlyContinue | Stop-Service -Force
                Get-Process "Classroom", "Securly*", "SecurlyWindowsAgent" -ErrorAction SilentlyContinue | Stop-Process -Force
                if (Test-Path $folder) {
                    takeown /f "$folder" /a /r /d y | Out-Null
                    icacls "$folder" /reset /t /c /q | Out-Null
                    if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
                    if (Test-Path "$folder\Classroom.exe") { Move-Item "$folder\Classroom.exe" "$backupDir\Classroom.exe" -Force }
                    "DUMMY" | Out-File "$folder\Classroom.exe" -Force
                    icacls "$folder" /inheritance:r /t /c /q | Out-Null
                    icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
                }
                Write-Host "Locked and Moved." -ForegroundColor Red
            }
            "unlock" {
    $folder = "C:\Program Files\Securly\Classroom"
    $backup = "C:\Users\Public\Documents\SecurlyBackup\Classroom.exe"
    $target = "$folder\Classroom.exe"

    # 1. Force-open the folder
    takeown /f "$folder" /a /r /d y | Out-Null
    icacls "$folder" /reset /t /c /q | Out-Null
    icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null

    # 2. Kill any small 'Dummy' files
    Get-ChildItem $folder -Filter "*.exe" | Where-Object { $_.Length -lt 5000 } | Remove-Item -Force -ErrorAction SilentlyContinue

    # 3. Restore the real app
    if (Test-Path $backup) {
        Move-Item $backup $target -Force -ErrorAction SilentlyContinue
    }

    # 4. Final check - if the app exists, force it to run
    if (Test-Path $target) {
        Unblock-File $target -ErrorAction SilentlyContinue
        
        # Clean local lock-state
        if (Test-Path "C:\ProgramData\Securly") { Remove-Item "C:\ProgramData\Securly\*" -Recurse -Force -ErrorAction SilentlyContinue }
        
        # Restart the background watcher
        sc.exe config "SecurlyClassroomService" start= auto | Out-Null
        Start-Service "SecurlyClassroomService" -ErrorAction SilentlyContinue
        
        # The 'Start' command bypasses some PowerShell launch restrictions
        Start-Sleep -Seconds 2
        cmd /c "start `"`" `"$target`""
        Write-Host "Unlock attempted. Check your system tray." -ForegroundColor Green
    } else {
        Write-Host "Error: Real Classroom.exe not found in backup folder." -ForegroundColor Red
    }
}

        }
    }
})

$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
