import 'dart:convert';
import '../settings/csv_settings.dart';

/// Converts CSV data to and from JSON format.
final class CsvToJsonConverter {

  const CsvToJsonConverter({
    this.settings = const CsvSettings(),
    this.headers,
  });
  final CsvSettings settings;
  final List<String>? headers;

  /// Converts CSV rows to JSON string
  String convert(List<List<Object?>> rows, {bool pretty = false}) {
    final maps = _toMaps(rows);
    final encoder = pretty
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return encoder.convert(maps);
  }

  /// Converts CSV rows to list of maps
  List<Map<String, Object?>> toMaps(List<List<Object?>> rows) => _toMaps(rows);

  List<Map<String, Object?>> _toMaps(List<List<Object?>> rows) {
    final effectiveHeaders = headers ?? _generateHeaders(rows);
    return rowsToMaps(rows, effectiveHeaders);
  }

  List<String> _generateHeaders(List<List<Object?>> rows) {
    if (rows.isEmpty) return [];
    final maxColumns = rows.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    return List.generate(maxColumns, (i) => 'column_${i + 1}');
  }

  /// Static method to convert rows to maps with given headers
  static List<Map<String, Object?>> rowsToMaps(
    List<List<Object?>> rows,
    List<String> headers,
  ) {
    return rows.map((row) {
      final map = <String, Object?>{};
      for (var i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length ? row[i] : null;
      }
      return map;
    }).toList();
  }
}

/// Converts JSON data to CSV format
final class JsonToCsvConverter {

  const JsonToCsvConverter({this.settings = const CsvSettings()});
  final CsvSettings settings;

  /// Converts JSON string to CSV rows
  (List<String>? headers, List<List<Object?>>) convert(String jsonString) {
    final decoded = json.decode(jsonString);

    return switch (decoded) {
      final List<dynamic> list => _convertList(list),
      final Map<String, dynamic> map => _convertSingleMap(map),
      _ => (null, <List<Object?>>[]),
    };
  }

  (List<String>?, List<List<Object?>>) _convertList(List<dynamic> list) {
    if (list.isEmpty) return (null, []);

    // Check if it's a list of maps
    if (list.first is Map<String, dynamic>) {
      final maps = list.cast<Map<String, dynamic>>();

      // Collect all keys
      final allKeys = <String>{};
      for (final map in maps) {
        allKeys.addAll(map.keys);
      }
      final headers = allKeys.toList();

      final rows = maps.map((map) {
        return headers.map((key) => _convertValue(map[key])).toList();
      }).toList();

      return (headers, rows);
    }

    // List of simple values or nested lists
    if (list.first is List) {
      return (null, list.map((e) => (e as List).map(_convertValue).toList()).toList());
    }

    // Single row of values
    return (null, [list.map(_convertValue).toList()]);
  }

  (List<String>?, List<List<Object?>>) _convertSingleMap(Map<String, dynamic> map) {
    final headers = map.keys.toList();
    final row = headers.map((key) => _convertValue(map[key])).toList();
    return (headers, [row]);
  }

  Object? _convertValue(dynamic value) => switch (value) {
        null => null,
    final String s => s,
        final num n => n,
    final bool b => b.toString(),
    final List l => l.map(_convertValue).join(', '),
    final Map m => json.encode(m),
        _ => value.toString(),
      };
}

/// Extension for JSON conversion on data lists
extension JsonConversionExtension on List<List<Object?>> {
  /// Converts to JSON string
  String toJson({
    List<String>? headers,
    bool pretty = false,
  }) {
    return CsvToJsonConverter(headers: headers).convert(this, pretty: pretty);
  }

  /// Converts to list of maps
  List<Map<String, Object?>> toMaps(List<String> headers) {
    return CsvToJsonConverter.rowsToMaps(this, headers);
  }
}
