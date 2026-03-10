import '../core/api_client.dart';
import '../models/message.dart';

class MessageRepository {
  final ApiClient _client = ApiClient();

  Future<InternalMessage> sendMessage({
    required String token,
    required String receiverId,
    required String content,
  }) async {
    final response = await _client
        .withToken(token)
        .post(
          '/internal-messages/send',
          body: {'receiver_id': receiverId, 'content': content},
        );

    if (response.isOk) {
      return InternalMessage.fromMap(response.json);
    } else {
      throw ApiException.fromResponse(response);
    }
  }

  Future<String> getGrievanceConversation({
    required String token,
    required String grievanceId,
  }) async {
    final response = await _client
        .withToken(token)
        .get('/internal-messages/grievance/$grievanceId');

    if (response.isOk) {
      return response.json as String;
    } else {
      throw ApiException.fromResponse(response);
    }
  }

  Future<List<InternalMessage>> getConversationMessages({
    required String token,
    required String conversationId,
  }) async {
    final response = await _client
        .withToken(token)
        .get('/internal-messages/conversations/$conversationId/messages');

    if (response.isOk) {
      final list = response.json as List;
      return list.map((m) => InternalMessage.fromMap(m)).toList();
    } else {
      throw ApiException.fromResponse(response);
    }
  }

  Future<InternalMessage> sendConversationMessage({
    required String token,
    required String conversationId,
    required String content,
  }) async {
    final response = await _client
        .withToken(token)
        .post(
          '/internal-messages/conversations/$conversationId/messages',
          body: {'content': content},
        );

    if (response.isOk) {
      return InternalMessage.fromMap(response.json);
    } else {
      throw ApiException.fromResponse(response);
    }
  }

  Future<List<InternalMessage>> getThread({
    required String token,
    required String otherUserId,
  }) async {
    final response = await _client
        .withToken(token)
        .get('/internal-messages/thread/$otherUserId');

    if (response.isOk) {
      final list = response.json as List;
      return list.map((m) => InternalMessage.fromMap(m)).toList();
    } else {
      throw ApiException.fromResponse(response);
    }
  }

  Future<List<ConversationMember>> getConversations({
    required String token,
  }) async {
    final response = await _client
        .withToken(token)
        .get('/internal-messages/conversations');

    if (response.isOk) {
      final list = response.json as List;
      return list.map((m) => ConversationMember.fromMap(m)).toList();
    } else {
      throw ApiException.fromResponse(response);
    }
  }

  Future<List<ConversationMember>> getColleagues({
    required String token,
  }) async {
    final response = await _client
        .withToken(token)
        .get('/internal-messages/colleagues');

    if (response.isOk) {
      final list = response.json as List;
      return list.map((m) => ConversationMember.fromMap(m)).toList();
    } else {
      throw ApiException.fromResponse(response);
    }
  }
}
