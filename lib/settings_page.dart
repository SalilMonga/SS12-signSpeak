import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Speech
  bool _autoSpeak = true;
  double _speechSpeed = 1.0;

  // Camera
  bool _useFrontCamera = false;
  String _resolution = 'Medium';

  // Appearance
  bool _darkMode = false;
  double _textSize = 1.0; // 0.0 = Small, 1.0 = Medium, 2.0 = Large

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
      backgroundColor: Colors.grey.shade100,
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
          _buildSectionHeader('Translation'),
          _buildCard([
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

          _buildSectionHeader('Camera'),
          _buildCard([
            _buildCameraToggle(),
            _buildDivider(),
            _buildResolutionSelector(),
          ]),

          _buildSectionHeader('Appearance'),
          _buildCard([
            _buildDarkModeToggle(),
            _buildDivider(),
            _buildTextSizeSlider(),
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
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
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
    return SwitchListTile(
      title: const Text('Auto-speak'),
      subtitle: const Text('Read translations aloud automatically'),
      value: _autoSpeak,
      activeTrackColor: _kPrimaryBlue,
      onChanged: (value) {
        HapticFeedback.lightImpact();
        setState(() => _autoSpeak = value);
      },
    );
  }

  Widget _buildSpeechSpeedSlider() {
    return ListTile(
      title: const Text('Speech Speed'),
      subtitle: Slider(
        value: _speechSpeed,
        min: 0.5,
        max: 2.0,
        divisions: 6,
        activeColor: _kPrimaryBlue,
        label: '${_speechSpeed.toStringAsFixed(1)}x',
        onChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => _speechSpeed = value);
        },
      ),
      trailing: Text(
        '${_speechSpeed.toStringAsFixed(1)}x',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
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
    return SwitchListTile(
      title: const Text('Dark Mode'),
      value: _darkMode,
      activeTrackColor: _kPrimaryBlue,
      onChanged: (value) {
        HapticFeedback.lightImpact();
        setState(() => _darkMode = value);
      },
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
