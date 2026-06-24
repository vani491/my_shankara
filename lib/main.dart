import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myshankara/screens/guru_dakshina.dart';
import 'package:myshankara/screens/share_darshan.dart';
import 'package:myshankara/setting_pages/terms_of_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/notification_service.dart';

import 'dart:async';
// chandni changes
// import 'firebase_options.dart';
import 'screens/root_nav.dart';
import 'screens/theme_demo_page.dart';
import 'setting_pages/settings_notifications.dart';
import 'screens/support.dart';

import 'screens/ba_about.dart';
import 'onboarding_flow/aa_onboarding_choice.dart';
import 'screens/welcome_slides.dart';
import 'setting_pages/privacy_policy.dart';
import 'screens/manage_subscription.dart';
import 'onboarding_flow/bb_verify_email_screen.dart';
import 'screens/profile_basics.dart';
// import 'screens/ca_onboarding_as_guest.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';

class AppState extends ChangeNotifier {
  AppState();

  User? _user;

  bool _isOnboarded = false;
  bool _isProfileComplete = false;
  bool _isEmailVerified = false;

  StreamSubscription<User?>? _sub;
  String? _preferredName;
  String? _fullName;
  Map<String, dynamic>? _userData;

  User? get user => _user;
  bool get isOnboarded => _isOnboarded;
  bool get isProfileComplete => _isProfileComplete;
  bool get isEmailVerified => _isEmailVerified;

  String? get preferredName => _preferredName;
  String? get fullName => _fullName;
  Map<String, dynamic>? get userData => _userData;

  Future<void> refreshEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      _isEmailVerified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      notifyListeners();
    }
  }

  Future<void> attachAuth() async {
    await _sub?.cancel();
    _sub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      _user = u;
      _isEmailVerified = u?.emailVerified ?? false;
      if (u != null) {
        await checkProfileComplete();
        await loadUserData();
      } else {
        _isProfileComplete = false;
        _preferredName = null;
        _fullName = null;
        _userData = null;
      }
      notifyListeners();
    });
  }

  Future<void> checkProfileComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.isAnonymous) {
      _isProfileComplete = true;
      notifyListeners();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _isProfileComplete = doc.exists && doc.data()?['fullName'] != null;
    } catch (e) {
      _isProfileComplete = false;
    }
    notifyListeners();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;


    if (user.isAnonymous) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        _userData = doc.data();
        _preferredName = _userData?['preferredName'];
        _fullName = _userData?['fullName'];
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = prefs.getBool('isOnboarded') ?? false;
    notifyListeners();
  }

  Future<void> setOnboarded([bool value = true]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboarded', value);
    _isOnboarded = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final appState = AppState();

  try {
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      debugPrint('Firebase init failed (continuing anyway): $e\n$st');
    }

    try {
      await appState.attachAuth().timeout(const Duration(seconds: 4));
    } catch (e, st) {
      debugPrint('attachAuth failed (continuing anyway): $e\n$st');
    }

    try {
      await appState.loadOnboardingFlag().timeout(const Duration(seconds: 4));
    } catch (e, st) {
      debugPrint('loadOnboardingFlag failed (continuing anyway): $e\n$st');
    }

    final initialUser = FirebaseAuth.instance.currentUser;
    if (initialUser != null) {
      try {
        await appState.checkProfileComplete().timeout(const Duration(seconds: 4));
      } catch (e, st) {
        debugPrint('checkProfileComplete failed (continuing anyway): $e\n$st');
      }
    }
  } catch (e, st) {
    debugPrint('Startup init error (continuing anyway): $e\n$st');
  } finally {
    FlutterNativeSplash.remove();
  }

  runApp(MyApp(appState: appState));

  // Non-blocking: notifications init + re-apply saved schedule, after UI is up.
  _initNotificationsInBackground();
}

Future<void> _initNotificationsInBackground() async {
  try {
    await NotificationService.instance.init();
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = prefs.getBool('notifications_enabled') ?? false;
    if (notifEnabled) {
      final hour = prefs.getInt('notif_hour') ?? 7;
      final minute = prefs.getInt('notif_minute') ?? 0;
      await NotificationService.instance.scheduleWeekly(
        hour: hour,
        minute: minute,
      );
    }
  } catch (e, st) {
    debugPrint('Notification init failed (non-fatal): $e\n$st');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.appState});
  final AppState appState;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: widget.appState,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final isOnboarded = widget.appState.isOnboarded;
      final user = widget.appState.user;
      final isAuthed = user != null;
      final isAnonymous = user?.isAnonymous ?? false;
      final isEmailVerified = widget.appState.isEmailVerified;
      final isProfileComplete = widget.appState.isProfileComplete;
      final currentPath = state.uri.path;

      final goingToLogin = currentPath == '/login';
      final goingToOnboarding = currentPath == '/onboarding';
      final goingToProfileBasics = currentPath == '/profile-basics';
      final goingToVerifyEmail = currentPath == '/verify-email';

      final isPublicLegalPage =
          currentPath == '/privacy-policy' || currentPath == '/terms-of-service';
      if (isPublicLegalPage) return null; // always allow, regardless of auth state

      // Onboarding check
      if (!isOnboarded && !goingToOnboarding) {
        return '/onboarding';
      }

      // Authentication check
      if (isOnboarded && !isAuthed && !goingToLogin && !goingToOnboarding) {
        return '/login';
      }

      // Email verification - SKIP for anonymous users
      if (isAuthed &&
          !isAnonymous &&
          !isEmailVerified &&
          !goingToVerifyEmail &&
          !goingToProfileBasics) {
        return '/verify-email';
      }

      // Profile completion - SKIP for anonymous users
      if (isAuthed &&
          !isAnonymous &&
          isEmailVerified &&
          !isProfileComplete &&
          !goingToProfileBasics) {
        return '/profile-basics';
      }

      // Already authenticated users shouldn't access login/onboarding
      if (isAuthed && !isAnonymous && (goingToLogin || goingToOnboarding)){
        return '/';
      }

      return null;
    },

    routes: [
      GoRoute(path: '/support', builder: (_, __) => const HelpSupportScreen()),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => OnboardingScreen(
          onFinished: () => widget.appState.setOnboarded(true),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsNotificationsScreen(),
      ),
      GoRoute(
        path: '/manage-subscription',
        builder: (_, __) => const ManageSubscriptionPage(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (_, __) => const PrivacyPolicyPage(),
      ),
      GoRoute(
        path: '/terms-of-service',
        builder: (_, __) => const TermsOfServicePage(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => ProfileBasicsPage(
          appState: widget.appState,
          isEditMode: true,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => ProfileBasicsPage(
          appState: widget.appState,
          isEditMode: true,
        ),
      ),
      GoRoute(
        path: '/profile-basics',
        builder: (_, __) => ProfileBasicsPage(appState: widget.appState),
      ),
      GoRoute(path: '/guru-dakshina', builder: (_, __) => const GuruDakshinaPage()),
      GoRoute(path: '/share-darshan', builder: (_, __) => const ShareDarshanPage()),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => VerifyEmailScreen(
          email: widget.appState.user?.email ?? '',
          appState: widget.appState,
        ),
      ),
      GoRoute(path: '/', builder: (_, __) => const RootNav()),
    ],
  );

  String get userEmail => 'test@gmail.com';

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoRouter + Drawer Shell',
      routerConfig: _router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> performSignOutActions() async {
  await FirebaseAuth.instance.signOut();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('isOnboarded');
}

Future<void> showSignOutConfirmDialog(
    BuildContext context, {
      Future<void> Function()? onConfirm,
    }) async {
  bool isSigningOut = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: !isSigningOut,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              "You'll need to sign in again to continue.",
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: isSigningOut ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isSigningOut
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.logout),
                label: Text(isSigningOut ? 'Signing out…' : 'Sign out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                  disabledBackgroundColor: Theme.of(
                    ctx,
                  ).colorScheme.error.withOpacity(0.6),
                ),
                onPressed: isSigningOut
                    ? null
                    : () async {
                  setState(() => isSigningOut = true);
                  try {
                    if (onConfirm != null) {
                      await onConfirm();
                    } else {
                      await performSignOutActions();
                    }
                    if (context.mounted) {
                      context.go('/login');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sign out failed: $e')),
                      );
                    }
                  } finally {
                    if (ctx.mounted) setState(() => isSigningOut = false);
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Home'));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Profile'));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Settings'));
}