import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/formatters.dart';

/// Teks angka dengan animasi *count-up*: nilai lama berjalan naik/turun menuju
/// nilai baru alih-alih berganti seketika. Membuat statistik terasa "hidup".
class AnimatedCountText extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}

/// Seperti [AnimatedCountText] tapi diformat sebagai mata uang Rupiah.
class AnimatedCurrencyText extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCurrencyText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        Formatters.formatCurrency(v.round()),
        style: style,
      ),
    );
  }
}

/// Chip statistik yang: (1) menghitung angka secara *count-up*, dan (2)
/// melakukan *scale pulse* singkat setiap kali nilainya berubah, sehingga
/// pengguna langsung tahu ada yang diperbarui.
class AnimatedStatChip extends StatefulWidget {
  final String label;
  final int value;
  final Color color;

  const AnimatedStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  State<AnimatedStatChip> createState() => _AnimatedStatChipState();
}

class _AnimatedStatChipState extends State<AnimatedStatChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseC;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseC, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant AnimatedStatChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _pulseC.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.label}: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.color,
              ),
            ),
            AnimatedCountText(
              value: widget.value,
              duration: const Duration(milliseconds: 450),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
