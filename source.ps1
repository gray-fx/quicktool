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
    $exeName = "Classroom.exe"
    $targetPath = "$folder\$exeName"
    
    # 1. KILL DUMMIES AND UNLOCK FOLDER
    takeown /f "$folder" /a /r /d y | Out-Null
    icacls "$folder" /reset /t /c /q | Out-Null
    icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null
    
    # Delete any 0-byte or 'DUMMY' files currently in the folder
    Get-ChildItem $folder -Filter "*.exe" | Where-Object { $_.Length -lt 5000 } | Remove-Item -Force

    # 2. SEARCH & RESCUE: Find where the real EXE is hiding
    $searchPaths = @(
        "C:\Windows\Temp\Classroom_backup.exe",
        "C:\Users\Public\Documents\SecurlyBackup\Classroom.exe",
        "$folder\win_system_service.exe",
        "C:\ProgramData\Securly\Classroom.exe"
    )

    $found = $false
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            Write-Host "Found real app at: $path" -ForegroundColor Cyan
            Move-Item $path $targetPath -Force
            $found = $true
            break
        }
    }

    # 3. EMERGENCY SCAN: If still not found, search the whole drive (limited)
    if (-not $found) {
        Write-Host "Performing emergency scan..." -ForegroundColor Yellow
        $emergency = Get-ChildItem "C:\Program Files" -Recurse -Filter "Classroom.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($emergency) { 
            Copy-Item $emergency.FullName $targetPath -Force
            $found = $true
        }
    }

    # 4. FINAL RESTORE
    if ($found) {
        Unblock-File $targetPath
        if (Test-Path "C:\ProgramData\Securly") { Remove-Item "C:\ProgramData\Securly\*" -Recurse -Force -ErrorAction SilentlyContinue }
        
        sc.exe config "SecurlyClassroomService" start= auto | Out-Null
        Start-Service "SecurlyClassroomService" -ErrorAction SilentlyContinue
        
        Start-Sleep -Seconds 3
        & $targetPath
        Write-Host "Restored and Launched." -ForegroundColor Green
    } else {
        Write-Host "CRITICAL: Could not find the real Classroom.exe anywhere." -ForegroundColor Red
    }
}

}


            "enable" {
    $pac = "https://www-filter.c2.securly.com"
    $hives = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings", 
               "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings")

    foreach ($path in $hives) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "AutoConfigURL" -Value $pac -Type String
        
        # Override GPO: Force User settings
        if ($path -like "HKLM*") { Set-ItemProperty -Path $path -Name "ProxySettingsPerUser" -Value 1 -Type DWord }

        # Binary Force: 05 enables, 01 disables checkbox
        $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
        Set-ItemProperty -Path "$path\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary -ErrorAction SilentlyContinue
    }
    [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
}
"disable" {
    $hives = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings", 
               "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings")
    foreach ($path in $hives) {
        Remove-ItemProperty -Path $path -Name "AutoConfigURL" -ErrorAction SilentlyContinue
        $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
        Set-ItemProperty -Path "$path\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary -ErrorAction SilentlyContinue
    }
    [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
}

        }
    }
})

$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
