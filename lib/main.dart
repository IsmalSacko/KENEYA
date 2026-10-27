import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common/utils/app_theme.dart';
import 'core/api/changement_api.dart';
import 'core/offline/local_store.dart';
import 'core/offline/sync_manager.dart';
import 'compte/compte_controller.dart';
import 'compte/mes_tickets_controller.dart';
import 'file/appareil_api.dart';
import 'screens/appareil/borne_screen.dart';
import 'screens/appareil/ecran_salle_screen.dart';
import 'controllers/auth_controller.dart';
import 'controllers/etablissement_controller.dart';
import 'controllers/medicament_controller.dart';
import 'controllers/patient_controller.dart';
import 'controllers/user_controller.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth_gateway_screen.dart';
import 'screens/compte/ma_sante_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // « lundi 2 novembre » : les dates s'écrivent en français partout.
  await initializeDateFormatting('fr');
  await LocalStore.init();
  await ChangementApi.verifier();
  await SyncManager.instance.init();
  await LocalNotificationService.init();
  runApp(const KeneyaPlusApp());
}

/// Le compte se restaure une fois la session du membre relue : un
/// utilisateur de l'app 3.x y est rattaché à sa personne sans rien ressaisir.
CompteController _compteApresAuth(AuthController auth) {
  final compte = CompteController();
  var lance = false;
  void lancer() {
    if (lance || auth.initializing) return;
    lance = true;
    auth.removeListener(lancer);
    compte.restaurer(auth);
  }

  auth.addListener(lancer);
  lancer();
  return compte;
}

class KeneyaPlusApp extends StatelessWidget {
  const KeneyaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
        ChangeNotifierProvider<MesTicketsController>(
          create: (_) => MesTicketsController(),
        ),
        ChangeNotifierProvider<CompteController>(
          create: (context) => _compteApresAuth(context.read<AuthController>()),
        ),
        ChangeNotifierProvider<PatientController>(
          create: (_) => PatientController(),
        ),
        ChangeNotifierProvider<MedicamentController>(
          create: (_) => MedicamentController(),
        ),
        ChangeNotifierProvider<EtablissementController>(
          create: (_) => EtablissementController(),
        ),
        ChangeNotifierProvider<UserController>(create: (_) => UserController()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'Ngoni Santé',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr'), Locale('en')],
            // L'app est en français : calendriers et boutons système aussi,
            // même sur un téléphone réglé en anglais.
            locale: const Locale('fr'),
            home: const _AppEntryPoint(),
          );
        },
      ),
    );
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  static const int _onboardingVersion = 2;
  static const String _onboardingVersionKey = 'onboarding_completed_version';

  bool _loadingOnboarding = true;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final doneVersion = prefs.getInt(_onboardingVersionKey) ?? 0;
    final done = doneVersion >= _onboardingVersion;

    if (!mounted) return;
    setState(() {
      _onboardingCompleted = done;
      _loadingOnboarding = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_onboardingVersionKey, _onboardingVersion);

    if (!mounted) return;
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOnboarding) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_onboardingCompleted) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    // Appareil d'établissement (écran de salle, borne) : pas de compte.
    return ValueListenableBuilder<int>(
      valueListenable: AppareilApi.changements,
      builder: (context, _, _) => switch (AppareilApi.mode) {
        'ecran' => EcranSalleScreen(onQuitter: () => setState(() {})),
        'borne' => BorneScreen(onQuitter: () => setState(() {})),
        _ => _session(),
      },
    );
  }

  Widget _session() {
    return Consumer2<AuthController, CompteController>(
      builder: (context, auth, compte, child) {
        if (auth.initializing || compte.initialisation) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Un espace pro est ouvert. La clé reconstruit l'accueil pro à chaque
        // changement d'établissement, pour qu'il recharge ses données.
        if (auth.isAuthenticated) {
          return KeyedSubtree(
            key: ValueKey(compte.espaceActif ?? 'espace'),
            child: const HomeScreen(),
          );
        }

        if (compte.connecte) return const MaSanteScreen();

        return const AuthGatewayScreen();
      },
    );
  }
}
