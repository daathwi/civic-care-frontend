import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_theme.dart';

class VoiceRecordingWidget extends StatefulWidget {
  final Function(File?) onRecordingComplete;

  const VoiceRecordingWidget({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget> {
  late AudioRecorder _recorder;
  late AudioPlayer _player;

  bool _isRecording = false;
  String? _recordingPath;
  Duration _duration = Duration.zero;
  Timer? _timer;

  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _player = AudioPlayer();

    _player.onPositionChanged.listen((p) {
      setState(() => _playPosition = p);
    });
    _player.onDurationChanged.listen((d) {
      setState(() => _totalDuration = d);
    });
    _player.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _playPosition = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig();
        await _recorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _duration = Duration.zero;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() => _duration = Duration(seconds: t.tick));
          if (t.tick >= 120) {
            // 2 minutes limit
            _stopRecording();
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordingPath = path;
    });
    if (path != null) {
      widget.onRecordingComplete(File(path));
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordingPath == null) return;

    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(_recordingPath!));
      setState(() => _isPlaying = true);
    }
  }

  void _deleteRecording() {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) file.deleteSync();
    }
    setState(() {
      _recordingPath = null;
      _duration = Duration.zero;
      _isPlaying = false;
      _playPosition = Duration.zero;
      _totalDuration = Duration.zero;
    });
    widget.onRecordingComplete(null);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_recordingPath != null && !_isRecording)
            _buildPlaybackUI()
          else
            _buildRecordUI(),
        ],
      ),
    );
  }

  Widget _buildRecordUI() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressUp: () => _stopRecording(),
      onLongPressCancel: () => _stopRecording(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        color: _isRecording
            ? Colors.red.withValues(alpha: 0.05)
            : Colors.transparent,
        child: Row(
          children: [
            _buildRecordIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording ? 'Recording...' : 'Voice Note',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _isRecording ? Colors.red : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isRecording
                        ? 'Release to stop • ${_formatDuration(_duration)}'
                        : 'Hold to record your message',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (_isRecording) const _RecordingPulse(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isRecording
            ? Colors.red.withValues(alpha: 0.1)
            : AppTheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: _isRecording ? Colors.red : AppTheme.primary,
        size: 24,
      ),
    );
  }

  Widget _buildPlaybackUI() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _PlaybackButton(isPlaying: _isPlaying, onTap: _togglePlayback),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voice Note',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_formatDuration(_playPosition)} / ${_formatDuration(_totalDuration)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _totalDuration.inMilliseconds > 0
                        ? _playPosition.inMilliseconds /
                              _totalDuration.inMilliseconds
                        : 0,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.withValues(alpha: 0.7),
              size: 22,
            ),
            onPressed: _deleteRecording,
          ),
        ],
      ),
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlaybackButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse();

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(CurveTween(curve: Curves.easeInOut)),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
