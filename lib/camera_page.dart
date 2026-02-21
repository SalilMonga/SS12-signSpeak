import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'history_page.dart';
import 'settings_page.dart';

const _mpChannel = MethodChannel('mediapipe_hands');

const Color _kPrimaryBlue = Color(0xFF3B5BFE);

// ---------------------------------------------------------------------------
// CameraPage — full-screen camera with floating overlay widgets
// ---------------------------------------------------------------------------

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _hasError = false;
  String _errorMessage = '';
  int _cameraIndex = 0;
  bool _flashOn = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No cameras found on this device.';
      });
      return;
    }

    final previousController = _controller;
    _controller = null;
    await previousController?.dispose();

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888, // required for iOS MediaPipe bridge
    );

    try {
      await controller.initialize();

      // Stream camera frames to iOS native code for MediaPipe hand detection
      int lastSentMs = 0;
      await controller.startImageStream((CameraImage image) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Throttle to ~10 fps to avoid spamming the bridge
        if (now - lastSentMs < 100) return;
        lastSentMs = now;

        final Uint8List bytes = image.planes.first.bytes;
        try {
          await _mpChannel.invokeMethod('processFrameBGRA', {
            'w': image.width,
            'h': image.height,
            'bytes': bytes,
            't': now,
            'bytesPerRow': image.planes.first.bytesPerRow,
          });
        } catch (e) {
          debugPrint("processFrameBGRA failed: $e");
        }
      });

      if (!mounted) return;
      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();
      setState(() {
        _controller = controller;
        _hasError = false;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _currentZoom = 1.0;
      });
    } on CameraException catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Camera error: ${e.description}';
      });
    }
  }

  void _switchCamera() {
    HapticFeedback.lightImpact();
    // Toggle between front and back only — pick the first camera with the
    // opposite lens direction so we don't cycle through ultrawide/telephoto.
    final currentDirection = _cameras[_cameraIndex].lensDirection;
    final targetDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final idx = _cameras.indexWhere((c) => c.lensDirection == targetDirection);
    if (idx != -1) _cameraIndex = idx;
    _flashOn = false;
    _initCamera();
  }

  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.lightImpact();

    if (_isFrontCamera) {
      // Front camera has no torch — toggle screen glow instead
      setState(() => _flashOn = !_flashOn);
      // Max out screen brightness when glow is on
      if (_flashOn) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    } else {
      final newMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(newMode);
      setState(() => _flashOn = !_flashOn);
    }
  }

  Future<void> _setZoom(double level) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final clamped = level.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clamped);
    HapticFeedback.selectionClick();
    setState(() => _currentZoom = clamped);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _hasError
          ? _buildError()
          : (_controller == null || !_controller!.value.isInitialized)
          ? const Center(child: CircularProgressIndicator())
          : _buildCameraStack(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen camera preview
        _CameraPreview(controller: _controller!),

        // Front-camera "flash" — uniform white overlay to boost screen brightness
        if (_isFrontCamera && _flashOn)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),

        // Live Translation Card (top)
        const Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _LiveTranslationCard(),
            ),
          ),
        ),

        // Detection frame overlay (centered)
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(painter: _DetectionFramePainter()),
          ),
        ),

        // Bottom control bar + camera switch
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom selector — back camera only
                if (!_isFrontCamera)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ZoomSelector(
                      currentZoom: _currentZoom,
                      minZoom: _minZoom,
                      maxZoom: _maxZoom,
                      onZoomSelected: _setZoom,
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _BottomControlBar(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CameraSwitchButton(
                      onPressed: _switchCamera,
                      isFront: _isFrontCamera,
                    ),
                    const SizedBox(width: 24),
                    _FlashButton(
                      onPressed: _toggleFlash,
                      isOn: _flashOn,
                      isFrontCamera: _isFrontCamera,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CameraPreview — fills entire parent, edge-to-edge
// ---------------------------------------------------------------------------

class _CameraPreview extends StatelessWidget {
  final CameraController controller;

  const _CameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize!.height,
              height: controller.value.previewSize!.width,
              child: controller.buildPreview(),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _LiveTranslationCard — floating white card at top
// ---------------------------------------------------------------------------

class _LiveTranslationCard extends StatelessWidget {
  const _LiveTranslationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'LIVE TRANSLATION',
                style: TextStyle(
                  color: _kPrimaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _kPrimaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Processing...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Translated text placeholder
          const Text(
            'Hello, how can I help you today?',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          const Divider(height: 1),
          const SizedBox(height: 12),

          // Detection status row
          Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: _kPrimaryBlue,
                child: Icon(Icons.check, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Hand detected',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _kPrimaryBlue, width: 1.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '98% CONFIDENCE',
                  style: TextStyle(
                    color: _kPrimaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DetectionFramePainter — four blue corner brackets
// ---------------------------------------------------------------------------

class _DetectionFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kPrimaryBlue
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double len = 30;

    // Top-left
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - len),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// _ZoomSelector — 0.5x / 1x / 2x pill toggle (back camera only)
// ---------------------------------------------------------------------------

class _ZoomSelector extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomSelected;

  const _ZoomSelector({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = <double>[0.5, 1.0, 2.0]
        .where((z) => z >= minZoom && z <= maxZoom)
        .toList();

    // Always include 1.0 if the range covers it
    if (!options.contains(1.0) && minZoom <= 1.0 && maxZoom >= 1.0) {
      options.add(1.0);
      options.sort();
    }

    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((zoom) {
          final isSelected = (currentZoom - zoom).abs() < 0.05;
          final label = zoom == 0.5
              ? '.5x'
              : '${zoom.toStringAsFixed(0)}x';
          return GestureDetector(
            onTap: () => onZoomSelected(zoom),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? _kPrimaryBlue : Colors.white,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BottomControlBar — floating white pill with History / Speech On / Settings
// ---------------------------------------------------------------------------

class _BottomControlBar extends StatefulWidget {
  const _BottomControlBar();

  @override
  State<_BottomControlBar> createState() => _BottomControlBarState();
}

class _BottomControlBarState extends State<_BottomControlBar> {
  bool _speechOn = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // History
          _BarIconLabel(
            icon: Icons.history,
            label: 'History',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),

          // Speech toggle pill button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _speechOn = !_speechOn);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _speechOn ? _kPrimaryBlue : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _speechOn ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _speechOn ? 'SPEECH ON' : 'SPEECH OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Settings
          _BarIconLabel(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarIconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BarIconLabel({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade700),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FlashButton — small circular button to toggle torch
// ---------------------------------------------------------------------------

class _FlashButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isOn;
  final bool isFrontCamera;

  const _FlashButton({
    required this.onPressed,
    required this.isOn,
    required this.isFrontCamera,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    if (isFrontCamera) {
      icon = isOn ? Icons.lightbulb : Icons.lightbulb_outline;
    } else {
      icon = isOn ? Icons.flash_on : Icons.flash_off;
    }

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOn ? _kPrimaryBlue : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isOn ? Colors.white : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOn ? 'On' : 'Off',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CameraSwitchButton — small circular button below the control bar
// ---------------------------------------------------------------------------

class _CameraSwitchButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isFront;

  const _CameraSwitchButton({required this.onPressed, required this.isFront});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cameraswitch,
              size: 22,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFront ? 'Front' : 'Back',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
