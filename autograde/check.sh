#!/usr/bin/env bash
# shellcheck disable=SC2016  # regex'ides on sõna-sõnaline \$ (nt \$ANSIBLE_VAULT), laiendust pole vaja
# Autograder: üks kontroll korraga. Väljumiskood 0 = punktid, muu = ei.
# Kasutus: bash autograde/check.sh <päev> <kontroll>    nt  bash autograde/check.sh k01 shellcheck
# Kõik kontrollid ja punktid: autograde/TESTS.md
#
# Classroom 50 jooksutab iga tagi peal kõik testid. Kui GITHUB_REF_NAME on päeva tag (k01…k07), siis
# hilisemate päevade testid lõpetavad kohe (SKIP, 0 p) ega laadi tööriistu alla. Varasemad päevad jooksevad
# (regressioon). Iga tagi juures loeb ainult selle päeva 100 p.
set -uo pipefail
shopt -s nullglob   # tühi glob = tühi loend, mitte sõna-sõnalt "k01-bash/*.sh"

day="${1:?päev puudub (k01..k07, cloud)}"
name="${2:?kontroll puudub}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLS="${AUTOGRADE_TOOLS:-$HOME/.cache/autograde}"
mkdir -p "$TOOLS"
export PATH="$TOOLS:$PATH"
AUTOGRADE_TMP=$(mktemp -d)
trap 'rm -rf "$AUTOGRADE_TMP"' EXIT
cd "$ROOT" || exit 1

# Tööriistade versioonid (kinnitatud; uuenda teadlikult ja testi lahenduse peal)
SHELLCHECK_VERSION=0.10.0
ACTIONLINT_VERSION=1.7.3
KUBECONFORM_VERSION=0.6.7
TOFU_VERSION=1.13.1          # OpenTofu uusim 1.x (endoflife.date 04.10.2026); versions.tf nõuab >= 1.10
ANSIBLE_CORE_SPEC='ansible-core==2.21.*'
ANSIBLE_LINT_SPEC='ansible-lint==26.9.*'

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "OK: $*"; exit 0; }

ref="${GITHUB_REF_NAME:-}"
# Uuesti hindamisel (regrade) on ref submit/…: otsi päeva tag, mis osutab samale commit'ile.
if [[ -n "$ref" && ! "$ref" =~ ^k0[1-7]$ ]] && command -v git > /dev/null; then
    head_sha=$(git rev-parse HEAD 2> /dev/null || true)
    ref=$(timeout 20 git ls-remote --tags origin 'k0*' 2> /dev/null \
        | awk -v h="$head_sha" '$1 == h { t = $2; sub("refs/tags/", "", t); sub(/\^\{\}$/, "", t); print t }' \
        | grep -E '^k0[1-7]$' | sort | tail -1 || true)
fi
if [[ "$ref" =~ ^k0[1-7]$ && "$day" =~ ^k0[1-7]$ && "${day#k0}" -gt "${ref#k0}" ]]; then
    echo "SKIP: $day test, aga esitatud on tag $ref"; exit 1
fi

# Kasutaja workflow'd (ilma Classroom 50 autograderi omadeta)
user_workflows() {
    local f
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        [[ -f "$f" && "$f" != *autograde* && "$f" != *classroom* ]] && echo "$f"
    done
    return 0
}
need_files() { local f; for f in "$@"; do [[ -e "$f" ]] || fail "puudub $f"; done; }

# Ansible'i kontrollid jooksevad koopia peal ilma vault.yml-ita (vault-parooli autograderil pole).
# Koopia on $AUTOGRADE_TMP all ja kustutatakse väljumisel.
ansible_copy() {
    [[ -d k02-ansible ]] || return 1
    local tmp
    tmp=$(mktemp -d -p "$AUTOGRADE_TMP")
    cp -r k02-ansible/. "$tmp/"
    rm -f "$tmp/group_vars/all/vault.yml"
    if [[ -f "$tmp/requirements.yml" ]]; then
        # Galaxy katkestuse vastu üks kordus
        ansible-galaxy collection install -r "$tmp/requirements.yml" > /dev/null 2>&1 \
            || { sleep 5; ansible-galaxy collection install -r "$tmp/requirements.yml" > /dev/null; } || return 1
    fi
    echo "$tmp"
}

# Paigaldab vajaduse korral tööriista $TOOLS alla. Peab jooksma põhishellis (mitte $(...) sees), et PATH jääks.
tool() {
    local t="$1"
    case "$t" in
        ansible-playbook|ansible-lint|ansible-galaxy)
            # Alati kinnitatud venv (PEP 668: Ubuntu 24.04 ei luba pip --user; süsteemi ansible võib olla vana)
            if [[ ! -x "$TOOLS/ansible-venv/bin/ansible-lint" ]]; then
                { python3 -m venv "$TOOLS/ansible-venv" &&
                  "$TOOLS/ansible-venv/bin/pip" install -q "$ANSIBLE_CORE_SPEC" "$ANSIBLE_LINT_SPEC"; } \
                    > "$TOOLS/ansible-pip.log" 2>&1 \
                    || { tail -5 "$TOOLS/ansible-pip.log"; fail "Ansible'i paigaldus kukkus (python3-venv olemas? PyPI kättesaadav?)"; }
            fi
            export PATH="$TOOLS/ansible-venv/bin:$PATH" ;;
        tofu)
            if ! command -v tofu > /dev/null || ! tofu version | head -1 | grep -Eq 'v1\.(1[0-9]|[2-9][0-9])\.'; then
                curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
                    | tar -xz -C "$TOOLS" tofu || fail "tofu $TOFU_VERSION paigaldus kukkus"
                hash -r
            fi ;;
        *)
            command -v "$t" > /dev/null && return 0
            case "$t" in
                shellcheck)
                    curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
                        | tar -xJ -C "$TOOLS" --strip-components=1 "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" ;;
                actionlint)
                    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" \
                        | tar -xz -C "$TOOLS" actionlint ;;
                kubeconform)
                    curl -fsSL "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
                        | tar -xz -C "$TOOLS" kubeconform ;;
                *) fail "tundmatu tööriist $t" ;;
            esac ;;
    esac
    command -v "$t" > /dev/null || fail "tööriista $t ei õnnestunud paigaldada"
}

case "$day/$name" in

# ---------- K1 Bash ----------
# Fragment koondamiseks: asendab check.sh-is kõik k01/* harud. Punktid kokku 100 (vt tests-k01.md).
# Tühi glob ei lase läbi: failide loend kogutakse nullglob'iga ja tühja loendi korral FAIL.
k01/files)
    need_files k01-bash/hosts k01-bash/websetup.sh k01-bash/webdeploy.sh k01-bash/deploy-all.sh k01-bash/check.sh \
        k01-bash/etc-hosts.sh k01-bash/services/mariadb.sh k01-bash/services/memcache.sh \
        k01-bash/services/rabbitmq.sh k01-bash/services/tomcat.sh k01-bash/services/nginx.sh
    if grep -q $'\r' k01-bash/hosts k01-bash/*.sh k01-bash/services/*.sh; then
        fail "Windowsi reavahetused (CRLF): VS Code all paremal CRLF -> LF, või .gitattributes"
    fi
    pass "kõik failid olemas, LF-reavahetused" ;;
k01/executable)
    shopt -s nullglob
    files=(k01-bash/*.sh k01-bash/services/*.sh)
    # starteri mustandid üksi ei anna punkte: õppija enda skriptid peavad olemas olema
    need_files k01-bash/websetup.sh k01-bash/webdeploy.sh
    [[ ${#files[@]} -ge 3 ]] || fail "k01-bash/ all pole skripte"
    for f in "${files[@]}"; do
        [[ -x "$f" ]] || fail "$f pole käivitatav (chmod +x; git add --chmod=+x $f)"
        head -1 "$f" | grep -q '^#!' || fail "$f: shebang puudub"
    done
    pass "${#files[@]} skripti käivitatavad" ;;
k01/syntax)
    shopt -s nullglob
    files=(k01-bash/*.sh k01-bash/services/*.sh)
    # starteri mustandid üksi ei anna punkte: õppija enda skriptid peavad olemas olema
    need_files k01-bash/websetup.sh k01-bash/webdeploy.sh
    [[ ${#files[@]} -ge 3 ]] || fail "k01-bash/ all pole skripte"
    for f in "${files[@]}"; do bash -n "$f" || fail "$f: süntaksiviga"; done
    pass "bash -n (${#files[@]} skripti)" ;;
k01/shellcheck)
    shopt -s nullglob
    files=(k01-bash/*.sh k01-bash/services/*.sh)
    # starteri mustandid üksi ei anna punkte: õppija enda skriptid peavad olemas olema
    need_files k01-bash/websetup.sh k01-bash/webdeploy.sh
    [[ ${#files[@]} -ge 3 ]] || fail "k01-bash/ all pole skripte"
    tool shellcheck
    shellcheck -S warning "${files[@]}" || fail "ShellCheck leidis vigu"
    pass "ShellCheck puhas (${#files[@]} skripti)" ;;
k01/strict)
    shopt -s nullglob
    files=(k01-bash/*.sh k01-bash/services/*.sh)
    # starteri mustandid üksi ei anna punkte: õppija enda skriptid peavad olemas olema
    need_files k01-bash/websetup.sh k01-bash/webdeploy.sh
    [[ ${#files[@]} -ge 3 ]] || fail "k01-bash/ all pole skripte"
    for f in "${files[@]}"; do
        grep -Eq '^[[:space:]]*set -[a-z]*e' "$f" || fail "$f: 'set -e' (või set -euo pipefail) puudub"
    done
    pass "skriptid peatuvad vea juures" ;;
k01/parameters)
    need_files k01-bash/websetup.sh
    grep -Eq '\$\{?1' k01-bash/websetup.sh || fail "websetup.sh ei kasuta argumenti (\$1)"
    grep -q 'os-release' k01-bash/websetup.sh || fail "websetup.sh ei tuvasta distrot (/etc/os-release)"
    if ! grep -q 'apt' k01-bash/websetup.sh || ! grep -q 'dnf' k01-bash/websetup.sh; then
        fail "websetup.sh peab toetama nii Ubuntut (apt) kui Rockyt (dnf)"
    fi
    grep -Eq '^[[:space:]]*(function[[:space:]]+)?[a-z_]+[[:space:]]*\(\)' k01-bash/websetup.sh \
        || fail "websetup.sh: vähemalt üks funktsioon puudub"
    pass "websetup.sh: argument, distro, funktsioon" ;;
k01/loop)
    need_files k01-bash/webdeploy.sh
    grep -Eq '(^|[[:space:]])(for|while)[[:space:]]' k01-bash/webdeploy.sh || fail "webdeploy.sh: tsükkel puudub"
    grep -q 'hosts' k01-bash/webdeploy.sh || fail "webdeploy.sh ei loe hostide faili"
    grep -q 'ssh' k01-bash/webdeploy.sh || fail "webdeploy.sh ei kasuta ssh-d"
    if grep -Eq 'while[[:space:]]+(IFS=[^ ]*[[:space:]]+)?read' k01-bash/webdeploy.sh \
        && ! grep -Eq 'ssh[^|]*[[:space:]]-n([[:space:]]|$)|< */dev/null|mapfile|readarray' k01-bash/webdeploy.sh; then
        fail "webdeploy.sh: while read + ssh neelab stdin-i (ssh -n, for-tsükkel või mapfile)"
    fi
    pass "webdeploy.sh käib hostid läbi" ;;
k01/secrets)
    need_files .gitignore k01-bash/websetup.sh k01-bash/webdeploy.sh k01-bash/hosts
    if git ls-files --error-unmatch k01-bash/secrets.env > /dev/null 2>&1; then
        fail "k01-bash/secrets.env on Gitis (git rm --cached k01-bash/secrets.env)"
    fi
    grep -Eq '(^|/)secrets\.env$' .gitignore || fail ".gitignore ei sisalda secrets.env"
    git ls-files k01-bash | xargs -r grep -lE '^(DB_PASSWORD|RABBITMQ_PASSWORD|TEACHER_TOKEN)=[^$]' 2> /dev/null \
        | grep -v 'example$' | grep -q . && fail "paroolid on Gitis olevas failis (ainult secrets.env.example tohib)"
    pass "saladused pole Gitis" ;;
k01/fixed)
    need_files k01-bash/services/mariadb.sh k01-bash/services/memcache.sh k01-bash/services/tomcat.sh
    grep -q "'labseis'@'%'" k01-bash/services/mariadb.sh \
        || fail "mariadb.sh: kasutaja peab tohtima tulla app01-st, mitte ainult db01-st endast"
    grep -q "'labseis'@'localhost'" k01-bash/services/mariadb.sh && fail "mariadb.sh: alles on 'labseis'@'localhost'"
    grep -q '0\.0\.0\.0' k01-bash/services/memcache.sh || fail "memcache.sh: memcached kuulab ainult 127.0.0.1"
    grep -Eq 'chown -R tomcat' k01-bash/services/tomcat.sh || fail "tomcat.sh: Tomcati kaust ei kuulu kasutajale tomcat"
    pass "starteri kolm viga parandatud" ;;
k01/report)
    need_files k01-bash/check.sh
    grep -Eq 'labseis-report|/api/results' k01-bash/check.sh || fail "check.sh ei saada tulemust Labori seisu"
    grep -v '^[[:space:]]*#' k01-bash/check.sh | grep -Eq 'curl.*/health' \
        || fail "check.sh ei kontrolli rakendust (curl .../health)"
    pass "check.sh kontrollib /health ja saadab tulemused" ;;

# ---------- K2 Ansible ----------
# Fragment check.sh case-plokki (K2). Kokku 100 p: files 10, inventory 10, structure 10, vault 10,
# idempotent 10, syntax 20, lint 30. Ansible ja ansible-lint: tool() kinnitatud venv-is
# (PEP 668); sama versioon on lab.md control node'i juhendis.
k02/files)
    need_files k02-ansible/ansible.cfg k02-ansible/inventory.ini k02-ansible/site.yml k02-ansible/requirements.yml
    for r in mariadb memcached rabbitmq tomcat nginx; do need_files "k02-ansible/roles/$r/tasks/main.yml"; done
    pass "failid ja rollid olemas" ;;
k02/inventory)
    inv=k02-ansible/inventory.ini
    need_files "$inv"
    for g in db cache queue app web; do
        grep -Eq "^\[$g\]" "$inv" || fail "$inv: grupp [$g] puudub"
    done
    # OS-grupid: K2 käsitsi [ubuntu:children]/[rocky:children], K4 OpenTofu genereerib [ubuntu]/[rocky] hostidega
    for g in ubuntu rocky; do
        grep -Eq "^\[$g(:children)?\]" "$inv" || fail "$inv: OS-grupp [$g] või [$g:children] puudub (group_vars/$g.yml)"
    done
    grep -Eq 'ansible_host=' "$inv" || fail "$inv: ansible_host puudub"
    find k02-ansible/host_vars k02-ansible/group_vars -name '*.y*ml' -not -path '*/group_vars/all/*' \
        -not -name 'all.y*ml' 2> /dev/null | grep -q . \
        || fail "muutujad ainult group_vars/all-is: lisa host_vars/<host>.yml või group_vars/<grupp>.yml"
    pass "inventory grupid, vanemgrupid ja muutujate tasemed" ;;
k02/structure)
    n=$(compgen -G 'k02-ansible/roles/*/templates/*.j2' | wc -l)
    [[ $n -ge 2 ]] || fail "Jinja2 malle (roles/*/templates/*.j2) on $n, vaja vähemalt 2 (nginx sait, rakenduse env)"
    compgen -G 'k02-ansible/roles/*/handlers/main.yml' > /dev/null || fail "handlerid (roles/*/handlers/main.yml) puuduvad"
    grep -rqs --include='*.yml' 'notify:' k02-ansible/roles || fail "ükski ülesanne ei teavita handlerit (notify:)"
    compgen -G 'k02-ansible/roles/*/defaults/main.yml' > /dev/null || fail "rollidel pole vaikeväärtusi (defaults/main.yml)"
    grep -rqs --include='*.yml' -E 'os_family' k02-ansible/roles || fail "Ubuntu/Rocky erinevus puudub (ansible_facts['os_family'])"
    grep -Eq '^collections:' k02-ansible/requirements.yml || fail "requirements.yml: collections: puudub"
    grep -Eq 'version:' k02-ansible/requirements.yml || fail "requirements.yml: collectionitel pole versioone"
    pass "mallid, handlerid, defaults, OS-tingimus, requirements" ;;
k02/vault)
    f=k02-ansible/group_vars/all/vault.yml
    need_files "$f"
    head -1 "$f" | grep -q '^\$ANSIBLE_VAULT' || fail "$f ei ole krüpteeritud (ansible-vault encrypt)"
    if git ls-files k02-ansible | grep -Eq '(^|/)\.vault_pass|vault_pass\.txt$|\.dec$'; then
        fail "vault'i parool või dekrüpteeritud fail on Gitis"
    fi
    # Avatekstis parool: võti *password*/*token*, väärtus pole muutuja ega tühi
    plain=$(grep -rnE --include='*.yml' --include='*.yaml' --exclude='vault.yml' --exclude='*.example' \
        '^\s*[A-Za-z0-9_]*(password|passwd|token)[A-Za-z0-9_]*:\s*["'"'"']?[^"'"'"'{[:space:]#]' k02-ansible \
        | grep -Ev 'update_password:|no_log:' || true)
    [[ -z "$plain" ]] || fail "avatekstis saladus (pane vault.yml-i ja viita {{ vault_... }}): $(head -1 <<< "$plain")"
    pass "saladused Vaultis" ;;
k02/idempotent)
    f=k02-ansible/run2.txt
    need_files "$f"
    recap=$(grep -E '^[A-Za-z0-9_.-]+\s+:\s+ok=[0-9]+' "$f" || true)
    [[ $(grep -c . <<< "$recap") -ge 5 ]] || fail "$f: PLAY RECAP-is pole 5 hosti (ansible-playbook site.yml | tee run2.txt)"
    if grep -Eq '(changed|failed|unreachable)=[1-9]' <<< "$recap"; then
        fail "teine käivitus pole puhas: $(grep -E '(changed|failed|unreachable)=[1-9]' <<< "$recap" | head -1)"
    fi
    pass "teine käivitus: changed=0" ;;
k02/syntax)
    [[ -d k02-ansible ]] || fail "kaust k02-ansible puudub"
    tool ansible-playbook
    work=$(ansible_copy) || fail "requirements.yml collectionite paigaldus kukkus"
    cd "$work" || fail "ajutine kaust puudub"
    # Kõik krüpteeritud failid välja; vale vault_password_file ansible.cfg-s ei tohi kontrolli kukutada
    grep -rlZ --include='*.yml' --include='*.yaml' '^\$ANSIBLE_VAULT' . | xargs -0 -r rm -f
    printf 'autograde\n' > .autograde_vault_pass
    export ANSIBLE_VAULT_PASSWORD_FILE="$work/.autograde_vault_pass"
    printf '[db]\ndb01\n[cache]\nmc01\n[queue]\nrmq01\n[app]\napp01\n[web]\nweb01\n[ubuntu:children]\nqueue\napp\nweb\n[rocky:children]\ndb\ncache\n' > inv.ini
    ansible-playbook -i inv.ini --syntax-check site.yml || fail "syntax-check kukkus (site.yml)"
    if [[ -f deploy.yml ]]; then ansible-playbook -i inv.ini --syntax-check deploy.yml || fail "syntax-check kukkus (deploy.yml)"; fi
    pass "syntax-check" ;;
k02/lint)
    [[ -d k02-ansible ]] || fail "kaust k02-ansible puudub"
    tool ansible-lint
    nq=$(grep -rn --include='*.yml' --include='*.yaml' 'noqa' k02-ansible | wc -l)
    [[ $nq -le 3 ]] || fail "# noqa on $nq korda (lubatud kuni 3, igaühel põhjendus)"
    work=$(ansible_copy) || fail "requirements.yml collectionite paigaldus kukkus"
    cd "$work" || fail "ajutine kaust puudub"
    grep -rlZ --include='*.yml' --include='*.yaml' '^\$ANSIBLE_VAULT' . | xargs -0 -r rm -f
    printf 'autograde\n' > .autograde_vault_pass
    export ANSIBLE_VAULT_PASSWORD_FILE="$work/.autograde_vault_pass"
    # Kõik reeglid kehtivad: õppija enda skip_list ei loe
    rm -rf .ansible-lint .ansible-lint.yml .ansible-lint.yaml .config/ansible-lint.yml
    ansible-lint --offline -q || fail "ansible-lint leidis vigu"
    pass "ansible-lint puhas" ;;

# ---------- K3 Docker ----------
# Asendab check.sh praegused k03/* harud. Punktid: files 10, compose 15, deps 15, multistage 15, tags 10, build 35 = 100.
# jq on GitHubi ubuntu runneril olemas; docker compose config ei vaja daemonit, docker build vajab.
k03/files)
    need_files k03-docker/app/Dockerfile k03-docker/db/Dockerfile k03-docker/web/Dockerfile \
        k03-docker/web/nginx.conf k03-docker/compose.yaml k03-docker/.env.example .dockerignore
    # Kontrollime Giti sisu, mitte töökausta: lokaalselt on .env olemas ja see on õige
    if git ls-files --error-unmatch k03-docker/.env > /dev/null 2>&1; then fail "k03-docker/.env on Gitis (git rm --cached)"; fi
    git check-ignore -q k03-docker/.env || fail ".gitignore ei hoia k03-docker/.env faili eemal"
    # .dockerignore: kas lubamisnimekiri (*) või .env ja .git selgesõnaliselt välja
    if ! grep -Eq '^\*$' .dockerignore; then
        grep -Eq '(^|/)\.env' .dockerignore || fail ".dockerignore ei jäta .env faili välja"
        grep -Eq '^/?\.git/?$' .dockerignore || fail ".dockerignore ei jäta .git kausta välja"
    fi
    pass "failid olemas, saladused Gitist ja ehituskontekstist väljas" ;;
k03/compose)
    command -v docker > /dev/null || fail "docker puudub"
    cp k03-docker/.env.example "$AUTOGRADE_TMP/autograde.env"
    docker compose -f k03-docker/compose.yaml --env-file "$AUTOGRADE_TMP/autograde.env" config -q || fail "compose.yaml ei valideeru"
    pass "compose.yaml korras" ;;
k03/deps)
    command -v jq > /dev/null || fail "jq puudub"
    cp k03-docker/.env.example "$AUTOGRADE_TMP/autograde.env"
    cfg=$(docker compose -f k03-docker/compose.yaml --env-file "$AUTOGRADE_TMP/autograde.env" config --format json) \
        || fail "compose.yaml ei valideeru"
    for s in db01 mc01 rmq01 app01 web01; do
        jq -e --arg s "$s" '.services[$s]' <<< "$cfg" > /dev/null || fail "teenus $s puudub"
        jq -e --arg s "$s" '.services[$s].restart // "" | test("always|unless-stopped|on-failure")' <<< "$cfg" > /dev/null \
            || fail "$s: restart-poliitika puudub (reboot'i järel ei tõuse)"
    done
    jq -e '.services.app01.depends_on.db01.condition == "service_healthy"' <<< "$cfg" > /dev/null \
        || fail "app01 ei oota db01 healthcheck'i (depends_on + condition: service_healthy)"
    jq -e '.services.web01.depends_on.app01' <<< "$cfg" > /dev/null || fail "web01 ei sõltu app01-st"
    jq -e '[.services.db01.volumes[]? | select(.type == "volume" and .target == "/var/lib/mysql")] | length > 0' \
        <<< "$cfg" > /dev/null || fail "db01 andmed pole nimega volume'is (/var/lib/mysql)"
    jq -e '[.services.app01.ports[]?, .services.db01.ports[]?, .services.mc01.ports[]?] | length == 0' \
        <<< "$cfg" > /dev/null || fail "app01/db01/mc01 port on hostis avatud (ainult web01 peab olema väljas)"
    pass "5 teenust, sõltuvused healthcheck'iga, volume, restart" ;;
k03/multistage)
    f=k03-docker/app/Dockerfile
    need_files "$f"
    [[ $(grep -Eic '^FROM ' "$f") -ge 2 ]] || fail "app/Dockerfile pole mitmeastmeline (vähemalt 2 FROM-i)"
    grep -Eiq '^COPY --from=' "$f" || fail "app/Dockerfile ei kopeeri WAR-i build-astmest (COPY --from=)"
    if ! grep -Eiq '^HEALTHCHECK ' "$f"; then
        cp k03-docker/.env.example "$AUTOGRADE_TMP/autograde.env"
        docker compose -f k03-docker/compose.yaml --env-file "$AUTOGRADE_TMP/autograde.env" config --format json 2> /dev/null \
            | jq -e '.services.app01.healthcheck.test' > /dev/null || fail "app01 healthcheck puudub"
    fi
    pass "multistage + healthcheck" ;;
k03/tags)
    shopt -s nullglob
    files=(k03-docker/*/Dockerfile*)
    [[ ${#files[@]} -ge 3 ]] || fail "Dockerfile'id puuduvad"
    for f in "${files[@]}"; do
        # astmete nimed (FROM x AS nimi) ei vaja tag'i, kui neile hiljem viidatakse
        stages=$(grep -Eio '^FROM .+ AS [A-Za-z0-9_.-]+' "$f" | awk '{print $NF}')
        while read -r img; do
            [[ -z "$img" ]] && continue
            grep -qxiF "$img" <<< "$stages" && continue
            [[ "$img" == *'$'* ]] && continue
            [[ "$img" == *:* || "$img" == *@sha256:* ]] || fail "$f: $img ilma tag'ita"
            [[ "$img" == *:latest ]] && fail "$f: $img (latest ei ole versioon)"
        done < <(grep -Ei '^FROM ' "$f" | sed -E 's/--platform=[^ ]+ //' | awk '{print $2}')
    done
    cp k03-docker/.env.example "$AUTOGRADE_TMP/autograde.env"
    mapfile -t imgs < <(docker compose -f k03-docker/compose.yaml --env-file "$AUTOGRADE_TMP/autograde.env" config --format json \
        | jq -r '.services[] | select(.build == null) | .image')
    [[ ${#imgs[@]} -ge 2 ]] || fail "compose'is pole ametlikke image'eid (mc01, rmq01)"
    for img in "${imgs[@]}"; do
        [[ "${img##*/}" == *:* ]] || fail "compose: $img ilma tag'ita"
        [[ "$img" == *:latest ]] && fail "compose: $img (latest ei ole versioon)"
    done
    pass "kõik image'id versiooniga" ;;
k03/build)
    command -v docker > /dev/null || fail "docker puudub"
    cp k03-docker/.env.example "$AUTOGRADE_TMP/autograde.env"
    # Compose ehitab kõik build:-iga teenused (app01, db01, web01) nende oma kontekstiga. Maveni tõttu 2–4 min.
    docker compose -f k03-docker/compose.yaml --env-file "$AUTOGRADE_TMP/autograde.env" build --quiet || fail "image'id ei ehitu"
    pass "app, db ja web image ehituvad" ;;

# ---------- K4 OpenTofu ----------
k04/files)
    need_files k04-tofu/versions.tf k04-tofu/main.tf k04-tofu/variables.tf k04-tofu/outputs.tf \
        k04-tofu/inventory.tftpl k04-tofu/terraform.tfvars.example k04-tofu/.terraform.lock.hcl
    tracked=$(git ls-files k04-tofu)
    [[ -n "$tracked" ]] || fail "k04-tofu/ failid ei ole Gitis (git add)"
    bad=$(grep -E '\.tfstate|(^|/)terraform\.tfvars$|\.auto\.tfvars$|(^|/)\.terraform/|\.tfplan$|(^|/)backend\.hcl$|crash\..*log$' <<< "$tracked" || true)
    [[ -z "$bad" ]] || fail "need ei tohi olla Gitis: $(tr '\n' ' ' <<< "$bad")(git rm --cached …, lisa .gitignore'i)"
    pass "failid olemas, state/tfvars/plan Gitist väljas" ;;
k04/secrets)
    mapfile -t tracked < <(git ls-files k04-tofu)
    [[ ${#tracked[@]} -gt 0 ]] || fail "k04-tofu/ failid ei ole Gitis"
    if grep -lE '[A-Za-z0-9._-]+@(pve|pam)![A-Za-z0-9_-]+=[0-9a-fA-F-]{36}' "${tracked[@]}"; then
        fail "API token on koodis (vt failid ülal). Tühista token koolitaja juures, kasuta TF_VAR_proxmox_api_token"
    fi
    if grep -l 'PRIVATE KEY' "${tracked[@]}"; then fail "privaatvõti on Gitis"; fi
    if grep -hv '^\s*#' "${tracked[@]}" | grep -Eq 'api_token\s*=\s*"'; then
        fail "api_token on string koodis, peab tulema muutujast (var.proxmox_api_token)"
    fi
    tfs=()
    for f in k04-tofu/*.tf; do [[ -e "$f" ]] && tfs+=("$f"); done
    [[ ${#tfs[@]} -gt 0 ]] || fail "k04-tofu/*.tf puuduvad"
    cat "${tfs[@]}" | tr '\n' ' ' | grep -Eq 'variable "[^"]*token[^"]*" *\{[^}]*sensitive *= *true' \
        || fail "tokeni muutujal puudub sensitive = true"
    pass "saladusi koodis pole, token on sensitive muutuja" ;;
k04/fmt)
    need_files k04-tofu/main.tf
    tool tofu
    tofu -chdir=k04-tofu fmt -check -recursive || fail "tofu fmt -check: vorminda (tofu fmt -recursive)"
    pass "vormindatud" ;;
k04/validate)
    need_files k04-tofu/main.tf k04-tofu/versions.tf
    tool tofu
    tofu -chdir=k04-tofu init -backend=false -input=false -lockfile=readonly > /dev/null \
        || fail "tofu init kukkus (kas .terraform.lock.hcl vastab versions.tf-ile? tofu providers lock -platform=linux_amd64)"
    tofu -chdir=k04-tofu validate || fail "tofu validate kukkus"
    pass "tofu validate" ;;
k04/resources)
    tfs=()
    while IFS= read -r f; do tfs+=("$f"); done < <(find k04-tofu -name '*.tf' -not -path '*/.terraform/*' -not -path '*/01-alused/*')
    [[ ${#tfs[@]} -gt 0 ]] || fail "k04-tofu/ .tf failid puuduvad"
    code=$(grep -hv '^\s*#' "${tfs[@]}")
    grep -q 'bpg/proxmox' <<< "$code" || fail "provider bpg/proxmox puudub"
    grep -q 'resource "proxmox_virtual_environment_vm"' <<< "$code" || fail "VM-i ressurss puudub"
    grep -q 'data "proxmox_virtual_environment_vms"' <<< "$code" || fail "mall ei tule andmeallikast (data proxmox_virtual_environment_vms)"
    grep -q 'for_each' <<< "$code" || fail "VM-id ei tule for_each abil"
    grep -Eq 'type *= *"(x86-64-v[234](-AES)?|host)"' <<< "$code" || fail "CPU tüüp puudub (Rocky 9 vajab x86-64-v2-AES)"
    grep -Eq 'tags *= *sort\(' <<< "$code" || fail "tagid ei ole sorteeritud (sort(...)): plan ei jää puhtaks"
    grep -q 'resource "local_file"' <<< "$code" || fail "inventory't ei genereerita (local_file)"
    grep -q 'templatefile(' <<< "$code" || fail "templatefile() puudub"
    grep -q 'k02-ansible/inventory.ini' <<< "$code" || fail "inventory ei lähe k02-ansible/inventory.ini-sse"
    pass "provider, andmeallikas, for_each, CPU, tagid, inventory" ;;
k04/module)
    mods=()
    for f in k04-tofu/modules/*/main.tf; do [[ -e "$f" ]] && mods+=("$f"); done
    [[ ${#mods[@]} -gt 0 ]] || fail "moodul puudub (k04-tofu/modules/<nimi>/main.tf)"
    grep -hv '^\s*#' "${mods[@]}" | grep -q 'resource "proxmox_virtual_environment_vm"' || fail "moodulis pole VM-i ressurssi"
    root=()
    for f in k04-tofu/*.tf; do [[ -e "$f" ]] && root+=("$f"); done
    [[ ${#root[@]} -gt 0 ]] || fail "k04-tofu/*.tf puuduvad"
    grep -hv '^\s*#' "${root[@]}" | grep -Eq 'source *= *"\./modules/' || fail "juurmoodul ei kasuta ./modules/…"
    grep -hv '^\s*#' "${root[@]}" | grep -q 'module\.' || fail "mooduli väljundit (module.<nimi>…) ei kasutata"
    pass "moodul ja selle väljundid" ;;

# ---------- K5 GitHub Actions (asendab praegused k05/files, k05/actionlint, k05/stages) ----------
# Kõik kontrollid loevad KÕIKI õppija workflow'sid (user_workflows), kommentaarid eemaldatakse enne grep'i.
# Tühi .github/workflows/ annab FAIL, mitte OK.
k05/files)
    mapfile -t wf < <(user_workflows)
    [[ ${#wf[@]} -gt 0 ]] || fail ".github/workflows/ ei sisalda ühtegi workflow'd"
    need_files pom.xml k03-docker/app/Dockerfile k03-docker/compose.yaml
    if git ls-files --error-unmatch k03-docker/.env > /dev/null 2>&1; then fail "k03-docker/.env on Gitis"; fi
    pass "workflow (${#wf[@]}) ja K3 failid olemas" ;;
k05/actionlint)
    tool actionlint
    mapfile -t wf < <(user_workflows)
    [[ ${#wf[@]} -gt 0 ]] || fail "workflow puudub"
    if grep -hq 'labseis' "${wf[@]}" && ! grep -qs 'labseis' .github/actionlint.yaml; then
        fail "runs-on kasutab label'it labseis: lisa see faili .github/actionlint.yaml (vt lab.md Osa 4)"
    fi
    actionlint "${wf[@]}" || fail "actionlint leidis vigu"
    pass "actionlint puhas" ;;
k05/build)
    mapfile -t wf < <(user_workflows)
    [[ ${#wf[@]} -gt 0 ]] || fail "workflow puudub"
    code=$(sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*$//' "${wf[@]}")
    grep -Eq 'pull_request' <<< "$code" || fail "PR trigger (pull_request) puudub"
    grep -Eq 'uses:[[:space:]]*actions/checkout@' <<< "$code" || fail "checkout puudub"
    grep -Eq 'uses:[[:space:]]*actions/setup-java@' <<< "$code" || fail "setup-java puudub"
    grep -Eq "java-version:[[:space:]]*['\"]?21" <<< "$code" || fail "Java 21 pole valitud (java-version: \"21\")"
    grep -Eq '(mvn|mvnw)[^|;&]*[[:space:]](verify|install)\b' <<< "$code" || fail "mvn verify puudub"
    pass "build + test igal push'il ja PR-il" ;;
k05/structure)
    mapfile -t wf < <(user_workflows)
    [[ ${#wf[@]} -gt 0 ]] || fail "workflow puudub"
    code=$(sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*$//' "${wf[@]}")
    grep -Eq '^[[:space:]]+needs:' <<< "$code" || fail "jobid pole seotud (needs:)"
    grep -Eq '^[[:space:]]+(- )?if:' <<< "$code" || fail "tingimus (if:) puudub"
    grep -Eq '^permissions:' <<< "$code" || fail "globaalne permissions: puudub (vähima õiguse põhimõte)"
    grep -Eq 'uses:[[:space:]]*actions/upload-artifact@' <<< "$code" || fail "WAR artefaktina puudub (upload-artifact)"
    grep -Eq 'uses:[[:space:]]*aquasecurity/trivy-action@' <<< "$code" || fail "Trivy job puudub"
    grep -Eq 'docker/build-push-action@|docker (image )?build' <<< "$code" || fail "image ehitus puudub"
    grep -Eq 'ghcr\.io' <<< "$code" || fail "image ei lähe ghcr.io-sse"
    grep -Eq 'GIT_SHA' <<< "$code" || fail "image ei saa commit'i (build-args: GIT_SHA=...)"
    pass "build ‖ security → image" ;;
k05/deploy)
    mapfile -t wf < <(user_workflows)
    [[ ${#wf[@]} -gt 0 ]] || fail "workflow puudub"
    code=$(sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*$//' "${wf[@]}")
    grep -Eq 'runs-on:.*self-hosted' <<< "$code" || fail "deploy ei jookse self-hosted runneril"
    grep -Eq '^[[:space:]]+environment:' <<< "$code" || fail "environment puudub"
    grep -Eo 'secrets\.[A-Za-z0-9_]+' <<< "$code" | grep -vqx 'secrets\.GITHUB_TOKEN' \
        || fail "deploy ei kasuta environment'i secret'eid (secrets.DB_PASSWORD jt)"
    grep -Eq 'workflow_dispatch' <<< "$code" || fail "workflow_dispatch puudub"
    grep -Eq 'schedule:' <<< "$code" || fail "schedule puudub"
    grep -Eq '/version' <<< "$code" || fail "deploy ei kontrolli /version"
    grep -Eq -- '--wait|until .*curl|curl[^|]*--retry' <<< "$code" || fail "deploy ei oota tervet konteinerit (sleep ei sobi)"
    pass "deploy self-hosted runneriga, triggerid, secrets" ;;
k05/hygiene)
    mapfile -t wf < <(user_workflows)
    [[ ${#wf[@]} -gt 0 ]] || fail "workflow puudub"
    if grep -nE '(ghp_|github_pat_|gho_|AKIA[0-9A-Z]{16})' "${wf[@]}"; then fail "token/võti otse failis"; fi
    if grep -inE '^[^#]*(PASSWORD|TOKEN)[A-Z_]*[:=][[:space:]]*["'\'']?[A-Za-z0-9]{6,}' "${wf[@]}" | grep -v '\${{'; then
        fail "parool otse failis: kasuta secrets.*"
    fi
    if grep -nE 'uses:[[:space:]]*[^ ]+@(main|master)\b' "${wf[@]}"; then fail "action @main/@master: kinnita versioon"; fi
    if grep -nE 'uses:[[:space:]]*(actions/(checkout|setup-java|upload-artifact|download-artifact)@v[1-4]|docker/(login-action@v[1-3]|build-push-action@v[1-6]))\b' "${wf[@]}"; then
        fail "Node 20 action'id ei tööta alates 2026. a septembrist: kasuta uusi major'eid"
    fi
    if grep -nE 'uses:[[:space:]]*aquasecurity/trivy-action@' "${wf[@]}" | grep -vE '@[0-9a-f]{40}\b'; then
        fail "trivy-action peab olema kinnitatud täis-SHA-ga (tag'id kompromiteeriti märtsis 2026)"
    fi
    pass "saladusi pole, action'id kinnitatud" ;;

# ---------- K6 Jenkins ----------
# Kommentaarid (// ja /* */) eemaldatakse enne kontrolli, et välja kommenteeritud etapp punkte ei annaks.
k06/files)
    need_files k06-jenkins/Jenkinsfile k06-jenkins/settings.xml k06-jenkins/Dockerfile
    pass "Jenkinsfile, settings.xml, Dockerfile olemas" ;;
k06/stages)
    need_files k06-jenkins/Jenkinsfile
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    grep -Eq '^[[:space:]]*pipeline[[:space:]]*\{' <<< "$code" || fail "deklaratiivne pipeline { } puudub"
    grep -Eiq "stage\([\"'][^\"']*build" <<< "$code" || fail "build etapp puudub"
    grep -Eiq "stage\([\"'][^\"']*test" <<< "$code" || fail "test etapp puudub"
    grep -q 'mvn' <<< "$code" || fail "Maven käsk puudub"
    grep -q 'junit' <<< "$code" || fail "testiraport (junit) puudub"
    pass "build ja test etapid, testiraport" ;;
k06/agent)
    need_files k06-jenkins/Jenkinsfile
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    grep -Eq 'agent[[:space:]]+any' <<< "$code" && fail "agent any: controller ei ehita, kasuta agent { label ... }"
    grep -Eq 'agent[[:space:]]*\{[[:space:]]*label' <<< "$code" || fail "agent { label '<sinu github nimi>' } puudub"
    grep -Eq "^[[:space:]]*(maven|jdk)[[:space:]]+[\"']" <<< "$code" || fail "tools { maven / jdk } puudub"
    pass "build jookseb sinu agendil" ;;
k06/quality)
    need_files k06-jenkins/Jenkinsfile
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    s=$(grep -n 'withSonarQubeEnv' <<< "$code" | head -1 | cut -d: -f1)
    q=$(grep -n 'waitForQualityGate' <<< "$code" | head -1 | cut -d: -f1)
    [[ -n "$s" ]] || fail "withSonarQubeEnv puudub"
    [[ -n "$q" ]] || fail "waitForQualityGate puudub"
    [[ "$q" -gt "$s" ]] || fail "kvaliteedivärav peab tulema pärast analüüsi"
    grep -q 'abortPipeline:[[:space:]]*true' <<< "$code" || fail "waitForQualityGate abortPipeline: true puudub"
    grep -q 'timeout' <<< "$code" || fail "timeout puudub (värav võib jääda ootama)"
    key=$(grep -Eo 'sonar\.projectKey=[^[:space:]"\\]+' <<< "$code" | head -1)
    [[ -n "$key" ]] || fail "-Dsonar.projectKey=... puudub"
    [[ "$key" == "sonar.projectKey=labori-seis" ]] && fail "projectKey peab olema õppijapõhine (labori-seis-<github>)"
    pass "SonarQube + quality gate" ;;
k06/nexus)
    need_files k06-jenkins/Jenkinsfile k06-jenkins/settings.xml
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    grep -Eq 'nexusArtifactUploader|/repository/' <<< "$code" || fail "Nexuse üleslaadimine puudub"
    grep -q 'maven-public' k06-jenkins/settings.xml || fail "settings.xml: mirror maven-public peale puudub"
    grep -q '<mirrorOf>' k06-jenkins/settings.xml || fail "settings.xml: <mirrorOf> puudub"
    grep -Eq "\-s[[:space:]]+[^[:space:]\"']*settings\.xml" <<< "$code" \
        || fail "Maven ei kasuta settings.xml-i (-s k06-jenkins/settings.xml)"
    pass "artefakt Nexusesse, sõltuvused Nexusest" ;;
k06/secrets)
    need_files k06-jenkins/Jenkinsfile
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    if grep -Eiq "(pass(word|wd)?|parool|token|secret)[A-Z_]*[[:space:]]*[=:][[:space:]]*[\"'][^\"'\$]{4,}" <<< "$code"; then
        fail "Jenkinsfile'is on saladus; pane see Jenkinsi folderi credentialiks"
    fi
    grep -Eq 'credentialsId|withCredentials' <<< "$code" || fail "credentialid ei tule Jenkinsist (credentialsId)"
    pass "saladusi pole, credentialid Jenkinsist" ;;
k06/triggers)
    need_files k06-jenkins/Jenkinsfile
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    grep -Eq 'triggers[[:space:]]*\{' <<< "$code" || fail "triggers { } plokk puudub"
    grep -Eq "pollSCM\(|cron\(|upstream\(" <<< "$code" || fail "pollSCM / cron / upstream puudub"
    pass "trigger olemas" ;;
k06/docker)
    need_files k06-jenkins/Jenkinsfile k06-jenkins/Dockerfile
    code=$(perl -0pe 's#/\*.*?\*/##gs; s#(^|\s)//[^\n]*#$1#g' k06-jenkins/Jenkinsfile)
    grep -Eq 'docker build|docker\.build' <<< "$code" || fail "Docker image etapp puudub"
    grep -Eq 'docker (rmi|image (prune|rm))|cleanWs' <<< "$code" || fail "koristus (docker rmi / prune / cleanWs) puudub"
    grep -Eq '^COPY[[:space:]].*\.war' k06-jenkins/Dockerfile || fail "Dockerfile ei kopeeri valmis WAR-i (build once)"
    pass "image samast WAR-ist, koristus" ;;

# ---------- K7 Kubernetes ----------
# Manifestid = ainult k07-k8s/ ülemise taseme *.yaml/*.yml (sama hulk, mida kubectl apply -f ja Argo CD loevad).
# Alamkaustad argocd/ ja examples/ kontrollitakse eraldi.
k07/files)
    shopt -s nullglob
    m=(k07-k8s/*.yaml k07-k8s/*.yml)
    [[ ${#m[@]} -gt 0 ]] || fail "k07-k8s/ manifestid puuduvad"
    grep -q '^kind:' "${m[@]}" || fail "k07-k8s/ failides pole ühtegi objekti (ainult TODO-d?)"
    need_files k07-k8s/argocd/application.yaml
    pass "${#m[@]} manifesti + argocd/application.yaml" ;;
k07/kubeconform)
    tool kubeconform
    shopt -s nullglob
    m=(k07-k8s/*.yaml k07-k8s/*.yml)
    [[ ${#m[@]} -gt 0 ]] || fail "k07-k8s/ manifestid puuduvad"
    # -strict: tundmatud väljad (taandeviga) on viga. Argo Application (CRD) ei tohi olla ülemisel tasemel.
    out=$(kubeconform -strict -summary "${m[@]}") || { echo "$out"; fail "kubeconform leidis vigu"; }
    echo "$out"
    grep -Eq 'Valid: [1-9]' <<< "$out" || fail "ükski objekt ei valideerunud"
    pass "manifestid valideeruvad" ;;
k07/objects)
    shopt -s nullglob
    m=(k07-k8s/*.yaml k07-k8s/*.yml)
    [[ ${#m[@]} -gt 0 ]] || fail "k07-k8s/ manifestid puuduvad"
    # Iga Deployment: nimi, readinessProbe, resources
    deps=$(awk '
        function flush() { if (kind == "Deployment") print name, r + 0, res + 0; kind = ""; name = ""; r = 0; res = 0 }
        FNR == 1 || /^---/ { flush() }
        /^kind:/ { kind = $2 }
        /^  name:/ && name == "" { name = $2 }
        /readinessProbe:/ { r = 1 }
        /resources:/ { res = 1 }
        END { flush() }' "${m[@]}")
    n=$(grep -c . <<< "$deps" || true)
    [[ $n -ge 4 ]] || fail "Deployment'e $n, vaja 4 (db01, mc01, rmq01, app01)"
    while read -r d r res; do
        [[ $r == 1 ]] || fail "Deployment $d: readinessProbe puudub"
        [[ $res == 1 ]] || fail "Deployment $d: resources puudub (ResourceQuota nõuab)"
    done <<< "$deps"
    [[ $(cat "${m[@]}" | grep -c '^kind: Service$') -ge 4 ]] || fail "Service'eid alla 4"
    grep -q '^kind: PersistentVolumeClaim' "${m[@]}" || fail "db01 PVC puudub"
    grep -q 'livenessProbe:' "${m[@]}" || fail "livenessProbe puudub"
    grep -q '^kind: Ingress' "${m[@]}" || fail "Ingress puudub"
    grep -q 'ingressClassName: *traefik' "${m[@]}" || fail "Ingress: ingressClassName: traefik puudub"
    # app01 ootab sõltuvusi init-konteineris (depends_on asendus). nslookup ei oota: Service'i DNS on olemas ka tühjana
    grep -q 'initContainers:' "${m[@]}" || fail "app01 initContainers puudub (wait-deps)"
    if grep -vhE '^\s*#' "${m[@]}" | grep -n 'nslookup'; then fail "init-konteiner nslookup'iga ei oota pod'e: kontrolli TCP-porti"; fi
    # Init ConfigMap Gitis (Argo CD ei loo käsitsi tehtud objekte) ja vastab db/schema.sql-ile
    want=$(grep -c 'CREATE TABLE' db/schema.sql)
    have=$(cat "${m[@]}" | grep -c 'CREATE TABLE' || true)
    [[ $have -eq $want ]] || fail "init ConfigMap: CREATE TABLE $have, db/schema.sql-is $want (bash k07-k8s/gen-db-init.sh)"
    pass "$n Deployment'i probe'ide ja resources'iga, Service, PVC, Ingress, initContainers, init ConfigMap" ;;
k07/hygiene)
    shopt -s nullglob
    m=(k07-k8s/*.yaml k07-k8s/*.yml)
    [[ ${#m[@]} -gt 0 ]] || fail "k07-k8s/ manifestid puuduvad"
    if grep -l '^kind: Namespace' "${m[@]}"; then fail "Namespace objekt: namespace tuleb kubeconfig'i context'ist"; fi
    if grep -nE '^\s+namespace:' "${m[@]}"; then fail "namespace: rida manifestis (eemalda)"; fi
    if grep -l '^kind: Secret' "${m[@]}"; then fail "Secret k07-k8s/ kaustas: loo see kubectl create secret'iga"; fi
    if grep -n 'muuda-mind' "${m[@]}"; then fail "näidisparool manifestis"; fi
    while read -r img; do
        [[ -n "$img" ]] || continue
        [[ "$img" == *:latest ]] && fail "image $img: :latest ei ole GitOpsis jälgitav, kasuta tagi"
        [[ "$img" =~ :[^:/]+$ || "$img" == *@sha256:* ]] || fail "image $img: tag puudub"
    done < <(grep -hE '^\s*(- )?image:' "${m[@]}" | sed -E 's/.*image:[[:space:]]*//; s/["'\'']//g; s/[[:space:]]*(#.*)?$//')
    hosts=$(grep -hE '^\s*(- )?host:' "${m[@]}" | sed -E 's/.*host:[[:space:]]*//; s/["'\'']//g; s/[[:space:]]*$//')
    [[ -n "$hosts" ]] || fail "Ingress host puudub"
    while read -r h; do
        [[ "$h" =~ ^labori-seis-[a-z0-9-]+\.lab\.hkhk\.ee$ ]] || fail "Ingress host $h: peab olema labori-seis-<github>.lab.hkhk.ee"
    done <<< "$hosts"
    while read -r rep; do
        [[ -z "$rep" || "$rep" -le 2 ]] || fail "replicas: $rep — jagatud klastris kuni 2"
    done < <(grep -hE '^\s+replicas:' "${m[@]}" | sed -E 's/.*replicas:[[:space:]]*([0-9]+).*/\1/')
    pass "namespace'i, Secret'i ja :latest'i pole, host unikaalne" ;;
k07/gitops)
    f=k07-k8s/argocd/application.yaml
    need_files "$f"
    grep -q '^apiVersion: argoproj.io/v1alpha1' "$f" || fail "$f: apiVersion argoproj.io/v1alpha1 puudub"
    grep -q '^kind: Application$' "$f" || fail "$f: kind: Application puudub"
    if grep -vE '^\s*#' "$f" | grep -nE '<[a-z-]+>'; then fail "$f: asenda <...> kohad"; fi
    grep -Eq '^\s+repoURL: *https://github\.com/' "$f" || fail "source.repoURL puudub"
    grep -Eq '^\s+path: *k07-k8s/?\s*$' "$f" || fail "source.path peab olema k07-k8s"
    grep -Eq '^\s+targetRevision: *\S' "$f" || fail "source.targetRevision puudub"
    grep -Eq '^\s+project: *is-[a-z0-9-]+\s*$' "$f" || fail "project peab olema is-<github>"
    grep -Eq '^\s+namespace: *is-[a-z0-9-]+\s*$' "$f" || fail "destination.namespace peab olema is-<github>"
    grep -Eq 'prune: *true' "$f" || fail "syncPolicy.automated.prune puudub"
    grep -Eq 'selfHeal: *true' "$f" || fail "syncPolicy.automated.selfHeal puudub"
    pass "Argo CD Application: k07-k8s, automated prune + selfHeal" ;;
k07/cibump)
    # GitOps: CI kirjutab image'i tagi manifesti, klastrisse viib Argo CD. CI-l ei tohi olla klastri võtit.
    tool actionlint
    f=""
    while read -r w; do grep -q 'workflow_run' "$w" && grep -q 'k07-k8s/40-app.yaml' "$w" && f="$w"; done < <(user_workflows)
    [[ -n "$f" ]] || fail "workflow, mis workflow_run'iga uuendab k07-k8s/40-app.yaml-i, puudub (.github/workflows/gitops.yml)"
    actionlint "$f" || fail "$f: actionlint leidis vigu"
    if grep -nE 'TODO|^\s+if: *false' "$f"; then fail "$f: TODO-d täitmata"; fi
    code=$(grep -vE '^\s*#' "$f")
    grep -Eq '\b(sed|yq)\b' <<< "$code" || fail "$f: manifesti muutmine (sed/yq) puudub"
    grep -q 'git push' <<< "$code" || fail "$f: git push puudub"
    grep -q 'change-cause' <<< "$code" || fail "$f: change-cause'i uuendus puudub (rollout history)"
    grep -Eq 'contents: *write' "$f" || fail "$f: permissions contents: write puudub"
    grep -q 'workflow_run.head_sha' "$f" || fail "$f: tag peab tulema ci jooksu commit'ist (github.event.workflow_run.head_sha)"
    grep -q 'workflow_run.conclusion' "$f" || fail "$f: kontrolli, et ci oli roheline (workflow_run.conclusion)"
    if grep -nE 'kubectl|KUBECONFIG|kubeconfig' <<< "$code"; then
        fail "$f: CI ei tohi klastrit puutuda (GitOps: Argo CD tõmbab)"
    fi
    pass "$f: CI → manifest → Argo CD" ;;

# ---------- Pilv / saladused (0 p, hoiatus) ----------
# Kasutus: bash autograde/check.sh cloud secrets
# AWS võtmed, privaatvõtmed, kubeconfig'i võtmed, tfstate ja AWS-i CSV-d ei tohi Gitis olla.
# Väljundisse lähevad ainult failinimed, mitte leitud väärtused (CI logi võib olla nähtav).
cloud/secrets)
    git rev-parse --is-inside-work-tree > /dev/null 2>&1 || fail "pole Giti repo"
    bad_files=$(git ls-files | grep -E '\.pem$|\.tfstate$|\.tfstate\.|(^|/)\.terraform/|(^|/)terraform\.tfvars$|_accessKeys\.csv$|_credentials\.csv$|(^|/)\.aws/|(^|/)k3s\.yaml$|(^|/)kubeconfig[^/]*$' \
        | grep -Ev '\.example$' || true)
    [[ -z "$bad_files" ]] || fail "need failid ei tohi Gitis olla (git rm --cached + .gitignore): $(echo "$bad_files" | paste -sd ' ' -)"
    # AKIA/ASIA + 16 märki = AWS access key ID; AWS-i dokumentatsiooni näidisvõti (…EXAMPLE) on lubatud
    key_files=$(git grep -lIE '(AKIA|ASIA)[A-Z0-9]{16}' -- . ':!autograde/**' 2> /dev/null \
        | while read -r f; do grep -EoI '(AKIA|ASIA)[A-Z0-9]{16}' "$f" | grep -vq 'EXAMPLE$' && echo "$f"; done || true)
    [[ -z "$key_files" ]] || fail "AWS access key Gitis: $(echo "$key_files" | paste -sd ' ' -)"
    secret_files=$(git grep -lIE 'aws_secret_access_key[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+]{40}' -- . ':!autograde/**' 2> /dev/null || true)
    [[ -z "$secret_files" ]] || fail "AWS secret key Gitis: $(echo "$secret_files" | paste -sd ' ' -)"
    pk_files=$(git grep -lIE -e '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' -e 'client-key-data: [A-Za-z0-9+/=]{20,}' -- . ':!autograde/**' 2> /dev/null || true)
    [[ -z "$pk_files" ]] || fail "privaatvõti Gitis: $(echo "$pk_files" | paste -sd ' ' -)"
    pass "AWS võtmeid, privaatvõtmeid ega state'i Gitis pole" ;;

*) fail "tundmatu kontroll: $day/$name" ;;
esac
