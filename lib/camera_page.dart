import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'api_service.dart';
import 'history_page.dart';
import 'main.dart' show serverIpNotifier, offlineModeNotifier;
import 'offline_sentence_service.dart';
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

  // Live "best guess" coming from iOS
  String _bestGuess = 'no hands detected';
  int _handsCount = 0;
  bool _paused = false;

  final List<String> _wordBuffer =[];
  // Sentence generation
  final ApiService _apiService = ApiService();
  final OfflineSentenceService _offlineService = OfflineSentenceService();
  String _generatedSentence = '';
  bool _generatingApi = false;

  // TTS
  late final FlutterTts _tts;
  bool _speechOn = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Load offline templates
    _offlineService.init();

    // Init TTS (same config as SpeechPage)
    _tts = FlutterTts();
    _initTts();

    // Keep ApiService IP in sync with global setting
    _apiService.updateIp(serverIpNotifier.value);
    serverIpNotifier.addListener(_onServerIpChanged);

    // Listen for iOS -> Flutter updates
    _mpChannel.setMethodCallHandler(_onNativeMessage);

    _initCamera();
  }

  void _onServerIpChanged() {
    _apiService.updateIp(serverIpNotifier.value);
  }

  Future<void> _initTts() async {
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowAirPlay,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ],
      IosTextToSpeechAudioMode.voicePrompt,
    );
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speakSentence(String sentence) async {
    if (!_speechOn || sentence.isEmpty) return;
    await _tts.stop();
    await _tts.speak(sentence);
  }

  // Handle iOS -> Flutter callbacks
  Future<void> _onNativeMessage(MethodCall call) async {
    // Drop all native messages while paused
    if (_paused) return;

    switch (call.method) {
      case 'onWord':
        // expects: { "word": "apple" } OR just "apple"
        String next = 'no hands detected';
        final args = call.arguments;
        setState(() => _bestGuess = next); //clear

        
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

      case 'onPhraseComplete':
        final args = call.arguments;
        List<String> words = [];
        if (args is Map) {
          final w = args['words'];
          if (w is List) {
            words = w.map((e) => e.toString()).toList();
          }
        }
        if (words.isEmpty || !mounted) return;

        if (offlineModeNotifier.value) {
          // Offline: local template router (instant)
          final sentence = _offlineService.generate(words);
          if (!mounted) return;
          setState(() {
            _generatedSentence = sentence;
            _generatingApi = false;
          });
          _speakSentence(sentence);
        } else {
          // Online: Ollama API (async)
          setState(() {
            _generatingApi = true;
            _generatedSentence = '';
          });

          try {
            final sentence = await _apiService.generateSentence(words);
            if (!mounted) return;
            setState(() {
              _generatedSentence = sentence;
              _generatingApi = false;
            });
            _speakSentence(sentence);
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _generatedSentence = 'Could not reach server';
              _generatingApi = false;
            });
          }
        }
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
      imageFormatGroup:
          ImageFormatGroup.bgra8888, // required for iOS MediaPipe bridge
    );

    try {
      await controller.initialize();

      // Start streaming unless already paused
      if (!_paused) {
        await _startImageStream(controller);
      }

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

  Future<void> _startImageStream(CameraController controller) async {
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
  }

  Future<void> _togglePause() async {
    if (_controller == null) return;
    HapticFeedback.lightImpact();

    if (_paused) {
      // Resume: restart the image stream
      await _startImageStream(_controller!);
      setState(() => _paused = false);
    } else {
      // Pause: stop the image stream entirely
      await _controller!.stopImageStream();
      setState(() => _paused = true);
    }
  }

  // Track whether we were already manually paused before navigating away
  bool _wasPausedBeforeNav = false;

  void _pauseForNavigation() {
    if (_controller == null) return;
    _wasPausedBeforeNav = _paused;
    if (!_paused) {
      _controller!.stopImageStream();
      setState(() => _paused = true);
    }
  }

  void _resumeAfterNavigation() {
    if (_controller == null || !mounted) return;
    // Only resume if the user hadn't manually paused before navigating
    if (!_wasPausedBeforeNav) {
      _startImageStream(_controller!);
      setState(() => _paused = false);
    }
  }

  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    if (_isFrontCamera) return; // no flash on most front cams

    HapticFeedback.lightImpact();
    _flashOn = !_flashOn;
    try {
      await _controller!.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off,
      );
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
    _tts.stop();
    serverIpNotifier.removeListener(_onServerIpChanged);
    _controller?.dispose();
    _mpChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody(context));
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
                  maxHeight:
                      240, // enough room for sentence + divider + hand-detected row
                ),
                child: _LiveTranslationCard(
                  bestGuess: _bestGuess,
                  handsCount: _handsCount,
                  paused: _paused,
                  generatedSentence: _generatedSentence,
                  generating: _generatingApi,
                ),
              ),
            ),
          ),
        ),

        // Bottom floating bar + secondary controls
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // White pill bar: History | Speech On | Settings
                  _BottomControlBar(
                    onPause: _pauseForNavigation,
                    onResume: _resumeAfterNavigation,
                    speechOn: _speechOn,
                    onSpeechToggle: () {
                      HapticFeedback.lightImpact();
                      setState(() => _speechOn = !_speechOn);
                      if (!_speechOn) _tts.stop();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Secondary row: Back (switch camera) + Off (flash)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SecondaryButton(
                        icon: Icons.cameraswitch,
                        label: 'Back',
                        onPressed: _switchCamera,
                      ),
                      const SizedBox(width: 16),
                      _SecondaryButton(
                        icon: _paused ? Icons.play_arrow : Icons.pause,
                        label: _paused ? 'Resume' : 'Pause',
                        onPressed: _togglePause,
                      ),
                      const SizedBox(width: 16),
                      _SecondaryButton(
                        icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                        label: _flashOn ? 'On' : 'Off',
                        onPressed: _isFrontCamera ? null : _toggleFlash,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Zoom selector (left edge, vertically centered)
        if (!_isFrontCamera)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ZoomSelector(
                currentZoom: _currentZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onZoomSelected: _setZoom,
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
  final String bestGuess;
  final int handsCount;
  final bool paused;
  final String generatedSentence;
  final bool generating;

  const _LiveTranslationCard({
    required this.bestGuess,
    required this.handsCount,
    this.paused = false,
    this.generatedSentence = '',
    this.generating = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasHands = handsCount > 0;
    // A real word is anything other than the default placeholder
    final hasWord =
        bestGuess.isNotEmpty && bestGuess != 'no hands detected';
    final display = hasWord ? bestGuess : 'Hello, how can I help you today?';

    final bool hasSentence = generatedSentence.isNotEmpty;

    // Status logic: paused > generating > translating (got a word) > hands visible > idle
    final Color statusDotColor;
    final String statusLabel;
    final bool animateDots;
    if (paused) {
      statusDotColor = Colors.orange;
      statusLabel = 'Paused';
      animateDots = false;
    } else if (generating) {
      statusDotColor = Colors.amber;
      statusLabel = 'Generating';
      animateDots = true;
    } else if (hasWord) {
      statusDotColor = Colors.green;
      statusLabel = 'Translating';
      animateDots = true;
    } else if (hasHands) {
      statusDotColor = _kPrimaryBlue;
      statusLabel = 'Processing';
      animateDots = true;
    } else {
      statusDotColor = Colors.grey.shade400;
      statusLabel = 'Waiting';
      animateDots = true;
    }

    final cardColor = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
                'LIVE TRANSLATION',
                style: TextStyle(
                  color: _kPrimaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: offlineModeNotifier,
                builder: (context, offline, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: offline ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      offline ? 'OFFLINE' : 'ONLINE',
                      style: TextStyle(
                        color: offline ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusDotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              if (animateDots)
                _AnimatedStatusText(
                  label: statusLabel,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                )
              else
                Text(
                  statusLabel,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // When a generated sentence exists, show current sign as a small label
          if (hasSentence && hasWord) ...[
            Text(
              'Current sign: ${bestGuess.toUpperCase()}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Main display: generated sentence (if available) or bestGuess
          if (generating)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimaryBlue),
                ),
                const SizedBox(width: 10),
                Text(
                  'Generating sentence...',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            )
          else
            Text(
              hasSentence ? generatedSentence : display,
              style: TextStyle(
                color: onSurface,
                fontSize: hasSentence ? 22 : 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          const SizedBox(height: 10),

          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasWord) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hand detected',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 1.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'TRANSLATING',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ] else if (hasHands) ...[
                Icon(Icons.check_circle, color: _kPrimaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hand detected',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kPrimaryBlue, width: 1.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'DETECTED',
                    style: TextStyle(
                      color: _kPrimaryBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ] else ...[
                Icon(Icons.front_hand_outlined,
                    color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Show your hands to start',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
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
    final options = <double>[
      0.5,
      1.0,
      2.0,
    ].where((z) => z >= minZoom && z <= maxZoom).toList();

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

class _BottomControlBar extends StatelessWidget {
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final bool speechOn;
  final VoidCallback onSpeechToggle;

  const _BottomControlBar({
    this.onPause,
    this.onResume,
    required this.speechOn,
    required this.onSpeechToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // History
          _BarIconLabel(
            icon: Icons.history,
            label: 'History',
            onTap: () async {
              HapticFeedback.lightImpact();
              onPause?.call();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
              onResume?.call();
            },
          ),
          const SizedBox(width: 20),

          // Speech toggle pill button
          GestureDetector(
            onTap: onSpeechToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: speechOn ? _kPrimaryBlue : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    speechOn ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    speechOn ? 'SPEECH ON' : 'SPEECH OFF',
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
          const SizedBox(width: 20),

          // Settings
          _BarIconLabel(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () async {
              HapticFeedback.lightImpact();
              onPause?.call();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              onResume?.call();
            },
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AnimatedStatusText — cycles dots: "Label.", "Label..", "Label..."
// ---------------------------------------------------------------------------

class _AnimatedStatusText extends StatefulWidget {
  final String label;
  final TextStyle style;

  const _AnimatedStatusText({required this.label, required this.style});

  @override
  State<_AnimatedStatusText> createState() => _AnimatedStatusTextState();
}

class _AnimatedStatusTextState extends State<_AnimatedStatusText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final next = (_controller.value * 3).floor() + 1;
    if (next != _dotCount) {
      setState(() => _dotCount = next);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    final padded = dots.padRight(3);
    return Text(
      '${widget.label}$padded',
      style: widget.style,
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
    final iconTextColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: iconTextColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: iconTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
