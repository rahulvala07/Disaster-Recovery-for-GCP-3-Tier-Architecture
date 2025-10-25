#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y nginx wget curl

# Get instance metadata
INSTANCE_NAME=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
INSTANCE_ZONE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d'/' -f4)
INSTANCE_REGION=$(echo $INSTANCE_ZONE | cut -d'-' -f1,2)

# Create health check endpoint
cat > /var/www/html/health <<EOF
OK
EOF

# Create application page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GCP DR Demo - Mumbai ↔ Delhi</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            padding: 50px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            text-align: center;
            max-width: 700px;
        }
        h1 {
            font-size: 3em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        h2 {
            font-size: 1.8em;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        .info {
            background: rgba(255, 255, 255, 0.15);
            border-radius: 15px;
            padding: 30px;
            margin: 30px 0;
        }
        .badge {
            background: rgba(255, 255, 255, 0.25);
            padding: 12px 24px;
            border-radius: 10px;
            display: inline-block;
            margin: 10px;
            font-size: 1.1em;
        }
        .status {
            background: #10b981;
            color: white;
            padding: 18px;
            border-radius: 12px;
            margin-top: 25px;
            font-weight: bold;
            font-size: 1.2em;
            box-shadow: 0 4px 15px rgba(16, 185, 129, 0.4);
        }
        .footer {
            margin-top: 30px;
            opacity: 0.7;
            font-size: 0.95em;
        }
        .icon {
            font-size: 1.5em;
            margin-right: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1><span class="icon">🚀</span>Disaster Recovery Demo</h1>
        <h2>Multi-Region Architecture</h2>
        <div class="info">
            <div class="badge">
                <strong>Instance:</strong> $INSTANCE_NAME
            </div>
            <div class="badge">
                <strong>Zone:</strong> $INSTANCE_ZONE
            </div>
            <div class="badge">
                <strong>Region:</strong> $INSTANCE_REGION
            </div>
        </div>
        <div class="status">
            <span class="icon">✓</span>System Operational
        </div>
        <div class="footer">
            Mumbai (Primary) ↔ Delhi (Secondary)<br>
            Powered by Google Cloud Platform
        </div>
    </div>
</body>
</html>
EOF

cat > /etc/nginx/sites-available/default <<'NGINX_EOF'
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
}
NGINX_EOF

systemctl restart nginx
systemctl enable nginx