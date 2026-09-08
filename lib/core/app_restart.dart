import 'package:flutter/material.dart';

/// Wraps the app so any descendant can force the *entire* widget subtree
/// below this point to be torn down and rebuilt from scratch (see
/// [restart]), briefly showing a splash screen while it happens.
///
/// Why this exists: most of this app's theming (see AppColors/
/// AppTextStyles) is read from plain mutable static fields rather than
/// through Theme.of(context)/an InheritedWidget, and a mutation to those
/// fields doesn't by itself mark every descendant dirty — only widgets
/// that happen to get rebuilt some other way (their own setState, a
/// provider they watch, etc.) actually repaint with the new values. That
/// left some screens visibly stale after toggling dark mode or changing
/// the language until something else happened to rebuild them. Swapping
/// this widget's Key forces Flutter to dispose and recreate every Element
/// underneath — including ones that would otherwise never have rebuilt on
/// their own — which is a blunt fix, but a reliable one, for this
/// specific architecture. It's applied deliberately only around dark
/// mode/language changes, not as a general-purpose pattern.
class AppRestart extends StatefulWidget {
  final Widget child;
  const AppRestart({super.key, required this.child});

  /// Call after the actual settings change has already been applied
  /// (e.g. after `await themeModeProvider.notifier.setDark(v)` or
  /// `await context.setLocale(...)` has finished) — the rebuilt tree below
  /// reads whatever state is current at that moment.
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartState>()?._restart();
  }

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  Key _key = UniqueKey();
  bool _showSplash = false;

  Future<void> _restart() async {
    setState(() => _showSplash = true);
    // One frame's worth of headroom for the splash to actually paint
    // before the old tree underneath gets torn down.
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      _key = UniqueKey();
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const _RestartSplash();
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// Mirrors flutter_native_splash's own configuration (see pubspec.yaml)
/// so this reads as a continuation of the same splash rather than a
/// visibly different screen.
class _RestartSplash extends StatelessWidget {
  const _RestartSplash();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEE8DC),
      child: Center(
        child: Image.asset(
          'assets/icon/app_icon_source.png',
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
