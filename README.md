# IS1-26 · Labori seis

Sinu kursuse repo. Siin ehitad seitsme laupäeva jooksul sama rakenduse (Labori seis) üles seitse korda: skriptidega,
Ansible'iga, konteinerites, OpenTofuga, pipeline'iga ja Kubernetesis.

## Kuidas siin töötada

1. 1. kohtumisel töötad kaustas `k01/` otse `main`-il. Alates 2. kohtumisest alusta uuel harul (`git switch -c k02-ansible` jne).
2. Tee päeva issue'd läbi (GitHub → Issues, milestone `K1` … `K7`). Sulge issue commit'iga: `git commit -m "k01: training.yml (closes #3)"`.
3. Päeva lõpus tag ja push (alates 2. kohtumisest enne PR `main`-i ja merge):

   ```bash
   git switch main && git pull
   git tag k01 && git push origin k01
   ```

   Tag `k01` on esitamine. Autograder jookseb tagi peal, tulemus on Classroom 50-s.
4. Parandus pärast esitamist: uus commit, siis tag uuesti (`git tag -f k01 && git push -f origin k01`). Lubatud üks hilinenud kord.

## Kui jäid maha

Koolitaja lahendused on harudel `lahendus/k01` … `lahendus/k07`. Võta eelmise päeva lahendus ja jätka sealt:

```bash
git remote add kursus https://github.com/hkhk-tk/lahendused.git   # üks kord
git fetch kursus
git merge kursus/lahendus/k01 --allow-unrelated-histories
```

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
