import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/home_widgets/data/datasources/sejong_home_widgets_remote.dart';
import 'package:sejong_smart_campus/features/home_widgets/domain/entities/home_widget_models.dart';

final _homeWidgetsRemoteProvider = FutureProvider<SejongHomeWidgetsRemote>((
  ref,
) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongHomeWidgetsRemote(client: client);
});

final weatherProvider = FutureProvider<Weather>((ref) async {
  final remote = await ref.watch(_homeWidgetsRemoteProvider.future);
  return remote.fetchWeather();
});

final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) async {
  final remote = await ref.watch(_homeWidgetsRemoteProvider.future);
  return remote.fetchBanners();
});

final feedsLatestProvider = FutureProvider<List<FeedItem>>((ref) async {
  final remote = await ref.watch(_homeWidgetsRemoteProvider.future);
  return remote.fetchFeeds(count: 5);
});
