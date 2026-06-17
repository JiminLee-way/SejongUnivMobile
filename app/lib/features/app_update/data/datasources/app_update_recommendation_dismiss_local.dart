import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_recommendation.dart';

class AppUpdateRecommendationDismissLocal {
  AppUpdateRecommendationDismissLocal({File? fileForTesting})
    : _fileForTesting = fileForTesting;

  static const _fileName = 'app_update_recommendation_dismiss.json';

  final File? _fileForTesting;
  File? _cachedFile;

  Future<File> _file() async {
    final testFile = _fileForTesting;
    if (testFile != null) return testFile;
    final cached = _cachedFile;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    _cachedFile = file;
    return file;
  }

  Future<AppUpdateRecommendationDismissState?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      return AppUpdateRecommendationDismissState.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isDismissed({
    required int latestBuildNumber,
    DateTime? now,
  }) async {
    return !shouldShowRecommendedUpdate(
      latestBuildNumber: latestBuildNumber,
      dismissState: await read(),
      now: now ?? DateTime.now(),
    );
  }

  Future<void> snoozeForOneDay({
    required int latestBuildNumber,
    DateTime? now,
  }) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final base = now ?? DateTime.now();
    final state = AppUpdateRecommendationDismissState(
      latestBuildNumber: latestBuildNumber,
      dismissedUntil: base.add(const Duration(hours: 24)),
    );
    await file.writeAsString(jsonEncode(state.toJson()));
  }
}
