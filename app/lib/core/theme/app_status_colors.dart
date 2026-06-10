import 'package:flutter/material.dart';

/// 출석/근태 상태 색상 토큰. 이전엔 ucheck 화면별로 file-private const로 복붙돼 있었음 —
/// 단일 SSOT로 통합.
abstract final class AppStatusColors {
  AppStatusColors._();

  static const present = Color(0xFF0CA886);
  static const lateArrival = Color(0xFFF59E0B);
  static const absent = Color(0xFF9E001F);
  static const earlyLeave = Color(0xFFF97316);
  static const midLeave = Color(0xFFF97316);
  static const holiday = Color(0xFF9E9E9E);
}
