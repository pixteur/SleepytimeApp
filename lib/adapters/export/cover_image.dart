/// Draws the picture the Lunii shows while a story plays: a night sky, a
/// scatter of stars, and a crescent moon — the app's icon, in the 320×240
/// 24-bit BMP the device expects.
///
/// Pure Dart on purpose: no image package, no font rendering, no asset to keep
/// in sync. The star field is seeded from the story title, so a given story
/// always gets the same sky. See `docs/lunii-export.md`.
library;

import 'dart:math';
import 'dart:typed_data';

const int _width = 320;
const int _height = 240;

/// A night-sky cover as 24-bit BMP bytes.
Uint8List nightSkyCover({String seed = ''}) {
  // 3 bytes per pixel; 320 * 3 = 960 is already a multiple of 4, so BMP's
  // row padding never kicks in.
  final pixels = Uint8List(_width * _height * 3);

  void plot(int x, int y, int r, int g, int b) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return;
    final i = (y * _width + x) * 3;
    pixels[i] = b; // BMP stores pixels as BGR
    pixels[i + 1] = g;
    pixels[i + 2] = r;
  }

  // Sky: deep indigo at the top easing to a warmer horizon.
  for (var y = 0; y < _height; y++) {
    final t = y / (_height - 1);
    final r = (12 + 40 * t).round();
    final g = (14 + 28 * t).round();
    final b = (46 + 46 * t).round();
    for (var x = 0; x < _width; x++) {
      plot(x, y, r, g, b);
    }
  }

  // Stars, kept out of the upper-right where the moon sits.
  final rng = Random(seed.hashCode);
  for (var i = 0; i < 70; i++) {
    final x = rng.nextInt(_width);
    final y = rng.nextInt(_height - 60);
    if (x > 190 && y < 130) continue;
    final glow = 150 + rng.nextInt(105);
    plot(x, y, glow, glow, (glow * 0.92).round());
  }

  // Crescent moon: a pale disc with a second disc bitten out of it.
  const cx = 232.0, cy = 76.0, radius = 46.0;
  const bx = 254.0, by = 62.0, biteRadius = 42.0;
  for (var y = (cy - radius).floor(); y <= (cy + radius).ceil(); y++) {
    for (var x = (cx - radius).floor(); x <= (cx + radius).ceil(); x++) {
      final dx = x - cx, dy = y - cy;
      final distance = sqrt(dx * dx + dy * dy);
      if (distance > radius) continue;
      final bdx = x - bx, bdy = y - by;
      if (sqrt(bdx * bdx + bdy * bdy) <= biteRadius) continue;
      // Soften the rim so the edge doesn't look like a cut-out.
      final edge = (radius - distance).clamp(0.0, 3.0) / 3.0;
      plot(
        x,
        y,
        (150 + 96 * edge).round(),
        (146 + 90 * edge).round(),
        (120 + 76 * edge).round(),
      );
    }
  }

  return _bmp24(pixels);
}

/// Wrap bottom-up BGR rows in a 24-bit BMP header.
Uint8List _bmp24(Uint8List pixels) {
  const headerSize = 54;
  final imageSize = _width * _height * 3;
  final out = Uint8List(headerSize + imageSize);
  final header = ByteData.view(out.buffer);

  out[0] = 0x42; // 'B'
  out[1] = 0x4d; // 'M'
  header.setUint32(2, headerSize + imageSize, Endian.little); // file size
  header.setUint32(10, headerSize, Endian.little); // pixel data offset
  header.setUint32(14, 40, Endian.little); // DIB header size
  header.setInt32(18, _width, Endian.little);
  header.setInt32(22, _height, Endian.little);
  header.setUint16(26, 1, Endian.little); // colour planes
  header.setUint16(28, 24, Endian.little); // bits per pixel
  header.setUint32(34, imageSize, Endian.little);
  header.setInt32(38, 2835, Endian.little); // 72 DPI, in pixels per metre
  header.setInt32(42, 2835, Endian.little);

  // BMP rows run bottom to top.
  for (var y = 0; y < _height; y++) {
    final source = (_height - 1 - y) * _width * 3;
    out.setRange(
      headerSize + y * _width * 3,
      headerSize + (y + 1) * _width * 3,
      pixels.sublist(source, source + _width * 3),
    );
  }
  return out;
}
