import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// Prefixed: easy_localization re-exports intl, whose TextDirection shadows
// Flutter's enum of the same name.
import 'package:flutter/material.dart' as material;

import '../../../core/prayer/prayer_times_service.dart';
import '../../../core/ramadan/ramadan_status.dart';
import '../../../core/utils/arabic_numerals.dart';

/// The Ramadan night header: crescent, stars, hanging lanterns, and the
/// countdown to iftar.
///
/// Replaces the ordinary green header for the month only. The decoration is
/// confined to this header — the cards below keep their normal treatment, so
/// the data stays as readable in Ramadan as it is the rest of the year.
class RamadanHeader extends StatefulWidget {
  final RamadanStatus status;
  final DailyPrayerTimes times;
  final bool isArabic;

  const RamadanHeader({
    super.key,
    required this.status,
    required this.times,
    required this.isArabic,
  });

  @override
  State<RamadanHeader> createState() => _RamadanHeaderState();
}

/// Ticks once a second, and only this widget rebuilds.
///
/// The app-wide nowProvider ticks every 30s, which is right for the
/// ordinary prayer countdown but would make these seconds jump in
/// thirties. Watching a faster clock from the home screen would rebuild
/// the whole page every second instead of this one card.
class _RamadanHeaderState extends State<RamadanHeader> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  RamadanStatus get status => widget.status;
  DailyPrayerTimes get times => widget.times;
  bool get isArabic => widget.isArabic;
  DateTime get now => _now;

  /// Time left until the fast ends, or until it begins once the sun is down.
  ///
  /// After maghrib the interesting number stops being iftar — that has
  /// happened — and becomes tomorrow's imsak, so the card turns over rather
  /// than sitting on a countdown that already reached zero.
  (Duration remaining, bool untilIftar) _target() {
    if (now.isBefore(times.imsak)) {
      return (times.imsak.difference(now), false);
    }
    if (now.isBefore(times.maghrib)) {
      return (times.maghrib.difference(now), true);
    }
    // Past maghrib: imsak for the coming dawn, which is tomorrow's.
    return (times.imsak.add(const Duration(days: 1)).difference(now), false);
  }

  /// How much of the fasting day has gone, 0..1 — the bar under the clock.
  double get _progress {
    final total = times.maghrib.difference(times.imsak).inSeconds;
    if (total <= 0) return 0;
    final gone = now.difference(times.imsak).inSeconds;
    return (gone / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final (remaining, untilIftar) = _target();
    String n(int v) => isArabic
        ? toArabicDigits(v.toString().padLeft(2, '0'))
        : v.toString().padLeft(2, '0');
    String clock(DateTime at) => formatClockTime(at, arabicDigits: isArabic);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_night2, _night1, _night0],
            stops: [0.0, 0.46, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 10,
          20,
          22,
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _NightSky()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 34),
                Text(
                  'ramadan.hijri_line'.tr(
                    namedArgs: {
                      'day': isArabic
                          ? toArabicDigits('${status.day}')
                          : '${status.day}',
                      'year': isArabic
                          ? toArabicDigits('${status.hijriYear}')
                          : '${status.hijriYear}',
                    },
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _goldLit,
                    height: 1.5,
                  ),
                ),
                Text(
                  status.isLastTen
                      ? 'ramadan.last_ten_now'.tr()
                      : 'ramadan.day_of_month'.tr(
                          namedArgs: {
                            'day': isArabic
                                ? toArabicDigits('${status.day}')
                                : '${status.day}',
                          },
                        ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _creamDim,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _goldLit.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        untilIftar
                            ? 'ramadan.until_iftar'.tr()
                            : 'ramadan.until_imsak'.tr(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _creamDim,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Pinned LTR: a clock counts down left to right in both
                      // languages, and mirroring it puts the seconds first.
                      Directionality(
                        textDirection: material.TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _Unit(n(remaining.inHours), 'ramadan.hours'.tr()),
                            _Unit(
                              n(remaining.inMinutes % 60),
                              'ramadan.minutes'.tr(),
                            ),
                            _Unit(
                              n(remaining.inSeconds % 60),
                              'ramadan.seconds'.tr(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(_goldLit),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Edge(
                              'prayers.imsak'.tr(),
                              clock(times.imsak),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          Expanded(
                            child: _Edge(
                              'ramadan.iftar'.tr(),
                              clock(times.maghrib),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _night0 = Color(0xFF08150E);
const _night1 = Color(0xFF0E2417);
const _night2 = Color(0xFF14311F);
const _goldLit = Color(0xFFE0B45F);
const _creamDim = Color(0xFFA8C4A8);

class _Unit extends StatelessWidget {
  final String value;
  final String label;

  const _Unit(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _creamDim),
          ),
        ],
      ),
    );
  }
}

class _Edge extends StatelessWidget {
  final String label;
  final String value;

  const _Edge(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _creamDim)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Crescent, stars and a string of lanterns.
///
/// Painted rather than assembled from widgets: it is one static decoration
/// behind the text, and a CustomPaint costs one layer instead of thirty
/// positioned boxes. Nothing here animates — a header that twinkles behind a
/// countdown is a distraction from the only number on it that matters.
class _NightSky extends StatelessWidget {
  const _NightSky();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SkyPainter());
}

class _SkyPainter extends CustomPainter {
  // Fixed positions rather than Random(): a repaint must not move the stars.
  static const _stars = <(double, double, double)>[
    (0.10, 0.16, 1.6),
    (0.22, 0.42, 1.1),
    (0.34, 0.10, 1.9),
    (0.47, 0.30, 1.2),
    (0.63, 0.14, 1.5),
    (0.71, 0.38, 1.0),
    (0.86, 0.22, 1.8),
    (0.93, 0.46, 1.2),
    (0.16, 0.58, 1.1),
    (0.55, 0.55, 1.3),
  ];

  static const _lanternX = [0.14, 0.36, 0.58, 0.80];

  @override
  void paint(Canvas canvas, Size size) {
    final star = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (final (fx, fy, r) in _stars) {
      canvas.drawCircle(Offset(fx * size.width, fy * size.height), r, star);
    }

    // Crescent: a filled disc with a second disc punched out of it, offset up
    // and to the side. Drawn into a saved layer so the cut-out clears the
    // gradient behind rather than painting the header colour over it.
    final cx = size.width * 0.86;
    final cy = size.height * 0.13;
    const radius = 17.0;
    canvas.saveLayer(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius * 2),
      Paint(),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..color = _goldLit,
    );
    canvas.drawCircle(
      Offset(cx + 6.5, cy - 4.5),
      radius,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // The lantern string: a shallow arc with lanterns hanging from it.
    final wire = Paint()
      ..color = _goldLit.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(0, 6)
      ..quadraticBezierTo(size.width / 2, 22, size.width, 6);
    canvas.drawPath(path, wire);

    for (final fx in _lanternX) {
      final x = fx * size.width;
      // Follow the wire's own curve so each lantern hangs from it rather than
      // floating at a fixed height.
      final t = fx;
      final y = 6 * math.pow(1 - t, 2) + 22 * 2 * t * (1 - t) + 6 * t * t;
      canvas.drawLine(
        Offset(x, y.toDouble()),
        Offset(x, y + 7),
        wire,
      );
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 5, y + 7, 10, 15),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        body,
        Paint()
          ..color = _goldLit.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(body, Paint()..color = _goldLit);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => false;
}
