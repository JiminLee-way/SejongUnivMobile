import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/sjpt/data/datasources/facility_images_cache.dart';
import 'package:sejong_smart_campus/features/sjpt/data/datasources/supabase_facility_images_remote.dart';
import 'package:sejong_smart_campus/features/sjpt/data/datasources/sjpt_client.dart';
import 'package:sejong_smart_campus/features/sjpt/data/repositories/sjpt_reservation_repository.dart';
import 'package:sejong_smart_campus/features/sjpt/domain/entities/sjpt_models.dart';

final sjptClientProvider = FutureProvider<SjptClient>((ref) async {
  // 계정 격리 — 사용자가 바뀌면 이전 사용자의 PII/세션(_runningSejong·_intgUsrNo·
  // 이름·전화·학과)을 들고 있는 SjptClient를 폐기하고 새 인스턴스로 교체. userId만
  // select 해 토큰 refresh(같은 사용자 객체 재발행)엔 영향받지 않게 한다. 이 의존이
  // 없으면 로그아웃→다른 계정 로그인 후에도 예약이 이전 사용자 명의로 제출될 수 있음.
  ref.watch(currentUserProvider.select((u) => u?.userId));
  final jar = await ref.watch(cookieJarProvider.future);
  return SjptClient(cookieJar: jar);
});

/// SSO 초기화 — RUNNING_SEJONG 획득. 앱 세션 당 1회.
final sjptInitProvider = FutureProvider.autoDispose<String>((ref) async {
  final client = await ref.watch(sjptClientProvider.future);
  final uuid = await client.initialize();
  if (uuid == null) throw Exception('RUNNING_SEJONG 없음 — SSO 실패 또는 로그인 만료');
  return uuid;
});

// ── 카테고리 필터 ────────────────────────────────────────────

/// 6개 고정 카테고리.
enum SjptCategory {
  all, // 전체
  classroom, // 강의실 (GAI008001)
  lab, // 실험실 (GAI008002)
  sports, // 체육·공연 (GAI008013 + GAI008014)
  studentUnion, // 학생회관 (건물명 기반)
  other, // 그외
}

bool _matchesCategory(SjptFacility f, SjptCategory cat) => switch (cat) {
  SjptCategory.all => true,
  SjptCategory.classroom => f.typeCd == 'GAI008001',
  SjptCategory.lab => f.typeCd == 'GAI008002',
  SjptCategory.sports => f.typeCd == 'GAI008013' || f.typeCd == 'GAI008014',
  SjptCategory.studentUnion => f.buildingName.contains('학생회관'),
  SjptCategory.other =>
    f.typeCd != 'GAI008001' &&
        f.typeCd != 'GAI008002' &&
        f.typeCd != 'GAI008013' &&
        f.typeCd != 'GAI008014' &&
        !f.buildingName.contains('학생회관'),
};

class _CategoryNotifier extends Notifier<SjptCategory> {
  @override
  SjptCategory build() => SjptCategory.all;
  void select(SjptCategory c) => state = c;
}

final sjptSelectedCategoryProvider =
    NotifierProvider<_CategoryNotifier, SjptCategory>(_CategoryNotifier.new);

// ── 날짜 / 건물 필터 ─────────────────────────────────────────

/// 선택된 날짜 (기본값: 오늘).
class _DateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void select(DateTime d) => state = d;
}

final sjptSelectedDateProvider = NotifierProvider<_DateNotifier, DateTime>(
  _DateNotifier.new,
);

/// 선택된 건물 필터 (null = 전체).
class _BuildingNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? b) => state = b;
}

final sjptSelectedBuildingProvider =
    NotifierProvider<_BuildingNotifier, String?>(_BuildingNotifier.new);

// ── 데이터 ──────────────────────────────────────────────────

final _facilityImagesRemoteProvider = Provider<SupabaseFacilityImagesRemote>(
  (ref) => SupabaseFacilityImagesRemote(Supabase.instance.client),
);

final _facilityImagesCacheProvider = Provider<FacilityImagesCache>(
  (ref) => FacilityImagesCache(),
);

/// 시설 이미지 매핑 — Supabase `facility_images` (room_abbt → image_url).
/// 서버 구동(관리자가 행 추가 + 이미지 업로드 → APK 재빌드 없이 반영, home_events 철학).
///
/// **로컬 캐시 우선 + 버전 패리티 체크(stale-while-revalidate)**:
///  1. 로컬 파일 캐시가 있으면 즉시 반환 → 다음 실행에도 네트워크 대기 없이 바로
///     노출(이미지 바이트는 cached_network_image가 디스크 캐시 → 즉시 렌더).
///  2. 백그라운드로 DB **버전 시그니처만** 조회(updated_at 1컬럼) → 캐시 버전과
///     같으면 아무것도 안 함(전체 재요청 X), 다르면 전체 맵을 받아 캐시·state 갱신.
///  3. 캐시가 없으면(첫 실행) 전체 맵을 받아 캐시에 저장.
///
/// room_abbt 정확 매칭이 키 — 예: '센B102', '광106', '운동장'. 네트워크 실패/미적재
/// 시엔 캐시 유지(없으면 빈 맵 degrade) → 강의실 카드는 `_legacyAicenterImageUrl`
/// 폴백 또는 아이콘 배너. non-autoDispose 세션 캐시 — pull-to-refresh 시 invalidate
/// 하면 캐시 즉시 노출 + 재검증.
class _FacilityImagesNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final cache = ref.watch(_facilityImagesCacheProvider);
    final cached = await cache.load();
    if (cached != null) {
      // 캐시 즉시 노출 + 백그라운드 재검증(버전 다를 때만 전체 재요청).
      unawaited(_revalidate(cached.version));
      return cached.map;
    }
    // 첫 실행: 전체 fetch 후 캐시 저장.
    final fresh = await ref.watch(_facilityImagesRemoteProvider).fetchActive();
    await cache.save(fresh.version, fresh.map);
    return fresh.map;
  }

  Future<void> _revalidate(String knownVersion) async {
    try {
      final remote = ref.read(_facilityImagesRemoteProvider);
      final remoteVersion = await remote.fetchVersion();
      if (remoteVersion == knownVersion) return; // 변경 없음 → 캐시 그대로.
      final fresh = await remote.fetchActive();
      await ref
          .read(_facilityImagesCacheProvider)
          .save(fresh.version, fresh.map);
      state = AsyncData(fresh.map);
    } catch (_) {
      // 네트워크 실패 → 캐시 유지(state 건드리지 않음). (notifier가 이미
      // dispose됐으면 state 할당이 던질 수 있어 여기서 함께 흡수.)
    }
  }
}

final facilityImagesProvider =
    AsyncNotifierProvider<_FacilityImagesNotifier, Map<String, String>>(
      _FacilityImagesNotifier.new,
    );

/// 시설물 전체 목록 (세션 동안 캐시).
final sjptFacilitiesProvider = FutureProvider<List<SjptFacility>>((ref) async {
  await ref.watch(sjptInitProvider.future);
  final client = await ref.watch(sjptClientProvider.future);
  final raw = await client.listFacilities();
  return raw.map(SjptFacility.fromJson).toList();
});

/// 현재 카테고리 기준 건물 목록 (중복 제거, 정렬).
final sjptBuildingsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final cat = ref.watch(sjptSelectedCategoryProvider);
  // 학생회관 카테고리는 건물 서브필터 불필요 — 빈 목록 반환.
  if (cat == SjptCategory.studentUnion) {
    return ref.watch(sjptFacilitiesProvider).whenData((_) => const []);
  }
  return ref.watch(sjptFacilitiesProvider).whenData((list) {
    final filtered = list.where((f) => _matchesCategory(f, cat)).toList();
    return filtered.map((f) => f.buildingName).toSet().toList()..sort();
  });
});

/// 카테고리·건물 필터가 적용된 시설 목록.
final sjptFilteredFacilitiesProvider = Provider<AsyncValue<List<SjptFacility>>>(
  (ref) {
    final cat = ref.watch(sjptSelectedCategoryProvider);
    final building = ref.watch(sjptSelectedBuildingProvider);
    return ref
        .watch(sjptFacilitiesProvider)
        .whenData(
          (list) => list.where((f) {
            if (!_matchesCategory(f, cat)) return false;
            if (building != null && f.buildingName != building) return false;
            return true;
          }).toList(),
        );
  },
);

/// 특정 시설물 시간표.
final sjptTimeTableProvider = FutureProvider.autoDispose
    .family<List<SjptTimeSlot>, ({String roomAbbt, String date})>((
      ref,
      args,
    ) async {
      await ref.watch(sjptInitProvider.future);
      final client = await ref.watch(sjptClientProvider.future);
      final raw = await client.listRoomTimeTable(
        roomAbbt: args.roomAbbt,
        useDate: args.date,
      );
      return raw.map(SjptTimeSlot.fromJson).toList();
    });

/// 특정 시설물의 예약 가능 인스턴스 (FACILITY_MNGT_NO 포함).
/// null = 해당 날짜에 예약 불가.
final sjptFacilityInstanceProvider = FutureProvider.autoDispose
    .family<SjptFacilityInstance?, ({String roomAbbt, String date})>((
      ref,
      args,
    ) async {
      await ref.watch(sjptInitProvider.future);
      final client = await ref.watch(sjptClientProvider.future);
      final raw = await client.getFacilityInstance(
        roomAbbt: args.roomAbbt,
        useDate: args.date,
      );
      return raw != null ? SjptFacilityInstance.fromJson(raw) : null;
    });

/// 점유 슬롯의 예약 목록 (신청번호 조회용).
final sjptSlotReservationsProvider = FutureProvider.autoDispose
    .family<
      List<SjptSlotReservation>,
      ({
        String placeDivCd,
        String bldNo,
        String roomNo,
        String bldNm,
        String roomAbbt,
        String useDate,
      })
    >((ref, args) async {
      await ref.watch(sjptInitProvider.future);
      final client = await ref.watch(sjptClientProvider.future);
      final raw = await client.listSlotReservations(
        placeDivCd: args.placeDivCd,
        bldNo: args.bldNo,
        roomNo: args.roomNo,
        bldNm: args.bldNm,
        roomAbbt: args.roomAbbt,
        useDate: args.useDate,
      );
      return raw.map(SjptSlotReservation.fromJson).toList();
    });

/// 내 시설물 신청 내역 — SJPT 서버 조회 (최근 1개월 + 향후 2개월).
final sjptMyReservationsProvider =
    FutureProvider.autoDispose<List<SjptReservation>>((ref) async {
      await ref.watch(sjptInitProvider.future);
      final client = await ref.watch(sjptClientProvider.future);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month + 2, 0);
      final raw = await client.listMyApplications(
        startDate: _yyyymmdd(start),
        endDate: _yyyymmdd(end),
      );
      return raw.map(SjptReservation.fromJson).toList();
    });

// ── Supabase 로컬 캐시 ───────────────────────────────────────

final sjptReservationRepositoryProvider = Provider<SjptReservationRepository>(
  (ref) => SjptReservationRepository(),
);

/// Supabase 캐시에서 내 예약 내역 로드 (앱 재시작 후에도 신청번호 확인 가능).
final sjptLocalReservationsProvider =
    FutureProvider.autoDispose<List<SjptLocalReservation>>((ref) async {
      final repo = ref.watch(sjptReservationRepositoryProvider);
      return repo.loadReservations();
    });

String _yyyymmdd(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
