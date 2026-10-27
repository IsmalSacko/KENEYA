// Parcours de l'app sur un émulateur, contre l'API locale (Docker) :
// chaque écran et chaque fenêtre est ouvert, du texte est saisi (le vrai
// clavier s'ouvre). Le moindre débordement d'affichage fait échouer le test.
//
//   flutter test integration_test -d emulator-5556 \
//     --dart-define=API_URL=http://10.0.2.2:8000/api
//
// Compte de démo : 70000001 / 1234, avec le « CSCom de Hamdallaye ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keneya_plus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Fait défiler la page (vers le haut, puis vers le bas) jusqu'à l'élément,
  /// comme quelqu'un qui cherche un bouton sorti de l'écran.
  Future<void> chercher(WidgetTester t, Finder f) async {
    for (final sens in [800.0, -800.0]) {
      for (var i = 0; i < 6 && f.evaluate().isEmpty; i++) {
        final listes = find.byType(Scrollable);
        if (listes.evaluate().isEmpty) return;
        await t.drag(listes.first, Offset(0, sens), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 400));
      }
      if (f.evaluate().isNotEmpty) return;
    }
  }

  /// Attend qu'un élément apparaisse (le réseau prend du temps).
  Future<void> attendre(WidgetTester t, Finder f, {int secondes = 25}) async {
    for (var i = 0; i < secondes * 4; i++) {
      await t.pump(const Duration(milliseconds: 250));
      if (f.evaluate().isNotEmpty) return;
      // Après 3 s, l'élément est peut-être sorti de l'écran : on défile.
      if (i == 12) await chercher(t, f);
    }
    // Ce qu'il y avait à l'écran, pour comprendre l'échec.
    final textes = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(40)
        .join(' | ');
    throw TestFailure(
      'Introuvable après ${secondes}s : $f\nÀ l’écran : $textes',
    );
  }

  Future<void> toucher(WidgetTester t, Finder f) async {
    for (var i = 0; i < 12 && f.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    // Le clavier se ferme avant de toucher un bouton : la page reprend sa
    // place (les débordements, eux, ont été vus pendant la saisie).
    t.view.resetViewInsets();
    await t.pump(const Duration(milliseconds: 300));
    if (f.evaluate().isEmpty) await chercher(t, f);
    await attendre(t, f);
    await t.ensureVisible(f.first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(f.first);
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> retour(WidgetTester t) async {
    // Laisse finir une transition en cours : son bouton retour ignore le doigt.
    await t.pump(const Duration(milliseconds: 800));
    final bouton = find.byType(BackButton);
    if (bouton.evaluate().isNotEmpty) {
      await t.tap(bouton.last);
    } else {
      await t.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    }
    await t.pump(const Duration(seconds: 1));
  }

  void etape(String nom) => debugPrint('▶ $nom');

  /// Saisie avec le clavier « ouvert » : sa place (40 % de l'écran) est
  /// réservée en bas, comme sur un vrai téléphone. Une fenêtre qui ne
  /// défile pas déborde alors, et le test échoue.
  Future<void> saisir(WidgetTester t, Finder champ, String texte) async {
    final hauteur = t.view.physicalSize.height;
    t.view.viewInsets = FakeViewPadding(bottom: hauteur * 0.4);
    await t.pump(const Duration(milliseconds: 500));
    if (champ.evaluate().isEmpty) await chercher(t, champ);
    await t.ensureVisible(champ.first);
    await t.enterText(champ.first, texte);
    await t.pump(const Duration(seconds: 1));
  }

  /// Ouvre un onglet de l'espace pro, directement ou sous « Plus ».
  Future<void> onglet(WidgetTester t, String court, String titre) async {
    // Tablette (ou téléphone en paysage) : le rail à gauche, qui défile.
    final rail = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(titre),
    );
    if (find.byType(NavigationRail).evaluate().isNotEmpty) {
      await t.ensureVisible(rail.first);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(rail.first);
      await t.pump(const Duration(seconds: 3));
      return;
    }
    final direct = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(court),
    );
    if (direct.evaluate().isNotEmpty) {
      await t.tap(direct.first);
      // L'onglet courant rangé sous « Plus » prête son nom à ce bouton :
      // le toucher ouvre la liste, où l'on choisit l'onglet.
      await t.pump(const Duration(seconds: 1));
      final dansPlus = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(ListTile, titre),
      );
      if (dansPlus.evaluate().isNotEmpty) await toucher(t, dansPlus);
    } else {
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.more_horiz_rounded),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      await toucher(t, find.widgetWithText(ListTile, titre));
    }
    await t.pump(const Duration(seconds: 3));
  }

  testWidgets('parcours complet sans débordement', (t) async {
    app.main();
    await attendre(t, find.text('Passer'), secondes: 40);
    await t.tap(find.text('Passer'));
    await t.pump(const Duration(seconds: 1));

    // Connexion
    await toucher(t, find.widgetWithText(ElevatedButton, 'Se connecter'));
    await attendre(
      t,
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
    );
    await saisir(
      t,
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '70000001',
    );
    await saisir(t, find.widgetWithText(TextFormField, 'PIN'), '1234');
    await toucher(t, find.widgetWithText(ElevatedButton, 'Se connecter'));
    await attendre(t, find.textContaining('Bonjour'));

    // Ma santé
    for (final ecran in [
      'Mes rendez-vous',
      'Mon dossier',
      'Grossesse et enfants',
      'Mes ordonnances',
      'Mes paiements',
      'Ma carte santé',
      'Trouver un établissement',
    ]) {
      etape(ecran);
      await toucher(t, find.text(ecran));
      await t.pump(const Duration(seconds: 3));
      await retour(t);
    }

    etape('Mon dossier : QR d’accord, allergies');
    await toucher(t, find.text('Mon dossier'));
    await toucher(t, find.text('Afficher mon QR'));
    await attendre(t, find.textContaining('Valable une fois'));
    await toucher(t, find.text('Fermer'));
    await toucher(t, find.text('Modifier'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Antécédents (maladies, opérations)'),
      'Asthme',
    );
    await toucher(t, find.text('Enregistrer'));
    await attendre(t, find.textContaining('Asthme', findRichText: true));
    await retour(t);

    etape('Espace pro du centre de santé');
    // Espace pro du centre de santé
    await toucher(t, find.text('CSCom de Hamdallaye'));
    await attendre(
      t,
      find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
    );
    await t.pump(const Duration(seconds: 3));

    etape('Hospitalisation : chambres');
    await onglet(t, 'Hospit.', 'Hospitalisation');
    await toucher(t, find.text('Lits'));
    if (find.textContaining('Aucune chambre').evaluate().isNotEmpty) {
      await toucher(t, find.byTooltip('Nouvelle chambre'));
      await saisir(
        t,
        find.widgetWithText(TextField, 'Nom (ex. Salle d’observation)'),
        'Salle d’observation',
      );
      await saisir(t, find.widgetWithText(TextField, 'Nombre de lits'), '3');
      await saisir(
        t,
        find.widgetWithText(TextField, 'Prix de la nuit (XOF)'),
        '3000',
      );
      await toucher(t, find.text('Créer'));
      await attendre(t, find.textContaining('Salle d’observation'));
    }

    etape("File d'attente");
    // File d'attente : donner un ticket (saisie au clavier), régler la file
    await onglet(t, 'File', 'File d’attente');
    await toucher(t, find.text('Donner un ticket'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Nom (facultatif)'),
      'Test Intégration',
    );
    await toucher(t, find.widgetWithText(ElevatedButton, 'Donner le ticket'));
    await attendre(t, find.text('Fermer'));
    await toucher(t, find.text('Fermer'));
    await toucher(t, find.byTooltip('Régler la file'));
    await t.pump(const Duration(seconds: 3));
    await toucher(t, find.text('Ajouter un service'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Nom (ex. Pédiatrie)'),
      'Essai',
    );
    await toucher(t, find.text('Annuler'));
    await retour(t);
    await toucher(t, find.byTooltip('Chiffres du jour'));
    await t.pump(const Duration(seconds: 3));
    await retour(t);

    etape('Rendez-vous ');
    // Rendez-vous : agendas, nouveau rendez-vous
    await onglet(t, 'RDV', 'Rendez-vous');
    await toucher(t, find.byTooltip('Agendas'));
    await t.pump(const Duration(seconds: 3));
    await toucher(t, find.text('Agenda'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Nom (ex. Dr Diarra, Vaccination)'),
      'Dr Essai',
    );
    await retour(t);
    await retour(t);

    etape('Caisse ');
    // Caisse : tarifs (la fenêtre qui débordait), visites
    await onglet(t, 'Caisse', 'Caisse');
    await toucher(t, find.byTooltip('Tarifs et rapport'));
    await t.pump(const Duration(seconds: 3));
    await toucher(t, find.text('Tarif'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Acte (ex. Consultation générale)'),
      'Consultation générale',
    );
    await saisir(t, find.widgetWithText(TextField, 'Prix (XOF)'), '2000');
    await toucher(t, find.text('Enregistrer'));
    await t.pump(const Duration(seconds: 2));
    await retour(t);

    etape('Assureurs');
    await toucher(t, find.byTooltip('Assureurs'));
    await t.pump(const Duration(seconds: 2));
    if (find.textContaining('Aucun assureur').evaluate().isNotEmpty) {
      await toucher(t, find.byTooltip('Nouvel assureur'));
      await saisir(
        t,
        find.widgetWithText(TextField, 'Nom (ex. AMO, mutuelle…)'),
        'AMO (CANAM)',
      );
      await saisir(
        t,
        find.widgetWithText(TextField, 'Part prise en charge (%)'),
        '70',
      );
      await toucher(t, find.text('Enregistrer'));
    }
    await toucher(t, find.text('Bordereau'));
    await attendre(t, find.textContaining('À réclamer'));
    await retour(t);
    await retour(t);

    // Ouvrir sa caisse, puis la visite du ticket donné plus haut : acte,
    // ordonnance, encaissement.
    etape('Visite et encaissement');
    await onglet(t, 'Caisse', 'Caisse');
    await attendre(
      t,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Ouvrir ma caisse' || w.data == 'Clôturer ma caisse'),
      ),
    );
    if (find.text('Ouvrir ma caisse').evaluate().isNotEmpty) {
      await toucher(t, find.text('Ouvrir ma caisse'));
      await saisir(t, find.byType(TextField).last, '5000');
      await toucher(t, find.text('Valider'));
      await t.pump(const Duration(seconds: 2));
    }
    await toucher(t, find.textContaining('Test Intégration'));
    await t.pump(const Duration(seconds: 3));
    await toucher(t, find.text('Ajouter un acte'));
    await toucher(t, find.text('Consultation générale'));
    await t.pump(const Duration(seconds: 2));
    etape('Assurance sur la visite');
    await toucher(t, find.widgetWithText(TextButton, 'Ajouter'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Numéro d’assuré (sur la carte)'),
      'AMO-1',
    );
    await toucher(t, find.text('Appliquer'));
    await attendre(t, find.textContaining('part assureur'));
    // Dossier : infos médicales (clavier ouvert), puis la consultation.
    etape('Dossier et consultation');
    await toucher(t, find.text('Dossier et consultation'));
    await attendre(t, find.text('À savoir'));
    await toucher(t, find.text('Modifier'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Allergies (ex. pénicilline)'),
      'Pénicilline',
    );
    await toucher(t, find.text('Enregistrer'));
    await attendre(t, find.textContaining('Pénicilline', findRichText: true));
    await toucher(t, find.text('Consultation'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Motif (ex. fièvre depuis 3 jours)'),
      'Fièvre depuis 3 jours',
    );
    await saisir(t, find.widgetWithText(TextField, 'Température'), '38.5');
    await saisir(t, find.widgetWithText(TextField, 'TA systolique'), '120');
    await saisir(t, find.widgetWithText(TextField, 'TA diastolique'), '80');
    await saisir(
      t,
      find.widgetWithText(TextField, 'Diagnostic'),
      'Paludisme simple',
    );
    await toucher(t, find.text('Enregistrer la consultation'));
    // La carte de la consultation, dans le dossier (pas le champ saisi).
    await attendre(t, find.textContaining('Diagnostic : ', findRichText: true));
    etape('Demande d’analyses');
    await toucher(t, find.text('Demander des analyses'));
    await toucher(t, find.text('TDR paludisme'));
    await toucher(t, find.text('Glycémie à jeun'));
    await saisir(
      t,
      find.widgetWithText(
        TextField,
        'Renseignements cliniques (ex. fièvre 39 °C)',
      ),
      'Fièvre',
    );
    await toucher(t, find.textContaining('Demander 2 analyses'));
    await attendre(t, find.text('en attente'));

    etape('Grossesse, CPN, accouchement, carnet');
    await toucher(t, find.text('Grossesse'));
    await toucher(t, find.text('Date des dernières règles'));
    await toucher(t, find.text('OK'));
    await saisir(t, find.widgetWithText(TextField, 'Gestité'), '2');
    await saisir(t, find.widgetWithText(TextField, 'Parité'), '1');
    await toucher(t, find.text('Déclarer'));
    await toucher(t, find.text('CPN 1'));
    await saisir(t, find.widgetWithText(TextField, 'Poids'), '62');
    await saisir(t, find.widgetWithText(TextField, 'Hauteur utérine'), '20');
    await toucher(t, find.text('Céphalique'));
    await toucher(t, find.text('Enregistrer la CPN'));
    await attendre(t, find.textContaining('CPN 1 ·'));
    await toucher(t, find.text('Accouchement'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Prénom (facultatif)'),
      'Awa Test',
    );
    await saisir(t, find.widgetWithText(TextField, 'Poids (g)'), '3100');
    await toucher(t, find.text('Jumeaux : un autre enfant'));
    await toucher(t, find.byTooltip('Retirer').last);
    await toucher(t, find.text('Enregistrer l’accouchement'));
    await toucher(t, find.text('Awa Test'));
    await attendre(t, find.text('BCG'));
    await toucher(t, find.text('Fait').first);
    await saisir(
      t,
      find.widgetWithText(TextField, 'Numéro de lot (facultatif)'),
      'L42',
    );
    await toucher(t, find.text('Noter'));
    await attendre(t, find.textContaining('Fait le'));
    await retour(t);
    await retour(t);

    etape('Hospitaliser, soin, sortie');
    await toucher(t, find.text('Hospitaliser'));
    await toucher(
      t,
      find.byWidgetPredicate((w) => w is ActionChip && w.onPressed != null),
    );
    await saisir(
      t,
      find.widgetWithText(TextField, 'Motif d’hospitalisation'),
      'Paludisme grave',
    );
    await toucher(t, find.widgetWithText(ElevatedButton, 'Hospitaliser'));
    await toucher(t, find.text('Prescrire un soin'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Produit (ex. Artésunate)'),
      'Artésunate',
    );
    await saisir(
      t,
      find.widgetWithText(TextField, 'Dose (ex. 120 mg)'),
      '120 mg',
    );
    await toucher(t, find.text('IV'));
    await toucher(t, find.text('20:00'));
    await toucher(t, find.text('Prescrire'));
    await attendre(t, find.text('Plan de soins'));
    await toucher(t, find.text('Sortie'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Résumé de sortie'),
      'Évolution favorable',
    );
    await toucher(t, find.text('Valider la sortie'));
    await attendre(t, find.textContaining('Sorti ·'));
    await retour(t);
    await retour(t);

    await toucher(t, find.text('Ordonnance'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Produit 1 (ex. Paracétamol 500 mg)'),
      'Paracétamol 500 mg',
    );
    await saisir(
      t,
      find.widgetWithText(
        TextField,
        'Posologie (ex. 1 cp matin et soir, 5 jours)',
      ),
      '1 cp 3 fois par jour',
    );
    await toucher(t, find.text('Signer l’ordonnance'));
    await attendre(t, find.text('Fermer'));
    await toucher(t, find.text('Fermer'));
    await t.pump(const Duration(seconds: 1));
    await toucher(t, find.textContaining('Encaisser'));
    await toucher(t, find.text('Valider le paiement'));
    await attendre(t, find.text('Payé'));
    await retour(t);

    etape('Patients : nouveau, ticket, fiche, dossier');
    await onglet(t, 'Patients', 'Patients');
    await toucher(t, find.text('Nouveau patient'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Prénom et nom'),
      'Awa Essai',
    );
    await toucher(t, find.text('Femme'));
    await saisir(t, find.widgetWithText(TextField, 'Âge (ans)'), '28');
    await saisir(t, find.widgetWithText(TextField, 'Quartier'), 'Banconi');
    await toucher(t, find.text('Enregistrer'));
    await toucher(t, find.textContaining('Envoyer'));
    await toucher(t, find.text('Donner le ticket'));
    await attendre(t, find.text('Fermer'));
    await toucher(t, find.text('Fermer'));
    await attendre(t, find.text('Visite en cours aujourd’hui'));
    await retour(t);
    await saisir(t, find.widgetWithText(TextField, 'Nom ou téléphone'), 'Test');
    await toucher(t, find.text('Test Intégration'));
    await toucher(t, find.text('Dossier médical'));
    await attendre(
      t,
      find.textContaining('Paludisme simple', findRichText: true),
    );
    await retour(t);
    await retour(t);

    etape('Entrée : badges, visiteurs');
    await onglet(t, 'Entrée', 'Entrée');
    await toucher(t, find.byTooltip('Badges et présence du mois'));
    await attendre(t, find.text('Présence du mois'));
    await toucher(t, find.byIcon(Icons.qr_code_2_rounded));
    await toucher(t, find.text('Fermer'));
    await retour(t);
    await toucher(t, find.text('Visiteurs'));
    await toucher(t, find.byTooltip('Nouveau visiteur'));
    await saisir(t, find.widgetWithText(TextField, 'Nom du visiteur'), 'Fatou');
    await saisir(
      t,
      find.widgetWithText(TextField, 'Téléphone (facultatif)'),
      '70000099',
    );
    await toucher(t, find.text('Entrer'));
    await attendre(t, find.text('À scanner à la sortie'));
    await toucher(t, find.text('Fermer'));
    await toucher(t, find.text('Sorti').first);

    etape('Maternité');
    await onglet(t, 'Matern.', 'Maternité');
    await saisir(t, find.widgetWithText(TextField, 'Nom de la patiente'), 'x');
    await t.pump(const Duration(seconds: 2));

    etape('Laboratoire');
    await onglet(t, 'Labo', 'Laboratoire');
    await toucher(t, find.text('Test Intégration'));
    await attendre(t, find.text('Valider et prévenir le patient'));
    // Une demande laissée par un essai interrompu est peut-être déjà prélevée.
    if (find.text('Prélevé').evaluate().isNotEmpty) {
      await toucher(t, find.text('Prélevé'));
    }
    await attendre(t, find.text('Négatif'));
    await toucher(t, find.text('Négatif'));
    await saisir(t, find.widgetWithText(TextField, 'Résultat'), '0,9');
    await toucher(t, find.text('Valider et prévenir le patient'));
    await attendre(t, find.textContaining('Validé par'));
    await retour(t);
    await toucher(t, find.byTooltip('Analyses et prix'));
    await toucher(t, find.text('Hémoglobine'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Prix (XOF) — vide : non facturé'),
      '1500',
    );
    await toucher(t, find.text('Annuler'));
    await toucher(t, find.byTooltip('Nouvelle analyse'));
    await saisir(t, find.widgetWithText(TextField, 'Code (ex. CRP)'), 'CRP');
    await toucher(t, find.text('Annuler'));
    await retour(t);

    etape('Pharmacie');
    // Pharmacie : nouveau produit (saisie), réception
    await onglet(t, 'Pharma.', 'Pharmacie');
    await toucher(t, find.byTooltip('Nouveau produit'));
    await saisir(
      t,
      find.widgetWithText(TextField, 'Nom (ex. Doliprane 500 mg)'),
      'Paracétamol 500 mg',
    );
    await saisir(t, find.widgetWithText(TextField, 'Prix de la boîte'), '1500');
    // Vérifie le formulaire sans créer de produit (pas de doublons en démo).
    await toucher(t, find.text('Annuler'));
    await t.pump(const Duration(seconds: 2));
    await toucher(t, find.text('Vente au comptoir'));
    await t.pump(const Duration(seconds: 2));
    await retour(t);

    etape('Réglages et');
    // Réglages et sélecteur d'espaces
    await onglet(t, 'Réglages', 'Réglages');
    await t.pump(const Duration(seconds: 2));
    await toucher(t, find.byTooltip('Changer d’espace'));
    await t.pump(const Duration(seconds: 1));
    await toucher(t, find.text('Ma santé'));
    await attendre(t, find.textContaining('Bonjour'));
  });
}
