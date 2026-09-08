import 'dart:math';

/// The Kaaba's coordinates — the same reference point flutter_qiblah uses
/// internally (its own copy isn't part of the package's public API, so
/// this is a small independent copy, not a duplicate import).
const kKaabaLatitude = 21.422487;
const kKaabaLongitude = 39.826206;

/// Great-circle initial bearing (0–360°, clockwise from true north) from
/// [latitude]/[longitude] to the Kaaba — the standard forward-azimuth
/// formula. Verified against reference bearings for several cities (see
/// qibla_bearing_test.dart), including cross-checking flutter_qiblah's own
/// (unexported, so not directly testable) internal formula produces the
/// same values.
///
/// Shown in the UI as a static number alongside the live compass needle:
/// the needle depends on the device's magnetometer, which drifts and needs
/// periodic calibration, but this number depends only on location and
/// stays correct regardless — a way for the user to sanity-check the
/// needle against a fixed reference.
double qiblaBearingDegrees(double latitude, double longitude) {
  final phi1 = latitude * pi / 180;
  final phi2 = kKaabaLatitude * pi / 180;
  final deltaLambda = (kKaabaLongitude - longitude) * pi / 180;

  final y = sin(deltaLambda) * cos(phi2);
  final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
  final bearing = atan2(y, x) * 180 / pi;
  return (bearing + 360) % 360;
}

/// Normalizes any angle in degrees to (-180, 180] — the signed "how far
/// off, and which way" form needed to test alignment or draw a turn hint.
double normalizeAngleDegrees(double degrees) {
  var d = degrees % 360;
  if (d <= -180) d += 360;
  if (d > 180) d -= 360;
  return d;
}

/// Whether the device is currently pointed at the Qibla, given
/// flutter_qiblah's combined `qiblah` value (device heading adjusted by
/// the bearing to the Kaaba — see QiblahDirection). The needle's on-screen
/// rotation is `-qiblah`, so "pointing straight up" (i.e. aligned) is
/// `qiblah ≈ 0 (mod 360)` — *not* `offset ≈ 0`, which is the bearing to
/// the Kaaba itself and has no reason to be near zero for most locations
/// on Earth (e.g. ~136° for Cairo, ~244° for Riyadh). Comparing against
/// `offset` was the bug: it made the "aligned" state nearly unreachable
/// for almost every real user.
bool isFacingQibla(double qiblah, {double toleranceDegrees = 3}) =>
    normalizeAngleDegrees(qiblah).abs() < toleranceDegrees;
