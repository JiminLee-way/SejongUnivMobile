import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/home_widgets/domain/entities/home_widget_models.dart';

class SejongHomeWidgetsRemote {
  SejongHomeWidgetsRemote({required this.client});
  final SejongApiClient client;

  Future<Weather> fetchWeather() async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.weather);
    return client.unwrap<Weather>(
      res,
      (raw) => Weather.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  Future<List<HomeBanner>> fetchBanners() async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.homeBanners);
    return client.unwrap<List<HomeBanner>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(HomeBanner.fromJson)
          .toList();
    });
  }

  Future<List<FeedItem>> fetchFeeds({int count = 5}) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.feedsLatest,
      queryParameters: {'count': count},
    );
    return client.unwrap<List<FeedItem>>(res, (raw) {
      final m = raw is Map<String, dynamic> ? raw : null;
      final list = (m?['feeds'] as List?) ?? (raw is List ? raw : const []);
      return list.cast<Map<String, dynamic>>().map(FeedItem.fromJson).toList();
    });
  }
}
