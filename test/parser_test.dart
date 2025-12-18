import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('CsvParser', () {
    group('basic parsing', () {
      test('parses simple CSV', () {
        const csv = 'a,b,c\n1,2,3';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ]);
      });

      test('parses empty string', () {
        const csv = '';
        final result = FlutterCsv.parse(csv);

        expect(result, isEmpty);
      });

      test('parses single row', () {
        const csv = 'a,b,c';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['a', 'b', 'c'],
        ]);
      });

      test('parses single value', () {
        const csv = 'value';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['value'],
        ]);
      });
    });

    group('quoted fields', () {
      test('parses quoted fields', () {
        const csv = '"hello","world"';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['hello', 'world'],
        ]);
      });

      test('parses fields with commas inside quotes', () {
        const csv = '"hello, world",test';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['hello, world', 'test'],
        ]);
      });

      test('parses escaped quotes', () {
        const csv = '"say ""hello"""';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['say "hello"'],
        ]);
      });

      test('parses newlines inside quotes', () {
        const csv = '"line1\nline2",other';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['line1\nline2', 'other'],
        ]);
      });
    });

    group('delimiters', () {
      test('parses with semicolon delimiter', () {
        const csv = 'a;b;c\n1;2;3';
        final result = FlutterCsv.parse(
          csv,
          settings: const CsvSettings(fieldDelimiter: ';'),
        );

        expect(result, [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ]);
      });

      test('parses with tab delimiter', () {
        const csv = 'a\tb\tc\n1\t2\t3';
        final result = FlutterCsv.parse(
          csv,
          settings: CsvSettings.tsv,
        );

        expect(result, [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ]);
      });

      test('parses with CRLF line endings', () {
        const csv = 'a,b,c\r\n1,2,3';
        final result = FlutterCsv.parse(
          csv,
          settings: CsvSettings.rfc4180,
        );

        expect(result, [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ]);
      });

      test('parses mixed line endings', () {
        const csv = 'a,b,c\n1,2,3\r\n4,5,6';
        final result = FlutterCsv.parse(csv);

        expect(result.length, greaterThanOrEqualTo(2));
        expect(result[0], ['a', 'b', 'c']);
      });
    });

    group('number parsing', () {
      test('parses numbers when enabled', () {
        const csv = '1,2.5,text';
        final result = FlutterCsv.parse(
          csv,
          settings: const CsvSettings(parseNumbers: true),
        );

        expect(result, [
          [1, 2.5, 'text'],
        ]);
      });

      test('keeps numbers as strings when disabled', () {
        const csv = '1,2.5,text';
        final result = FlutterCsv.parse(
          csv,
          settings: const CsvSettings(parseNumbers: false),
        );

        expect(result, [
          ['1', '2.5', 'text'],
        ]);
      });

      test('handles European decimal separator', () {
        const csv = '1;2,5;text';
        final result = FlutterCsv.parse(
          csv,
          settings: CsvSettings.european.copyWith(parseNumbers: true),
        );

        expect(result, [
          [1, 2.5, 'text'],
        ]);
      });
    });

    group('empty lines and fields', () {
      test('skips empty lines by default', () {
        const csv = 'a,b\n\nc,d';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['a', 'b'],
          ['c', 'd'],
        ]);
      });

      test('keeps empty lines when configured', () {
        const csv = 'a,b\n\nc,d';
        final result = FlutterCsv.parse(
          csv,
          settings: const CsvSettings(skipEmptyLines: false),
        );

        expect(result.length, 3);
      });

      test('handles empty fields', () {
        const csv = 'a,,c\n,b,';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['a', '', 'c'],
          ['', 'b', ''],
        ]);
      });

      test('handles trailing newlines', () {
        const csv = 'a,b,c\n1,2,3\n';
        final result = FlutterCsv.parse(csv);

        expect(result, [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ]);
      });
    });

    group('auto-detection', () {
      test('auto-detects delimiter', () {
        const csv = 'a;b;c\n1;2;3';
        final result = FlutterCsv.parseAuto(csv);

        expect(result, [
          ['a', 'b', 'c'],
          ['1', '2', '3'],
        ]);
      });

      test('auto-detects settings', () {
        const csv = 'a;b;c\n1;2;3';
        final settings = FlutterCsv.detectSettings(csv);

        expect(settings.fieldDelimiter, ';');
      });
    });

    group('trimming', () {
      test('trims fields when enabled', () {
        const csv = ' a , b , c ';
        final result = FlutterCsv.parse(
          csv,
          settings: const CsvSettings(trimFields: true),
        );

        expect(result, [
          ['a', 'b', 'c'],
        ]);
      });

      test('preserves whitespace when disabled', () {
        const csv = ' a , b , c ';
        final result = FlutterCsv.parse(
          csv,
          settings: const CsvSettings(trimFields: false),
        );

        expect(result, [
          [' a ', ' b ', ' c '],
        ]);
      });
    });
  });
}
