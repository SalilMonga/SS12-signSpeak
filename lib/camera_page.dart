import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'test_page.dart';

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

  // 👇 NEW: live “best guess” coming from iOS
  String _bestGuess = 'no hands detected';
  int _handsCount = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // 👇 NEW: listen for iOS -> Flutter updates
    _mpChannel.setMethodCallHandler(_onNativeMessage);

    _initCamera();
  }

  // 👇 NEW: handle iOS callbacks
  Future<void> _onNativeMessage(MethodCall call) async {
    switch (call.method) {
      case 'onWord':
        // expects: { "word": "apple" } OR just "apple"
        String next = 'no hands detected';
        final args = call.arguments;

        if (args is String) {
          next = args;
        } else if (args is Map) {
          final w = args['word'];
          if (w is String) next = w;
        }

        if (!mounted) return;
        setState(() {
          _bestGuess = next.isEmpty ? 'no hands detected' : next;
        });
        return;

      case 'onHands':
        // optional: expects { "count": 0/1/2 } OR just int
        int c = 0;
        final args = call.arguments;
        if (args is int) {
          c = args;
        } else if (args is Map) {
          final v = args['count'];
          if (v is int) c = v;
        }

        if (!mounted) return;
        setState(() {
          _handsCount = c;
          if (c == 0) _bestGuess = 'no hands detected';
        });
        return;

      default:
        return;
    }
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
      _cameras.isNotEmpty && _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    if (_isFrontCamera) return; // no flash on most front cams

    HapticFeedback.lightImpact();
    _flashOn = !_flashOn;
    try {
      await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // ignore
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null) return;
    HapticFeedback.selectionClick();
    final z = zoom.clamp(_minZoom, _maxZoom);
    _currentZoom = z;
    try {
      await _controller!.setZoomLevel(z);
      if (!mounted) return;
      setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    // (optional) stop listening
    _mpChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_hasError) {
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

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _CameraPreview(controller: _controller!),

        // Top overlay card (✅ constrained so it won't fill the screen)
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 160, // 👈 tweak this number if you want it taller/shorter
                ),
                child: _LiveTranslationCard(
                  bestGuess: _bestGuess,
                  handsCount: _handsCount,
                ),
              ),
            ),
          ),
        ),

        // Bottom controls (kept as-is)
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleIconButton(
                    icon: Icons.history,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryPage()),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _CircleIconButton(
                    icon: Icons.cameraswitch,
                    onPressed: _switchCamera,
                  ),
                  const SizedBox(width: 20),
                  _CircleIconButton(
                    icon: Icons.settings,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Zoom selector (if back camera)
        if (!_isFrontCamera)
          Positioned(
            right: 16,
            top: 160,
            child: _ZoomSelector(
              currentZoom: _currentZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              onZoomSelected: _setZoom,
            ),
          ),

        // Flash toggle
        Positioned(
          left: 16,
          bottom: 96,
          child: _FlashButton(
            onPressed: _toggleFlash,
            isOn: _flashOn,
            isFrontCamera: _isFrontCamera,
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
  final String bestGuess;
  final int handsCount;

  const _LiveTranslationCard({
    required this.bestGuess,
    required this.handsCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasHands = handsCount > 0;
    final display = bestGuess.isEmpty ? 'no hands detected' : bestGuess;

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
          Row(
            children: [
              const Text(
                'LIVE GUESS',
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
                decoration: BoxDecoration(
                  color: hasHands ? _kPrimaryBlue : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                hasHands ? 'Seeing hands' : 'No hands',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            display,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            hasHands ? 'hands: $handsCount' : 'show your hands to start',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons / controls (unchanged)
// ---------------------------------------------------------------------------

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

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
    if (isFrontCamera) return const SizedBox.shrink();
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isOn ? 'Flash On' : 'Flash Off',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((zoom) {
          final isSelected = (currentZoom - zoom).abs() < 0.05;
          final label = zoom == 0.5 ? '.5x' : '${zoom.toStringAsFixed(0)}x';
          return GestureDetector(
            onTap: () => onZoomSelected(zoom),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _kPrimaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

          // Test API
          _BarIconLabel(
            icon: Icons.science_outlined,
            label: 'Test API',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestPage()),
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
