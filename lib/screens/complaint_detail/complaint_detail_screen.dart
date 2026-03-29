import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../models/complaint.dart';
import '../../models/user_models.dart';
import '../../models/field_worker.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/field_worker_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../repository/grievance_mappers.dart' show eventAccentColor;
import '../../widgets/civic_ui.dart';
import '../../widgets/sensitive_blur_wrapper.dart';
import '../../widgets/audio_player_widget.dart';
import '../../utils/launch_links.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../officer/chat_screen.dart';

part '_widgets.dart';
part '_location.dart';
part '_comments.dart';
part '_updates.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Citizen / Manager Complaint Detail Screen
// ═══════════════════════════════════════════════════════════════════════════════

class ComplaintDetailScreen extends ConsumerStatefulWidget {
  final Complaint complaint;
  final bool isEmbedded;

  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<ComplaintDetailScreen> createState() =>
      _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _commentScrollController = ScrollController();
  final MapController _mapController = MapController();
  int _selectedTab = 0;
  String? _loadingId;

  // Wrapper for setState — needed because extensions can't call setState directly
  // ignore: unused_element
  void _rebuildState(VoidCallback fn) => setState(fn);

  WebSocketChannel? _wsChannel;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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
          .then((_) {
            _scrollToBottom();
          });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allComplaints = ref.watch(complaintListProvider);
    final c = allComplaints.firstWhere(
      (item) => item.id == widget.complaint.id,
      orElse: () => widget.complaint,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 800;

        if (widget.isEmbedded) {
          return isWeb
              ? _buildWebDetailLayout(c)
              : _buildMobileDetailContent(c);
        }

        return ResponsiveLayout(
          mobile: _buildMobileStandalone(c),
          desktop: _buildWebStandalone(c),
        );
      },
    );
  }

  Widget _buildMobileStandalone(Complaint c) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceScaffold.withValues(alpha: 0.8),
            scrolledUnderElevation: 0,
            pinned: true,
            floating: false,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Ticket #${c.id.length > 4 ? c.id.substring(c.id.length - 4) : c.id.padLeft(4, '0')}',
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
                child: ListView(
                  key: const PageStorageKey('web_content_list'),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeaderImage(c),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
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
                                    color: Colors.grey[500],
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  c.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF3A3A3C),
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

                          // Location Bento Card
                          _buildBentoCard(child: _buildLocationSection(c)),
                          const SizedBox(height: 24),

                          // Activity & Feedback Section
                          _buildTabSection(c),
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
                                    key: const ValueKey('feedback'),
                                    child: _buildFeedbackTab(c),
                                  ),
                          ),
                          const SizedBox(
                            height: 100,
                          ), // Clearance for bottom bar
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(c),
    );
  }

  Widget _buildWebStandalone(Complaint c) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Issue Ticket',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _buildWebDetailLayout(c, padding: const EdgeInsets.all(32)),
        ),
      ),
    );
  }

  Widget _buildWebDetailLayout(
    Complaint c, {
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    final ticketId =
        '#TK-${DateFormat('yy').format(c.date)}-${c.id.length > 4 ? c.id.substring(c.id.length - 4).toUpperCase() : c.id.padLeft(4, '0').toUpperCase()}';

    return SingleChildScrollView(
      key: const PageStorageKey('web_sidebar_scroll'),
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Core Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Information
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ticketId,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat(
                              'MMMM dd, yyyy • hh:mm a',
                            ).format(c.date),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        c.title,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMetadataTags(c),
                      const SizedBox(height: 24),
                      Text(
                        c.description,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF4B5563),
                          height: 1.6,
                        ),
                      ),
                      if (c.audioPath != null) ...[
                        const SizedBox(height: 16),
                        AudioPlayerWidget(url: c.audioPath!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Location section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: _buildLocationSection(c),
                ),
                const SizedBox(height: 24),
                // Image if available
                if (c.imagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildHeaderImage(c),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right Column: Interaction & Timeline
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT STATUS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[400],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailedStatus(c),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Timeline & Comments Tabs
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _buildTabSection(c),
                      const SizedBox(height: 24),
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
                                key: const ValueKey('scrollable_comments'),
                                child: _buildScrollableComments(c),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatus(Complaint c) {
    final statusColor = Color(c.status.colorValue);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(c.status.icon, color: statusColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.status.label,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              Text(
                'Updated on ${DateFormat('MMM dd').format(c.date)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDetailContent(Complaint c) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(complaintProvider.notifier)
                .refreshGrievanceDetail(c.id),
            child: SingleChildScrollView(
              key: const PageStorageKey('mobile_detail_scroll'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderImage(c),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusRow(c),
                        const SizedBox(height: 16),
                        Text(
                          c.title,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMetadataTags(c),
                        const SizedBox(height: 20),
                        Text(
                          c.description,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4B5563),
                            height: 1.6,
                          ),
                        ),
                        if (c.audioPath != null) ...[
                          const SizedBox(height: 16),
                          AudioPlayerWidget(url: c.audioPath!),
                        ],
                        const SizedBox(height: 24),
                        _buildLocationSection(c),
                        const Divider(height: 48),
                        _buildTabSection(c),
                        const SizedBox(height: 24),
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
                                  key: const ValueKey('feedback'),
                                  child: _buildFeedbackTab(c),
                                ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(c),
      ],
    );
  }
}
