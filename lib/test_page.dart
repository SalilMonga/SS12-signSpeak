import 'package:flutter/material.dart';
import 'api_service.dart';
import 'main.dart' show serverIpNotifier;

const Color _kPrimaryBlue = Color(0xFF3B5BFE);

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late final TextEditingController _ipController;
  final _customWordsController = TextEditingController();
  final _apiService = ApiService();

  String? _result;
  String? _error;
  bool _loading = false;
  List<String> _selectedWords = [];

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: serverIpNotifier.value);
  }

  static const List<List<String>> _presets = [
    ['I', 'WANT', 'APPLE'],
    ['GO', 'YOU', 'STORE'],
    ['HELLO'],
    ['THANK', 'YOU'],
    ['HELP', 'ME', 'PLEASE'],
    ['WHAT', 'YOUR', 'NAME'],
  ];

  Future<void> _send(List<String> words) async {
    if (words.isEmpty) return;

    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'Please enter the server IP address.');
      return;
    }

    _apiService.updateIp(ip);
    serverIpNotifier.value = ip;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _selectedWords = words;
    });

    try {
      final sentence = await _apiService.generateSentence(words);
      if (!mounted) return;
      setState(() {
        _result = sentence;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _sendCustom() {
    final text = _customWordsController.text.trim();
    if (text.isEmpty) return;
    final words = text.split(RegExp(r'[\s,]+')).where((w) => w.isNotEmpty).toList();
    _send(words);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _customWordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Test API'),
        backgroundColor: _kPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server IP field
            _SectionLabel('Server IP'),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '10.0.0.123',
                prefixText: 'http://',
                suffixText: ':8000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Preset word chips
            _SectionLabel('Preset Word Combinations'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((words) {
                return ActionChip(
                  label: Text(
                    words.join(' '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _kPrimaryBlue, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => _send(words),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Custom input
            _SectionLabel('Custom Words'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customWordsController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. I WANT WATER',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendCustom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Send',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Result area
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _kPrimaryBlue),
                ),
              ),

            if (_selectedWords.isNotEmpty && !_loading)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Input: ${_selectedWords.join(', ')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_result != null) ...[
                      const Text(
                        'Generated Sentence:',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kPrimaryBlue,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _result!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Error',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }
}
