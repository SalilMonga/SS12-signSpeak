import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'main.dart' show sentenceHistory, SentenceRecord, serverIpNotifier, offlineModeNotifier;

const Color _kPrimaryBlue = Color(0xFF3B5BFE);

// ---------------------------------------------------------------------------
// HistoryPage — scrollable log of past generated sentences (max 30)
// ---------------------------------------------------------------------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<SentenceRecord> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List.of(sentenceHistory.entries);
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    sentenceHistory.clear();
    setState(() => _entries.clear());
  }

  void _deleteEntry(int index) {
    HapticFeedback.lightImpact();
    sentenceHistory.removeAt(index);
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

  void _showSummary() {
    HapticFeedback.lightImpact();
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    // Entries are most-recent-first; reverse so summary reads chronologically
    final recent = _entries
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList()
        .reversed
        .toList();

    if (recent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No translations in the last 5 minutes'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final sentences = recent.map((e) => e.text).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _SummarySheet(
          sentences: sentences,
          onCopy: (text) {
            _copyToClipboard(text);
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: _entries.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showSummary,
              backgroundColor: _kPrimaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.summarize),
              label: const Text(
                'Summarize',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
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
              onCopy: () => _copyToClipboard(entry.text),
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

  Map<String, List<SentenceRecord>> _groupByDate(
    List<SentenceRecord> entries,
  ) {
    final Map<String, List<SentenceRecord>> groups = {};
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
// _HistoryCard — single sentence entry card with copy button
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  final SentenceRecord entry;
  final VoidCallback onCopy;
  final VoidCallback onDismissed;

  const _HistoryCard({
    required this.entry,
    required this.onCopy,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: entry.offline
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.offline ? 'OFFLINE' : 'ONLINE',
                    style: TextStyle(
                      color: entry.offline ? Colors.orange : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kPrimaryBlue, width: 1.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 14, color: _kPrimaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'COPY',
                          style: TextStyle(
                            color: _kPrimaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SummarySheet — bottom sheet that calls Ollama to summarize recent sentences
// ---------------------------------------------------------------------------

class _SummarySheet extends StatefulWidget {
  final List<String> sentences;
  final ValueChanged<String> onCopy;

  const _SummarySheet({required this.sentences, required this.onCopy});

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  String _summary = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    if (offlineModeNotifier.value) {
      // Offline fallback: just join the sentences
      setState(() {
        _summary = widget.sentences.join('\n');
        _loading = false;
      });
      return;
    }

    try {
      final api = ApiService(baseUrl: 'http://${serverIpNotifier.value}:8000');
      final result = await api.summarizeSentences(widget.sentences);
      if (!mounted) return;
      setState(() {
        _summary = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Fallback to plain join on error
      setState(() {
        _summary = widget.sentences.join('\n');
        _error = 'Could not reach server — showing raw sentences';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'RECENT SUMMARY',
                  style: TextStyle(
                    color: _kPrimaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.sentences.length} sentence${widget.sentences.length == 1 ? '' : 's'} (last 5 min)',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kPrimaryBlue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Summarizing with Ollama...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : SelectableText(
                      _summary,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () => widget.onCopy(_summary),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text(
                  'COPY SUMMARY',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
