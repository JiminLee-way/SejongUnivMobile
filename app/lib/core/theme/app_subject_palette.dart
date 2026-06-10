import 'package:flutter/material.dart';

/// 시간표 강의·친구 아바타 그라데이션 팔레트 8종.
/// timetable / friend_timetable / common_free_time 3개 화면에서 동일하게 사용 — SSOT.
abstract final class AppSubjectPalette {
  AppSubjectPalette._();

  static const gradients = <List<Color>>[
    [Color(0xFFFCA5A5), Color(0xFFEF4444)],
    [Color(0xFFFCD34D), Color(0xFFD97706)],
    [Color(0xFF93C5FD), Color(0xFF2563EB)],
    [Color(0xFFA7F3D0), Color(0xFF059669)],
    [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
    [Color(0xFFF9A8D4), Color(0xFFDB2777)],
    [Color(0xFF99F6E4), Color(0xFF0D9488)],
    [Color(0xFFFDBA74), Color(0xFFEA580C)],
  ];
}
