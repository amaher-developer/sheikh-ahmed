import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/qibla/qibla_bearing.dart';

void main() {
  // Reference bearings computed independently via the standard atan2
  // great-circle bearing formula, and cross-checked to match
  // flutter_qiblah's own (unexported) internal formula bit-for-bit at
  // these coordinates — see the investigation notes in qibla_bearing.dart.
  final cases = <String, (double lat, double lon, double expectedBearing)>{
    'Cairo': (30.0444, 31.2357, 136.14),
    'Riyadh': (24.7136, 46.6753, 243.80),
    'Istanbul': (41.0082, 28.9784, 151.62),
    'London': (51.5072, -0.1276, 118.99),
    'New York': (40.7128, -74.0060, 58.48),
    'Jakarta': (-6.2088, 106.8456, 295.15),
    'Amman': (31.9454, 35.9284, 160.78),
  };

  for (final entry in cases.entries) {
    final (lat, lon, expected) = entry.value;
    test('${entry.key}: bearing to the Kaaba is ~$expected°', () {
      final bearing = qiblaBearingDegrees(lat, lon);
      expect(bearing, closeTo(expected, 0.05));
    });
  }

  test('always returns a value in [0, 360)', () {
    for (final entry in cases.entries) {
      final (lat, lon, _) = entry.value;
      final bearing = qiblaBearingDegrees(lat, lon);
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    }
  });

  test('standing at the Kaaba is a degenerate case, not a crash', () {
    expect(
      () => qiblaBearingDegrees(kKaabaLatitude, kKaabaLongitude),
      returnsNormally,
    );
  });

  group('isFacingQibla', () {
    // Regression test: the compass screen used to check `offset.abs() < 3`
    // instead of the combined `qiblah` value. `offset` is the bearing to
    // the Kaaba itself (e.g. ~136° for Cairo) and has no reason to be near
    // zero, so that check was nearly unreachable for real users — this
    // pins down the fix.
    test('true when qiblah is exactly 0 (device pointed at the Kaaba)', () {
      expect(isFacingQibla(0), isTrue);
    });

    test('true within tolerance just under the threshold', () {
      expect(isFacingQibla(2.9), isTrue);
      expect(isFacingQibla(-2.9), isTrue);
    });

    test('false just outside the threshold', () {
      expect(isFacingQibla(3.1), isFalse);
      expect(isFacingQibla(-3.1), isFalse);
    });

    test('handles wraparound near 360', () {
      expect(isFacingQibla(358), isTrue); // -2° normalized
      expect(isFacingQibla(361), isTrue); // 1° normalized
    });

    test(
      'a large nonzero offset (e.g. Cairo, ~136°) does not by itself '
      'mean aligned — only qiblah being near zero does',
      () {
        // This is exactly the bug: someone actually facing the Kaaba in
        // Cairo has qiblah == 0, not offset == 0.
        expect(isFacingQibla(136.14), isFalse);
      },
    );

    test('a real "facing Mecca in Cairo" scenario evaluates to aligned', () {
      const offset = 136.14; // Cairo's bearing to the Kaaba
      const heading = 136.14; // device heading equals that bearing
      final qiblah = heading + (360 - offset);
      expect(isFacingQibla(qiblah), isTrue);
    });
  });
}
