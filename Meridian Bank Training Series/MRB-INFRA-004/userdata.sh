#!/bin/bash
# 1. Update packages and install Nginx
apt-get update
apt-get install -y nginx

# 2. Capture the VM hostname and the local private IP address
VM_NAME=$(hostname)
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 3. Create a styled dashboard page
cat <<HTML > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Dashboard</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: #f8fafc;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .card {
            background: rgba(30, 41, 59, 0.8);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            padding: 40px;
            max-width: 480px;
            width: 100%;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
        }
        .status-badge {
            display: inline-block;
            background-color: #10b981;
            color: #022c22;
            font-weight: 700;
            font-size: 0.75rem;
            padding: 4px 12px;
            border-radius: 9999px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 20px;
        }
        h1 {
            font-size: 1.8rem;
            font-weight: 700;
            margin-bottom: 8px;
            background: linear-gradient(90deg, #38bdf8, #818cf8);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        p.subtitle {
            color: #94a3b8;
            font-size: 0.95rem;
            margin-bottom: 28px;
        }
        .info-box {
            background: #0f172a;
            border-radius: 10px;
            padding: 16px;
            margin-bottom: 12px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-left: 4px solid #38bdf8;
        }
        .info-label {
            color: #64748b;
            font-size: 0.8rem;
            text-transform: uppercase;
            font-weight: 600;
        }
        .info-value {
            font-family: 'Courier New', Courier, monospace;
            font-size: 0.95rem;
            color: #38bdf8;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="status-badge">● Server Active</div>
        <h1>Web Server Live</h1>
        <p class="subtitle">Provisioned automatically via Terraform</p>
        
        <div class="info-box">
            <span class="info-label">Hostname</span>
            <span class="info-value">$VM_NAME</span>
        </div>
        
        <div class="info-box">
            <span class="info-label">Private IP</span>
            <span class="info-value">$LOCAL_IP</span>
        </div>
    </div>
</body>
</html>
HTML

# 4. Ensure Nginx starts and is running
systemctl enable nginx
systemctl restart nginx