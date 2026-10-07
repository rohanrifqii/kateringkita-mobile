import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(37),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(37),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Home',
                  iconBuilder: (color, size) => FigmaHomeIcon(
                    color: color,
                    size: size,
                  ),
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Orders',
                  iconBuilder: (color, size) => Icon(
                    Icons.assignment_outlined,
                    color: color,
                    size: size,
                  ),
                ),
                _buildNavItem(
                  index: 2,
                  label: 'AI',
                  iconBuilder: (color, size) => FigmaAiIcon(
                    color: color,
                    size: size,
                  ),
                ),
                _buildNavItem(
                  index: 3,
                  label: 'Liked',
                  iconBuilder: (color, size) => Icon(
                    currentIndex == 3
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: color,
                    size: size,
                  ),
                ),
                _buildNavItem(
                  index: 4,
                  label: 'Profile',
                  iconBuilder: (color, size) => Icon(
                    Icons.account_circle_outlined,
                    color: color,
                    size: size,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required Widget Function(Color color, double size) iconBuilder,
  }) {
    final isSelected = currentIndex == index;
    const inactiveColor = Color(0xFF2E2A27);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          child: isSelected
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: iconBuilder(Colors.white, 20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: iconBuilder(inactiveColor, 24),
                ),
        ),
      ),
    );
  }
}

/// Custom vector painter representing the exact Home icon from Figma
class FigmaHomeIcon extends StatelessWidget {
  final Color color;
  final double size;

  const FigmaHomeIcon({
    super.key,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _FigmaHomeIconPainter(color: color),
      ),
    );
  }
}

class _FigmaHomeIconPainter extends CustomPainter {
  final Color color;

  _FigmaHomeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final sx = w / 24.0;
    final sy = h / 24.0;

    // 1. Top curved arc
    final topArc = Path();
    topArc.moveTo(7.5 * sx, 4.2 * sy);
    topArc.quadraticBezierTo(12.0 * sx, 1.8 * sy, 16.5 * sx, 4.2 * sy);
    canvas.drawPath(topArc, paint);

    // 2. Main dome structure with arched door notch at the bottom center
    final body = Path();
    body.moveTo(10.0 * sx, 20.5 * sy);
    body.lineTo(5.5 * sx, 20.5 * sy);
    body.lineTo(5.5 * sx, 12.0 * sy);
    body.quadraticBezierTo(5.5 * sx, 6.8 * sy, 12.0 * sx, 6.8 * sy);
    body.quadraticBezierTo(18.5 * sx, 6.8 * sy, 18.5 * sy, 12.0 * sy);
    body.lineTo(18.5 * sx, 20.5 * sy);
    body.lineTo(14.0 * sx, 20.5 * sy);
    body.lineTo(14.0 * sx, 17.5 * sy);
    body.quadraticBezierTo(12.0 * sx, 15.5 * sy, 10.0 * sx, 17.5 * sy);
    body.lineTo(10.0 * sx, 20.5 * sy);

    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant _FigmaHomeIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Custom vector painter representing the upright, centered AI lightbulb icon with '+' sparkle
class FigmaAiIcon extends StatelessWidget {
  final Color color;
  final double size;

  const FigmaAiIcon({
    super.key,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _FigmaAiIconPainter(color: color),
      ),
    );
  }
}

class _FigmaAiIconPainter extends CustomPainter {
  final Color color;

  _FigmaAiIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final sx = w / 24.0;
    final sy = h / 24.0;

    // Centered bulb body: cx = 11.2 keeps the whole composition (bulb + plus sign) centered at 12.0
    const cx = 11.2;
    const r = 4.8;

    // 1. Bulb dome and neck
    final bulbPath = Path();
    bulbPath.moveTo((cx - 2.2) * sx, 15.6 * sy);
    bulbPath.lineTo((cx - 2.6) * sx, 12.8 * sy);
    bulbPath.arcToPoint(
      Offset((cx + 2.6) * sx, 12.8 * sy),
      radius: Radius.circular(r * sx),
      largeArc: true,
      clockwise: true,
    );
    bulbPath.lineTo((cx + 2.2) * sx, 15.6 * sy);
    bulbPath.lineTo((cx - 2.2) * sx, 15.6 * sy);
    canvas.drawPath(bulbPath, paint);

    // 2. Base screw ridge
    canvas.drawLine(
      Offset((cx - 1.6) * sx, 17.6 * sy),
      Offset((cx + 1.6) * sx, 17.6 * sy),
      paint,
    );

    // 3. Bottom rounded cap
    final cap = Path();
    cap.moveTo((cx - 1.0) * sx, 19.3 * sy);
    cap.quadraticBezierTo(cx * sx, 20.6 * sy, (cx + 1.0) * sx, 19.3 * sy);
    canvas.drawPath(cap, paint);

    // 4. Upright '+' sparkle at top-right
    const plusX = 17.6;
    const plusY = 5.2;
    canvas.drawLine(
      Offset((plusX - 1.8) * sx, plusY * sy),
      Offset((plusX + 1.8) * sx, plusY * sy),
      paint,
    );
    canvas.drawLine(
      Offset(plusX * sx, (plusY - 1.8) * sy),
      Offset(plusX * sx, (plusY + 1.8) * sy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FigmaAiIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
