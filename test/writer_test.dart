import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('CsvWriter', () {
    group('basic writing', () {
      test('writes simple rows', () {
        final csv = FlutterCsv.write([
          ['a', 'b', 'c'],
          [1, 2, 3],
        ]);

        expect(csv, 'a,b,c\n1,2,3');
      });

      test('writes empty list', () {
        final csv = FlutterCsv.write([]);

        expect(csv, isEmpty);
      });

      test('writes single row', () {
        final csv = FlutterCsv.write([
          ['a', 'b', 'c'],
        ]);

        expect(csv, 'a,b,c');
      });

      test('writes single value', () {
        final csv = FlutterCsv.write([
          ['value'],
        ]);

        expect(csv, 'value');
      });
    });

    group('special characters', () {
      test('quotes fields with comma', () {
        final csv = FlutterCsv.write([
          ['hello, world', 'test'],
        ]);

        expect(csv, '"hello, world",test');
      });

      test('quotes fields with newline', () {
        final csv = FlutterCsv.write([
          ['line1\nline2', 'test'],
        ]);

        expect(csv, '"line1\nline2",test');
      });

      test('escapes quotes', () {
        final csv = FlutterCsv.write([
          ['say "hello"', 'test'],
        ]);

        expect(csv, '"say ""hello""",test');
      });

      test('quotes fields with delimiter', () {
        final csv = FlutterCsv.write([
          ['a;b', 'c'],
        ], settings: const CsvSettings(fieldDelimiter: ';'));

        expect(csv, '"a;b";c');
      });
    });

    group('quote all fields', () {
      test('quotes all fields when enabled', () {
        final csv = FlutterCsv.write([
          ['a', 'b', 'c'],
        ], settings: const CsvSettings(quoteAllFields: true));

        expect(csv, '"a","b","c"');
      });
    });

    group('null handling', () {
      test('writes null as empty string by default', () {
        final csv = FlutterCsv.write([
          ['a', null, 'c'],
        ]);

        expect(csv, 'a,,c');
      });

      test('writes null as configured value', () {
        final csv = FlutterCsv.write([
          ['a', null, 'c'],
        ], settings: const CsvSettings(nullValue: 'NULL'));

        expect(csv, 'a,NULL,c');
      });
    });

    group('different delimiters', () {
      test('writes with semicolon delimiter', () {
        final csv = FlutterCsv.write([
          ['a', 'b', 'c'],
        ], settings: const CsvSettings(fieldDelimiter: ';'));

        expect(csv, 'a;b;c');
      });

      test('writes with tab delimiter', () {
        final csv = FlutterCsv.write([
          ['a', 'b', 'c'],
        ], settings: CsvSettings.tsv);

        expect(csv, 'a\tb\tc');
      });

      test('writes with CRLF', () {
        final csv = FlutterCsv.write([
          ['a'],
          ['b'],
        ], settings: CsvSettings.rfc4180);

        expect(csv, 'a\r\nb');
      });
    });

    group('trailing EOL', () {
      test('adds trailing EOL when requested', () {
        final csv = FlutterCsv.writeWithTrailingEol([
          ['a', 'b'],
        ]);

        expect(csv, 'a,b\n');
      });
    });

    group('single row', () {
      test('writes single row', () {
        final csv = FlutterCsv.writeRow(['a', 'b', 'c']);

        expect(csv, 'a,b,c');
      });
    });

    group('type handling', () {
      test('writes integers', () {
        final csv = FlutterCsv.write([
          [1, 2, 3],
        ]);

        expect(csv, '1,2,3');
      });

      test('writes doubles', () {
        final csv = FlutterCsv.write([
          [1.5, 2.5, 3.5],
        ]);

        expect(csv, '1.5,2.5,3.5');
      });

      test('writes booleans', () {
        final csv = FlutterCsv.write([
          [true, false],
        ]);

        expect(csv, 'true,false');
      });

      test('writes dates', () {
        final date = DateTime(2024, 1, 15, 10, 30);
        final csv = FlutterCsv.write([
          [date],
        ]);

        expect(csv, contains('2024-01-15'));
      });

      test('handles European decimal separator', () {
        final csv = FlutterCsv.write([
          [1.5, 2.5],
        ], settings: CsvSettings.european);

        expect(csv, '1,5;2,5');
      });
    });

    group('bytes export', () {
      test('exports to bytes', () {
        final bytes = FlutterCsv.writeBytes([
          ['a', 'b'],
        ]);

        expect(bytes, isNotEmpty);
      });

      test('exports with BOM', () {
        final bytes = FlutterCsv.writeBytes([
          ['a'],
        ], includeBom: true);

        expect(bytes[0], 0xEF);
        expect(bytes[1], 0xBB);
        expect(bytes[2], 0xBF);
      });
    });
  });

  group('CsvSanitizer', () {
    group('sanitize modes', () {
      test('minimal mode only quotes when necessary', () {
        const sanitizer = CsvSanitizer(mode: SanitizeMode.minimal);

        expect(sanitizer.sanitize('hello'), 'hello');
        expect(sanitizer.sanitize('hello,world'), '"hello,world"');
      });

      test('quoteStrings mode quotes all strings', () {
        const sanitizer = CsvSanitizer(mode: SanitizeMode.quoteStrings);

        expect(sanitizer.sanitize('hello'), '"hello"');
        expect(sanitizer.sanitize(123), '123');
      });

      test('quoteAll mode quotes everything', () {
        const sanitizer = CsvSanitizer(mode: SanitizeMode.quoteAll);

        expect(sanitizer.sanitize('hello'), '"hello"');
        expect(sanitizer.sanitize(123), '"123"');
      });

      test('escape mode escapes special chars', () {
        const sanitizer = CsvSanitizer(mode: SanitizeMode.escape);

        expect(sanitizer.sanitize('a,b'), r'a\,b');
        expect(sanitizer.sanitize('a"b'), r'a\"b');
      });
    });

    group('row sanitization', () {
      test('sanitizes entire row', () {
        const sanitizer = CsvSanitizer();
        final result = sanitizer.sanitizeRow(['hello', 'a,b', 123]);

        expect(result, ['hello', '"a,b"', '123']);
      });

      test('sanitizes all data', () {
        const sanitizer = CsvSanitizer();
        final result = sanitizer.sanitizeAll([
          ['a', 'b,c'],
          [1, 2],
        ]);

        expect(result, [
          ['a', '"b,c"'],
          ['1', '2'],
        ]);
      });
    });

    group('extension', () {
      test('sanitize extension works', () {
        expect('hello'.sanitizeForCsv(), 'hello');
        expect('a,b'.sanitizeForCsv(), '"a,b"');
      });
    });
  });
}
