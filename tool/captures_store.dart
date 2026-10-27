import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keneya_plus/common/utils/app_theme.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/core/api/api_client.dart';
import 'package:keneya_plus/core/offline/local_store.dart';
import 'package:keneya_plus/labo/labo_models.dart';
import 'package:keneya_plus/maternite/maternite_models.dart';
import 'package:keneya_plus/models/user_model.dart';
import 'package:keneya_plus/patients/patients_service.dart';
import 'package:keneya_plus/screens/dossier/dossier_screen.dart';
import 'package:keneya_plus/screens/home/tabs/aujourdhui_tab.dart';
import 'package:keneya_plus/screens/hospitalisation/sejour_screen.dart';
import 'package:keneya_plus/hospitalisation/hospit_models.dart';
import 'package:keneya_plus/screens/labo/demande_labo_screen.dart';
import 'package:keneya_plus/screens/maternite/grossesse_screen.dart';
import 'package:keneya_plus/screens/patients/patient_screen.dart';
import 'package:keneya_plus/screens/patients/patients_tab.dart';
import 'package:provider/provider.dart';

/// Produit les captures d'écran de la fiche Google Play.
///
/// Lancer : `outils/polices.sh` une fois, puis
///          `flutter test tool/captures_store.dart`
/// Sortie  : `store/telephone/`, `store/tablette-7/`, `store/tablette-10/`
///
/// Ce n'est pas un test : c'est un outil, hébergé ici parce que seul le
/// harnais de test sait transformer un widget en PNG. Les captures sortent
/// des vrais écrans, avec le vrai thème, nourris par une fausse API (un
/// CSCom de Bamako) : elles montrent ce que verra le soignant.

const _telephone = _Format('telephone', 1080, 1920, 2.75);
const _tablette7 = _Format('tablette-7', 1080, 1920, 2.0);
// Densité plus basse sur la grande tablette : plus de points logiques, donc
// les mises en page larges (rail, quatre colonnes) plutôt qu'un téléphone
// agrandi.
const _tablette10 = _Format('tablette-10', 1440, 2560, 1.6);

class _Format {
  const _Format(this.dossier, this.largeur, this.hauteur, this.densite);

  final String dossier;
  final int largeur;
  final int hauteur;
  final double densite;

  bool get large => largeur / densite >= 700;
}

class _Ecran {
  const _Ecran(this.nom, this.build, {this.coque});

  final String nom;
  final Widget Function() build;

  /// Titre de l'onglet quand l'écran est un onglet de l'accueil pro (avec la
  /// barre de navigation) ; null pour un écran ouvert par-dessus.
  final String? coque;
}

/// Sept écrans, dans l'ordre d'une journée au centre de santé : la journée,
/// les patients, la fiche, la consultation, le labo, la maternité,
/// l'hospitalisation. Google en montre quatre avant de faire défiler.
final _ecrans = <_Ecran>[
  _Ecran('1-accueil', () => const AujourdhuiTab(), coque: 'Accueil'),
  _Ecran('2-patients', () => const PatientsTab(), coque: 'Patients'),
  _Ecran('3-fiche', () => PatientScreen(patient: _patientDemo)),
  _Ecran('4-consultation', () => const DossierScreen(visiteUuid: 'v1')),
  _Ecran('5-laboratoire', () => DemandeLaboScreen(demande: _demandeLabo)),
  _Ecran('6-maternite', () => GrossesseScreen(grossesse: _grossesse)),
  _Ecran('7-hospitalisation', () => SejourScreen(sejour: _sejourDemo)),
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
    _sansPlugins();
    await LocalStore.init();
    await _chargerLesPolices();
    // Les polices sont chargées à la main : pas de téléchargement.
    GoogleFonts.config.allowRuntimeFetching = false;
    ApiClient.dio.httpClientAdapter = _FausseApi();
  });

  testWidgets('écrit les captures de la fiche Play', (tester) async {
    debugDisableShadows = false;
    final debordements = <String>{};

    try {
      for (final format in [_telephone, _tablette7, _tablette10]) {
        for (final ecran in _ecrans) {
          await _rendre(
            tester,
            chemin: 'store/${format.dossier}/${ecran.nom}.png',
            format: format,
            enfant: _Demonstration(format: format, ecran: ecran),
            debordements: debordements,
          );
        }
      }
    } finally {
      debugDisableShadows = true;
    }
    for (final d in debordements) {
      debugPrint('⚠ $d');
    }
  });
}

// ---------------------------------------------------------------------------
// L'application autour d'un écran
// ---------------------------------------------------------------------------

class _Demonstration extends StatelessWidget {
  const _Demonstration({required this.format, required this.ecran});

  final _Format format;
  final _Ecran ecran;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthController>.value(
      value: _session(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ecran.coque == null
            ? ecran.build()
            : _Coque(titre: ecran.coque!, large: format.large, child: ecran.build()),
      ),
    );
  }
}

/// Le médecin-chef d'un CSCom, avec tous les modules.
AuthController _session() {
  final auth = AuthController();
  auth
    ..permissions = const [
      'patients.voir', 'patients.gerer', 'dossier.lire', 'dossier.ecrire',
      'consultation.faire', 'ordonnance.prescrire', 'file.emettre',
      'file.appeler', 'file.gerer', 'rdv.voir', 'rdv.gerer',
      'caisse.encaisser', 'caisse.rapports', 'labo.saisir', 'labo.valider',
      'maternite.suivre', 'hospitalisation.gerer', 'soins.administrer',
      'etablissement.regler',
    ]
    ..modules = const [
      'file', 'rdv', 'consultation', 'caisse', 'pharmacie', 'labo',
      'maternite', 'hospitalisation',
    ]
    ..devise = 'XOF'
    ..currentUser = UserModel(
      id: 1,
      etablissementId: 1,
      name: 'Dr Fatoumata Diarra',
      telephone: '+22370000001',
      role: 'medecin',
      actif: true,
    );
  return auth;
}

/// La navigation de l'espace pro, reprise de l'accueil : un rail sur
/// tablette, la barre du bas (quatre onglets et « Plus ») au téléphone.
class _Coque extends StatelessWidget {
  const _Coque({required this.titre, required this.large, required this.child});

  final String titre;
  final bool large;
  final Widget child;

  static const _onglets = [
    ('Accueil', Icons.home_outlined, Icons.home),
    ('File d’attente', Icons.groups_2_outlined, Icons.groups_2),
    ('Patients', Icons.people_outline, Icons.people),
    ('Laboratoire', Icons.science_outlined, Icons.science),
    ('Maternité', Icons.pregnant_woman_outlined, Icons.pregnant_woman),
    ('Hospitalisation', Icons.bed_outlined, Icons.bed),
    ('Caisse', Icons.point_of_sale_outlined, Icons.point_of_sale),
    ('Pharmacie', Icons.local_pharmacy_outlined, Icons.local_pharmacy),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _onglets.indexWhere((o) => o.$1 == titre);
    return Scaffold(
      appBar: AppBar(
        title: Text(titre),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: large
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final o in _onglets)
                      NavigationRailDestination(
                        icon: Icon(o.$2),
                        selectedIcon: Icon(o.$3),
                        label: Text(o.$1),
                      ),
                  ],
                ),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: large
          ? null
          : NavigationBar(
              selectedIndex: index.clamp(0, 4),
              destinations: [
                for (final o in _onglets.take(4))
                  NavigationDestination(
                    icon: Icon(o.$2),
                    selectedIcon: Icon(o.$3),
                    label: o.$1 == 'File d’attente'
                        ? 'File'
                        : o.$1 == 'Laboratoire'
                        ? 'Labo'
                        : o.$1,
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded),
                  label: 'Plus',
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Le CSCom de démonstration
// ---------------------------------------------------------------------------

final _maintenant = DateTime.now();
String _il(int jours, [int heure = 9, int minute = 0]) => DateTime(
  _maintenant.year,
  _maintenant.month,
  _maintenant.day - jours,
  heure,
  minute,
).toUtc().toIso8601String();
String _jour(int dans) => DateTime(
  _maintenant.year,
  _maintenant.month,
  _maintenant.day + dans,
).toIso8601String().substring(0, 10);

final _patients = <Map<String, dynamic>>[
  {'uuid': 'p1', 'numero': '000127', 'en_cours': true, 'derniere_visite': _il(0, 8, 12), 'nom': 'Aminata Coulibaly', 'sexe': 'F', 'age': 27, 'telephone': '+223 76 12 34 56', 'adresse': 'Banconi', 'a_un_compte': true},
  {'uuid': 'p2', 'numero': '000098', 'en_cours': true, 'derniere_visite': _il(0, 9, 5), 'nom': 'Moussa Traoré', 'sexe': 'M', 'age': 54, 'telephone': '+223 66 45 78 12', 'adresse': 'Hamdallaye'},
  {'uuid': 'p3', 'numero': '000143', 'derniere_visite': _il(6), 'nom': 'Fanta Keïta', 'sexe': 'F', 'age': 8, 'telephone': '+223 70 98 11 02', 'adresse': 'Lafiabougou'},
  {'uuid': 'p4', 'numero': '000061', 'derniere_visite': _il(21), 'nom': 'Bakary Sanogo', 'sexe': 'M', 'age': 41, 'telephone': '+223 79 21 64 30', 'adresse': 'Djélibougou'},
  {'uuid': 'p5', 'numero': '000152', 'derniere_visite': _il(45), 'nom': 'Oumou Diallo', 'sexe': 'F', 'age': 33, 'telephone': '+223 65 07 88 41', 'adresse': 'Sabalibougou'},
  {'uuid': 'p6', 'numero': '000158', 'nom': 'Ibrahim Konaté', 'sexe': 'M', 'age': 2, 'telephone': '+223 76 55 02 19', 'adresse': 'Banconi'},
];

final _patientDemo = Patient.fromJson({
  ..._patients.first,
  'visites': [
    {'uuid': 'v1', 'ouverte_at': _il(0, 8, 12), 'statut': 'ouverte', 'services': ['Consultation', 'Laboratoire'], 'total': 3500, 'reste': 0, 'devise': 'XOF'},
    {'uuid': 'v0', 'ouverte_at': _il(42), 'statut': 'cloturee', 'services': ['Maternité'], 'total': 2000, 'reste': 0, 'devise': 'XOF'},
  ],
  'rendez_vous': [
    {'uuid': 'r1', 'debut': DateTime(_maintenant.year, _maintenant.month, _maintenant.day + 14, 9).toUtc().toIso8601String(), 'agenda': 'CPN — Sage-femme', 'motif': 'CPN 3'},
  ],
});

final _consultation = {
  'uuid': 'c1',
  'date': _il(0, 9, 40),
  'etablissement': 'CSCom de Hamdallaye',
  'ici': true,
  'praticien': 'Dr Fatoumata Diarra',
  'motif': 'Fièvre et frissons depuis 3 jours',
  'constantes': {'ta_sys': 110, 'ta_dia': 70, 'temperature': 38.9, 'pouls': 102, 'poids': 61},
  'examen': 'Pâleur conjonctivale modérée, pas de signe de gravité.',
  'diagnostic': 'Paludisme simple',
  'cim10': 'B54',
  'conclusion': 'Artéméther-luméfantrine 3 jours, paracétamol, boire beaucoup.',
  'prochain_rdv': _jour(7),
};

final _lignesLabo = [
  {'uuid': 'l1', 'nom': 'TDR paludisme', 'type_resultat': 'choix', 'choix': ['Négatif', 'Positif'], 'normale': 'Négatif', 'resultat': 'Positif', 'anormal': true},
  {'uuid': 'l2', 'nom': 'Hémoglobine', 'type_resultat': 'nombre', 'unite': 'g/dL', 'normale': '12 – 16 g/dL', 'resultat': '10,8', 'anormal': true},
  {'uuid': 'l3', 'nom': 'Glycémie à jeun', 'type_resultat': 'nombre', 'unite': 'g/L', 'normale': '0,7 – 1,1 g/L', 'resultat': '0,92', 'anormal': false},
];

final _demandeLabo = DemandeLabo.fromJson({
  'uuid': 'd1',
  'statut': 'prelevee',
  'urgent': false,
  'patient': 'Aminata Coulibaly',
  'etablissement': 'CSCom de Hamdallaye',
  'date': _il(0, 9, 45),
  'prescripteur': 'Dr Fatoumata Diarra',
  'renseignements': 'Fièvre 38,9 °C depuis 3 jours',
  'qr': 'ngoni-sante:labo:d1',
  'lignes': _lignesLabo,
});

final _grossesse = Grossesse.fromJson({
  'uuid': 'g1',
  'statut': 'en_cours',
  'patiente': 'Oumou Diallo',
  'dossier_uuid': 'p5',
  'ddr': _jour(-168),
  'dpa': _jour(112),
  'semaines': 24,
  'gestite': 3,
  'parite': 2,
  'prochain_rdv': _jour(28),
  'cpn': [
    {'numero': 1, 'semaines': 12, 'date': _il(84), 'etablissement': 'CSCom de Hamdallaye', 'praticien': 'Mariam Sidibé, sage-femme', 'poids': 63, 'ta_sys': 110, 'ta_dia': 70, 'fer': true, 'moustiquaire': true, 'vat': 1},
    {'numero': 2, 'semaines': 20, 'date': _il(28), 'etablissement': 'CSCom de Hamdallaye', 'praticien': 'Mariam Sidibé, sage-femme', 'poids': 66, 'ta_sys': 115, 'ta_dia': 75, 'hauteur_uterine': 19, 'bcf': 142, 'tpi': 1, 'vat': 2, 'fer': true, 'presentation': 'cephalique'},
    {'numero': 3, 'semaines': 24, 'date': _il(0, 10), 'etablissement': 'CSCom de Hamdallaye', 'praticien': 'Mariam Sidibé, sage-femme', 'poids': 68, 'ta_sys': 120, 'ta_dia': 80, 'hauteur_uterine': 23, 'bcf': 140, 'tpi': 2, 'fer': true, 'presentation': 'cephalique', 'observations': 'Bonne évolution. Revoir dans 4 semaines.'},
  ],
});

final _sejourJson = <String, dynamic>{
  'uuid': 's1',
  'statut': 'en_cours',
  'patient': 'Bakary Sanogo',
  'dossier_uuid': 'p4',
  'allergies': 'Pénicilline',
  'lit': 'Salle d’observation · lit 2',
  'motif': 'Paludisme grave',
  'medecin': 'Dr Fatoumata Diarra',
  'entree_at': _il(1, 16, 20),
  'nuits': 1,
  'bracelet': 'ngoni-sante:bracelet:s1',
  'soins': [
    {'uuid': 'so1', 'produit': 'Artésunate', 'dose': '120 mg', 'voie': 'iv', 'horaires': ['08:00', '20:00'], 'prescripteur': 'Dr Fatoumata Diarra', 'arrete': false},
    {'uuid': 'so2', 'produit': 'Paracétamol', 'dose': '1 g', 'voie': 'po', 'horaires': ['06:00', '12:00', '18:00'], 'instructions': 'Si fièvre', 'arrete': false},
    {'uuid': 'so3', 'produit': 'Sérum glucosé 5 %', 'dose': '500 mL', 'voie': 'iv', 'horaires': ['08:00'], 'arrete': false},
  ],
  'plan': [
    {'soin_uuid': 'so2', 'produit': 'Paracétamol', 'dose': '1 g', 'voie': 'po', 'prevue_at': _il(0, 6), 'heure': '06:00', 'statut': 'faite', 'par': 'Kadiatou, infirmière'},
    {'soin_uuid': 'so1', 'produit': 'Artésunate', 'dose': '120 mg', 'voie': 'iv', 'prevue_at': _il(0, 8), 'heure': '08:00', 'statut': 'faite', 'par': 'Kadiatou, infirmière'},
    {'soin_uuid': 'so3', 'produit': 'Sérum glucosé 5 %', 'dose': '500 mL', 'voie': 'iv', 'prevue_at': _il(0, 8), 'heure': '08:00', 'statut': 'faite', 'par': 'Kadiatou, infirmière'},
    {'soin_uuid': 'so2', 'produit': 'Paracétamol', 'dose': '1 g', 'voie': 'po', 'prevue_at': _il(0, 12), 'heure': '12:00', 'statut': 'a_faire', 'en_retard': false},
    {'soin_uuid': 'so2', 'produit': 'Paracétamol', 'dose': '1 g', 'voie': 'po', 'prevue_at': _il(0, 18), 'heure': '18:00', 'statut': 'a_faire', 'en_retard': false},
    {'soin_uuid': 'so1', 'produit': 'Artésunate', 'dose': '120 mg', 'voie': 'iv', 'prevue_at': _il(0, 20), 'heure': '20:00', 'statut': 'a_faire', 'en_retard': false},
  ],
};

final _sejourDemo = Sejour.fromJson(_sejourJson);

/// Ce que l'API répondrait, chemin par chemin.
Object? _reponse(String methode, String chemin) {
  return switch (chemin) {
    '/file/services' => {
      'data': [
        {'uuid': 'sv1', 'nom': 'Consultation', 'prefixe': 'A', 'actif': true, 'en_attente': 6, 'points': []},
        {'uuid': 'sv2', 'nom': 'Maternité', 'prefixe': 'M', 'actif': true, 'en_attente': 3, 'points': []},
        {'uuid': 'sv3', 'nom': 'Laboratoire', 'prefixe': 'L', 'actif': true, 'en_attente': 2, 'points': []},
        {'uuid': 'sv4', 'nom': 'Caisse', 'prefixe': 'C', 'actif': true, 'en_attente': 1, 'points': []},
      ],
    },
    '/caisse/rapport' => {'devise': 'XOF', 'visites': 37, 'encaisse': 148500, 'impaye': 6000},
    '/labo/demandes' => {
      'data': [
        for (var i = 0; i < 4; i++)
          {'uuid': 'd$i', 'statut': 'prelevee', 'urgent': i == 0, 'patient': _patients[i]['nom'], 'etablissement': 'CSCom', 'lignes': _lignesLabo},
      ],
    },
    '/hospitalisation/sejours' => {
      'data': [
        {..._sejourJson, 'en_retard': 0},
        {..._sejourJson, 'uuid': 's2', 'patient': 'Fanta Keïta', 'lit': 'Salle d’observation · lit 3', 'en_retard': 1},
        {..._sejourJson, 'uuid': 's3', 'patient': 'Ibrahim Konaté', 'lit': 'Pédiatrie · lit 1', 'en_retard': 0},
      ],
    },
    '/maternite/grossesses' => {
      'data': [
        for (var i = 0; i < 12; i++) {'uuid': 'g$i', 'patiente': 'Patiente $i', 'ddr': _jour(-100), 'dpa': _jour(180), 'cpn': []},
      ],
    },
    '/patients' => {'data': _patients},
    '/patients/p1' => {
      'patient': {
        ..._patients.first,
        'visites': [
          {'uuid': 'v1', 'ouverte_at': _il(0, 8, 12), 'statut': 'ouverte', 'services': ['Consultation', 'Laboratoire'], 'total': 3500, 'reste': 0, 'devise': 'XOF'},
          {'uuid': 'v0', 'ouverte_at': _il(42), 'statut': 'cloturee', 'services': ['Maternité'], 'total': 2000, 'reste': 0, 'devise': 'XOF'},
        ],
        'rendez_vous': [
          {'uuid': 'r1', 'debut': DateTime(_maintenant.year, _maintenant.month, _maintenant.day + 14, 9).toUtc().toIso8601String(), 'agenda': 'CPN — Sage-femme', 'motif': 'CPN 3'},
        ],
      },
    },
    '/visites/v1/dossier' => {
      'dossier': {
        'uuid': 'p1',
        'nom': 'Aminata Coulibaly',
        'telephone': '+223 76 12 34 56',
        'sexe': 'F',
        'age': 27,
        'groupe_sanguin': 'O+',
        'allergies': 'Pénicilline',
        'antecedents': 'Drépanocytose AS. Deux accouchements par voie basse.',
        'a_un_compte': true,
        'acces_historique': false,
        'consultations_ailleurs': 2,
        'peut_demander_acces': true,
        'consultations': [_consultation],
        'analyses': [
          {'uuid': 'd1', 'statut': 'validee', 'date': _il(0, 10, 30), 'etablissement': 'CSCom de Hamdallaye', 'lignes': _lignesLabo},
        ],
      },
      'tri': {
        'constantes': {'ta_sys': 110, 'ta_dia': 70, 'temperature': 38.9, 'pouls': 102, 'spo2': 98, 'poids': 61},
        'at': _il(0, 8, 40),
        'par': 'Kadiatou, infirmière',
      },
    },
    '/hospitalisation/sejours/s1' => {'sejour': _sejourJson},
    _ => null,
  };
}

class _FausseApi implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final corps = _reponse(options.method, options.path);
    return ResponseBody.fromString(
      jsonEncode(corps ?? {'message': 'Démonstration'}),
      corps == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Le rendu
// ---------------------------------------------------------------------------

/// Les plugins (stockage sécurisé, dossiers) n'existent pas dans le harnais :
/// on leur répond « rien », comme un téléphone neuf.
void _sansPlugins() {
  final messager = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messager.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (_) async => null,
  );
  messager.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.createTempSync('captures').path,
  );

  // `google_fonts` cherche ses polices parmi les ressources de l'app : on
  // ajoute celles d'`outils/polices` au manifeste que le harnais sert, sans
  // quoi il les réclame au réseau, absent ici.
  final ressources = Directory('build/unit_test_assets');
  final polices = Directory('outils/polices')
      .listSync()
      .whereType<File>()
      .map((f) => 'outils/polices/${f.uri.pathSegments.last}')
      .toList();
  messager.setMockMessageHandler('flutter/assets', (message) async {
    final cle = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List()));
    if (cle == 'AssetManifest.bin') {
      final origine = File('${ressources.path}/AssetManifest.bin');
      final manifeste = origine.existsSync()
          ? (const StandardMessageCodec().decodeMessage(
                      ByteData.sublistView(origine.readAsBytesSync()),
                    )
                    as Map)
                .cast<Object?, Object?>()
          : <Object?, Object?>{};
      for (final p in polices) {
        manifeste[p] = [
          {'asset': p},
        ];
      }
      return const StandardMessageCodec().encodeMessage(manifeste);
    }
    final fichier = File(
      cle.startsWith('outils/') ? cle : '${ressources.path}/$cle',
    );
    return fichier.existsSync()
        ? ByteData.sublistView(fichier.readAsBytesSync())
        : null;
  });
}

/// `google_fonts` va chercher Poppins et Nunito Sans sur le réseau, que le
/// harnais coupe. On enregistre les familles sous les noms qu'il cherche :
/// « Poppins_700 » par graisse, et « Poppins » en repli.
Future<void> _chargerLesPolices() async {
  final polices = Directory('outils/polices');
  if (!polices.existsSync()) {
    fail('Polices absentes. Lancez `outils/polices.sh`, puis réessayez.');
  }

  Future<void> charger(String famille, List<String> fichiers) async {
    final chargeur = FontLoader(famille);
    for (final f in fichiers) {
      chargeur.addFont(
        Future.value(ByteData.sublistView(File('${polices.path}/$f').readAsBytesSync())),
      );
    }
    await chargeur.load();
  }

  const graisses = {
    'regular': 'Regular', '100': 'Regular', '200': 'Regular', '300': 'Regular',
    '400': 'Regular', '500': 'Medium', '600': 'SemiBold', '700': 'Bold',
    '800': 'ExtraBold', '900': 'ExtraBold',
  };
  for (final famille in const ['Poppins', 'NunitoSans']) {
    String fichier(String coupe) {
      for (final essai in [coupe, 'SemiBold', 'Bold', 'Regular']) {
        if (File('${polices.path}/$famille-$essai.ttf').existsSync()) {
          return '$famille-$essai.ttf';
        }
      }
      return '$famille-Regular.ttf';
    }

    await charger(famille, [fichier('Regular'), fichier('Bold')]);
    for (final g in graisses.entries) {
      await charger('${famille}_${g.key}', [fichier(g.value)]);
    }
  }

  Directory? cache;
  for (
    var dossier = File(Platform.resolvedExecutable).parent;
    dossier.path != dossier.parent.path;
    dossier = dossier.parent
  ) {
    final candidat = Directory('${dossier.path}/material_fonts');
    if (candidat.existsSync()) {
      cache = candidat;
      break;
    }
  }
  if (cache == null) fail('Polices Material introuvables : `flutter precache`.');
  final icones = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(File('${cache.path}/MaterialIcons-Regular.otf').readAsBytesSync()),
      ),
    );
  await icones.load();
}

Future<void> _rendre(
  WidgetTester tester, {
  required String chemin,
  required _Format format,
  required Widget enfant,
  required Set<String> debordements,
}) async {
  // Les erreurs du rendu : les débordements sont notés pour être corrigés ;
  // `google_fonts`, qui réclame ses polices aux ressources de l'app alors
  // qu'elles sont déjà chargées, est ignoré — le texte sort juste.
  void recueillir() {
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      final texte = '$e';
      if (texte.contains('overflowed')) {
        debordements.add('$chemin : ${texte.split('\n').first}');
      } else if (!texte.contains('GoogleFonts') && !texte.contains('google_fonts')) {
        throw e;
      }
    }
  }

  final cle = GlobalKey();
  tester.view.physicalSize = Size(format.largeur.toDouble(), format.hauteur.toDouble());
  tester.view.devicePixelRatio = format.densite;
  tester.view.padding = FakeViewPadding(top: 28 * format.densite);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(RepaintBoundary(key: cle, child: enfant));
  recueillir();
  // Les écrans chargent leurs données : on laisse la fausse API répondre.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
    recueillir();
  }
  await tester.pump(const Duration(seconds: 1));
  recueillir();

  final boundary = cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final octets = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: format.densite);
    final donnees = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return donnees!.buffer.asUint8List();
  });

  File(chemin)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(octets!);
  // Démonte l'écran : ses minuteries ne doivent pas déborder sur le suivant.
  await tester.pumpWidget(const SizedBox());
  recueillir();
}
