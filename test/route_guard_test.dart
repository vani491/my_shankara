import 'package:flutter_test/flutter_test.dart';
import 'package:myshankara/routing/route_guard.dart';

RouteGuardState _state({
  bool isReady = true,
  bool isOnboarded = true,
  bool isSignedIn = true,
  bool isGuest = false,
  bool isEmailVerified = true,
  bool? isProfileComplete = true,
}) =>
    RouteGuardState(
      isReady: isReady,
      isOnboarded: isOnboarded,
      isSignedIn: isSignedIn,
      isGuest: isGuest,
      isEmailVerified: isEmailVerified,
      isProfileComplete: isProfileComplete,
    );

const _appRoutes = [
  '/',
  '/settings',
  '/profile',
  '/edit-profile',
  '/about',
  '/support',
  '/guru-dakshina',
  '/share-darshan',
  '/manage-subscription',
  '/darshan',
];

void main() {
  group('startup (not ready)', () {
    final s = _state(isReady: false, isSignedIn: false, isOnboarded: false);

    test('holds every route on the splash', () {
      for (final r in [..._appRoutes, '/onboarding', '/login']) {
        expect(resolveRedirect(s, r), AppRoutes.splash, reason: r);
      }
      expect(resolveRedirect(s, AppRoutes.splash), isNull);
    });

    test('never shows the slides from not-yet-loaded defaults', () {
      expect(resolveRedirect(s, '/'), isNot(AppRoutes.onboarding));
    });
  });

  group('signed-in user (reported bugs)', () {
    // Issue 1: Settings opened the slides when the stored flag was missing.
    // Issue 2: slides flashed at launch for an already signed-in user.
    for (final onboarded in [true, false]) {
      for (final guest in [true, false]) {
        test('never reaches the slides (onboarded=$onboarded, guest=$guest)',
            () {
          final s = _state(isOnboarded: onboarded, isGuest: guest);
          for (final r in _appRoutes) {
            expect(resolveRedirect(s, r), isNull, reason: r);
          }
          expect(resolveRedirect(s, AppRoutes.onboarding), AppRoutes.home);
          expect(resolveRedirect(s, AppRoutes.splash), AppRoutes.home);
        });
      }
    }
  });

  group('signed out', () {
    test('fresh install sees the slides', () {
      final s = _state(isSignedIn: false, isOnboarded: false);
      expect(resolveRedirect(s, '/'), AppRoutes.onboarding);
      expect(resolveRedirect(s, '/settings'), AppRoutes.onboarding);
      expect(resolveRedirect(s, AppRoutes.onboarding), isNull);
    });

    test('after the slides, always the login screen', () {
      final s = _state(isSignedIn: false, isOnboarded: true);
      for (final r in [..._appRoutes, AppRoutes.onboarding, AppRoutes.splash]) {
        expect(resolveRedirect(s, r), AppRoutes.login, reason: r);
      }
      expect(resolveRedirect(s, AppRoutes.login), isNull);
    });
  });

  group('account checks', () {
    test('unverified email goes to verification', () {
      final s = _state(isEmailVerified: false, isProfileComplete: null);
      expect(resolveRedirect(s, '/'), AppRoutes.verifyEmail);
      expect(resolveRedirect(s, '/settings'), AppRoutes.verifyEmail);
      expect(resolveRedirect(s, AppRoutes.verifyEmail), isNull);
      expect(resolveRedirect(s, AppRoutes.profileBasics), isNull);
    });

    test('confirmed incomplete profile goes to the profile form', () {
      final s = _state(isProfileComplete: false);
      expect(resolveRedirect(s, '/'), AppRoutes.profileBasics);
      expect(resolveRedirect(s, '/settings'), AppRoutes.profileBasics);
      expect(resolveRedirect(s, AppRoutes.profileBasics), isNull);
    });

    test('unknown profile state does not force the profile form', () {
      final s = _state(isProfileComplete: null);
      for (final r in _appRoutes) {
        expect(resolveRedirect(s, r), isNull, reason: r);
      }
    });

    test('signed-in account leaves login for home; guest may stay', () {
      expect(resolveRedirect(_state(), AppRoutes.login), AppRoutes.home);
      expect(resolveRedirect(_state(isGuest: true), AppRoutes.login), isNull);
    });

    test('guests skip verification and profile checks', () {
      final s = _state(
        isGuest: true,
        isEmailVerified: false,
        isProfileComplete: false,
      );
      expect(resolveRedirect(s, '/'), isNull);
    });
  });

  test('legal pages are reachable in every state', () {
    for (final s in [
      _state(isReady: false),
      _state(isSignedIn: false, isOnboarded: false),
      _state(isEmailVerified: false),
    ]) {
      expect(resolveRedirect(s, AppRoutes.privacyPolicy), isNull);
      expect(resolveRedirect(s, AppRoutes.termsOfService), isNull);
    }
  });
}
