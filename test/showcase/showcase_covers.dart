import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'showcase_track.dart';

/// Album covers for the showcase scenes, drawn in code: flat poster
/// shapes in flat colours, which a GIF palette keeps exact. Cover 0 is
/// the showcase song's harbour; the others mix a few layouts with a few
/// palettes by [seed], so a library gets a shelf of distinct covers.
Future<Uint8List> paintCover(int seed, {int size = 400}) async {
  final recorder = ui.PictureRecorder();
  final s = size.toDouble();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, s, s));
  if (seed == 0) {
    _harbour(canvas, s);
  } else {
    final colours = _palettes[(seed * 3 + seed ~/ 4) % _palettes.length];
    switch (seed % 4) {
      case 0:
        _sunrise(canvas, s, colours);
      case 1:
        _bauhaus(canvas, s, colours, seed);
      case 2:
        _ridges(canvas, s, colours, seed);
      default:
        _rings(canvas, s, colours, seed);
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

/// The showcase song's cover, as PNG bytes. Like every cover, run it
/// inside `tester.runAsync`.
Future<Uint8List> paintShowcaseCover({int size = 600}) =>
    paintCover(0, size: size);

/// Five flat colours each: background, two mids, a light, a dark.
const List<List<int>> _palettes = [
  [0xFF1F3B4D, 0xFF3E7C8C, 0xFFE0A458, 0xFFF4E3C1, 0xFF0F1E27],
  [0xFF3B1F2B, 0xFFB8476A, 0xFFF29E6D, 0xFFFBE3C9, 0xFF1C0E14],
  [0xFF20302A, 0xFF5E8C61, 0xFFD9C26A, 0xFFF0EAD2, 0xFF101814],
  [0xFF2A2340, 0xFF6C5CA8, 0xFF5FC2C0, 0xFFE8E4F4, 0xFF15111F],
  [0xFFE9E1D3, 0xFFD3542F, 0xFF2D5D7B, 0xFF1D1D1F, 0xFFF7F2E8],
  [0xFF14324A, 0xFFF2B33D, 0xFFE4572E, 0xFFF3EFE0, 0xFF0A1824],
  [0xFF41322A, 0xFFC97B4A, 0xFF8FB3A0, 0xFFF1E4D3, 0xFF221A15],
];

Paint _flat(int argb) => Paint()..color = Color(argb);

/// A sun rising in bands over a flat sea.
void _sunrise(Canvas canvas, double s, List<int> c) {
  canvas.drawRect(Rect.fromLTWH(0, 0, s, s), _flat(c[0]));
  final centre = Offset(s / 2, s * 0.68);
  for (var i = 0; i < 4; i++) {
    canvas.drawCircle(
      centre,
      s * (0.42 - i * 0.09),
      _flat(i.isEven ? c[1] : c[2]),
    );
  }
  canvas.drawCircle(centre, s * 0.1, _flat(c[3]));
  canvas.drawRect(Rect.fromLTWH(0, s * 0.68, s, s * 0.32), _flat(c[4]));
  for (var i = 0; i < 5; i++) {
    final y = s * (0.73 + i * 0.05);
    final w = s * (0.3 - i * 0.04);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(s / 2, y), width: w, height: s * 0.012),
      _flat(c[2]),
    );
  }
}

/// A Bauhaus grid of quarter and half circles.
void _bauhaus(Canvas canvas, double s, List<int> c, int seed) {
  canvas.drawRect(Rect.fromLTWH(0, 0, s, s), _flat(c[3]));
  final cell = s / 3;
  for (var y = 0; y < 3; y++) {
    for (var x = 0; x < 3; x++) {
      final k = x + y * 3;
      final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
      final colour = c[(k + seed) % 3];
      canvas.save();
      canvas.clipRect(rect);
      switch ((k * 5 + seed) % 4) {
        case 0:
          canvas.drawCircle(rect.topLeft, cell, _flat(colour));
        case 1:
          canvas.drawCircle(rect.center, cell * 0.42, _flat(colour));
        case 2:
          canvas.drawRect(rect, _flat(colour));
          canvas.drawCircle(rect.bottomRight, cell * 0.7, _flat(c[3]));
        default:
          canvas.drawCircle(rect.bottomCenter, cell / 2, _flat(colour));
      }
      canvas.restore();
    }
  }
}

/// Mountain ridges in flat layers under a pale sun.
void _ridges(Canvas canvas, double s, List<int> c, int seed) {
  canvas.drawRect(Rect.fromLTWH(0, 0, s, s), _flat(c[3]));
  canvas.drawCircle(Offset(s * 0.7, s * 0.3), s * 0.12, _flat(c[2]));
  for (var layer = 0; layer < 4; layer++) {
    final base = s * (0.5 + layer * 0.13);
    final path = Path()..moveTo(0, s);
    for (var i = 0; i <= 8; i++) {
      final x = i / 8 * s;
      final peak = sceneHash(i + layer * 11, seed) * s * 0.16;
      path.lineTo(x, base - (i.isEven ? peak : peak * 0.3));
    }
    path
      ..lineTo(s, s)
      ..close();
    canvas.drawPath(path, _flat([c[1], c[0], c[4], c[4]][layer]));
  }
}

/// Offset rings, like a speaker cone seen from above.
void _rings(Canvas canvas, double s, List<int> c, int seed) {
  canvas.drawRect(Rect.fromLTWH(0, 0, s, s), _flat(c[4]));
  final centre = Offset(
    s * (0.35 + 0.3 * sceneHash(seed, 5)),
    s * (0.35 + 0.3 * sceneHash(seed, 9)),
  );
  for (var i = 0; i < 7; i++) {
    canvas.drawCircle(
      centre + Offset(i * s * 0.012, -i * s * 0.008),
      s * (0.62 - i * 0.08),
      _flat([c[0], c[1], c[0], c[2], c[0], c[3], c[1]][i]),
    );
  }
  final band = Rect.fromLTWH(0, s * 0.86, s, s * 0.035);
  canvas.drawRect(band, _flat(c[3]));
}

/// The showcase song's cover: a night harbour (a banded dusk sky, a low
/// moon in rings of glow, its broken reflection, a ferry).
void _harbour(Canvas canvas, double s) {
  Paint flat(int argb) => Paint()..color = Color(argb);
  final horizon = s * 0.63;

  // The sky in flat bands, deep blue at the top to a warm horizon.
  const sky = [0xFF101633, 0xFF1A1E45, 0xFF2B2856, 0xFF4A3463, 0xFF7C4567];
  const stops = [0.0, 0.26, 0.48, 0.66, 0.82];
  for (var i = 0; i < sky.length; i++) {
    final top = horizon * stops[i];
    canvas.drawRect(Rect.fromLTRB(0, top, s, horizon), flat(sky[i]));
  }
  canvas.drawRect(
    Rect.fromLTRB(0, horizon * 0.93, s, horizon),
    flat(0xFFC46F63),
  );

  // A few stars, placed by a fixed hash.
  for (var i = 0; i < 34; i++) {
    final x = sceneHash(i, 3) * s;
    final y = sceneHash(i, 7) * horizon * 0.5;
    final r = (sceneHash(i, 9) < 0.8 ? 1.4 : 2.4) * s / 600;
    canvas.drawCircle(Offset(x, y), r, flat(0xFFE9E4F5));
  }

  // The moon, low over the water, in rings of glow.
  final moon = Offset(s * 0.62, horizon - s * 0.1);
  canvas.drawCircle(moon, s * 0.25, flat(0x22FFC79A));
  canvas.drawCircle(moon, s * 0.185, flat(0x2EFFC79A));
  canvas.drawCircle(moon, s * 0.14, flat(0x3DFFD3A8));
  canvas.drawCircle(moon, s * 0.105, flat(0xFFFFE6C4));

  // Hills along the horizon, in front of the moon.
  final hills = Path()..moveTo(0, horizon);
  for (var i = 0; i <= 12; i++) {
    final x = i / 12 * s;
    final y = horizon - s * (0.02 + 0.035 * sceneNoise(i * 0.9, 41));
    hills.lineTo(x, y);
  }
  hills
    ..lineTo(s, horizon)
    ..close();
  canvas.drawPath(hills, flat(0xFF211C3B));

  // Water in flat bands, darker towards the front.
  const water = [0xFF2A2446, 0xFF201C3A, 0xFF16152C, 0xFF0E0F20];
  for (var i = 0; i < water.length; i++) {
    final top = horizon + (s - horizon) * i / water.length;
    canvas.drawRect(Rect.fromLTRB(0, top, s, s), flat(water[i]));
  }

  // The moon's reflection, broken into strokes that widen and dim.
  for (var i = 0; i < 16; i++) {
    final y = horizon + s * 0.02 + i * (s - horizon - s * 0.05) / 16;
    final w = s * (0.05 + 0.013 * i) * (0.55 + 0.45 * sceneHash(i, 13));
    final x = moon.dx + s * 0.03 * (sceneHash(i, 17) - 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: w, height: s * 0.008),
        Radius.circular(s * 0.004),
      ),
      flat(i < 5 ? 0xFFFFD9AE : (i < 11 ? 0xFFD9A07E : 0xFF8C6170)),
    );
  }

  // A small ferry crossing the light, its windows lit.
  final deck = horizon + s * 0.05;
  final boat = Path()
    ..moveTo(s * 0.26, deck)
    ..lineTo(s * 0.44, deck)
    ..lineTo(s * 0.42, deck + s * 0.024)
    ..lineTo(s * 0.28, deck + s * 0.024)
    ..close()
    ..addRect(Rect.fromLTWH(s * 0.3, deck - s * 0.026, s * 0.1, s * 0.026))
    ..addRect(Rect.fromLTWH(s * 0.335, deck - s * 0.046, s * 0.012, s * 0.02));
  canvas.drawPath(boat, flat(0xFF080912));
  for (var i = 0; i < 5; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        s * (0.308 + i * 0.018),
        deck - s * 0.018,
        s * 0.009,
        s * 0.008,
      ),
      flat(0xFFFFD27F),
    );
  }
}
