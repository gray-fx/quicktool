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
            $folder = "C:\Program Files\Securly\Classroom"
            $versionFolder = "$folder\1.3.1.3"
            $exePath = "$versionFolder\Classroom.exe"
            $backupDir = "C:\Users\Public\Documents\SecurlyBackup"
        
            # 1. THE PURGE: Kill every possible Securly process
            $targets = "Classroom*", "Securly*", "SlingshotApp", "LogSender", "ClassroomNativeHost"
            Get-Process $targets -ErrorAction SilentlyContinue | Stop-Process -Force
            
            # Wait for processes to fully exit
            Start-Sleep -Seconds 2
        
            if (Test-Path $versionFolder) {
                takeown /f "$folder" /a /r /d y | Out-Null
                icacls "$folder" /reset /t /c /q | Out-Null
                
                if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
                
                # 2. MOVE THE REAL EXE
                if (Test-Path $exePath) { 
                    Move-Item $exePath "$backupDir\Classroom.exe" -Force -ErrorAction SilentlyContinue 
                }
        
                # 3. CREATE DUMMY
                "DUMMY" | Out-File $exePath -Force
        
                # 4. LOCK DOWN
                icacls "$folder" /inheritance:r /t /c /q | Out-Null
                icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
                Write-Host "Locked and Purged." -ForegroundColor Red
            }
        }
        "unlock" {
            $folder = "C:\Program Files\Securly\Classroom"
            $versionFolder = "$folder\1.3.1.3"
            $exePath = "$versionFolder\Classroom.exe"
            $backupDir = "C:\Users\Public\Documents\SecurlyBackup"
        
            # 1. KILL AGAIN (Ensures nothing grabbed the dummy)
            $targets = "Classroom*", "Securly*", "SlingshotApp", "LogSender", "ClassroomNativeHost"
            Get-Process $targets -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Seconds 1
        
            # 2. RESTORE PERMISSIONS
            takeown /f "$folder" /a /r /d y | Out-Null
            icacls "$folder" /reset /t /c /q | Out-Null
            icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        
            # 3. SWAP FILES
            if (Test-Path $exePath) { Remove-Item $exePath -Force -ErrorAction SilentlyContinue }
            # Small delay to let the file system release the lock
            Start-Sleep -Milliseconds 500
            
            if (Test-Path "$backupDir\Classroom.exe") { 
                Move-Item "$backupDir\Classroom.exe" $exePath -Force 
            }
        
            # 4. FINAL RESTORE & LAUNCH
            if (Test-Path $exePath) {
                Unblock-File $exePath
                if (Test-Path "C:\ProgramData\Securly") { 
                    Remove-Item "C:\ProgramData\Securly\*" -Recurse -Force -ErrorAction SilentlyContinue 
                }
                Start-Sleep -Seconds 2
                # Use Start-Process with high priority to stay alive
                Start-Process $exePath -WorkingDirectory $versionFolder
                Write-Host "Classroom Fully Restored." -ForegroundColor Green
            }
        }

}


        }
    }
})

$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
