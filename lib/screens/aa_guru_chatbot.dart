import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myshankara/theme/app_theme.dart';
import '../app_drawer.dart';
import '../main.dart';
import '../theme/colors.dart';
import '../widgets/app_layout.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding_flow/ba_create_account.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/access_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// ─── Guest daily-message limit ───────────────────────────────────────────────
const int _kGuestDailyLimit = 5;

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final List<_Msg> _messages = [];
  bool _botTyping = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Guest helpers ──────────────────────────────────────────────────────────

  /// True when the current user is anonymous (guest) or not signed in.
  bool get _isGuest => _auth.currentUser?.isAnonymous ?? true;

  /// Returns how many messages the guest has sent today.
  Future<int> _guestMessageCountToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('guest_msg_date') ?? '';

    if (today != lastDate) {
      // New day → reset
      await prefs.setString('guest_msg_date', today);
      await prefs.setInt('guest_msg_count', 0);
      return 0;
    }
    return prefs.getInt('guest_msg_count') ?? 0;
  }

  Future<bool> _canGuestSendMessage() async {
    if (!_isGuest) return true;
    return (await _guestMessageCountToday()) < _kGuestDailyLimit;
  }

  Future<void> _incrementGuestCount() async {
    if (!_isGuest) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('guest_msg_count') ?? 0) + 1;
    await prefs.setInt('guest_msg_count', count);
    if (mounted) setState(() => _guestMessagesUsed = count);
  }

  /// Shows a dialog with the exact time the limit resets (next midnight).
  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Daily Limit Reached',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 30
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Body
                Text(
                  'You\'ve used all $_kGuestDailyLimit messages for today.Sign up for unlimited access to your spiritual guide.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onBackground.withOpacity(0.75),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 28),

                // Primary — mirrors "Start 30-day Free Trial"
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/login');
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sign up',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary — mirrors "Continue as Guest"
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Maybe Later',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ── Firestore helpers ──────────────────────────────────────────────────────

  String? getUid() => _auth.currentUser?.uid;

  Future<void> _saveMessageToFirestore(_Msg msg) async {
    final uid = getUid();
    if (uid == null || _currentChatId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .add({
      'role': msg.role.name,
      'text': msg.text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(_currentChatId)
        .update({'lastMessage': msg.text});
  }

  // ── Guest message counter (live, in-memory) ───────────────────────────────
  int _guestMessagesUsed = 0;

  // ── Chat history (only used for signed-in users) ───────────────────────────
  final List<_ChatSession> _chatHistory = [];
  String _currentChatId = '';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_isGuest) {
      // Guests get a fresh, in-memory-only session – no Firestore touched.
      _seedFirstMessage();
      _loadGuestCount();
    } else {
      _loadChatsFromFirestore();
      _loadLastChatOrCreate();
    }
  }

  Future<void> _loadGuestCount() async {
    final count = await _guestMessageCountToday();
    if (mounted) setState(() => _guestMessagesUsed = count);
  }

  // ── Firestore chat loading (signed-in users only) ─────────────────────────

  Future<void> _loadLastChatOrCreate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final chats = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (chats.docs.isEmpty) {
      _startNewChat();
      return;
    }

    final lastChat = chats.docs.first;
    final msgs = await lastChat.reference.collection('messages').limit(1).get();

    if (msgs.docs.isEmpty) {
      _startNewChat();
    } else {
      _loadChatFromFirestore(lastChat.id);
    }
  }

  Future<void> _loadChatFromFirestore(String chatId) async {
    final uid = getUid();
    if (uid == null) return;

    _currentChatId = chatId;

    final msgs = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    setState(() {
      _messages.clear();
      _seedFirstMessage();

      for (final m in msgs.docs) {
        _messages.add(
          _Msg(
            role: m['role'] == 'user' ? Role.user : Role.bot,
            text: m['text'],
            ts: (m['timestamp'] as Timestamp).toDate(),
          ),
        );
      }
    });

    _jumpToBottomSoon();
  }

  Future<void> _loadChatsFromFirestore() async {
    final uid = getUid();
    if (uid == null) return;
    _chatHistory.clear();

    final chats = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('createdAt', descending: true)
        .get();

    for (var chat in chats.docs) {
      final msgs = await chat.reference
          .collection('messages')
          .orderBy('timestamp')
          .get();

      if (msgs.docs.isEmpty) continue;

      _chatHistory.add(
        _ChatSession(
          id: chat.id,
          title: msgs.docs.isNotEmpty ? msgs.docs.first['text'] : 'New Chat',
          timestamp: DateTime.now(),
          messages: msgs.docs.map((m) {
            return _Msg(
              role: m['role'] == 'user' ? Role.user : Role.bot,
              text: m['text'],
              ts: (m['timestamp'] as Timestamp).toDate(),
            );
          }).toList(),
        ),
      );
    }

    setState(() {});
  }

  // ── Chat management ────────────────────────────────────────────────────────

  void _startNewChat() {
    setState(() {
      _currentChatId = '';
      _messages.clear();
      _seedFirstMessage();
    });
  }

  Future<void> _createChatIfNeeded(String firstMessageText) async {
    final uid = getUid();
    if (uid == null) return;
    if (_currentChatId.isNotEmpty) return;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .add({
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': firstMessageText,
    });

    _currentChatId = doc.id;
  }

  void _saveCurrentChat() {
    if (_messages.length <= 1) return;

    final session = _ChatSession(
      id: _currentChatId,
      title: _getChatTitle(),
      timestamp: DateTime.now(),
      messages: List.from(_messages),
    );

    setState(() {
      _chatHistory.removeWhere((chat) => chat.id == _currentChatId);
      _chatHistory.insert(0, session);
    });
  }

  String _getChatTitle() {
    final firstUserMsg = _messages.firstWhere(
          (msg) => msg.role == Role.user,
      orElse: () => _Msg(role: Role.bot, text: 'New Chat', ts: DateTime.now()),
    );

    String title = firstUserMsg.text;
    if (title.length > 30) title = '${title.substring(0, 30)}...';
    return title;
  }

  void _loadChat(_ChatSession session) {
    if (_messages.length > 1) _saveCurrentChat();

    setState(() {
      _currentChatId = session.id;
      _messages.clear();
      _messages.addAll(session.messages);
    });

    Navigator.pop(context);
    _jumpToBottomSoon();
  }

  void _deleteChat(_ChatSession session) {
    setState(() => _chatHistory.remove(session));
  }

  void _seedFirstMessage() {
    _messages.add(
      _Msg(
        role: Role.bot,
        text: "Hi! I'm your assistant.\nAsk me anything to get started. 🙂",
        ts: DateTime.now(),
        isWelcome: true,
      ),
    );
  }

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> _sendCurrentText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _botTyping) return;

    // 1. Check guest daily limit
    if (_isGuest) {
      final canSend = await _canGuestSendMessage();
      if (!canSend) {
        _showLimitReachedDialog();
        return;
      }
    }

    // Trial / subscription check (signed-in users)
    if (!_isGuest) {
      final allowed = await AccessService.hasAccess();
      if (!allowed) {
        if (mounted) context.push('/guru-dakshina');
        return;
      }
    }

    final isFirstMessage = _messages.length == 1;
    final userMsg = _Msg(role: Role.user, text: text, ts: DateTime.now());

    setState(() {
      _messages.add(userMsg);
      _controller.clear();
      _botTyping = true;
    });

    _jumpToBottomSoon();

    try {
      // 2. Guests: no Firestore writes
      if (!_isGuest) {
        if (isFirstMessage) await _createChatIfNeeded(text);
        await _saveMessageToFirestore(userMsg);
      }

      final reply = await _callDify(text);
      final botMsg = _Msg(role: Role.bot, text: reply, ts: DateTime.now());

      setState(() => _messages.add(botMsg));

      // 3. Increment guest counter OR persist to Firestore
      if (_isGuest) {
        await _incrementGuestCount();
      } else {
        await _saveMessageToFirestore(botMsg);
        await _loadChatsFromFirestore();
      }
    } catch (e) {
      setState(() {
        _messages.add(_Msg(
          role: Role.bot,
          text: "Sorry, I couldn't get a reply right now.",
          ts: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _botTyping = false);
      _jumpToBottomSoon();
    }
  }

  void _jumpToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    if (_messages.length > 1 && !_isGuest) {
      _saveCurrentChat();
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _confirmDelete(
      BuildContext context, _ChatSession chat, bool isCurrentChat) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Delete conversation? This action cannot be undone.',
            softWrap: true,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _deleteChat(chat);
                        Navigator.pop(context);
                        if (isCurrentChat) _startNewChat();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        textStyle:
                        const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Chat history popup (signed-in users only) ──────────────────────────────

  void _showChatHistoryPopup() {
    final theme = Theme.of(context);
    final brand = Theme.of(context).extension<BrandExtension>()!;
    final chatHistoryColor = Theme.of(context).colorScheme.primary;
    final onBg = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                    Expanded(
                      child: Text(
                        'Chat History',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: chatHistoryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.pop(context);
                        _startNewChat();
                      },
                      tooltip: 'New Chat',
                    ),
                  ],
                ),
              ),
              // Chat list
              Expanded(
                child: _chatHistory.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_outlined,
                        size: 64,
                        color: onBg.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chat history yet',
                        style: TextStyle(
                          color: onBg.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _chatHistory.length,
                  itemBuilder: (context, index) {
                    final chat = _chatHistory[index];
                    final isCurrentChat = chat.id == _currentChatId;

                    return Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.grey.shade400, width: 2),
                        ),
                        child: ListTile(
                          selected: isCurrentChat,
                          selectedTileColor: isCurrentChat
                              ? brand.accentButton.withOpacity(0.1)
                              : Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrentChat
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 17,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            _formatChatTime(
                                chat.timestamp, isCurrentChat),
                            style: TextStyle(
                              fontSize: 12,
                              color: isCurrentChat
                                  ? brand.accentButton
                                  : theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                              fontWeight: isCurrentChat
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () => _confirmDelete(
                                context, chat, isCurrentChat),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadChatFromFirestore(chat.id);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = Theme.of(context).extension<BrandExtension>()!;
    final bg = theme.colorScheme.surface;
    final onBg = theme.colorScheme.onSurface;

    return AppLayout(
      title: "Guru Chat",
      backgroundImage: 'assets/guruchatbg.png',
      backgroundOpacity: 0.40,
      drawer: const AppDrawer(),
      actions: [
        // History button only for signed-in users
        if (!_isGuest)
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showChatHistoryPopup,
            tooltip: 'Chat History',
          ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _startNewChat,
          tooltip: 'New Chat',
        ),
      ],
      body: SafeArea(
        child: Column(
          children: [
            // ── Guest limit banner ───────────────────────────────────────────
            if (_isGuest) _GuestLimitBanner(
              usedToday: _guestMessagesUsed,
              onSignUp: () {
                context.go('/login');
              },
            ),

            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
                itemCount: _messages.length + (_botTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  return ListenableBuilder(
                    listenable: context
                        .findAncestorWidgetOfExactType<MyApp>()!
                        .appState,
                    builder: (context, _) {
                      final preferredName = context
                          .findAncestorWidgetOfExactType<MyApp>()!
                          .appState
                          .preferredName ??
                          'Sishya';

                      if (index >= _messages.length) {
                        return const _TypingBubble();
                      }

                      final msg = _messages[index];
                      final isUser = msg.role == Role.user;

                      if (msg.isWelcome) {
                        return _WelcomeMessage(
                            greeting: 'I am here. What would you like to share?');
                      }

                      return _MessageBubble(
                        text: msg.text,
                        isUser: isUser,
                        time: _fmtTime(msg.ts),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Composer ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendCurrentText(),
                      decoration: InputDecoration(
                        hintText: "Type a message…",
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                          BorderSide(color: onBg.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color:
                              theme.colorScheme.primary.withOpacity(0.4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendCurrentText,
                    icon: CircleAvatar(
                      backgroundColor: AppColors.accent,
                      radius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.asset(
                          'assets/om.png',
                          width: 25,
                          height: 25,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // SafeArea
    );
  }

}

// ─── Guest limit banner ────────────────────────────────────────────────────────

/// A slim banner shown above the chat for guest users indicating the daily cap.
/// [usedToday] is owned and updated by the parent [_ChatbotPageState] so the
/// counter decreases immediately after each message is sent.
class _GuestLimitBanner extends StatelessWidget {
  final int usedToday;
  final VoidCallback onSignUp;

  const _GuestLimitBanner({
    required this.usedToday,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (_kGuestDailyLimit - usedToday).clamp(0, _kGuestDailyLimit);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$remaining of $_kGuestDailyLimit messages remaining today',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onSignUp,
              style: TextButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Sign Up',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ───────────────────────────────────────────────────────────────

enum Role { user, bot }

class _Msg {
  final Role role;
  final String text;
  final DateTime ts;
  final bool isWelcome;

  _Msg({
    required this.role,
    required this.text,
    required this.ts,
    this.isWelcome = false,
  });
}

class _ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;
  final List<_Msg> messages;

  _ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
  });
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.time,
  });

  final String text;
  final bool isUser;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor = isUser
        ? const Color(0xFFFFB300)
        : Theme.of(context).colorScheme.primary;

    final textColor = isUser
        ? const Color(0xFF000000)
        : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.transparent,
                      child: Image.asset(
                        'assets/Guru-Chat.png',
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isUser ? 16 : 4),
                        topRight: Radius.circular(isUser ? 4 : 16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: textColor,
                        height: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.thumb_up_outlined,
                          size: 18, color: AppColors.secondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thanks for your feedback!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.thumb_down_outlined,
                          size: 18, color: AppColors.secondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thanks for your feedback!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.content_copy_outlined,
                          size: 18, color: AppColors.secondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copy action triggered!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )


          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
              child: FadeTransition(
                opacity: Tween(begin: 0.2, end: 1.0).animate(
                    CurvedAnimation(
                        parent: _c,
                        curve: Interval(i * 0.2, 0.6 + i * 0.2))),
                child: const _Dot(),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration:
        BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
      ),
    );
  }
}

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Image.asset('assets/Guru-Chat.png', width: 160, height: 160),
          const SizedBox(height: 16),
          Text(greeting,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────────

String _fmtTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return "$h:$m $ampm";
}

String _formatChatTime(DateTime t, bool isActive) {
  if (isActive) return 'Today • Active';
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}

Future<String> _callDify(String userText) async {
  final url = Uri.parse('https://dify.myshankara.ai/v1/chat-messages');
  final resp = await http.post(
    url,
    headers: const {
      'Authorization': 'Bearer app-R5F8MFLhSOex8tKyE0C3MFwt',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "inputs": {},
      "query": userText,
      "response_mode": "blocking",
      "conversation_id": "",
      "user": "abc-123",
      "files": [],
    }),
  );

  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    final data = jsonDecode(resp.body);
    final answer = data['answer'] ?? data['data'] ?? data['message'] ?? resp.body;
    return answer.toString();
  } else {
    throw Exception('Dify error ${resp.statusCode}: ${resp.body}');
  }
}