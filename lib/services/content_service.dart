import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single piece of remotely-hosted legal/info content
/// (Privacy Policy, Terms of Service, About MyShankara, ...).
class ContentPage {
  final String slug;
  final String title;
  final String content;
  final DateTime? updatedAt;

  const ContentPage({
    required this.slug,
    required this.title,
    required this.content,
    this.updatedAt,
  });

  factory ContentPage.fromJson(Map<String, dynamic> json) {
    return ContentPage(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

/// Fetches the app's legal/info pages (Privacy Policy, Terms of Service,
/// About MyShankara) from the MyShankara dashboard. Content is returned as
/// Markdown, rendered client-side.
class ContentService {
  ContentService._();

  static const String _baseUrl = 'https://dashboard.myshankara.ai';

  static Future<ContentPage> fetchPrivacyPolicy() =>
      _fetch('$_baseUrl/get_privacy_policy');

  static Future<ContentPage> fetchTermsOfService() =>
      _fetch('$_baseUrl/get_terms_of_service');

  static Future<ContentPage> fetchAboutMyShankara() =>
      _fetch('$_baseUrl/get_about_myshankara');

  static Future<ContentPage> _fetch(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return ContentPage.fromJson(data);
    }
    throw Exception('Failed to load content (${resp.statusCode})');
  }
}
