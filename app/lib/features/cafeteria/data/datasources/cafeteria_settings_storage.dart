import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 사용자의 학식 기본 건물 선호 — 학식 탭 진입 시 어느 건물을 자동 선택할지.
enum CafeteriaPreference {
  /// 군자관(sjapp 첫 건물). 평일 주 사용 케이스.
  gunja,

  /// 행복기숙사(가상 건물). 기숙사 거주 학생 + 주말.
  happydorm,
}

CafeteriaPreference? _parse(String? s) {
  switch (s) {
    case 'gunja':
      return CafeteriaPreference.gunja;
    case 'happydorm':
      return CafeteriaPreference.happydorm;
    default:
      return null;
  }
}

String _serialize(CafeteriaPreference p) {
  switch (p) {
    case CafeteriaPreference.gunja:
      return 'gunja';
    case CafeteriaPreference.happydorm:
      return 'happydorm';
  }
}

/// 학식 화면 설정(기본 건물). 첫 진입 시 null → 온보딩 다이얼로그 트리거.
class CafeteriaSettingsStorage {
  static const _filename = 'cafeteria_settings.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<CafeteriaPreference?> loadDefaultBuilding() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      if (txt.isEmpty) return null;
      final j = jsonDecode(txt) as Map<String, dynamic>;
      return _parse(j['defaultBuilding'] as String?);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDefaultBuilding(CafeteriaPreference pref) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'defaultBuilding': _serialize(pref)}));
    } catch (_) {}
  }
}
