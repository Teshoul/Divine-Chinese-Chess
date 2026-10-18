import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'board_draw.dart';

Route<void> fadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

class Reveal extends StatelessWidget {
  final Animation<double> parent;
  final int index;
  final Widget child;
  const Reveal(
      {super.key,
      required this.parent,
      required this.index,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final start = min(index * 0.12, 0.6);
    final a = CurvedAnimation(
        parent: parent,
        curve: Interval(start, min(start + 0.4, 1.0),
            curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }
}

class PressCard extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const PressCard(
      {super.key,
      required this.color,
      required this.icon,
      required this.title,
      required this.sub,
      this.onTap});

  @override
  State<PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<PressCard> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color.withOpacity(0.95),
                widget.color.withOpacity(0.6)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.sub,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

Widget sideTag(BuildContext context, Side s,
    {required bool active, bool mine = false}) {
  final col = s == Side.red ? kRedC : kBlackC;
  final cs = Theme.of(context).colorScheme;
  final txt = active ? Colors.white : (s == Side.red ? kRedC : cs.onSurface);
  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: active ? col : col.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: col.withOpacity(active ? 1.0 : 0.35), width: 1.5),
    ),
    child: Text('${s.cn}${mine ? '（你）' : ''}',
        style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
  );
}
