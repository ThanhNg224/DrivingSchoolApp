// lib/pages/video_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/learner_recorder.dart';
import '../services/face_scanner.dart';
import '../services/permission_service.dart';
import '../services/session_manager.dart';


class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  VideoScreenState createState() => VideoScreenState();
}

class VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isFaceDetected = true;
  bool _warningDialogActive = false;
  late Directory sessionFolder;

  // Global key to access LearnerRecorder's state.
  final GlobalKey<LearnerRecorderState> _learnerRecorderKey = GlobalKey<LearnerRecorderState>();

  @override
  void initState() {
    super.initState();
    _askForPermissionsThenInit();
  }

  Future<void> _askForPermissionsThenInit() async {
    // 1) Request the permissions
    bool granted = await requestPermissions();
    if (!mounted) return;

    if (!granted) {
      // Show an alert or navigate back if permissions are critical
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Permissions Required"),
          content: const Text("Camera and microphone permissions are needed."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            )
          ],
        ),
      );
      return;
    }

    // If permissions are granted, initialize the session and video.
    _initializeSessionAndVideo();
  
  }
  
  Future<void> _initializeSessionAndVideo() async {
    try {
      // Create a unique session folder (from Step 1).
      sessionFolder = await createSessionFolder();
      debugPrint("Session folder created: ${sessionFolder.path}");
      
      // Initialize the lesson video player (using an asset for demonstration).
      _controller = VideoPlayerController.asset('assets/videos/siu.mp4')
        ..initialize().then((_) {
          setState(() {
            _remaining = _controller.value.duration;
          });
          _controller.play();
          _startTimer();
        });
      
      // Update remaining time as the video plays.
      _controller.addListener(() {
        if (_controller.value.isInitialized) {
          setState(() {
            _remaining = _controller.value.duration - _controller.value.position;
            if (_remaining.isNegative) _remaining = Duration.zero;
          });
        }
      });
    } catch (e) {
      debugPrint("Error in initialization: $e");
    }
  }

  // Timer that updates the remaining time and shows a completion dialog when the video ends.
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
        _learnerRecorderKey.currentState?.endSession();
      }
    });
  }

  // Combined face detection handler that updates both the video playback and the learner recorder.
  void _handleFaceDetection(bool isDetected) {
    // If video is over, ignore further face detection.
    if (_controller.value.position >= _controller.value.duration) return;
    
    debugPrint("Face detection update: $isDetected");
    setState(() {
      _isFaceDetected = isDetected;
    });
    
    // Forward face detection status to the LearnerRecorder.
    _learnerRecorderKey.currentState?.updateFaceDetectionStatus(isDetected);
    
    // Manage video playback based on face detection.
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
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_warningDialogActive && _isFaceDetected) {
            try {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
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

  // Displays a warning dialog when no face is detected.
  void _showWarningDialog() {
    _warningDialogActive = true;
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap OK.
      builder: (context) => AlertDialog(
        title: const Text("Face Not Detected"),
        content: const Text("Please ensure your face is visible to continue watching the video."),
        actions: [
          TextButton(
            onPressed: () {
              // Dismiss dialog unconditionally.
              Navigator.of(context, rootNavigator: true).pop();
              _warningDialogActive = false;
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

  // Displays a completion dialog when the video finishes.
  void _showCompletionDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text("Lesson Completed"),
      content: const Text("You have finished watching the lesson video."),
      actions: [
        TextButton(
          onPressed: () {
            // Stop the current recording chunk
            _learnerRecorderKey.currentState?.stopCurrentChunk();

            Navigator.pop(context);
            //Navigate to next screen or do other steps
          },
          child: const Text("Continue"),
        ),
      ],
    ),
  );
}


  // Helper to format a Duration as mm:ss.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
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
                        // Instruction text.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          color: Colors.black.withAlpha(200),
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
                    // LearnerRecorder (hidden) for recording learner’s face.
                    LearnerRecorder(
                      key: _learnerRecorderKey,
                      sessionFolder: sessionFolder,
                      onFaceStatusChanged: (detected) {
                        debugPrint("LearnerRecorder received face status: $detected");
                      },
                    ),
                    // FaceScanner widget for real-time face detection.
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
