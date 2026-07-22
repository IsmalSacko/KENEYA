import 'package:flutter/material.dart';

import '../common/utils/app_style.dart';
import '../common/utils/kcolors.dart';
import '../common/utils/kstrings.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGatewayScreen extends StatefulWidget {
  const AuthGatewayScreen({super.key});

  @override
  State<AuthGatewayScreen> createState() => _AuthGatewayScreenState();
}

class _AuthGatewayScreenState extends State<AuthGatewayScreen> {
  final PageController _pageController = PageController();
  int _current = 0;

  static const List<_Slide> _slides = [
    _Slide(
      icon: Icons.local_hospital_rounded,
      title: 'Gérez votre établissement',
      description: 'Cabinets et pharmacies, tout au même endroit.',
    ),
    _Slide(
      icon: Icons.groups_rounded,
      title: 'Patients & consultations',
      description:
          'Suivez vos patients et leurs consultations en un clin d’œil.',
    ),
    _Slide(
      icon: Icons.inventory_2_rounded,
      title: 'Stock & paiements',
      description: 'Médicaments, ventes et encaissements toujours maîtrisés.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _goRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Kolors.kPrimary, Kolors.kBlue, Kolors.kPrimaryDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: Kolors.kWhite.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: Kolors.kWhite,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppText.kAppName,
                        style: appStyle(22, Kolors.kWhite, FontWeight.w800),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _current = i),
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        final illSize = (isDesktop ? 280.0 : size.width * 0.55)
                            .clamp(180.0, 300.0)
                            .toDouble();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Illus(icon: slide.icon, size: illSize),
                              const SizedBox(height: 30),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: appStyle(
                                  isDesktop ? 30 : 24,
                                  Kolors.kWhite,
                                  FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                slide.description,
                                textAlign: TextAlign.center,
                                style: appStyle(
                                  isDesktop ? 17 : 14,
                                  Kolors.kWhite.withValues(alpha: 0.92),
                                  FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final active = index == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 26 : 8,
                        decoration: BoxDecoration(
                          color: active
                              ? Kolors.kWhite
                              : Kolors.kWhite.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _goLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Kolors.kWhite,
                              foregroundColor: Kolors.kPrimaryDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              AppText.kLoginButton,
                              style: appStyle(
                                15,
                                Kolors.kPrimaryDark,
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _goRegister,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Kolors.kWhite,
                              side: BorderSide(
                                color: Kolors.kWhite.withValues(alpha: 0.85),
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              AppText.kRegisterButton,
                              style:
                                  appStyle(15, Kolors.kWhite, FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _Illus extends StatelessWidget {
  const _Illus({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _circle(size, 0.10),
          _circle(size * 0.74, 0.16),
          _circle(size * 0.5, 0.24),
          Icon(icon, size: size * 0.28, color: Kolors.kWhite),
        ],
      ),
    );
  }

  Widget _circle(double d, double alpha) => Container(
    height: d,
    width: d,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Kolors.kWhite.withValues(alpha: alpha),
    ),
  );
}
