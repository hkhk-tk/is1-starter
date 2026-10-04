#!/usr/bin/env bash
# db01: MariaDB + andmebaas labseis. Ubuntu või Rocky.
# Keskkond: DB_PASSWORD (kohustuslik). Failid: /tmp/schema.sql, /tmp/seed.sql
set -euo pipefail
# MUSTAND: skript lõpeb vigadeta, aga kas app01 pääseb andmebaasi? Kontrolli /health.
: "${DB_PASSWORD:?DB_PASSWORD puudub}"

timeout 900 cloud-init status --wait > /dev/null 2>&1 || true

. /etc/os-release
case "$ID" in
    ubuntu|debian)
        export DEBIAN_FRONTEND=noninteractive
        apt-get -o DPkg::Lock::Timeout=120 update -qq
        apt-get -o DPkg::Lock::Timeout=120 install -y -qq mariadb-server
        conf=/etc/mysql/mariadb.conf.d/60-labseis.cnf ;;
    rocky|rhel|centos|almalinux)
        dnf install -y -q mariadb-server
        conf=/etc/my.cnf.d/60-labseis.cnf ;;
    *) echo "Tundmatu distro: $ID" >&2; exit 1 ;;
esac

cat > "$conf" <<CNF
[mysqld]
bind-address = 0.0.0.0
CNF

systemctl enable --now mariadb
systemctl restart mariadb

# root logib sisse unix_socket'iga (sudo mysql), parooli pole vaja.
mysql <<SQL
CREATE DATABASE IF NOT EXISTS labseis CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'labseis'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER 'labseis'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON labseis.* TO 'labseis'@'localhost';
FLUSH PRIVILEGES;
SQL

mysql labseis < /tmp/schema.sql
mysql labseis < /tmp/seed.sql

if command -v firewall-cmd > /dev/null && systemctl is-active --quiet firewalld; then
    firewall-cmd -q --permanent --add-port=3306/tcp
    firewall-cmd -q --reload
fi

ss -tln | grep -q '0.0.0.0:3306' || { echo "MariaDB ei kuula 0.0.0.0:3306 (ss -tlnp)" >&2; exit 1; }
echo "MariaDB valmis: $(mysql -N -e 'SELECT COUNT(*) FROM labseis.student') õppijat"
