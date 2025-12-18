import 'package:flutter_csv/flutter_csv.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterCsv Integration', () {
    group('Full workflow: Parse -> Modify -> Export', () {
      test('complete workflow', () {
        // Parse
        const csv = 'Name,Age\nJohn,30\nJane,25';
        final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);

        // Verify parsing
        expect(doc.headers, ['Name', 'Age']);
        expect(doc.rowCount, 2);

        // Export
        final exported = doc.toCsv();
        expect(exported, csv);
      });
    });

    group('Builder workflow', () {
      test('complete builder workflow', () {
        // Build
        final builder = FlutterCsv.builder()
          ..columns(['Product', 'Price', 'Quantity'])
          ..row(['Apple', 1.50, 100])
          ..row(['Banana', 0.75, 200])
          ..row(['Orange', 2.00, 50]);
        final doc = builder.build();

        // Export to JSON
        final json = doc.toJson();
        expect(json, contains('Product'));
        expect(json, contains('Apple'));

        // Export to CSV
        final csv = doc.toCsv();
        expect(csv, contains('Product,Price,Quantity'));
        expect(csv, contains('Apple'));
      });
    });

    group('Different presets', () {
      test('RFC 4180 preset', () {
        final builder = FlutterCsv.rfc4180Builder()
          ..columns(['A', 'B'])
          ..row([1, 2]);
        final csv = builder.export();

        expect(csv, 'A,B\r\n1,2');
      });

      test('Excel preset', () {
        final builder = FlutterCsv.excelBuilder()
          ..columns(['A', 'B'])
          ..row([1, 2]);
        final doc = builder.build();

        final result = doc.export(format: CsvExportFormat.excel);
        expect(result.bytes[0], 0xEF); // BOM
      });

      test('European preset', () {
        final builder = FlutterCsv.europeanBuilder()
          ..columns(['A', 'B'])
          ..row([1.5, 2.5]);
        final csv = builder.export();

        expect(csv, contains(';'));
        expect(csv, contains(','));
      });

      test('TSV preset', () {
        final builder = FlutterCsv.tsvBuilder()
          ..columns(['A', 'B'])
          ..row([1, 2]);
        final csv = builder.export();

        expect(csv, contains('\t'));
      });
    });

    group('Edge cases', () {
      test('handles empty CSV', () {
        final result = FlutterCsv.parse('');
        expect(result, isEmpty);
      });

      test('handles CSV with only headers', () {
        const csv = 'A,B,C';
        final doc = FlutterCsv.parseDocument(csv, firstRowIsHeader: true);

        expect(doc.headers, ['A', 'B', 'C']);
        expect(doc.rowCount, 0);
      });

      test('handles very long fields', () {
        final longValue = 'x' * 10000;
        final csv = FlutterCsv.write([
          [longValue],
        ]);

        final parsed = FlutterCsv.parse(csv);
        expect(parsed[0][0], longValue);
      });

      test('handles special unicode characters', () {
        final csv = FlutterCsv.write([
          ['日本語', 'émoji 🎉', 'Ñoño'],
        ]);

        final parsed = FlutterCsv.parse(csv);
        expect(parsed[0][0], '日本語');
        expect(parsed[0][1], 'émoji 🎉');
        expect(parsed[0][2], 'Ñoño');
      });

      test('handles empty fields', () {
        const csv = 'a,,b\n,c,';
        final result = FlutterCsv.parse(csv);

        expect(result[0], ['a', '', 'b']);
        expect(result[1], ['', 'c', '']);
      });
    });

    group('Settings presets', () {
      test('CsvSettings.rfc4180', () {
        expect(CsvSettings.rfc4180.eol, '\r\n');
        expect(CsvSettings.rfc4180.fieldDelimiter, ',');
      });

      test('CsvSettings.excel', () {
        expect(CsvSettings.excel.quoteAllFields, isTrue);
      });

      test('CsvSettings.european', () {
        expect(CsvSettings.european.fieldDelimiter, ';');
        expect(CsvSettings.european.decimalSeparator, ',');
      });

      test('CsvSettings.tsv', () {
        expect(CsvSettings.tsv.fieldDelimiter, '\t');
      });

      test('CsvSettings.copyWith', () {
        final settings = const CsvSettings().copyWith(fieldDelimiter: '|');
        expect(settings.fieldDelimiter, '|');
        expect(settings.textDelimiter, '"');
      });
    });

    group('Sanitization', () {
      test('sanitizes value with comma', () {
        final result = FlutterCsv.sanitize('hello, world');
        expect(result, '"hello, world"');
      });

      test('sanitizes value with quote', () {
        final result = FlutterCsv.sanitize('say "hello"');
        expect(result, '"say ""hello"""');
      });

      test('sanitizes with different modes', () {
        final minimal = FlutterCsv.sanitize('hello', mode: SanitizeMode.minimal);
        final quoteAll = FlutterCsv.sanitize('hello', mode: SanitizeMode.quoteAll);

        expect(minimal, 'hello');
        expect(quoteAll, '"hello"');
      });
    });
  });

  group('Errors', () {
    group('CsvParseException', () {
      test('provides location information', () {
        const error = CsvParseException('test', line: 5, column: 10);

        expect(error.message, 'test');
        expect(error.line, 5);
        expect(error.column, 10);
        expect(error.toString(), contains('line 5'));
      });
    });

    group('UnclosedQuoteException', () {
      test('throws for unclosed quote with strict parsing', () {
        const csv = '"unclosed';

        expect(
          () => FlutterCsv.parse(
            csv,
            settings: const CsvSettings(allowInvalid: false),
          ),
          throwsA(isA<UnclosedQuoteException>()),
        );
      });

      test('handles unclosed quote with lenient parsing', () {
        const csv = '"unclosed';
        final result = FlutterCsv.parse(csv);

        // Should not throw
        expect(result, isNotEmpty);
      });
    });

    group('SettingsValidator', () {
      test('validates empty delimiter', () {
        final errors = SettingsValidator.validate(
          fieldDelimiter: '',
          textDelimiter: '"',
          textEndDelimiter: '"',
          eol: '\n',
        );

        expect(errors, contains(SettingsError.emptyDelimiter));
      });
    });
  });
}
