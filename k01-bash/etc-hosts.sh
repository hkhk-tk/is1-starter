#!/usr/bin/env bash
# Kirjutab labori hostinimed /etc/hosts faili (idempotentne: vana plokk asendatakse).
# Kasutus: sudo bash etc-hosts.sh < hosts
#
# Proxmoxi cloud-init kirjutab /etc/hosts igal boodil mallist üle (PVE user-data: manage_etc_hosts: true).
# Seepärast: drop-in manage_etc_hosts: false JA sama plokk cloud-init'i hosts-malli.
# Drop-in üksi ei piisa, kui VM-i user-data sisaldab manage_etc_hosts: true (user-data on tugevam);
# siis taastab ploki mall. Kontroll: sudo reboot, seejärel getent hosts db01.
set -euo pipefail

begin="# labori-seis BEGIN"
end="# labori-seis END"

# CRLF välja (Windowsis salvestatud fail), kommentaarid ja tühjad read välja, "nimi IP" -> "IP nimi"
block=$(tr -d '\r' | grep -Ev '^[[:space:]]*(#|$)' | awk 'NF >= 2 {print $2, $1}')
[[ -n "$block" ]] || { echo "Sisendis pole ühtegi 'nimi IP' rida" >&2; exit 1; }

write_block() {
    local file="$1"
    sed -i "/^$begin\$/,/^$end\$/d" "$file"
    printf '%s\n%s\n%s\n' "$begin" "$block" "$end" >> "$file"
}

write_block /etc/hosts

if [[ -d /etc/cloud ]]; then
    mkdir -p /etc/cloud/cloud.cfg.d
    printf '# labori-seis: /etc/hosts plokki haldab etc-hosts.sh\nmanage_etc_hosts: false\n' \
        > /etc/cloud/cloud.cfg.d/99-labori-seis.cfg
    for tmpl in /etc/cloud/templates/hosts.debian.tmpl /etc/cloud/templates/hosts.redhat.tmpl; do
        if [[ -f "$tmpl" ]]; then write_block "$tmpl"; fi
    done
fi

echo "/etc/hosts uuendatud ($(hostname -s)):"
echo "$block"
