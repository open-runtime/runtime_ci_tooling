import 'dart:convert';

/// Collects text while enforcing a strict UTF-8 byte budget.
///
/// When appended content would exceed [maxBytes], the buffer keeps the largest
/// valid UTF-8 prefix that fits, appends [truncationSuffix] (or a prefix of it
/// if needed), and marks itself truncated. Further appends are ignored.
class Utf8BoundedBuffer {
  final int maxBytes;
  final String truncationSuffix;

  final StringBuffer _buffer = StringBuffer();
  int _byteLength = 0;
  bool _isTruncated = false;

  Utf8BoundedBuffer({required this.maxBytes, required this.truncationSuffix})
    : assert(maxBytes >= 0, 'maxBytes must be non-negative');

  int get byteLength => _byteLength;
  bool get isTruncated => _isTruncated;
  bool get isEmpty => _buffer.isEmpty;

  @override
  String toString() => _buffer.toString();

  void append(String data) {
    if (_isTruncated || data.isEmpty) {
      return;
    }
    if (maxBytes <= 0) {
      _isTruncated = true;
      return;
    }

    final dataBytes = utf8.encode(data).length;
    if (_byteLength + dataBytes <= maxBytes) {
      _buffer.write(data);
      _byteLength += dataBytes;
      return;
    }

    final available = maxBytes - _byteLength;
    if (available <= 0) {
      _isTruncated = true;
      return;
    }

    final suffixBytes = utf8.encode(truncationSuffix).length;
    final reservedForSuffix = suffixBytes < available ? suffixBytes : available;
    final dataBudget = available - reservedForSuffix;

    if (dataBudget > 0) {
      final prefix = truncateToUtf8Bytes(data, dataBudget);
      if (prefix.isNotEmpty) {
        _buffer.write(prefix);
        _byteLength += utf8.encode(prefix).length;
      }
    }

    final remaining = maxBytes - _byteLength;
    if (remaining > 0) {
      final suffixPrefix = truncateToUtf8Bytes(truncationSuffix, remaining);
      if (suffixPrefix.isNotEmpty) {
        _buffer.write(suffixPrefix);
        _byteLength += utf8.encode(suffixPrefix).length;
      }
    }

    _isTruncated = true;
  }

  static String truncateToUtf8Bytes(String input, int maxBytes) {
    if (maxBytes <= 0 || input.isEmpty) return '';
    if (utf8.encode(input).length <= maxBytes) return input;

    final out = StringBuffer();
    var used = 0;
    for (final rune in input.runes) {
      final chunk = String.fromCharCode(rune);
      final chunkBytes = utf8.encode(chunk).length;
      if (used + chunkBytes > maxBytes) break;
      out.write(chunk);
      used += chunkBytes;
    }
    return out.toString();
  }
}
