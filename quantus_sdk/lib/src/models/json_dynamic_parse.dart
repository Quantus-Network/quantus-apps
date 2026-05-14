import 'dart:convert';

/// Parses values produced by APIs that sometimes nest objects and sometimes
/// JSON-encode them as strings (e.g. FCM [RemoteMessage.data]).
Map<String, dynamic>? jsonMapOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw FormatException('JSON string must decode to an object, got ${decoded.runtimeType}');
  }
  throw FormatException('Expected Map or JSON object string, got ${value.runtimeType}');
}

Map<String, dynamic> jsonMapRequired(dynamic value, String fieldName) {
  final m = jsonMapOrNull(value);
  if (m == null) {
    throw FormatException('Missing or empty map for $fieldName');
  }
  return m;
}

BigInt bigIntFromJson(dynamic value) {
  if (value is BigInt) return value;
  if (value is int) return BigInt.from(value);
  if (value is String) return BigInt.parse(value);
  throw FormatException('Cannot parse BigInt from ${value.runtimeType}: $value');
}

DateTime dateTimeFromJson(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Cannot parse DateTime from ${value.runtimeType}: $value');
}

String stringFromJson(dynamic value) {
  if (value is String) return value;
  throw FormatException('Expected String, got ${value.runtimeType}: $value');
}

/// Resolves `{"id":"..."}`, a JSON string of that object, or a bare address
/// string.
String nestedAccountId(dynamic holder) {
  if (holder == null) return '';
  if (holder is String) {
    final s = holder.trim();
    if (s.startsWith('{')) {
      final m = jsonMapOrNull(s);
      final id = m?['id'];
      if (id is String) return id;
      if (id != null) return id.toString();
      return '';
    }
    return s;
  }
  final m = jsonMapOrNull(holder);
  if (m != null) {
    final id = m['id'];
    if (id is String) return id;
    if (id != null) return id.toString();
  }
  return '';
}

String? optionalExtrinsicHash(Map<String, dynamic> json) {
  final nested = jsonMapOrNull(json['extrinsic'])?['id'];
  if (nested is String) return nested;
  final direct = json['extrinsicHash'];
  if (direct is String) return direct;
  return null;
}

int blockHeightFromJsonMap(Map<String, dynamic>? block) {
  if (block == null) return 0;
  final h = block['height'];
  if (h == null) return 0;
  if (h is int) return h;
  if (h is num) return h.toInt();
  if (h is String) return int.parse(h);
  throw FormatException('Invalid block height: $h (${h.runtimeType})');
}

String blockHashFromJsonMap(Map<String, dynamic>? block) {
  if (block == null) return '';
  final hash = block['hash'];
  if (hash == null) return '';
  if (hash is String) return hash;
  return hash.toString();
}
