/// Shared UI pieces — chips, cards, form labels (mirrors Chips.tsx + the
/// .card/.label/.btn styles in globals.css), plus the modern additions:
/// skeleton loaders, empty states and section headers used across screens.
library;

import 'package:flutter/material.dart';
import 'meta.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = statusStyle[status] ?? statusStyle['pending']!;
    return _pill(statusLabel[status] ?? status, s.bg, s.fg,
        icon: statusIcon[status]);
  }
}

class OverdueChip extends StatelessWidget {
  const OverdueChip({super.key});

  @override
  Widget build(BuildContext context) =>
      _pill('Overdue', C.red50, C.red700, icon: Icons.warning_amber_rounded);
}

class CategoryChip extends StatelessWidget {
  final String category;
  const CategoryChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) =>
      _pill(categoryLabel[category] ?? category, C.emerald50, C.emerald900);
}

Widget _pill(String text, Color bg, Color fg, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ],
    ),
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final Color? leftBorder;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.leftBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      foregroundDecoration: leftBorder == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: leftBorder!, width: 4)),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
    return card;
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: C.gray600)),
    );
  }
}

InputDecoration inputDecoration({String? hint, IconData? icon}) =>
    InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20, color: C.gray400),
      isDense: true,
      filled: true,
      fillColor: C.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.emerald700, width: 2),
      ),
    );

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(
      children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: error ? C.red700 : C.emerald800,
  ));
}

/// Pulsing gray block used to build skeleton loading placeholders.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;
  const SkeletonBox({super.key, required this.height, this.width, this.radius});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(C.gray100, C.gray200, _c.value),
          borderRadius: widget.radius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// A page-shaped skeleton: a couple of stat-tile-sized blocks and a few
/// card-sized blocks, used while a screen's first load is in flight.
class SkeletonList extends StatelessWidget {
  final int cards;
  const SkeletonList({super.key, this.cards = 3});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (var i = 0; i < cards; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonBox(
              height: 96,
              radius: BorderRadius.circular(16),
            ),
          ),
      ],
    );
  }
}

/// Friendly "nothing here" placeholder used across empty lists.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: C.emerald50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: C.emerald700, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: C.gray500)),
          ],
        ],
      ),
    );
  }
}

/// Consistent icon + title used above each dashboard/section block.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: C.emerald50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: C.emerald700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(fontSize: 11, color: C.gray500)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Modern stat tile with an icon badge, used on the dashboard.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String big;
  final String cap;
  final bool alert;
  const StatTile({
    super.key,
    required this.icon,
    required this.big,
    required this.cap,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: alert ? C.red50 : C.emerald50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: alert ? C.red600 : C.emerald700),
          ),
          const SizedBox(height: 10),
          Text(big,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: alert ? C.red600 : C.text)),
          Text(cap, style: const TextStyle(fontSize: 11.5, color: C.gray500)),
        ],
      ),
    );
  }
}
