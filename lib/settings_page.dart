import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart' show themeNotifier, serverIpNotifier, offlineModeNotifier, speechOnNotifier, speechSpeedNotifier;
import 'test_page.dart';
import 'speech_page.dart';
import 'Routerdemo.dart';

const Color _kPrimaryBlue = Color(0xFF3B5BFE);

// ---------------------------------------------------------------------------
// SettingsPage — full-screen settings with scrollable sections
// ---------------------------------------------------------------------------

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Translation
  String _outputLanguage = 'English';
  double _confidenceThreshold = 0.80;
  bool _continuousMode = true;

  // Camera
  bool _useFrontCamera = false;
  String _resolution = 'Medium';

  // Server
  late final TextEditingController _serverIpController;

  // Appearance
  double _textSize = 1.0; // 0.0 = Small, 1.0 = Medium, 2.0 = Large

  @override
  void initState() {
    super.initState();
    _serverIpController = TextEditingController(text: serverIpNotifier.value);
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    super.dispose();
  }

  static const List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Japanese',
    'Korean',
    'Chinese',
    'Arabic',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildProSection('Translation', [
            _buildLanguageDropdown(),
            _buildDivider(),
            _buildConfidenceSlider(),
            _buildDivider(),
            _buildAutoDetectToggle(),
          ]),

          _buildSectionHeader('Speech'),
          _buildCard([
            _buildAutoSpeakToggle(),
            _buildDivider(),
            _buildSpeechSpeedSlider(),
          ]),

          _buildSectionHeader('Appearance'),
          _buildCard([
            _buildDarkModeToggle(),
            _buildDivider(),
            _buildTextSizeSlider(),
          ]),

          _buildProSection('Camera', [
            _buildCameraToggle(),
            _buildDivider(),
            _buildResolutionSelector(),
          ]),

          _buildSectionHeader('Server'),
          _buildCard([
            ValueListenableBuilder<bool>(
              valueListenable: offlineModeNotifier,
              builder: (context, offline, _) {
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Offline Mode'),
                      subtitle: const Text('Uses local templates (no server needed)'),
                      value: offline,
                      activeTrackColor: _kPrimaryBlue,
                      onChanged: (value) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          offlineModeNotifier.value = value;
                        });
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: TextField(
                        controller: _serverIpController,
                        enabled: !offline,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Ollama Server IP',
                          hintText: '10.40.3.166',
                          prefixText: 'http://',
                          suffixText: ':8000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          serverIpNotifier.value = value.trim();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ]),

          _buildSectionHeader('Developer'),
          _buildCard([
            _buildActionTile('Test API', Icons.science_outlined, () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestPage()),
              );
            }),
            _buildDivider(),
            _buildActionTile('Text to Speech', Icons.record_voice_over, () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SpeechPage()),
              );
            }),
            _buildDivider(),
            _buildActionTile('Router Demo', Icons.route, () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RouterDemo()),
              );
            }),
          ]),

          _buildSectionHeader('About'),
          _buildCard([
            _buildStaticTile('App Version', '1.0.0'),
            _buildDivider(),
            _buildActionTile('Send Feedback', Icons.feedback_outlined, () {
              HapticFeedback.lightImpact();
              _showStubSnackbar('Feedback feature coming soon');
            }),
            _buildDivider(),
            _buildActionTile('Privacy Policy', Icons.privacy_tip_outlined, () {
              HapticFeedback.lightImpact();
              _showStubSnackbar('Privacy policy coming soon');
            }),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card container
  // ---------------------------------------------------------------------------

  Widget _buildCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  // ---------------------------------------------------------------------------
  // Pro section — blurred card with lock overlay
  // ---------------------------------------------------------------------------

  Widget _buildProSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kPrimaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 10, color: _kPrimaryBlue),
                    SizedBox(width: 3),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: _kPrimaryBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              // The actual card content (rendered but blurred)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(children: children),
              ),
              // Blur + lock overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 18, color: _kPrimaryBlue),
                              SizedBox(width: 8),
                              Text(
                                'Upgrade to Pro',
                                style: TextStyle(
                                  color: _kPrimaryBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Translation section
  // ---------------------------------------------------------------------------

  Widget _buildLanguageDropdown() {
    return ListTile(
      title: const Text('Output Language'),
      trailing: DropdownButton<String>(
        value: _outputLanguage,
        underline: const SizedBox(),
        onChanged: (value) {
          if (value != null) {
            HapticFeedback.selectionClick();
            setState(() => _outputLanguage = value);
          }
        },
        items: _languages
            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
            .toList(),
      ),
    );
  }

  Widget _buildConfidenceSlider() {
    return ListTile(
      title: const Text('Confidence Threshold'),
      subtitle: Slider(
        value: _confidenceThreshold,
        min: 0.50,
        max: 1.00,
        divisions: 10,
        activeColor: _kPrimaryBlue,
        label: '${(_confidenceThreshold * 100).round()}%',
        onChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => _confidenceThreshold = value);
        },
      ),
      trailing: Text(
        '${(_confidenceThreshold * 100).round()}%',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAutoDetectToggle() {
    return SwitchListTile(
      title: const Text('Auto-detect Mode'),
      subtitle: Text(_continuousMode ? 'Continuous' : 'Tap to translate'),
      value: _continuousMode,
      activeTrackColor: _kPrimaryBlue,
      onChanged: (value) {
        HapticFeedback.lightImpact();
        setState(() => _continuousMode = value);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Speech section
  // ---------------------------------------------------------------------------

  Widget _buildAutoSpeakToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: speechOnNotifier,
      builder: (context, speechOn, _) {
        return SwitchListTile(
          title: const Text('Auto-speak'),
          subtitle: const Text('Read translations aloud automatically'),
          value: speechOn,
          activeTrackColor: _kPrimaryBlue,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            speechOnNotifier.value = value;
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildSpeechSpeedSlider() {
    return ValueListenableBuilder<double>(
      valueListenable: speechSpeedNotifier,
      builder: (context, speed, _) {
        return ListTile(
          title: const Text('Speech Speed'),
          subtitle: Slider(
            value: speed,
            min: 0.1,
            max: 0.9,
            divisions: 8,
            activeColor: _kPrimaryBlue,
            label: _speedLabel(speed),
            onChanged: (value) {
              HapticFeedback.selectionClick();
              speechSpeedNotifier.value = value;
            },
          ),
          trailing: Text(
            _speedLabel(speed),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  String _speedLabel(double speed) {
    if (speed <= 0.3) return 'Slow';
    if (speed <= 0.6) return 'Normal';
    return 'Fast';
  }

  // ---------------------------------------------------------------------------
  // Camera section
  // ---------------------------------------------------------------------------

  Widget _buildCameraToggle() {
    return SwitchListTile(
      title: const Text('Default Camera'),
      subtitle: Text(_useFrontCamera ? 'Front' : 'Back'),
      value: _useFrontCamera,
      activeTrackColor: _kPrimaryBlue,
      onChanged: (value) {
        HapticFeedback.lightImpact();
        setState(() => _useFrontCamera = value);
      },
    );
  }

  Widget _buildResolutionSelector() {
    return ListTile(
      title: const Text('Resolution'),
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Low', label: Text('Low')),
          ButtonSegment(value: 'Medium', label: Text('Med')),
          ButtonSegment(value: 'High', label: Text('High')),
        ],
        selected: {_resolution},
        onSelectionChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => _resolution = value.first);
        },
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.black87;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? _kPrimaryBlue
                : Colors.transparent;
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Appearance section
  // ---------------------------------------------------------------------------

  Widget _buildDarkModeToggle() {
    return ListTile(
      title: const Text('Theme'),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {themeNotifier.value},
        onSelectionChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => themeNotifier.value = value.first);
        },
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return Theme.of(context).colorScheme.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? _kPrimaryBlue
                : Colors.transparent;
          }),
        ),
      ),
    );
  }

  Widget _buildTextSizeSlider() {
    final labels = ['Small', 'Medium', 'Large'];
    return ListTile(
      title: const Text('Translation Text Size'),
      subtitle: Slider(
        value: _textSize,
        min: 0.0,
        max: 2.0,
        divisions: 2,
        activeColor: _kPrimaryBlue,
        label: labels[_textSize.round()],
        onChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => _textSize = value);
        },
      ),
      trailing: Text(
        labels[_textSize.round()],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // About section
  // ---------------------------------------------------------------------------

  Widget _buildStaticTile(String title, String value) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon, color: _kPrimaryBlue),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  void _showStubSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
