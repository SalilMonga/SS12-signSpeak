import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RouterDemo extends StatefulWidget {
  const RouterDemo({super.key});

  @override
  State<RouterDemo> createState() => _RouterDemoState();
}

class _RouterDemoState extends State<RouterDemo> {
  static const _channel = MethodChannel('asl_router');

  bool _initialized = false;
  String _output = '';

  final TextEditingController _controller =
      TextEditingController(text: 'APPLE GET WANT');

  @override
  void initState() {
    super.initState();
    _initTemplates();
  }

  Future<void> _initTemplates() async {
    // Load JSON from Flutter assets
    final jsonStr = await rootBundle.loadString('assets/templates.json');

    // Validate JSON shape
    final decoded = json.decode(jsonStr);
    if (decoded is! Map) {
      throw Exception('templates.json must be a JSON object of intentKey -> [templates]');
    }

    // Send templates to Swift
    await _channel.invokeMethod('initTemplates', {'templatesJson': jsonStr});

    setState(() => _initialized = true);
    debugPrint('Templates initialized');
  }

  List<String> _wordsFromTextbox() {
    return _controller.text
        .trim()
        .split(RegExp(r'\s+')) // split on any whitespace
        .where((w) => w.isNotEmpty)
        .map((w) => w.toUpperCase())
        .toList();
  }

  Future<void> _runRouter() async {
    final words = _wordsFromTextbox();
    debugPrint('Sending words: $words');

    final sentence = await _channel.invokeMethod<String>(
      'routeWords',
      {'words': words},
    );

    setState(() => _output = sentence ?? '(null)');
    debugPrint('Final sentence (Flutter): $_output');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASL Router Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_initialized ? 'Templates ready' : 'Loading templates...'),
            const SizedBox(height: 12),

            TextField(
              controller: _controller,
              enabled: _initialized,
              decoration: const InputDecoration(
                labelText: 'Words (space-separated)',
                hintText: 'e.g. WHERE BATHROOM',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _runRouter(),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _initialized ? _runRouter : null,
              child: const Text('Run'),
            ),

            const SizedBox(height: 12),
            SelectableText(_output),
          ],
        ),
      ),
    );
  }
}