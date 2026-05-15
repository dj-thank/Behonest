import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/capture_upload_service.dart';
import '../services/trip_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.uid,
    required this.tripId,
    required this.momentId,
  });

  final String uid;
  final String tripId;
  final String momentId;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _uploadService = CaptureUploadService();
  final _tripService = TripService();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  XFile? _backPhoto;
  XFile? _frontPhoto;
  File? _combinedPreview;
  bool _initializing = true;
  bool _taking = false;
  bool _uploading = false;
  Object? _cameraError;
  _CaptureStep _step = _CaptureStep.back;

  @override
  void initState() {
    super.initState();
    unawaited(_setupCamera());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _setupCamera() async {
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw StateError('利用できるカメラがありません。');
      }
      await _switchToStep(_step);
    } catch (error) {
      _cameraError = error;
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _switchToStep(_CaptureStep step) async {
    await _controller?.dispose();
    _controller = null;

    final direction = step == _CaptureStep.back
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final camera = _cameras.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => _cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    await controller.initialize();
    if (mounted) setState(() => _step = step);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _combinedPreview;
    if (preview != null) return _buildPreview(preview);

    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_step == _CaptureStep.back ? '外カメを撮る' : 'インカメを撮る'),
      ),
      body: _buildCameraBody(controller),
    );
  }

  Widget _buildCameraBody(CameraController? controller) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'カメラを起動できませんでした。\n$_cameraError',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _setupCamera, child: const Text('もう一度試す')),
            ],
          ),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(controller)),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _helperText,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _taking || _uploading ? null : _takePicture,
                    icon: Icon(_taking ? Icons.hourglass_empty : Icons.camera_alt),
                    label: Text(_buttonText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(File preview) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('投稿前チェック'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(preview, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _retake,
                      icon: const Icon(Icons.refresh),
                      label: const Text('撮り直す'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: Icon(_uploading ? Icons.cloud_upload : Icons.send),
                      label: Text(_uploading ? '投稿中...' : '投稿する'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _helperText {
    if (_uploading) return 'アップロード中...';
    if (_step == _CaptureStep.back) return 'まずは目の前の景色を撮ろう。次にインカメを撮ります。';
    return '次に今の自分たちを撮ろう。投稿前に確認できます。';
  }

  String get _buttonText {
    if (_taking) return '撮影中...';
    return _step == _CaptureStep.back ? '外カメで撮る' : 'インカメで撮る';
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _taking = true);
    try {
      final photo = await controller.takePicture();
      if (_step == _CaptureStep.back) {
        _backPhoto = photo;
        await _switchToStep(_CaptureStep.front);
      } else {
        _frontPhoto = photo;
        await _buildCombinedPreview();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撮影に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _buildCombinedPreview() async {
    final backPhoto = _backPhoto;
    final frontPhoto = _frontPhoto;
    if (backPhoto == null || frontPhoto == null) return;

    final preview = await _uploadService.buildCombinedPreview(
      backPhoto: backPhoto,
      frontPhoto: frontPhoto,
    );
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _combinedPreview = preview);
  }

  Future<void> _upload() async {
    final backPhoto = _backPhoto;
    final frontPhoto = _frontPhoto;
    final combinedPreview = _combinedPreview;
    if (backPhoto == null || frontPhoto == null || combinedPreview == null) return;

    setState(() => _uploading = true);
    try {
      final profile = await _tripService.userProfile(widget.uid).first;
      await _uploadService.uploadPost(
        uid: widget.uid,
        tripId: widget.tripId,
        momentId: widget.momentId,
        displayName: profile.displayName,
        backPhoto: backPhoto,
        frontPhoto: frontPhoto,
        combinedPhoto: combinedPreview,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _retake() async {
    _backPhoto = null;
    _frontPhoto = null;
    _combinedPreview = null;
    _step = _CaptureStep.back;
    await _setupCamera();
  }
}

enum _CaptureStep { back, front }
