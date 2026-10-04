#!/usr/bin/env bash
# rmq01: RabbitMQ + kasutaja labseis. Ubuntu (Rocky jaoks vajab RabbitMQ eraldi repot).
# Keskkond: RABBITMQ_PASSWORD (kohustuslik)
set -euo pipefail
: "${RABBITMQ_PASSWORD:?RABBITMQ_PASSWORD puudub}"

timeout 900 cloud-init status --wait > /dev/null 2>&1 || true

. /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo "rabbitmq.sh eeldab Ubuntut (sain: $ID)" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=120 update -qq
apt-get -o DPkg::Lock::Timeout=120 install -y -qq rabbitmq-server
systemctl enable --now rabbitmq-server
# Erlangi node käivitub mõne sekundiga; rabbitmqctl enne seda annab vea
rabbitmqctl await_startup > /dev/null

# Kasutaja: loo või uuenda parool (idempotentne)
if rabbitmqctl list_users -q | awk '{print $1}' | grep -qx labseis; then
    rabbitmqctl change_password labseis "$RABBITMQ_PASSWORD" > /dev/null
else
    rabbitmqctl add_user labseis "$RABBITMQ_PASSWORD" > /dev/null
fi
rabbitmqctl set_permissions -p / labseis ".*" ".*" ".*" > /dev/null

# guest töötab ainult localhostist; kustutame turvalisuse pärast
rabbitmqctl delete_user guest > /dev/null 2>&1 || true

echo "RabbitMQ valmis ($(rabbitmqctl version 2> /dev/null || echo '?'))"
