import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:myshankara/theme/app_theme.dart';
import '../theme/colors.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
//   • CTA buttons     → per-step accent color (saffron/indigo/green/terracotta),
//                       intentionally varies by step — see _ctaColors below
// ─────────────────────────────────────────────────────────────────────────────

class DarshanScreen extends StatefulWidget {
  final VoidCallback? onDarshanComplete;

  const DarshanScreen({
    super.key,
    this.onDarshanComplete,
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
    AppColors.darshanStepStory,
    AppColors.darshanStepInterpretation,
    AppColors.darshanStepReflection,
    AppColors.darshanStepDiya,
  ];
  static const _stepLabels = ['Story', 'Insight', 'Reflect', 'Diya'];

  static const _hintSeenPrefKey = 'darshan_swipe_hint_seen';
  bool _showSwipeHint = false;

  // ── Background images per step ─────────────────────────────────────────────
  static const _backgrounds = [
    'assets/backgrounds/back1.webp',
    'assets/backgrounds/back3.webp',
    'assets/backgrounds/back2.webp',
    'assets/backgrounds/back1.webp',
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

    // Show the "swipe or tap to continue" hint only the very first time
    // a user goes through Darshan — not on every screen, every day.
    SharedPreferences.getInstance().then((prefs) {
      final seen = prefs.getBool(_hintSeenPrefKey) ?? false;
      if (mounted && !seen) {
        setState(() => _showSwipeHint = true);
      }
    });
  }

  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    setState(() => _showSwipeHint = false);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_hintSeenPrefKey, true),
    );
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
      context.pop();
    }
  }

  void _handleCTA() {
    if (_currentStep == 3) {
      if (!_isGuest) widget.onDarshanComplete?.call();
      context.pop();
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪔', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 16),

                Text(
                  'Light Your Diya Daily.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                Text(
                  'Every flame is an act of devotion.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onBackground.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Would you like to begin your seva journey?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/login');
                    },
                    child: const Text('Sign up to track seva'),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      HapticFeedback.mediumImpact();
                      setState(() => _diyaAnimating = true);
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (mounted) {
                          setState(() { _diyaLit = true; _diyaAnimating = false; });
                        }
                      });
                    },
                    child: const Text('Maybe later'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                _DarshanHeader(
                  onBack: _goPrev,
                  currentStep: _currentStep,
                  stepColors: _ctaColors,
                  stepLabel: _stepLabels[_currentStep],
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) {
                      setState(() => _currentStep = i);
                      _dismissSwipeHint();
                    },
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
                  showHint: _showSwipeHint,
                  onCTA: _handleCTA,
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
// HEADER — back button + step label/counter + progress bar, one compact block
// (progress color tracks the current step's theme color, same as the CTA)
// ─────────────────────────────────────────────────────────────────────────────
class _DarshanHeader extends StatelessWidget {
  final VoidCallback onBack;
  final int currentStep;
  final List<Color> stepColors;
  final String stepLabel;

  const _DarshanHeader({
    required this.onBack,
    required this.currentStep,
    required this.stepColors,
    required this.stepLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onBackground.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: stepColors[currentStep],
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text(stepLabel),
                    ),
                    Text(
                      '${currentStep + 1} / 4',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(4, (i) {
                    final isActive = i == currentStep;
                    final isPast = i < currentStep;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? stepColors[i]
                              : isPast
                              ? stepColors[i].withValues(alpha: 0.5)
                              : AppColors.outline,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }),
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
            color: AppColors.onBackground.withValues(alpha: 0.04),
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
          child: Container(height: 1, color: AppColors.primary.withValues(alpha: 0.9)),
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
          child: Container(height: 1, color: AppColors.primary.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

}

/// Markdown style sheet shared by the Story and Insight screens, mapped onto
/// this screen's AppColors design system (see the header comment for the
/// palette rules) rather than the Material theme's colorScheme.
MarkdownStyleSheet _darshanMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final bodyColor = AppColors.onBackground;

  return MarkdownStyleSheet(
    p: theme.textTheme.bodyMedium?.copyWith(color: bodyColor, height: 1.6),
    h1: theme.textTheme.titleLarge?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w800,
    ),
    h2: theme.textTheme.titleMedium?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w800,
    ),
    h3: theme.textTheme.titleSmall?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
    strong: theme.textTheme.bodyMedium?.copyWith(
      color: bodyColor,
      fontWeight: FontWeight.w700,
    ),
    em: theme.textTheme.bodyMedium?.copyWith(
      color: bodyColor,
      fontStyle: FontStyle.italic,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
    a: theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.link,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    ),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: bodyColor.withValues(alpha: 0.75),
      fontStyle: FontStyle.italic,
      height: 1.5,
    ),
    blockquoteDecoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: AppColors.surface,
      color: bodyColor,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
      ),
    ),
  );
}

void _launchDarshanLink(String? href) {
  if (href == null) return;
  launchUrlString(href);
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

          // Story — rendered as Markdown (server sends it in Markdown format)
          if (story.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: MarkdownBody(
                data: story,
                selectable: true,
                styleSheet: _darshanMarkdownStyleSheet(context),
                onTapLink: (text, href, title) => _launchDarshanLink(href),
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
              'assets/onboarding/screen-1.webp',
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

          // Insight — rendered as Markdown (server sends it in Markdown format)
          if (insight.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: MarkdownBody(
                data: insight,
                selectable: true,
                styleSheet: _darshanMarkdownStyleSheet(context),
                onTapLink: (text, href, title) => _launchDarshanLink(href),
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
              'assets/onboarding/2ndpaeg.png',
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
              'assets/onboarding/screen3.png',
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
                    ? 'assets/diya/diya-darsan.png'
                    : 'assets/diya/diya-darsan-unlit.png',
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
              icon: Image.asset('assets/diya/fire.png', width: 22, height: 22),
              label: Text(
                diyaLit ? 'Diya Lit ✓' : 'Light Your Diya',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.onAccent,
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
                      'assets/backgrounds/sunrise_background.png',
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
                        'assets/icons/sunrise.png',
                        width: 30,
                        height: 30,
                        color: AppColors.accent,
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
  final bool showHint;
  final VoidCallback onCTA;

  const _DarshanCTA({
    required this.step,
    required this.ctaLabel,
    required this.ctaColor,
    required this.showHint,
    required this.onCTA,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
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
                      color: AppColors.onPrimary,
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
                    color: AppColors.onPrimary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: (showHint && step < 3)
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Swipe left or tap to continue',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}