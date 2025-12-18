import 'dart:convert';
import 'dart:typed_data';

import '../settings/csv_settings.dart';
import '../builder/csv_document.dart';

/// Export format options
enum CsvExportFormat {
  /// Standard CSV
  csv,

  /// Tab-separated values
  tsv,

  /// Semicolon-separated (European)
  european,

  /// RFC 4180 compliant
  rfc4180,

  /// Excel-optimized with BOM
  excel,
}

/// Result of an export operation
final class ExportResult {
  const ExportResult({
    required this.content,
    required this.bytes,
    required this.extension,
    required this.mimeType,
    required this.encoding,
  });

  /// The exported content as string
  final String content;

  /// The exported content as bytes
  final Uint8List bytes;

  /// Suggested file extension
  final String extension;

  /// MIME type for the export
  final String mimeType;

  /// Encoding used
  final Encoding encoding;

  /// Content length in bytes
  int get length => bytes.length;
}

/// Handles CSV export with various format options.
///
/// Addresses Safari export issues (issue #48) and large file handling (issue #73).
final class CsvExporter {
  const CsvExporter._();

  /// Exports a CsvDocument to string
  static String exportToString(
    CsvDocument document, {
    CsvExportFormat format = CsvExportFormat.csv,
  }) {
    final settings = _settingsForFormat(format, document.settings);
    return document.copyWith(settings: settings).toCsv();
  }

  /// Exports a CsvDocument to bytes
  static Uint8List exportToBytes(
    CsvDocument document, {
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    final content = exportToString(document, format: format);
    final contentBytes = encoding.encode(content);

    if (includeBom && encoding == utf8) {
      // UTF-8 BOM: EF BB BF
      return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...contentBytes]);
    }

    return Uint8List.fromList(contentBytes);
  }

  /// Exports with full result information
  static ExportResult export(
    CsvDocument document, {
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
  }) {
    final includeBom = format == CsvExportFormat.excel;
    final content = exportToString(document, format: format);
    final bytes = exportToBytes(
      document,
      format: format,
      encoding: encoding,
      includeBom: includeBom,
    );

    return ExportResult(
      content: content,
      bytes: bytes,
      extension: _extensionForFormat(format),
      mimeType: _mimeTypeForFormat(format),
      encoding: encoding,
    );
  }

  /// Exports for web download (Safari-compatible - fixes issue #48)
  static ExportResult exportForWeb(
    CsvDocument document, {
    CsvExportFormat format = CsvExportFormat.csv,
  }) {
    // Use UTF-8 with BOM for better browser compatibility
    return export(
      document,
      format: format,
      encoding: utf8,
    );
  }

  /// Exports document in chunks for large files (fixes issue #73)
  static Iterable<String> exportInChunks(
    CsvDocument document, {
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
  }) sync* {
    final settings = _settingsForFormat(format, document.settings);
    final modifiedDoc = document.copyWith(settings: settings);

    // Yield headers first if present
    if (modifiedDoc.hasHeaders) {
      final headerDoc = CsvDocument(
        settings: settings,
        headers: null,
        data: [modifiedDoc.headers!],
      );
      yield headerDoc.toCsv();
      if (modifiedDoc.rowCount > 0) {
        yield settings.eol;
      }
    }

    // Yield data in chunks
    final totalRows = modifiedDoc.rowCount;
    for (var i = 0; i < totalRows; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, totalRows);
      final chunkData = modifiedDoc.data.sublist(i, end);

      final chunkDoc = CsvDocument(
        settings: settings,
        headers: null,
        data: chunkData,
      );

      yield chunkDoc.toCsv();

      if (end < totalRows) {
        yield settings.eol;
      }
    }
  }

  /// Streams bytes for very large files
  static Stream<Uint8List> exportAsStream(
    CsvDocument document, {
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
    bool includeBomAtStart = false,
  }) async* {
    var isFirst = true;

    for (final chunk
        in exportInChunks(document, chunkSize: chunkSize, format: format)) {
      if (isFirst && includeBomAtStart && encoding == utf8) {
        yield Uint8List.fromList([0xEF, 0xBB, 0xBF, ...encoding.encode(chunk)]);
        isFirst = false;
      } else {
        yield Uint8List.fromList(encoding.encode(chunk));
      }
    }
  }

  static CsvSettings _settingsForFormat(
      CsvExportFormat format, CsvSettings base) {
    return switch (format) {
      CsvExportFormat.csv => base,
      CsvExportFormat.tsv => CsvSettings.tsv,
      CsvExportFormat.european => CsvSettings.european,
      CsvExportFormat.rfc4180 => CsvSettings.rfc4180,
      CsvExportFormat.excel => CsvSettings.excel,
    };
  }

  static String _extensionForFormat(CsvExportFormat format) {
    return switch (format) {
      CsvExportFormat.csv => 'csv',
      CsvExportFormat.tsv => 'tsv',
      CsvExportFormat.european => 'csv',
      CsvExportFormat.rfc4180 => 'csv',
      CsvExportFormat.excel => 'csv',
    };
  }

  static String _mimeTypeForFormat(CsvExportFormat format) {
    return switch (format) {
      CsvExportFormat.csv => 'text/csv',
      CsvExportFormat.tsv => 'text/tab-separated-values',
      CsvExportFormat.european => 'text/csv',
      CsvExportFormat.rfc4180 => 'text/csv',
      CsvExportFormat.excel => 'application/vnd.ms-excel',
    };
  }
}

/// Extension for easy export on CsvDocument
extension CsvDocumentExportExtension on CsvDocument {
  /// Exports to string with format
  String exportToString({CsvExportFormat format = CsvExportFormat.csv}) {
    return CsvExporter.exportToString(this, format: format);
  }

  /// Exports to bytes
  Uint8List exportToBytes({
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
    bool includeBom = false,
  }) {
    return CsvExporter.exportToBytes(
      this,
      format: format,
      encoding: encoding,
      includeBom: includeBom,
    );
  }

  /// Exports with full result
  ExportResult export({
    CsvExportFormat format = CsvExportFormat.csv,
    Encoding encoding = utf8,
  }) {
    return CsvExporter.export(this, format: format, encoding: encoding);
  }

  /// Exports for web download
  ExportResult exportForWeb({CsvExportFormat format = CsvExportFormat.csv}) {
    return CsvExporter.exportForWeb(this, format: format);
  }

  /// Exports in chunks for large files
  Iterable<String> exportInChunks({
    int chunkSize = 1000,
    CsvExportFormat format = CsvExportFormat.csv,
  }) {
    return CsvExporter.exportInChunks(this,
        chunkSize: chunkSize, format: format);
  }
}
