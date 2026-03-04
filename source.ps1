# ==========================================
# CHECK: TEAL SQURRIEL
# ==========================================
$regPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$folder = "C:\Program Files\Securly\Classroom"

function Refresh-Internet {
    $signature = @"
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@
    Add-Type -MemberDefinition $signature -Name WinInet -Namespace Win32 -ErrorAction SilentlyContinue
    # Force system to reload proxy settings
    [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    [Win32.WinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
}

# Use this updated logic inside your Switch statement:
switch ($cmd) {
    "enable" {
        $pac = "https://www-filter.c2.securly.com"
        Set-ItemProperty -Path $regPath -Name "AutoConfigURL" -Value $pac -Type String
        # Set the binary '05' flag which is the actual "Enable" checkbox
        $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
        Set-ItemProperty -Path "$regPath\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary
        Refresh-Internet
    }
    "disable" {
        Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
        # Set binary '01' to uncheck all LAN boxes
        $bin = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
        Set-ItemProperty -Path "$regPath\Connections" -Name "DefaultConnectionSettings" -Value $bin -Type Binary
        Refresh-Internet
    }
    "lock" {
        Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
        if (Test-Path $folder) {
            # Added /A for Administrators and /Q for Quiet mode
            takeown /f "$folder" /a /r /d y | Out-Null
            icacls "$folder" /inheritance:r /deny Everyone:F /t /q | Out-Null
        }
    }
    "unlock" {
        if (Test-Path $folder) {
            icacls "$folder" /remove:deny Everyone /t /q | Out-Null
            icacls "$folder" /grant Everyone:F /t /q | Out-Null
            Start-Sleep -Seconds 1
            if (Test-Path "$folder\Classroom.exe") { 
                Start-Process "$folder\Classroom.exe" -WorkingDirectory $folder 
            }
        }
    }
}
