import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/holidays/domain/entities/holiday.dart';

/// Supabase-backed holiday read-only adapter.
class SupabaseHolidayRemote {
  SupabaseHolidayRemote(this._client);
  final SupabaseClient _client;

  /// [year] 전체 휴일 list. is_holiday=true만 (기념일/평일은 제외).
  Future<List<Holiday>> fetchYear(int year) async {
    final from = '$year-01-01';
    final to = '$year-12-31';
    final rows = await _client
        .from(SupabaseConfig.tableHolidays)
        .select('date,name,is_holiday')
        .gte('date', from)
        .lte('date', to)
        .eq('is_holiday', true);
    return [
      for (final r in rows as List<dynamic>)
        _toHoliday(r as Map<String, dynamic>),
    ];
  }

  Holiday _toHoliday(Map<String, dynamic> r) {
    final dateStr = r['date'] as String;
    final parts = dateStr.split('-');
    return Holiday(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      name: (r['name'] as String?) ?? '',
      isHoliday: (r['is_holiday'] as bool?) ?? true,
    );
  }
}
