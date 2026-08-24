/// A picture of its own for every world.
///
/// The night-sky cover varies only where the stars fall, so two worlds arrive
/// on the storyteller looking identical — same indigo, same moon in the same
/// corner. On a device with no screen worth reading, the picture is half of
/// how a child tells one pack from another, so it has to actually differ.
///
/// Everything here is derived from the world's **name**: the palette, what
/// stands on the horizon, what hangs in the sky. So a world's picture is
/// stable for as long as it is called what it is called — every episode of
/// "Pip's Adventures" shows the same place — and two worlds are near-certain
/// to look nothing alike.
///
/// Pure Dart, like the rest of the cover work: no image package, no asset to
/// keep in sync. See `docs/lunii-sync.md`.
library;

import 'dart:math';
import 'dart:typed_data';

import '../image/bmp_rle4.dart';

const int _width = 320;
const int _height = 240;

/// A world's sky and ground, as 16 colours the device can show.
class _Palette {
  const _Palette(this.name, this.skyTop, this.skyLow, this.body, this.ground);

  final String name;

  /// The gradient runs [skyTop] at the top to [skyLow] at the horizon.
  final int skyTop;
  final int skyLow;

  /// Whatever hangs in the sky — moon, sun, planet.
  final int body;

  /// The silhouette along the bottom.
  final int ground;
}

/// Eight skies, chosen to be told apart at a glance rather than to be subtle:
/// a child picking a pack sees the colour before anything else.
const List<_Palette> _palettes = [
  _Palette('midnight', 0x0C0E2E, 0x342A5C, 0xF6ECC4, 0x05060F),
  _Palette('dusk', 0x2B1B4A, 0xC96F5A, 0xFFE3B0, 0x1A0E22),
  _Palette('sea', 0x03202E, 0x0E6E7A, 0xCFF4E8, 0x021017),
  _Palette('forest', 0x0A1F14, 0x2E6B3A, 0xE8F0B8, 0x040D08),
  _Palette('amber', 0x3A1E06, 0xD98A2B, 0xFFF0C2, 0x1C0D02),
  _Palette('plum', 0x27093A, 0x8B3C74, 0xF7D7EE, 0x140420),
  _Palette('frost', 0x0B2138, 0x7FA9C9, 0xF2FAFF, 0x061320),
  _Palette('moss', 0x1A2408, 0x7E8F3A, 0xFBF6C8, 0x0C1104),
];

/// What stands along the bottom of the picture.
enum _Ground { hills, mountains, forest, waves, rooftops, dunes }

/// What hangs in the sky.
enum _Sky { crescent, fullMoon, ringed, lowSun, bare }

/// A 4×4 ordered-dither matrix, scaled to 0…15.
const List<List<int>> _bayer4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

/// The picture for a world, ready for the device.
IndexedImage worldCoverIndexed({required String seed}) {
  final choice = _chooseFor(seed);
  return _render(seed, choice);
}

/// The same picture as a 24-bit BMP, for looking at on a computer. Only the
/// indexed form goes to the device; this exists so a change here can be seen
/// without a storyteller plugged in.
Uint8List worldCoverBmp({required String seed}) {
  final image = worldCoverIndexed(seed: seed);
  const headerSize = 54;
  final rowBytes = _width * 3;
  final out = Uint8List(headerSize + rowBytes * _height);
  final header = ByteData.view(out.buffer);
  out[0] = 0x42;
  out[1] = 0x4d;
  header.setUint32(2, out.length, Endian.little);
  header.setUint32(10, headerSize, Endian.little);
  header.setUint32(14, 40, Endian.little);
  header.setInt32(18, _width, Endian.little);
  header.setInt32(22, _height, Endian.little);
  header.setUint16(26, 1, Endian.little);
  header.setUint16(28, 24, Endian.little);
  header.setUint32(34, rowBytes * _height, Endian.little);
  for (var y = 0; y < _height; y++) {
    // BMP rows run bottom to top.
    final source = (_height - 1 - y) * _width;
    for (var x = 0; x < _width; x++) {
      final colour = image.palette[image.pixels[source + x]];
      final at = headerSize + y * rowBytes + x * 3;
      out[at] = colour & 0xFF;
      out[at + 1] = (colour >> 8) & 0xFF;
      out[at + 2] = (colour >> 16) & 0xFF;
    }
  }
  return out;
}

/// The name of the look a world gets, for a dry run to print.
String worldCoverDescription(String seed) {
  final c = _chooseFor(seed);
  return '${c.palette.name} sky, ${c.sky.name} above ${c.ground.name}';
}

class _Choice {
  const _Choice(this.palette, this.ground, this.sky);
  final _Palette palette;
  final _Ground ground;
  final _Sky sky;
}

/// Three independent draws from the name, so palette, ground and sky vary
/// separately — 8 × 6 × 5 = 240 combinations before the stars are placed.
_Choice _chooseFor(String seed) {
  final n = _hash(seed);
  return _Choice(
    _palettes[n % _palettes.length],
    _Ground.values[(n ~/ 8) % _Ground.values.length],
    _Sky.values[(n ~/ 64) % _Sky.values.length],
  );
}

/// FNV-1a over the name. `String.hashCode` is not stable across runs, and a
/// world whose picture changed between two sends would be a different world
/// as far as a child is concerned.
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.trim().toLowerCase().codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

IndexedImage _render(String seed, _Choice choice) {
  final palette = _paletteFor(choice.palette);
  final pixels = Uint8List(_width * _height);
  final rng = Random(_hash(seed));

  void plot(int x, int y, int index) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return;
    pixels[y * _width + x] = index;
  }

  // Sky: ten steps, dithered so the gradient reads as a gradient rather than
  // ten stripes. Sixteen colours cannot make a smooth sky on their own; a
  // pixel sitting between two steps alternates between them across
  // neighbours, and the eye does the blending.
  for (var y = 0; y < _height; y++) {
    final exact = y * 9 / (_height - 1);
    final step = exact.floor().clamp(0, 9);
    final within = exact - step;
    for (var x = 0; x < _width; x++) {
      final threshold = _bayer4[y & 3][x & 3] / 16;
      plot(x, y, (within > threshold ? step + 1 : step).clamp(0, 9));
    }
  }

  // Stars, thinned toward the horizon where the sky is brightest.
  final stars = choice.sky == _Sky.lowSun ? 25 : 70;
  for (var i = 0; i < stars; i++) {
    final x = rng.nextInt(_width);
    final y = rng.nextInt(_height - 90);
    plot(x, y, rng.nextInt(4) == 0 ? 15 : 14);
  }

  _drawSky(choice.sky, plot, rng);
  _drawGround(choice.ground, plot, rng);

  return IndexedImage(
    width: _width,
    height: _height,
    pixels: pixels,
    palette: palette,
  );
}

/// Sixteen entries: ten sky steps, three of whatever is in the sky, the
/// ground, and two of star.
List<int> _paletteFor(_Palette p) => [
  for (var i = 0; i < 10; i++) _lerp(p.skyTop, p.skyLow, i / 9),
  _lerp(p.body, p.skyLow, 0.55),
  _lerp(p.body, p.skyLow, 0.25),
  p.body,
  p.ground,
  _lerp(0xFFFFFF, p.skyLow, 0.55),
  0xFFFFEB,
];

int _lerp(int a, int b, double t) {
  int channel(int shift) {
    final from = (a >> shift) & 0xFF;
    final to = (b >> shift) & 0xFF;
    return (from + (to - from) * t).round().clamp(0, 255);
  }

  return (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

void _drawSky(_Sky sky, void Function(int, int, int) plot, Random rng) {
  const cx = 232.0, cy = 74.0;
  void disc(double x0, double y0, double radius, int index) {
    for (var y = (y0 - radius).floor(); y <= (y0 + radius).ceil(); y++) {
      for (var x = (x0 - radius).floor(); x <= (x0 + radius).ceil(); x++) {
        final dx = x - x0, dy = y - y0;
        if (dx * dx + dy * dy <= radius * radius) plot(x, y, index);
      }
    }
  }

  switch (sky) {
    case _Sky.crescent:
      disc(cx, cy, 46, 12);
      // A second disc in sky colour bites the crescent out of the first.
      for (var y = 28; y <= 120; y++) {
        for (var x = 186; x <= 300; x++) {
          final dx = x - 254.0, dy = y - 60.0;
          if (dx * dx + dy * dy <= 42 * 42) {
            final exact = y * 9 / (_height - 1);
            final step = exact.floor().clamp(0, 9);
            final threshold = _bayer4[y & 3][x & 3] / 16;
            plot(
              x,
              y,
              (exact - step > threshold ? step + 1 : step).clamp(0, 9),
            );
          }
        }
      }
    case _Sky.fullMoon:
      disc(cx, cy, 40, 12);
      disc(cx - 12, cy - 10, 8, 11);
      disc(cx + 14, cy + 12, 6, 11);
    case _Sky.ringed:
      disc(cx, cy, 34, 12);
      // A ring, drawn as a flat ellipse crossing the body.
      for (var t = 0; t < 720; t++) {
        final a = t * pi / 360;
        for (final r in [56.0, 60.0, 64.0]) {
          plot((cx + cos(a) * r).round(), (cy + sin(a) * r * 0.22).round(), 11);
        }
      }
    case _Sky.lowSun:
      disc(cx - 40, 150, 30, 12);
      disc(cx - 40, 150, 38, 11);
      disc(cx - 40, 150, 30, 12);
    case _Sky.bare:
      // Only stars. A few brighter ones so it doesn't read as empty.
      for (var i = 0; i < 12; i++) {
        plot(rng.nextInt(_width), rng.nextInt(120), 15);
      }
  }
}

void _drawGround(
  _Ground ground,
  void Function(int, int, int) plot,
  Random rng,
) {
  void fillColumn(int x, int fromY) {
    for (var y = fromY; y < _height; y++) {
      plot(x, y, 13);
    }
  }

  switch (ground) {
    case _Ground.hills:
      for (var x = 0; x < _width; x++) {
        final y =
            196 - (sin(x / 54) * 16).round() - (sin(x / 23 + 1) * 6).round();
        fillColumn(x, y);
      }
    case _Ground.mountains:
      final peaks = [
        for (var i = 0; i < 4; i++) (40 + i * 80.0, 120.0 + rng.nextInt(40)),
      ];
      for (var x = 0; x < _width; x++) {
        var top = _height.toDouble();
        for (final (px, py) in peaks) {
          final slope = py + (x - px).abs() * 1.15;
          if (slope < top) top = slope;
        }
        fillColumn(x, top.round().clamp(0, _height));
      }
    case _Ground.forest:
      for (var x = 0; x < _width; x++) {
        fillColumn(x, 208);
      }
      for (var i = 0; i < 16; i++) {
        final x0 = 6 + i * 20 + rng.nextInt(6);
        final height = 40 + rng.nextInt(34);
        for (var y = 0; y < height; y++) {
          final halfWidth = (y * 9 ~/ height) + 1;
          for (var x = x0 - halfWidth; x <= x0 + halfWidth; x++) {
            plot(x, 208 - height + y, 13);
          }
        }
      }
    case _Ground.waves:
      for (var x = 0; x < _width; x++) {
        fillColumn(x, 200 + (sin(x / 30) * 4).round());
      }
      for (var i = 0; i < 5; i++) {
        final y = 168 + i * 7;
        for (var x = 0; x < _width; x++) {
          if ((x + i * 13) % 46 < 22) {
            plot(x, y + (sin(x / 18 + i) * 2).round(), 13);
          }
        }
      }
    case _Ground.rooftops:
      var x = 0;
      while (x < _width) {
        final w = 22 + rng.nextInt(26);
        final top = 150 + rng.nextInt(52);
        for (var px = x; px < x + w && px < _width; px++) {
          fillColumn(px, top);
        }
        x += w + 2;
      }
    case _Ground.dunes:
      for (var x = 0; x < _width; x++) {
        fillColumn(x, 202 - (sin(x / 96) * 22).round());
      }
  }
}
