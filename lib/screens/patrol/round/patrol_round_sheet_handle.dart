part of '../patrol_round_screen.dart';

/// Thanh kéo: vuốt nhẹ (hoặc flick nhỏ) lên/xuống là đóng sheet.
class _SheetVerticalDismissHandle extends StatefulWidget {
  const _SheetVerticalDismissHandle({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_SheetVerticalDismissHandle> createState() =>
      _SheetVerticalDismissHandleState();
}

class _SheetVerticalDismissHandleState extends State<_SheetVerticalDismissHandle> {
  double _dragY = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _dragY = 0,
      onVerticalDragUpdate: (d) => _dragY += d.delta.dy,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() > 85 || _dragY.abs() > 14) {
          widget.onDismiss();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

