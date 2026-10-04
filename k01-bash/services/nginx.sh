#!/usr/bin/env bash
# web01: Nginx reverse proxy → app01:8080. Ubuntu.
set -euo pipefail

timeout 900 cloud-init status --wait > /dev/null 2>&1 || true

# K1.2 harjutusest võib web01-s olla apache2, mis hoiab porti 80 (nginx-i paigaldus kukuks)
systemctl disable --now apache2 > /dev/null 2>&1 || true

# Nginx kontrollib upstream'i nime käivitamisel: app01 peab lahenduma
getent hosts app01 > /dev/null || { echo "web01 ei tunne nime app01 (etc-hosts.sh)" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=120 update -qq
apt-get -o DPkg::Lock::Timeout=120 install -y -qq nginx

# 'CONF' jutumärkides: Bash ei asenda $host ja $remote_addr, need on Nginxi muutujad
cat > /etc/nginx/sites-available/labori-seis <<'CONF'
upstream labori_seis {
    server app01:8080;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://labori_seis;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
CONF

ln -sfn /etc/nginx/sites-available/labori-seis /etc/nginx/sites-enabled/labori-seis
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx
systemctl reload nginx
echo "Nginx valmis"
