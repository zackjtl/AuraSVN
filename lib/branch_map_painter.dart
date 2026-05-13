part of 'main.dart';

class BranchMapBackgroundPainter extends CustomPainter {
  const BranchMapBackgroundPainter({required this.colors});

  final AuraThemeColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.background,
    );
  }

  @override
  bool shouldRepaint(covariant BranchMapBackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
