/// The 4-bit run-length BMP a Lunii storyteller shows while a story plays.
///
/// Measured, not assumed: `tool/lunii_image_survey.dart` decodes every one of
/// the 199 images across the nine packs on a physical FW2 device, and all 199
/// agree — 320×240, 4 bpp, `BI_RLE4`, bottom-up, a 40-byte
/// `BITMAPINFOHEADER`, sixteen palette entries immediately after it and the
/// pixel data immediately after those.
///
/// Two findings from decoding rather than from the headers shape the encoder
/// below. Runs cap at 255 pixels, which the device's own files hit. And **no
/// image on the device uses RLE4's delta escape** — so the firmware's support
/// for it is unproven and [encodeBmpRle4] never emits one. [decodeBmpRle4]
/// still understands deltas, because reading is where being generous is free.
///
/// The palette is per image and is *not* a fixed greyscale ramp: only 149 of
/// the 199 are grey at all, and those carry their own unordered levels. So
/// callers pick their own sixteen colours and nothing is flattened.
///
/// See [docs/lunii-sync.md](../../../docs/lunii-sync.md).
library;

import 'dart:typed_data';

/// Palette entries at 4 bits per pixel.
const int paletteSize = 16;

const int _fileHeaderSize = 14;
const int _dibHeaderSize = 40;
const int _pixelOffset = _fileHeaderSize + _dibHeaderSize + paletteSize * 4;

/// A run can name at most 255 pixels, and absolute mode at most 255 indices.
const int _maxRun = 255;

/// Below this, the same pixels are cheaper carried inside an absolute block.
/// A run costs two bytes however long it is; in a block those pixels cost
/// about half a byte each, so a run only starts paying from five.
const int _minRunLength = 5;

/// An image as palette indices, one byte per pixel, **top row first** — the
/// order everything else in the app thinks in. Bottom-up is a BMP detail and
/// stays inside this file.
class IndexedImage {
  IndexedImage({
    required this.width,
    required this.height,
    required this.pixels,
    required this.palette,
  });

  final int width;
  final int height;

  /// `width * height` bytes, each 0..15, row 0 at the top.
  final Uint8List pixels;

  /// Up to [paletteSize] colours as `0xRRGGBB`.
  final List<int> palette;

  int at(int x, int y) => pixels[y * width + x];
}

class BmpFormatException implements Exception {
  const BmpFormatException(this.message);
  final String message;

  @override
  String toString() => 'BmpFormatException: $message';
}

/// Encode [image] as a 4-bit RLE BMP.
Uint8List encodeBmpRle4(IndexedImage image) {
  if (image.width <= 0 || image.height <= 0) {
    throw BmpFormatException('Empty image: ${image.width}×${image.height}');
  }
  if (image.pixels.length != image.width * image.height) {
    throw BmpFormatException(
      '${image.pixels.length} pixels for a '
      '${image.width}×${image.height} image',
    );
  }
  if (image.palette.length > paletteSize) {
    throw BmpFormatException(
      '${image.palette.length} colours; 4 bpp holds $paletteSize',
    );
  }
  for (final index in image.pixels) {
    if (index >= paletteSize) {
      throw BmpFormatException('Pixel index $index is outside the palette');
    }
  }

  final rle = BytesBuilder();
  // BMP rows run bottom to top, so the last row of the image goes first.
  for (var y = image.height - 1; y >= 0; y--) {
    _encodeRow(
      Uint8List.sublistView(
        image.pixels,
        y * image.width,
        (y + 1) * image.width,
      ),
      rle,
    );
    rle.add(const [0x00, 0x00]); // end of line
  }
  rle.add(const [0x00, 0x01]); // end of bitmap
  final pixelData = rle.toBytes();

  final out = Uint8List(_pixelOffset + pixelData.length);
  final view = ByteData.sublistView(out);
  out[0] = 0x42; // 'B'
  out[1] = 0x4D; // 'M'
  view.setUint32(2, out.length, Endian.little);
  view.setUint32(10, _pixelOffset, Endian.little);
  view.setUint32(14, _dibHeaderSize, Endian.little);
  view.setInt32(18, image.width, Endian.little);
  view.setInt32(22, image.height, Endian.little); // positive: bottom-up
  view.setUint16(26, 1, Endian.little); // colour planes
  view.setUint16(28, 4, Endian.little); // bits per pixel
  view.setUint32(30, 2, Endian.little); // BI_RLE4
  view.setUint32(34, pixelData.length, Endian.little);
  view.setInt32(38, 2835, Endian.little); // 72 DPI in pixels per metre
  view.setInt32(42, 2835, Endian.little);
  view.setUint32(46, paletteSize, Endian.little);
  view.setUint32(50, paletteSize, Endian.little);

  for (var i = 0; i < paletteSize; i++) {
    final colour = i < image.palette.length ? image.palette[i] : 0;
    final at = _fileHeaderSize + _dibHeaderSize + i * 4;
    out[at] = colour & 0xFF; // blue
    out[at + 1] = (colour >> 8) & 0xFF; // green
    out[at + 2] = (colour >> 16) & 0xFF; // red
  }
  out.setRange(_pixelOffset, out.length, pixelData);
  return out;
}

/// Emit one row.
///
/// A run in RLE4 names *two* nibbles and alternates them, so it encodes a flat
/// stretch and a two-colour check equally well — which is why a dithered
/// gradient compresses here at all. Anything shorter than [_minRunLength]
/// accumulates into an absolute block instead.
void _encodeRow(Uint8List row, BytesBuilder out) {
  final pending = <int>[];

  void flush() {
    if (pending.isEmpty) return;
    if (pending.length < 3) {
      // Absolute mode needs three. One or two pixels are cheaper as runs, and
      // cost the same two bytes either way.
      for (var i = 0; i < pending.length; i += 2) {
        final pair = i + 1 < pending.length;
        out.add([
          pair ? 2 : 1,
          (pending[i] << 4) | (pair ? pending[i + 1] : 0),
        ]);
      }
    } else {
      out.add([0x00, pending.length]);
      // Two indices per byte, the whole block padded to a 16-bit boundary.
      final block = Uint8List(((pending.length + 1) ~/ 2 + 1) & ~1);
      for (var i = 0; i < pending.length; i++) {
        if (i.isEven) {
          block[i >> 1] = pending[i] << 4;
        } else {
          block[i >> 1] |= pending[i];
        }
      }
      out.add(block);
    }
    pending.clear();
  }

  var x = 0;
  while (x < row.length) {
    final a = row[x];
    final b = x + 1 < row.length ? row[x + 1] : a;
    var run = 1;
    while (run < _maxRun &&
        x + run < row.length &&
        row[x + run] == (run.isEven ? a : b)) {
      run++;
    }
    if (run >= _minRunLength) {
      flush();
      out.add([run, (a << 4) | b]);
      x += run;
    } else {
      pending.add(a);
      x++;
      if (pending.length == _maxRun) flush();
    }
  }
  flush();
}

/// Read a 4-bit RLE BMP back.
///
/// Deliberately more permissive than [encodeBmpRle4] is: it accepts top-down
/// images and delta escapes, neither of which the encoder produces, because
/// this also has to read whatever is already on a device. Pixels a delta or a
/// short row skips over are left as index 0.
IndexedImage decodeBmpRle4(Uint8List bytes) {
  if (bytes.length < _fileHeaderSize + _dibHeaderSize) {
    throw BmpFormatException('Too short to be a BMP: ${bytes.length} bytes');
  }
  if (bytes[0] != 0x42 || bytes[1] != 0x4D) {
    throw const BmpFormatException('Not a BMP: no "BM" magic');
  }
  final view = ByteData.sublistView(bytes);
  final pixelOffset = view.getUint32(10, Endian.little);
  final dibSize = view.getUint32(14, Endian.little);
  final width = view.getInt32(18, Endian.little);
  final rawHeight = view.getInt32(22, Endian.little);
  final bitCount = view.getUint16(28, Endian.little);
  final compression = view.getUint32(30, Endian.little);
  var clrUsed = view.getUint32(46, Endian.little);

  if (bitCount != 4) {
    throw BmpFormatException('Expected 4 bpp, found $bitCount');
  }
  if (compression != 2) {
    throw BmpFormatException('Expected BI_RLE4 (2), found $compression');
  }
  final height = rawHeight.abs();
  // A negative height means the rows are stored top-first instead.
  final topDown = rawHeight < 0;
  if (width <= 0 || height <= 0) {
    throw BmpFormatException('Nonsense size: $width×$rawHeight');
  }
  if (pixelOffset > bytes.length) {
    throw BmpFormatException(
      'Pixel data starts at $pixelOffset, past the end of ${bytes.length}',
    );
  }

  if (clrUsed == 0 || clrUsed > paletteSize) clrUsed = paletteSize;
  final paletteAt = _fileHeaderSize + dibSize;
  final palette = <int>[];
  for (var i = 0; i < clrUsed; i++) {
    final at = paletteAt + i * 4;
    palette.add(
      at + 2 < bytes.length
          ? (bytes[at + 2] << 16) | (bytes[at + 1] << 8) | bytes[at]
          : 0,
    );
  }

  final pixels = Uint8List(width * height);
  void plot(int x, int y, int index) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    pixels[(topDown ? y : height - 1 - y) * width + x] = index;
  }

  var at = pixelOffset;
  var x = 0;
  var y = 0;
  while (at + 1 < bytes.length) {
    final count = bytes[at];
    final value = bytes[at + 1];
    at += 2;
    if (count > 0) {
      // A run alternates the two nibbles of `value`.
      for (var i = 0; i < count; i++) {
        plot(x + i, y, i.isEven ? value >> 4 : value & 0xF);
      }
      x += count;
      continue;
    }
    switch (value) {
      case 0: // end of line
        x = 0;
        y++;
      case 1: // end of bitmap
        return IndexedImage(
          width: width,
          height: height,
          pixels: pixels,
          palette: palette,
        );
      case 2: // delta
        if (at + 1 >= bytes.length) {
          throw const BmpFormatException('Delta escape runs off the end');
        }
        x += bytes[at];
        y += bytes[at + 1];
        at += 2;
      default: // absolute: `value` indices, nibble-packed, padded to 16 bits
        final byteCount = ((value + 1) ~/ 2 + 1) & ~1;
        if (at + byteCount > bytes.length) {
          throw const BmpFormatException('Absolute block runs off the end');
        }
        for (var i = 0; i < value; i++) {
          final packed = bytes[at + (i >> 1)];
          plot(x + i, y, i.isEven ? packed >> 4 : packed & 0xF);
        }
        at += byteCount;
        x += value;
    }
  }
  throw const BmpFormatException('Pixel data ended without end-of-bitmap');
}
