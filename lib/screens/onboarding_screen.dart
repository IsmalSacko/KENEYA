import 'package:flutter/material.dart';

import '../common/utils/app_style.dart';
import '../common/utils/kcolors.dart';
import '../common/utils/kstrings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Bienvenue sur KENEYA+',
      description:
          'La solution simple et fiable pour gérer vos activités de santé.',
      icon: Icons.health_and_safety_rounded,
      colors: [Kolors.kPrimary, Kolors.kBlue],
    ),
    _OnboardingPageData(
      title: 'Patients centralisés',
      description: 'Retrouvez en un instant les informations essentielles.',
      icon: Icons.groups_rounded,
      colors: [Kolors.kBlue, Kolors.kPrimaryDark],
    ),
    _OnboardingPageData(
      title: 'Médicaments & stock',
      description: 'Suivez vos stocks et évitez les ruptures.',
      icon: Icons.medication_rounded,
      colors: [Kolors.kPrimaryLight, Kolors.kPrimary],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _previous() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 900;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pages[_currentPage].colors,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: isLast
                          ? const SizedBox(height: 40)
                          : TextButton(
                              onPressed: widget.onComplete,
                              child: Text(
                                'Passer',
                                style: appStyle(
                                  14,
                                  Kolors.kWhite,
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (value) =>
                          setState(() => _currentPage = value),
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        final illustrationSize =
                            (isDesktop ? 320.0 : size.width * 0.62)
                                .clamp(200.0, 340.0);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _OnboardingIllustration(
                                icon: page.icon,
                                size: illustrationSize.toDouble(),
                              ),
                              SizedBox(height: isDesktop ? 40 : 32),
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: appStyle(
                                  isDesktop ? 34 : 27,
                                  Kolors.kWhite,
                                  FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: appStyle(
                                  isDesktop ? 18 : 15,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (index) {
                            final active = index == _currentPage;
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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            if (_currentPage > 0) ...[
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: _previous,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Kolors.kWhite,
                                      side: BorderSide(
                                        color: Kolors.kWhite
                                            .withValues(alpha: 0.8),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      'Précédent',
                                      style: appStyle(
                                        14,
                                        Kolors.kWhite,
                                        FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _next,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Kolors.kWhite,
                                    foregroundColor: Kolors.kPrimaryDark,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    isLast ? AppText.kGetStarted : 'Suivant',
                                    style: appStyle(
                                      15,
                                      Kolors.kPrimaryDark,
                                      FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

/// Illustration vectorielle (cercles concentriques translucides + icône santé).
class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.icon, required this.size});

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
          _circle(size * 0.76, 0.14),
          _circle(size * 0.52, 0.22),
          Icon(icon, size: size * 0.30, color: Kolors.kWhite),
        ],
      ),
    );
  }

  Widget _circle(double diameter, double alpha) {
    return Container(
      height: diameter,
      width: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Kolors.kWhite.withValues(alpha: alpha),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
}
