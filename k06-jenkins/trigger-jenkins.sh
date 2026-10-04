#!/usr/bin/env bash
# Remote trigger: käivitab Jenkinsi jobi väljastpoolt (control node'ist, self-hosted runnerist, cronist).
# API tokeniga autentides ei ole crumbi (CSRF) vaja; parooli käsureale ei panda.
#
# Kasutus: JENKINS_USER=<gh> JENKINS_TOKEN=<API token> ./trigger-jenkins.sh [--wait] [folder/job]
#   API token: Jenkins → sinu nimi (paremal üleval) → Security → API Token → Add new token
# Vaikimisi job: <JENKINS_USER>/labori-seis. Keskkond: JENKINS_URL (vaikimisi http://jenkins.lab.hkhk.ee:8080)
set -euo pipefail

wait=0
if [[ "${1:-}" == "--wait" ]]; then
    wait=1
    shift
fi
url="${JENKINS_URL:-http://jenkins.lab.hkhk.ee:8080}"
url="${url%/}"
: "${JENKINS_USER:?JENKINS_USER puudub}"
: "${JENKINS_TOKEN:?JENKINS_TOKEN puudub}"
job="${1:-$JENKINS_USER/labori-seis}"
job_path="job/${job//\//\/job\/}"
auth="$JENKINS_USER:$JENKINS_TOKEN"

headers=$(mktemp)
trap 'rm -f "$headers"' EXIT
code=$(curl -sS -o /dev/null -D "$headers" -w '%{http_code}' -X POST -u "$auth" "$url/$job_path/build")

case "$code" in
    201) echo "OK: build järjekorras ($url/$job_path/)" ;;
    401) echo "FAIL: 401, vale kasutaja või token" >&2; exit 1 ;;
    403) echo "FAIL: 403, sul pole Job/Build õigust ($job)" >&2; exit 1 ;;
    404) echo "FAIL: 404, jobi $job ei ole" >&2; exit 1 ;;
    *)   echo "FAIL: HTTP $code" >&2; exit 1 ;;
esac

[[ $wait -eq 1 ]] || exit 0

# Location: .../queue/item/<id>/  → oota, kuni järjekorrast saab build, siis kuni see lõpeb
queue=$(grep -i '^location:' "$headers" | tr -d '\r' | awk '{print $2}')
build_url=""
for _ in $(seq 1 60); do
    build_url=$(curl -fsS -u "$auth" "${queue}api/json" | grep -o '"executable":{[^}]*"url":"[^"]*"' | grep -o 'http[^"]*' || true)
    [[ -n "$build_url" ]] && break
    sleep 5
done
[[ -n "$build_url" ]] || { echo "FAIL: build ei alanud 5 minutiga (agent offline?)" >&2; exit 1; }
echo "Build: $build_url"

while :; do
    result=$(curl -fsS -u "$auth" "${build_url}api/json?tree=result" | grep -o '"result":"[A-Z]*"' | cut -d'"' -f4 || true)
    if [[ -n "$result" ]]; then
        echo "Tulemus: $result"
        [[ "$result" == "SUCCESS" ]]
        exit
    fi
    sleep 10
done
