import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/library/data/datasources/sejong_library_remote.dart';

final _libraryRemoteProvider = FutureProvider<SejongLibraryRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongLibraryRemote(client: client);
});

/// 도서 대출 / 연체 / 예약 건수 — 학생증·MY 페이지·홈 위젯 공용.
final loanInfoProvider = FutureProvider<LibraryLoanInfo>((ref) async {
  ref.watch(currentUserProvider);
  final remote = await ref.watch(_libraryRemoteProvider.future);
  return remote.fetchLoanInfo();
});
