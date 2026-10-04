#!/usr/bin/env bash
# Paigaldab Jenkinsi agendi sinu control node'ile (inbound, WebSocket) ja teeb sellest systemd teenuse.
# Ühendus käib ainult agendilt controllerile (VPN-i kaudu); Jenkins ei vaja SSH-d sinu masinasse.
#
# Kasutus (control node'il, Ubuntu 24.04):
#   sudo JENKINS_SECRET=<saladus> ./jenkins-agent.sh <github-kasutajanimi>
# Saladus: Jenkins → Manage Jenkins → Nodes → <sinu nimi> (lehel on käsk, -secret järel olev pikk hex).
# Keskkond: JENKINS_URL (vaikimisi http://jenkins.lab.hkhk.ee:8080)
set -euo pipefail

name="${1:?github kasutajanimi (= node nimi Jenkinsis)}"
name="${name,,}"
url="${JENKINS_URL:-http://jenkins.lab.hkhk.ee:8080}"
url="${url%/}"
: "${JENKINS_SECRET:?JENKINS_SECRET puudub (vt Nodes → $name)}"
home=/opt/jenkins
java_home=/usr/lib/jvm/java-21-openjdk-amd64   # peab klappima JCasC tööriistaga 'jdk21'

if [[ $EUID -ne 0 ]]; then
    echo "Käivita sudo-ga" >&2
    exit 1
fi

# Proxmoxi mallist loodud VM: cloud-init võib apt-i veel hoida
if command -v cloud-init > /dev/null; then
    cloud-init status --wait > /dev/null || true
fi

apt_get() { DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 -y -qq "$@"; }
apt_get update
apt_get install openjdk-21-jdk-headless git curl

if [[ ! -x "$java_home/bin/java" ]]; then
    echo "FAIL: $java_home/bin/java puudub (kas masin on amd64 Ubuntu?)" >&2
    exit 1
fi

# Teenuse kasutaja: sama nimi mis controlleris, kuid see on sinu masina kasutaja
if ! id jenkins > /dev/null 2>&1; then
    useradd --system --home-dir "$home" --create-home --shell /bin/bash jenkins
fi
install -d -o jenkins -g jenkins -m 750 "$home"

# Docker etapp (K6 plokk 30). docker grupp = root-õigus SELLES masinas, mitte controlleris.
if getent group docker > /dev/null; then
    usermod -aG docker jenkins
else
    echo "Hoiatus: docker grupp puudub (K3 Docker paigaldamata?), Docker etapp ei tööta" >&2
fi

# agent.jar tuleb controllerist, nii on versioonid alati kooskõlas
curl -fsSL "$url/jnlpJars/agent.jar" -o "$home/agent.jar.new"
mv "$home/agent.jar.new" "$home/agent.jar"
chown jenkins:jenkins "$home/agent.jar"

# Saladus failis (mitte käsureal), et see ei paistaks `ps` väljundis
( umask 077 && printf '%s\n' "$JENKINS_SECRET" > "$home/secret" )
chown jenkins:jenkins "$home/secret"

cat > /etc/systemd/system/jenkins-agent.service <<EOF
[Unit]
Description=Jenkinsi agent $name ($url)
After=network-online.target
Wants=network-online.target

[Service]
User=jenkins
Group=jenkins
WorkingDirectory=$home
ExecStart=$java_home/bin/java -jar $home/agent.jar -url $url/ -name $name -secret @$home/secret -webSocket -workDir $home
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jenkins-agent > /dev/null
# restart: uus protsess saab ka uue docker grupi
systemctl restart jenkins-agent

for _ in $(seq 1 20); do
    if journalctl -u jenkins-agent --since "-1min" --no-pager | grep -q 'Connected'; then
        echo "OK: agent $name ühendus controlleriga olemas"
        exit 0
    fi
    sleep 3
done
echo "FAIL: agent ei ühendunud. Vaata: journalctl -u jenkins-agent -n 30" >&2
journalctl -u jenkins-agent -n 15 --no-pager >&2
exit 1
