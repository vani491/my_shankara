// colors.dart - https://chatgpt.com/c/68ff64f3-024c-8321-9f39-90d49d332d21, https://chatgpt.com/c/68ff5b68-a384-8323-ad07-6725e2e0810f
import 'package:flutter/material.dart';

/// Brand-led palette derived from Ivory, Indigo, and Saffron.
/// Values chosen for strong WCAG contrast between base colors and their "on*" pairs.
final class AppColors {
  const AppColors._();

  // key actions
  static const Color primary = Color(0xFF2A265F); // Indigo 500, bluish
  static const Color onPrimary = Color(0xFFFFFFFF); // AA/AAA on primary

  // supporting actions/accents
  static const Color secondary = Color(0xFF5C6BC0); // Indigo 400 (distinct from primary)
  static const Color onSecondary = Color(0xFFFFFFFF);

  // small highlights (badges, indicators)
  static const Color accent = Color(0xFFF4972A);
  static const Color onAccent = Color(0xFF111827); // Near-black for excellent contrast

  // app backdrop; default text/icons
  static const Color background = Color(0xFFFFFFF0); // Ivory
  static const Color onBackground = Color(0xFF1A1C1E); // Deep neutral ink

  // cards, sheets, bars
  // static const Color surface = Color(0xFFFFFFFF); // Clean white atop ivory background
  static const Color surface = Color(0xFFFFF8F0);
  static const Color onSurface = Color(0xFF1A1C1E);

  // destructive/error states
  static const Color error = Color(0xFFD32F2F); // Red 700
  static const Color onError = Color(0xFFFFFFFF);

  // confirmations
  static const Color success = Color(0xFF2E7D32); // Green 800
  static const Color onSuccess = Color(0xFFFFFFFF);

  // cautions
  static const Color warning = Color(0xFFFF8F00); // Amber 800 (saffron-adjacent)
  static const Color onWarning = Color(0xFF111827);

  // interactive text (distinct from Primary)
  static const Color link = Color(0xFF303F9F); // Indigo 700 (clearly different from primary)

  // borders, dividers, input strokes
  static const Color outline = Color(0xFFD8D5C5); // Warm neutral stroke over ivory/white

  // muted text/icons for disabled controls
  static const Color disabled = Color(0x61000000);

  // high-contrast focus ring
  static const Color focus = Color(0xFFFFB300); // Strong saffron ring visible on light/dark

  // modal/backdrop overlay (translucent layer)
  static const Color scrim = Color(0x99000000);
}
