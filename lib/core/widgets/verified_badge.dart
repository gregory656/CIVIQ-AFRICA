import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class CiviqVerifiedBadge extends StatelessWidget {
  const CiviqVerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified account',
      child: CustomPaint(
        size: Size.square(size),
        painter: _VerifiedBadgePainter(),
        child: SizedBox.square(
          dimension: size,
          child: Icon(Icons.check, size: size * 0.68, color: AppColors.white),
        ),
      ),
    );
  }
}

class _VerifiedBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A66C2)
      ..style = PaintingStyle.fill;
    final path = Path();
    final points = <Offset>[
      Offset(size.width * 0.50, 0),
      Offset(size.width * 0.62, size.height * 0.10),
      Offset(size.width * 0.78, size.height * 0.07),
      Offset(size.width * 0.88, size.height * 0.22),
      Offset(size.width, size.height * 0.32),
      Offset(size.width * 0.94, size.height * 0.50),
      Offset(size.width, size.height * 0.68),
      Offset(size.width * 0.84, size.height * 0.78),
      Offset(size.width * 0.78, size.height * 0.94),
      Offset(size.width * 0.60, size.height * 0.90),
      Offset(size.width * 0.50, size.height),
      Offset(size.width * 0.38, size.height * 0.90),
      Offset(size.width * 0.22, size.height * 0.94),
      Offset(size.width * 0.12, size.height * 0.78),
      Offset(0, size.height * 0.68),
      Offset(size.width * 0.06, size.height * 0.50),
      Offset(0, size.height * 0.32),
      Offset(size.width * 0.16, size.height * 0.22),
      Offset(size.width * 0.22, size.height * 0.07),
      Offset(size.width * 0.40, size.height * 0.10),
    ];
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
