/// Supabase connection config.
///
/// Public source builds do not contain project URLs or keys. Internal builds pass
/// them with `--dart-define` or `--dart-define-from-file`.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String tableHolidays = String.fromEnvironment(
    'SUPABASE_TABLE_01',
  );
  static const String tableAppConfig = String.fromEnvironment(
    'SUPABASE_TABLE_02',
  );
  static const String tableDeptOffices = String.fromEnvironment(
    'SUPABASE_TABLE_03',
  );
  static const String tableSjptReservations = String.fromEnvironment(
    'SUPABASE_TABLE_04',
  );
  static const String tableFacilityImages = String.fromEnvironment(
    'SUPABASE_TABLE_05',
  );
  static const String tableHomeEvents = String.fromEnvironment(
    'SUPABASE_TABLE_06',
  );
  static const String tableAppInquiries = String.fromEnvironment(
    'SUPABASE_TABLE_07',
  );
  static const String functionOnboard = String.fromEnvironment(
    'SUPABASE_FUNCTION_01',
  );
  static const String rpcUpsertUserFromSjapp = String.fromEnvironment(
    'SUPABASE_RPC_01',
  );
  static const String rpcUpdateLastSeen = String.fromEnvironment(
    'SUPABASE_RPC_02',
  );
  static const String rpcWithdrawUser = String.fromEnvironment(
    'SUPABASE_RPC_03',
  );
  static const String rpcSaveTimetable = String.fromEnvironment(
    'SUPABASE_RPC_04',
  );
  static const String rpcFindUserByStudentId = String.fromEnvironment(
    'SUPABASE_RPC_05',
  );
  static const String rpcFindUserByName = String.fromEnvironment(
    'SUPABASE_RPC_06',
  );
  static const String rpcSendFriendRequest = String.fromEnvironment(
    'SUPABASE_RPC_07',
  );
  static const String rpcRespondFriendRequest = String.fromEnvironment(
    'SUPABASE_RPC_08',
  );
  static const String rpcListMyFriends = String.fromEnvironment(
    'SUPABASE_RPC_09',
  );
  static const String rpcListPendingFriendRequests = String.fromEnvironment(
    'SUPABASE_RPC_10',
  );
  static const String rpcIssueFriendInviteCode = String.fromEnvironment(
    'SUPABASE_RPC_11',
  );
  static const String rpcRedeemFriendInviteCode = String.fromEnvironment(
    'SUPABASE_RPC_12',
  );
  static const String rpcGetSearchVisible = String.fromEnvironment(
    'SUPABASE_RPC_13',
  );
  static const String rpcSetSearchVisible = String.fromEnvironment(
    'SUPABASE_RPC_14',
  );
  static const String rpcGetFriendTimetableSemesters = String.fromEnvironment(
    'SUPABASE_RPC_15',
  );
  static const String rpcGetFriendTimetable = String.fromEnvironment(
    'SUPABASE_RPC_16',
  );

  static bool get isConfigured =>
      url.startsWith('https://') && anonKey.trim().isNotEmpty;

  static String? publicStorageBase(String bucketPath) {
    if (!isConfigured) return null;
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return '$base/storage/v1/object/public/$bucketPath';
  }
}
