
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// A widget that records the learner's camera feed in chunks.
/// If the face is not detected, it stops recording and shows a warning.
class LearnerRecorder extends StatefulWidget {
  /// The folder where all video chunks will be stored.
  final Directory sessionFolder;

  /// Callback to notify a parent widget about face status changes (optional).
  final Function(bool)? onFaceStatusChanged;

  const LearnerRecorder({
    super.key,
    required this.sessionFolder,
    this.onFaceStatusChanged,
  });

  @override
  // Make the state class public so it can be referenced by GlobalKey<LearnerRecorderState>.
  LearnerRecorderState createState() => LearnerRecorderState();
}

class LearnerRecorderState extends State<LearnerRecorder> {
  CameraController? _controller;
  Timer? _chunkTimer;
  int _chunkIndex = 1;
  bool _isRecording = false;
  bool _faceDetected = true;
  bool _lessonEnded = false;
  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  /// Initializes the camera for chunked recording.
  Future<void> _initializeRecorder() async {
    try {
      // Get the available cameras and pick the front camera.
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Create a low-resolution camera controller for performance.
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: true, // or false, if you don't need audio
      );

      // Initialize the controller.
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {});
      // Start the first recording chunk immediately.
      _startRecordingChunk();
    } catch (e) {
      debugPrint("Error initializing LearnerRecorder: $e");
    }
  }

  /// Call this when the lesson is over and you want to stop all recordings.
Future<void> endSession() async {
  _lessonEnded = true;        // Mark the session as ended
  _chunkTimer?.cancel();      // Cancel any scheduled chunk timer
  if (_isRecording) {
    await _stopRecordingChunk();
  }
  debugPrint("Lesson ended. No further chunks will be recorded.");
}

  /// Starts a new chunk recording for 10 secs.
  Future<void> _startRecordingChunk() async {
  // Don't start if recording, controller issues, or lesson ended
  if (_isRecording || 
      _controller == null || 
      !_controller!.value.isInitialized ||
      _lessonEnded) {
    debugPrint("Skipping chunk start due to state: recording=$_isRecording, controller=${_controller != null}, initialized=${_controller?.value.isInitialized}, ended=$_lessonEnded");
    return;
  }

  try {
    await _controller!.startVideoRecording();
    setState(() => _isRecording = true);  // Use setState for all state changes
    debugPrint("Started recording chunk $_chunkIndex");

    _chunkTimer = Timer(const Duration(seconds: 10), () async {
      await _stopRecordingChunk();
      // Check conditions again before starting next chunk
      if (_faceDetected && !_lessonEnded && mounted) {
        _startRecordingChunk();
      }
    });
  } catch (e) {
    debugPrint("Error starting recording chunk: $e");
    // Add recovery logic here - maybe retry after delay?
    Future.delayed(Duration(seconds: 2), () {
      if (!_lessonEnded && mounted) _startRecordingChunk();
    });
  }
}


  /// Stops the current chunk recording and saves the file.
  Future<void> _stopRecordingChunk() async {
    if (!_isRecording || _controller == null) return;

    try {
      final rawFile = await _controller!.stopVideoRecording();
      _isRecording = false;

      final String chunkFileName = 'chunk_${_chunkIndex.toString().padLeft(2, '0')}.mp4';
      final String chunkPath = path.join(widget.sessionFolder.path, chunkFileName);
      await rawFile.saveTo(chunkPath);
      debugPrint("Saved chunk: $chunkPath");

      _chunkIndex++;
    } catch (e) {
      debugPrint("Error stopping recording chunk: $e");
    } finally {
      _chunkTimer?.cancel();
    }
  }

  Future<void> stopCurrentChunk() async {
  if (_isRecording) {
    await _stopRecordingChunk();
  }
}


  /// Update face detection status from the FaceScanner.
  /// If the face is lost, stop recording. If the face returns, resume recording.
  Future<void> updateFaceDetectionStatus(bool detected) async {
    setState(() {
      _faceDetected = detected;
    });

    // Notify parent widget if provided.
    widget.onFaceStatusChanged?.call(detected);

    if (!detected && _isRecording) {
      // Stop the current recording chunk if the face is lost.
      await _stopRecordingChunk();
      // Optionally, show a warning if you like, or do so from the main screen.
    } else if (detected && !_isRecording) {
      // Face returned, resume chunk recording if no warning is active.
      _startRecordingChunk();
    }
  }

  @override
  void dispose() {
    _chunkTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hidden widget that does not show a preview to the user.
    return Offstage(
      offstage: true,
      child: (_controller != null && _controller!.value.isInitialized)
          ? CameraPreview(_controller!)
          : const SizedBox.shrink(),
    );
  }
}
