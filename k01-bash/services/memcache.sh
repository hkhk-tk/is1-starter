#!/usr/bin/env bash
# mc01: Memcached, kuulab kõigil liidestel pordil 11211. Ubuntu või Rocky.
set -euo pipefail
# MUSTAND: memcached käivitub, aga kas app01 saab sellega ühendust? Kontrolli /health.

timeout 900 cloud-init status --wait > /dev/null 2>&1 || true

. /etc/os-release
case "$ID" in
    ubuntu|debian)
        export DEBIAN_FRONTEND=noninteractive
        apt-get -o DPkg::Lock::Timeout=120 update -qq
        apt-get -o DPkg::Lock::Timeout=120 install -y -qq memcached ;;
    rocky|rhel|centos|almalinux)
        dnf install -y -q memcached ;;
    *) echo "Tundmatu distro: $ID" >&2; exit 1 ;;
esac

systemctl enable --now memcached
systemctl restart memcached

if command -v firewall-cmd > /dev/null && systemctl is-active --quiet firewalld; then
    firewall-cmd -q --permanent --add-port=11211/tcp
    firewall-cmd -q --reload
fi

sleep 2
ss -tln | grep ':11211'
echo "Memcached valmis"
