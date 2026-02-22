import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

const Color _kPrimaryBlue = Color(0xFF3B5BFE);
// SpeechPage will allow user to type any text and speak it with flutter_tts
// Pipeline-ready: pass translatedText from Ollama to pre-fill the field.

class SpeechPage extends StatefulWidget {
  /// Pre-fills the text field — pass the Ollama sentence here when available.
  final String translatedText;

  const SpeechPage({super.key, this.translatedText = ''}); // constructor with optional translatedText parameter to pass a text value to field 

  @override
  State<SpeechPage> createState() => _SpeechPageState(); // create state for the speech page
}

class _SpeechPageState extends State<SpeechPage> { 
  late final FlutterTts _tts; 
  late final TextEditingController _textController; 
  bool _isSpeaking = false; 
  double _speechRate = 0.5; // iOS range: 0.0 (slow) – 1.0 (fast), 0.5 = normal

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.translatedText);
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();

      //using a try-catch to debug that audio is sucessful without the ringer interfering.
    try{
      await _tts.setSharedInstance(true); // ensure TTS continues in background and isn't affected by ring/silent switch
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker, // route audio to speaker by default
          IosTextToSpeechAudioCategoryOptions.allowBluetooth, // allow routing to Bluetooth devices 
        ], 
        IosTextToSpeechAudioMode.defaultMode,
      );
      print("Audio category set successfully"); 
    } catch(e){
      print(" Audio error:$e");
    }

//problem: use playback audio so ring configuration doesn't affect it 
    await _tts.setSharedInstance(true); 
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
    [ IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowAirPlay,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
    ],
    IosTextToSpeechAudioMode.voicePrompt,
    );

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _toggleSpeech() async {
    HapticFeedback.mediumImpact();
    if (_isSpeaking) {
      await _tts.stop();
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus(); // dismiss keyboard before speaking
    await _tts.awaitSynthCompletion(true);
    await _tts.speak(text);
  }

  Future<void> _onRateChanged(double value) async {
    setState(() => _speechRate = value);
    await _tts.setSpeechRate(value);
  }

  @override
  void dispose() {  
    _tts.stop(); // stop tts
    _textController.dispose(); // "flush" text controller
    super.dispose(); //dispose of the state 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( //
        title: const Text(
          'Text to Speech', // page title 
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: GestureDetector( // detects place of taps to dismiss keyboard when tapping outside of the text field.
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // text input card 
              _TextInputCard(
                controller: _textController,
                isSpeaking: _isSpeaking,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 28),

              // speak button
              _SpeakButton(
                isSpeaking: _isSpeaking,
                enabled: _textController.text.trim().isNotEmpty,
                onTap: _toggleSpeech,
              ),

              const SizedBox(height: 36),

              //speech speed control 
              _SpeedControl(
                value: _speechRate,
                onChanged: _onRateChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Text input card for text to be spoken
class _TextInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSpeaking;
  final ValueChanged<String> onChanged; //enable speak buttton when text is not empty 

  const _TextInputCard({ //constructor with required parameters
    required this.controller,
    required this.isSpeaking,
    required this.onChanged,
  });

  @override
  //UI textcard design
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'TEXT',
                style: TextStyle(
                  color: _kPrimaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (isSpeaking) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _kPrimaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Speaking...',
                  style: TextStyle(
                    color: _kPrimaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Editable text field
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 4,
            minLines: 3,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Type something to speak...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
                fontSize: 18,
              ),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

// _SpeakButton big pill button, blue = idle, red = speaking
// Enabled only when there's text to speak, otherwise speak button will be grey 
class _SpeakButton extends StatelessWidget { // made it public to use in main.dart
  final bool isSpeaking; 
  final bool enabled;
  final VoidCallback onTap;

  const _SpeakButton({ //constructor with required parameters
    required this.isSpeaking,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.grey.shade300
              : isSpeaking
                  ? Colors.red.shade400
                  : _kPrimaryBlue,
          borderRadius: BorderRadius.circular(32),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: (isSpeaking ? Colors.red : _kPrimaryBlue)
                        .withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 12),
            Text(
              isSpeaking ? 'STOP' : 'SPEAK',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SpeedControl — slider: Slow / Normal / Fast
// ---------------------------------------------------------------------------
class _SpeedControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SpeedControl({required this.value, required this.onChanged});

  String get _label { // slider for speech speed control 
    if (value <= 0.3) return 'Slow';
    if (value <= 0.6) return 'Normal';
    return 'Fast';
  }

  @override
  //UI design for the speech speed controller
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SPEECH SPEED',
                style: TextStyle(
                  color: _kPrimaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                _label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0.1,
            max: 0.9,
            divisions: 8,
            activeColor: _kPrimaryBlue,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
