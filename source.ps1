# ==========================================
# 1. LOAD ASSEMBLIES (Uses Edge Chromium)
# check code ORCA
# ==========================================
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Path for WebView2 - usually found in PowerBI or Edge folders
$wpfPath = "C:\Program Files\Microsoft Power BI Desktop\bin\Microsoft.Web.WebView2.WinForms.dll"
if (-not (Test-Path $wpfPath)) { 
    # Fallback to common install path if PowerBI isn't there
    $wpfPath = "C:\Windows\System32\Microsoft.Web.WebView2.WinForms.dll" 
}
Add-Type -Path $wpfPath -ErrorAction SilentlyContinue

# ==========================================
# 2. THE HTML & CSS GUI
# ==========================================
$html = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <style>
        body { background: #121212; color: #e0e0e0; font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; padding: 20px; }
        .card { background: #1e1e1e; width: 320px; padding: 20px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.5); border: 1px solid #333; }
        button { 
            width: 100%; height: 45px; margin: 8px 0; cursor: pointer; border-radius: 6px;
            background: #2d2d2d; color: white; border: 1px solid #444; font-size: 14px; font-weight: 600; transition: all 0.2s;
        }
        button:hover { background: #3d3d3d; border-color: #666; transform: translateY(-1px); }
        .btn-green { border-color: #2ecc71; color: #2ecc71; }
        .btn-green:hover { background: #2ecc71; color: white; }
        .btn-red { border-color: #e74c3c; color: #e74c3c; }
        .btn-red:hover { background: #e74c3c; color: white; }
        #status { font-size: 12px; color: #888; margin-top: 15px; text-align: center; }
    </style>
</head>
<body>
    <div class='card'>
        <h3 style='margin-top:0'>Securly Quicktool</h3>
        <button class='btn-green' onclick='send("enable")'>Enable Web Filter</button>
        <button class='btn-red' onclick='send("disable")'>Disable Web Filter</button>
        <button onclick='send("lock")'>Lock Classroom</button>
        <button class='btn-green' onclick='send("unlock")'>Unlock Start Classroom</button>
        <div id='status'>Ready.</div>
    </div>

    <script>
        function send(cmd) {
            document.getElementById('status').innerText = "Processing...";
            // This sends a message directly to the PowerShell "bridge"
            window.chrome.webview.postMessage(cmd);
        }
    </script>
</body>
</html>
"@

# ==========================================
# 3. CREATE WINDOW & BRIDGE
# ==========================================
$form = New-Object System.Windows.Forms.Form -Property @{ Width=400; Height=450; Text="Quicktool v2.0"; BackColor="#121212"; StartPosition="CenterScreen"; Topmost=$true }

$webView = New-Object Microsoft.Web.WebView2.WinForms.WebView2 -Property @{ Dock="Fill" }
$form.Controls.Add($webView)

# Initialize Chromium Engine
$webView.Add_CoreWebView2InitializationCompleted({
    $webView.CoreWebView2.NavigateToString($html)
})
$webView.EnsureCoreWebView2Async()

# THE BRIDGE: What happens when JavaScript sends a message
$webView.Add_WebMessageReceived({
    param($sender, $args)
    $cmd = $args.TryGetWebMessageAsString()
    
    switch ($cmd) {
        "enable" {
            $url = "https://www-filter.c2.securly.com"
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "AutoConfigURL" -Value $url -Type String
            # ... additional registry logic here ...
            $webView.ExecuteScriptAsync("document.getElementById('status').innerText = 'Filter Enabled';")
        }
        "disable" {
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "AutoConfigURL" -ErrorAction SilentlyContinue
            $webView.ExecuteScriptAsync("document.getElementById('status').innerText = 'Filter Disabled';")
        }
        "lock" {
            Get-Process "Classroom" -ErrorAction SilentlyContinue | Stop-Process -Force
            # ... lock folder logic ...
            $webView.ExecuteScriptAsync("document.getElementById('status').innerText = 'Classroom Locked';")
        }
        "unlock" {
            # ... unlock folder logic ...
            $webView.ExecuteScriptAsync("document.getElementById('status').innerText = 'Classroom Unlocked';")
        }
    }
})

$form.ShowDialog()
