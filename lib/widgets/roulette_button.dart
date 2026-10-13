import 'package:flutter/material.dart';

/// The roulette button: a rounded gradient pill with a soft glow. Deliberately
/// understated — the only motion is the die spinning while a roll is in flight
/// (real feedback) plus a faint gradient sweep on the same condition.
class RouletteButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool busy;

  const RouletteButton({super.key, this.onPressed, this.busy = false});

  @override
  State<RouletteButton> createState() => _RouletteButtonState();
}

class _RouletteButtonState extends State<RouletteButton> with SingleTickerProviderStateMixin {
  /// Drives both the die spin and the gradient sweep; only runs while busy.
  late final AnimationController _roll =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _syncRoll();
  }

  @override
  void didUpdateWidget(covariant RouletteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _syncRoll();
  }

  void _syncRoll() {
    if (widget.busy) {
      if (!_roll.isAnimating) _roll.repeat();
    } else {
      _roll.stop();
      _roll.value = 0;
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _roll,
      builder: (context, _) {
        final t = widget.busy ? _roll.value : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 + 2 * t, 1),
              colors: [scheme.primary, scheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withAlpha(90),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: enabled ? widget.onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 17),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.busy
                        ? RotationTransition(turns: _roll, child: const Icon(Icons.casino, color: Colors.white, size: 28))
                        : const Icon(Icons.casino, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      widget.busy ? 'Rolling…' : 'Change random wallpaper',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
