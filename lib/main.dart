import 'package:flutter/material.dart';
import 'camera_page.dart';
import 'speech_page.dart';

//testing audio
Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();
 runApp(const SignSpeakApp()); //run the app on ios native 
}

class SignSpeakApp extends StatelessWidget {
  const SignSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignSpeak - ASL Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CameraPage(),
      // const SpeechPage(), // !Need to integrate !
    );
  }
}
