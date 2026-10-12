import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The roulette button: a breathing, gradient "casino" button whose dice spins
/// while a roll is in flight. Pure Flutter animations — no packages.
class RouletteButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool busy;

  const RouletteButton({super.key, this.onPressed, this.busy = false});

  @override
  State<RouletteButton> createState() => _RouletteButtonState();
}

class _RouletteButtonState extends State<RouletteButton> with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 850));

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant RouletteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _syncSpin();
  }

  void _syncSpin() {
    if (widget.busy) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _spin]),
      builder: (context, _) {
        final t = _pulse.value;
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(scheme.primary, scheme.tertiary, t)!,
            Color.lerp(scheme.tertiary, scheme.secondary, t)!,
          ],
        );
        // Idle: gentle breathing scale + glow. Busy: a touch of extra pop.
        final scale = 1 + (widget.busy ? 0.02 : 0.035 * t);
        final glow = scheme.primary.withAlpha((120 + 90 * t).round());

        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(color: glow, blurRadius: 22 + 14 * t, spreadRadius: 1),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: enabled ? widget.onPressed : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Idle: the die gently rocks. Busy: it spins flat out.
                      widget.busy
                          ? RotationTransition(
                              turns: _spin,
                              child: const Icon(Icons.casino, color: Colors.white, size: 30),
                            )
                          : Transform.rotate(
                              angle: math.sin(t * math.pi * 2) * 0.18,
                              child: const Icon(Icons.casino, color: Colors.white, size: 30),
                            ),
                      const SizedBox(width: 12),
                      Text(
                        widget.busy ? 'Rolling…' : 'Change random wallpaper',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
