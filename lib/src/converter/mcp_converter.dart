import 'dart:convert';

/// Converts CSV data to and from Model Context Protocol (MCP) format.
///
/// MCP often exchanges data as Resources. This converter focuses on
/// TextResource format:
/// ```json
/// {
///   "uri": "optional-uri",
///   "mimeType": "text/csv",
///   "text": "csv-content"
/// }
/// ```
class McpConverter {
  const McpConverter();

  /// Wraps CSV content into an MCP TextResource JSON string.
  ///
  /// [csvContent] The raw CSV string.
  /// [uri] Optional URI for the resource.
  /// [name] Optional name for the resource.
  String toMcp(String csvContent, {String? uri, String? name}) {
    final map = toMcpMap(csvContent, uri: uri, name: name);
    return jsonEncode(map);
  }

  /// Wraps CSV content into an MCP TextResource Map.
  Map<String, dynamic> toMcpMap(String csvContent,
      {String? uri, String? name}) {
    return {
      if (uri != null) 'uri': uri,
      if (name != null) 'name': name,
      'mimeType': 'text/csv',
      'text': csvContent,
    };
  }

  /// Extracts CSV content from an MCP JSON string.
  ///
  /// Supports both a single Resource object and a helper structure like
  /// `{"contents": [...]}` if it contains a list of resources (returns first match).
  String fromMcp(String mcpJson) {
    if (mcpJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(mcpJson);
      return _extractFromDynamic(decoded);
    } catch (e) {
      throw FormatException('Invalid MCP JSON: $e');
    }
  }

  String _extractFromDynamic(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Check if it is a direct Resource
      if (data.containsKey('text') &&
          (data['mimeType'] == 'text/csv' || !data.containsKey('mimeType'))) {
        return data['text'] as String;
      }

      // Check commonly used "contents" or "resources" wrapper
      if (data.containsKey('contents') && data['contents'] is List) {
        return _extractFromList(data['contents'] as List);
      }
      if (data.containsKey('resources') && data['resources'] is List) {
        return _extractFromList(data['resources'] as List);
      }
    } else if (data is List) {
      return _extractFromList(data);
    }

    throw const FormatException('Could not find CSV text in MCP structure');
  }

  String _extractFromList(List list) {
    if (list.isEmpty) return '';
    // improved: find the first item specifically marked as csv, otherwise take the first one
    for (final item in list) {
      if (item is Map<String, dynamic> &&
          item['mimeType'] == 'text/csv' &&
          item.containsKey('text')) {
        return item['text'] as String;
      }
    }
    // Fallback: try the first item if it has text
    final first = list.first;
    if (first is Map<String, dynamic> && first.containsKey('text')) {
      return first['text'] as String;
    }

    throw const FormatException('No valid text resource found in list');
  }
}
