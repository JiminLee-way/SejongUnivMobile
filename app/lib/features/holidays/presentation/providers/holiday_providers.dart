import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/holidays/data/datasources/supabase_holiday_remote.dart';
import 'package:sejong_smart_campus/features/holidays/domain/entities/holiday.dart';

final _holidayRemoteProvider = Provider<SupabaseHolidayRemote>((ref) {
  return SupabaseHolidayRemote(ref.watch(supabaseClientProvider));
});

/// 해당 연도의 한국 공휴일 list — Edge Function이 채워둔 캐시에서 SELECT.
///
/// 일 단위 데이터(연 30~50건)라 메모리 비용 미미 — autoDispose 안 함.
/// 앱 lifetime 동안 한 번만 fetch, 그 후 캐시.
final koreanHolidaysProvider = FutureProvider.family<List<Holiday>, int>((
  ref,
  year,
) async {
  final remote = ref.watch(_holidayRemoteProvider);
  return remote.fetchYear(year);
});

/// 여러 날짜 범위에 걸쳐 빠르게 조회할 때 — date(year,month,day) → name map.
final holidayLookupProvider = Provider.family<Map<DateTime, String>, int>((
  ref,
  year,
) {
  final list = ref.watch(koreanHolidaysProvider(year)).value ?? const [];
  return {
    for (final h in list)
      if (h.isHoliday) DateTime(h.date.year, h.date.month, h.date.day): h.name,
  };
});
