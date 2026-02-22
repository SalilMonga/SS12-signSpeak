import 'package:flutter/material.dart';
import 'camera_page.dart';
import 'speech_page.dart';

/// Global notifier so any page (e.g. SettingsPage) can toggle the theme.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Global notifier for the Ollama server IP address.
final ValueNotifier<String> serverIpNotifier = ValueNotifier('10.40.3.166');

/// Global notifier for offline mode (local template router vs Ollama).
final ValueNotifier<bool> offlineModeNotifier = ValueNotifier(false);

//testing audio
Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 runApp(const SignSpeakApp()); //run the app on ios native
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
