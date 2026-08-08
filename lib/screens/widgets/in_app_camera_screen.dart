import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:traceability_app/services/language_service.dart';

/// Opens a full-screen **in-app** camera and returns the captured JPEG file
/// path, or `null` if the user cancelled or capture failed.
///
/// Unlike `image_picker`'s `ImageSource.camera` (which launches the separate
/// system-camera app and lets Android kill our process under memory pressure),
/// this camera runs inside our own process. That means any work running in
/// parallel — GPS sampling and the accuracy dialog — survives the capture, so
/// the "menghitung akurasi" modal always appears and no point is ever lost to a
/// cold restart.
Future<String?> captureInAppPhoto(BuildContext context, {String? title}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => InAppCameraScreen(title: title),
    ),
  );
}

class InAppCameraScreen extends StatefulWidget {
  final String? title;
  const InAppCameraScreen({super.key, this.title});

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _description;
  bool _capturing = false;
  bool _ready = false;
  String? _error;
  FlashMode _flash = FlashMode.off;

  bool get _isID => LanguageService.to.isId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _error =
              _isID ? 'Tidak ada kamera terdeteksi.' : 'No camera detected.');
        }
        return;
      }
      _description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _initController(_description!);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            (_isID ? 'Gagal membuka kamera: ' : 'Failed to open camera: ') +
                e.toString());
      }
    }
  }

  Future<void> _initController(CameraDescription cam) async {
    final controller = CameraController(
      cam,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      try {
        await controller.setFlashMode(_flash);
      } catch (_) {}
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            (_isID ? 'Gagal membuka kamera: ' : 'Failed to open camera: ') +
                e.toString());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    if (state == AppLifecycleState.inactive) {
      _ready = false;
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _description != null) {
      _initController(_description!);
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await c.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final shot = await c.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(shot.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              (_isID ? 'Gagal mengambil foto: ' : 'Failed to capture: ') +
                  e.toString())));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildPreview(c)),
            // Top bar: close + flash.
            Positioned(
              top: 8,
              left: 4,
              right: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (widget.title != null)
                    Expanded(
                      child: Text(
                        widget.title!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      _flash == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                      color: Colors.white,
                    ),
                    onPressed: _ready ? _toggleFlash : null,
                  ),
                ],
              ),
            ),
            // Shutter.
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: (_ready && !_capturing) ? _capture : null,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(CameraController? c) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    if (c == null || !_ready || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return CameraPreview(c);
  }
}
