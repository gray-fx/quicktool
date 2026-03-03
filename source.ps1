# check = octopus
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

$userSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$classroomFolder = "C:\Program Files\Securly\Classroom"
$classroomPath = "$classroomFolder\Classroom.exe"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Quicktool v1.0"
$form.Size = New-Object System.Drawing.Size(420, 600) # Increased height for Error Panel
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Topmost = $true

# Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(340, 60); $statusPanel.Location = New-Object System.Drawing.Point(30, 70); $statusPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48); $form.Controls.Add($statusPanel)

$filterStatus = New-Object System.Windows.Forms.Label; $filterStatus.Text = "Filter: --"; $filterStatus.Location = New-Object System.Drawing.Point(10, 10); $filterStatus.Size = New-Object System.Drawing.Size(320, 20); $statusPanel.Controls.Add($filterStatus)
$classroomStatus = New-Object System.Windows.Forms.Label; $classroomStatus.Text = "App: --"; $classroomStatus.Location = New-Object System.Drawing.Point(10, 32); $classroomStatus.Size = New-Object System.Drawing.Size(320, 20); $statusPanel.Controls.Add($classroomStatus)

# Errors Panel (New)
$errorPanel = New-Object System.Windows.Forms.Panel
$errorPanel.Size = New-Object System.Drawing.Size(340, 60); $errorPanel.Location = New-Object System.Drawing.Point(30, 420); $errorPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48); $form.Controls.Add($errorPanel)
$errorLabel = New-Object System.Windows.Forms.Label; $errorLabel.Text = "No errors detected."; $errorLabel.Location = New-Object System.Drawing.Point(10, 10); $errorLabel.Size = New-Object System.Drawing.Size(320, 40); $errorLabel.ForeColor = [System.Drawing.Color]::Gray; $errorPanel.Controls.Add($errorLabel)

function Update-Status {
    $current = (Get-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue).AutoConfigURL
    $filterStatus.Text = if ($current) { "● Securly Filter: ACTIVE" } else { "○ Securly Filter: DISABLED" }
    $filterStatus.ForeColor = if ($current) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::Tomato }
    
    $proc = Get-Process "Classroom" -ErrorAction SilentlyContinue
    $classroomStatus.Text = if ($proc) { "● Classroom App: RUNNING" } else { "○ Classroom App: STOPPED" }
    $classroomStatus.ForeColor = if ($proc) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::Tomato }
}

function Create-ModernButton($text, $yPos, $color) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text; $btn.Size = New-Object System.Drawing.Size(340, 50); $btn.Location = New-Object System.Drawing.Point(30, $yPos); $btn.FlatStyle = "Flat"; $btn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65); $btn.FlatAppearance.BorderColor = $color; $btn.FlatAppearance.BorderSize = 1; $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag = $color
    $btn.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = "Black" })
    $btn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65); $this.ForeColor = "White" })
    return $btn
}

# 1. ENABLE
$enableBtn = Create-ModernButton "ENABLE WEB FILTER" 150 ([System.Drawing.Color]::LimeGreen)
$enableBtn.Add_Click({
    try {
        $url = "https://www-filter.c2.securly.com"
        Set-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -Value $url -Type String
        $eb = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
        Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $eb -Type Binary
        Refresh-Settings
    } catch { $errorLabel.Text = "Enable Error: $($_.Exception.Message)"; $errorLabel.ForeColor = "Tomato" }
})
$form.Controls.Add($enableBtn)

# 2. DISABLE
$disableBtn = Create-ModernButton "DISABLE WEB FILTER" 210 ([System.Drawing.Color]::Tomato)
$disableBtn.Add_Click({
    try {
        Remove-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
        $db = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
        Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $db -Type Binary
        Refresh-Settings
    } catch { $errorLabel.Text = "Disable Error: $($_.Exception.Message)"; $errorLabel.ForeColor = "Tomato" }
})
$form.Controls.Add($disableBtn)

# 3. KILL LOCK
$killLockBtn = Create-ModernButton "LOCK CLASSROOM" 290 ([System.Drawing.Color]::OrangeRed)
$killLockBtn.Add_Click({
    try {
        Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
        takeown /f "$classroomFolder" /a /r /d y | Out-Null
        icacls "$classroomFolder" /inheritance:r /deny Everyone:F /t | Out-Null
        Update-Status
    } catch { $errorLabel.Text = "Lock Error: $($_.Exception.Message)"; $errorLabel.ForeColor = "Tomato" }
})
$form.Controls.Add($killLockBtn)

# 4. UNLOCK START (Name Reverted)
$unlockStartBtn = Create-ModernButton "UNLOCK START CLASSROOM" 350 ([System.Drawing.Color]::LimeGreen)
$unlockStartBtn.Add_Click({
    try {
        icacls "$classroomFolder" /remove:deny Everyone /t | Out-Null
        icacls "$classroomFolder" /grant "Everyone:(OI)(CI)F" /t | Out-Null
        Start-Sleep -Seconds 1
        Start-Process "$classroomPath" -WorkingDirectory $classroomFolder
        Update-Status
    } catch { $errorLabel.Text = "Unlock Error: $($_.Exception.Message)"; $errorLabel.ForeColor = "Tomato" }
})
$form.Controls.Add($unlockStartBtn)

$form.Add_Shown({ Update-Status; $form.Activate() })
[void]$form.ShowDialog()
