import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The "خاتم" motif — two squares overlapped at 45°, forming the eight-point
/// star used throughout the Mus'haf to mark quarters of a hizb (رُبع الحزب).
/// Used as a light repeating background texture behind headers, and as the
/// small brand mark / divider glyph. Keep opacity low (see design review:
/// prior denser patterns read as noise, not ornament).
class KhatimPattern extends StatelessWidget {
  final double tileSize;
  final Color color;
  final double opacity;

  const KhatimPattern({
    super.key,
    this.tileSize = 46,
    this.color = Colors.white,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KhatimPainter(
        tileSize: tileSize,
        color: color,
        opacity: opacity,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _KhatimPainter extends CustomPainter {
  final double tileSize;
  final Color color;
  final double opacity;

  _KhatimPainter({
    required this.tileSize,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final origin = Offset(col * tileSize, row * tileSize);
        _drawTile(canvas, origin, tileSize, paint);
      }
    }
  }

  void _drawTile(Canvas canvas, Offset origin, double s, Paint paint) {
    final center = origin + Offset(s / 2, s / 2);
    final squareSide = s * 24 / 46;
    final rectSize = Size(squareSide, squareSide);

    final rect = Rect.fromCenter(
      center: center,
      width: rectSize.width,
      height: rectSize.height,
    );
    canvas.drawRect(rect, paint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.7853981634); // 45deg
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KhatimPainter oldDelegate) =>
      oldDelegate.tileSize != tileSize ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}

/// Small standalone khatim glyph — used as the brand mark and as the
/// divider ornament between sections.
class KhatimGlyph extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const KhatimGlyph({
    super.key,
    this.size = 20,
    this.color = const Color(0xFF2F5D3F),
    this.strokeWidth = 2.6,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _KhatimGlyphPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _KhatimGlyphPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _KhatimGlyphPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final center = Offset(size.width / 2, size.height / 2);
    final side = size.width * 0.6;
    final rect = Rect.fromCenter(center: center, width: side, height: side);

    canvas.drawRect(rect, paint);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.7853981634);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KhatimGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Thin divider row with a gold khatim glyph centered — matches the
/// "orn" divider used between sections in the mockups.
class OrnamentDivider extends StatelessWidget {
  final EdgeInsets margin;

  const OrnamentDivider({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 18),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 62, height: 1, color: AppColors.divider),
          const SizedBox(width: 10),
          const KhatimGlyph(
            size: 14,
            color: Color(0xFFB0813A),
            strokeWidth: 2.4,
          ),
          const SizedBox(width: 10),
          Container(width: 62, height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}
