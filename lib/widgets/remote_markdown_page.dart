import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../services/content_service.dart';

/// A page that fetches a [ContentPage] (Markdown content) from the backend
/// and renders it. Used for Privacy Policy, Terms of Service, and About
/// MyShankara, which are all served from the same dashboard CMS.
class RemoteMarkdownPage extends StatefulWidget {
  final String title;
  final Future<ContentPage> Function() fetcher;

  const RemoteMarkdownPage({
    super.key,
    required this.title,
    required this.fetcher,
  });

  @override
  State<RemoteMarkdownPage> createState() => _RemoteMarkdownPageState();
}

class _RemoteMarkdownPageState extends State<RemoteMarkdownPage> {
  late Future<ContentPage> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
  }

  void _retry() {
    setState(() {
      _future = widget.fetcher();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<ContentPage>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _retry);
            }
            final page = snapshot.data!;
            return _ContentView(page: page, fallbackTitle: widget.title);
          },
        ),
      ),
    );
  }
}

class _ContentView extends StatelessWidget {
  final ContentPage page;
  final String fallbackTitle;

  const _ContentView({required this.page, required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final hasContent = page.content.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (page.updatedAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Last updated: ${DateFormat('MMMM d, yyyy').format(page.updatedAt!.toLocal())}',
                style: tt.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasContent
                ? MarkdownBody(
                    data: page.content,
                    selectable: true,
                    styleSheet: _markdownStyleSheet(context),
                    onTapLink: (text, href, title) {
                      if (href == null) return;
                      launchUrlString(href);
                    },
                  )
                : Text(
                    'This content isn\'t available yet. Please check back soon.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© 2026 MyShankara. All rights reserved.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final bodyColor = cs.onSurface.withValues(alpha: 0.8);

    return MarkdownStyleSheet(
      p: tt.bodyMedium?.copyWith(height: 1.6, color: bodyColor),
      h1: tt.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      h2: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      h3: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      strong: tt.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      em: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: bodyColor),
      listBullet: tt.bodyMedium?.copyWith(color: bodyColor),
      a: tt.bodyMedium?.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
      ),
      blockquote: tt.bodyMedium?.copyWith(
        color: bodyColor,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      code: tt.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: cs.primary.withValues(alpha: 0.06),
        color: cs.onSurface,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load this page.',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Please check your connection and try again.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
