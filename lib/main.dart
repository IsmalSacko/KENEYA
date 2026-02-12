import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/etablissement_controller.dart';
import 'controllers/medicament_controller.dart';
import 'controllers/patient_controller.dart';
import 'controllers/user_controller.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
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
        ChangeNotifierProvider<UserController>(
          create: (_) => UserController(),
        ),
      ],
      child: MaterialApp(
        title: 'Keneya Plus',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: Consumer<AuthController>(
          builder: (context, auth, child) {
            if (auth.initializing) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (auth.isAuthenticated) {
              return const HomeScreen();
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
