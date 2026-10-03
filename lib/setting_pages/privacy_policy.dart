import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../widgets/remote_markdown_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoteMarkdownPage(
      title: 'Privacy Policy',
      fetcher: ContentService.fetchPrivacyPolicy,
    );
  }
}
