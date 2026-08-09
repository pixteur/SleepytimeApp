/// Draws the picture the Lunii shows while a story plays: a night sky, a
/// scatter of stars, and a crescent moon — the app's icon, at 320×240.
///
/// Pure Dart on purpose: no image package, no font rendering, no asset to keep
/// in sync. The star field is seeded from the story title, so a given story
/// always gets the same sky.
///
/// Two ways out, because the two transfer routes want different things.
/// [nightSkyCover] returns a 24-bit BMP for the STUdio zip, which converts on
/// transfer. [nightSkyCoverIndexed] returns the sixteen colours a storyteller
/// takes directly. See `docs/lunii-export.md` and `docs/lunii-sync.md`.
library;

import 'dart:math';
import 'dart:typed_data';

import '../image/bmp_rle4.dart';

const int _width = 320;
const int _height = 240;

/// A night-sky cover as 24-bit BMP bytes.
Uint8List nightSkyCover({String seed = ''}) => _bmp24(_draw(seed));

/// The same picture reduced to the sixteen colours a Lunii can show.
///
/// The palette is chosen rather than computed — ten steps of sky, four of
/// moonlight, two of starlight — because we drew the picture and know what is
/// in it. A quantiser would spend entries working that out.
///
/// Ten sky steps across 240 rows would band visibly, so the mapping is
/// ordered-dithered against a 4×4 Bayer matrix. The trade is noise instead of
/// stripes, and it happens to suit RLE4: a dithered gradient alternates
/// between two indices, and an RLE4 run encodes exactly that — two nibbles,
/// alternating — so the dither costs almost nothing to store.
IndexedImage nightSkyCoverIndexed({String seed = ''}) =>
    _toIndexed(_draw(seed));

/// Sixteen colours as `0xRRGGBB`: ten of sky from the top of the gradient to
/// the horizon, four of moon from its body to its lit rim, two of star.
const List<int> coverPalette = [
  // Sky, ten even steps of the same gradient _draw paints.
  0x0C0E2E, 0x101133, 0x151438, 0x19173D, 0x1E1A42,
  0x221E48, 0x27214D, 0x2B2452, 0x302757, 0x342A5C,
  // Moon, body to lit rim.
  0x969278, 0xB6B091, 0xD6CEAA, 0xF6ECC4,
  // Stars, faint and bright.
  0x96968A, 0xFFFFEB,
];

/// A 4×4 ordered-dither matrix, scaled to 0…15.
const List<List<int>> _bayer4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

/// Nearest palette entry to a colour, nudged by the dither threshold so that
/// a value sitting between two entries alternates between them across
/// neighbouring pixels instead of snapping to one.
int _nearest(int r, int g, int b, int threshold) {
  // The nudge is about half the gap between adjacent sky steps, which is what
  // sets how far a pixel may be pushed toward its neighbour.
  const spread = 5;
  final offset = (threshold - 8) * spread ~/ 8;
  final tr = (r + offset).clamp(0, 255);
  final tg = (g + offset).clamp(0, 255);
  final tb = (b + offset).clamp(0, 255);

  var best = 0;
  var bestDistance = 1 << 30;
  for (var i = 0; i < coverPalette.length; i++) {
    final dr = ((coverPalette[i] >> 16) & 0xFF) - tr;
    final dg = ((coverPalette[i] >> 8) & 0xFF) - tg;
    final db = (coverPalette[i] & 0xFF) - tb;
    final distance = dr * dr + dg * dg + db * db;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = i;
    }
  }
  return best;
}

/// Ashi's vélo under the same night sky — the cover for a story whose
/// heroine's bicycle is a character in its own right.
///
/// Same palette and the same dither as [nightSkyCoverIndexed]: the bicycle is
/// drawn in the moonlight creams already in the sixteen, so it needs no new
/// entries and comes out glowing against the dark.
IndexedImage veloCoverIndexed({String seed = ''}) =>
    _toIndexed(_drawVelo(seed));

/// A night-sky cover as 24-bit BMP bytes, with the bicycle — for the STUdio
/// zip, which takes full colour.
Uint8List veloCover({String seed = ''}) => _bmp24(_drawVelo(seed));

/// Reduce a drawn BGR buffer to the sixteen colours a Lunii can show.
IndexedImage _toIndexed(Uint8List rgb) {
  final pixels = Uint8List(_width * _height);
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final i = (y * _width + x) * 3;
      pixels[y * _width + x] = _nearest(
        rgb[i + 2],
        rgb[i + 1],
        rgb[i],
        _bayer4[y & 3][x & 3],
      );
    }
  }
  return IndexedImage(
    width: _width,
    height: _height,
    pixels: pixels,
    palette: coverPalette,
  );
}

/// The sky and stars, then a bicycle in silhouette-with-highlights.
Uint8List _drawVelo(String seed) {
  final pixels = _draw(seed, moon: false);

  void plot(int x, int y, int r, int g, int b) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) return;
    final i = (y * _width + x) * 3;
    pixels[i] = b;
    pixels[i + 1] = g;
    pixels[i + 2] = r;
  }

  /// A disc of radius [thickness] at every step, which is how a line gets
  /// width without any anti-aliasing machinery.
  void stroke(
    double x0,
    double y0,
    double x1,
    double y1,
    double thickness,
    int r,
    int g,
    int b,
  ) {
    final steps = (max((x1 - x0).abs(), (y1 - y0).abs()) * 2).ceil() + 1;
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final cx = x0 + (x1 - x0) * t;
      final cy = y0 + (y1 - y0) * t;
      // Always the centre: a thickness under ~0.71 satisfies the disc test
      // nowhere, so without this a thin line draws precisely nothing.
      plot(cx.round(), cy.round(), r, g, b);
      for (var dy = -thickness; dy <= thickness; dy++) {
        for (var dx = -thickness; dx <= thickness; dx++) {
          if (dx * dx + dy * dy > thickness * thickness) continue;
          plot((cx + dx).round(), (cy + dy).round(), r, g, b);
        }
      }
    }
  }

  void ring(
    double cx,
    double cy,
    double radius,
    double thickness,
    int r,
    int g,
    int b,
  ) {
    final steps = (radius * 8).ceil();
    for (var s = 0; s < steps; s++) {
      final a = 2 * pi * s / steps;
      stroke(
        cx + cos(a) * radius,
        cy + sin(a) * radius,
        cx + cos(a) * radius,
        cy + sin(a) * radius,
        thickness,
        r,
        g,
        b,
      );
    }
  }

  // Moonlit cream, and a dimmer tone for the spokes so the wheels read as
  // wheels rather than as solid discs.
  const cr = 246, cg = 236, cb = 196;
  const sr = 182, sg = 176, sb = 145;

  const rearX = 92.0, frontX = 232.0, hubY = 170.0, radius = 40.0;
  const crankX = 162.0, crankY = 170.0;
  const seatX = 126.0, seatY = 118.0;
  const headX = 206.0, headY = 116.0;

  for (final cx in [rearX, frontX]) {
    for (var s = 0; s < 8; s++) {
      final a = pi * s / 8;
      stroke(
        cx - cos(a) * (radius - 2),
        hubY - sin(a) * (radius - 2),
        cx + cos(a) * (radius - 2),
        hubY + sin(a) * (radius - 2),
        0.5,
        sr,
        sg,
        sb,
      );
    }
    ring(cx, hubY, radius, 2, cr, cg, cb);
    ring(cx, hubY, 3, 1.5, cr, cg, cb);
  }

  // Frame: chain stay, seat stay, seat tube, top tube, down tube, fork.
  stroke(rearX, hubY, crankX, crankY, 2, cr, cg, cb);
  stroke(rearX, hubY, seatX, seatY, 2, cr, cg, cb);
  stroke(seatX, seatY, crankX, crankY, 2, cr, cg, cb);
  stroke(seatX, seatY, headX, headY, 2, cr, cg, cb);
  stroke(crankX, crankY, headX, headY, 2, cr, cg, cb);
  stroke(headX, headY, frontX, hubY, 2, cr, cg, cb);

  // Saddle, handlebars, and a crank arm so it looks ridden rather than parked.
  stroke(seatX - 11, seatY - 5, seatX + 7, seatY - 5, 2.5, cr, cg, cb);
  stroke(headX, headY, headX, headY - 12, 2, cr, cg, cb);
  stroke(headX - 13, headY - 13, headX + 9, headY - 11, 2, cr, cg, cb);
  stroke(crankX, crankY, crankX - 6, crankY + 13, 1.5, sr, sg, sb);

  return pixels;
}

/// The picture itself, as BGR bytes, top row first.
Uint8List _draw(String seed, {bool moon = true}) {
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

  if (!moon) return pixels;

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

  return pixels;
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
