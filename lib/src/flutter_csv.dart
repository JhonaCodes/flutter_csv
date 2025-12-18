import 'dart:convert';
import 'dart:typed_data';

import 'settings/csv_settings.dart';
import 'settings/settings_detector.dart';
import 'parser/csv_parser.dart';
import 'writer/csv_writer.dart';
import 'builder/csv_builder.dart';
import 'converter/mcp_converter.dart';
import 'converter/mcp_schema_converter.dart';
import 'builder/csv_document.dart';
import 'sanitizer/csv_sanitizer.dart';
import 'headers/csv_headers.dart';
import 'converter/json_converter.dart';
import 'converter/msgpack_converter.dart';
import 'exporter/csv_exporter.dart';
import 'io/csv_file_handler.dart';

/// Main entry point for flutter_csv library.
///
/// Provides static methods for common CSV operations and factory methods
/// for creating builders and documents.
///
/// Example usage:
/// ```dart
/// // Quick parse
/// final data = FlutterCsv.parse('a,b,c\n1,2,3');
///
/// // Builder pattern
/// final csv = FlutterCsv.builder()
///   ..columns(['Name', 'Age'])
///   ..row(['John', 30])
///   ..build();
///
/// // Quick export
/// final csvString = FlutterCsv.write([['a', 'b'], [1, 2]]);
/// ```
final class FlutterCsv {
  const FlutterCsv._();

  // ============================================================
  // PARSING (Import)
  // ============================================================

  /// Parses a CSV string into a list of rows
  static List<List<dynamic>> parse(
    String csv, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvParser(settings: settings).parse(csv);
  }

  /// Parses a CSV string with auto-detected settings
  static List<List<dynamic>> parseAuto(String csv) {
    const detector = SmartSettingsDetector();
    final result = detector.detect(csv);
    return CsvParser(settings: result.settings).parse(csv);
  }

  /// Parses a CSV string into a CsvDocument
  static CsvDocument parseDocument(
    String csv, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = false,
  }) {
    return CsvDocument.fromCsv(
      csv,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
    );
  }

  /// Parses with auto-detection of headers
  static CsvDocument parseWithAutoHeaders(
    String csv, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final document = CsvDocument.fromCsv(csv, settings: settings);
    final detection = document.detectHeaders();

    if (detection.isHeader && detection.confidence >= 0.7) {
      return document.promoteFirstRowToHeaders();
    }

    return document;
  }

  /// Parses a single CSV row
  static List<dynamic> parseRow(
    String csvRow, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvParser(settings: settings).parseRow(csvRow);
  }

  /// Parses CSV bytes
  static List<List<dynamic>> parseBytes(
    Uint8List bytes, {
    CsvSettings settings = const CsvSettings(),
    Encoding encoding = utf8,
  }) {
    // Handle BOM
    var startIndex = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      startIndex = 3;
    }

    final csv = encoding.decode(bytes.sublist(startIndex));
    return parse(csv, settings: settings);
  }

  // ============================================================
  // WRITING (Export)
  // ============================================================

  /// Converts rows to CSV string
  static String write(
    List<List<Object?>> rows, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvWriter(settings: settings).write(rows);
  }

  /// Converts rows to CSV string with trailing EOL
  static String writeWithTrailingEol(
    List<List<Object?>> rows, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvWriter(settings: settings).writeWithTrailingEol(rows);
  }

  /// Converts a single row to CSV string
  static String writeRow(
    List<Object?> row, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvWriter(settings: settings).writeRow(row);
  }

  /// Converts rows to CSV bytes
  static Uint8List writeBytes(
    List<List<Object?>> rows, {
    CsvSettings settings = const CsvSettings(),
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    final csv = write(rows, settings: settings);
    final contentBytes = encoding.encode(csv);

    if (includeBom && encoding == utf8) {
      return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...contentBytes]);
    }

    return Uint8List.fromList(contentBytes);
  }

  // ============================================================
  // BUILDER
  // ============================================================

  /// Creates a new CSV builder
  static CsvBuilder builder() => CsvBuilder();

  /// Creates a builder with preset settings
  static CsvBuilder builderWithSettings(CsvSettings settings) {
    return CsvBuilder()..settings(settings);
  }

  /// Creates an RFC 4180 compliant builder
  static CsvBuilder rfc4180Builder() {
    return CsvBuilder()..rfc4180();
  }

  /// Creates an Excel-friendly builder
  static CsvBuilder excelBuilder() {
    return CsvBuilder()..excel();
  }

  /// Creates a European CSV builder
  static CsvBuilder europeanBuilder() {
    return CsvBuilder()..european();
  }

  /// Creates a TSV builder
  static CsvBuilder tsvBuilder() {
    return CsvBuilder()..tsv();
  }

  // ============================================================
  // CONVERSION
  // ============================================================

  /// Converts CSV to JSON string
  static String toJson(
    String csv, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = true,
    bool pretty = false,
  }) {
    final document = parseDocument(
      csv,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
    );
    return document.toJson(pretty: pretty);
  }

  /// Converts CSV to list of maps
  static List<Map<String, Object?>> toMaps(
    String csv, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = true,
  }) {
    final document = parseDocument(
      csv,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
    );
    return document.toMaps();
  }

  /// Converts JSON to CSV
  static String fromJson(
    String json, {
    CsvSettings settings = const CsvSettings(),
    bool includeHeaders = true,
  }) {
    final converter = JsonToCsvConverter(settings: settings);
    final (headers, data) = converter.convert(json);

    final builder = CsvBuilder()..settings(settings);

    if (includeHeaders && headers != null) {
      builder.columns(headers);
    }

    builder.rows(data);

    return builder.export();
  }

  /// Converts list of maps to CSV
  static String fromMaps(
    List<Map<String, Object?>> maps, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvDocument.fromMaps(maps, settings: settings).toCsv();
  }

  // ============================================================
  // DETECTION & VALIDATION
  // ============================================================

  /// Detects CSV settings from sample
  static CsvSettings detectSettings(String csvSample) {
    const detector = SmartSettingsDetector();
    return detector.detect(csvSample).settings;
  }

  /// Detects if first row is a header
  static CsvHeaderDetection detectHeaders(
    List<List<Object?>> data, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvHeaderDetector(settings: settings).detect(data);
  }

  /// Sanitizes a value for CSV
  static String sanitize(
    Object? value, {
    CsvSettings settings = const CsvSettings(),
    SanitizeMode mode = SanitizeMode.minimal,
  }) {
    return CsvSanitizer(settings: settings, mode: mode).sanitize(value);
  }

  // ============================================================
  // EXPORT UTILITIES
  // ============================================================

  /// Exports document to specific format
  static ExportResult export(
    CsvDocument document, {
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
  }) {
    return CsvExporter.export(document, format: format, encoding: encoding);
  }

  /// Exports for web download (browser-compatible)
  static ExportResult exportForWeb(
    CsvDocument document, {
    CsvExportFormat format = CsvExportFormat.csv,
  }) {
    return CsvExporter.exportForWeb(document, format: format);
  }

  /// Exports in chunks for large files
  static Iterable<String> exportInChunks(
    CsvDocument document, {
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
  }) {
    return CsvExporter.exportInChunks(
      document,
      chunkSize: chunkSize,
      format: format,
    );
  }

  // ============================================================
  // HEADER UTILITIES
  // ============================================================

  /// Generates default headers
  static List<String> generateHeaders(int count, {String prefix = 'Column'}) {
    return CsvHeaders.generate(count, prefix: prefix);
  }

  /// Normalizes headers
  static List<String> normalizeHeaders(List<String> headers) {
    return CsvHeaders.normalize(headers);
  }

  /// Makes headers unique
  static List<String> uniqueHeaders(List<String> headers) {
    return CsvHeaders.makeUnique(headers);
  }

  // ============================================================
  // MESSAGEPACK CONVERSION
  // ============================================================

  /// Converts CSV to MessagePack bytes
  static Uint8List toMsgPack(
    String csv, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = true,
  }) {
    final document = parseDocument(
      csv,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
    );
    final converter = CsvToMsgPackConverter(headers: document.headers);
    return converter.convertWithMetadata(document.data);
  }

  /// Converts MessagePack bytes to CSV string
  static String fromMsgPack(
    Uint8List bytes, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final converter = MsgPackToCsvConverter(settings: settings);
    final (headers, rows) = converter.convert(bytes);

    final document = CsvDocument(
      settings: settings,
      headers: headers,
      data: rows,
    );

    return document.toCsv();
  }

  /// Converts MessagePack bytes to CsvDocument
  static CsvDocument parseMsgPack(
    Uint8List bytes, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final converter = MsgPackToCsvConverter(settings: settings);
    final (headers, rows) = converter.convert(bytes);

    return CsvDocument(
      settings: settings,
      headers: headers,
      data: rows,
    );
  }

  /// Converts rows to MessagePack bytes
  static Uint8List rowsToMsgPack(
    List<List<Object?>> rows, {
    List<String>? headers,
  }) {
    final converter = CsvToMsgPackConverter(headers: headers);
    return converter.convertWithMetadata(rows);
  }

  // ============================================================
  // MCP CONVERSION
  // ============================================================

  /// Converts CSV string to Model Context Protocol (MCP) JSON format.
  ///
  /// Wraps the CSV content in a structure compatible with MCP TextResource:
  /// `{"mimeType": "text/csv", "text": "..."}`
  static String toMcp(String csvContent, {String? uri, String? name}) {
    return const McpConverter().toMcp(csvContent, uri: uri, name: name);
  }

  /// Extracts CSV content from Model Context Protocol (MCP) JSON format.
  ///
  /// Supports unwrapping from simple TextResource or List of resources.
  static String fromMcp(String mcpJson) {
    return const McpConverter().fromMcp(mcpJson);
  }

  /// Converts CSV string to Model Context Protocol (MCP) Map structure.
  static Map<String, dynamic> toMcpMap(String csvContent,
      {String? uri, String? name}) {
    return const McpConverter().toMcpMap(csvContent, uri: uri, name: name);
  }

  // ============================================================
  // MCP SCHEMA CONVERSION
  // ============================================================

  /// Converts CSV to MCP Tools definition (List of Tools)
  static List<Map<String, dynamic>> convertMcpTools(
    String csv, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final doc = parseDocument(csv, settings: settings, firstRowIsHeader: true);
    return const McpSchemaConverter().convertTools(doc);
  }

  /// Converts CSV to MCP Resources definition (List of Resources)
  static List<Map<String, dynamic>> convertMcpResources(
    String csv, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final doc = parseDocument(csv, settings: settings, firstRowIsHeader: true);
    return const McpSchemaConverter().convertResources(doc);
  }

  /// Converts CSV to MCP Prompts definition (List of Prompts)
  static List<Map<String, dynamic>> convertMcpPrompts(
    String csv, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final doc = parseDocument(csv, settings: settings, firstRowIsHeader: true);
    return const McpSchemaConverter().convertPrompts(doc);
  }

  // ============================================================
  // FILE I/O
  // ============================================================

  /// Saves a CsvDocument to a file
  static Future<FileOperationResult> saveToFile(
    CsvDocument document,
    String filePath, {
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    return CsvFileHandler.save(
      document,
      filePath,
      format: format,
      encoding: encoding,
      includeBom: includeBom,
    );
  }

  /// Saves a CsvDocument to a file synchronously
  static FileOperationResult saveToFileSync(
    CsvDocument document,
    String filePath, {
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    return CsvFileHandler.saveSync(
      document,
      filePath,
      format: format,
      encoding: encoding,
      includeBom: includeBom,
    );
  }

  /// Saves CSV rows directly to a file
  static Future<FileOperationResult> saveRowsToFile(
    List<List<Object?>> rows,
    String filePath, {
    List<String>? headers,
    CsvSettings settings = const CsvSettings(),
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
  }) {
    return CsvFileHandler.saveRows(
      rows,
      filePath,
      headers: headers,
      settings: settings,
      format: format,
      encoding: encoding,
    );
  }

  /// Loads a CSV file into a CsvDocument
  static Future<CsvDocument> loadFromFile(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = false,
    Encoding encoding = utf8,
  }) {
    return CsvFileHandler.load(
      filePath,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
      encoding: encoding,
    );
  }

  /// Loads a CSV file synchronously
  static CsvDocument loadFromFileSync(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = false,
    Encoding encoding = utf8,
  }) {
    return CsvFileHandler.loadSync(
      filePath,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
      encoding: encoding,
    );
  }

  /// Loads a MessagePack file into a CsvDocument
  static Future<CsvDocument> loadMsgPackFile(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
  }) {
    return CsvFileHandler.loadMsgPack(filePath, settings: settings);
  }

  /// Saves large CSV using streaming (for very large files)
  static Future<FileOperationResult> saveStreaming(
    CsvDocument document,
    String filePath, {
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
  }) {
    return CsvFileHandler.saveStreaming(
      document,
      filePath,
      chunkSize: chunkSize,
      format: format,
      encoding: encoding,
    );
  }

  /// Reads a CSV file line by line (for very large files)
  static Stream<List<String>> readFileLines(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
    Encoding encoding = utf8,
  }) {
    return CsvFileHandler.readLines(
      filePath,
      settings: settings,
      encoding: encoding,
    );
  }
}
