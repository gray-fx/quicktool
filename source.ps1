# ==========================================
# REFRESH & HELPER FUNCTIONS NEW24156
# ==========================================
$signature = @"
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@
if (-not ([PowerShell].Assembly.GetType('Win32.WinInet'))) {
    Add-Type -MemberDefinition $signature -Name WinInet -Namespace Win32
}

function Refresh-Settings {
    [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
    Update-Status
}

# ==========================================
# REGISTRY & FILE PATHS
# ==========================================
$userSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$classroomFolder = "C:\Program Files\Securly\Classroom"
$classroomPath = "$classroomFolder\Classroom.exe"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# CREATE FORM
# ==========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool v1.2 (GitHub Live)"
$form.Size = New-Object System.Drawing.Size(420, 540)
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Topmost = $true

# Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(340, 60); $statusPanel.Location = New-Object System.Drawing.Point(30, 40); $statusPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48); $form.Controls.Add($statusPanel)

$filterStatus = New-Object System.Windows.Forms.Label; $filterStatus.Text = "Filter: --"; $filterStatus.Location = New-Object System.Drawing.Point(10, 10); $filterStatus.Size = New-Object System.Drawing.Size(320, 20); $statusPanel.Controls.Add($filterStatus)
$classroomStatus = New-Object System.Windows.Forms.Label; $classroomStatus.Text = "App: --"; $classroomStatus.Location = New-Object System.Drawing.Point(10, 32); $classroomStatus.Size = New-Object System.Drawing.Size(320, 20); $statusPanel.Controls.Add($classroomStatus)

function Update-Status {
    $current = (Get-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue).AutoConfigURL
    $filterStatus.Text = if ($current) { "● Securly Filter: ACTIVE" } else { "○ Securly Filter: DISABLED" }
    $filterStatus.ForeColor = if ($current) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::Tomato }
    
    $proc = Get-Process "Classroom" -ErrorAction SilentlyContinue
    $classroomStatus.Text = if ($proc) { "● Classroom App: RUNNING" } else { "○ Classroom App: STOPPED" }
    $classroomStatus.ForeColor = if ($proc) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::Tomato }
}

# FIXED: Store color in .Tag to prevent the null BackColor crash
function Create-ModernButton($text, $yPos, $color) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text; $btn.Size = New-Object System.Drawing.Size(340, 50); $btn.Location = New-Object System.Drawing.Point(30, $yPos); $btn.FlatStyle = "Flat"; $btn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65); $btn.FlatAppearance.BorderColor = $color; $btn.FlatAppearance.BorderSize = 1; $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag = $color # Keep a local copy of the color inside the button
    $btn.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = [System.Drawing.Color]::Black })
    $btn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65); $this.ForeColor = [System.Drawing.Color]::White })
    return $btn
}

# ==========================================
# BUTTON ACTIONS
# ==========================================

# 1. ENABLE FILTER
$enableBtn = Create-ModernButton "ENABLE WEB FILTER" 120 ([System.Drawing.Color]::LimeGreen)
$enableBtn.Add_Click({
    $url = "https://www-filter.c2.securly.com"
    Set-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -Value $url -Type String
    Set-ItemProperty -Path $userSettingsPath -Name "ProxyEnable" -Value 0 -Type DWord
    
    # Binary '05' enables Auto Config Script checkbox
    $enableBinary = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
    Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $enableBinary -Type Binary
    Refresh-Settings
})
$form.Controls.Add($enableBtn)

# 2. DISABLE FILTER
$disableBtn = Create-ModernButton "DISABLE WEB FILTER" 180 ([System.Drawing.Color]::Tomato)
$disableBtn.Add_Click({
    Remove-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
    $disableBinary = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
    Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $disableBinary -Type Binary
    Refresh-Settings
})
$form.Controls.Add($disableBtn)

# 3. LOCK CLASSROOM
$killLockBtn = Create-ModernButton "LOCK CLASSROOM" 260 ([System.Drawing.Color]::OrangeRed)
$killLockBtn.Add_Click({
    $form.Enabled = $false
    Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $classroomFolder) {
        takeown /f "$classroomFolder" /a /r /d y | Out-Null
        icacls "$classroomFolder" /inheritance:r /deny Everyone:F /t | Out-Null
    }
    $form.Enabled = $true
    Update-Status
})
$form.Controls.Add($killLockBtn)

# 4. UNLOCK CLASSROOM
$unlockStartBtn = Create-ModernButton "UNLOCK & START CLASSROOM" 320 ([System.Drawing.Color]::DeepSkyBlue)
$unlockStartBtn.Add_Click({
    $form.Enabled = $false
    if (Test-Path $classroomFolder) {
        takeown /f "$classroomFolder" /a /r /d y | Out-Null
        icacls "$classroomFolder" /remove:deny Everyone /t | Out-Null
        icacls "$classroomFolder" /grant "Everyone:(OI)(CI)F" /t | Out-Null
        Start-Sleep -Seconds 1
        if (Test-Path $classroomPath) {
            Start-Process "$classroomPath" -WorkingDirectory $classroomFolder
        }
    }
    $form.Enabled = $true
    Update-Status
})
$form.Controls.Add($unlockStartBtn)

# Initialize
$form.Add_Shown({ Update-Status; $form.Activate() })
[void]$form.ShowDialog()
