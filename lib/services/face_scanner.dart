import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import 'face_verification_service.dart';

class FaceScanner extends StatefulWidget {
  final Function(bool) onFaceDetected;

  const FaceScanner({super.key, required this.onFaceDetected});

  @override
  State<FaceScanner> createState() => _FaceScannerState();
}

class _FaceScannerState extends State<FaceScanner> {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  Timer? _detectionTimer;
  
  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      // Try to get the front camera for face detection
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // Lower resolution for faster processing
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      if (!mounted) return;
      
      // Start capturing frames at regular intervals
      _detectionTimer = Timer.periodic(
        const Duration(milliseconds: 1500), // Adjust interval as needed
        (_) => _processCameraImage()
      );
      
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      // Report face not detected cause we can't verify
      widget.onFaceDetected(false);
    }
  }

  Future<void> _processCameraImage() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _isProcessingFrame) {
      return;
    }
    
    _isProcessingFrame = true;
    try {
      final XFile picture = await _cameraController!.takePicture();
      await _detectFace(picture);
    } catch (e) {
      debugPrint("Error processing camera image: $e");
    } finally {
      if (mounted) {
        _isProcessingFrame = false;
      }
    }
  }

  Future<void> _detectFace(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      final bool faceDetected = faces.isNotEmpty;
      
      if (faceDetected) {
        // Call the verifyFace API if a face is detected.
        try {
          await verifyFace(image.path);
        } catch (apiError) {
          debugPrint("Error calling verifyFace: $apiError");
        }
      }
      
      // Always notify parent with the current detection state.
      widget.onFaceDetected(faceDetected);
    } catch (e) {
      debugPrint("Error detecting face: $e");
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _cameraController?.value.isInitialized == true
        ? Offstage(
            offstage: true,
            child: CameraPreview(_cameraController!),
          )
        : const SizedBox.shrink();
  }
}
