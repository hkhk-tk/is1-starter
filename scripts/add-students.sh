#!/usr/bin/env bash
# Lisab õppijad CSV-failist andmebaasi ja trükib igaühe tokeni.
# CSV: nimi,github (päiserida puudub)
# Kasutus: add-students.sh opilased.csv [kursuse_kood] | mysql labseis
# Olemasolev õppija (sama github) saab uue tokeni: korduv käivitus ei kuku.
set -euo pipefail

csv="${1:?CSV-fail puudub}"
course="${2:-IS1-26}"

# SQL-is ohtlikud märgid välja: ' (lõpetaks stringi) ja \ (põgeneks sulgevast jutumärgist)
clean() { local s="${1//\'/}"; s="${s//\\/}"; printf '%s' "${s%$'\r'}"; }

while IFS=, read -r name github; do
    github=$(clean "$github")
    [[ -z "$github" ]] && continue
    token=$(openssl rand -hex 16)
    printf "INSERT INTO student (course_id, name, github, token) SELECT id, '%s', '%s', '%s' FROM course WHERE code = '%s' ON DUPLICATE KEY UPDATE token = '%s';\n" \
        "$(clean "$name")" "$github" "$token" "$(clean "$course")" "$token"
    echo "-- $github $token" >&2
done < "$csv"
