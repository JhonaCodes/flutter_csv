import '../settings/csv_settings.dart';
import '../writer/csv_writer.dart';
import '../parser/csv_parser.dart';
import '../converter/json_converter.dart';
import '../headers/csv_headers.dart';

/// Represents a parsed or built CSV document.
///
/// This is the main result type from parsing or building CSV data.
/// Provides methods for export, conversion, and manipulation.
final class CsvDocument {

  /// Creates a document from CSV string
  factory CsvDocument.fromCsv(
    String csv, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = false,
  }) {
    final parser = CsvParser(settings: settings);
    final rows = parser.parse(csv);

    if (rows.isEmpty) {
      return CsvDocument(settings: settings, data: const []);
    }

    if (firstRowIsHeader && rows.isNotEmpty) {
      final headerRow = rows.first.map((e) => e?.toString() ?? '').toList();
      return CsvDocument(
        settings: settings,
        headers: headerRow,
        data: rows.skip(1).toList(),
      );
    }

    return CsvDocument(settings: settings, data: rows);
  }

  const CsvDocument({
    this.settings = const CsvSettings(),
    this.headers,
    required this.data,
  });

  /// Creates a document from list of maps
  factory CsvDocument.fromMaps(
    List<Map<String, Object?>> maps, {
    CsvSettings settings = const CsvSettings(),
  }) {
    if (maps.isEmpty) {
      return CsvDocument(settings: settings, data: const []);
    }

    // Collect all unique keys as headers
    final allKeys = <String>{};
    for (final map in maps) {
      allKeys.addAll(map.keys);
    }
    final headerList = allKeys.toList();

    final dataRows = maps.map((map) {
      return headerList.map((key) => map[key]).toList();
    }).toList();

    return CsvDocument(
      settings: settings,
      headers: headerList,
      data: dataRows,
    );
  }
  /// CSV settings used for this document
  final CsvSettings settings;

  /// Column headers (null if no headers)
  final List<String>? headers;

  /// Data rows (excluding headers)
  final List<List<Object?>> data;

  /// Whether this document has headers
  bool get hasHeaders => headers != null && headers!.isNotEmpty;

  /// Total number of rows (excluding headers)
  int get rowCount => data.length;

  /// Number of columns
  int get columnCount {
    if (hasHeaders) return headers!.length;
    if (data.isEmpty) return 0;
    return data.first.length;
  }

  /// Whether the document is empty
  bool get isEmpty => data.isEmpty;

  /// Whether the document has data
  bool get isNotEmpty => data.isNotEmpty;

  /// Gets a specific row by index
  List<Object?>? getRow(int index) {
    if (index < 0 || index >= data.length) return null;
    return data[index];
  }

  /// Gets a specific cell value
  Object? getCell(int row, int column) {
    if (row < 0 || row >= data.length) return null;
    if (column < 0 || column >= data[row].length) return null;
    return data[row][column];
  }

  /// Gets a cell by header name
  Object? getCellByHeader(int row, String header) {
    if (headers == null) return null;
    final columnIndex = headers!.indexOf(header);
    if (columnIndex < 0) return null;
    return getCell(row, columnIndex);
  }

  /// Gets a column of values
  List<Object?> getColumn(int index) {
    return data.map((row) => index < row.length ? row[index] : null).toList();
  }

  /// Gets a column by header name
  List<Object?> getColumnByHeader(String header) {
    if (headers == null) return [];
    final columnIndex = headers!.indexOf(header);
    if (columnIndex < 0) return [];
    return getColumn(columnIndex);
  }

  /// Exports to CSV string
  String toCsv() {
    final writer = CsvWriter(settings: settings);
    final allRows = <List<Object?>>[];

    if (hasHeaders) {
      allRows.add(headers!);
    }
    allRows.addAll(data);

    return writer.write(allRows);
  }

  /// Exports to CSV string with trailing EOL
  String toCsvWithTrailingEol() {
    final writer = CsvWriter(settings: settings);
    final allRows = <List<Object?>>[];

    if (hasHeaders) {
      allRows.add(headers!);
    }
    allRows.addAll(data);

    return writer.writeWithTrailingEol(allRows);
  }

  /// Converts to list of maps (requires headers)
  List<Map<String, Object?>> toMaps() {
    if (!hasHeaders) {
      throw StateError('Cannot convert to maps without headers');
    }
    return CsvToJsonConverter.rowsToMaps(data, headers!);
  }

  /// Converts to JSON string
  String toJson({bool pretty = false}) {
    return CsvToJsonConverter(
      settings: settings,
      headers: headers,
    ).convert(data, pretty: pretty);
  }

  /// Detects if first row looks like headers
  CsvHeaderDetection detectHeaders() {
    return CsvHeaderDetector(settings: settings).detect(
      hasHeaders ? [headers!, ...data] : data,
    );
  }

  /// Creates a copy with modified properties
  CsvDocument copyWith({
    CsvSettings? settings,
    List<String>? headers,
    List<List<Object?>>? data,
  }) {
    return CsvDocument(
      settings: settings ?? this.settings,
      headers: headers ?? this.headers,
      data: data ?? this.data,
    );
  }

  /// Creates a new document with headers set from first row
  CsvDocument promoteFirstRowToHeaders() {
    if (data.isEmpty) return this;

    return CsvDocument(
      settings: settings,
      headers: data.first.map((e) => e?.toString() ?? '').toList(),
      data: data.skip(1).toList(),
    );
  }

  /// Creates a new document with headers added as first row
  CsvDocument demoteHeadersToFirstRow() {
    if (!hasHeaders) return this;

    return CsvDocument(
      settings: settings,
      headers: null,
      data: [headers!, ...data],
    );
  }

  @override
  String toString() {
    return 'CsvDocument(rows: $rowCount, columns: $columnCount, hasHeaders: $hasHeaders)';
  }
}
