# Assets graphiques Google Play — KENEYA

Générés par [`generate.py`](generate.py) (HTML/CSS → Chrome headless → PNG).
Régénérer : `python3 generate.py` (nécessite `google-chrome` + `python3-pil`).
Tous les fichiers sont dans [`out/`](out/), aux **dimensions exactes** exigées et **bien en dessous** des limites de poids.

## Correspondance avec les champs de la Play Console

| Champ Play Console | Fichier(s) | Format exigé | Statut |
|---|---|---|---|
| **Icône de l'application** * | `icon_512.png` | PNG, 512×512, ≤1 Mo | ✅ 512×512, ~112 Ko |
| **Image de présentation** * | `feature_graphic_1024x500.png` | PNG/JPEG, 1024×500, ≤15 Mo | ✅ 1024×500, ~257 Ko |
| **Captures téléphone** * (2 à 8, ≥4 en 1080×1080 min pour la promo) | `phone_1.png` … `phone_6.png` | PNG, 9:16, côté 320–3840 px | ✅ 6× 1080×1920 |
| **Captures tablette 7"** * (2 à 8) | `tablet7_1.png`, `tablet7_2.png` | PNG, 16:9 ou 9:16, côté 320–3840 px | ✅ 2× 1920×1080 |
| **Captures tablette 10"** * (2 à 8) | `tablet10_1.png`, `tablet10_2.png` | PNG, 16:9 ou 9:16, côté 1080–7680 px | ✅ 2× 2560×1440 |
| **Captures Chromebook** (4 à 8) | `chromebook_1.png`, `chromebook_2.png` | PNG, 16:9 ou 9:16, côté 1080–7680 px | ⚠️ 2 fournies (4 min si utilisé) |
| **Vidéo** | — | URL YouTube publique/non répertoriée, sans pub | Optionnel, non fourni |
| **Android XR** | — | 4 à 8 captures | Optionnel, non fourni |

\* = obligatoire pour publier.

## Contenu des captures

| # | Écran | Message |
|---|---|---|
| 1 | Connexion (téléphone + PIN) | Connexion sécurisée |
| 2 | Tableau de bord (stats + graphe) | Pilotez votre établissement |
| 3 | Liste patients + recherche | Dossiers patients centralisés |
| 4 | Consultation + ordonnance | Consultations & ordonnances |
| 5 | Pharmacie / stock (alertes rupture) | Pharmacie & gestion de stock |
| 6 | Mode hors-ligne + synchro | 100 % hors-ligne |

Tablettes/Chromebook : interface deux volets (tableau de bord ; liste + fiche patient maître-détail).

## Charte

- Secteur **santé** (KENEYA = « santé » en bambara), Mali.
- Couleurs : teal `#0d9488` → emerald `#10b981` (dégradé de marque), neutres slate, accents danger/amber.
- Marque : croix médicale blanche + tracé de pouls (ECG).
- Données affichées = **fictives** (mockups marketing), cohérentes avec le métier (paludisme, médicaments courants, mobile money).

## Remarques importantes

- **Captures = maquettes marketing** (rendu HTML), pas des captures de l'app réelle. Google l'accepte, mais elles doivent rester **représentatives** de l'app. Quand l'app tourne sur un vrai appareil, tu peux remplacer par de vraies captures si tu préfères.
- Pour avoir le **droit de promouvoir** l'appli : au moins **4** captures téléphone ≥ 1080×1080 → OK (6 fournies en 1080×1920).
- Si tu ajoutes les captures **Chromebook**, il en faut **4 à 8** : régénère avec 2 captures de plus (ou réutilise `tablet10_*`).
