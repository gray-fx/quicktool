# ==========================================
# CONFIG & SETTINGS
# ==========================================
$port = 8282
$url = "http://localhost:$port/"
$userSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$classroomFolder = "C:\Program Files\Securly\Classroom"

# ==========================================
# THE HTML & CSS GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { background: #1e1e1e; color: white; font-family: 'Segoe UI'; display: flex; flex-direction: column; align-items: center; padding: 20px; }
        .panel { background: #2d2d30; width: 340px; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        button { 
            width: 340px; height: 50px; margin: 10px 0; cursor: pointer;
            background: #3c3c41; color: white; border: 1px solid #555; font-size: 16px; transition: 0.2s;
        }
        button:hover { background: #505055; }
        .btn-enable { border-color: LimeGreen; }
        .btn-enable:hover { background: LimeGreen; color: black; }
        .btn-disable { border-color: Tomato; }
        .btn-disable:hover { background: Tomato; color: black; }
        #status { color: gray; font-size: 14px; margin-top: 20px; text-align: center; }
    </style>
</head>
<body>
    <div class="panel">
        <div id="filter-text">Filter: Checking...</div>
        <div id="app-text">App: Checking...</div>
    </div>

    <button class="btn-enable" onclick="run('enable')">ENABLE WEB FILTER</button>
    <button class="btn-disable" onclick="run('disable')">DISABLE WEB FILTER</button>
    <button onclick="run('lock')">LOCK CLASSROOM</button>
    <button class="btn-enable" onclick="run('unlock')">UNLOCK START CLASSROOM</button>

    <div class="panel" id="status">No errors detected.</div>

    <script>
        async function run(cmd) {
            document.getElementById('status').innerText = "Running " + cmd + "...";
            try {
                const resp = await fetch('/' + cmd);
                const text = await resp.text();
                document.getElementById('status').innerText = text;
            } catch (e) {
                document.getElementById('status').innerText = "Error connecting to script.";
            }
        }
    </script>
</body>
</html>
"@

# ==========================================
# THE SERVER LOGIC
# ==========================================
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()

# Automatically open the GUI in the default browser
Start-Process $url

Write-Host "Server running at $url. Close this window to stop." -ForegroundColor Cyan

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    $route = $request.RawUrl.Trim('/')

    $msg = "Action Complete"

    # RUN COMMANDS BASED ON BUTTON CLICK
    switch ($route) {
        "enable" {
            $pac = "https://www-filter.c2.securly.com"
            Set-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -Value $pac -Type String
            $eb = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $eb -Type Binary
            $msg = "Filter Enabled"
        }
        "disable" {
            Remove-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
            $db = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $db -Type Binary
            $msg = "Filter Disabled"
        }
        "lock" {
            Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
            icacls "$classroomFolder" /inheritance:r /deny Everyone:F /t | Out-Null
            $msg = "Classroom Locked"
        }
        "unlock" {
            icacls "$classroomFolder" /remove:deny Everyone /t | Out-Null
            icacls "$classroomFolder" /grant "Everyone:(OI)(CI)F" /t | Out-Null
            $msg = "Classroom Unlocked"
        }
    }

    # SEND HTML BACK OR STATUS MESSAGE
    $buffer = if ($route -eq "") { [System.Text.Encoding]::UTF8.GetBytes($html) } 
             else { [System.Text.Encoding]::UTF8.GetBytes($msg) }
             
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
}
