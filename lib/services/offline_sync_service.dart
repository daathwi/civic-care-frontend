import 'dart:io';

import '../repository/attendance_repository.dart';
import '../repository/grievance_repository.dart';
import '../repository/message_repository.dart';
import 'offline_storage.dart';

/// Runs when connectivity returns. Processes pending sync queue.
class OfflineSyncService {
  OfflineSyncService({
    required OfflineStorage storage,
    required String? accessToken,
    required String? workerId,
    required GrievanceRepository grievanceRepo,
    required AttendanceRepository attendanceRepo,
    required MessageRepository messageRepo,
  })  : _storage = storage,
        _token = accessToken,
        _workerId = workerId,
        _grievanceRepo = grievanceRepo,
        _attendanceRepo = attendanceRepo,
        _messageRepo = messageRepo;

  final OfflineStorage _storage;
  final String? _token;
  final String? _workerId;
  final GrievanceRepository _grievanceRepo;
  final AttendanceRepository _attendanceRepo;
  final MessageRepository _messageRepo;

  Future<void> sync() async {
    if (_token == null || _token.isEmpty) return;

    try {
      final queue = await _storage.getSyncQueue();
      final localClockIn = await _storage.getLocalClockIn();

      if (localClockIn != null && _workerId != null) {
        try {
          await _attendanceRepo.clockIn(
            accessToken: _token,
            lat: (localClockIn['lat'] as num?)?.toDouble() ?? 0,
            lng: (localClockIn['lng'] as num?)?.toDouble() ?? 0,
          );
          await _storage.clearLocalClockIn();
        } catch (_) {}
      }

      final remaining = <Map<String, dynamic>>[];
      for (final item in queue) {
        final type = item['type'] as String?;
        try {
          if (type == 'clock_out') {
            await _attendanceRepo.clockOut(
              accessToken: _token,
              lat: (item['lat'] as num?)?.toDouble() ?? 0,
              lng: (item['lng'] as num?)?.toDouble() ?? 0,
            );
          } else if (type == 'update_status') {
            final complaintId = item['complaint_id'] as String?;
            final status = item['status'] as String?;
            final note = item['note'] as String? ?? 'Resolved offline';
            String? resolutionUrl;
            final path = item['resolution_image_path'] as String?;
            if (path != null && path.isNotEmpty) {
              final file = File(path);
              if (await file.exists()) {
                resolutionUrl = await _grievanceRepo.uploadResolutionPhoto(
                  accessToken: _token,
                  file: file,
                );
              }
            }
            await _grievanceRepo.update(
              complaintId!,
              accessToken: _token,
              status: status,
              note: note,
              resolutionImageUrl: resolutionUrl,
            );
          } else if (type == 'add_comment') {
            final complaintId = item['complaint_id'] as String?;
            final text = item['text'] as String? ?? '';
            if (complaintId != null && text.isNotEmpty) {
              await _grievanceRepo.addComment(
                complaintId,
                accessToken: _token,
                text: text,
              );
            }
          } else if (type == 'send_staff_message') {
            final grievanceId = item['grievance_id'] as String?;
            final content = item['content'] as String? ?? '';
            if (grievanceId != null && content.isNotEmpty) {
              final convId = await _messageRepo.getGrievanceConversation(
                token: _token,
                grievanceId: grievanceId,
              );
              await _messageRepo.sendConversationMessage(
                token: _token,
                conversationId: convId,
                content: content,
              );
            }
          } else {
            remaining.add(item);
          }
        } catch (_) {
          remaining.add(item);
        }
      }
      await _storage.setSyncQueue(remaining);
    } catch (_) {}
  }
}
