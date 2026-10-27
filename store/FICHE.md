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
Accueil, consultation, labo, maternité, caisse : le centre de santé en une app.
```

## Description complète (4 000 caractères)

```
Ngoni Santé fait tourner un centre de santé, un cabinet, une clinique ou une pharmacie dans une seule application — et donne au patient, dans la même application, son ticket, ses rendez-vous et son dossier.

UNE JOURNÉE AU CENTRE DE SANTÉ

• L'accueil — Le patient est enregistré une seule fois : nom, âge, téléphone, quartier. Le lendemain, on le retrouve en tapant trois lettres de son nom. Un enfant amené avec le téléphone de sa mère reste un patient à part.

• La file d'attente — Un ticket par service, l'urgence et les femmes enceintes d'abord, sans oublier ceux qui attendent depuis le matin. Écran d'appel en salle, borne, ticket imprimé avec QR, et SMS « c'est bientôt à vous » : plus personne ne fait le pied de grue devant la porte.

• Le tri — L'infirmier note la tension, la température, le poids. Le médecin les retrouve dans sa consultation, déjà remplies.

• La consultation — Motif, examen, diagnostic (CIM-10 au besoin), conclusion, date à revoir. Le dossier montre les allergies en rouge.

• Le dossier qui suit le patient — D'un centre à l'autre, avec son accord : il montre un QR ou dicte un code reçu par SMS, et le soignant voit son historique pendant 7 jours. Le patient voit qui a ouvert son dossier.

• Le laboratoire — Le médecin coche les analyses, elles arrivent au labo et sur la facture. Étiquette QR sur le tube, résultat hors normes en rouge, validation, et le patient est prévenu par SMS que ses résultats sont prêts.

• L'ordonnance — Signée numériquement : n'importe quelle pharmacie Ngoni Santé la vérifie en scannant son QR, même sans connexion.

• La maternité — Grossesse et terme, consultations prénatales (TPI, VAT, fer), accouchement, dossier du nouveau-né, carnet de vaccination selon le PEV avec rappel SMS la veille.

• L'hospitalisation — Lits et chambres, plan de soins heure par heure, bracelet QR scanné au lit avant chaque soin : si ce n'est pas le bon patient, l'application refuse.

• La caisse — Une seule facture pour toute la visite. Le ticket de consultation est facturé dès l'accueil. Espèces, Orange Money, Moov, Wave ; part de l'assurance déduite ; clôture de caisse avec l'écart du tiroir.

• La pharmacie — Lots et dates de péremption (le plus proche sort d'abord, jamais un périmé), vente au comptoir, délivrance d'ordonnance par scan, alertes de stock.

• L'équipe — Chacun voit ce qui le concerne : la caisse ne lit pas les dossiers médicaux. Badges QR pour le pointage, visiteurs enregistrés à l'entrée.

POUR LE PATIENT

La même application lui donne son ticket depuis chez lui, ses rendez-vous et leurs rappels, sa carte santé QR, ses ordonnances, ses résultats d'analyses, le suivi de sa grossesse et le carnet de vaccination de ses enfants. Il garde la main sur son dossier : c'est lui qui l'ouvre à un nouveau soignant, et il peut retirer cet accès.

PENSÉE POUR NOS CENTRES

• En français, montants en francs CFA et dans la devise de chaque pays.
• Le numéro de téléphone suffit : pas d'adresse e-mail.
• Faite pour les téléphones et tablettes d'entrée de gamme.

À SAVOIR

Ngoni Santé est un outil de travail pour les soignants et un carnet pour le patient. L'application ne pose pas de diagnostic et ne remplace pas une consultation.

Une question : keneya.ismaeldev.fr
```

## Notes de version (500 caractères)

```
KENEYA+ devient Ngoni Santé : une seule application pour l'établissement et le patient. Fiche patient et tri, file d'attente avec SMS, rendez-vous, consultation, dossier partagé avec l'accord du patient, laboratoire, maternité et vaccination, hospitalisation avec bracelet QR, caisse unique avec Mobile Money et assurances, pharmacie par lots.
```

## Catégorie et classement

| Champ | Valeur |
| --- | --- |
| Type d'application | Application |
| Catégorie | Médecine |
| Balises | Gestion d'entreprise, Santé |
| Classification du contenu | Tout public (aucun contenu sensible) |
| Public cible | 18 ans et plus |
| Application conçue pour les familles | Non |
| Contient des annonces | Non |
| Achats intégrés | Non |
| Déclaration « applications de santé » | Oui : gestion d'établissement de santé et dossier patient ; ce n'est pas un dispositif médical, il ne pose pas de diagnostic |

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

## Ce qui manque avant de publier

1. **Déployer l'API** : la page `/confidentialite` doit répondre avant de
   l'indiquer à Play (une application de santé est refusée sans elle).
2. **L'e-mail de contact** de la fiche.
3. **La déclaration « applications de santé »** dans la console (Contenu de
   l'application).
