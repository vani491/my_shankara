import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:myshankara/screens/root_nav.dart';
import '../main.dart';
import '../model/mood_data.dart';
import '../theme/colors.dart';
import '../widgets/app_layout.dart';
import 'ac_darshan_screen.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

// AFTER
class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToChat;
  final VoidCallback? onGoToDarshan;
  const HomeScreen({super.key, this.onGoToChat,this.onGoToDarshan,});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {

  int? _selectedMood;
  // Sloka state
  String _slokaDeity = '';
  String _slokaDevanagari = '';
  String _slokaRoman = '';
  String _slokaMeaning = '';
  bool _slokaLoading = true;
  bool _slokaDarshan = true;

  String _titleDarshan = '';
  String _teaserDarshan = '';
  String _timezone = '';

  int _lifetimeDiyas = 0;
  List<bool> _weekDiyas = List.filled(7, false); // Sun to Sat
  bool _diyaStatsLoading = true;
  String _preferredName = 'Sishya';
  bool _isGuest = false;


  @override
  void initState() {
    super.initState();
    _initData();
    _loadUserDisplayName();
  }

  Future<void> _initData() async {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    _timezone = timezoneInfo.identifier;
    _fetchSloka();
    _fetchDarshan();
    fetchDiyaStats();
  }

  Future<void> _fetchSloka() async {
    try {
      final uri = Uri.parse('https://dashboard.myshankara.ai/get_sloka')
          .replace(queryParameters: {
        'timezone': _timezone,
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _slokaDeity = (data['deity'] as String?) ?? '';
          _slokaDevanagari = (data['devanagari'] as String?) ?? '';
          _slokaRoman = (data['roman_simple'] as String?) ?? '';
          _slokaMeaning = (data['meaning'] as String?) ?? '';
          _slokaLoading = false;
        });
      } else {
        setState(() => _slokaLoading = false);
      }
    } catch (_) {
      setState(() => _slokaLoading = false);
    }
  }
  // ── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchDarshan() async {
    try {
      final uri = Uri.parse('https://dashboard.myshankara.ai/get_darshan')
          .replace(queryParameters: {
        'timezone': _timezone,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _titleDarshan        = data['title']           as String? ?? '';
            _teaserDarshan       = data['teaser']          as String? ?? '';
            _slokaDarshan    = false;
          });
        }
      } else {
        if (mounted) setState(() => _slokaDarshan = false);
      }
    } catch (_) {
      if (mounted) setState(() => _slokaDarshan = false);
    }
  }


  Future<void> fetchDiyaStats() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Current week ke Sun-Sat dates nikalo
    final now = DateTime.now();
    // Sunday = 0 in dart weekday (weekday 7 = Sunday, so adjust)
    final todayWeekday = now.weekday == 7 ? 0 : now.weekday; // 0=Sun, 1=Mon...6=Sat
    final sunday = now.subtract(Duration(days: todayWeekday));

    List<bool> weekStatus = List.filled(7, false);

    for (int i = 0; i < 7; i++) {
      final day = sunday.add(Duration(days: i));
      final dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('diyaLogs')
          .doc(dateKey)
          .get();
      weekStatus[i] = snap.exists;
    }

    // Lifetime count
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final lifetime = (userSnap.data()?['totalDiyasLit'] as num?)?.toInt() ?? 0;

    if (mounted) {
      setState(() {
        _weekDiyas = weekStatus;
        _lifetimeDiyas = lifetime;
        _diyaStatsLoading = false;
      });
    }
  }


  Future<void> _loadUserDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;

    // Guest = anonymous or not signed in
    if (user == null || user.isAnonymous) {
      setState(() {
        _isGuest = true;
        _preferredName = 'Sishya';
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final name = doc.data()?['preferredName'] as String?;

      setState(() {
        _preferredName = (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : 'Sishya';
      });
    } catch (e) {
      // Fallback gracefully on error
      setState(() {
        _preferredName = 'Sishya';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppLayout(
      title: 'Namaste, $_preferredName',
      backgroundImage: 'assets/home-background.jpg',
      backgroundOpacity: 0.6,

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(context),

            const SizedBox(height: 8),

            ListTile(
              leading: Icon(Icons.person_outline, color: cs.primary),
              title: const Text('Profile'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.favorite_outline, color: cs.primary),
              title: const Text('Manage Subscription'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: cs.primary),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.info_outline, color: cs.primary),
              title: const Text('About'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: cs.primary),
              title: const Text('Help & Support'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text('Sign out', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(context);
                showSignOutConfirmDialog(
                  context,
                  onConfirm: performSignOutActions,
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                fetchDiyaStats(),
              ]);
            },
            child: SingleChildScrollView(
              // padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'A new day, a new beginning.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface.withValues(alpha: 0.60),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFF0),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      image: DecorationImage(
                        image: AssetImage('assets/stir_background.png'), // or NetworkImage('https://...')
                        fit: BoxFit.cover, // cover, contain, fill, fitWidth, fitHeight, none
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'What stirs within you today?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildMoodButton(context, '😔', 0),
                            _buildMoodButton(context, '😕', 1),
                            _buildMoodButton(context, '😐', 2),
                            _buildMoodButton(context, '🙂', 3),
                            _buildMoodButton(context, '😄', 4),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Background image — fills entire container
                          Positioned.fill(
                            child: Image.asset(
                              'assets/home-page-container1-image.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    cs.primary.withValues(alpha: 0.00),
                                    cs.primary.withValues(alpha: 1.00),
                                  ],
                                  center: Alignment(0.75, 0.2),
                                  radius: 1.2,
                                ),
                              ),
                            ),
                          ),

                          // Foreground content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.45,
                                      ),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '✨',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "Today's Darshan",
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  _titleDarshan,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _teaserDarshan,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () => widget.onGoToDarshan?.call(),
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
                                    'Begin Darshan',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
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

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                      image: DecorationImage(
                          image: AssetImage('assets/diya_tracker_background.png'),
                          fit: BoxFit.cover
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top row: heading + lifetime diyas ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    'Your Seva This Week',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Every day you show up, your light grows.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right – Lifetime Diyas badge (stacked label + big number)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBF2).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFC5A059).withValues(alpha: 0.4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Lifetime',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/diya-lit.png',
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(width: 25),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 0),
                                        child: Text(
                                          _diyaStatsLoading ? '...' : '$_lifetimeDiyas',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),


                                  const SizedBox(width: 15),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── 7-day diya row ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ...['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                .asMap()
                                .entries
                                .map((e) => _buildDiyaDay(context, e.value, _weekDiyas[e.key]))
                                .toList(),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Divider(
                          thickness: 0.8,
                          color: AppColors.outline.withValues(alpha: 0.5),
                        ),

                        const SizedBox(height: 4),

                        // ── Bottom message ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            const SizedBox(width: 6),

                            if (_isGuest)
                              ElevatedButton.icon(
                                onPressed: () => context.go('/login'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  elevation: 0,
                                ),
                                label: Text(
                                  'Sign up to track your seva',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              )
                            else
                              Text(
                                'Every diya is a step closer to the divine.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurface.withValues(alpha: 0.70),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      // Use the brand surface colour (warm ivory-white)
                      color: AppColors.surface,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.20),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Top label row ──
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Daily Shloka',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: AppColors.outline,
                            ),

                            //  Pushes the pill to the far right
                            const Spacer(),

                            if (_slokaLoading)
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.onSurface,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  //  Dark border matching your theme
                                  border: Border.all(
                                    color: const Color(0xFF8F0929),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 100),
                                      child: Text(
                                        _slokaDeity,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 15,
                                            color: const Color(0xFFD4860A),
                                            fontWeight: FontWeight.w600
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    //  Replace with your own PNG
                                    Image.asset(
                                      'assets/om_icon.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Sanskrit shloka ──
                        Text(
                          _slokaDevanagari,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Transliteration ──
                        Text(
                          _slokaRoman,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Container(height: 1, color: const Color(0xFF2A265F).withValues(alpha: 0.9)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'ॐ',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFF2A265F).withValues(alpha: 1.0),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(height: 1, color: const Color(0xFF2A265F).withValues(alpha: 0.9)),
                            ),
                          ],
                        ),


                        const SizedBox(height: 14),

                        // ── Meaning ──
                        Text(
                          _slokaMeaning,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.onBackground.withValues(alpha: 0.80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

        )
      ),
    );
  }






  Widget _buildMoodButton(BuildContext context, String emoji, int index) {
    return GestureDetector(
      onTap: () => _showMoodDialog(context, index),
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundImage: AssetImage('assets/user-profile.webp'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shivani S.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll(EdgeInsets.zero),
                      minimumSize: WidgetStatePropertyAll(Size(0, 0)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Diya day cell ─────────────────────────────────────────────────────────
  Widget _buildDiyaDay(BuildContext context, String day, bool isLit) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          isLit ? 'assets/diya-lit.png' : 'assets/diya-nlit.png',
          width: 32,
          height: 32,
        ),
        const SizedBox(height: 4),
        Text(
          day,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isLit
                ? AppColors.primary
                : AppColors.onSurface.withValues(alpha: 0.30),
          ),
        ),
      ],
    );
  }



  // Dialog method
  void _showMoodDialog(BuildContext context, int index) {
    final mood = moodDataList[index];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: AssetImage('assets/stir_popup_background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                // Subtle white overlay so text stays readable
                color: Colors.white.withValues(alpha: 0.35),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji
                  Text(mood.emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    mood.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    mood.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Question
                  Text(
                    mood.question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary button - Speak to the Guru
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onGoToChat?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A020),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        elevation: 6,
                        shadowColor: const Color(0xFFE8A020).withValues(alpha: 0.5),
                      ),
                      child: const Text(
                        'Speak to the Guru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary button - Maybe later
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
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

}