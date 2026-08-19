/// Labels, colors and formatting — mirrors src/lib/meta.ts + Tailwind palette.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';

const statusLabel = <String, String>{
  'pending': 'Pending',
  'in_progress': 'In Progress',
  'submitted': 'Submitted',
  'approved': 'Approved',
  'returned': 'Returned',
};

const categoryLabel = <String, String>{
  'attendance': '📋 Attendance',
  'finance': '💰 Finance',
  'inventory': '📦 Inventory',
  'announcement': '📢 Announcement',
  'poc_data': '👥 POC / Data',
  'other': '📝 Other',
};

final categories = categoryLabel.keys.toList();

/// App palette (Tailwind equivalents used by the web app).
abstract final class C {
  static const bg = Color(0xFFF6F8F7);
  static const text = Color(0xFF1C2321);
  static const border = Color(0xFFE2E8E4);
  // Atfal brand — sampled directly from the logo's background gradient.
  static const brand50 = Color(0xFFFCEAE6);
  static const brand100 = Color(0xFFF8D2C8);
  static const brand200 = Color(0xFFF0AC9C);
  static const brand600 = Color(0xFFD5532F);
  static const brand700 = Color(0xFFA92425);
  static const brand800 = Color(0xFF89181E);
  static const brand900 = Color(0xFF5C1015);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue700 = Color(0xFF1D4ED8);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const red50 = Color(0xFFFEF2F2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);

  /// Soft header gradient used behind the login hero and section banners —
  /// mirrors the logo's own background gradient (deep maroon → orange).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand800, brand700, brand600],
  );
}

/// Icon shown per task category (leading glyph in categoryLabel already
/// carries an emoji; this is used where a Material icon reads cleaner).
const categoryIcon = <String, IconData>{
  'attendance': Icons.checklist_rounded,
  'finance': Icons.payments_outlined,
  'inventory': Icons.inventory_2_outlined,
  'announcement': Icons.campaign_outlined,
  'poc_data': Icons.groups_outlined,
  'other': Icons.notes_outlined,
};

const statusIcon = <String, IconData>{
  'pending': Icons.schedule_outlined,
  'in_progress': Icons.autorenew_rounded,
  'submitted': Icons.upload_file_outlined,
  'approved': Icons.check_circle_outline_rounded,
  'returned': Icons.replay_rounded,
};

class StatusStyle {
  final Color bg;
  final Color fg;
  final String letter;
  const StatusStyle(this.bg, this.fg, this.letter);
}

const statusStyle = <String, StatusStyle>{
  'pending': StatusStyle(C.gray100, C.gray600, 'P'),
  'in_progress': StatusStyle(C.blue50, C.blue700, 'I'),
  'submitted': StatusStyle(C.amber50, C.amber700, 'S'),
  'approved': StatusStyle(C.brand50, C.brand700, 'A'),
  'returned': StatusStyle(C.red50, C.red700, 'R'),
};

String fmtDate(String? d) {
  if (d == null || d.isEmpty) return '—';
  final dt = DateTime.parse(d.length == 10 ? '${d}T00:00:00' : d).toLocal();
  return DateFormat('d MMM y').format(dt);
}

String fmtTime(String d) =>
    DateFormat('d MMM, HH:mm').format(DateTime.parse(d).toLocal());

bool isOverdue(Task t, String status) {
  final due = t.dueDate;
  if (due == null || due.isEmpty) return false;
  if (status == 'approved' || status == 'submitted') return false;
  return DateTime.parse('${due}T23:59:59').isBefore(DateTime.now());
}
