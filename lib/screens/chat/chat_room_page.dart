import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/chat_notifier.dart';
import '../../services/notification_service.dart';
import '../../services/directory_service.dart';
import '../../services/voice_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/character_dialog.dart';

/// Ruang percakapan 1-lawan-1. Realtime lewat [ChatService.messagesStream].
///
/// Fitur: balas/quote, reaksi emoji, edit & hapus pesan, indikator mengetik,
/// tanda dibaca, pencarian dalam percakapan, pesan disematkan, presence.
class ChatRoomPage extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String recipientRole;

  const ChatRoomPage({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _textC = TextEditingController();
  final _scrollC = ScrollController();
  final _searchC = TextEditingController();

  bool _sending = false;
  bool _searching = false;
  String _searchQuery = '';

  ReplyPreview? _replyTo;
  ChatMessage? _editing;

  bool _isRecording = false;

  late final String _cid;

  // Stream di-cache sekali (bukan dibuat ulang tiap build). Tanpa ini, saat
  // keyboard muncul build() jalan lagi → stream baru → StreamBuilder reset ke
  // ConnectionState.waiting → daftar pesan berkedip/"refresh". Stream yang
  // dipakai >1 StreamBuilder dijadikan broadcast; onCancel menutup listener
  // Firestore saat halaman ditutup (mencegah kebocoran).
  late final Stream<List<ChatMessage>> _messagesStream;
  late final Stream<bool> _typingStream;
  late final Stream<StaffContact?> _contactStream;
  late final Stream<Conversation?> _convoStream;

  String? _meId;
  Timer? _typingTimer;
  bool _typingSent = false;

  /// Waktu "bersihkan pesan" milik pengguna ini. Pesan sebelum waktu ini
  /// disembunyikan dari daftar (clear per-pengguna). null = belum dibersihkan.
  DateTime? _clearedAt;
  StreamSubscription<Conversation?>? _convoSub;

  static const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  void initState() {
    super.initState();
    // conversationId butuh kedua uid; me.id diisi saat build pertama.
    _textC.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textC.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _convoSub?.cancel();
    _stopTyping();
    // Percakapan tak lagi aktif — notifikasi berikutnya boleh muncul.
    ChatNotifier.instance.setActiveConversation(null);
    _textC.dispose();
    _scrollC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  void _ensureInit(String meId) {
    if (_meId != null) return;
    _meId = meId;
    _cid = ChatService.conversationId(meId, widget.recipientId);

    // Buat stream SEKALI di sini, bukan di build(). Yang dipakai lebih dari satu
    // StreamBuilder (typing, contact, conversation) dijadikan broadcast.
    _messagesStream = ChatService.messagesStream(_cid);
    _typingStream = ChatService.typingStream(
      conversationId: _cid,
      otherUid: widget.recipientId,
    ).asBroadcastStream(onCancel: (s) => s.cancel());
    _contactStream = DirectoryService.contactStream(widget.recipientId)
        .asBroadcastStream(onCancel: (s) => s.cancel());
    _convoStream = ChatService.conversationStream(_cid)
        .asBroadcastStream(onCancel: (s) => s.cancel());

    // Pantau waktu "bersihkan" milik kita agar filter pesan ikut ter-update.
    _convoSub = _convoStream.listen((c) {
      final cleared = c?.clearedFor(meId);
      if (cleared != _clearedAt && mounted) {
        setState(() => _clearedAt = cleared);
      }
    });

    // Tandai dibaca begitu masuk ruang.
    ChatService.markRead(conversationId: _cid, uid: meId);

    // Beri tahu ChatNotifier bahwa percakapan ini sedang aktif — jangan notif.
    ChatNotifier.instance.setActiveConversation(_cid);
    // Hapus notifikasi lama untuk percakapan ini (badge sudah tidak berlaku).
    NotificationService.instance.clearForConversation(_cid);
  }

  // ── Typing ────────────────────────────────────────────────────────────────
  void _onTextChanged() {
    final me = _meId;
    if (me == null) return;
    if (_textC.text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_typingSent) {
      _typingSent = true;
      ChatService.setTyping(conversationId: _cid, uid: me, typing: true);
    }
    // Reset timer idle → hentikan status setelah 3 dtk tanpa ketik.
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    final me = _meId;
    if (me == null || !_typingSent) return;
    _typingSent = false;
    ChatService.setTyping(conversationId: _cid, uid: me, typing: false);
  }

  // ── Kirim / edit ────────────────────────────────────────────────────────
  Future<void> _send(UserModel me) async {
    final text = _textC.text.trim();
    if (text.isEmpty || _sending) return;

    // Mode edit: perbarui pesan lama alih-alih kirim baru.
    if (_editing != null) {
      final target = _editing!;
      _textC.clear();
      setState(() => _editing = null);
      try {
        await ChatService.editMessage(
          conversationId: _cid,
          messageId: target.id,
          newText: text,
        );
      } catch (e) {
        _showError('Gagal mengedit: $e');
      }
      return;
    }

    setState(() => _sending = true);
    _textC.clear();
    _typingTimer?.cancel();
    _stopTyping();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    try {
      await ChatService.sendMessage(
        sender: me,
        recipientId: widget.recipientId,
        recipientName: widget.recipientName,
        recipientRole: widget.recipientRole,
        text: text,
        replyTo: reply,
      );
      _scrollToBottom();
    } catch (e) {
      _textC.text = text;
      setState(() => _replyTo = reply);
      _showError('Gagal mengirim pesan: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollC.hasClients) {
        _scrollC.animateTo(
          _scrollC.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Aksi pesan (long-press) ───────────────────────────────────────────────
  void _openMessageActions(ChatMessage msg, bool mine) {
    if (msg.deleted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageActionSheet(
        emojis: _reactionEmojis,
        mine: mine,
        onReact: (emoji) {
          Navigator.pop(context);
          _react(msg, emoji);
        },
        onReply: () {
          Navigator.pop(context);
          setState(() {
            _editing = null;
            _replyTo = ReplyPreview(
              messageId: msg.id,
              senderId: msg.senderId,
              text: msg.text,
            );
          });
        },
        onCopy: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: msg.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesan disalin')),
          );
        },
        onPin: () {
          Navigator.pop(context);
          _pin(msg);
        },
        onEdit: mine
            ? () {
                Navigator.pop(context);
                setState(() {
                  _replyTo = null;
                  _editing = msg;
                  _textC.text = msg.text;
                  _textC.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textC.text.length),
                  );
                });
              }
            : null,
        onDelete: mine
            ? () {
                Navigator.pop(context);
                _confirmDelete(msg);
              }
            : null,
      ),
    );
  }

  Future<void> _react(ChatMessage msg, String emoji) async {
    final me = _meId;
    if (me == null) return;
    try {
      await ChatService.toggleReaction(
        conversationId: _cid,
        messageId: msg.id,
        emoji: emoji,
        uid: me,
      );
    } catch (e) {
      _showError('Gagal memberi reaksi: $e');
    }
  }

  Future<void> _pin(ChatMessage msg) async {
    final me = context.read<AuthProvider>().user;
    if (me == null) return;
    final senderName = msg.senderId == me.id ? me.nama : widget.recipientName;
    try {
      await ChatService.pinMessage(
        conversationId: _cid,
        message: msg,
        senderName: senderName,
        pinnedBy: me.id,
      );
    } catch (e) {
      _showError('Gagal menyematkan: $e');
    }
  }

  Future<void> _confirmDelete(ChatMessage msg) async {
    final ok = await AppDialogs.showConfirm(context, message: 'Pesan ini akan dihapus untuk semua orang.', confirmLabel: 'Hapus', danger: true);
    if (ok != true) return;
    try {
      await ChatService.deleteMessage(conversationId: _cid, messageId: msg.id);
    } catch (e) {
      _showError('Gagal menghapus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Sesi tidak valid')));
    }
    _ensureInit(me.id);
    final roleColor = AppColors.roleBadge(widget.recipientRole);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _searching ? _searchAppBar() : _titleAppBar(roleColor),
      body: Column(
        children: [
          _pinnedBanner(),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var messages = snapshot.data ?? [];
                // Sembunyikan pesan yang dibuat sebelum waktu "bersihkan"
                // milik kita (clear per-pengguna) — lawan tetap melihatnya.
                final cleared = _clearedAt;
                if (cleared != null) {
                  messages = messages
                      .where((m) => m.createdAt.isAfter(cleared))
                      .toList();
                }
                // Tandai dibaca tiap ada pesan baru dari lawan.
                if (messages.isNotEmpty &&
                    messages.last.senderId != me.id) {
                  ChatService.markRead(conversationId: _cid, uid: me.id);
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  messages = messages
                      .where((m) =>
                          !m.deleted && m.text.toLowerCase().contains(q))
                      .toList();
                }
                if (messages.isEmpty) {
                  return EmptyState(
                    icon: _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.forum_outlined,
                    message: _searchQuery.isNotEmpty
                        ? 'Tidak ditemukan'
                        : 'Belum ada pesan',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Coba kata kunci lain.'
                        : 'Kirim pesan pertama untuk memulai percakapan.',
                  );
                }
                if (_searchQuery.isEmpty) _scrollToBottom();
                return ListView.builder(
                  controller: _scrollC,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final mine = msg.senderId == me.id;
                    final isLastMine = mine &&
                        i == messages.length - 1 &&
                        _searchQuery.isEmpty;
                    return _bubble(msg, mine, isLastMine, me.id);
                  },
                );
              },
            ),
          ),
          _typingIndicator(),
          if (_replyTo != null) _replyBar(),
          if (_editing != null) _editBar(),
          _composer(me),
        ],
      ),
    );
  }

  // ── App bars ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _titleAppBar(Color roleColor) {
    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          StreamBuilder<StaffContact?>(
            stream: _contactStream,
            builder: (context, snap) {
              final online = snap.data?.isOnlineNow ?? false;
              return Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: roleColor.withAlpha(40),
                    child: Text(
                      _initials(widget.recipientName),
                      style: GoogleFonts.plusJakartaSans(
                        color: roleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (online)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _headerSubtitle(),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Cari pesan',
          onPressed: () => setState(() => _searching = true),
        ),
        PopupMenuButton<String>(
          tooltip: 'Menu',
          onSelected: (v) {
            if (v == 'clear') _confirmClearMessages();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_outlined,
                      size: 20, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Text(
                    'Bersihkan pesan chat',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Konfirmasi lalu bersihkan pesan chat HANYA untuk pengguna ini.
  Future<void> _confirmClearMessages() async {
    final me = _meId;
    if (me == null) return;
    final ok = await AppDialogs.showConfirm(context, message: 'Semua pesan akan dihapus dari tampilan Anda. Lawan bicara tetap dapat melihat percakapan ini. Tindakan ini tidak dapat dibatalkan.', confirmLabel: 'Bersihkan', danger: true);
    if (ok != true) return;
    try {
      await ChatService.clearMessagesForUser(conversationId: _cid, uid: me);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan chat dibersihkan')),
        );
      }
    } catch (e) {
      _showError('Gagal membersihkan: $e');
    }
  }

  /// Subjudul header: "sedang mengetik…" > online > terakhir dilihat > role.
  Widget _headerSubtitle() {
    return StreamBuilder<bool>(
      stream: _typingStream,
      builder: (context, typingSnap) {
        if (typingSnap.data == true) {
          return Text(
            'sedang mengetik…',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        return StreamBuilder<StaffContact?>(
          stream: _contactStream,
          builder: (context, snap) {
            final c = snap.data;
            String label;
            Color color = AppColors.textSecondary;
            if (c?.isOnlineNow ?? false) {
              label = 'Online';
              color = AppColors.success;
            } else if (c?.lastSeen != null) {
              label = 'Terakhir dilihat ${_lastSeenLabel(c!.lastSeen!)}';
            } else {
              label = _roleDisplay(widget.recipientRole);
            }
            return Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: color),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _searchAppBar() {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() {
          _searching = false;
          _searchQuery = '';
          _searchC.clear();
        }),
      ),
      title: TextField(
        controller: _searchC,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.plusJakartaSans(fontSize: 15),
        decoration: const InputDecoration(
          hintText: 'Cari dalam percakapan…',
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _searchQuery = '';
              _searchC.clear();
            }),
          ),
      ],
    );
  }

  // ── Pinned banner ──────────────────────────────────────────────────────────
  Widget _pinnedBanner() {
    return StreamBuilder<Conversation?>(
      stream: _convoStream,
      builder: (context, snap) {
        final pinned = snap.data?.pinned;
        if (pinned == null) return const SizedBox.shrink();
        return Material(
          color: AppColors.primaryLight,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disematkan • ${pinned.senderName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          pinned.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Lepas sematan',
                    onPressed: () => ChatService.unpin(_cid),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Typing indicator (bawah daftar) ────────────────────────────────────────
  Widget _typingIndicator() {
    return StreamBuilder<bool>(
      stream: _typingStream,
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TypingDots(),
              const SizedBox(width: 8),
              Text(
                '${widget.recipientName.split(' ').first} sedang mengetik…',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Bubble ─────────────────────────────────────────────────────────────────
  Widget _bubble(ChatMessage msg, bool mine, bool isLastMine, String meId) {
    final bubbleColor = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _openMessageActions(msg, mine),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (msg.replyTo != null) _replyQuote(msg.replyTo!, mine),
                    if (msg.deleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block,
                              size: 14,
                              color: textColor.withAlpha(150)),
                          const SizedBox(width: 5),
                          Text(
                            'Pesan ini dihapus',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontStyle: FontStyle.italic,
                              color: textColor.withAlpha(170),
                            ),
                          ),
                        ],
                      )
                    else if (msg.isVoice)
                      _voiceBubble(msg, mine, textColor)
                    else
                      Text(
                        msg.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          height: 1.3,
                          color: textColor,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.isEdited && !msg.deleted) ...[
                          Text(
                            'diedit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: mine ? Colors.white70 : AppColors.textHint,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          DateFormat('HH:mm').format(msg.createdAt),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: mine ? Colors.white70 : AppColors.textHint,
                          ),
                        ),
                        if (isLastMine) ...[
                          const SizedBox(width: 4),
                          _readReceipt(meId),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (msg.reactions.isNotEmpty) _reactionChips(msg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _voiceBubble(ChatMessage msg, bool mine, Color textColor) {
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mine ? Icons.play_circle_filled : Icons.play_circle_filled,
              color: textColor, size: 28,
            ),
            const SizedBox(width: 8),
            Container(
              width: 80, height: 4,
              decoration: BoxDecoration(
                color: textColor.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              msg.voiceDuration != null ? '${msg.voiceDuration! ~/ 60}:${(msg.voiceDuration! % 60).toString().padLeft(2, '0')}' : '0:05',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: textColor.withAlpha(180),
              ),
            ),
          ],
        ),
        if (msg.text != '[Pesan Suara]' && msg.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(msg.text, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textColor.withAlpha(200))),
        ],
      ],
    );
  }

  Widget _replyQuote(ReplyPreview reply, bool mine) {
    final onDark = mine;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withAlpha(38) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: onDark ? Colors.white : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        reply.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          height: 1.25,
          color: onDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _reactionChips(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: msg.reactions.entries.map((e) {
          final reacted = _meId != null && e.value.contains(_meId);
          return GestureDetector(
            onTap: () => _react(msg, e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: reacted ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: reacted ? AppColors.primary : AppColors.border,
                  width: reacted ? 1.2 : 0.8,
                ),
              ),
              child: Text(
                '${e.key} ${e.value.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Centang status baca pada pesan terakhir milik saya.
  Widget _readReceipt(String meId) {
    return StreamBuilder<Conversation?>(
      stream: _convoStream,
      builder: (context, snap) {
        final read = snap.data?.readByOther(meId) ?? false;
        return Icon(
          read ? Icons.done_all : Icons.done,
          size: 14,
          color: read ? const Color(0xFF7FD4FF) : Colors.white70,
        );
      },
    );
  }

  // ── Reply / edit bars di atas composer ──────────────────────────────────────
  Widget _replyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(width: 3, height: 34, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membalas',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  _replyTo!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _editBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.edit, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mengedit pesan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  _editing!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() {
              _editing = null;
              _textC.clear();
            }),
          ),
        ],
      ),
    );
  }

  // ── Composer ────────────────────────────────────────────────────────────────
  Widget _composer(UserModel me) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 6,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _voiceButton(me),
            const SizedBox(width: 6),
            Expanded(
              child: _isRecording
                  ? _recordingIndicator()
                  : TextField(
                      controller: _textC,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14.5),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            if (!_isRecording)
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : () => _send(me),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_editing != null ? Icons.check : Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _voiceButton(UserModel me) {
    return GestureDetector(
      onLongPressStart: (_) async {
        if (_editing != null) return;
        final perm = await VoiceService.instance.requestPermission();
        if (!perm) return;
        final path = await VoiceService.instance.startRecording();
        if (path != null && mounted) {
          setState(() => _isRecording = true);
        }
      },
      onLongPressEnd: (_) async {
        if (!_isRecording) return;
        final path = await VoiceService.instance.stopRecording();
        if (path == null || !mounted) {
          setState(() => _isRecording = false);
          return;
        }
        setState(() => _isRecording = false);
        _sendVoice(me, path);
      },
      onLongPressCancel: () async {
        if (!_isRecording) return;
        await VoiceService.instance.cancelRecording();
        if (mounted) setState(() => _isRecording = false);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isRecording ? AppColors.danger.withAlpha(30) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isRecording ? Icons.mic : Icons.mic_none,
          color: _isRecording ? AppColors.danger : AppColors.textHint,
          size: 22,
        ),
      ),
    );
  }

  Widget _recordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 14),
          const SizedBox(width: 8),
          Text(
            'Rekam suara...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: AppColors.danger, fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
            GestureDetector(
            onTap: () async {
              await VoiceService.instance.cancelRecording();
              if (mounted) setState(() => _isRecording = false);
            },
            child: Icon(Icons.close, size: 18, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVoice(UserModel me, String path) async {
    try {
      final bytes = await VoiceService.instance.readBytes(path);
      if (bytes == null) return;

      setState(() => _sending = true);

      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final downloadUrl = await CloudinaryService.uploadBytes(bytes, fileName);

      await ChatService.sendMessage(
        sender: me,
        recipientId: widget.recipientId,
        recipientName: widget.recipientName,
        recipientRole: widget.recipientRole,
        text: '[Pesan Suara]',
        voiceUrl: downloadUrl,
        voiceDuration: null,
      );

      _scrollToBottom();
    } catch (e) {
      _showError('Gagal mengirim pesan suara: $e');
    } finally {
      await VoiceService.instance.deleteFile(path);
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _lastSeenLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    final sameDay = DateTime.now().day == dt.day;
    if (!sameDay && diff.inDays == 0) return 'kemarin ${DateFormat('HH:mm').format(dt)}';
    if (diff.inDays == 1) return 'kemarin';
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  String _roleDisplay(String role) {
    switch (role) {
      case 'administrator':
      case 'superadmin':
      case 'admin':
        return 'Administrator';
      case 'organization_admin':
      case 'admin_organisasi':
      case 'organisasi':
        return 'Admin Organisasi';
      case 'admin_eskul':
      case 'eskul':
        return 'Admin Eskul';
      case 'pembina_organisasi':
        return 'Pembina Organisasi';
      case 'pembina_eskul':
        return 'Pembina Eskul';
      default:
        return role;
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Bottom sheet aksi pesan: baris emoji reaksi + menu (balas, salin, sematkan,
/// edit, hapus).
class _MessageActionSheet extends StatelessWidget {
  final List<String> emojis;
  final bool mine;
  final void Function(String emoji) onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageActionSheet({
    required this.emojis,
    required this.mine,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onPin,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Baris reaksi cepat.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: emojis
                    .map((e) => GestureDetector(
                          onTap: () => onReact(e),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(e,
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            _action(Icons.reply, 'Balas', onReply),
            _action(Icons.push_pin_outlined, 'Sematkan', onPin),
            _action(Icons.copy_outlined, 'Salin', onCopy),
            if (onEdit != null) _action(Icons.edit_outlined, 'Edit', onEdit!),
            if (onDelete != null)
              _action(Icons.delete_outline, 'Hapus', onDelete!,
                  danger: true),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Tiga titik animasi untuk indikator "sedang mengetik".
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value - i * 0.2) % 1.0;
            final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 6 * scale,
              height: 6 * scale,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
