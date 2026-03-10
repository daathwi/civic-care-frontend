import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';

/// Per-grievance staff chat screen — real-time WebSocket messaging via InternalMessage.
class ChatScreen extends ConsumerStatefulWidget {
  final String grievanceId;
  final String grievanceTitle;

  const ChatScreen({
    super.key,
    required this.grievanceId,
    required this.grievanceTitle,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  WebSocketChannel? _channel;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    try {
      final repo = ref.read(messageRepositoryProvider);
      // Fetch the conversation ID assigned to this specific grievance
      final convId = await repo.getGrievanceConversation(
        token: token,
        grievanceId: widget.grievanceId,
      );

      // Connect WebSocket
      final baseWsUrl = apiBaseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      final wsUrl = Uri.parse('$baseWsUrl$apiPrefix/ws/conversations/$convId/messages');
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      // Fetch missing history
      await ref.read(taskChatProvider(widget.grievanceId).notifier).loadMessages();
      
      // Auth
      _channel!.sink.add(jsonEncode({"type": "auth", "token": token}));

      _channel!.stream.listen((message) {
        try {
            final decoded = jsonDecode(message);
            if (decoded['type'] == 'new_message') {
                final msgData = decoded['message'] as Map<String, dynamic>;
                final newMsg = InternalMessage.fromMap(msgData);
                
                // We add it to the ChatNotifier's list of messages to update the UI
                ref.read(taskChatProvider(widget.grievanceId).notifier).replaceOrAddMessageLocally(newMsg);
                _scrollToBottom();
            }
        } catch (_) {}
      });

      setState(() {
        _isInit = true;
      });

      // Post-frame scroll down
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _scrollToBottom(animated: false);
      });
    } catch (_) {}
  }

  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final currentUser = ref.read(authProvider).user;
    if (currentUser != null) {
      // Optimsitic UI Update
      final optimisticMsg = InternalMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        senderId: currentUser.id,
        senderName: currentUser.name,
        receiverId: '', 
        content: text,
        isRead: true,
        createdAt: DateTime.now(),
      );
      ref.read(taskChatProvider(widget.grievanceId).notifier).addMessageLocally(optimisticMsg);
      _scrollToBottom();
    }

    HapticFeedback.lightImpact();
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        "type": "message",
        "content": text,
      }));
    }
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final chatState = ref.watch(taskChatProvider(widget.grievanceId));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              elevation: 0,
              scrolledUnderElevation: 0.5,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              titleSpacing: 0,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Staff Chat',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Grievance context banner
          Container(
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 64,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.grievanceTitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: (chatState.isLoading && chatState.messages.isEmpty) || !_isInit
                ? const Center(child: CircularProgressIndicator.adaptive())
                : chatState.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
                          final isMe = msg.senderId == currentUser?.id;

                          final isFirstInGroup = index == 0 ||
                              chatState.messages[index - 1].senderId != msg.senderId ||
                              msg.createdAt.difference(chatState.messages[index - 1].createdAt).inMinutes > 5;

                          final isLastInGroup = index == chatState.messages.length - 1 ||
                                  chatState.messages[index + 1].senderId != msg.senderId ||
                                  chatState.messages[index + 1].createdAt.difference(msg.createdAt).inMinutes > 5;

                          final showTime = isFirstInGroup &&
                              (index == 0 || msg.createdAt.difference(chatState.messages[index - 1].createdAt).inMinutes > 15);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showTime)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      msg.timeFormatted,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ),
                              if (isFirstInGroup && !isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      msg.senderName ?? 'Staff',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ),
                              _ChatBubble(
                                message: msg,
                                isMe: isMe,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                              ),
                              if (isLastInGroup)
                                const SizedBox(height: 10)
                              else
                                const SizedBox(height: 2),
                            ],
                          );
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 48,
              color: AppTheme.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start the private conversation between staffs',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: GoogleFonts.inter(fontSize: 16),
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, child) {
                  final isTyping = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isTyping ? AppTheme.primary : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final InternalMessage message;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppTheme.primary : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;

    final radius = isMe
        ? BorderRadius.only(
            topLeft: const Radius.circular(18),
            bottomLeft: const Radius.circular(18),
            topRight: Radius.circular(isFirstInGroup ? 18 : 6),
            bottomRight: Radius.circular(isLastInGroup ? 18 : 6),
          )
        : BorderRadius.only(
            topRight: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
            topLeft: Radius.circular(isFirstInGroup ? 18 : 6),
            bottomLeft: Radius.circular(isLastInGroup ? 18 : 6),
          );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
          boxShadow: isMe
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          message.content,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
