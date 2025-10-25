#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y python3 python3-pip mysql-client

# Get database details from metadata
DB_HOST=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-host")
DB_NAME=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-name")
DB_USER=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-user")
DB_PASS=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-pass")

# Install Flask
pip3 install flask mysql-connector-python gunicorn

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Create Flask app
cat > /opt/app/app.py <<'PYTHON_EOF'
from flask import Flask, jsonify, request
import mysql.connector
import os
import socket
from datetime import datetime

app = Flask(__name__)

DB_CONFIG = {
    'host': os.environ.get('DB_HOST'),
    'user': os.environ.get('DB_USER'),
    'password': os.environ.get('DB_PASS'),
    'database': os.environ.get('DB_NAME')
}

def get_db_connection():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Exception as e:
        return None

@app.route('/health')
def health():
    return 'OK', 200

@app.route('/')
def home():
    hostname = socket.gethostname()
    return jsonify({
        'status': 'running',
        'hostname': hostname,
        'timestamp': datetime.now().isoformat(),
        'message': 'Application tier healthy'
    })

@app.route('/db-check')
def db_check():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT VERSION(), NOW()")
            version, now = cursor.fetchone()
            cursor.close()
            conn.close()
            return jsonify({
                'database': 'connected',
                'version': version,
                'server_time': str(now),
                'host': DB_CONFIG['host']
            })
        except Exception as e:
            return jsonify({'database': 'error', 'message': str(e)}), 500
    else:
        return jsonify({'database': 'connection_failed'}), 500

@app.route('/write-test', methods=['POST'])
def write_test():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS test_data (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    message VARCHAR(255),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            message = request.json.get('message', 'Test message')
            cursor.execute("INSERT INTO test_data (message) VALUES (%s)", (message,))
            conn.commit()
            cursor.close()
            conn.close()
            return jsonify({'status': 'success', 'message': 'Data written'})
        except Exception as e:
            return jsonify({'status': 'error', 'message': str(e)}), 500
    else:
        return jsonify({'status': 'error', 'message': 'DB connection failed'}), 500

@app.route('/read-test')
def read_test():
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM test_data ORDER BY created_at DESC LIMIT 10")
            results = cursor.fetchall()
            cursor.close()
            conn.close()
            return jsonify({
                'status': 'success',
                'data': [{'id': r[0], 'message': r[1], 'created_at': str(r[2])} for r in results]
            })
        except Exception as e:
            return jsonify({'status': 'error', 'message': str(e)}), 500
    else:
        return jsonify({'status': 'error', 'message': 'DB connection failed'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
PYTHON_EOF

# Set environment variables
cat > /opt/app/.env <<ENV_EOF
DB_HOST=$DB_HOST
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
ENV_EOF

# Create systemd service
cat > /etc/systemd/system/app.service <<'SERVICE_EOF'
[Unit]
Description=Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:8080 --workers 4 --timeout 120 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl start app
systemctl enable app