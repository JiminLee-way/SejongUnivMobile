import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/finance/data/datasources/sejong_finance_remote.dart';
import 'package:sejong_smart_campus/features/finance/domain/entities/finance_models.dart';

final _financeRemoteProvider = FutureProvider<SejongFinanceRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongFinanceRemote(client: client);
});

final scholarshipSemestersProvider = FutureProvider<List<FinanceSemester>>((
  ref,
) async {
  ref.watch(currentUserProvider);
  final remote = await ref.watch(_financeRemoteProvider.future);
  return remote.fetchScholarshipSemesters();
});

typedef SemesterKey = ({String year, String smtCd});

final scholarshipsProvider = FutureProvider.autoDispose
    .family<List<ScholarshipItem>, SemesterKey>((ref, k) async {
      final remote = await ref.watch(_financeRemoteProvider.future);
      return remote.fetchScholarships(year: k.year, smtCd: k.smtCd);
    });

final tuitionNoticeProvider = FutureProvider.autoDispose
    .family<List<TuitionItem>, SemesterKey>((ref, k) async {
      final remote = await ref.watch(_financeRemoteProvider.future);
      return remote.fetchTuitionNotice(year: k.year, smtCd: k.smtCd);
    });

final discretionaryProvider = FutureProvider.autoDispose
    .family<List<DiscretionaryGroup>, SemesterKey>((ref, k) async {
      final remote = await ref.watch(_financeRemoteProvider.future);
      return remote.fetchDiscretionary(year: k.year, smtCd: k.smtCd);
    });
