import 'dart:convert';

class ProductFormatter {
  /// Formats raw product string (JSON or plain string) into human-readable text.
  /// Example input: '[{"name":"Paracetamol","qty":2,"price":100}]'
  /// Example output: 'Paracetamol × 2' or 'Paracetamol × 2, Amoxicillin × 1'
  static String format(String? product, {bool singleLine = true}) {
    if (product == null || product.trim().isEmpty) return '';

    final trimmed = product.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final items = decoded.map((e) {
            if (e is Map) {
              final name = e['name'] ?? e['product_name'] ?? 'Product';
              final qty = e['qty'] ?? e['quantity'];
              if (qty != null && (qty as num) > 0) {
                return '$name × $qty';
              }
              return name.toString();
            }
            return e.toString();
          }).where((str) => str.isNotEmpty).toList();

          if (items.isNotEmpty) {
            return items.join(singleLine ? ', ' : '\n');
          }
        } else if (decoded is Map) {
          final name = decoded['name'] ?? decoded['product_name'] ?? 'Product';
          final qty = decoded['qty'] ?? decoded['quantity'];
          if (qty != null && (qty as num) > 0) {
            return '$name × $qty';
          }
          return name.toString();
        }
      } catch (_) {
        final matches = RegExp(r'"name"\s*:\s*"([^"]+)"').allMatches(trimmed);
        if (matches.isNotEmpty) {
          return matches.map((m) => m.group(1)).whereType<String>().join(singleLine ? ', ' : '\n');
        }
        final cleaned = trimmed.replaceAll(RegExp(r'[\[\]\{\}"]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        return cleaned;
      }
    }

    return trimmed;
  }
}
