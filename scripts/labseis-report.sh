#!/usr/bin/env bash
# Saadab ühe kontrolli tulemuse Labori seisu.
# Kasutus: labseis-report.sh <lab> <check> <OK|FAIL> [sõnum]
# Keskkond: LABSEIS_URL (vaikimisi http://web01), LABSEIS_TOKEN (kohustuslik)
set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Kasutus: $0 <lab> <check> <OK|FAIL> [sõnum]" >&2
    exit 2
fi

lab="$1"
check="$2"
status="$3"
message="${4:-}"
url="${LABSEIS_URL:-http://web01}"
: "${LABSEIS_TOKEN:?LABSEIS_TOKEN puudub}"

if [[ "$status" != "OK" && "$status" != "FAIL" ]]; then
    echo "Staatus peab olema OK või FAIL" >&2
    exit 2
fi

host=$(hostname -s)
if command -v jq > /dev/null; then
    body=$(jq -cn --arg lab "$lab" --arg check "$check" --arg status "$status" \
        --arg message "$message" --arg host "$host" '$ARGS.named')
else
    # JSON ilma jq-ta: juhtmärgid (reavahetus, TAB) tühikuks, kurakaldkriips ja jutumärk välja
    message=$(printf '%s' "$message" | tr '\000-\037' ' ')
    message="${message//\\/}"
    message="${message//\"/\'}"
    body="{\"lab\":\"$lab\",\"check\":\"$check\",\"status\":\"$status\",\"message\":\"$message\",\"host\":\"$host\"}"
fi

curl -fsS --max-time 10 -X POST "$url/api/results" \
    -H "Authorization: Bearer $LABSEIS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body"
echo
