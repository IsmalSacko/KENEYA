# Fiche Google Play — Ngoni Santé

Tout ce que la console demande, prêt à coller. Les visuels sont dans ce
dossier, un sous-dossier par format. Application : `com.ismaeldev.keneya`
(l'identifiant ne change pas : c'est la même application que KENEYA+, qui
devient Ngoni Santé).

| Ce que demande la console | Fichier |
| --- | --- |
| Icône de l'application (512 × 512, PNG 32 bits) | `icone-512.png` |
| Image de présentation (1024 × 500, PNG) | `image-presentation-1024x500.png` |
| Captures — téléphone (2 à 8, 1080 × 1920) | `telephone/` |
| Captures — tablette 7 pouces (1080 × 1920) | `tablette-7/` |
| Captures — tablette 10 pouces (1440 × 2560) | `tablette-10/` |

Les captures sortent des vrais écrans de l'application, avec le vrai thème et
des données de démonstration (un CSCom de Bamako) :
`outils/polices.sh` (une fois), puis `flutter test tool/captures_store.dart`.
L'icône et l'image de présentation : `python3 outils/marque.py`.

**La fiche part avec l'app.** `python3 outils/fiche_play.py` range ces textes
et ces visuels dans `android/fastlane/metadata/android/fr-FR/` (notes de
version au numéro de build du `pubspec.yaml`) ; le workflow de déploiement les
envoie au Play Store avec l'App Bundle. Après une retouche de cette fiche ou
des captures : relancer le script, committer, déployer.

---

## Nom de l'application (30 caractères)

```
Ngoni Santé
```

## Description courte (80 caractères)

```
Le logiciel des centres de santé : accueil, file, consultation, labo, caisse.
```

## Description complète (4 000 caractères)

```
Ngoni Santé est le logiciel de gestion des établissements de santé : centre de santé (CSCom), cabinet médical ou dentaire, clinique, maternité, laboratoire, pharmacie et dépôt de médicaments. Une seule application pour toute l'équipe — accueil, soignants, laboratoire, pharmacie, caisse — chacun avec ses droits.

UNE JOURNÉE DANS L'ÉTABLISSEMENT

• L'accueil — Chaque patient a son dossier numéroté, créé une fois : on le retrouve en tapant trois lettres de son nom, son téléphone ou son numéro. Les doublons se fusionnent.

• La file d'attente — Un ticket par service, priorité aux urgences et aux femmes enceintes, écran d'appel en salle, borne d'entrée, ticket imprimé avec QR. Un seul ticket par patient, même s'il l'a pris depuis chez lui.

• Le tri et la consultation — Constantes prises au tri, retrouvées par le médecin. Motif, examen, diagnostic (CIM-10), conclusion, rendez-vous de contrôle.

• Le laboratoire — Analyses demandées en consultation, étiquette QR sur le tube, résultat hors normes en rouge, validation.

• L'ordonnance — Prescrite dans le catalogue de la pharmacie, avec prix et stock ; signée numériquement, elle se vérifie par QR, même sans connexion.

• La maternité et la vaccination — Grossesse, consultations prénatales, accouchement, carnet de vaccination selon le PEV.

• L'hospitalisation — Lits et chambres, plan de soins, bracelet QR scanné avant chaque soin.

• La caisse — Une facture par passage, Mobile Money (Orange, Moov, Wave), part de l'assurance, reçu imprimé ou envoyé par WhatsApp, clôture de caisse.

• La pharmacie — Écran de vente comme une caisse de boutique : code-barres, panier, encaissement en un geste, vente à crédit. Lots et péremption, inventaire, liste à commander au grossiste.

• Le pilotage — Rapport du mois : fréquentation, consultations par âge et sexe, diagnostics, paludisme, CPN, vaccins, recettes, comparés au mois précédent.

POUR LES PATIENTS DE L'ÉTABLISSEMENT

Les patients peuvent suivre leur ticket depuis leur téléphone, prendre rendez-vous, signaler leur arrivée et retrouver leurs ordonnances. Leur dossier médical reste fermé aux autres établissements sauf s'ils l'ouvrent eux-mêmes.

PENSÉ POUR NOS ÉTABLISSEMENTS

• En français, montants en francs CFA.
• Le numéro de téléphone suffit pour se connecter.
• Rappels par WhatsApp et notifications, sans frais de SMS.
• Fait pour les téléphones et tablettes d'entrée de gamme.

À SAVOIR

Ngoni Santé est un outil de travail pour les professionnels de santé. Ce n'est pas un dispositif médical : il ne pose pas de diagnostic et ne remplace pas l'avis d'un soignant.

Une question : ismael-dev.com
```

## Notes de version (500 caractères)

```
Notifications sur le téléphone : établissement validé, alertes pour l'équipe. Le bandeau « En attente de vérification » disparaît dès la validation. Numéro d'autorisation facultatif. Catégories de la pharmacie modifiables. Prix justes à l'écran Vendre. Stock modifiable dans la fiche produit. Boutons du bas jamais cachés. Pharmacies et dépôts : plus d'onglet Patients (Vendre, Caisse, Stock). Corrections.
```

## Catégorie et classement

| Champ | Valeur |
| --- | --- |
| Type d'application | Application |
| Catégorie | Entreprise (outil de gestion pour les professionnels de santé) |
| Balises | Gestion d'entreprise, Productivité |
| Classification du contenu | Tout public (aucun contenu sensible) |
| Public cible | 18 ans et plus |
| Application conçue pour les familles | Non |
| Contient des annonces | Non |
| Achats intégrés | Non |
| Déclaration « applications de santé » | Obligatoire pour toutes les apps : on y déclare un outil pour professionnels (gestion d'établissement), pas une app santé grand public ni un dispositif médical |

## Coordonnées

| Champ | Valeur |
| --- | --- |
| Site web | https://keneya.ismaeldev.fr |
| E-mail | à renseigner (celui qui répondra aux utilisateurs) |
| Téléphone | facultatif |
| Politique de confidentialité | https://keneya.ismaeldev.fr/confidentialite (en ligne dès que l'API est déployée) |
| Suppression du compte | https://keneya.ismaeldev.fr/suppression-compte (en place) |

## Sécurité des données — ce que déclare le formulaire

L'application collecte et transmet à `keneya.ismaeldev.fr` :

| Donnée | Collectée | Partagée | Obligatoire | Pourquoi |
| --- | --- | --- | --- | --- |
| Nom | oui | non | oui | identifier le patient et le soignant |
| Numéro de téléphone | oui | non | oui | identifiant de connexion, SMS de rappel |
| Informations de santé | oui | non | non | dossier médical, consultations, analyses, grossesse |
| Position approximative | oui | non | non | trouver un centre près de soi (jamais enregistrée) |
| Photos et vidéos | non | — | — | la caméra lit les QR, rien n'est envoyé |

Chiffrement en transit : oui (HTTPS). Le dossier médical n'est lu que par
l'établissement qui l'a écrit, ou avec l'accord du patient ; chaque ouverture
est tracée. Suppression du compte : par la page ci-dessus.

---

## Déclarations à remplir dans la console (à recopier)

**Contenu de l'application › Règles de confidentialité**
`https://keneya.ismaeldev.fr/confidentialite` (en ligne).

**Contenu de l'application › Applications de santé**
Google pose ce questionnaire à **toutes** les apps. Ngoni Santé n'est pas une
app santé grand public : c'est un outil pour les professionnels de santé.
- Fonctionnalités à cocher, et seulement elles : *Gestion des services de
  santé* (gestion d'établissement, prise de rendez-vous, dossiers tenus par
  les soignants). Ne pas cocher le suivi de la santé, le bien-être, la
  forme, ni la santé mentale.
- Dispositif médical réglementé : **Non** (aucun diagnostic, aucune
  décision de traitement automatique).
- Application d'un organisme public : **Non**.
- Données de santé : saisies par les soignants de l'établissement, chiffrées
  en transit, jamais vendues ni partagées à des tiers.

**Contenu de l'application › Suppression des données**
`https://keneya.ismaeldev.fr/suppression-compte` (en ligne).

**Coordonnées**
E-mail de contact : à choisir (celui qui répondra aux utilisateurs).

Ensuite : valider le brouillon Alpha, puis « Promouvoir la version » vers
Production quand l'essai en centre est concluant.
