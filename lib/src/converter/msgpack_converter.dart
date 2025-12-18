import 'dart:convert';
import 'dart:typed_data';

import '../settings/csv_settings.dart';

/// MessagePack format types
class _MsgPackFormat {
  static const int fixMapMin = 0x80;
  static const int fixMapMax = 0x8f;
  static const int fixArrayMin = 0x90;
  static const int fixArrayMax = 0x9f;
  static const int fixStrMin = 0xa0;
  static const int fixStrMax = 0xbf;
  static const int nil = 0xc0;
  static const int falseValue = 0xc2;
  static const int trueValue = 0xc3;
  static const int bin8 = 0xc4;
  static const int bin16 = 0xc5;
  static const int bin32 = 0xc6;
  static const int float32 = 0xca;
  static const int float64 = 0xcb;
  static const int uint8 = 0xcc;
  static const int uint16 = 0xcd;
  static const int uint32 = 0xce;
  static const int uint64 = 0xcf;
  static const int int8 = 0xd0;
  static const int int16 = 0xd1;
  static const int int32 = 0xd2;
  static const int int64 = 0xd3;
  static const int str8 = 0xd9;
  static const int str16 = 0xda;
  static const int str32 = 0xdb;
  static const int array16 = 0xdc;
  static const int array32 = 0xdd;
  static const int map16 = 0xde;
  static const int map32 = 0xdf;
  static const int negativeFixIntMin = 0xe0;
  // ignore: unused_field
  static const int negativeFixIntMax = 0xff;
  static const int positiveFixIntMax = 0x7f;
}

/// Converts CSV data to and from MessagePack binary format.
///
/// MessagePack is a fast, compact binary serialization format.
/// This allows efficient storage and transmission of CSV data.
final class CsvToMsgPackConverter {
  final CsvSettings settings;
  final List<String>? headers;

  const CsvToMsgPackConverter({
    this.settings = const CsvSettings(),
    this.headers,
  });

  /// Converts CSV rows to MessagePack bytes
  Uint8List convert(List<List<Object?>> rows) {
    final effectiveHeaders = headers;

    if (effectiveHeaders != null) {
      // Convert to list of maps
      final maps = rows.map((row) {
        final map = <String, Object?>{};
        for (var i = 0; i < effectiveHeaders.length; i++) {
          map[effectiveHeaders[i]] = i < row.length ? row[i] : null;
        }
        return map;
      }).toList();

      return _MsgPackEncoder().encode(maps);
    }

    // Without headers, encode as array of arrays
    return _MsgPackEncoder().encode(rows);
  }

  /// Converts CSV rows to MessagePack bytes with metadata
  Uint8List convertWithMetadata(List<List<Object?>> rows) {
    final data = <String, Object?>{
      'headers': headers,
      'rows': rows,
      'settings': {
        'fieldDelimiter': settings.fieldDelimiter,
        'textDelimiter': settings.textDelimiter,
        'eol': settings.eol,
      },
    };

    return _MsgPackEncoder().encode(data);
  }
}

/// Converts MessagePack binary data to CSV format
final class MsgPackToCsvConverter {
  final CsvSettings settings;

  const MsgPackToCsvConverter({this.settings = const CsvSettings()});

  /// Converts MessagePack bytes to CSV data
  /// Returns (headers, rows) tuple
  (List<String>?, List<List<Object?>>) convert(Uint8List bytes) {
    final decoded = _MsgPackDecoder().decode(bytes);

    return switch (decoded) {
      // Array of maps -> extract headers and rows
      List<dynamic> list when list.isNotEmpty && list.first is Map =>
        _convertListOfMaps(list.cast<Map>()),

      // Array of arrays -> return as rows
      List<dynamic> list when list.isNotEmpty && list.first is List => (
          null,
          list.map((e) => (e as List).cast<Object?>()).toList()
        ),

      // Map with metadata
      Map<dynamic, dynamic> map when map.containsKey('rows') =>
        _convertMetadataFormat(map),

      // Single map
      Map<dynamic, dynamic> map => _convertSingleMap(map),
      _ => (null, <List<Object?>>[]),
    };
  }

  (List<String>, List<List<Object?>>) _convertListOfMaps(List<Map> maps) {
    if (maps.isEmpty) return ([], []);

    // Collect all keys as headers
    final allKeys = <String>{};
    for (final map in maps) {
      allKeys.addAll(map.keys.map((k) => k.toString()));
    }
    final headers = allKeys.toList();

    final rows = maps.map((map) {
      return headers.map((key) => map[key]).toList();
    }).toList();

    return (headers, rows);
  }

  (List<String>?, List<List<Object?>>) _convertMetadataFormat(Map map) {
    final headers = (map['headers'] as List?)?.cast<String>();
    final rows = (map['rows'] as List?)
            ?.map((e) => (e as List).cast<Object?>())
            .toList() ??
        [];

    return (headers, rows);
  }

  (List<String>, List<List<Object?>>) _convertSingleMap(Map map) {
    final headers = map.keys.map((k) => k.toString()).toList();
    final row = headers.map((key) => map[key]).toList();
    return (headers, [row]);
  }
}

/// Simple MessagePack encoder
class _MsgPackEncoder {
  final BytesBuilder _buffer = BytesBuilder();

  Uint8List encode(Object? value) {
    _encodeValue(value);
    return _buffer.toBytes();
  }

  void _encodeValue(Object? value) {
    switch (value) {
      case null:
        _buffer.addByte(_MsgPackFormat.nil);
      case bool b:
        _buffer
            .addByte(b ? _MsgPackFormat.trueValue : _MsgPackFormat.falseValue);
      case int i:
        _encodeInt(i);
      case double d:
        _encodeDouble(d);
      case String s:
        _encodeString(s);
      case List l:
        _encodeList(l);
      case Map m:
        _encodeMap(m);
      default:
        _encodeString(value.toString());
    }
  }

  void _encodeInt(int value) {
    if (value >= 0) {
      if (value <= _MsgPackFormat.positiveFixIntMax) {
        _buffer.addByte(value);
      } else if (value <= 0xFF) {
        _buffer.addByte(_MsgPackFormat.uint8);
        _buffer.addByte(value);
      } else if (value <= 0xFFFF) {
        _buffer.addByte(_MsgPackFormat.uint16);
        _buffer.add(_uint16Bytes(value));
      } else if (value <= 0xFFFFFFFF) {
        _buffer.addByte(_MsgPackFormat.uint32);
        _buffer.add(_uint32Bytes(value));
      } else {
        _buffer.addByte(_MsgPackFormat.uint64);
        _buffer.add(_uint64Bytes(value));
      }
    } else {
      if (value >= -32) {
        _buffer.addByte(value & 0xFF);
      } else if (value >= -128) {
        _buffer.addByte(_MsgPackFormat.int8);
        _buffer.addByte(value & 0xFF);
      } else if (value >= -32768) {
        _buffer.addByte(_MsgPackFormat.int16);
        _buffer.add(_int16Bytes(value));
      } else if (value >= -2147483648) {
        _buffer.addByte(_MsgPackFormat.int32);
        _buffer.add(_int32Bytes(value));
      } else {
        _buffer.addByte(_MsgPackFormat.int64);
        _buffer.add(_int64Bytes(value));
      }
    }
  }

  void _encodeDouble(double value) {
    _buffer.addByte(_MsgPackFormat.float64);
    final data = ByteData(8);
    data.setFloat64(0, value, Endian.big);
    _buffer.add(data.buffer.asUint8List());
  }

  void _encodeString(String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;

    if (length <= 31) {
      _buffer.addByte(_MsgPackFormat.fixStrMin | length);
    } else if (length <= 0xFF) {
      _buffer.addByte(_MsgPackFormat.str8);
      _buffer.addByte(length);
    } else if (length <= 0xFFFF) {
      _buffer.addByte(_MsgPackFormat.str16);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(_MsgPackFormat.str32);
      _buffer.add(_uint32Bytes(length));
    }

    _buffer.add(bytes);
  }

  void _encodeList(List list) {
    final length = list.length;

    if (length <= 15) {
      _buffer.addByte(_MsgPackFormat.fixArrayMin | length);
    } else if (length <= 0xFFFF) {
      _buffer.addByte(_MsgPackFormat.array16);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(_MsgPackFormat.array32);
      _buffer.add(_uint32Bytes(length));
    }

    for (final item in list) {
      _encodeValue(item);
    }
  }

  void _encodeMap(Map map) {
    final length = map.length;

    if (length <= 15) {
      _buffer.addByte(_MsgPackFormat.fixMapMin | length);
    } else if (length <= 0xFFFF) {
      _buffer.addByte(_MsgPackFormat.map16);
      _buffer.add(_uint16Bytes(length));
    } else {
      _buffer.addByte(_MsgPackFormat.map32);
      _buffer.add(_uint32Bytes(length));
    }

    map.forEach((key, value) {
      _encodeValue(key);
      _encodeValue(value);
    });
  }

  List<int> _uint16Bytes(int value) => [value >> 8, value & 0xFF];
  List<int> _uint32Bytes(int value) => [
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];
  List<int> _uint64Bytes(int value) => [
        (value >> 56) & 0xFF,
        (value >> 48) & 0xFF,
        (value >> 40) & 0xFF,
        (value >> 32) & 0xFF,
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];
  List<int> _int16Bytes(int value) => _uint16Bytes(value);
  List<int> _int32Bytes(int value) => _uint32Bytes(value);
  List<int> _int64Bytes(int value) => _uint64Bytes(value);
}

/// Simple MessagePack decoder
class _MsgPackDecoder {
  late Uint8List _data;
  int _offset = 0;

  Object? decode(Uint8List bytes) {
    _data = bytes;
    _offset = 0;
    return _decodeValue();
  }

  Object? _decodeValue() {
    if (_offset >= _data.length) return null;

    final byte = _data[_offset++];

    // Positive fixint
    if (byte <= _MsgPackFormat.positiveFixIntMax) {
      return byte;
    }

    // Fixmap
    if (byte >= _MsgPackFormat.fixMapMin && byte <= _MsgPackFormat.fixMapMax) {
      return _decodeMap(byte & 0x0F);
    }

    // Fixarray
    if (byte >= _MsgPackFormat.fixArrayMin &&
        byte <= _MsgPackFormat.fixArrayMax) {
      return _decodeArray(byte & 0x0F);
    }

    // Fixstr
    if (byte >= _MsgPackFormat.fixStrMin && byte <= _MsgPackFormat.fixStrMax) {
      return _decodeString(byte & 0x1F);
    }

    // Negative fixint
    if (byte >= _MsgPackFormat.negativeFixIntMin) {
      return byte - 256;
    }

    return switch (byte) {
      _MsgPackFormat.nil => null,
      _MsgPackFormat.falseValue => false,
      _MsgPackFormat.trueValue => true,
      _MsgPackFormat.uint8 => _readUint8(),
      _MsgPackFormat.uint16 => _readUint16(),
      _MsgPackFormat.uint32 => _readUint32(),
      _MsgPackFormat.uint64 => _readUint64(),
      _MsgPackFormat.int8 => _readInt8(),
      _MsgPackFormat.int16 => _readInt16(),
      _MsgPackFormat.int32 => _readInt32(),
      _MsgPackFormat.int64 => _readInt64(),
      _MsgPackFormat.float32 => _readFloat32(),
      _MsgPackFormat.float64 => _readFloat64(),
      _MsgPackFormat.str8 => _decodeString(_readUint8()),
      _MsgPackFormat.str16 => _decodeString(_readUint16()),
      _MsgPackFormat.str32 => _decodeString(_readUint32()),
      _MsgPackFormat.array16 => _decodeArray(_readUint16()),
      _MsgPackFormat.array32 => _decodeArray(_readUint32()),
      _MsgPackFormat.map16 => _decodeMap(_readUint16()),
      _MsgPackFormat.map32 => _decodeMap(_readUint32()),
      _MsgPackFormat.bin8 => _readBin(_readUint8()),
      _MsgPackFormat.bin16 => _readBin(_readUint16()),
      _MsgPackFormat.bin32 => _readBin(_readUint32()),
      _ => null,
    };
  }

  int _readUint8() => _data[_offset++];

  int _readUint16() {
    final value = (_data[_offset] << 8) | _data[_offset + 1];
    _offset += 2;
    return value;
  }

  int _readUint32() {
    final value = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return value;
  }

  int _readUint64() {
    final high = _readUint32();
    final low = _readUint32();
    return (high << 32) | low;
  }

  int _readInt8() {
    final value = _data[_offset++];
    return value < 128 ? value : value - 256;
  }

  int _readInt16() {
    final value = _readUint16();
    return value < 32768 ? value : value - 65536;
  }

  int _readInt32() {
    final value = _readUint32();
    return value < 2147483648 ? value : value - 4294967296;
  }

  int _readInt64() => _readUint64();

  double _readFloat32() {
    final data = ByteData.sublistView(_data, _offset, _offset + 4);
    _offset += 4;
    return data.getFloat32(0, Endian.big);
  }

  double _readFloat64() {
    final data = ByteData.sublistView(_data, _offset, _offset + 8);
    _offset += 8;
    return data.getFloat64(0, Endian.big);
  }

  String _decodeString(int length) {
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return utf8.decode(bytes);
  }

  List<Object?> _decodeArray(int length) {
    final list = <Object?>[];
    for (var i = 0; i < length; i++) {
      list.add(_decodeValue());
    }
    return list;
  }

  Map<String, Object?> _decodeMap(int length) {
    final map = <String, Object?>{};
    for (var i = 0; i < length; i++) {
      final key = _decodeValue()?.toString() ?? '';
      final value = _decodeValue();
      map[key] = value;
    }
    return map;
  }

  Uint8List _readBin(int length) {
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return bytes;
  }
}

/// Extension for MessagePack conversion on data lists
extension MsgPackConversionExtension on List<List<Object?>> {
  /// Converts to MessagePack bytes
  Uint8List toMsgPack({List<String>? headers}) {
    return CsvToMsgPackConverter(headers: headers).convert(this);
  }

  /// Converts to MessagePack bytes with metadata
  Uint8List toMsgPackWithMetadata({List<String>? headers}) {
    return CsvToMsgPackConverter(headers: headers).convertWithMetadata(this);
  }
}
