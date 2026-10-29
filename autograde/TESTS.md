# Autograderi testid (Classroom 50)

Üks Classroom 50 ülesanne, esitamine **tagged commit** (tagid `k01` … `k07`). Iga päeva testid kokku **100 punkti**.
Classroom 50-s: ülesanne → Tests → lisa iga rida eraldi testina (Command = veerg "Käsk", Points = veerg "Punktid").

Autograder jooksutab iga tagi peal kõik read. `check.sh` vaatab `GITHUB_REF_NAME`-i: kui tag on `k03`, siis K4–K7
read lõpetavad kohe `SKIP` teatega (0 p, tööriistu ei laadita). K1–K3 jooksevad uuesti (regressioon).
**Iga tagi juures loe ainult selle päeva ridu.** Lokaalselt (ilma `GITHUB_REF_NAME`-ita) jooksevad kõik.

| Päev | Test | Käsk | Punktid |
|---|---|---|---|
| K1 | kohustuslik: failid, LF, skripti süntaks | `bash autograde/check.sh k01 files` | 15 |
| K1 | kohustuslik: ansible.cfg → inventory.ini | `bash autograde/check.sh k01 config` | 10 |
| K1 | kohustuslik: inventory grupid ubuntu, alma, ansible_user | `bash autograde/check.sh k01 inventory` | 15 |
| K1 | kohustuslik: syntax-check training.yml, tools.yml | `bash autograde/check.sh k01 syntax` | 25 |
| K1 | kohustuslik: training.yml file, copy, mode | `bash autograde/check.sh k01 training` | 15 |
| K1 | boonus: tools.yml when ja tags | `bash autograde/check.sh k01 tools` | 10 |
| K1 | boonus: lõpuülesanne README.txt | `bash autograde/check.sh k01 final` | 10 |
| K2 | failid ja rollid | `bash autograde/check.sh k02 files` | 10 |
| K2 | inventory: grupid, OS-grupid (ubuntu, alma), host/group vars | `bash autograde/check.sh k02 inventory` | 10 |
| K2 | mallid, handlerid, defaults, OS-tingimus | `bash autograde/check.sh k02 structure` | 10 |
| K2 | Vault, avatekstis paroole pole | `bash autograde/check.sh k02 vault` | 10 |
| K2 | teine käivitus changed=0 (`run2.txt`) | `bash autograde/check.sh k02 idempotent` | 10 |
| K2 | syntax-check | `bash autograde/check.sh k02 syntax` | 20 |
| K2 | ansible-lint | `bash autograde/check.sh k02 lint` | 30 |
| K3 | failid + saladused väljas | `bash autograde/check.sh k03 files` | 10 |
| K3 | compose valideerub | `bash autograde/check.sh k03 compose` | 15 |
| K3 | sõltuvused, volume, restart | `bash autograde/check.sh k03 deps` | 15 |
| K3 | multistage + healthcheck | `bash autograde/check.sh k03 multistage` | 15 |
| K3 | image'id versiooniga | `bash autograde/check.sh k03 tags` | 10 |
| K3 | image'id ehituvad (2–4 min) | `bash autograde/check.sh k03 build` | 35 |
| K4 | failid, state/tfvars Gitist väljas | `bash autograde/check.sh k04 files` | 15 |
| K4 | saladusi koodis pole | `bash autograde/check.sh k04 secrets` | 15 |
| K4 | fmt | `bash autograde/check.sh k04 fmt` | 10 |
| K4 | validate | `bash autograde/check.sh k04 validate` | 30 |
| K4 | provider, data, for_each, CPU, tagid, inventory | `bash autograde/check.sh k04 resources` | 15 |
| K4 | moodul | `bash autograde/check.sh k04 module` | 15 |
| K5 | workflow + K3 failid | `bash autograde/check.sh k05 files` | 10 |
| K5 | actionlint | `bash autograde/check.sh k05 actionlint` | 25 |
| K5 | build + test (push, PR, Java 21, mvn verify) | `bash autograde/check.sh k05 build` | 15 |
| K5 | needs, if, permissions, artefakt, Trivy, image ghcr.io-sse | `bash autograde/check.sh k05 structure` | 25 |
| K5 | deploy self-hosted, environment, secrets, triggerid, /version | `bash autograde/check.sh k05 deploy` | 15 |
| K5 | hügieen: saladused, @main, Node 20, Trivy SHA | `bash autograde/check.sh k05 hygiene` | 10 |
| K6 | failid (Jenkinsfile, settings.xml, Dockerfile) | `bash autograde/check.sh k06 files` | 10 |
| K6 | Build + Test + junit | `bash autograde/check.sh k06 stages` | 15 |
| K6 | oma agent (label, mitte any), tools | `bash autograde/check.sh k06 agent` | 10 |
| K6 | Sonar + quality gate (õppijapõhine projectKey) | `bash autograde/check.sh k06 quality` | 25 |
| K6 | Nexus: upload + settings.xml mirror | `bash autograde/check.sh k06 nexus` | 15 |
| K6 | saladusi pole, credentialid Jenkinsist | `bash autograde/check.sh k06 secrets` | 10 |
| K6 | triggers (pollSCM/cron/upstream) | `bash autograde/check.sh k06 triggers` | 10 |
| K6 | Docker image samast WAR-ist + koristus | `bash autograde/check.sh k06 docker` | 5 |
| K7 | manifestid + Application | `bash autograde/check.sh k07 files` | 10 |
| K7 | kubeconform -strict | `bash autograde/check.sh k07 kubeconform` | 20 |
| K7 | objektid, probe'id, resources, initContainers, init ConfigMap | `bash autograde/check.sh k07 objects` | 25 |
| K7 | hügieen: namespace, Secret, :latest, host | `bash autograde/check.sh k07 hygiene` | 15 |
| K7 | Argo CD Application | `bash autograde/check.sh k07 gitops` | 15 |
| K7 | CI uuendab image'i tagi manifestis (gitops.yml) | `bash autograde/check.sh k07 cibump` | 15 |
| – | saladused Gitis (AWS võtmed, privaatvõtmed, tfstate, kubeconfig) | `bash autograde/check.sh cloud secrets` | 0 (hoiatus) |

`cloud secrets` lisa 0-punktisena (kui Classroom 50 ei luba 0 p testi, siis 1 p). Väljundis on ainult failinimed.

## Mida autograder ei näe

- Proxmoxi VM-ide, Jenkinsi, SonarQube'i ja k3s-i päris seisu (VPN-i taga). Seda kontrollivad koolitaja skriptid
  (`klaster/jenkins/kontroll-k06.sh`, `klaster/k3s/k07-verify.sh`) ja tulemus jõuab Labori seisu.
- `k02 idempotent` loeb õppija salvestatud teise käivituse logi `k02-ansible/run2.txt` (Ansible ei jookse autograderis VM-ide vastu).

## Tööriistad autograderi runneril

`ubuntu-latest` runneril on `docker`, `jq`, `perl`, `python3`, `curl`. `check.sh` laeb ise alla (kaust `~/.cache/autograde`):
ShellCheck 0.10.0, actionlint 1.7.3, kubeconform 0.6.7, OpenTofu 1.13.1 (kui puudub või on < 1.10),
ansible-core 2.21 + ansible-lint 26.9 venv-i. `k03 build` ehitab kolm image'it (2–4 min); `k07 kubeconform` laeb skeemid GitHubist.
