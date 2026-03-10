import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../models/message.dart';
import '../repository/message_repository.dart';

final messageRepositoryProvider = Provider((ref) => MessageRepository());

final conversationsProvider = FutureProvider<List<ConversationMember>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return [];

  final repo = ref.read(messageRepositoryProvider);
  return await repo.getConversations(token: auth.accessToken!);
});

final colleaguesProvider = FutureProvider<List<ConversationMember>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return [];

  final repo = ref.read(messageRepositoryProvider);
  return await repo.getColleagues(token: auth.accessToken!);
});

class ChatState {
  final List<InternalMessage> messages;
  final bool isLoading;
  final String? error;

  ChatState({this.messages = const [], this.isLoading = false, this.error});

  ChatState copyWith({
    List<InternalMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends FamilyNotifier<ChatState, String> {
  @override
  ChatState build(String arg) {
    // arg is otherUserId
    _loadMessages();
    return ChatState(isLoading: true);
  }

  Future<void> _loadMessages() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    try {
      final repo = ref.read(messageRepositoryProvider);
      final messages = await repo.getThread(
        token: auth.accessToken!,
        otherUserId: arg,
      );
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> sendMessage(String content) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    try {
      final repo = ref.read(messageRepositoryProvider);
      final newMsg = await repo.sendMessage(
        token: auth.accessToken!,
        receiverId: arg,
        content: content,
      );
      state = state.copyWith(messages: [...state.messages, newMsg]);

      // Refresh conversations list
      ref.invalidate(conversationsProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void addMessageLocally(InternalMessage msg) {
    state = state.copyWith(messages: [...state.messages, msg]);
  }
}

final chatProvider = NotifierProviderFamily<ChatNotifier, ChatState, String>(
  ChatNotifier.new,
);

class TaskChatNotifier extends FamilyNotifier<ChatState, String> {
  @override
  ChatState build(String arg) {
    // arg is grievanceId
    loadMessages();
    return ChatState(isLoading: true);
  }

  Future<void> loadMessages() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    try {
      final repo = ref.read(messageRepositoryProvider);
      // First get/create conversation ID for this grievance
      final convId = await repo.getGrievanceConversation(
        token: auth.accessToken!,
        grievanceId: arg,
      );

      final messages = await repo.getConversationMessages(
        token: auth.accessToken!,
        conversationId: convId,
      );
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void addMessageLocally(InternalMessage msg) {
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void replaceOrAddMessageLocally(InternalMessage msg) {
    final currentMessages = List<InternalMessage>.from(state.messages);
    
    // Check if the last message is a temporary optimistic message with exactly the same content
    // from the same user.
    if (currentMessages.isNotEmpty) {
      final lastMsg = currentMessages.last;
      if (lastMsg.id.startsWith('temp_') && 
          lastMsg.content == msg.content && 
          lastMsg.senderId == msg.senderId) {
        
        // It's a match! Replace the temporary message with the real one from the server.
        currentMessages[currentMessages.length - 1] = msg;
        state = state.copyWith(messages: currentMessages);
        return;
      }
    }
    
    // Otherwise just add it
    state = state.copyWith(messages: [...currentMessages, msg]);
  }
}

final taskChatProvider =
    NotifierProviderFamily<TaskChatNotifier, ChatState, String>(
      TaskChatNotifier.new,
    );
