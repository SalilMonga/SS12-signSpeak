import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _kPrimaryBlue = Color(0xFF3B5BFE);

// ---------------------------------------------------------------------------
// TranslationEntry — model for a single translation record
// ---------------------------------------------------------------------------

class TranslationEntry {
  final String text;
  final DateTime timestamp;
  final double confidence;

  const TranslationEntry({
    required this.text,
    required this.timestamp,
    required this.confidence,
  });
}

// ---------------------------------------------------------------------------
// HistoryPage — scrollable log of past translations
// ---------------------------------------------------------------------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<TranslationEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _buildSampleData();
  }

  List<TranslationEntry> _buildSampleData() {
    final now = DateTime.now();
    return [
      TranslationEntry(
        text: 'Hello, how are you?',
        timestamp: now.subtract(const Duration(minutes: 5)),
        confidence: 0.98,
      ),
      TranslationEntry(
        text: 'Thank you very much',
        timestamp: now.subtract(const Duration(minutes: 22)),
        confidence: 0.95,
      ),
      TranslationEntry(
        text: 'My name is...',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 10)),
        confidence: 0.87,
      ),
      TranslationEntry(
        text: 'Nice to meet you',
        timestamp: now.subtract(const Duration(hours: 2)),
        confidence: 0.92,
      ),
      TranslationEntry(
        text: 'Good morning',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        confidence: 0.96,
      ),
      TranslationEntry(
        text: 'Please help me',
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        confidence: 0.89,
      ),
      TranslationEntry(
        text: 'Where is the bathroom?',
        timestamp: now.subtract(const Duration(days: 2, hours: 1)),
        confidence: 0.78,
      ),
      TranslationEntry(
        text: 'I love you',
        timestamp: now.subtract(const Duration(days: 2, hours: 4)),
        confidence: 0.99,
      ),
    ];
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    setState(() => _entries.clear());
  }

  void _deleteEntry(int index) {
    HapticFeedback.lightImpact();
    setState(() => _entries.removeAt(index));
  }

  void _copyToClipboard(String text) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: _kPrimaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _entries.isEmpty ? _buildEmptyState() : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No translations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your translation history will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = _groupByDate(_entries);
    final List<Widget> children = [];

    for (final group in grouped.entries) {
      children.add(_buildDateHeader(group.key));
      for (int i = 0; i < group.value.length; i++) {
        final entry = group.value[i];
        final globalIndex = _entries.indexOf(entry);
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _HistoryCard(
              entry: entry,
              onTap: () => _copyToClipboard(entry.text),
              onDismissed: () => _deleteEntry(globalIndex),
            ),
          ),
        );
      }
    }

    children.add(const SizedBox(height: 24));

    return ListView(children: children);
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Map<String, List<TranslationEntry>> _groupByDate(
    List<TranslationEntry> entries,
  ) {
    final Map<String, List<TranslationEntry>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final entry in entries) {
      final entryDate = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );

      String label;
      if (entryDate == today) {
        label = 'Today';
      } else if (entryDate == yesterday) {
        label = 'Yesterday';
      } else {
        label =
            '${entryDate.month}/${entryDate.day}/${entryDate.year}';
      }

      groups.putIfAbsent(label, () => []).add(entry);
    }
    return groups;
  }
}

// ---------------------------------------------------------------------------
// _HistoryCard — single translation entry card
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  final TranslationEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _HistoryCard({
    required this.entry,
    required this.onTap,
    required this.onDismissed,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${entry.text}_${entry.timestamp.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatTime(entry.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kPrimaryBlue, width: 1.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(entry.confidence * 100).round()}% CONFIDENCE',
                      style: const TextStyle(
                        color: _kPrimaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
