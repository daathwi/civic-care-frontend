import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SensitiveBlurWrapper extends StatefulWidget {
  final Widget child;
  final bool isSensitive;
  final double blurAmount;

  const SensitiveBlurWrapper({
    super.key,
    required this.child,
    this.isSensitive = false,
    this.blurAmount = 20.0,
  });

  @override
  State<SensitiveBlurWrapper> createState() => _SensitiveBlurWrapperState();
}

class _SensitiveBlurWrapperState extends State<SensitiveBlurWrapper> {
  bool _isBlurred = true;

  @override
  void initState() {
    super.initState();
    _isBlurred = widget.isSensitive;
  }

  @override
  void didUpdateWidget(SensitiveBlurWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSensitive != widget.isSensitive) {
      setState(() {
        _isBlurred = widget.isSensitive;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSensitive) return widget.child;

    return ClipRRect(
      child: Stack(
        children: [
          widget.child,
          if (_isBlurred)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurAmount,
                    sigmaY: widget.blurAmount,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isBlurred = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.black87,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sensitive Content',
                                style: GoogleFonts.outfit(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
