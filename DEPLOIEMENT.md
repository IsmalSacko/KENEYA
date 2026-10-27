# 🚀 Déploiement KENEYA+ — Aide-mémoire

Application Flutter **`com.ismaeldev.keneya`** publiée sur Google Play via
**GitHub Actions + fastlane**. Signature release automatique, upload sur la
piste de **test fermé (Alpha)** en brouillon.

- Dépôt : https://github.com/IsmalSacko/KENEYA (branche unique : `main`)
- Workflow : `.github/workflows/deploy-android.yml`
- fastlane : `android/fastlane/` (lane `deploy`, paramètre `track`, défaut `alpha`)

---

## 📦 Publier une nouvelle version

```bash
# 1. Incrémenter la version dans pubspec.yaml
#    version: 3.0.1+8   ← le numéro de build (+N) DOIT toujours augmenter

# 2. Committer sur main
git add pubspec.yaml
git commit -m "Version X"
git push origin main

# 3. Créer et pousser le tag → déclenche le déploiement
git tag v3.0.1
git push origin v3.0.1

# 4. Suivre le déploiement en direct
gh run watch
```

> Le workflow se déclenche **uniquement** sur un tag `v*` (ou manuellement).
> Un simple `git push origin main` ne déploie pas.

### Déclenchement manuel (choix de la piste)
```bash
gh workflow run "Déploiement Android (Play Store)"        # défaut: alpha
# ou depuis l'UI : onglet Actions → Run workflow → choisir la piste
```
Pistes possibles : `alpha` (test fermé), `internal`, `beta`, `production`.

---

## 👀 Suivre / piloter les runs (GitHub CLI)

```bash
gh run list                    # historique des runs
gh run list --limit 5          # 5 derniers
gh run watch                   # suit le run en cours, en direct
gh run view                    # détail du dernier run
gh run view --log              # logs complets
gh run view <id> --log-failed  # uniquement les steps en échec
gh run rerun <id>              # relancer un run échoué
gh run cancel <id>             # annuler un run en cours
```

---

## ✅ Dernière étape (manuelle, Play Console)

Après un run réussi, la release est en **brouillon** :

1. https://play.google.com/console → app **KENEYA+**
2. *Tests → Tests fermés - Alpha*
3. La release apparaît → **Modifier la release → Examiner → Déployer**

---

## 🔐 Secrets & configuration (déjà en place)

### Secrets GitHub (Settings → Secrets and variables → Actions)
| Secret | Contenu |
|--------|---------|
| `KEYSTORE_BASE64` | keystore `.jks` encodé en base64 |
| `KEYSTORE_PASSWORD` | mot de passe du keystore |
| `KEY_PASSWORD` | mot de passe de la clé |
| `KEY_ALIAS` | `keneya` |
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON du compte de service Google Play |

### Fichiers locaux (⚠️ gitignorés — ne jamais committer)
- `android/app/keneya-release.jks` — keystore de signature
- `android/key.properties` — mots de passe de signature
- `keneya-*.json` — clé du compte de service Google

> **CRITIQUE** : sauvegarde `keneya-release.jks` + son mot de passe hors machine.
> Sa perte = **impossible de publier une mise à jour** de l'app, définitivement.

### Compte de service Google
`github-actions@keneya-503217.iam.gserviceaccount.com` (projet Cloud `keneya-503217`,
rôle *Administrateur des versions* dans la Play Console).

---

## 🛠️ Builds locaux (hors CI)

```bash
flutter build appbundle --release   # AAB → build/app/outputs/bundle/release/app-release.aab
flutter build apk --release         # APK → build/app/outputs/flutter-apk/app-release.apk
flutter build web --release         # Web → build/web/
```

Vérifier la signature d'un APK :
```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔧 Première config `gh` (déjà fait, pour mémoire)

```bash
gh auth login    # GitHub.com → SSH → clé id_ed25519 → autoriser dans le navigateur
```

## 🌿 Git — une seule branche

Le projet n'utilise que `main`. Push via SSH (clé `~/.ssh/id_ed25519`) :
```bash
git push origin main
```
