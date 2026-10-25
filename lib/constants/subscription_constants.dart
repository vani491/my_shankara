/// Store product IDs and links for the MyShankara membership.
///
/// iOS and Android are separate on purpose, so one store's ID can change
/// without touching the other. Change an ID here and no other code needs to.
class SubscriptionConstants {
  SubscriptionConstants._();

  /// Monthly auto-renewing subscription (App Store Connect).
  static const String iosProductId = 'myshankara_monthly';

  /// Monthly auto-renewing subscription (Google Play Console).
  static const String androidProductId = 'myshankara_monthly';

  // Where users manage / cancel a subscription.
  static const String iosManageUrl = 'https://apps.apple.com/account/subscriptions';
  static const String androidManageUrl =
      'https://play.google.com/store/account/subscriptions';

  // Shown under the plan card. Replace with the final hosted pages if they move.
  static const String termsUrl = 'https://www.myshankara.ai/terms-and-conditions';
  static const String privacyUrl = 'https://www.myshankara.ai/privacy-policy';
}
