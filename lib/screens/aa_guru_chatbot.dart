import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myshankara/theme/app_theme.dart';
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
import 'dart:async';

// ─── Guest daily-message limit ───────────────────────────────────────────────
const int _kGuestDailyLimit = 5;

// ─── Dify API config ──────────────────────────────────────────────────────────
// Shared by every Dify call in this file.
const String _difyBaseUrl = 'https://dify.myshankara.ai/v1';
const String _difyApiKey = 'app-uYLIu5sp5pouPQihWiJ1ch5Q';

/// The Dify "user" identifier — the same Firebase Auth uid used as the
/// Firestore document id under `users/{uid}`. Every user (including guests,
/// who are signed in anonymously) has one, so this must stay identical
/// between the original chat-messages request and any later feedback /
/// delete request for that same conversation, or Dify responds with a 404.
String _difyEndUserId() => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

class ChatbotPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const ChatbotPage({super.key, this.onOpenDrawer});

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  'You\'ve used all $_kGuestDailyLimit messages for today. Sign up for unlimited access to your spiritual guide.',
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

  Future<void> _saveDifyConversationId() async {
    final uid = getUid();
    if (uid == null || _currentChatId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(_currentChatId)
        .update({'difyConversationId': _difyConversationId});
  }

  /// Returns the created Firestore doc id (needed later to persist feedback
  /// changes back onto this exact message), or null for guests / no chat.
  Future<String?> _saveMessageToFirestore(_Msg msg) async {
    final uid = getUid();
    if (uid == null || _currentChatId.isEmpty) return null;

    final docRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .add({
      'role': msg.role.name,
      'text': msg.text,
      'timestamp': FieldValue.serverTimestamp(),
      if (msg.messageId != null) 'messageId': msg.messageId,
      'feedback': msg.feedback.name,
    });

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(_currentChatId)
        .update({'lastMessage': msg.text});

    return docRef.id;
  }

  /// Best-effort persistence of a feedback change onto an already-saved
  /// message, so it loads back correctly next time the chat is opened.
  Future<void> _persistFeedback(_Msg msg) async {
    final uid = getUid();
    if (uid == null ||
        _currentChatId.isEmpty ||
        msg.firestoreDocId == null) {
      return;
    }
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .doc(msg.firestoreDocId)
          .update({'feedback': msg.feedback.name});
    } catch (_) {
      // Non-critical: the Dify-side feedback already succeeded. Worst case
      // the local highlight resets next time this chat is reopened.
    }
  }

  // ── Guest message counter (live, in-memory) ───────────────────────────────
  int _guestMessagesUsed = 0;

  // ── Chat history (only used for signed-in users) ───────────────────────────
  final List<_ChatSession> _chatHistory = [];
  String _currentChatId = '';

  // ── Dify conversation continuity ────────────────────────────────────────────
  // Sent back on every Dify call so replies stay in the same conversation
  // instead of starting a new one on every turn.
  String _difyConversationId = '';

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

    final chatDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .get();
    _difyConversationId = (chatDoc.data()?['difyConversationId'] ?? '') as String;

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
        final data = m.data();
        _messages.add(
          _Msg(
            role: data['role'] == 'user' ? Role.user : Role.bot,
            text: data['text'],
            ts: (data['timestamp'] as Timestamp).toDate(),
            messageId: data['messageId'] as String?,
            feedback: _thumbFromName(data['feedback'] as String?),
            firestoreDocId: m.id,
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
          difyConversationId:
              (chat.data()['difyConversationId'] ?? '') as String,
          messages: msgs.docs.map((m) {
            final data = m.data();
            return _Msg(
              role: data['role'] == 'user' ? Role.user : Role.bot,
              text: data['text'],
              ts: (data['timestamp'] as Timestamp).toDate(),
              messageId: data['messageId'] as String?,
              feedback: _thumbFromName(data['feedback'] as String?),
              firestoreDocId: m.id,
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
      _difyConversationId = '';
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
      difyConversationId: _difyConversationId,
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

  /// Deletes a chat locally, in Firestore, and its Dify conversation.
  /// The local list is updated immediately for a responsive UI; the Firestore
  /// and Dify deletes happen in the background and only surface a snackbar
  /// on failure (removal already happened locally, so it isn't reverted —
  /// see the class doc comment on `_deleteChatFromFirestore` for why this can
  /// still leave stale server-side state on failure).
  void _deleteChat(_ChatSession session) {
    setState(() => _chatHistory.remove(session));
    unawaited(_deleteChatEverywhere(session));
  }

  Future<void> _deleteChatEverywhere(_ChatSession session) async {
    try {
      await _deleteChatFromFirestore(session.id);
    } catch (_) {
      _showTransientError("Couldn't fully delete this chat. It may reappear.");
    }

    if (session.difyConversationId.isNotEmpty) {
      try {
        await _deleteDifyConversation(session.difyConversationId);
      } catch (_) {
        _showTransientError("Couldn't delete the conversation from the assistant.");
      }
    }
  }

  /// Deletes a chat doc and its messages subcollection (Firestore does not
  /// cascade-delete subcollections on its own).
  Future<void> _deleteChatFromFirestore(String chatId) async {
    final uid = getUid();
    if (uid == null || chatId.isEmpty) return;

    final chatRef =
        _firestore.collection('users').doc(uid).collection('chats').doc(chatId);

    final msgs = await chatRef.collection('messages').get();
    final batch = _firestore.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(chatRef);
    await batch.commit();
  }

  void _showTransientError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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

    // Disable the send button immediately so rapid taps can't queue up
    // multiple requests while the async checks below are in flight.
    setState(() => _botTyping = true);

    // 1. Check guest daily limit
    if (_isGuest) {
      final canSend = await _canGuestSendMessage();
      if (!canSend) {
        setState(() => _botTyping = false);
        _showLimitReachedDialog();
        return;
      }
    }

    // Trial / subscription check (signed-in users)
    if (!_isGuest) {
      final allowed = await AccessService.hasAccess();
      if (!allowed) {
        setState(() => _botTyping = false);
        if (mounted) context.push('/guru-dakshina');
        return;
      }
    }

    final isFirstMessage = _messages.length == 1;
    final userMsg = _Msg(role: Role.user, text: text, ts: DateTime.now());

    setState(() {
      _messages.add(userMsg);
      _controller.clear();
    });

    _jumpToBottomSoon();

    try {
      // 2. Guests: no Firestore writes
      if (!_isGuest) {
        if (isFirstMessage) await _createChatIfNeeded(text);
        await _saveMessageToFirestore(userMsg);
      }

      final reply = await _callDify(text, _difyConversationId);
      final cleanedAnswer =
          reply.answer.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
      final botMsg = _Msg(
        role: Role.bot,
        text: cleanedAnswer,
        ts: DateTime.now(),
        messageId: reply.messageId.isEmpty ? null : reply.messageId,
      );

      if (reply.conversationId.isNotEmpty) {
        _difyConversationId = reply.conversationId;
      }

      setState(() => _messages.add(botMsg));

      // 3. Increment guest counter OR persist to Firestore
      if (_isGuest) {
        await _incrementGuestCount();
      } else {
        botMsg.firestoreDocId = await _saveMessageToFirestore(botMsg);
        await _saveDifyConversationId();
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

  void _onTerms() => context.push('/terms-of-service');
  void _onPrivacy() => context.push('/privacy-policy');

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
      BuildContext context, _ChatSession chat, bool isCurrentChat,
      {VoidCallback? onDeleted}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Delete conversation? This action cannot be undone.',
            softWrap: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteChat(chat);
                onDeleted?.call();
                Navigator.pop(context);
                if (isCurrentChat) _startNewChat();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('Delete'),
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
    final onBg = theme.colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Grabber handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: onBg.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Close',
                        ),
                        Expanded(
                          child: Text(
                            'Chat History',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _startNewChat();
                          },
                          tooltip: 'New Chat',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: AppColors.outline),
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
                        : ListView.separated(
                      itemCount: _chatHistory.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.outline.withOpacity(0.5),
                      ),
                      itemBuilder: (context, index) {
                        final chat = _chatHistory[index];
                        final isCurrentChat = chat.id == _currentChatId;

                        return ListTile(
                          selected: isCurrentChat,
                          selectedTileColor:
                              brand.accentButton.withOpacity(0.1),
                          hoverColor:
                              theme.colorScheme.primary.withOpacity(0.06),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
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
                            icon: Icon(Icons.delete_outline,
                                color: theme.colorScheme.error),
                            onPressed: () => _confirmDelete(
                              context,
                              chat,
                              isCurrentChat,
                              onDeleted: () => setSheetState(() {}),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _loadChatFromFirestore(chat.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
      backgroundImage: 'assets/backgrounds/guruchatbg.png',
      backgroundOpacity: 0.40,
      onMenuPressed: widget.onOpenDrawer,
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
                        key: ValueKey(
                            '${_currentChatId}_${index}_${msg.ts.microsecondsSinceEpoch}'),
                        text: msg.text,
                        isUser: isUser,
                        time: _fmtTime(msg.ts),
                        messageId: msg.messageId,
                        feedback: msg.feedback,
                        onFeedbackChanged: (thumb) {
                          msg.feedback = thumb;
                          _persistFeedback(msg);
                        },
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) =>
                              _botTyping ? null : _sendCurrentText(),
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
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _botTyping ? null : _sendCurrentText,
                        icon: CircleAvatar(
                          backgroundColor: _botTyping
                              ? AppColors.accent.withOpacity(0.4)
                              : AppColors.accent,
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(
                              'assets/icons/om.png',
                              width: 25,
                              height: 25,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ChatDisclaimer(onTerms: _onTerms, onPrivacy: _onPrivacy),
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

// ─── Chat disclaimer ───────────────────────────────────────────────────────────
/// Shown just below the message composer to set expectations about AI
/// accuracy and privacy, with links to the legal pages.
class _ChatDisclaimer extends StatelessWidget {
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const _ChatDisclaimer({
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      fontSize: 11,
    );
    final linkStyle = style?.copyWith(
      color: AppColors.link,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: style,
        children: [
          const TextSpan(
            text: 'AI-generated responses may be inaccurate • Do not share '
                'sensitive information • ',
          ),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = onTerms,
          ),
          const TextSpan(text: ' • '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = onPrivacy,
          ),
        ],
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
  final String? messageId;
  // Mutated in place (not via setState) so the current thumbs up/down
  // selection survives widget rebuilds without needing a parent rebuild.
  _Thumb feedback;
  // Firestore doc id for this message, set once it's been saved, so a later
  // feedback change can be written back onto the same document.
  String? firestoreDocId;

  _Msg({
    required this.role,
    required this.text,
    required this.ts,
    this.isWelcome = false,
    this.messageId,
    this.feedback = _Thumb.none,
    this.firestoreDocId,
  });
}

_Thumb _thumbFromName(String? name) {
  switch (name) {
    case 'up':
      return _Thumb.up;
    case 'down':
      return _Thumb.down;
    default:
      return _Thumb.none;
  }
}

class _ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;
  final List<_Msg> messages;
  final String difyConversationId;

  _ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
    this.difyConversationId = '',
  });
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.time,
    this.messageId,
    this.feedback = _Thumb.none,
    this.onFeedbackChanged,
  });

  final String text;
  final bool isUser;
  final String time;
  final String? messageId;
  final _Thumb feedback;
  final ValueChanged<_Thumb>? onFeedbackChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bubbleColor = isUser
        ? const Color(0xFFFFB300)
        : Theme.of(context).colorScheme.primary;

    final textColor = isUser
        ? const Color(0xFF000000)
        : AppColors.onPrimary;

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
                        'assets/images/Guru-Chat.png',
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
                          color: AppColors.onBackground.withValues(alpha: 0.05),
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
            if (!isUser) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: _MessageActions(
                  text: text,
                  messageId: messageId,
                  initialFeedback: feedback,
                  onFeedbackChanged: onFeedbackChanged ?? (_) {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Thumb { none, up, down }

class _MessageActions extends StatefulWidget {
  const _MessageActions({
    required this.text,
    required this.messageId,
    required this.initialFeedback,
    required this.onFeedbackChanged,
  });

  final String text;
  final String? messageId;
  final _Thumb initialFeedback;
  final ValueChanged<_Thumb> onFeedbackChanged;

  @override
  State<_MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<_MessageActions> {
  late _Thumb _selected = widget.initialFeedback;
  // Which thumb (if any) currently has a feedback request in flight.
  _Thumb? _pending;
  bool _justCopied = false;
  Timer? _copyRevertTimer;

  bool get _canRate => widget.messageId != null && widget.messageId!.isNotEmpty;

  @override
  void dispose() {
    _copyRevertTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap(_Thumb thumb) async {
    // Guard against double-tap spamming and missing message ids.
    if (_pending != null || !_canRate) return;

    // Selecting thumbs-down (not un-voting an existing dislike) asks for an
    // optional explanation first.
    if (thumb == _Thumb.down && _selected != _Thumb.down) {
      final content = await _showFeedbackContentDialog(context);
      if (!mounted || content == null) return; // dialog cancelled
      await _submitFeedback(
        pressedThumb: thumb,
        next: _Thumb.down,
        content: content.isEmpty ? null : content,
      );
      return;
    }

    final next = _selected == thumb ? _Thumb.none : thumb;
    await _submitFeedback(pressedThumb: thumb, next: next);
  }

  Future<void> _submitFeedback({
    required _Thumb pressedThumb,
    required _Thumb next,
    String? content,
  }) async {
    final previous = _selected;
    final rating = switch (next) {
      _Thumb.up => 'like',
      _Thumb.down => 'dislike',
      _Thumb.none => null,
    };

    setState(() {
      _selected = next;
      _pending = pressedThumb;
    });
    widget.onFeedbackChanged(next);

    try {
      await _sendDifyFeedback(
        messageId: widget.messageId!,
        rating: rating,
        content: content,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _selected = previous);
      widget.onFeedbackChanged(previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send feedback. Please try again."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.text));
    _copyRevertTimer?.cancel();
    setState(() => _justCopied = true);
    _copyRevertTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _justCopied = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _thumbIcon(_Thumb thumb, IconData icon) {
    if (_pending == thumb) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.secondary,
        ),
      );
    }
    final isSelected = _selected == thumb;
    final disabled = !_canRate || (_pending != null && _pending != thumb);
    return Icon(
      icon,
      size: 18,
      color: isSelected
          ? AppColors.accent.withOpacity(disabled ? 0.5 : 1)
          : AppColors.secondary.withOpacity(disabled ? 0.4 : 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !_canRate || _pending != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: _thumbIcon(_Thumb.up, Icons.thumb_up_outlined),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: disabled ? null : () => _handleTap(_Thumb.up),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: _thumbIcon(_Thumb.down, Icons.thumb_down_outlined),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: disabled ? null : () => _handleTap(_Thumb.down),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
              _justCopied ? Icons.check : Icons.content_copy_outlined,
              size: 18,
              color: _justCopied ? AppColors.success : AppColors.secondary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: _copyText,
        ),
      ],
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
    return SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withOpacity(0.7),
        ),
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
          Image.asset('assets/images/Guru-Chat.png', width: 160, height: 160),
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

Future<({String answer, String conversationId, String messageId})> _callDify(
    String userText, String conversationId) async {
  final url = Uri.parse('$_difyBaseUrl/chat-messages');
  final resp = await http.post(
    url,
    headers: const {
      'Authorization': 'Bearer $_difyApiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "inputs": {},
      "query": userText,
      "response_mode": "blocking",
      "conversation_id": conversationId,
      "user": _difyEndUserId(),
      "files": [],
    }),
  );

  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    final data = jsonDecode(resp.body);
    final answer = data['answer'] ?? data['data'] ?? data['message'] ?? resp.body;
    return (
      answer: answer.toString(),
      conversationId: (data['conversation_id'] ?? '').toString(),
      messageId: (data['message_id'] ?? '').toString(),
    );
  } else {
    throw Exception('Dify error ${resp.statusCode}: ${resp.body}');
  }
}

/// Deletes a Dify conversation (and its messages) server-side. Called when
/// the user deletes a chat locally, so it doesn't linger in Dify.
Future<void> _deleteDifyConversation(String conversationId) async {
  final url = Uri.parse('$_difyBaseUrl/conversations/$conversationId');
  final resp = await http.delete(
    url,
    headers: const {
      'Authorization': 'Bearer $_difyApiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({"user": _difyEndUserId()}),
  );

  // 404 means it's already gone on Dify's side — treat as success.
  if (resp.statusCode != 404 &&
      !(resp.statusCode >= 200 && resp.statusCode < 300)) {
    throw Exception(
        'Dify delete-conversation error ${resp.statusCode}: ${resp.body}');
  }
}

/// Submits (or clears, when [rating] is null) feedback for one Dify message.
/// `user` must match the value sent on the original chat-messages request
/// for this [messageId], otherwise Dify returns 404.
Future<void> _sendDifyFeedback({
  required String messageId,
  required String? rating,
  String? content,
}) async {
  final url = Uri.parse('$_difyBaseUrl/messages/$messageId/feedbacks');
  final resp = await http.post(
    url,
    headers: const {
      'Authorization': 'Bearer $_difyApiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "rating": rating,
      "user": _difyEndUserId(),
      if (content != null && content.isNotEmpty) "content": content,
    }),
  );

  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw Exception('Dify feedback error ${resp.statusCode}: ${resp.body}');
  }
}

/// "Provide Feedback" dialog shown when a user selects thumbs-down, so the
/// dislike can be submitted with an optional explanation. Returns the typed
/// text on Submit (possibly empty), or null if the user cancelled.
Future<String?> _showFeedbackContentDialog(BuildContext context) {
  final controller = TextEditingController();
  final theme = Theme.of(context);

  return showDialog<String?>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          'Report / Provide Feedback',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please tell us what was wrong or inappropriate about this response',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Feedback Content',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onBackground.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'What could be improved?',
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.4)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Submit'),
          ),
        ],
      );
    },
  );
}