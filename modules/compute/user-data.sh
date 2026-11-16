#!/bin/bash
# ---------------------------------------------------------------------------
# Bootstraps a small Flask application on Amazon Linux 2023 that connects to
# the private RDS database, initializes a sample "users" table, and exposes
# CRUD + health endpoints - proving the app tier actually talks to the data
# tier, not just that infrastructure exists next to it.
# ---------------------------------------------------------------------------
set -euo pipefail

# 1. Update packages
dnf update -y

# 2. Install Python + pip (no separate web server needed - gunicorn serves directly)
dnf install -y python3 python3-pip

mkdir -p /opt/app
cd /opt/app

# 3. Install app dependencies (both DB drivers included so the same app.py
# works whichever engine was chosen; footprint is small either way)
pip3 install --no-cache-dir flask gunicorn psycopg2-binary pymysql

# ---------------------------------------------------------------------------
# DB connection settings, written to a root-only env file rather than baked
# into app.py. This keeps the secret out of source/version control and out of
# `ps`/process-listing output. It is still readable by root on the instance
# and present (base64-encoded) in the instance's user_data via the EC2 API -
# for real production use, pull the password from AWS Secrets Manager at
# boot/runtime instead of passing it through user_data. See README.
# ---------------------------------------------------------------------------
cat > /opt/app/app.env <<ENVEOF
DB_ENGINE=${db_engine}
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
APP_ENVIRONMENT=${environment}
ENVEOF
chmod 600 /opt/app/app.env
chown root:root /opt/app/app.env

# 4. The Flask application itself - plain Python, no Terraform template
# variables used inside this block, so no $${...} escaping is needed here.
cat > /opt/app/app.py <<'PYEOF'
import os
import socket
import time
import urllib.request
from datetime import datetime, timezone

from flask import Flask, jsonify, request

app = Flask(__name__)

DB_ENGINE = os.environ.get("DB_ENGINE", "postgres")
DB_HOST = os.environ.get("DB_HOST")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
APP_ENVIRONMENT = os.environ.get("APP_ENVIRONMENT", "production")

HOSTNAME = socket.gethostname()


def get_instance_metadata():
    """Fetch instance id + AZ via IMDSv2. Falls back gracefully if unavailable
    (e.g. running outside EC2)."""
    try:
        token_req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode()

        def meta(path):
            req = urllib.request.Request(
                f"http://169.254.169.254/latest/meta-data/{path}",
                headers={"X-aws-ec2-metadata-token": token},
            )
            return urllib.request.urlopen(req, timeout=2).read().decode()

        return meta("instance-id"), meta("placement/availability-zone")
    except Exception:
        return "unknown", "unknown"


INSTANCE_ID, AVAILABILITY_ZONE = get_instance_metadata()


def get_db_connection():
    if DB_ENGINE == "mysql":
        import pymysql

        return pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=5,
        )
    else:
        import psycopg2

        return psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            dbname=DB_NAME,
            connect_timeout=5,
        )


def init_db(max_attempts=10, delay_seconds=5):
    """Create the users table and seed sample data if empty. Retries because
    RDS may still be finishing setup when the instance first boots."""
    for attempt in range(1, max_attempts + 1):
        try:
            conn = get_db_connection()
            cur = conn.cursor()

            if DB_ENGINE == "mysql":
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS users (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        email VARCHAR(255) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )
            else:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS users (
                        id SERIAL PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        email VARCHAR(255) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )
            conn.commit()

            cur.execute("SELECT COUNT(*) FROM users")
            count = cur.fetchone()[0]

            if count == 0:
                sample_users = [
                    ("Ahmed", "ahmed@example.com"),
                    ("Omar", "omar@example.com"),
                    ("Sara", "sara@example.com"),
                    ("Laila", "laila@example.com"),
                    ("Youssef", "youssef@example.com"),
                ]
                cur.executemany(
                    "INSERT INTO users (name, email) VALUES (%s, %s)",
                    sample_users,
                )
                conn.commit()

            cur.close()
            conn.close()
            print(f"[init_db] Database ready after {attempt} attempt(s).")
            return
        except Exception as exc:
            print(f"[init_db] Attempt {attempt}/{max_attempts} failed: {exc}")
            if attempt == max_attempts:
                print("[init_db] Giving up - app will still start; /db-health will report the failure.")
                return
            time.sleep(delay_seconds)


def check_db():
    """Lightweight connectivity + row-count check used by / and /db-health."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM users")
        count = cur.fetchone()[0]
        cur.close()
        conn.close()
        return True, count, None
    except Exception as exc:
        return False, None, str(exc)


@app.route("/")
def index():
    connected, user_count, error = check_db()
    db_status = "CONNECTED" if connected else "DISCONNECTED"
    users_line = f"Users in Database: {user_count}" if connected else f"Error: {error}"

    html = f"""<!DOCTYPE html>
<html>
<head><title>AWS 3-Tier Application</title></head>
<body style="font-family: monospace; padding: 2rem;">
  <h1>AWS 3-Tier Application</h1>
  <h2>Application Server</h2>
  <p>Hostname: {HOSTNAME}</p>
  <p>Instance ID: {INSTANCE_ID}</p>
  <p>Availability Zone: {AVAILABILITY_ZONE}</p>
  <p>Environment: {APP_ENVIRONMENT}</p>
  <h2>Database Status</h2>
  <p>{DB_ENGINE.upper()}: {db_status}</p>
  <p>Database: {DB_NAME}</p>
  <p>{users_line}</p>
  <p>Last Query: SELECT COUNT(*) FROM users;</p>
  <hr>
  <p>Try: <a href="/users">/users</a> | <a href="/health">/health</a> | <a href="/db-health">/db-health</a></p>
</body>
</html>"""
    return html


@app.route("/health")
def health():
    # App-level liveness only - always 200 if the process is up. This is what
    # the ALB target group health check calls, so a slow/degraded DB does not
    # take healthy instances out of rotation.
    return jsonify({"status": "ok", "instance_id": INSTANCE_ID, "az": AVAILABILITY_ZONE})


@app.route("/db-health")
def db_health():
    connected, user_count, error = check_db()
    payload = {
        "database_engine": DB_ENGINE,
        "database_connection": "SUCCESS" if connected else "FAILURE",
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }
    if connected:
        payload["user_count"] = user_count
        return jsonify(payload), 200
    else:
        payload["error"] = error
        return jsonify(payload), 503


@app.route("/users", methods=["GET"])
def list_users():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, name, email, created_at FROM users ORDER BY id")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        users = [
            {"id": r[0], "name": r[1], "email": r[2], "created_at": str(r[3])}
            for r in rows
        ]
        return jsonify(users)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 503


@app.route("/users", methods=["POST"])
def create_user():
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    email = data.get("email")
    if not name or not email:
        return jsonify({"error": "both 'name' and 'email' are required"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("INSERT INTO users (name, email) VALUES (%s, %s)", (name, email))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "created", "name": name, "email": email}), 201
    except Exception as exc:
        return jsonify({"error": str(exc)}), 503


# Run DB initialization once at import time so it fires whether this module
# is executed directly or imported by gunicorn.
init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYEOF

chown -R root:root /opt/app

# 5. systemd unit: run gunicorn on port 80, reading DB credentials from the
# root-only env file. Running as root is required to bind port 80 directly;
# for a hardened production setup, run on an unprivileged port behind a
# reverse proxy or terminate on a different target port in the ALB.
cat > /etc/systemd/system/flaskapp.service <<'UNITEOF'
[Unit]
Description=Flask 3-tier demo application
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/app.env
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:80 --workers 2 --access-logfile - app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNITEOF

# 6-9. Enable and start the service
systemctl daemon-reload
systemctl enable flaskapp
systemctl start flaskapp
