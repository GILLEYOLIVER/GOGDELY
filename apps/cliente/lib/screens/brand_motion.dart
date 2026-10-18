import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';

import 'client_components.dart';
import 'intro_horn.dart';

const courierMascotAsset = 'assets/images/courier-mascot.png';

/// Original GOGDELY mark. The short entrance animation settles so it does not
/// keep rebuilding the navigation header or interfere with reduced motion.
class AnimatedBrandLogo extends StatefulWidget {
  const AnimatedBrandLogo({super.key});

  @override
  State<AnimatedBrandLogo> createState() => _AnimatedBrandLogoState();
}

class _AnimatedBrandLogoState extends State<AnimatedBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'GOGDELY',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = reduceMotion
                ? 1.0
                : Curves.easeOutBack.transform(_controller.value);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Transform.translate(
                offset: Offset((1 - progress) * -18, (1 - progress) * 3),
                child: Image.asset(courierMascotAsset,
                    width: 43, height: 34, fit: BoxFit.contain),
              ),
              const SizedBox(width: 3),
              const BrandWordmark(size: 19),
            ]);
          },
        ),
      ),
    );
  }
}

/// A brief in-app opening. It is skippable and ends immediately when the
/// platform requests reduced motion. There is no remote video or brand asset.
class BrandIntro extends StatefulWidget {
  const BrandIntro({super.key, required this.onFinished, this.onHorn});

  final VoidCallback onFinished;
  final VoidCallback? onHorn;

  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishTimer = Timer(const Duration(milliseconds: 350), _finish);
      }
    });
  Timer? _finishTimer;
  Timer? _secondManualHorn;
  bool _started = false;
  bool _finished = false;
  int _hornsPlayed = 0;
  bool _soundEnabledByTap = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _controller.addListener(_playHornsAtStop);
      _controller.forward();
    }
  }

  void _playHornsAtStop() {
    final progress = _controller.value;
    final target = progress >= .51 ? 2 : (progress >= .39 ? 1 : 0);
    while (_hornsPlayed < target) {
      _hornsPlayed++;
      (widget.onHorn ?? playIntroHorn)();
    }
  }

  void _enableHornSound() {
    if (_soundEnabledByTap) return;
    setState(() => _soundEnabledByTap = true);
    _hornsPlayed = 2;
    (widget.onHorn ?? playIntroHorn)();
    _secondManualHorn = Timer(const Duration(milliseconds: 620), () {
      if (mounted && !_finished) (widget.onHorn ?? playIntroHorn)();
    });
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _secondManualHorn?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: GogdelyColors.graphite,
        child: LayoutBuilder(builder: (context, bounds) {
          final width = bounds.maxWidth;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final value = _controller.value;
              final rideIn = Curves.easeOutCubic
                  .transform(((value - .04) / .27).clamp(0.0, 1.0));
              final rideOut = Curves.easeInCubic
                  .transform(((value - .68) / .26).clamp(0.0, 1.0));
              final reveal = Curves.easeOut
                  .transform(((value - .25) / .22).clamp(0.0, 1.0));
              final firstHorn = value >= .39 && value < .44;
              final secondHorn = value >= .51 && value < .56;
              return Stack(children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: GogdelyColors.graphite),
                  ),
                ),
                Positioned(
                  left: -width * .3,
                  right: -width * .3,
                  bottom: bounds.maxHeight * .27,
                  child: Container(
                    height: 3,
                    color: Colors.white
                        .withValues(alpha: .16 * rideIn * (1 - rideOut)),
                  ),
                ),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Transform.translate(
                        offset: Offset(
                          (rideIn - 1) * width * 1.05 + rideOut * width * 1.24,
                          value < .31 || value >= .68
                              ? math.sin(value * math.pi * 5) *
                                  3 *
                                  rideIn *
                                  (1 - rideOut)
                              : 0,
                        ),
                        child: Image.asset(courierMascotAsset,
                            key: const Key('intro-motorcycle'),
                            width: math.min(width * .80, 380),
                            height: math.min(bounds.maxHeight * .40, 300),
                            fit: BoxFit.contain),
                      ),
                      if (firstHorn || secondHorn)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Semantics(
                            label: 'Buzina',
                            child: Container(
                              key: Key(
                                  firstHorn ? 'intro-horn-1' : 'intro-horn-2'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: GogdelyColors.blue,
                                  borderRadius: BorderRadius.circular(18)),
                              child: const Text('BIP!',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: reveal,
                      child: Transform.scale(
                        scale: .86 + .14 * reveal,
                        child: const Text('gogdely.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.5,
                            )),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Opacity(
                      opacity: reveal,
                      child: const Text('Tudo chega mais perto.',
                          style: TextStyle(
                              color: Color(0xFFE7EFFF),
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: reveal,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ]),
                ),
                Positioned(
                  top: 0,
                  right: 8,
                  child: SafeArea(
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Pular',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                if (value >= .31 && value < .66 && !_soundEnabledByTap)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bounds.maxHeight * .14,
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _enableHornSound,
                        icon: const Icon(Icons.volume_up_outlined,
                            color: Colors.white),
                        label: const Text('Toque para ouvir as buzinas',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
              ]);
            },
          );
        }),
      );
}
