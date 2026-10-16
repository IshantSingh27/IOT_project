import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';

class MjpegStreamView extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  const MjpegStreamView({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
  });

  @override
  State<MjpegStreamView> createState() => _MjpegStreamViewState();
}

class _MjpegStreamViewState extends State<MjpegStreamView> {
  Uint8List? _currentFrame;
  http.Client? _client;
  StreamSubscription? _subscription;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  void _startStream() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _errorMessage = 'Stream returned status ${response.statusCode}';
          });
        }
        return;
      }

      final List<int> buffer = [];
      const jpegStart = 0xFFD8; // SOI
      const jpegEnd = 0xFFD9;   // EOI

      _subscription = response.stream.listen(
        (chunk) {
          buffer.addAll(chunk);

          // Find complete JPEG frames inside the buffer
          while (true) {
            final startIndex = _findByteSequence(buffer, jpegStart);
            if (startIndex == -1) {
              if (buffer.length > 500000) buffer.clear();
              break;
            }

            final endIndex = _findByteSequence(buffer, jpegEnd, startIndex + 2);
            if (endIndex == -1) break;

            final frameBytes = Uint8List.fromList(buffer.sublist(startIndex, endIndex + 2));
            buffer.removeRange(0, endIndex + 2);

            if (mounted) {
              setState(() {
                _currentFrame = frameBytes;
                _isLoading = false;
                _hasError = false;
              });
            }
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
              _errorMessage = 'Stream disconnected';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
              _errorMessage = 'Stream ended';
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  int _findByteSequence(List<int> bytes, int sequence, [int start = 0]) {
    final b1 = (sequence >> 8) & 0xFF;
    final b2 = sequence & 0xFF;

    for (int i = start; i < bytes.length - 1; i++) {
      if (bytes[i] == b1 && bytes[i + 1] == b2) {
        return i;
      }
    }
    return -1;
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: AppColors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: AppColors.alertRed, size: 40),
              const SizedBox(height: 8),
              Text(
                "Camera Stream Offline",
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage.isEmpty ? "Check network or backend" : _errorMessage,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _stopStream();
                  _startStream();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Reconnect"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _currentFrame == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: AppColors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              const SizedBox(height: 12),
              Text(
                "Connecting to Camera Feed...",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return widget.placeholder ?? const Center(child: Icon(Icons.error, color: Colors.red));
      },
    );
  }
}
