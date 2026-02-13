import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common/utils/app_theme.dart';
import 'core/offline/local_store.dart';
import 'core/offline/sync_manager.dart';
import 'controllers/auth_controller.dart';
import 'controllers/etablissement_controller.dart';
import 'controllers/medicament_controller.dart';
import 'controllers/patient_controller.dart';
import 'controllers/user_controller.dart';
import 'screens/home_screen.dart';
import 'screens/auth_gateway_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  await SyncManager.instance.init();
  runApp(const KeneyaPlusApp());
}

class KeneyaPlusApp extends StatelessWidget {
  const KeneyaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
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
            title: 'KENEYA+',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
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

    return Consumer<AuthController>(
      builder: (context, auth, child) {
        if (auth.initializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.isAuthenticated) {
          return const HomeScreen();
        }

        return const AuthGatewayScreen();
      },
    );
  }
}
