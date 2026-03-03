# ==========================================
# CONFIG & SETTINGS
# CHECK CODE: SQUID
# ==========================================
$port = 8282
$url = "http://localhost:$port/"
$userSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$classroomFolder = "C:\Program Files\Securly\Classroom"
$classroomPath = "$classroomFolder\Classroom.exe"

# ==========================================
# THE HTML & CSS GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { background: #1e1e1e; color: white; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; padding: 20px; }
        .panel { background: #2d2d30; width: 340px; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        button { 
            width: 340px; height: 50px; margin: 10px 0; cursor: pointer;
            background: #3c3c41; color: white; border: 1px solid #555; font-size: 16px; transition: 0.2s;
        }
        button:hover { background: #505055; border-color: white; }
        .btn-green { border-color: LimeGreen; }
        .btn-green:hover { background: LimeGreen; color: black; }
        .btn-red { border-color: Tomato; }
        .btn-red:hover { background: Tomato; color: black; }
        #status { color: #888; font-size: 14px; margin-top: 20px; text-align: center; min-height: 40px; }
    </style>
</head>
<body>
    <div class="panel">
        <div id="filter-text">Securly Filter Tool</div>
    </div>

    <button class="btn-green" onclick="run('enable')">ENABLE WEB FILTER</button>
    <button class="btn-red" onclick="run('disable')">DISABLE WEB FILTER</button>
    <button onclick="run('lock')">LOCK CLASSROOM</button>
    <button class="btn-green" onclick="run('unlock')">UNLOCK START CLASSROOM</button>

    <div class="panel" id="status">Ready.</div>

    <script>
        async function run(cmd) {
            const statusDiv = document.getElementById('status');
            statusDiv.innerText = "Connecting...";
            try {
                // We use the full URL to prevent 'relative path' confusion
                const resp = await fetch('http://localhost:8282/' + cmd, { 
                    method: 'GET',
                    mode: 'cors',
                    cache: 'no-cache'
                });
                const text = await resp.text();
                statusDiv.innerText = text;
            } catch (e) {
                statusDiv.innerText = "Error: PS Listener not responding.";
                console.error("Fetch failed:", e);
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
try {
    $listener.Start()
    Write-Host "Server started at $url" -ForegroundColor Green
    Start-Process $url 
} catch {
    Write-Host "Error: Port $port is blocked." -ForegroundColor Red
    pause; exit
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    
    $route = $request.Url.LocalPath.ToLower() 
    Write-Host "Request: $route" -ForegroundColor Gray

    # 1. HANDLE BROWSER SECURITY (CORS)
    $response.AddHeader("Access-Control-Allow-Origin", "*")
    $response.AddHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
    
    if ($request.HttpMethod -eq "OPTIONS") {
        $response.Close()
        continue
    }

    $msg = "Action Complete"

    # 2. RUN COMMANDS
    switch ($route) {
        "/" { $msg = $html; $response.ContentType = "text/html" }
        "/enable" {
            $pac = "https://www-filter.c2.securly.com"
            Set-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -Value $pac -Type String
            $eb = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $eb -Type Binary
            $msg = "Filter Enabled"
        }
        "/disable" {
            Remove-ItemProperty -Path $userSettingsPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
            $db = [byte[]](0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            Set-ItemProperty -Path "$userSettingsPath\Connections" -Name "DefaultConnectionSettings" -Value $db -Type Binary
            $msg = "Filter Disabled"
        }
        "/lock" {
            Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
            if (Test-Path $classroomFolder) {
                takeown /f "$classroomFolder" /a /r /d y | Out-Null
                icacls "$classroomFolder" /inheritance:r /deny Everyone:F /t | Out-Null
            }
            $msg = "Classroom Locked"
        }
        "/unlock" {
            if (Test-Path $classroomFolder) {
                icacls "$classroomFolder" /remove:deny Everyone /t | Out-Null
                icacls "$classroomFolder" /grant "Everyone:(OI)(CI)F" /t | Out-Null
                Start-Sleep -Seconds 1
                if (Test-Path $classroomPath) { Start-Process "$classroomPath" -WorkingDirectory $classroomFolder }
            }
            $msg = "Classroom Unlocked"
        }
    }

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($msg)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
}
