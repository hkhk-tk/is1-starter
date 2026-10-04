#!/usr/bin/env bash
# app01: Java 21 + Tomcat 10.1 + labori-seis.war. Ubuntu.
# Keskkond: DB_PASSWORD, RABBITMQ_PASSWORD, TEACHER_TOKEN (kohustuslikud)
#           WAR_URL (kui /tmp/labori-seis.war puudub)
#           TOMCAT_VERSION, TOMCAT_URL (klassis koolitaja peegel; vaikimisi archive.apache.org)
set -euo pipefail
# MUSTAND: kui rakendus ei vasta, vaata app01-s journalctl -u tomcat -n 50
: "${DB_PASSWORD:?}" "${RABBITMQ_PASSWORD:?}" "${TEACHER_TOKEN:?}"
TOMCAT_VERSION="${TOMCAT_VERSION:-10.1.60}"
TOMCAT_URL="${TOMCAT_URL:-https://archive.apache.org/dist/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz}"
TOMCAT_HOME=/opt/tomcat

timeout 900 cloud-init status --wait > /dev/null 2>&1 || true

export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=120 update -qq
apt-get -o DPkg::Lock::Timeout=120 install -y -qq openjdk-21-jre-headless curl
JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")

id tomcat > /dev/null 2>&1 || useradd --system --home "$TOMCAT_HOME" --shell /usr/sbin/nologin tomcat

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Tomcat: lae alla ainult siis, kui see versioon puudub
if [[ ! -d "$TOMCAT_HOME-$TOMCAT_VERSION" ]]; then
    curl -fsSL "$TOMCAT_URL" -o "$tmp/tomcat.tgz"
    mkdir -p "$TOMCAT_HOME-$TOMCAT_VERSION"
    tar -xzf "$tmp/tomcat.tgz" -C "$TOMCAT_HOME-$TOMCAT_VERSION" --strip-components=1
    rm -rf "$TOMCAT_HOME-$TOMCAT_VERSION"/webapps/*
fi
ln -sfn "$TOMCAT_HOME-$TOMCAT_VERSION" "$TOMCAT_HOME"

# Rakenduse seadistus: paroolid ainult siin failis, mitte Gitis ega WAR-is
install -d -m 750 -o root -g tomcat /etc/labori-seis
cat > /etc/labori-seis/env <<ENV
DB_HOST=db01
DB_PASSWORD=${DB_PASSWORD}
MEMCACHED_HOST=mc01
RABBITMQ_HOST=rmq01
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
TEACHER_TOKEN=${TEACHER_TOKEN}
ENV
chmod 640 /etc/labori-seis/env
chown root:tomcat /etc/labori-seis/env

# Type=simple + "catalina.sh run": Tomcat jääb esiplaanile ja systemd jälgib otse JVM-i.
# SuccessExitStatus=143: JVM lõpetab SIGTERM-i peale koodiga 143, see ei ole viga.
cat > /etc/systemd/system/tomcat.service <<UNIT
[Unit]
Description=Apache Tomcat ${TOMCAT_VERSION} (labori-seis)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=tomcat
Group=tomcat
EnvironmentFile=/etc/labori-seis/env
Environment=JAVA_HOME=${JAVA_HOME}
Environment=CATALINA_HOME=${TOMCAT_HOME}
Environment=CATALINA_BASE=${TOMCAT_HOME}
Environment=CATALINA_OPTS=-Xmx512m
ExecStart=${TOMCAT_HOME}/bin/catalina.sh run
SuccessExitStatus=143
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

# WAR: kohalik fail või allalaadimine. Alati enne ajutisse faili, siis install:
# Tomcat ei tohi webapps/ all poolikut faili näha.
if [[ -f /tmp/labori-seis.war ]]; then
    cp /tmp/labori-seis.war "$tmp/ROOT.war"
else
    : "${WAR_URL:?Pole /tmp/labori-seis.war ega WAR_URL-i}"
    curl -fsSL "$WAR_URL" -o "$tmp/ROOT.war"
fi
install -o tomcat -g tomcat -m 644 "$tmp/ROOT.war" "$TOMCAT_HOME/webapps/ROOT.war"

systemctl daemon-reload
systemctl enable tomcat
systemctl restart tomcat

echo "Ootan, kuni rakendus vastab..."
for _ in $(seq 1 60); do
    if curl -fsS http://localhost:8080/version > /dev/null 2>&1; then
        echo "Tomcat valmis: $(curl -fsS http://localhost:8080/version)"
        exit 0
    fi
    sleep 2
done
echo "Rakendus ei vasta 2 minuti jooksul. Vaata: journalctl -u tomcat -n 100" >&2
exit 1
