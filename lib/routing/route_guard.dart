/// Top-level routing rules for the app, kept free of Flutter/Firebase so they
/// can be unit tested exhaustively (see test/route_guard_test.dart).
library;

abstract final class AppRoutes {
  static const splash = '/splash';
  static const home = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const verifyEmail = '/verify-email';
  static const profileBasics = '/profile-basics';
  static const privacyPolicy = '/privacy-policy';
  static const termsOfService = '/terms-of-service';
}

/// An immutable view of the session state the router decides on.
class RouteGuardState {
  const RouteGuardState({
    required this.isReady,
    required this.isOnboarded,
    required this.isSignedIn,
    required this.isGuest,
    required this.isEmailVerified,
    required this.isProfileComplete,
  });

  /// False until the first auth state and the stored onboarding flag are
  /// both known. Until then every other field is a placeholder, not an answer.
  final bool isReady;

  /// This device has been through the intro slides.
  final bool isOnboarded;

  final bool isSignedIn;

  /// Signed in anonymously ("Continue as Guest").
  final bool isGuest;

  final bool isEmailVerified;

  /// null = not known yet (still loading, or the last read failed). Only a
  /// confirmed `false` may send the user to the profile form.
  final bool? isProfileComplete;
}

/// Returns where [location] must redirect to, or null to allow it.
///
/// Rules are evaluated in order. Each returns a final answer, so a later rule
/// never runs with an earlier rule's assumptions violated.
String? resolveRedirect(RouteGuardState s, String location) {
  // Legal pages are linked from the sign-up screens, so they are reachable in
  // every state, including while startup is still resolving.
  if (location == AppRoutes.privacyPolicy ||
      location == AppRoutes.termsOfService) {
    return null;
  }

  // 1. Startup. Nothing is decided from not-yet-loaded defaults: hold on the
  //    splash until auth and the onboarding flag are both known.
  if (!s.isReady) return _onlyAllow(AppRoutes.splash, location);

  // 2. Signed out: intro slides once per install, then the login screen.
  if (!s.isSignedIn) {
    return _onlyAllow(
      s.isOnboarded ? AppRoutes.login : AppRoutes.onboarding,
      location,
    );
  }

  // 3. Signed in (guest or account). Being signed in means the slides were
  //    already seen, so a signed-in user can never land on them, whatever
  //    the stored flag says.
  if (location == AppRoutes.onboarding || location == AppRoutes.splash) {
    return AppRoutes.home;
  }

  // Guests skip verification and profile; they may visit /login to upgrade.
  if (s.isGuest) return null;

  // 4. Account users: verify email first (the verify screen hands off to the
  //    profile form itself), then complete the profile.
  if (!s.isEmailVerified) {
    if (location == AppRoutes.verifyEmail ||
        location == AppRoutes.profileBasics) {
      return null;
    }
    return AppRoutes.verifyEmail;
  }

  if (s.isProfileComplete == false) {
    return _onlyAllow(AppRoutes.profileBasics, location);
  }

  if (location == AppRoutes.login) return AppRoutes.home;

  return null;
}

String? _onlyAllow(String target, String location) =>
    location == target ? null : target;
