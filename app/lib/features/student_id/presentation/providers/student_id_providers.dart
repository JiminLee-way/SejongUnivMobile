import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/demo/demo.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/student_id/data/datasources/sejong_photo_remote.dart';
import 'package:sejong_smart_campus/features/student_id/data/datasources/sejong_qr_remote.dart';

final _photoRemoteProvider = FutureProvider<SejongPhotoRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongPhotoRemote(client: client);
});

final _qrRemoteProvider = FutureProvider<SejongQrRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongQrRemote(client: client);
});

/// 서버 렌더 학생증 QR(PNG bytes). key는 학생증 화면이 만든 평문 payload JSON.
///
/// payload(=key)는 새로고침/만료 때마다 `timestamp`·`refreshKey`가 바뀌어 새 key가
/// 되므로 그때만 서버를 다시 호출한다(평소 1초 틱 재빌드로는 재호출 없음). 서버는
/// payload를 암호화한 토큰을 QR로 렌더하므로 **클라이언트 직접 렌더는 불가** —
/// 자세한 배경은 [SejongQrRemote].
final qrImageProvider = FutureProvider.autoDispose.family<Uint8List, String>((
  ref,
  payload,
) async {
  final remote = await ref.watch(_qrRemoteProvider.future);
  return remote.generateQr(data: payload);
});

/// 로그인된 사용자 프로필 사진 (image/jpeg bytes).
///
/// 세션이 살아있는 동안 메모리에 보관 — 학생증 화면 진입할 때마다 재요청하지
/// 않는다. 로그아웃 시 currentUserProvider가 null이 되면 같이 invalidate.
final myPhotoProvider = FutureProvider<Uint8List?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  // 데모: 학생증 사진을 마스코트 에셋으로 대체.
  if (ref.watch(demoModeProvider)) {
    final data = await rootBundle.load(kDemoMascotAsset);
    return data.buffer.asUint8List();
  }
  final remote = await ref.watch(_photoRemoteProvider.future);
  try {
    return await remote.fetchMyPhoto();
  } catch (_) {
    // 사진 실패해도 학생증 자체는 보여줘야 함 — silhouette fallback.
    return null;
  }
});
