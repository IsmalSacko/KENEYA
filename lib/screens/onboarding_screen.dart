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
      description: 'La solution simple pour gerer vos activites medicales.',
      imagePath: 'assets/images/onboarding_1.png',
      colors: [Kolors.kPrimary, Kolors.kPrimaryLight],
    ),
    _OnboardingPageData(
      title: 'Patients centralises',
      description: 'Retrouvez rapidement les informations essentielles.',
      imagePath: 'assets/images/onboarding_2.png',
      colors: [Kolors.kBlue, Kolors.kPrimary],
    ),
    _OnboardingPageData(
      title: 'Medicaments et stock',
      description: 'Suivez vos stocks et evitez les ruptures.',
      imagePath: 'assets/images/onboarding_3.png',
      colors: [Kolors.kPrimaryLight, Kolors.kBlue],
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isLast)
                      TextButton(
                        onPressed: widget.onComplete,
                        child: Text(
                          'Passer',
                          style: appStyle(14, Kolors.kWhite, FontWeight.w600),
                        ),
                      ),
                  ],
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
                    final imageWidth = isDesktop ? 460.0 : 280.0;
                    final imageHeight = isDesktop ? 300.0 : 360.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: imageHeight,
                            width: imageWidth,
                            decoration: BoxDecoration(
                              color: Kolors.kWhite.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Kolors.kWhite.withValues(alpha: 0.30),
                                width: 1.2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              page.imagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: appStyle(
                              isDesktop ? 34 : 28,
                              Kolors.kWhite,
                              FontWeight.w700,
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
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
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
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _currentPage == 0 ? null : _previous,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Kolors.kWhite,
                                side: BorderSide(
                                  color: Kolors.kWhite.withValues(alpha: 0.8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Precedent',
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
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Kolors.kWhite,
                                foregroundColor: Kolors.kPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                isLast ? AppText.kGetStarted : 'Suivant',
                                style: appStyle(
                                  15,
                                  Kolors.kPrimary,
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
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.colors,
  });

  final String title;
  final String description;
  final String imagePath;
  final List<Color> colors;
}
