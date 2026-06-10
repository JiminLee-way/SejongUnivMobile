import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';

/// Supabase-backed app update config read-only adapter.
class SupabaseAppConfigRemote {
  SupabaseAppConfigRemote(this._client);
  final SupabaseClient _client;

  static const String rowId = 'android';

  Future<AppUpdateConfig?> fetch() async {
    final row = await _client
        .from(SupabaseConfig.tableAppConfig)
        .select()
        .eq('id', rowId)
        .maybeSingle();
    if (row == null) return null;
    return AppUpdateConfig.fromJson(row);
  }
}
