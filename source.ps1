Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ==========================================
# 1. GPO OVERRIDE PATHS (The Fix) g2h830gb0v
# ==========================================
$policyPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
$userPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Ensure the Policy Key exists (Prevents 'Path not found' crash)
if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }

# ==========================================
# 2. THE HTML GUI
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
</style>
</head>
<body>
    <div class="card">
        <h2>Quicktool v4.0 (GPO Bypass)</h2>
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

$browser.add_Navigating({
    param($s, $e)
    if ($e.Url.ToString() -like "cmd://*") {
        $e.Cancel = $true
        $cmd = $e.Url.ToString().Replace("cmd://", "").TrimEnd("/")
        
        switch ($cmd) {
            "enable" {
                $pac = "https://www-filter.c2.securly.com"
                # FORCE PER-USER SETTINGS (Tells GPO to stop forcing per-machine)
                Set-ItemProperty -Path $policyPath -Name "ProxySettingsPerUser" -Value 1 -Type DWord
                # Apply PAC to both User and Policy hives
                Set-ItemProperty -Path $policyPath -Name "AutoConfigURL" -Value $pac -Type String
                Set-ItemProperty -Path $userPath -Name "AutoConfigURL" -Value $pac -Type String
                Write-Host "GPO Overridden: Filter Enabled." -ForegroundColor Green
            }
            "disable" {
                # Turn off the override and clear settings
                Set-ItemProperty -Path $policyPath -Name "ProxySettingsPerUser" -Value 1 -Type DWord
                Remove-ItemProperty -Path $policyPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $userPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                Write-Host "Filter Disabled." -ForegroundColor Yellow
            }
           "lock" {
    $folder = "C:\Program Files\Securly\Classroom"
    # 1. Kill the process
    Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
    
    if (Test-Path $folder) {
        # 2. Take ownership as Administrators (The Master Key)
        takeown /f "$folder" /a /r /d y | Out-Null
        
        # 3. Strip all inherited permissions
        icacls "$folder" /inheritance:r /t /c /q | Out-Null
        
        # 4. Apply the Hard Deny (OI=Object Inherit, CI=Container Inherit)
        # We MUST grant Administrators full control first so the script can still see the folder
        icacls "$folder" /grant "Administrators:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        icacls "$folder" /deny "SYSTEM:(OI)(CI)F" /t /c /q | Out-Null
        
        Write-Host "Classroom Deep-Locked." -ForegroundColor Red
    }
}
"unlock" {
    $folder = "C:\Program Files\Securly\Classroom"
    if (Test-Path $folder) {
        # 1. Take ownership back again just in case
        takeown /f "$folder" /a /r /d y | Out-Null
        
        # 2. THE FIX: Reset the ACL to default (Strips the Deny rules completely)
        icacls "$folder" /reset /t /c /q | Out-Null
        
        # 3. Grant Everyone access back
        icacls "$folder" /grant "Everyone:(OI)(CI)F" /t /c /q | Out-Null
        
        # 4. Restart the app
        Start-Sleep -Seconds 2
        if (Test-Path "$folder\Classroom.exe") { 
            # Use -WindowStyle Normal to ensure it pops up
            Start-Process "$folder\Classroom.exe" -WorkingDirectory $folder -WindowStyle Normal
        }
        Write-Host "Classroom Restored." -ForegroundColor Cyan
    }
}


        }
    }
})

$browser.DocumentText = $html
$form.Controls.Add($browser)
[void]$form.ShowDialog()
