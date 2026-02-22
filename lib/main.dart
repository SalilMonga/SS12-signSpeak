import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_page.dart';
import 'speech_page.dart';

/// Global notifier so any page (e.g. SettingsPage) can toggle the theme.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Global notifier for the Ollama server IP address.
final ValueNotifier<String> serverIpNotifier = ValueNotifier('10.40.3.166');

/// Global notifier for offline mode (local template router vs Ollama).
final ValueNotifier<bool> offlineModeNotifier = ValueNotifier(false);

/// Global sentence history (most recent first, max 30, persisted 24h).
final sentenceHistory = SentenceHistory();

class SentenceHistory {
  static const int maxEntries = 30;
  static const String _prefsKey = 'sentence_history';
  static const Duration maxAge = Duration(hours: 24);

  final List<SentenceRecord> _entries = [];

  List<SentenceRecord> get entries => List.unmodifiable(_entries);

  /// Load persisted entries and prune anything older than 24 hours.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    final List<dynamic> decoded = jsonDecode(raw);
    final cutoff = DateTime.now().subtract(maxAge);

    _entries.clear();
    for (final item in decoded) {
      final record = SentenceRecord.fromJson(item as Map<String, dynamic>);
      if (record.timestamp.isAfter(cutoff)) {
        _entries.add(record);
      }
    }
    // Re-save in case we pruned stale entries
    await _save();
  }

  Future<void> add(String text, {bool offline = false}) async {
    _entries.insert(0, SentenceRecord(
      text: text,
      timestamp: DateTime.now(),
      offline: offline,
    ));
    if (_entries.length > maxEntries) _entries.removeLast();
    await _save();
  }

  Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  Future<void> removeAt(int index) async {
    _entries.removeAt(index);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _entries.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(json));
  }
}

class SentenceRecord {
  final String text;
  final DateTime timestamp;
  final bool offline;

  const SentenceRecord({
    required this.text,
    required this.timestamp,
    required this.offline,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'offline': offline,
  };

  factory SentenceRecord.fromJson(Map<String, dynamic> json) => SentenceRecord(
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    offline: json['offline'] as bool? ?? false,
  );
}

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 await sentenceHistory.load(); // restore persisted history (prunes >24h)
 runApp(const SignSpeakApp());
}

class SignSpeakApp extends StatelessWidget {
  const SignSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'SignSpeak - ASL Translator',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: currentMode,
          home: const CameraPage(),
        );
      },
    );
  }
}
