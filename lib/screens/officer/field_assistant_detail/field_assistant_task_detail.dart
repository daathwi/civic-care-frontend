import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/launch_links.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/api_config.dart';
import '../../../models/complaint.dart';
import '../../../providers/complaint_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user_models.dart';
import '../../../repository/grievance_mappers.dart' show eventAccentColor;
import '../../../core/app_theme.dart';
import '../../../widgets/civic_ui.dart' show CivicVoteButton, ProximityWarning;
import '../../../widgets/audio_player_widget.dart';
import '../chat_screen.dart';

part '_widgets.dart';
part '_location.dart';
part '_comments.dart';
part '_updates.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CivicCare Worker Task Detail — Apple Native Premium Redesign v2
// Live WebSocket comments · Worker-differentiated bubbles · Discussion Room
// ═══════════════════════════════════════════════════════════════════════════════

class FieldAssistantTaskDetail extends ConsumerStatefulWidget {
  final Complaint complaint;
  final bool isEmbedded;

  const FieldAssistantTaskDetail({
    super.key,
    required this.complaint,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<FieldAssistantTaskDetail> createState() =>
      _FieldAssistantTaskDetailState();
}

class _FieldAssistantTaskDetailState
    extends ConsumerState<FieldAssistantTaskDetail> {
  final _picker = ImagePicker();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _commentScrollController = ScrollController();
  final MapController _mapController = MapController();

  bool _isUpdating = false;
  XFile? _resolutionPhoto;
  int _selectedTab = 0; // 0 = Updates, 1 = Comments
  /// When true, Start Work / Capture & Resolve require GPS within radius (separate from shift).
  bool _requireLocationAtGrievance = false;

  // Wrapper for setState — needed because extensions can't call setState directly
  // ignore: unused_element
  void _rebuildState(VoidCallback fn) => setState(fn);

  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure complaint is in complaintProvider so offline comments show optimistically
      ref.read(complaintProvider.notifier).ensureComplaintInList(widget.complaint);
      ref
          .read(complaintProvider.notifier)
          .refreshGrievanceDetail(widget.complaint.id);
      _connectWebSocket();
    });
  }

  bool _isDisposed = false;
  
  @override
  void dispose() {
    _isDisposed = true;
    _commentController.dispose();
    _commentScrollController.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  void _connectWebSocket() {
    final uri = Uri.parse(apiBaseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final wsUrl = uri.replace(
      scheme: wsScheme,
      path: '$apiPrefix/chat/ws/grievances/${widget.complaint.id}/comments',
    );
    debugPrint('DEBUG: Connecting to Comments WebSocket: $wsUrl');
    try {
      _wsChannel = WebSocketChannel.connect(wsUrl);

      final token = ref.read(authProvider).accessToken;
      if (token != null) {
        _wsChannel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      }

      _wsChannel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] == 'new_comment') {
              final commentData = msg['comment'] as Map<String, dynamic>;
              final newComment = Comment(
                id: commentData['id'] as String,
                userId: commentData['user_id'] as String,
                userName: commentData['user_name'] as String,
                text: commentData['text'] as String,
                timestamp:
                    DateTime.tryParse(commentData['created_at'] as String) ??
                    DateTime.now(),
              );
              ref
                  .read(complaintProvider.notifier)
                  .addCommentLocal(widget.complaint.id, newComment);
              _scrollToBottom();
            }
          } catch (e) {
            debugPrint('DEBUG: Error parsing WS message: $e');
          }
        },
        onDone: () {
          debugPrint('DEBUG: Comments WebSocket closed (onDone)');
          _wsChannel = null;
          if (!_isDisposed) {
            Future.delayed(const Duration(seconds: 3), () => _connectWebSocket());
          }
        },
        onError: (err) {
          debugPrint('DEBUG: Comments WebSocket error: $err');
          _wsChannel = null;
          if (!_isDisposed) {
            Future.delayed(const Duration(seconds: 5), () => _connectWebSocket());
          }
        },
      );
    } catch (e) {
      debugPrint('DEBUG: Failed to connect to WS: $e');
      if (!_isDisposed) {
        Future.delayed(const Duration(seconds: 10), () => _connectWebSocket());
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_commentScrollController.hasClients) {
        _commentScrollController.animateTo(
          _commentScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  // ── Actions ───────────────────────────────────────────────────────────────

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;
    final text = _commentController.text.trim();
    _commentController.clear();

    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'type': 'comment', 'text': text}));
    } else {
      ref
          .read(complaintProvider.notifier)
          .addComment(widget.complaint.id, text)
          .then((_) => _scrollToBottom());
    }
  }

  Future<void> _callCitizen() async {
    final contact = _latestComplaint.reporterPhone ?? '';
    if (contact.isEmpty) {
      _warn('No contact number available for this citizen.');
      return;
    }
    await launchPhoneDialer(contact);
  }

  Future<void> _startTask() async {
    final c = _latestComplaint;
    final att = ref.read(attendanceProvider);
    if (!att.isClockedIn) {
      _warn('Please clock in first.');
      return;
    }
    if (_requireLocationAtGrievance) {
      final distance = ref
          .read(attendanceProvider.notifier)
          .distanceTo(c.latitude, c.longitude);
      if (distance > 50.0 && distance != double.infinity) {
        if (!mounted) return;
        _showProximityWarning(distance);
        return;
      }
    }
    setState(() => _isUpdating = true);
    final err = await ref
        .read(complaintProvider.notifier)
        .updateStatus(
          c.id,
          ComplaintStatus.ongoing,
          'Field Assistant started work.',
        );
    if (mounted) {
      setState(() => _isUpdating = false);
      if (err != null) _warn(err);
    }
  }

  Future<void> _captureAndResolve() async {
    final c = _latestComplaint;
    if (_requireLocationAtGrievance) {
      final distance = ref
          .read(attendanceProvider.notifier)
          .distanceTo(c.latitude, c.longitude);
      if (distance > 50.0 && distance != double.infinity) {
        if (!mounted) return;
        _showProximityWarning(distance);
        return;
      }
    }
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;

    // ── Confirmation dialog ──────────────────────────────────────────────
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'Submit Resolution',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(photo.path),
                  height: 180,
                  width: MediaQuery.of(ctx).size.width,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Are you sure you want to mark this grievance as resolved? This action will notify the citizen.',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey[500])),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Premium Teal Green
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Submit', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _resolutionPhoto = photo;
      _isUpdating = true;
    });
    final err = await ref
        .read(complaintProvider.notifier)
        .updateStatus(
          widget.complaint.id,
          ComplaintStatus.completed,
          'Resolved at site.',
          resolutionImagePath: photo.path,
        );
    if (mounted) {
      setState(() => _isUpdating = false);
      if (err != null) {
        debugPrint('DEBUG: Resolution capture failed: $err');
        _warn('Submission failed: $err');
      } else {
        debugPrint('DEBUG: Resolution submission successful');
        if (!widget.isEmbedded) {
          Navigator.pop(context);
        } else {
          // If embedded, we rely on the provider refresh which we just fixed
          _warn('Resolution submitted successfully!');
        }
      }
    }
  }

  void _showProximityWarning(double distance) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: ProximityWarning(distanceMeters: distance),
      ),
    );
  }

  Complaint get _latestComplaint => ref
      .read(complaintProvider)
      .complaints
      .firstWhere(
        (c) => c.id == widget.complaint.id,
        orElse: () => widget.complaint,
      );

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allComplaints = ref.watch(complaintListProvider);
    final c = allComplaints.firstWhere(
      (item) => item.id == widget.complaint.id,
      orElse: () => widget.complaint,
    );
    final att = ref.watch(attendanceProvider);
    final distance = ref
        .read(attendanceProvider.notifier)
        .distanceTo(c.latitude, c.longitude);
    final isAtSite = distance <= 50.0;
    // canAct: if location required, must be at site; else only clock-in for Start Work
    final needLocation = _requireLocationAtGrievance;
    final locationOk = !needLocation || isAtSite;
    final canStartWork = att.isClockedIn && locationOk;
    final canCaptureResolve = locationOk;

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: widget.isEmbedded
          ? _buildBody(c, att, isAtSite, canStartWork, canCaptureResolve, distance)
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  backgroundColor: AppTheme.surfaceScaffold.withValues(
                    alpha: 0.8,
                  ),
                  scrolledUnderElevation: 0,
                  pinned: true,
                  elevation: 0,
                  centerTitle: true,
                  title: Text(
                    'Task #${c.id.length > 4 ? c.id.substring(c.id.length - 4) : c.id.padLeft(4, '0')}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.black,
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.black87,
                        size: 22,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
              body: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(complaintProvider.notifier)
                          .refreshGrievanceDetail(c.id),
                      child: _buildBody(c, att, isAtSite, canStartWork, canCaptureResolve, distance),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomActions(
        c,
        canStartWork,
        canCaptureResolve,
        att.isClockedIn,
        isAtSite,
      ),
    );
  }

  Widget _buildBody(
    Complaint c,
    AttendanceState att,
    bool isAtSite,
    bool canStartWork,
    bool canCaptureResolve,
    double distance,
  ) {
    return ListView(
      key: const PageStorageKey('task_detail_scroll'),
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _buildHeaderImage(c),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status & Title Bento Card
              _buildBentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow(c),
                    const SizedBox(height: 12),
                    Text(
                      c.title,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMetadataTags(c),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description Bento Card
              _buildBentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESCRIPTION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.description,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF3A3A3C),
                        height: 1.5,
                      ),
                    ),
                    if (c.audioPath != null) ...[
                      const SizedBox(height: 16),
                      AudioPlayerWidget(url: c.audioPath!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Location Bento Card (with proximity radio)
              _buildBentoCard(
                child: _buildLocationSection(c, att, isAtSite, distance),
              ),
              const SizedBox(height: 24),

              // Activity & Feedback Section
              _buildTabSection(),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedTab == 0
                    ? KeyedSubtree(
                        key: const ValueKey('updates'),
                        child: _buildUpdatesTab(c),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('comments'),
                        child: _buildDiscussionRoom(c),
                      ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Assignment Timer Widget ──────────────────────────────────────────────────

class AssignmentTimerWidget extends ConsumerStatefulWidget {
  final Complaint complaint;

  const AssignmentTimerWidget({super.key, required this.complaint});

  @override
  ConsumerState<AssignmentTimerWidget> createState() =>
      _AssignmentTimerWidgetState();
}

class _AssignmentTimerWidgetState extends ConsumerState<AssignmentTimerWidget> {
  // 30 minutes in seconds
  static const int escalationLimitSec = 30 * 60;
  int _remainingSeconds = 0;
  bool _escalatedLocally = false;
  bool _timerActive = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
  }

  void _calculateRemaining() {
    if (widget.complaint.status == ComplaintStatus.escalated) {
      setState(() {
        _remainingSeconds = 0;
        _escalatedLocally = true;
      });
      return;
    }

    final assignedAt = widget.complaint.assignedAt;
    if (assignedAt == null) return;

    final diffInfo = DateTime.now().difference(assignedAt);
    int remaining = escalationLimitSec - diffInfo.inSeconds;

    if (remaining <= 0) {
      _triggerEscalation();
    } else {
      setState(() {
        _remainingSeconds = remaining;
        _timerActive = true;
      });
      _tick();
    }
  }

  void _tick() {
    if (!mounted || !_timerActive) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _timerActive = false;
        _triggerEscalation();
      } else {
        _tick();
      }
    });
  }

  void _triggerEscalation() {
    if (!mounted) return;
    setState(() {
      _remainingSeconds = 0;
      _escalatedLocally = true;
    });
    // Call Provider to escalate
    ref
        .read(complaintProvider.notifier)
        .updateStatus(
          widget.complaint.id,
          ComplaintStatus.escalated,
          'System: Auto-escalated due to 30-min SLA breach',
        );
  }

  String get _formattedTime {
    if (_remainingSeconds <= 0) return '00:00:00';
    int hours = _remainingSeconds ~/ 3600;
    int minutes = (_remainingSeconds % 3600) ~/ 60;
    int seconds = _remainingSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.complaint.assignedAt == null) return const SizedBox.shrink();

    final isEscalated =
        _escalatedLocally ||
        widget.complaint.status == ComplaintStatus.escalated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEscalated
            ? AppTheme.error.withValues(alpha: 0.1)
            : AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEscalated
              ? AppTheme.error.withValues(alpha: 0.3)
              : AppTheme.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isEscalated ? Icons.warning_rounded : Icons.timer_rounded,
                color: isEscalated ? AppTheme.error : AppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isEscalated ? 'ESCALATED SLA BREACH' : 'SLA DEADLINE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isEscalated ? AppTheme.error : AppTheme.warning,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            isEscalated ? 'Time Over' : _formattedTime,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isEscalated ? AppTheme.error : AppTheme.warning,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
