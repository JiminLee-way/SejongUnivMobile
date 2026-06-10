import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/support/data/datasources/app_support_remote.dart';
import 'package:sejong_smart_campus/features/support/data/datasources/sejong_support_remote.dart';
import 'package:sejong_smart_campus/features/support/domain/entities/support_models.dart';

// ─────────────────────── FAQ (sjapp 학교 FAQ — 변경 없음) ───────────────────────

final _supportRemoteProvider = FutureProvider<SejongSupportRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongSupportRemote(client: client);
});

final faqCategoriesProvider = FutureProvider<List<FaqCategory>>((ref) async {
  final remote = await ref.watch(_supportRemoteProvider.future);
  return remote.fetchFaqCategories();
});

final faqsProvider = FutureProvider.autoDispose.family<List<FaqItem>, String?>((
  ref,
  categoryId,
) async {
  final remote = await ref.watch(_supportRemoteProvider.future);
  return remote.fetchFaqs(categoryId: categoryId);
});

// ─────────────────────── 앱 1:1 문의 (우리 Supabase) ───────────────────────

/// 앱 자체에 대한 1:1 문의 — sjapp이 아니라 Supabase `app_inquiries`.
final appSupportRemoteProvider = Provider<AppSupportRemote>((ref) {
  return AppSupportRemote(Supabase.instance.client);
});

/// 내 문의 목록. 로그인(익명 세션)에 묶이므로 currentUser 변경 시 재조회.
final myQnaProvider = FutureProvider<List<QnaItem>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.watch(appSupportRemoteProvider).listMyInquiries();
});
