import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class TemplateStore {
  final Map<String, List<String>> templates;

  TemplateStore(this.templates);

  static Future<TemplateStore> loadFromAsset(String path) async {
    final jsonStr = await rootBundle.loadString(path);
    final decoded = json.decode(jsonStr);
    if (decoded is! Map) {
      throw Exception('templates.json must be a JSON object of intentKey -> [templates]');
    }

    final Map<String, List<String>> casted = {};
    decoded.forEach((key, value) {
      if (value is List) {
        casted[key.toString()] = value.map((e) => e.toString()).toList();
      }
    });

    return TemplateStore(casted);
  }

  /// Pick a template with priority:
  /// - if NOUN exists, prefer templates containing {NOUN}
  /// - if PLACE exists, prefer templates containing {PLACE}
  /// - always prefer templates whose placeholders are all fillable
  /// - deterministic: pick the first match (no randomness)
  String pickTemplate(String intentKey, Map<String, String> slots,
      {String fallbackKey = 'unknown'}) {
    final list = templates[intentKey] ?? templates[fallbackKey] ?? const ["Sorry—can you rephrase that?"];

    bool fillable(String t) => _missingPlaceholders(t, slots).isEmpty;

    final viable = list.where(fillable).toList();
    if (viable.isEmpty) return list.first;

    // Priority: NOUN templates first when noun exists
    if (slots.containsKey('NOUN')) {
      final nounFirst = viable.where((t) => t.contains('{NOUN}')).toList();
      if (nounFirst.isNotEmpty) return nounFirst.first;
    }

    // Priority: PLACE templates first when place exists
    if (slots.containsKey('PLACE')) {
      final placeFirst = viable.where((t) => t.contains('{PLACE}')).toList();
      if (placeFirst.isNotEmpty) return placeFirst.first;
    }

    return viable.first;
  }

  static List<String> _missingPlaceholders(String template, Map<String, String> slots) {
    final re = RegExp(r'\{([A-Z_]+)\}');
    final missing = <String>[];
    for (final m in re.allMatches(template)) {
      final key = m.group(1);
      if (key != null && !slots.containsKey(key)) missing.add(key);
    }
    return missing;
  }
}

String renderTemplate(String template, Map<String, String> slots) {
  return template.replaceAllMapped(RegExp(r'\{([A-Z_]+)\}'), (m) {
    final key = m.group(1);
    if (key == null) return m.group(0) ?? '';
    return slots[key] ?? m.group(0) ?? '';
  });
}