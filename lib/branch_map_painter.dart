part of 'main.dart';

class BranchMapBackgroundPainter extends CustomPainter {
  const BranchMapBackgroundPainter({required this.colors});

  final AuraThemeColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.surfaceAlt, colors.surfaceSoft],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final gridPaint = Paint()
      ..color = colors.accent.withOpacity(0.12)
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BranchMapBackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
