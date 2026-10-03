import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../widgets/remote_markdown_page.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RemoteMarkdownPage(
      title: 'About MyShankara',
      fetcher: ContentService.fetchAboutMyShankara,
    );
  }
}
