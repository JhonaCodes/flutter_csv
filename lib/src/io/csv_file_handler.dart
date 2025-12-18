import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../settings/csv_settings.dart';
import '../builder/csv_document.dart';
import '../exporter/csv_exporter.dart';
import '../converter/msgpack_converter.dart';

/// File format for saving CSV data
enum CsvFileFormat {
  /// Standard CSV text file
  csv,

  /// Tab-separated values
  tsv,

  /// JSON format
  json,

  /// MessagePack binary format
  msgpack,
}

/// Result of a file operation
final class FileOperationResult {
  final bool success;
  final String? path;
  final int? bytesWritten;
  final String? error;

  const FileOperationResult({
    required this.success,
    this.path,
    this.bytesWritten,
    this.error,
  });

  factory FileOperationResult.success(String path, int bytes) =>
      FileOperationResult(success: true, path: path, bytesWritten: bytes);

  factory FileOperationResult.failure(String error) =>
      FileOperationResult(success: false, error: error);
}

/// Handles file I/O operations for CSV data.
///
/// Provides methods to save and load CSV files in various formats.
final class CsvFileHandler {
  const CsvFileHandler._();

  // ============================================================
  // SAVE OPERATIONS
  // ============================================================

  /// Saves a CsvDocument to a file
  static Future<FileOperationResult> save(
    CsvDocument document,
    String filePath, {
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) async {
    try {
      final bytes = _getBytes(document, format, encoding, includeBom);
      final file = File(filePath);

      // Create parent directories if they don't exist
      await file.parent.create(recursive: true);

      await file.writeAsBytes(bytes);

      return FileOperationResult.success(filePath, bytes.length);
    } catch (e) {
      return FileOperationResult.failure(e.toString());
    }
  }

  /// Saves a CsvDocument synchronously
  static FileOperationResult saveSync(
    CsvDocument document,
    String filePath, {
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    try {
      final bytes = _getBytes(document, format, encoding, includeBom);
      final file = File(filePath);

      // Create parent directories if they don't exist
      file.parent.createSync(recursive: true);

      file.writeAsBytesSync(bytes);

      return FileOperationResult.success(filePath, bytes.length);
    } catch (e) {
      return FileOperationResult.failure(e.toString());
    }
  }

  /// Saves CSV data rows directly to a file
  static Future<FileOperationResult> saveRows(
    List<List<Object?>> rows,
    String filePath, {
    List<String>? headers,
    CsvSettings settings = const CsvSettings(),
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
  }) async {
    final document = CsvDocument(
      settings: settings,
      headers: headers,
      data: rows,
    );
    return save(document, filePath, format: format, encoding: encoding);
  }

  // ============================================================
  // LOAD OPERATIONS
  // ============================================================

  /// Loads a CSV file into a CsvDocument
  static Future<CsvDocument> load(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = false,
    Encoding encoding = utf8,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    return _parseBytes(bytes, settings, firstRowIsHeader, encoding);
  }

  /// Loads a CSV file synchronously
  static CsvDocument loadSync(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
    bool firstRowIsHeader = false,
    Encoding encoding = utf8,
  }) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();

    return _parseBytes(bytes, settings, firstRowIsHeader, encoding);
  }

  /// Loads a MessagePack file
  static Future<CsvDocument> loadMsgPack(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final converter = MsgPackToCsvConverter(settings: settings);
    final (headers, rows) = converter.convert(bytes);

    return CsvDocument(
      settings: settings,
      headers: headers,
      data: rows,
    );
  }

  /// Loads a MessagePack file synchronously
  static CsvDocument loadMsgPackSync(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
  }) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();

    final converter = MsgPackToCsvConverter(settings: settings);
    final (headers, rows) = converter.convert(bytes);

    return CsvDocument(
      settings: settings,
      headers: headers,
      data: rows,
    );
  }

  // ============================================================
  // STREAM OPERATIONS
  // ============================================================

  /// Saves large CSV data using streaming
  static Future<FileOperationResult> saveStreaming(
    CsvDocument document,
    String filePath, {
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
  }) async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);

      final sink = file.openWrite(encoding: encoding);
      var totalBytes = 0;

      for (final chunk in CsvExporter.exportInChunks(
        document,
        chunkSize: chunkSize,
        format: format,
      )) {
        sink.write(chunk);
        totalBytes += encoding.encode(chunk).length;
      }

      await sink.close();

      return FileOperationResult.success(filePath, totalBytes);
    } catch (e) {
      return FileOperationResult.failure(e.toString());
    }
  }

  /// Reads a CSV file line by line (for very large files)
  static Stream<List<String>> readLines(
    String filePath, {
    CsvSettings settings = const CsvSettings(),
    Encoding encoding = utf8,
  }) async* {
    final file = File(filePath);
    final lines = file
        .openRead()
        .transform(encoding.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty && settings.skipEmptyLines) continue;

      // Simple split - for complex parsing use full parser
      yield line.split(settings.fieldDelimiter);
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  static Uint8List _getBytes(
    CsvDocument document,
    CsvFileFormat format,
    Encoding encoding,
    bool includeBom,
  ) {
    return switch (format) {
      CsvFileFormat.csv => _getCsvBytes(document, encoding, includeBom),
      CsvFileFormat.tsv => _getTsvBytes(document, encoding),
      CsvFileFormat.json => _getJsonBytes(document, encoding),
      CsvFileFormat.msgpack => _getMsgPackBytes(document),
    };
  }

  static Uint8List _getCsvBytes(
    CsvDocument document,
    Encoding encoding,
    bool includeBom,
  ) {
    final content = document.toCsv();
    final contentBytes = encoding.encode(content);

    if (includeBom && encoding == utf8) {
      return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...contentBytes]);
    }

    return Uint8List.fromList(contentBytes);
  }

  static Uint8List _getTsvBytes(CsvDocument document, Encoding encoding) {
    final tsvDoc = document.copyWith(settings: CsvSettings.tsv);
    return Uint8List.fromList(encoding.encode(tsvDoc.toCsv()));
  }

  static Uint8List _getJsonBytes(CsvDocument document, Encoding encoding) {
    final json = document.toJson(pretty: true);
    return Uint8List.fromList(encoding.encode(json));
  }

  static Uint8List _getMsgPackBytes(CsvDocument document) {
    final converter = CsvToMsgPackConverter(headers: document.headers);
    return converter.convertWithMetadata(document.data);
  }

  static CsvDocument _parseBytes(
    Uint8List bytes,
    CsvSettings settings,
    bool firstRowIsHeader,
    Encoding encoding,
  ) {
    // Handle BOM
    var startIndex = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      startIndex = 3;
    }

    final content = encoding.decode(bytes.sublist(startIndex));
    return CsvDocument.fromCsv(
      content,
      settings: settings,
      firstRowIsHeader: firstRowIsHeader,
    );
  }
}

/// Extension for easy file operations on CsvDocument
extension CsvDocumentFileExtension on CsvDocument {
  /// Saves the document to a file
  Future<FileOperationResult> saveToFile(
    String filePath, {
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    return CsvFileHandler.save(
      this,
      filePath,
      format: format,
      encoding: encoding,
      includeBom: includeBom,
    );
  }

  /// Saves the document to a file synchronously
  FileOperationResult saveToFileSync(
    String filePath, {
    CsvFileFormat format = CsvFileFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    return CsvFileHandler.saveSync(
      this,
      filePath,
      format: format,
      encoding: encoding,
      includeBom: includeBom,
    );
  }

  /// Saves using streaming for large files
  Future<FileOperationResult> saveStreaming(
    String filePath, {
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
  }) {
    return CsvFileHandler.saveStreaming(
      this,
      filePath,
      chunkSize: chunkSize,
      format: format,
      encoding: encoding,
    );
  }
}
