import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:myshankara/theme/app_theme.dart';
import '../theme/colors.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import '../services/diya_service.dart';
import '../services/access_service.dart';
// ─────────────────────────────────────────────────────────────────────────────
// DAILY DARSHAN — 4-SCREEN GUIDED EXPERIENCE
// Screens: Story → Interpretation → Reflection + Blessing → Diya + Next Day
//
// Design System (all from AppColors / theme — no ad-hoc per-screen colors):
//   • Headings        → AppColors.primary (indigo)
//   • Taglines        → AppColors.onSurface.withValues(alpha: 0.55)
//   • Body text       → AppColors.onBackground
//   • Accent / icons  → AppColors.accent  (saffron)
//   • Cards           → AppColors.surface bg + AppColors.outline border
//   • CTA buttons     → AppColors.accent  (consistent across ALL steps)
// ─────────────────────────────────────────────────────────────────────────────

class DarshanScreen extends StatefulWidget {
  final VoidCallback? onDarshanComplete;
  final VoidCallback? onGoHome;

  const DarshanScreen({
    super.key,
    this.onDarshanComplete,
    this.onGoHome,
  });

  @override
  State<DarshanScreen> createState() => _DarshanScreenState();
}

class _DarshanScreenState extends State<DarshanScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int _currentStep = 0;
  bool _diyaLit = false;
  bool _diyaAnimating = false;
  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
  // ── Darshan API data ───────────────────────────────────────────────────────
  bool _isLoading = true;
  int _week = 0;
  String _weekday = '';
  String _title = '';
  String _teaser = '';
  String _story = '';
  String _insight = '';
  String _reflectionQ1 = '';
  String _reflectionQ2 = '';
  String _blessing = '';
  String _tomorrowHook = '';
  String _timezone = '';

  late final PageController _pageController;
  late AnimationController _diyaGlowController;
  late Animation<double> _diyaGlowAnim;

  // ── CTA labels & per-step colors ──────────────────────────────────────────
  static const _ctaLabels = ['Understand', 'Reflect', 'Offer', 'Complete Darshan'];
  static const _ctaColors = [
    Color(0xFFF5A623), // saffron    — Step 0: Story
    Color(0xFF5C5DA6), // indigo     — Step 1: Interpretation
    Color(0xFF4A7C59), // green      — Step 2: Reflection
    Color(0xFFC94E2D), // terracotta — Step 3: Diya
  ];

  // ── Background images per step ─────────────────────────────────────────────
  static const _backgrounds = [
    'assets/back1.webp',
    'assets/back3.webp',
    'assets/back2.webp',
    'assets/back1.webp',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _diyaGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _diyaGlowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _diyaGlowController, curve: Curves.easeInOut),
    );

    _fetchDarshan();
    // Check the today status for diya
    DiyaService.isDiyaLitToday().then((alreadyLit) {
      if (mounted && alreadyLit) {
        setState(() => _diyaLit = true);
      }
    });
  }



  // ── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchDarshan() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      _timezone = timezoneInfo.identifier;
      final uri = Uri.parse('https://dashboard.myshankara.ai/get_darshan')
          .replace(queryParameters: {
        'timezone': _timezone,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _week         = (data['week']          as num?)?.toInt() ?? 0;
            _weekday      = data['weekday']         as String? ?? '';
            _title        = data['title']           as String? ?? '';
            _teaser       = data['teaser']          as String? ?? '';
            _story        = data['story']           as String? ?? '';
            _insight      = data['insight']         as String? ?? '';
            _reflectionQ1 = data['reflection_q1']  as String? ?? '';
            _reflectionQ2 = data['reflection_q2']  as String? ?? '';
            _blessing     = data['blessing']        as String? ?? '';
            _tomorrowHook = data['tomorrow_hook']   as String? ?? '';
            _isLoading    = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _diyaGlowController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _goNext() {
    if (_currentStep < 3) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goPrev() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onGoHome?.call();
    }
  }

  void _handleCTA() {
    if (_currentStep == 3) {
      if (!_isGuest) widget.onDarshanComplete?.call();
      widget.onGoHome?.call();
    } else {
      _goNext();
    }
  }

  Future<void> _lightDiya() async {
    if (_diyaLit) return;
    // Guest user check
    if (_isGuest) {
      _showGuestDialog();
      return;
    }

    // Trial / subscription check
    final allowed = await AccessService.hasAccess();
    if (!allowed) {
      if (mounted) context.push('/guru-dakshina');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _diyaAnimating = true);
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (mounted) {
        setState(() { _diyaLit = true; _diyaAnimating = false; });
        //DiyaService.lightDiya();
        await DiyaService.lightDiya();          // ← await it
        widget.onDarshanComplete?.call();
      }
    });
  }


  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: AssetImage('assets/stir_popup_background.png'), // same background
              fit: BoxFit.cover,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji
                  const Text('🪔', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Light Your Diya Daily.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Every flame is an act of devotion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Question
                  const Text(
                    'Would you like to begin your seva journey?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign up to track seva',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: ()
                      {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        setState(() => _diyaAnimating = true);
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted) {
                            setState(() { _diyaLit = true; _diyaAnimating = false; });
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                      ),
                      child: const Text(
                        'Maybe later',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF444444),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — crossfades on step change
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Image.asset(
              _backgrounds[_currentStep],
              key: ValueKey('bg_$_currentStep'), // unique per step, not per path
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Scrim so text stays legible over any background
          // Keep opacity low enough (≤0.55) so the background image shows through
          Container(
            color: AppColors.background.withValues(alpha: 0.40),
          ),

          SafeArea(
            child: Column(
              children: [
                _DarshanAppBar(onBack: _goPrev, currentStep: _currentStep),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _ProgressDots(currentStep: _currentStep),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentStep = i),
                    children: [
                      _StoryScreen(story: _story),
                      _InterpretationScreen(insight: _insight),
                      _ReflectionBlessingScreen(
                        reflectionQ1: _reflectionQ1,
                        reflectionQ2: _reflectionQ2,
                        blessing: _blessing,
                      ),
                      _DiyaScreen(
                        diyaLit: _diyaLit,
                        diyaAnimating: _diyaAnimating,
                        glowAnim: _diyaGlowAnim,
                        onLightDiya: () { _lightDiya(); },
                        tomorrowHook: _tomorrowHook,
                        isGuest: _isGuest,
                      ),
                    ],
                  ),
                ),

                _DarshanCTA(
                  step: _currentStep,
                  ctaLabel: _ctaLabels[_currentStep],
                  ctaColor: _ctaColors[_currentStep],
                  onCTA: _handleCTA,
                  onReturnHome: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _DarshanAppBar extends StatelessWidget {
  final VoidCallback onBack;
  final int currentStep;

  const _DarshanAppBar({required this.onBack, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered title
          Text('Daily Darshan', style: theme.textTheme.titleLarge),

          // Back button — left-pinned
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS DOTS
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressDots extends StatelessWidget {
  final int currentStep;
  const _ProgressDots({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final isActive = i == currentStep;
        final isPast = i < currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent
                  : isPast
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.outline,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Consistent hero zone used at the top of every screen.
/// icon + eyebrow label + title + tagline
class _ScreenHero extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;

  const _ScreenHero({
    required this.icon,
    required this.eyebrow,
    required this.title
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Icon badge — always accent-tinted
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: 32, color: AppColors.accent),
        ),
        const SizedBox(height: 12),

        // Eyebrow — small caps label in accent
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),

        // Title — always primary (indigo)
        Text(
          title,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// Content card — consistent surface for callouts, quotes, prompts.
class _ContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _ContentCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section label (REFLECTION, BLESSING, etc.)
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Lotus divider — shared between screens
class _LotusDivider extends StatelessWidget {
  const _LotusDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: const Color(0xFF2A265F).withValues(alpha: 0.9)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '🌷',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.outline.withValues(alpha: 0.8),
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: const Color(0xFF2A265F).withValues(alpha: 0.9)),
        ),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1 — STORY
// ─────────────────────────────────────────────────────────────────────────────
class _StoryScreen extends StatelessWidget {
  final String story;
  const _StoryScreen({required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          const _ScreenHero(
            icon: Icons.menu_book_rounded,
            eyebrow: 'Story',
            title: 'Eternal Lessons',
          ),

          const SizedBox(height: 28),

          // Story paragraphs — all left-aligned for readability
          if (story.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                story,
                textAlign: TextAlign.left,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onBackground,
                  height: 1.6,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Reflection teaser card
          _ContentCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Every story is a mirror.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onBackground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'What will you see today?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Story image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/screen-1.webp',
              width: double.infinity,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2 — INTERPRETATION
// ─────────────────────────────────────────────────────────────────────────────
class _InterpretationScreen extends StatelessWidget {
  final String insight;
  const _InterpretationScreen({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          const _ScreenHero(
            icon: Icons.lightbulb_outline_rounded,
            eyebrow: 'Insight',
            title: 'Wisdom for Today',
          ),

          const SizedBox(height: 28),

          // Insight paragraphs — left-aligned for readability
          if (insight.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                insight,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onBackground,
                  height: 1.6,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Pull-quote card
          _ContentCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 26,
                  color: AppColors.accent.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'When you change the way you see, '
                        'everything you do changes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Insight image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/2ndpaeg.png',
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 3 — REFLECTION + BLESSING
// ─────────────────────────────────────────────────────────────────────────────
class _ReflectionBlessingScreen extends StatelessWidget {
  final String reflectionQ1;
  final String reflectionQ2;
  final String blessing;

  const _ReflectionBlessingScreen({
    required this.reflectionQ1,
    required this.reflectionQ2,
    required this.blessing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          const _ScreenHero(
            icon: Icons.eco_outlined,
            eyebrow: 'Pause',
            title: 'Within. Reflect. Receive.',
          ),

          const SizedBox(height: 28),

          // ── Reflection section ──────────────────────────────────────────
          const Align(
            alignment: Alignment.centerLeft,
            child: _SectionLabel(
              icon: Icons.eco_rounded,
              label: 'Reflection',
            ),
          ),
          const SizedBox(height: 10),

          _ReflectionPrompt(reflectionQ1),
          const SizedBox(height: 10),
          _ReflectionPrompt(reflectionQ2),

          const SizedBox(height: 24),
          const _LotusDivider(),
          const SizedBox(height: 20),

          // ── Blessing section ────────────────────────────────────────────

          const Align(
            alignment: Alignment.centerLeft,
            child: _SectionLabel(
              icon: Icons.stars_rounded,
              label: 'Blessing',
            ),
          ),
          const SizedBox(height: 10),
          _ReflectionPrompt(blessing.isNotEmpty ? blessing : 'May this wisdom stay with you.'),
          const SizedBox(height: 24),

          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/screen3.png',
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ReflectionPrompt extends StatelessWidget {
  final String text;
  const _ReflectionPrompt(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onBackground,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 4 — DIYA + NEXT DAY
// ─────────────────────────────────────────────────────────────────────────────
class _DiyaScreen extends StatelessWidget {
  final bool diyaLit;
  final bool diyaAnimating;
  final Animation<double> glowAnim;
  final VoidCallback onLightDiya;
  final String tomorrowHook;
  final bool isGuest;


  const _DiyaScreen({
    required this.diyaLit,
    required this.diyaAnimating,
    required this.glowAnim,
    required this.onLightDiya,
    required this.tomorrowHook,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Diya image — unlit before tap, lit after tap
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.asset(
                diyaLit
                    ? 'assets/diya-darsan.png'
                    : 'assets/diya-darsan-unlit.png',
                key: ValueKey(diyaLit),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Light Diya button — accent, consistent with all CTAs
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: diyaLit ? null : onLightDiya,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Image.asset('assets/fire.png', width: 22, height: 22),
              label: Text(
                diyaLit ? 'Diya Lit ✓' : 'Light Your Diya',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),
          // "See you tomorrow" card
          _ContentCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // match your card radius
                    child: Image.asset(
                      'assets/sunrise_background.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                //  Content on top
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/sunrise.png',
                        width: 30,
                        height: 30,
                        color: Colors.orange,
                        colorBlendMode: BlendMode.srcIn, //  applies color only to non-transparent pixels
                      ),

                      Text(
                        'See you tomorrow',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5B2D08),
                          fontWeight: FontWeight.w700,
                          fontSize: 20
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tomorrowHook.isNotEmpty ? tomorrowHook : 'The Journey Continues',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onBackground,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM CTA
// ─────────────────────────────────────────────────────────────────────────────
class _DarshanCTA extends StatelessWidget {
  final int step;
  final String ctaLabel;
  final Color ctaColor;
  final VoidCallback onCTA;
  final VoidCallback onReturnHome;

  const _DarshanCTA({
    required this.step,
    required this.ctaLabel,
    required this.ctaColor,
    required this.onCTA,
    required this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onCTA,
              style: FilledButton.styleFrom(
                // Per-step color: saffron → indigo → green → terracotta
                backgroundColor: ctaColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ctaLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    step == 3
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          step < 3
              ? Text(
            'Swipe left or tap to continue',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          )
              :  const SizedBox.shrink(),
        ],
      ),
    );
  }
}