#!/usr/bin/env bash
# MUSTAND: kontrollib Labori seisu stacki ja saadab tulemused Labori seisu.
# Valmis: pordikontroll (kas teenus kuulab). Sinu töö: rakenduse tase (vt TODO).
# Keskkond / secrets.env: LABSEIS_TOKEN, LABSEIS_URL, TEACHER_TOKEN
set -euo pipefail
cd "$(dirname "$0")"

if [[ -f secrets.env ]]; then
    set -a
    # shellcheck disable=SC1091
    . ./secrets.env
    set +a
fi
REPORT="$(git rev-parse --show-toplevel)/scripts/labseis-report.sh"
LAB="lab-01"
fails=0
send_fail=0

ip_of() { tr -d '\r' < hosts | awk -v h="$1" '$1 == h {print $2}'; }

# Tulemus ekraanile ja Labori seisu. Saatmise viga ei katkesta kontrolli.
result() {
    local name="$1" status="$2" msg="$3"
    printf '%-13s %-4s %s\n' "$name" "$status" "$msg"
    [[ "$status" == OK ]] || fails=$((fails + 1))
    if [[ -n "${LABSEIS_TOKEN:-}" ]]; then
        bash "$REPORT" "$LAB" "$name" "$status" "$msg" > /dev/null 2>&1 || send_fail=1
    fi
}

port() {
    local name="$1" host="$2" port="$3" ip
    ip=$(ip_of "$host")
    if [[ -n "$ip" ]] && timeout 3 bash -c "echo > /dev/tcp/$ip/$port" 2> /dev/null; then
        result "$name" OK "$host:$port vastab"
    else
        result "$name" FAIL "$host:$port ei vasta"
    fi
}

port mariadb db01 3306
port memcached mc01 11211
port rabbitmq rmq01 5672
port tomcat app01 8080
port nginx web01 80

# TODO 1: küsi web01 kaudu /health ja anna iga võtme (db, queue, cache) kohta eraldi tulemus:
#         result health-db OK "..."  või  result health-db FAIL "..."
# TODO 2 (lisa): vahemälu test. Koondvaade "/?token=$TEACHER_TOKEN" kaks korda järjest,
#         teisel korral peab vastuse päis X-Cache olema HIT.

if [[ $send_fail -eq 1 ]]; then
    echo "NB: tulemuste saatmine Labori seisu (${LABSEIS_URL:-http://web01}) ebaõnnestus vähemalt korra" >&2
fi
[[ $fails -eq 0 ]]
