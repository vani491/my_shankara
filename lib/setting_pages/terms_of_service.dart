import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../widgets/remote_markdown_page.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoteMarkdownPage(
      title: 'Terms of Service',
      fetcher: ContentService.fetchTermsOfService,
    );
  }
}
