import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';

/// Convertit les données d'un tracé SVG (attribut `d`) en [Path].
Path svgPath(String data, {PathFillType fillType = PathFillType.nonZero}) {
  final path = Path()..fillType = fillType;
  writeSvgPathDataToPath(data, _PathSink(path));
  return path;
}

class _PathSink extends PathProxy {
  _PathSink(this.path);
  final Path path;
  @override
  void close() => path.close();
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}
