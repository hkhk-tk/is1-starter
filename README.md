# IS1-26 · Labori seis

Kursuse repositoorium. Siin ehitad seitsme laupäeva jooksul sama rakenduse (Labori seis) üles seitse korda: skriptidega,
Ansible'iga, konteinerites, OpenTofuga, pipeline'iga ja Kubernetesis.

## Kuidas siin töötada

Iga kohtumise failid lähevad oma kausta, 1. kohtumisel kausta `k01/`. Juhendid on kursuse saidil: <https://hkhk-tk.github.io/is1-automatiseerimine/>.

Töö esitatakse tag'iga. Päeva lõpus tee commit, saada see GitHubi ja lisa tag:

```bash
git push
git tag k01 && git push origin k01
```

Automaatne hindaja kontrollib tag'iga märgitud versiooni ja tulemus ilmub Classroom 50-s. Kui pead pärast esitamist midagi parandama, tee uus commit ja saada tag uuesti: `git tag -f k01 && git push -f origin k01`.

Küsimused: <https://github.com/hkhk-tk/is126-arutelu/discussions>.

## Kaustad

| Kaust | Päev | Mis seal on / mis sinna tuleb |
|---|---|---|
| `src/`, `pom.xml`, `db/` | — | rakenduse kood (ei muuda) |
| `scripts/labseis-report.sh` | K1 → | tulemuse saatmine Labori seisu |
| `k01/` | K1 | `prepare-training.sh`, `ansible.cfg`, `inventory.ini`, `training.yml`, `tools.yml` |
| `k02-ansible/` | K2 | `ansible.cfg`, `inventory.ini`, `site.yml`, `deploy.yml`, `requirements.yml`, `roles/`, `group_vars/`, `host_vars/`, `group_vars/all/vault.yml` (krüpteeritud), `run2.txt` |
| `k03-docker/`, `.dockerignore` | K3 | `app/`, `db/`, `web/` Dockerfile'id, `web/nginx.conf`, `compose.yaml`, `.env.example` |
| `k04-tofu/` | K4 | `versions.tf`, `variables.tf`, `locals.tf`, `data.tf`, `main.tf`, `outputs.tf`, `inventory.tf` + `inventory.tftpl`, `modules/vm/`, `terraform.tfvars.example`, `.terraform.lock.hcl` |
| `.github/workflows/`, `.github/actionlint.yaml` | K5, K7 | `ci.yml` (K5), valikuline `smoke.yml`, `gitops.yml` (K7) |
| `k06-jenkins/` | K6 | starteris abiskriptid `jenkins-agent.sh`, `trigger-jenkins.sh`. Sina: `Jenkinsfile`, `settings.xml`, `Dockerfile` |
| `k07-k8s/` | K7 | starteris manifestide mustandid TODO-dega + `gen-db-init.sh`, `argocd/application.yaml` mall |
| `cloud/` | kodutöö | `aws-leftovers.sh` (AWS-i lõpukontroll); pilve kodutööde failid |
| `autograde/` | — | autograderi kontrollid (ei muuda); kõik testid: `autograde/TESTS.md` |

## Kontrolli enne tagi ise

```bash
bash autograde/check.sh k01 files
bash autograde/check.sh k01 training
# kõik päeva testid korraga
grep -oE 'check\.sh k01 [a-z]+' autograde/TESTS.md | while read -r _ d t; do bash autograde/check.sh "$d" "$t"; done
```

## Saladused

Paroole, tokeneid, `.env`, `secrets.env`, `terraform.tfvars`, `*.auto.tfvars`, `*.tfplan`, `backend.hcl`, `*.tfstate`,
kubeconfig'e, `*.pem` ja AWS-i võtmefaile ei panda Giti. `.gitignore` hoiab neid eemal; autograder kontrollib
(`bash autograde/check.sh cloud secrets`).
