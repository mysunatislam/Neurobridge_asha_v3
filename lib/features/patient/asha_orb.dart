import 'package:flutter/material.dart';

/// Non-human Asha presence: breathing orb with 7 states, text-labelled
/// (never color-only), reduced-motion aware.
class AshaOrb extends StatefulWidget {
  final String state; // idle|listening|thinking|speaking|monitoring|needs_attention|offline
  final double size;
  const AshaOrb({super.key, this.state = 'monitoring', this.size = 150});

  @override
  State<AshaOrb> createState() => _AshaOrbState();
}

class _AshaOrbState extends State<AshaOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Color glow = const Color(0xFF2DD4BF);
    String label = 'Asha ${widget.state}';
    if (widget.state == 'needs_attention') glow = const Color(0xFFFFC44D);
    if (widget.state == 'offline') glow = const Color(0xFF93A1BB);
    if (widget.state == 'speaking') glow = const Color(0xFF7DD3FC);
    final body = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [glow.withOpacity(0.9), const Color(0xFF0E3A3A)]),
        boxShadow: [BoxShadow(color: glow.withOpacity(0.35), blurRadius: 34, spreadRadius: 4)],
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('◉', style: TextStyle(fontSize: 44, color: Colors.white)),
          Text(widget.state.toUpperCase(),
              style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white70)),
        ]),
      ),
    );
    return Semantics(
      label: label,
      child: reduce
          ? body
          : AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Transform.scale(
                scale: 1.0 + _c.value * 0.05,
                child: body,
              ),
            ),
    );
  }
}
