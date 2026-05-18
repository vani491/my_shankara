import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'dart:async';
// chandni changes
// import 'firebase_options.dart';
import 'screens/root_nav.dart';
import 'screens/theme_demo_page.dart';
import 'screens/edit_profile_screen.dart';
import 'setting_pages/settings_notifications.dart';
import 'screens/support.dart';

import 'screens/ba_about.dart';
import 'onboarding_flow/aa_onboarding_choice.dart';
import 'screens/welcome_slides.dart';
import 'setting_pages/privacy_terms.dart';
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

  await Firebase.initializeApp();
  final appState = AppState();
  await appState.attachAuth();
  await appState.loadOnboardingFlag();
  final initialUser = FirebaseAuth.instance.currentUser;
  if (initialUser != null) {
    await appState.checkProfileComplete();
  }
  FlutterNativeSplash.remove();
  runApp(MyApp(appState: appState));
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
        path: '/privacy-terms',
        builder: (_, __) => const PrivacyTermsPage(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile-basics',
        builder: (_, __) => ProfileBasicsPage(appState: widget.appState),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => VerifyEmailScreen(
          email: widget.appState.user?.email ?? '',
          appState: widget.appState,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [GoRoute(path: '/', builder: (_, __) => const RootNav())],
        // routes: [GoRoute(path: '/', builder: (_, __) => const ThemeDemoPage())],
      ),
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

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
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

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndexFromLocation(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/settings')) return 2;
    if (loc.startsWith('/profile')) return 1;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/profile');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final selected = _selectedIndexFromLocation(context);
    final theme = Theme.of(context);

    final loc = GoRouterState.of(context).uri.toString();
    final isChatPage = loc == '/' || loc.startsWith('/?');

    final navList = ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        SizedBox(
          height: 160,

          child: DrawerHeader(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: AssetImage('assets/user-profile.webp'),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shivani S.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(height: 2),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                context.push('/edit-profile');
                              },
                              style: const ButtonStyle(
                                padding: WidgetStatePropertyAll(
                                  EdgeInsets.zero,
                                ),
                                minimumSize: WidgetStatePropertyAll(
                                  Size(0, 0),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Edit Profile'),
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
        ),

        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: const Text('Manage Subscription'),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/manage-subscription');
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/settings');
          },
        ),
        const SizedBox(height: 100),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/about');
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Privacy & Terms'),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/privacy-terms');
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & Support'),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/support');
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () async {
            await showSignOutConfirmDialog(
              context,
              onConfirm: performSignOutActions,
            );
          },
        ),
      ],
    );

    final canPop = GoRouter.of(context).canPop();
    return Scaffold(
      key: _scaffoldKey,
      appBar: isChatPage ? null : AppBar(
        automaticallyImplyLeading: true,
      ),
      drawer: isWide ? null : Drawer(child: navList),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (i) => _onDestinationSelected(context, i),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
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