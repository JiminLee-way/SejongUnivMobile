import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/mcp/data/datasources/sejong_mcp_remote.dart';

final mcpRemoteProvider = FutureProvider<SejongMcpRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongMcpRemote(client: client);
});

final mcpGreetingProvider = FutureProvider<String?>((ref) async {
  final remote = await ref.watch(mcpRemoteProvider.future);
  return remote.fetchGreeting();
});

final mcpRecommendedQuestionsProvider = FutureProvider<List<String>>((
  ref,
) async {
  final remote = await ref.watch(mcpRemoteProvider.future);
  return remote.fetchRecommendedQuestions();
});
