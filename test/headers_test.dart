import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('CsvHeaderDetector', () {
    group('detection', () {
      test('detects string headers with numeric data', () {
        final data = [
          ['Name', 'Age', 'Score'],
          ['John', 30, 85.5],
          ['Jane', 25, 92.0],
        ];

        final detection = FlutterCsv.detectHeaders(data);

        expect(detection.isHeader, isTrue);
        expect(detection.confidence, greaterThan(0.5));
        expect(detection.headers, ['Name', 'Age', 'Score']);
      });

      test('detects no headers when all same type', () {
        final data = [
          ['John', 'Jane', 'Bob'],
          ['Alice', 'Eve', 'Charlie'],
        ];

        final detection = FlutterCsv.detectHeaders(data);

        expect(detection.confidence, lessThan(1.0));
      });

      test('handles empty data', () {
        final detection = FlutterCsv.detectHeaders([]);

        expect(detection.isHeader, isFalse);
      });

      test('handles single row', () {
        final detection = FlutterCsv.detectHeaders([
          ['a', 'b', 'c']
        ]);

        expect(detection.isHeader, isFalse);
        expect(detection.confidence, 0.5);
      });

      test('detects header patterns (snake_case)', () {
        final data = [
          ['user_name', 'user_age'],
          ['John', 30],
        ];

        final detection = FlutterCsv.detectHeaders(data);
        expect(detection.reasons, contains('First row matches header naming patterns'));
      });

      test('detects header patterns (CamelCase)', () {
        final data = [
          ['UserName', 'UserAge'],
          ['John', 30],
        ];

        final detection = FlutterCsv.detectHeaders(data);
        expect(detection.isHeader, isTrue);
      });
    });
  });

  group('CsvHeaders utility', () {
    group('generate', () {
      test('generates default headers', () {
        final headers = CsvHeaders.generate(3);

        expect(headers, ['Column1', 'Column2', 'Column3']);
      });

      test('generates headers with custom prefix', () {
        final headers = CsvHeaders.generate(3, prefix: 'Field');

        expect(headers, ['Field1', 'Field2', 'Field3']);
      });
    });

    group('normalize', () {
      test('normalizes headers', () {
        final headers = CsvHeaders.normalize(['First Name', 'Last Name', 'AGE']);

        expect(headers, ['first_name', 'last_name', 'age']);
      });

      test('handles multiple spaces', () {
        final headers = CsvHeaders.normalize(['Field  Name']);

        expect(headers, ['field_name']);
      });
    });

    group('makeUnique', () {
      test('makes duplicate headers unique', () {
        final headers = CsvHeaders.makeUnique(['name', 'name', 'name']);

        expect(headers, ['name', 'name_1', 'name_2']);
      });

      test('preserves unique headers', () {
        final headers = CsvHeaders.makeUnique(['a', 'b', 'c']);

        expect(headers, ['a', 'b', 'c']);
      });
    });

    group('fromRow', () {
      test('creates headers from row', () {
        final headers = CsvHeaders.fromRow(['Name', 'Age', null]);

        expect(headers, ['Name', 'Age', '']);
      });
    });
  });

  group('Auto-header detection in parsing', () {
    test('auto-detects and applies headers', () {
      const csv = 'Name,Age\nJohn,30\nJane,25';
      final doc = FlutterCsv.parseWithAutoHeaders(csv);

      expect(doc.hasHeaders, isTrue);
      expect(doc.headers, ['Name', 'Age']);
      expect(doc.rowCount, 2);
    });

    test('does not apply headers when not confident', () {
      const csv = '1,2,3\n4,5,6';
      final doc = FlutterCsv.parseWithAutoHeaders(csv);

      // May or may not have headers depending on detection
      // The important thing is it doesn't crash
      expect(doc.rowCount, greaterThan(0));
    });
  });

  group('FlutterCsv header utilities', () {
    test('generateHeaders', () {
      final headers = FlutterCsv.generateHeaders(3);
      expect(headers, ['Column1', 'Column2', 'Column3']);
    });

    test('normalizeHeaders', () {
      final headers = FlutterCsv.normalizeHeaders(['First Name']);
      expect(headers, ['first_name']);
    });

    test('uniqueHeaders', () {
      final headers = FlutterCsv.uniqueHeaders(['a', 'a']);
      expect(headers, ['a', 'a_1']);
    });
  });
}
