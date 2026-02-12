import 'package:flutter/material.dart';

import '../common/utils/app_style.dart';
import '../common/utils/kcolors.dart';
import '../common/utils/kstrings.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGatewayScreen extends StatelessWidget {
  const AuthGatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final cardMaxWidth = isDesktop ? 620.0 : 460.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Kolors.kPrimary, Kolors.kBlue, Kolors.kPrimaryLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMaxWidth),
                child: Container(
                  padding: EdgeInsets.all(isDesktop ? 28 : 22),
                  decoration: BoxDecoration(
                    color: Kolors.kWhite.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo_keneya_plus_icon.png',
                            height: isDesktop ? 88 : 72,
                            width: isDesktop ? 88 : 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 18 : 14),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppText.kGetStarted,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: appStyle(
                            isDesktop ? 36 : 26,
                            Kolors.kDark,
                            FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choisissez une option pour continuer',
                        textAlign: TextAlign.center,
                        style: appStyle(
                          isDesktop ? 16 : 13,
                          Kolors.kGray,
                          FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 24 : 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Kolors.kPrimary,
                            foregroundColor: Kolors.kWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppText.kLoginButton,
                            style: appStyle(14, Kolors.kWhite, FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Kolors.kPrimary,
                            side: const BorderSide(color: Kolors.kPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppText.kRegisterButton,
                            style: appStyle(
                              14,
                              Kolors.kPrimary,
                              FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
