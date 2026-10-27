# Ngoni Santé — cahier des charges

Version 0.1 — 26/10/2026. Refonte de Keneya (app `KENEYA`, API `KENEYA-BACK`,
app `keneya_patient`).

## 0. Décisions

| Sujet | Décision |
|---|---|
| Nom | **Ngoni Santé**, famille Ngoni (style bleu nuit / jaune, voir `REPRISE-STYLE-NGONI.md`) |
| Applications | **Une seule app** pour les patients et les professionnels. `keneya_patient` est fusionnée puis retirée. |
| Pays | Multi-pays, multi-devises, comme Ngoni Caisse |
| Cible | Hôpitaux, centres de santé (CSCom, CSRéf), cliniques, cabinets, pharmacies, laboratoires, maternités |
| Pilote | **Mali** par défaut (comme Ngoni Caisse), cible **centre de santé** |
| Identifiant Play Store | On garde `com.ismaeldev.keneya` : seul le nom affiché change, et les utilisateurs actuels reçoivent la mise à jour. |

Encore ouvert : l'établissement pilote précis (§ 14).

## 1. Principes non négociables

1. **Hors ligne d'abord.** L'accueil, la file, la caisse et la pharmacie
   continuent quand internet tombe, puis se synchronisent (base existante :
   `KENEYA-BACK/docs/OFFLINE_SYNC.md`).
2. **Le SMS est un canal à part entière.** Le patient sans smartphone reçoit
   son ticket, ses rappels de RDV et son « c'est bientôt votre tour ».
3. **Téléphones modestes.** Android 8+, 2 Go de RAM, peu de données ; l'écran
   d'affichage tourne sur une box Android TV ou un navigateur.
4. **Le patient décide.** Un établissement ne voit l'historique tenu par un
   autre établissement qu'avec l'accord du patient (QR ou code SMS).
5. **Le secret médical est cloisonné.** La caisse voit des montants, jamais un
   diagnostic. Chaque lecture d'un dossier est tracée.
6. **On démarre en 5 minutes.** Choix du profil, données de départ, et la file
   fonctionne dès le premier jour.
7. **Chaque métier a ses mots** (comme le `Jargon` de Ngoni Caisse).

## 2. Une app, plusieurs espaces

### Identité
- **Personne** : un être humain, identifié par son téléphone (pays + numéro)
  et un code SMS, puis un PIN pour l'usage courant et hors ligne.
- Une personne peut gérer des **proches** sans téléphone (enfant, parent
  âgé) : ce sont des personnes rattachées à son compte.
- Une personne peut être **membre** de zéro, un ou plusieurs établissements,
  avec un rôle dans chacun.

### Espaces dans l'app
| Espace | Pour qui | Contenu |
|---|---|---|
| **Ma santé** | tout le monde, toujours | carte QR, mes tickets en cours, mes RDV, ordonnances, résultats, reçus, mes proches, trouver un établissement |
| **Espace pro** | les membres d'un établissement | selon le rôle et les modules : accueil, file, agenda, consultation, caisse, pharmacie, labo, stock, équipe, statistiques |

On passe d'un espace à l'autre (et d'un établissement à l'autre) par un
sélecteur, comme le sélecteur de boutique de Ngoni Caisse.

### Modes établissement (même app, appareil dédié)
- **Écran d'affichage** : file d'attente en grand, annonces vocales.
  Il s'ouvre en scannant un QR d'appairage depuis l'Espace pro.
- **Borne** : prise de ticket et arrivée par QR, en plein écran verrouillé.
- **Poste guichet** : l'Espace pro réduit à « Appeler le suivant ».

Un appareil appairé n'a pas de compte personnel : il reçoit un jeton
d'appareil révocable, limité à son établissement et à son mode.

## 3. Pays et devises

Le pays est une **donnée servie par l'API**, jamais du code (même modèle que
`Pays` dans Ngoni Caisse, enrichi) :

| Champ | Exemple |
|---|---|
| code, nom, drapeau, indicatif | ML, Mali, 🇲🇱, 223 |
| devise, décimales | XOF, 0 — GHS, 2 |
| langues | fr, bm |
| fuseau | Africa/Bamako |
| moyens de paiement | espèces, Orange Money, Moov Money, Wave |
| fournisseur SMS | passerelle par pays |
| assureurs | AMO, mutuelles… (liste éditable) |
| référentiel médicaments | liste nationale importée |

Règles :
- Un établissement a **un pays et une devise**. Les montants sont stockés en
  **entiers dans l'unité mineure, avec le code devise**. Pas de conversion
  dans un établissement.
- Le patient garde sa Personne d'un pays à l'autre ; chaque établissement
  facture dans sa devise.
- Les prix d'abonnement sont fixés **par pays, en monnaie locale**.
- Interface en fr et en ; pt et ar ensuite. Les annonces vocales sont des
  fichiers enregistrés par langue (bambara, wolof…), avec repli sur la
  synthèse vocale.

## 4. Établissements, profils, modules, permissions

### Profils (choisis à la création, modifiables)
| Profil | Modules actifs par défaut |
|---|---|
| Cabinet médical | file, RDV, consultation, caisse |
| Centre de santé / CSCom | file, RDV, consultation, caisse, pharmacie, labo, maternité |
| Clinique / hôpital | tout, avec services multiples, hospitalisation, badges |
| Pharmacie / officine | file, caisse, pharmacie |
| Dépôt de médicaments | caisse, pharmacie (sans ordonnance obligatoire) |
| Laboratoire | file, RDV, labo, caisse |
| Maternité | file, RDV, maternité, consultation, caisse |
| Cabinet dentaire | file, RDV, consultation (actes dentaires), caisse |

Chaque profil fixe les modules, le vocabulaire, l'écran d'accueil, les rôles
proposés et les données de départ (services, tarifs types, médicaments
essentiels). Le plan d'abonnement borne les modules activables, et le serveur
refuse ce qui n'est pas inclus.

### Structure
`Établissement` → `Service` (Consultation, Pédiatrie, Caisse, Pharmacie, Labo…)
→ `Point de service` (Salle 2, Guichet 1, Comptoir B).

### Permissions
Un **rôle** est un ensemble de permissions (`file.appeler`,
`dossier.lire`, `caisse.encaisser`, `ordonnance.prescrire`,
`pharmacie.delivrer`…). Les rôles types (médecin, infirmier, sage-femme,
pharmacien, laborantin, caissier, accueil, gestionnaire, admin) sont créés
par le profil, et l'admin de l'établissement peut les ajuster. Ils remplacent
l'enum `App\Enums\Role`.

## 5. Le parcours patient : la visite

La **visite** est l'objet central. Elle s'ouvre quand le patient se présente
(ticket, arrivée sur RDV, urgence) et réunit tout ce qui se passe ce jour-là :

```
Arrivée ─▶ Accueil ─▶ Consultation ─▶ Caisse ─▶ Labo / Pharmacie ─▶ Sortie
   │          │            │             │              │
 ticket    dossier     actes,         facture      résultats,
 ou RDV    patient    ordonnance,     unique       délivrance
                       examens
```

- Une visite = **une facture**, des paiements partiels possibles, et une part
  assureur si besoin.
- Le passage d'un service à l'autre **transfère le ticket** : le patient ne
  refait pas la queue depuis le début.
- Une visite peut être « paiement d'abord » (CSCom, pharmacie) ou « paiement
  à la sortie » (clinique) : c'est un réglage de l'établissement.

## 6. File d'attente

### Ticket
- Numéro par service et par jour : `A012` consultation, `C004` caisse,
  `P007` pharmacie, `L003` labo (préfixes réglables).
- Pris à la **borne**, au **guichet**, **à distance dans l'app**, par **SMS**,
  ou créé automatiquement à l'arrivée sur RDV.
- Priorités : urgence > RDV à l'heure > femme enceinte / personne âgée /
  handicap > ordinaire. La règle est réglable (par exemple 1 prioritaire pour
  2 ordinaires) pour éviter que les ordinaires n'attendent indéfiniment.

### États
```
émis ─▶ appelé ─▶ en service ─▶ terminé
          │ ▲          │
          ▼ │          └─▶ transféré (nouveau ticket lié, même visite)
        absent (rappelable N fois, puis annulé)
```

### Fonctions
- « **Appeler le suivant** » sur le poste du soignant, ou appel d'un ticket
  précis.
- **Écran TV** : tickets appelés (« A012 → Salle 2 »), tickets suivants,
  annonce vocale et sonnerie. Rien de nominatif (seulement le numéro).
- **Suivi sur le téléphone** : position, attente estimée (moyenne glissante
  du service), notification « bientôt votre tour » à N tickets puis
  « c'est à vous » ; SMS si pas d'app.
- **Ticket imprimé** 58 mm en Bluetooth (code de `print_bluetooth_thermal`
  repris de Ngoni Caisse), avec le QR de suivi.
- Statistiques : attente moyenne et maximale, durée de service, absents,
  affluence par heure et par jour, charge par soignant.

### Temps réel et coupures
- En ligne : diffusion en direct via WebSocket (Laravel Reverb), avec repli
  sur interrogation toutes les 5 s.
- **Coupure d'internet** : un appareil de l'établissement est désigné
  **poste maître**. Les autres postes (guichets, écran) le joignent par le
  wifi local ; il numérote les tickets et rejoue tout vers l'API au retour du
  réseau. Si aucun poste maître n'est joignable, chaque guichet continue seul
  avec sa propre série de numéros (`A-G1-012`).

## 7. Rendez-vous

- Agenda par **praticien** et/ou par **service** : horaires, durée des
  créneaux, congés, nombre de places par créneau (consultation de masse).
- Réservation : par le patient dans l'app, par l'accueil (téléphone), ou par
  le praticien lui-même (« revenir dans 15 jours »).
- Règles de l'établissement : délai minimal, acompte éventuel par Mobile Money,
  validation manuelle ou automatique.
- Rappels : la veille et 2 h avant, par notification, SMS ou WhatsApp. Le
  patient confirme ou annule d'un geste ; la place libérée est proposée à la
  liste d'attente.
- **Arrivée par QR** : le patient scanne le QR de l'accueil (ou montre le
  sien) ; le ticket est créé avec la priorité « RDV ».
- Reprise de l'existant : `POST /public/rendez-vous` et la table
  `rendez_vous` deviennent des RDV liés à une Personne (retrouvée par
  téléphone).

## 8. QR codes

Tous les QR portent une **URL courte** `https://sante.ngoni.app/q/<jeton>`
(le domaine reste à confirmer) : un téléphone sans l'app ouvre une page web,
un téléphone avec l'app ouvre le bon écran.

| QR | Jeton | Vérification |
|---|---|---|
| Carte santé (app, imprimée, sur le carnet) | identifiant de Personne, rotation possible | ouvre la fiche **après** accord du patient (code SMS ou confirmation dans son app) |
| Ticket de file | identifiant du ticket | suivi public, sans nom |
| Rendez-vous | identifiant du RDV | arrivée |
| **Ordonnance** | contenu **signé (Ed25519)** par le serveur | la pharmacie vérifie la signature **hors ligne** ; la délivrance est marquée au serveur dès la synchro |
| Reçu | contenu signé | authenticité du paiement |
| Résultats de labo | jeton à usage limité + code | le patient les consulte |
| Établissement (affiche à l'entrée) | identifiant de l'établissement | prendre un ticket, horaires, tarifs |
| Appairage d'appareil | jeton à usage unique, 5 min | écran TV, borne, guichet |

Risque connu : deux pharmacies hors ligne pourraient délivrer la même
ordonnance. Pour le limiter, la délivrance partielle est indiquée sur
l'ordonnance, la double délivrance est signalée dès la synchro, et
l'établissement peut exiger d'être en ligne pour certains produits.

## 9. Badges

- **Badge du personnel** (QR imprimé, NFC en option) : pointage d'arrivée et
  de départ, ouverture rapide de session sur un poste partagé (badge + PIN),
  signature des actes. Rapport de présence par mois.
- **Bracelet du patient hospitalisé** (QR) : identification au lit avant un
  soin ou un médicament ; l'app refuse l'administration si le bracelet ne
  correspond pas à la prescription.
- **Badge visiteur** (option hôpital) : nom, patient visité, heure d'entrée
  et de sortie.

Impression : PDF A4 (planches de badges) via `printing`, et étiquette
thermique pour les bracelets.

## 10. Modules métier

| Module | Contenu minimal |
|---|---|
| Dossier patient | identité, date de naissance, sexe, groupe sanguin, allergies, antécédents, traitements en cours, historique des visites |
| Consultation | constantes (TA, T°, poids, taille, SpO2), motif, examen, diagnostic (CIM-10 en option), ordonnance, demandes d'examens, certificat, prochain RDV |
| Pharmacie | produits (DCI, forme, dosage, conditionnement), **lots et péremption**, vente à la boîte ou à l'unité, délivrance sur ordonnance QR, grossistes et commandes, inventaire, alertes |
| Laboratoire | catalogue d'analyses et valeurs normales, demandes, prélèvement (étiquette QR), saisie, validation, résultats envoyés au patient |
| Maternité | grossesse (CPN), accouchement, nouveau-né, vaccination de l'enfant |
| Hospitalisation | lits et chambres, admission et sortie, plan de soins, administration des médicaments (bracelet) |
| Caisse | facture de visite, tarifs par acte et par produit, paiements multiples (espèces, Mobile Money), session de caisse, remises, part assureur |
| Assurances | assureurs du pays, prise en charge en %, plafond, bordereaux à exporter |
| Statistiques | activité, recettes, file, stock, rapports mensuels exportables |

## 11. Architecture technique

### App (Flutter, un seul projet)
- Cibles : Android, iOS, web (back-office, écran TV, borne).
- Riverpod + go_router, alignés sur Ngoni Caisse.
- **Package partagé `ngoni_core`** (à extraire de Ngoni Caisse) : thème et kit
  UI, pays et formats, impression thermique et PDF, scan QR, client API,
  synchro hors ligne, authentification par téléphone.
- Les **parcours** (accueil, file, consultation, caisse, délivrance) ont de
  vrais écrans ; le CRUD générique actuel (`api_module_screen`) ne reste que
  pour les référentiels.
- Base locale SQLite (contrat `OFFLINE_SYNC.md` conservé et étendu).

### API (Laravel 12, `KENEYA-BACK`)
- Découpage par domaine : `Identite`, `Pays`, `Etablissements`, `File`,
  `RendezVous`, `Dossier`, `Consultation`, `Pharmacie`, `Labo`, `Caisse`,
  `Badges`, `Abonnements`.
- Locataire = établissement ; chaque requête pro est bornée à l'établissement
  actif (vérifié côté serveur, testé).
- Temps réel : Laravel Reverb. Tâches : files Laravel (SMS, rappels,
  statistiques).
- SMS : un fournisseur **par pays** derrière une interface unique.
- **Base distincte de Ngoni Caisse.** Les données de santé ne cohabitent pas
  avec des données commerciales ; seuls le style et le code partagé sont
  communs.
- Sécurité : chiffrement au repos des champs cliniques, journal d'accès aux
  dossiers (reprise de `JournalAudit`), sauvegardes chiffrées, durées de
  conservation réglables par pays.

## 12. Reprise de l'existant Keneya

| Aujourd'hui | Demain |
|---|---|
| `etablissements.type` (cabinet / pharmacie / cabinet_pharmacie) | profil + modules (cabinet → Cabinet médical, etc.) |
| `users` (rôle enum, téléphone + PIN) | Personne + Membre (rôle à permissions) ; on garde le PIN |
| `patients` par établissement | dossier d'établissement lié à une Personne (rapprochement par téléphone, doublons à valider) |
| `consultations` (motif + montant) | visite + consultation + ligne de facture |
| `medicaments` (un stock, une date) | produit + **un lot** reprenant stock et péremption |
| `ventes_pharmacie`, `paiements` | factures et paiements de visite |
| `rendez_vous` (public) | RDV liés à une Personne |
| app `keneya_patient` | espace « Ma santé », puis retrait du store |

Migrations réversibles, rejouées sur une copie de la production avant la
mise en ligne.

## 13. Feuille de route

Chaque lot est livrable seul (avancement : § 14). « Fini » = utilisé dans l'établissement pilote.

| Lot | Contenu | Fini quand |
|---|---|---|
| **1. Socle** | Personne, espaces, sélecteur d'établissement, pays et devises, profils et modules, permissions, renommage en Ngoni Santé, `ngoni_core` | un pro et un patient utilisent la même app ; un établissement se crée dans un autre pays avec sa devise |
| **2. File d'attente** | tickets, priorités, appel, écran TV, borne, impression, suivi sur téléphone, SMS, poste maître | une matinée complète de consultations gérée sans papier |
| **3. Rendez-vous** | agendas, réservation, rappels, arrivée par QR, carte santé QR | 80 % des RDV confirmés ou annulés via les rappels |
| **4. Visite et caisse** | visite, facture unique, Mobile Money, transfert entre services | la recette du jour sort sans calcul à la main |
| **5. Pharmacie** | lots, ordonnance QR signée, délivrance, grossistes, inventaire | une ordonnance d'un médecin est délivrée par scan |
| **6. Dossier et consultation** | dossier patient, consultation complète, accord par QR | le médecin consulte sans dossier papier |
| **7. Labo, maternité** | modules du § 10 | selon le pilote |
| **8. Hôpital** | hospitalisation, bracelets, badges, visiteurs, assurances | selon le pilote |

## 14. Avancement

### Lot 1 — 26/10/2026 (non commité ; API sur la branche `ngoni-sante-lot1`)
Fait :
- API : table `pays` (19 pays, Mali par défaut), `personnes` (un numéro =
  une personne), `users` devient le membre (`personne_id`), établissement
  avec pays, devise, profil et modules. Reprise des données existantes :
  un numéro partagé donne une seule personne (essayé sur MySQL 8.4).
- API : `/pays`, `/profils`, `/compte/*` (inscription, connexion, code SMS,
  PIN oublié, espaces, création d'établissement). Pilote SMS « journal »
  (rien ne part) ; code SMS obligatoire derrière `SANTE_VERIFICATION_TELEPHONE`.
  L'app 3.x continue de marcher (`/login`, `/register` inchangés).
- App : un seul compte, « Ma santé », espaces pro, sélecteur d'espace,
  création d'établissement par profil, écrans de `keneya_patient` repris,
  nom « Ngoni Santé ». Un utilisateur 3.x est reconnecté sans rien ressaisir.
- Changement d'espace : les opérations hors ligne en attente partent
  d'abord (sinon refus), puis le miroir local est vidé.

Fait ensuite (27/10) : permissions par module (`App\Sante\Permission`, rôle
« Accueil », réglage des droits par rôle et des modules dans l'onglet
Réglages), limites de débit nommées (un compteur par usage, pas un seul par
IP : les abonnés mobiles partagent souvent l'IP de leur opérateur).

Reste pour finir le lot 1 :
- package `ngoni_core` partagé avec Ngoni Caisse ;
- passerelle SMS réelle du Mali, puis activer la vérification du numéro ;
- retirer `keneya_patient` du store une fois cette version publiée.

### Lot 2 — file d'attente (27/10)
Fait :
- API : services (lettre, durée, ticket à distance), salles, tickets numérotés
  par service et par jour (fuseau du pays), priorités avec la règle
  anti-attente infinie, appel du suivant sans doublon, rappel, absent,
  transfert lié, position et attente estimée, SMS « c'est à vous » et
  « bientôt votre tour » (numéro mis au format international), services de
  départ selon le profil, appareils appairés par code ou QR (écran, borne),
  ticket à distance pour la personne, page web de suivi `/t/<ticket>` ouverte
  par le QR (sans l'app, jamais de nom), chiffres du jour.
- App : onglet File (poste, « Appeler le suivant », actions, liste en direct),
  « Donner un ticket », Régler la file (services, salles, écrans et bornes avec
  QR d'appairage), modes Écran de salle (annonce vocale, dernier appel en
  grand, écran toujours allumé) et Borne (3 touches, ticket avec QR,
  impression), « Prendre un ticket » et « Mes tickets » en direct dans Ma
  santé avec notification, ticket imprimé 58 mm (ESC/POS, accents retirés).
- Essayé sur l'émulateur contre l'API Docker : appel, écran de salle, borne,
  ticket à distance.

Reste :
- temps réel par WebSocket (Reverb) : aujourd'hui l'écran interroge toutes les
  3 s, la liste du guichet toutes les 5 s ;
- poste maître sur le wifi local quand internet tombe ;
- annonces enregistrées en langues locales (aujourd'hui synthèse vocale fr) ;
- impression à valider sur une vraie imprimante Bluetooth.

### Lot 3 — rendez-vous (27/10)
Fait :
- API : agendas (praticien ou service, durée, places par créneau, réservation
  en ligne, validation automatique ou par l'accueil, délai minimal, horizon),
  horaires par jour (deux plages), absences ; créneaux libres calculés dans
  le fuseau du pays et stockés en UTC ; réservation sous verrou (pas de
  surréservation) ; rendez-vous pris au téléphone par l'accueil ; actions
  confirmer, refuser, annuler, absent ; arrivée → ticket priorité « RDV » dans
  le service de l'agenda (une seule fois) ; arrivée par scan à l'accueil, à la
  borne, ou par le patient qui scanne l'affiche de l'accueil ; carte santé QR
  (jeton renouvelable, pas l'identifiant) ; rappels SMS veille et dernière
  minute (`php artisan sante:rappels-rdv`, planifiée toutes les 15 min).
- App : onglet Rendez-vous (journée, actions, nouveau rendez-vous), agendas
  (horaires par jour, absences), scan rendez-vous ou carte à l'accueil,
  affiche QR de l'accueil ; côté patient : réservation d'un créneau, Mes
  rendez-vous avec QR et annulation, « Je suis arrivé », Ma carte santé ;
  borne « J'ai un rendez-vous ». Les anciennes demandes (app 3.x, page
  publique) restent visibles et gérables.

Reste :
- liste d'attente quand une place se libère ;
- confirmation du rappel par réponse SMS (aujourd'hui : annuler dans l'app) ;
- en production, lancer le planificateur (`* * * * * php artisan schedule:run`)
  — en local : `docker exec keneya_keneya php artisan schedule:work`.

### Lot 4 — visite et caisse unifiée (27/10)
Fait :
- API : chaque ticket appartient à une visite (transfert = même visite ; la
  même personne revenue dans la journée = même visite) ; tarifs par catégorie ;
  facture unique (actes du tarif et lignes libres, quantités) ; encaissement
  dans une caisse ouverte, en plusieurs fois, jamais au-delà du reste, moyens
  de paiement du pays, référence obligatoire pour le Mobile Money ; clôture de
  caisse avec l'écart espèces comptées / attendues ; rapport du jour (facturé,
  encaissé par moyen, impayé, par catégorie) ; « mes visites » pour le patient.
  Montants en entiers dans l'unité de la devise.
- App : onglet Caisse (ouvrir / clôturer sa caisse, recherche par nom,
  téléphone ou ticket), écran de la visite (actes, paiements, encaisser),
  tarifs et rapport du jour, bouton « Facture » sur le ticket en cours,
  « Mes paiements » côté patient.

Reste :
- paiement Mobile Money initié par l'app (Orange Money, Wave…) : il faut un
  compte marchand par opérateur et par pays (question ouverte n° 5) ;
  aujourd'hui la caisse saisit la référence de la transaction ;
- reçu imprimé et reçu signé (QR vérifiable) ;
- part assureur (module Assurances, lot 8).

### Lot 5 — pharmacie (27/10)
Fait :
- API : produits (DCI, forme, dosage, unités par boîte, vente à l'unité,
  ordonnance obligatoire), lots avec péremption, délivrance par péremption la
  plus proche (jamais un lot périmé), réception des grossistes (en boîtes),
  inventaire par lot, alertes (stock bas, péremption sous 90 jours, périmés),
  le stock de l'app 3.x réaligné sur les lots ; ordonnances signées Ed25519
  (QR vérifiable hors ligne, clé publique servie), délivrées dans n'importe
  quelle pharmacie, ligne par ligne, jamais au-delà de la prescription ;
  délivrance facturée sur la visite ; reprise du stock existant en lot
  « REPRISE ».
- App : onglet Pharmacie (scanner une ordonnance — vérifiée sur le téléphone
  si internet manque —, vente au comptoir, alertes, produits et lots,
  réception, inventaire), prescription depuis la visite, « Mes ordonnances »
  côté patient. La signature PHP est vérifiée par le code Dart (test).

Reste : impression de l'ordonnance (A5/PDF) ; catalogue national des
médicaments à importer ; commandes aux grossistes.

### Lot 6 — dossier et consultation (27/10)
Fait :
- API : un dossier par personne (il la suit d'un établissement à l'autre) ;
  sans compte, il reste dans l'établissement qui l'a ouvert. La visite trouve
  le dossier par le compte du ticket ou par le numéro saisi à l'accueil.
  Consultation : motif, constantes (TA, T°, pouls, SpO₂, poids, taille,
  glycémie), examen, diagnostic et CIM-10, conclusion, date à revoir.
- **Secret médical** : un établissement voit ce qu'il a noté lui-même ;
  l'historique tenu ailleurs, seulement avec l'accord du patient — QR de son
  app (usage unique, 10 min) ou code SMS qu'il dicte —, pour 7 jours, et il
  peut le retirer. Chaque ouverture du dossier est tracée et le patient la
  voit. La caisse n'a pas le droit `dossier.lire`.
- App : bouton « Dossier et consultation » sur la visite, onglet Dossiers
  (patients vus récemment, recherche, scan du QR d'accord) ; côté patient,
  « Mon dossier » : ses consultations, ses allergies et antécédents qu'il
  note lui-même, son QR d'accord, qui y a accès, qui l'a ouvert.

Reste : demandes d'examens et certificat (avec le labo, lot 7) ; consultation
hors ligne ; un dossier sans compte qui rejoint le compte créé plus tard.

### Lot 7 — laboratoire et maternité (27/10)
Fait :
- Labo : catalogue de départ d'un centre de santé malien (TDR, goutte
  épaisse, Hb, glycémie, créatinine, groupage, test de grossesse, VIH,
  Widal, albuminurie, ECBU, selles), valeurs normales, prix par analyse
  (crée l'acte du tarif). Le médecin coche les analyses depuis le dossier :
  elles s'ajoutent à la facture de la visite. Au labo : liste « à faire »
  (urgences d'abord), étiquette du tube avec QR (imprimable), saisie, résultat
  hors normes marqué « anormal », validation. Le patient reçoit un SMS « vos
  résultats sont prêts » — jamais le résultat — et les voit dans « Mon
  dossier ». Le médecin les voit dans le dossier dès la validation.
- Maternité : déclaration de grossesse depuis la visite (DDR → terme et
  semaines), CPN numérotées (poids, TA, hauteur utérine, BCF, présentation,
  TPI, VAT, fer, moustiquaire, prochaine CPN), accouchement (heure, mode,
  jumeaux, Apgar, mort-né) : chaque enfant né vivant reçoit son dossier,
  rattaché à sa mère. Carnet de vaccination selon le calendrier du PEV
  (vaccins faits, prévus, en retard), tenu par la sage-femme ou l'infirmier.
- Côté patiente, « Grossesse et enfants » : semaines, terme, prochaine CPN,
  et le carnet de chaque enfant.

Reste : rappel SMS des CPN et des vaccins ; calendrier PEV à faire valider
par le district ; partogramme ; résultats d'analyses imprimés.

### Lot 8 — hôpital : hospitalisation, badges, visiteurs, assurances (27/10)
Fait :
- Hospitalisation : chambres et lits (prix de la nuit = acte du tarif),
  admission depuis la visite sur un lit libre, changement de lit, sortie
  (guéri, transféré, décédé…) qui ajoute les nuits à la facture. Plan de
  soins (produit, dose, voie, heures) prescrit par le médecin ; chaque prise
  du jour est à faire, faite, refusée ou non faite, « en retard » après une
  heure. **Bracelet QR** : l'infirmier le scanne avant de donner le soin ;
  si ce n'est pas le bon patient, l'app refuse. Bracelet imprimable
  (étiquette thermique, avec l'allergie en évidence).
- Badges du personnel : QR par membre (renouvelable si perdu), pointage à
  l'entrée (arrivée puis départ, double scan ignoré), présents du moment,
  présence du mois (jours, heures).
- Visiteurs : nom, patient visité (nom et lit, rien de médical), badge QR
  scanné à la sortie ; deux visiteurs au plus par patient à la fois.
- Assurances : assureurs de l'établissement (taux, plafond par visite) ; la
  caisse note l'assurance du patient sur la visite, la part de l'assureur
  sort de ce qu'il paie et suit les actes ajoutés ; bordereau du mois par
  assureur (écran et CSV) ; la part des assureurs dans le rapport du jour.
- Les refus métier (lit occupé, code faux…) ont leur propre exception
  (`App\Sante\Refus`) : un 403 ou un 404 n'est plus jamais changé en 422.

Reste : planches de badges en PDF A4 ; ouverture de session par badge + PIN
sur un poste partagé ; envoi du bordereau depuis l'app ; tiers payant sur la
pharmacie.

### Comment c'est testé
- API : `./vendor/bin/pest` (161 tests) et PHPStan niveau 9.
- App : `flutter test` (modèles, montants, signature des ordonnances) et un
  **parcours complet sur émulateur** contre l'API Docker
  (`integration_test/parcours_test.dart`) : chaque onglet, chaque fenêtre,
  saisies avec le clavier simulé ; tout débordement d'affichage le fait
  échouer. Il passe en portrait et en paysage (mise en page tablette).

## 15. Questions ouvertes

1. **Établissement pilote précis** (Mali, centre de santé). Il fixe l'ordre
   des lots 5 à 8.
2. **Domaine** des QR (`sante.ngoni.app` ?).
3. **Tarifs** : abonnement par profil ou par module ? SMS inclus ou en
   crédits ?
4. **Compte Ngoni commun** avec Ngoni Caisse (même identité, bases séparées)
   ou comptes distincts ?
5. **Comptes marchands Mobile Money** (Orange Money, Moov, Wave au Mali) :
   lesquels ouvrir, au nom de qui ? Sans eux, la caisse saisit la référence
   de la transaction, mais l'app ne déclenche pas le paiement.
6. **Passerelle SMS** du Mali (pour les codes, tickets et rappels) : quel
   fournisseur ?
