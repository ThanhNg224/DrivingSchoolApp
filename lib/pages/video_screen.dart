// lib/pages/video_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'face_scanner.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  VideoScreenState createState() => VideoScreenState();
}

class VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isFaceDetected = true; // Current face detection state
  bool _warningDialogActive = false; // Indicates if the warning dialog is showing

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/siu.mp4')
      ..initialize().then((_) {
        setState(() {
          _remaining = _controller.value.duration;
        });
        _controller.play();
        _startTimer();
      });

    // Update remaining time as video plays.
    _controller.addListener(() {
      if (_controller.value.isInitialized) {
        setState(() {
          _remaining = _controller.value.duration - _controller.value.position;
          if (_remaining.isNegative) _remaining = Duration.zero;
        });
      }
    });
  }

  // Starts a timer to update remaining time and detect video completion.
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_controller.value.isPlaying &&
          _controller.value.position < _controller.value.duration) {
        setState(() {
          _remaining = _controller.value.duration - _controller.value.position;
        });
      } else if (_controller.value.position >= _controller.value.duration) {
        _timer?.cancel();
        _showCompletionDialog();
      }
    });
  }

  // Handle updates from the FaceScanner widget.
  void _handleFaceDetection(bool isDetected) {
    // If video is over, ignore any detection updates.
    if (_controller.value.position >= _controller.value.duration) return;
    
    debugPrint("Face detection update: $isDetected");
    setState(() {
      _isFaceDetected = isDetected;
    });

    if (!_isFaceDetected) {
      if (_controller.value.isPlaying) {
        _controller.pause();
        debugPrint("Video paused due to missing face");
      }
      if (!_warningDialogActive) {
        _showWarningDialog();
      }
    } else {
      if (_controller.value.isInitialized && !_controller.value.isPlaying) {
        _controller.play();
        debugPrint("Video resumed as face is detected");
      }
      if (_warningDialogActive) {
        // Delay a little to ensure state update before dismissing dialog.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_warningDialogActive && _isFaceDetected) {
            try {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                debugPrint("Warning dialog dismissed automatically after delay");
              }
            } catch (e) {
              debugPrint("Error dismissing dialog: $e");
            }
            _warningDialogActive = false;
          }
        });
      }
    }
  }

  // Display warning dialog when no face is detected.
  void _showWarningDialog() {
    _warningDialogActive = true;
    showDialog(
      context: context,
      barrierDismissible: false, // Must tap OK.
      builder: (context) => AlertDialog(
        title: const Text("Face Not Detected"),
        content: const Text("Please ensure your face is visible to continue watching the video."),
        actions: [
          TextButton(
            onPressed: () {
              // Dismiss dialog unconditionally.
              Navigator.of(context, rootNavigator: true).pop();
              _warningDialogActive = false;
              // Re-check detection state after a short delay.
              Future.delayed(const Duration(milliseconds: 200), () {
                if (!_isFaceDetected) {
                  _showWarningDialog();
                  debugPrint("Re-showing warning dialog as no face detected after OK");
                } else {
                  if (_controller.value.isInitialized && !_controller.value.isPlaying) {
                    _controller.play();
                    debugPrint("Video resumed after OK pressed, face detected");
                  }
                }
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    ).then((_) {
      _warningDialogActive = false;
    });
  }

  // Display a dialog when the video completes.
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent skipping.
      builder: (context) => AlertDialog(
        title: const Text("Lesson Completed"),
        content: const Text("You have finished watching the lesson video."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Here: Navigate to the next screen.
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  // Helper to format Duration as mm:ss.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:'
           '${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progressValue = 0.0;
    if (_controller.value.isInitialized && _controller.value.duration.inSeconds > 0) {
      final durationSeconds = _controller.value.duration.inSeconds;
      final positionSeconds = _controller.value.position.inSeconds;
      progressValue = positionSeconds / durationSeconds;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Video'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.grey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _controller.value.isInitialized
              ? Stack(
                  children: [
                    Column(
                      children: [
                        // Progress bar and remaining time.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Remaining: ${_formatDuration(_remaining)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progressValue,
                                backgroundColor: Colors.grey.shade800,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                minHeight: 8,
                              ),
                            ],
                          ),
                        ),
                        // Video player area.
                        Expanded(
                          flex: 9,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: _controller.value.size.width,
                                height: _controller.value.size.height,
                                child: AbsorbPointer(
                                  child: VideoPlayer(_controller),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Instruction text at the bottom.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          color: Colors.black.withAlpha((0.5 * 255).toInt()),
                          child: const Text(
                            "You must watch the full video before continuing.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    // Hidden FaceScanner widget running in the background.
                    FaceScanner(onFaceDetected: _handleFaceDetection),
                    // Visual indicator for face detection status.
                    Positioned(
                      top: 50,
                      right: 10,
                      child: _isFaceDetected
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 40)
                          : const Icon(Icons.warning, color: Colors.red, size: 40),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),
      ),
    );
  }
}
