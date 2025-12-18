import 'dart:convert';
import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('CsvExporter', () {
    late CsvDocument document;

    setUp(() {
      final builder = FlutterCsv.builder()
        ..columns(['Name', 'Age'])
        ..row(['John', 30])
        ..row(['Jane', 25]);
      document = builder.build();
    });

    group('export formats', () {
      test('exports as CSV', () {
        final result = document.export(format: CsvExportFormat.csv);

        expect(result.extension, 'csv');
        expect(result.mimeType, 'text/csv');
        expect(result.content, contains('Name,Age'));
      });

      test('exports as TSV', () {
        final result = document.export(format: CsvExportFormat.tsv);

        expect(result.extension, 'tsv');
        expect(result.mimeType, 'text/tab-separated-values');
        expect(result.content, contains('\t'));
      });

      test('exports as European CSV', () {
        final result = document.export(format: CsvExportFormat.european);

        expect(result.content, contains(';'));
      });

      test('exports as RFC 4180', () {
        final result = document.export(format: CsvExportFormat.rfc4180);

        expect(result.content, contains('\r\n'));
      });

      test('exports as Excel', () {
        final result = document.export(format: CsvExportFormat.excel);

        expect(result.mimeType, 'application/vnd.ms-excel');
        // Excel format includes BOM
        expect(result.bytes[0], 0xEF);
        expect(result.bytes[1], 0xBB);
        expect(result.bytes[2], 0xBF);
      });
    });

    group('export result', () {
      test('provides content as string', () {
        final result = document.export();

        expect(result.content, isA<String>());
        expect(result.content, isNotEmpty);
      });

      test('provides content as bytes', () {
        final result = document.export();

        expect(result.bytes, isNotEmpty);
        expect(result.length, greaterThan(0));
      });

      test('reports correct encoding', () {
        final result = document.export();

        expect(result.encoding, utf8);
      });
    });

    group('web export', () {
      test('exports for web compatibility', () {
        final result = document.exportForWeb();

        expect(result, isNotNull);
        expect(result.content, isNotEmpty);
      });
    });

    group('chunked export', () {
      late CsvDocument largeDocument;

      setUp(() {
        final builder = FlutterCsv.builder()..columns(['ID', 'Value']);
        for (var i = 0; i < 100; i++) {
          builder.row([i, 'Value $i']);
        }
        largeDocument = builder.build();
      });

      test('exports in chunks', () {
        final chunks = largeDocument.exportInChunks(chunkSize: 10).toList();

        expect(chunks, isNotEmpty);
        expect(chunks.length, greaterThan(1));
      });

      test('all chunks together equal full export', () {
        final fullExport = largeDocument.toCsv();
        final chunks = largeDocument.exportInChunks(chunkSize: 10);
        final chunkedExport = chunks.join('');

        expect(chunkedExport, fullExport);
      });

      test('respects chunk size', () {
        final chunks = largeDocument.exportInChunks(chunkSize: 25).toList();

        // Header chunk + data chunks
        expect(chunks.length, greaterThan(3));
      });
    });

    group('stream export', () {
      test('exports as stream', () async {
        final chunks = <List<int>>[];

        await for (final chunk in CsvExporter.exportAsStream(
          document,
          chunkSize: 1,
        )) {
          chunks.add(chunk);
        }

        expect(chunks, isNotEmpty);
      });

      test('stream with BOM', () async {
        final chunks = <List<int>>[];

        await for (final chunk in CsvExporter.exportAsStream(
          document,
          chunkSize: 1,
          includeBomAtStart: true,
        )) {
          chunks.add(chunk);
        }

        // First chunk should start with BOM
        expect(chunks.first[0], 0xEF);
        expect(chunks.first[1], 0xBB);
        expect(chunks.first[2], 0xBF);
      });
    });

    group('to string', () {
      test('exportToString', () {
        final csv = document.exportToString();

        expect(csv, 'Name,Age\nJohn,30\nJane,25');
      });

      test('exportToString with format', () {
        final csv = document.exportToString(format: CsvExportFormat.tsv);

        expect(csv, contains('\t'));
      });
    });

    group('to bytes', () {
      test('exportToBytes', () {
        final bytes = document.exportToBytes();

        expect(bytes, isNotEmpty);
      });

      test('exportToBytes with BOM', () {
        final bytes = document.exportToBytes(includeBom: true);

        expect(bytes[0], 0xEF);
        expect(bytes[1], 0xBB);
        expect(bytes[2], 0xBF);
      });
    });
  });

  group('Static export methods', () {
    test('FlutterCsv.export', () {
      final doc = FlutterCsv.parseDocument('a,b\n1,2', firstRowIsHeader: true);
      final result = FlutterCsv.export(doc);

      expect(result.content, isNotEmpty);
    });

    test('FlutterCsv.exportForWeb', () {
      final doc = FlutterCsv.parseDocument('a,b\n1,2');
      final result = FlutterCsv.exportForWeb(doc);

      expect(result.content, isNotEmpty);
    });

    test('FlutterCsv.exportInChunks', () {
      final doc = FlutterCsv.parseDocument('a,b\n1,2\n3,4');
      final chunks = FlutterCsv.exportInChunks(doc, chunkSize: 1).toList();

      expect(chunks, isNotEmpty);
    });
  });
}
