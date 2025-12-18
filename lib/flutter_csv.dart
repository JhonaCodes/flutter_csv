/// A CSV library for Dart/Flutter with builder pattern,
/// import/export capabilities, header detection, JSON and MessagePack conversion.
///
/// ## Features
/// - Builder pattern with fluent API
/// - Import and export CSV files
/// - Auto-detection of delimiters and headers
/// - JSON conversion (CSV ↔ JSON)
/// - MessagePack conversion (CSV ↔ MsgPack)
/// - Multiple format presets (RFC 4180, Excel, European, TSV)
/// - Large file support with chunked processing
/// - File I/O operations
/// - Web-compatible exports
///
/// ## Quick Start
///
/// ### Parsing CSV
/// ```dart
/// // Simple parse
/// final data = FlutterCsv.parse('a,b,c\n1,2,3');
///
/// // With auto-detection
/// final data = FlutterCsv.parseAuto(csvString);
///
/// // As document with headers
/// final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);
/// ```
///
/// ### Building CSV
/// ```dart
/// final builder = FlutterCsv.builder()
///   ..columns(['Name', 'Age', 'City'])
///   ..row(['John', 30, 'NYC'])
///   ..row(['Jane', 25, 'LA']);
/// final doc = builder.build();
///
/// print(doc.toCsv());
/// ```
///
/// ### Converting
/// ```dart
/// // CSV to JSON
/// final json = FlutterCsv.toJson(csvString);
///
/// // JSON to CSV
/// final csv = FlutterCsv.fromJson(jsonString);
///
/// // CSV to MessagePack
/// final msgpack = FlutterCsv.toMsgPack(csvString);
///
/// // MessagePack to CSV
/// final csv = FlutterCsv.fromMsgPack(msgpackBytes);
/// ```
///
/// ### File Operations
/// ```dart
/// // Save to file
/// await doc.saveToFile('data.csv');
///
/// // Load from file
/// final doc = await FlutterCsv.loadFromFile('data.csv');
///
/// // Save as MessagePack
/// await doc.saveToFile('data.msgpack', format: CsvFileFormat.msgpack);
/// ```
///
/// ### Exporting
/// ```dart
/// final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);
///
/// // Export to different formats
/// final result = doc.export(format: CsvExportFormat.excel);
/// print(result.content);
/// print(result.bytes);
/// ```
library flutter_csv;

// Main entry point
export 'src/flutter_csv.dart';

// Settings
export 'src/settings/csv_settings.dart';
export 'src/settings/settings_detector.dart';

// Builder
export 'src/builder/csv_builder.dart';
export 'src/builder/csv_document.dart';

// Parser & Writer
export 'src/parser/csv_parser.dart';
export 'src/writer/csv_writer.dart';

// Sanitizer
export 'src/sanitizer/csv_sanitizer.dart';

// Headers
export 'src/headers/csv_headers.dart';

// Converters
export 'src/converter/json_converter.dart';
export 'src/converter/msgpack_converter.dart';
export 'src/converter/mcp_converter.dart';
export 'src/converter/mcp_schema_converter.dart';

// Exporter
export 'src/exporter/csv_exporter.dart';

// File I/O
export 'src/io/csv_file_handler.dart';

// Errors
export 'src/errors/csv_errors.dart';
