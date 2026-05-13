import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});
  // final VoidCallback onFinished;
  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Brand {
  static const saffron = Color(0xFFF4972A);
  static const lightSurface   = Color(0xFFEFEAFF);
  static const lightDivider   = Color(0xFFE5E7EB);
}


class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.length, required this.index});
  final int length;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: selected ? 32 : 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? _Brand.saffron
                : _Brand.lightDivider,
          ),
        );
      }),
    );
  }
}



class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _didPrecache = false;

  late final List<_Slide> _slides = const [
    _Slide(
      title: 'Welcome to MyShankara',
      subtitle:
      'A calm presence beside you—rooted in Sanatana Dharma, inspired by Adi Shankara, made for everyday life',
      asset: 'assets/onboarding/1.png',
    ),
    _Slide(
      title: 'Darshan & Diya Tracker',
      subtitle:
      'A simple daily rhythm—teaching, meaning, blessing—to build a quiet habit. Light the diya to mark continuity in a modern guru-shishya relationship',
      asset: 'assets/onboarding/2.png',
    ),
    _Slide(
      title: 'Guru Chat',
      subtitle:
      'Shankara stays by your side 24/7, listening without judgment and giving practical, dharmic guidance tailored to you',
      asset: 'assets/onboarding/3.png',
    ),
    _Slide(
      title: 'Your journey stays yours',
      subtitle: 'All conversations, logs, and journals are kept 100% confidential',
      asset: 'assets/onboarding/4.png',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    for (final s in _slides) {
      precacheImage(AssetImage(s.asset), context).catchError((_) {});
    }
    _didPrecache = true;
  }

  void _goNext() async {  // Make async
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      await widget.onFinished();  // Await it

    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = theme.extension<BrandExtension>();

    // final bg = _Brand.lightBg;
    // final primaryText = _Brand.lightPrimary;
    // final secondaryText = _Brand.lightSecondary;
    final divider = _Brand.lightDivider;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  const Spacer(),

                  TextButton(
                    onPressed: () async {
                      await widget.onFinished();
                      if (mounted) context.go('/login');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFFF4972A),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    ),
                    child: const Text('Skip',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return Column(
                      children: [
                        _ImageCard(asset: s.asset),
                        const SizedBox(height: 24),

                        // Title
                        Center(
                          child: Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Color(0xFF6755AB),
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              _DotsIndicator(length: _slides.length, index: _page),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _page == 0
                          ? null
                          : () => _controller.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {  // Make async
                        if (!isLast) {
                          _goNext();
                        } else {
                          await widget.onFinished();  // Await it
                          if (mounted) context.go('/login');
                        }
                      },
                      child: Text(isLast ? 'Get Started' : 'Next'),
                    )
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.title, required this.subtitle, required this.asset});
  final String title;
  final String subtitle;
  final String asset;
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.asset});
  final String asset;
  // final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = _Brand.lightSurface;
    final size = MediaQuery.of(context).size;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (size.width * dpr).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) {
            return Center(
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: Colors.black.withOpacity(0.35),
              ),
            );
          },
        ),
      ),
    );
  }
}
