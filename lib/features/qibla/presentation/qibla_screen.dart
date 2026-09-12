import 'dart:math' show pi, sin, cos;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart'
    show Geolocator, LocationPermission, Position;
import '../../../core/qibla/qibla_bearing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  Future<_QiblaReadiness>? _readinessFuture;

  @override
  void initState() {
    super.initState();
    _readinessFuture = _checkReadiness();
  }

  @override
  void dispose() {
    FlutterQiblah().dispose();
    super.dispose();
  }

  Future<_QiblaReadiness> _checkReadiness() async {
    final status = await FlutterQiblah.checkLocationStatus();
    if (!status.enabled) return _QiblaReadiness.gpsOff;
    if (status.status == LocationPermission.denied) {
      return _QiblaReadiness.needsPermission;
    }
    if (status.status == LocationPermission.deniedForever) {
      return _QiblaReadiness.deniedForever;
    }
    // flutter_qiblah's own androidDeviceSensorSupport() call returns true
    // unconditionally on non-Android — no need to branch by platform here.
    final hasSensor = await FlutterQiblah.androidDeviceSensorSupport();
    if (hasSensor == false) return _QiblaReadiness.noSensor;
    return _QiblaReadiness.ready;
  }

  void _recheck() => setState(() => _readinessFuture = _checkReadiness());

  Future<void> _requestAndRecheck() async {
    await FlutterQiblah.requestPermissions();
    _recheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SubScreenHeader(
            bottomPadding: 50,
            child: SubScreenTitleRow(title: 'qibla_screen.title'.tr()),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<_QiblaReadiness>(
              future: _readinessFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return _StatusCard(
                    icon: Icons.explore_outlined,
                    message: 'qibla_screen.checking'.tr(),
                    loading: true,
                  );
                }

                switch (snapshot.data!) {
                  case _QiblaReadiness.gpsOff:
                    return _StatusCard(
                      icon: Icons.location_off_outlined,
                      message: 'qibla_screen.gps_off'.tr(),
                      actionLabel: 'qibla_screen.enable_location'.tr(),
                      onAction: () async {
                        await Geolocator.openLocationSettings();
                        _recheck();
                      },
                    );
                  case _QiblaReadiness.needsPermission:
                    return _StatusCard(
                      icon: Icons.location_off_outlined,
                      message: 'qibla_screen.location_needed'.tr(),
                      actionLabel: 'qibla_screen.enable_location'.tr(),
                      onAction: _requestAndRecheck,
                    );
                  case _QiblaReadiness.deniedForever:
                    return _StatusCard(
                      icon: Icons.location_off_outlined,
                      message: 'qibla_screen.permission_denied_forever'.tr(),
                      actionLabel: 'qibla_screen.open_settings'.tr(),
                      onAction: () async {
                        await Geolocator.openAppSettings();
                        _recheck();
                      },
                    );
                  case _QiblaReadiness.noSensor:
                    return _StatusCard(
                      icon: Icons.explore_off_outlined,
                      message: 'qibla_screen.sensor_unsupported'.tr(),
                    );
                  case _QiblaReadiness.ready:
                    return const _CompassCard();
                }
              },
            ),
          ),
        ),
      ],
      ),
    );
  }
}

enum _QiblaReadiness { gpsOff, needsPermission, deniedForever, noSensor, ready }

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusCard({
    required this.icon,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(icon, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.8,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompassCard extends StatefulWidget {
  const _CompassCard();

  @override
  State<_CompassCard> createState() => _CompassCardState();
}

class _CompassCardState extends State<_CompassCard> {
  bool _wasAligned = false;

  // A static bearing computed from location alone (not the live compass),
  // so it stays correct even if the device's magnetometer needs
  // calibration — a fixed number the user can cross-check the needle
  // against. Best-effort: if this fails, the needle still works on its own.
  double? _staticBearing;

  @override
  void initState() {
    super.initState();
    Geolocator.getCurrentPosition()
        .then((Position pos) {
          if (!mounted) return;
          setState(
            () => _staticBearing = qiblaBearingDegrees(
              pos.latitude,
              pos.longitude,
            ),
          );
        })
        .catchError((_) {});
  }

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String _ar(int n) =>
      n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  /// Arabic-Indic digits in the Arabic UI only; the English UI used to show
  /// the bearing in Arabic digits too.
  static String _digits(BuildContext context, int n) =>
      context.locale.languageCode == 'ar' ? _ar(n) : '$n';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.primaryTint],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_staticBearing != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${'qibla_screen.fixed_bearing'.tr()} ${_digits(context, _staticBearing!.round())}°',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'qibla_screen.point_device'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 30),
          StreamBuilder<QiblahDirection>(
            stream: FlutterQiblah.qiblahStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: 280,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'qibla_screen.stream_error'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 280,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }
              final data = snapshot.data!;
              final aligned = isFacingQibla(data.qiblah);
              if (aligned && !_wasAligned) {
                HapticFeedback.mediumImpact();
              }
              _wasAligned = aligned;

              return Column(
                children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: aligned
                                ? [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        // Compass face: rotates opposite the device heading so
                        // its printed cardinal labels stay geographically correct.
                        AnimatedRotation(
                          turns: -data.direction / 360,
                          duration: const Duration(milliseconds: 150),
                          child: _CompassFace(highlighted: aligned),
                        ),
                        // Qibla needle: rotates by the angle to Mecca relative
                        // to the (already-corrected) compass face.
                        AnimatedRotation(
                          turns: -data.qiblah / 360,
                          duration: const Duration(milliseconds: 150),
                          child: _QiblaNeedle(aligned: aligned),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '${'qibla_screen.your_heading'.tr()} · ${data.direction.round()}${'qibla_screen.degrees'.tr()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: aligned ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.gold, AppColors.goldLight],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'qibla_screen.aligned'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'qibla_screen.calibration_hint'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompassFace extends StatelessWidget {
  final bool highlighted;
  const _CompassFace({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: highlighted ? AppColors.gold : AppColors.border,
          width: 3,
        ),
      ),
      child: CustomPaint(
        painter: _TickPainter(color: AppColors.divider),
        child: Stack(
          alignment: Alignment.center,
          children: const [
            _CardinalLabel(label: 'N', alignment: Alignment.topCenter),
            _CardinalLabel(label: 'S', alignment: Alignment.bottomCenter),
            _CardinalLabel(label: 'E', alignment: Alignment.centerRight),
            _CardinalLabel(label: 'W', alignment: Alignment.centerLeft),
          ],
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final Color color;
  _TickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    for (var deg = 0; deg < 360; deg += 15) {
      final rad = deg * pi / 180;
      final isMajor = deg % 90 == 0;
      final inner = radius - (isMajor ? 16 : 10);
      final outer = radius - 4;
      final start = Offset(
        center.dx + inner * sin(rad),
        center.dy - inner * cos(rad),
      );
      final end = Offset(
        center.dx + outer * sin(rad),
        center.dy - outer * cos(rad),
      );
      paint.strokeWidth = isMajor ? 2 : 1;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CardinalLabel extends StatelessWidget {
  final String label;
  final Alignment alignment;
  const _CardinalLabel({required this.label, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QiblaNeedle extends StatelessWidget {
  final bool aligned;
  const _QiblaNeedle({required this.aligned});

  @override
  Widget build(BuildContext context) {
    final color = aligned ? AppColors.gold : AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kaaba marker at the needle's tip — the thing you're actually
        // pointing at, rather than a bare arrowhead.
        _KaabaMarker(color: color),
        Icon(Icons.arrow_drop_up_rounded, size: 26, color: color),
        Container(width: 3, height: 74, color: color.withValues(alpha: 0.3)),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Center(
            child: KhatimGlyph(size: 16, color: Colors.white, strokeWidth: 2),
          ),
        ),
      ],
    );
  }
}

/// Simple Kaaba glyph: the cube with its gold kiswah band. Drawn rather
/// than pulled from an icon font — Material has no Kaaba icon.
class _KaabaMarker extends StatelessWidget {
  final Color color;
  const _KaabaMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The kiswah's embroidered band sits in the cube's upper third.
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            height: 5,
            width: 44,
            color: AppColors.goldLight,
          ),
        ],
      ),
    );
  }
}
