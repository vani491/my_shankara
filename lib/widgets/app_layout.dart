import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AppLayout extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? drawer;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  // Static image background (kept for backwards-compat)
  final String? backgroundImage;
  final double backgroundOpacity;

  // Video background — takes priority over backgroundImage when set
  final String? backgroundVideo;
  final double backgroundVideoOpacity;

  const AppLayout({
    Key? key,
    required this.title,
    required this.body,
    this.actions,
    this.drawer,
    this.showMenuButton = true,
    this.onMenuPressed,
    this.backgroundImage,
    this.backgroundOpacity = 1.0,
    this.backgroundVideo,
    this.backgroundVideoOpacity = 1.0,
  }) : super(key: key);

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.backgroundVideo != null) {
      _initVideo(widget.backgroundVideo!);
    }
  }

  @override
  void didUpdateWidget(AppLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialise if the video asset path changed
    if (widget.backgroundVideo != oldWidget.backgroundVideo) {
      _videoController?.dispose();
      _videoController = null;
      if (widget.backgroundVideo != null) {
        _initVideo(widget.backgroundVideo!);
      }
    }
  }

  Future<void> _initVideo(String assetPath) async {
    final controller = VideoPlayerController.asset(assetPath);
    _videoController = controller;

    await controller.initialize();
    controller.setLooping(true);
    controller.setVolume(0); // muted — background ambience
    controller.play();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // ── Background layer ───────────────────────────────────────────────────────

  Widget _buildBackground() {
    // 1. Video background
    if (widget.backgroundVideo != null) {
      final ctrl = _videoController;
      if (ctrl != null && ctrl.value.isInitialized) {
        return Opacity(
          opacity: widget.backgroundVideoOpacity,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            ),
          ),
        );
      }
      // Show nothing (transparent) while the video is loading
      return const SizedBox.shrink();
    }

    // 2. Static image background (legacy)
    if (widget.backgroundImage != null) {
      return Positioned.fill(
        child: Image.asset(
          widget.backgroundImage!,
          fit: BoxFit.cover,
          opacity: AlwaysStoppedAnimation(widget.backgroundOpacity),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBackground =
        widget.backgroundVideo != null || widget.backgroundImage != null;

    return Scaffold(
      // Extend body (and video) behind the AppBar so the video fills the screen
      extendBodyBehindAppBar: hasBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.showMenuButton
            ? Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: widget.onMenuPressed ??
                    () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        )
            : null,
        title: Text(
          widget.title,
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        // Keep AppBar transparent so the video shows through it
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: widget.actions,
      ),
      drawer: widget.drawer,
      body: hasBackground
          ? Stack(
        fit: StackFit.expand,
        children: [
          // Video / image layer — rendered first (bottom)
          _buildBackground(),
          // Content layer on top
          widget.body,
        ],
      )
          : widget.body,
    );
  }
}