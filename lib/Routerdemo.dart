import 'package:flutter/material.dart';
import 'offline_sentence_service.dart';

class RouterDemo extends StatefulWidget {
  const RouterDemo({super.key});

  @override
  State<RouterDemo> createState() => _RouterDemoState();
}

class _RouterDemoState extends State<RouterDemo> {
  final OfflineSentenceService _service = OfflineSentenceService();
  String _output = '';

  final TextEditingController _controller =
      TextEditingController(text: 'APPLE GET WANT');

  @override
  void initState() {
    super.initState();
    _service.init().then((_) {
      if (mounted) setState(() {});
      debugPrint('Templates initialized (Dart)');
    });
  }

  void _tokenizer() {
    final tokens = _controller.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toUpperCase())
        .toList();

    final sentence = _service.generate(tokens);
    setState(() => _output = sentence);
    debugPrint('sentence=$sentence');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _service.isReady;
    return Scaffold(
      appBar: AppBar(title: const Text('ASL Router Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ready ? 'Templates ready' : 'Loading templates...'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: ready,
              decoration: const InputDecoration(
                labelText: 'Words (space-separated)',
                hintText: 'e.g. WHERE BATHROOM',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _tokenizer(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: ready ? _tokenizer : null,
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
