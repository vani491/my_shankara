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
import 'services/subscription_service.dart';

import 'dart:async';

// chandni changes
import 'firebase_options.dart';
import 'screens/root_nav.dart';
import 'screens/ac_darshan_screen.dart';
import 'setting_pages/settings_notifications.dart';
import 'screens/support.dart';

import 'screens/ba_about.dart';
import 'onboarding_flow/aa_onboarding_choice.dart';
import 'screens/welcome_slides.dart';
import 'setting_pages/privacy_policy.dart';
import 'screens/manage_subscription.dart';
import 'onboarding_flow/bb_verify_email_screen.dart';
import 'screens/profile_basics.dart';
import 'routing/route_guard.dart';
// import 'screens/ca_onboarding_as_guest.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';

class AppState extends ChangeNotifier {
  static const _onboardedKey = 'isOnboarded';

  /// Upper bound on how long startup may hold the splash if auth or the
  /// preferences read never resolves (Firebase init failed, channel hung).
  static const _startupTimeout = Duration(seconds: 10);
  static const _profileReadTimeout = Duration(seconds: 4);

  User? _user;
  bool _isEmailVerified = false;

  // null = not yet known (loading, or the last read failed/timed out).
  bool? _isProfileComplete;
  Map<String, dynamic>? _userData;

  // Per-device "has seen the intro slides" flag. SharedPreferences is the
  // source of truth; this is the in-memory copy.
  bool _isOnboarded = false;

  // The router must not decide anything until both are true; see [isReady].
  bool _authResolved = false;
  bool _onboardingLoaded = false;
  final Completer<void> _readyCompleter = Completer<void>();
  Timer? _readyWatchdog;

  StreamSubscription<User?>? _authSub;

  // Bumped on every auth event so an older event's slow Firestore read can't
  // overwrite the state of a newer one (e.g. sign-out during sign-in).
  int _authGeneration = 0;

  User? get user => _user;

  bool get isOnboarded => _isOnboarded;

  bool? get isProfileComplete => _isProfileComplete;

  bool get isEmailVerified => _isEmailVerified;

  Map<String, dynamic>? get userData => _userData;

  String? get preferredName => _userData?['preferredName'] as String?;

  String? get fullName => _userData?['fullName'] as String?;

  /// True once the first auth state and the onboarding flag have both loaded.
  bool get isReady => _authResolved && _onboardingLoaded;

  /// Completes once [isReady] first becomes true.
  Future<void> get whenReady => _readyCompleter.future;

  RouteGuardState get routeGuardState => RouteGuardState(
    isReady: isReady,
    isOnboarded: _isOnboarded,
    isSignedIn: _user != null,
    isGuest: _user?.isAnonymous ?? false,
    isEmailVerified: _isEmailVerified,
    isProfileComplete: _isProfileComplete,
  );

  /// Starts loading the onboarding flag and listening to auth. Call once,
  /// after `Firebase.initializeApp` (successful or not).
  void start() {
    _readyWatchdog = Timer(_startupTimeout, _forceReady);
    unawaited(_loadOnboardingFlag());
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(
        (u) => unawaited(_onAuthChanged(u)),
        onError: (Object e, StackTrace st) {
          debugPrint('AppState: auth stream error: $e\n$st');
          _resolveAuthAsSignedOutIfPending();
        },
      );
    } catch (e, st) {
      // Firebase isn't available; there is no session to wait for.
      debugPrint('AppState: could not listen to auth: $e\n$st');
      _resolveAuthAsSignedOutIfPending();
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    final generation = ++_authGeneration;

    // Signed in (guest included) implies the slides were already seen.
    if (user != null) _markOnboarded();

    // Work out the new state completely before publishing any of it, so the
    // router never sees a new user paired with the previous user's profile.
    bool? profileComplete;
    Map<String, dynamic>? userData;
    if (user != null && user.isAnonymous) {
      profileComplete = true;
    } else if (user != null) {
      final doc = await _fetchUserDoc(user);
      if (generation != _authGeneration) return; // superseded by a newer event
      if (doc != null) {
        userData = doc.data();
        profileComplete = doc.exists && userData?['fullName'] != null;
      } else if (_user?.uid == user.uid) {
        // Read failed: keep what we knew for this user, never guess "false".
        userData = _userData;
        profileComplete = _isProfileComplete;
      }
    }

    _user = user;
    _isEmailVerified = user?.emailVerified ?? false;
    _isProfileComplete = profileComplete;
    _userData = userData;
    _authResolved = true;
    _completeReadyIfNeeded();
    notifyListeners();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _fetchUserDoc(
    User user,
  ) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(_profileReadTimeout);
    } catch (e) {
      debugPrint('AppState: user profile read failed: $e');
      return null;
    }
  }

  /// Re-reads the signed-in user's profile (e.g. after the profile form is
  /// saved). A failed read leaves the known state untouched.
  Future<void> checkProfileComplete() async {
    final user = _user;
    if (user == null) return;
    if (user.isAnonymous) {
      _isProfileComplete = true;
      notifyListeners();
      return;
    }
    final generation = _authGeneration;
    final doc = await _fetchUserDoc(user);
    if (doc == null || generation != _authGeneration) return;
    _userData = doc.data();
    _isProfileComplete = doc.exists && _userData?['fullName'] != null;
    notifyListeners();
  }

  Future<void> refreshEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    _isEmailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    notifyListeners();
  }

  Future<void> _loadOnboardingFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_onboardedKey) ?? false;
      // OR, not assign: a sign-in may already have marked it while we read.
      _isOnboarded = _isOnboarded || stored;
    } catch (e, st) {
      debugPrint('AppState: could not read isOnboarded: $e\n$st');
    }
    _onboardingLoaded = true;
    _completeReadyIfNeeded();
    notifyListeners();
  }

  /// Called by the intro slides when the user finishes or skips them.
  Future<void> setOnboarded([bool value = true]) async {
    _isOnboarded = value;
    _onboardingLoaded = true;
    await _persistOnboarded(value);
    _completeReadyIfNeeded();
    notifyListeners();
  }

  /// Sets the flag in memory and on disk. Restores it if it is missing for a
  /// signed-in user (an older build cleared it on sign-out, or iOS kept the
  /// Firebase session in the Keychain across a reinstall), so the slides stay
  /// strictly "once per install".
  void _markOnboarded() {
    if (_isOnboarded) return;
    _isOnboarded = true;
    unawaited(_persistOnboarded(true));
  }

  Future<void> _persistOnboarded(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardedKey, value);
    } catch (e) {
      debugPrint('AppState: could not persist isOnboarded: $e');
    }
  }

  void _resolveAuthAsSignedOutIfPending() {
    if (_authResolved) return;
    _authResolved = true;
    _completeReadyIfNeeded();
    notifyListeners();
  }

  void _forceReady() {
    if (isReady) return;
    debugPrint(
      'AppState: startup not resolved in time '
      '(auth=$_authResolved, onboarding=$_onboardingLoaded), forcing ready',
    );
    if (!_authResolved) {
      // Best effort from the synchronously restored session. A late auth
      // event still lands normally through [_onAuthChanged].
      try {
        _user = FirebaseAuth.instance.currentUser;
      } catch (_) {
        _user = null;
      }
      _isEmailVerified = _user?.emailVerified ?? false;
      if (_user != null) _markOnboarded();
      if (_user?.isAnonymous ?? false) _isProfileComplete = true;
      _authResolved = true;
    }
    _onboardingLoaded = true;
    _completeReadyIfNeeded();
    notifyListeners();
  }

  void _completeReadyIfNeeded() {
    if (!isReady || _readyCompleter.isCompleted) return;
    _readyWatchdog?.cancel();
    _readyCompleter.complete();
  }

  @override
  void dispose() {
    _readyWatchdog?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native splash up until the router knows where to go, so the
  // first screen the user sees is already the right one.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase init failed (continuing anyway): $e\n$st');
  }

  final appState = AppState()..start();
  unawaited(
    appState.whenReady.then((_) {
      // Remove after the frame that renders the resolved route.
      widgetsBinding.addPostFrameCallback((_) => FlutterNativeSplash.remove());
      widgetsBinding.ensureVisualUpdate();
    }),
  );

  // Start listening to the purchase stream right away so no store transaction
  // delivered at launch is missed. The listener is attached synchronously;
  // only the product lookup is async, so it is not awaited.
  unawaited(SubscriptionService.instance.init());

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
      await NotificationService.instance.scheduleDaily(
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
    // Start on the splash; the guard moves on once AppState.isReady.
    initialLocation: AppRoutes.splash,
    refreshListenable: widget.appState,
    debugLogDiagnostics: false,

    // All routing rules live in routing/route_guard.dart. Re-evaluated on
    // every navigation and whenever AppState notifies.
    redirect: (context, state) =>
        resolveRedirect(widget.appState.routeGuardState, state.uri.path),

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const _StartupSplash(),
      ),
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
        builder: (_, __) =>
            ProfileBasicsPage(appState: widget.appState, isEditMode: true),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            ProfileBasicsPage(appState: widget.appState, isEditMode: true),
      ),
      GoRoute(
        path: '/profile-basics',
        builder: (_, __) => ProfileBasicsPage(appState: widget.appState),
      ),
      GoRoute(
        path: '/darshan',
        builder: (_, state) =>
            DarshanScreen(onDarshanComplete: state.extra as VoidCallback?),
      ),
      GoRoute(
        path: '/guru-dakshina',
        builder: (_, __) => const GuruDakshinaPage(),
      ),
      GoRoute(
        path: '/share-darshan',
        builder: (_, __) => const ShareDarshanPage(),
      ),
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
  void dispose() {
    SubscriptionService.instance.dispose();
    super.dispose();
  }

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
  // 'isOnboarded' is a per-device flag (has this device seen the intro
  // slides), so it is intentionally NOT cleared on sign-out.
  await FirebaseAuth.instance.signOut();
}

/// Shown while [AppState.isReady] is false. Deliberately has no navigation of
/// its own — the router redirect moves on once auth and the flag have loaded.
class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/splash-logo.png', width: 160),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
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
            content: Text(
              "You'll need to sign in again to continue.",
              style: TextStyle(
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSigningOut ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                child: Text(isSigningOut ? 'Signing out…' : 'Sign out'),
              ),
            ],
          );
        },
      );
    },
  );
}
