#!/usr/bin/env bash
# Control node'ilt: seadistab kogu stacki õiges järjekorras üle SSH.
# Eeldused: fail "hosts" (vt hosts.example), "secrets.env", SSH võti hostides (kasutaja devops, sudo).
# Kasutus: ./deploy-all.sh            (kõik)
#          ./deploy-all.sh db01       (üks host)
set -euo pipefail
cd "$(dirname "$0")"

# Repo juur (seal on db/ ja target/). Töötab nii labori-seis/deploy/bash/ kui õppija k01-bash/ kaustas.
REPO_ROOT=$(git rev-parse --show-toplevel 2> /dev/null) || REPO_ROOT=$(cd .. && pwd)
# Teenuse-skriptid: õppija repos alamkaustas services/, lahenduse repos samas kaustas
if [[ -d services ]]; then SVC_DIR=services; else SVC_DIR=.; fi
SSH_USER="${SSH_USER:-devops}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new)

[[ -f hosts ]] || { echo "Fail 'hosts' puudub (cp hosts.example hosts)" >&2; exit 1; }
[[ -f secrets.env ]] || { echo "Fail 'secrets.env' puudub (cp secrets.env.example secrets.env)" >&2; exit 1; }
# shellcheck disable=SC1091
. ./secrets.env
: "${DB_PASSWORD:?secrets.env: DB_PASSWORD puudub}" "${RABBITMQ_PASSWORD:?}" "${TEACHER_TOKEN:?}"

# Järjekord: alt üles. Nginx kontrollib käivitudes, kas app01 nimi lahendub; Tomcati skript ootab,
# kuni rakendus vastab. Andmebaas, vahemälu ja järjekord peavad siis juba olemas olema.
ORDER=(db01 mc01 rmq01 app01 web01)
declare -A SCRIPT=([db01]=mariadb.sh [mc01]=memcache.sh [rmq01]=rabbitmq.sh [app01]=tomcat.sh [web01]=nginx.sh)

targets=("${@:-${ORDER[@]}}")

# hosts-fail: CRLF välja, kommentaarid välja
hosts_clean() { tr -d '\r' < hosts | grep -Ev '^[[:space:]]*(#|$)'; }
ip_of() { hosts_clean | awk -v h="$1" '$1 == h {print $2}'; }

validate_hosts() {
    local dup h
    dup=$(hosts_clean | awk '{print $2}' | sort | uniq -d)
    [[ -z "$dup" ]] || { echo "hosts: sama IP mitmel real: $dup" >&2; exit 1; }
    dup=$(hosts_clean | awk '{print $1}' | sort | uniq -d)
    [[ -z "$dup" ]] || { echo "hosts: sama nimi mitmel real: $dup" >&2; exit 1; }
    for h in "${ORDER[@]}"; do
        [[ -n "$(ip_of "$h")" ]] || { echo "hosts: $h puudub" >&2; exit 1; }
    done
}

# Saladused saadetakse ssh standardsisendisse koos skriptiga, mitte käsureale:
# käsurida on näha ps-is ja sudo logis (journalctl -t sudo), stdin mitte.
# Skript pannakse funktsiooni sisse ja käivitatakse </dev/null-iga, et ükski skripti käsk
# (apt, mysql ...) ei saaks ülejäänud skripti standardsisendist ära lugeda.
remote_run() {
    local ip="$1" file="$2"
    {
        printf 'export DB_PASSWORD=%q RABBITMQ_PASSWORD=%q TEACHER_TOKEN=%q WAR_URL=%q\n' \
            "$DB_PASSWORD" "$RABBITMQ_PASSWORD" "$TEACHER_TOKEN" "${WAR_URL:-}"
        printf 'export TOMCAT_URL=%q TOMCAT_VERSION=%q\n' "${TOMCAT_URL:-}" "${TOMCAT_VERSION:-}"
        printf 'labseis_main() {\n'
        cat "$file"
        printf '\n}\nlabseis_main < /dev/null\n'
    } | ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "sudo bash -s"
}

run() {
    local host="$1" ip script
    ip=$(ip_of "$host")
    script="${SCRIPT[$host]:-}"
    [[ -n "$script" ]] || { echo "Tundmatu host: $host (lubatud: ${ORDER[*]})" >&2; return 1; }
    [[ -n "$ip" ]] || { echo "$host puudub failis hosts" >&2; return 1; }
    echo "=== $host ($ip): $script"

    # /etc/hosts sihtmasinas (nimi -> IP), et app01 leiaks db01 ja Nginx app01
    scp -q "${SSH_OPTS[@]}" etc-hosts.sh "$SSH_USER@$ip:/tmp/"
    ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "sudo bash /tmp/etc-hosts.sh" < <(hosts_clean) > /dev/null

    case "$host" in
        db01) scp -q "${SSH_OPTS[@]}" "$REPO_ROOT/db/schema.sql" "$REPO_ROOT/db/seed.sql" "$SSH_USER@$ip:/tmp/" ;;
        app01)
            if [[ -f "$REPO_ROOT/target/labori-seis.war" ]]; then
                scp -q "${SSH_OPTS[@]}" "$REPO_ROOT/target/labori-seis.war" "$SSH_USER@$ip:/tmp/"
            fi ;;
    esac

    remote_run "$ip" "$SVC_DIR/$script"
}

validate_hosts
for host in "${targets[@]}"; do
    run "$host"
done

web=$(ip_of web01)
echo
if ! getent hosts db01 > /dev/null; then
    echo "NB: control node ei tunne nime db01. check.sh töötab IP-dega, aga ssh/curl nimega mitte:"
    echo "    sudo bash etc-hosts.sh < hosts"
fi
echo "Valmis. /health web01 kaudu:"
curl -sS --max-time 10 "http://$web/health" || echo "web01 ei vasta (vaata: ssh web01 sudo journalctl -u nginx -n 20)"
echo
