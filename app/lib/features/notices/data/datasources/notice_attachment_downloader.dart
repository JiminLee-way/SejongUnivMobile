import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';

/// 공지 첨부파일 다운로드 + OS 기본 앱으로 열기.
///
/// 쿠키/Authorization이 필요 없는 첨부 URL을 stand-alone [Dio]로 다운로드한다.
///
/// 저장 위치는 app docs dir 하위 `sejong_downloads/`. 같은 파일명이면 덮어쓰기.
class NoticeAttachmentDownloader {
  NoticeAttachmentDownloader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              // 큰 PDF/HWP 대비 — 30MB 수준까지는 receive 60s.
              receiveTimeout: const Duration(seconds: 60),
              followRedirects: true,
              // 4xx도 onResponse로 받아 호출자 메시지 분기 가능.
              validateStatus: (s) => s != null && s < 500,
              // SmartApp 웹뷰가 그대로 사용하는 UA — 서버가 desktop UA로
              // 차별 응답하는 케이스 회피.
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                if (ServiceUrls.sejongApi.isNotEmpty)
                  'Referer': ServiceUrls.join(ServiceUrls.sejongApi, '/'),
              },
            ),
          );

  final Dio _dio;

  /// 단일 첨부파일 다운로드. [onProgress]는 (received, total). total -1이면 미상.
  /// 반환 [DownloadResult]는 호출자(스크린)에서 토스트/에러 메시지에 사용.
  Future<DownloadResult> download(
    NoticeAttachment attachment, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (attachment.fileUrl.isEmpty) {
      return const DownloadResult(success: false, message: '파일 주소가 비어있어요');
    }
    try {
      final dir = await _downloadsDir();
      final safe = _sanitize(attachment.fileName);
      final path = '${dir.path}/$safe';
      await _dio.download(
        attachment.fileUrl,
        path,
        onReceiveProgress: onProgress,
      );
      return DownloadResult(success: true, savedPath: path);
    } on DioException catch (e) {
      return DownloadResult(
        success: false,
        message: '다운로드 실패 (${e.type.name})',
      );
    } catch (e) {
      return DownloadResult(success: false, message: '다운로드 실패: $e');
    }
  }

  /// 다운로드 후 [OpenFilex]로 즉시 OS 기본 앱에서 열기.
  ///
  /// 이미 받은 파일이 있으면 재다운로드 없이 바로 열기.
  Future<DownloadResult> downloadAndOpen(
    NoticeAttachment attachment, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await _downloadsDir();
    final safe = _sanitize(attachment.fileName);
    final path = '${dir.path}/$safe';
    final existing = File(path);
    DownloadResult dl;
    if (await existing.exists() && await existing.length() > 0) {
      dl = DownloadResult(success: true, savedPath: path);
    } else {
      dl = await download(attachment, onProgress: onProgress);
      if (!dl.success) return dl;
    }
    final opened = await OpenFilex.open(dl.savedPath!);
    if (opened.type != ResultType.done) {
      return DownloadResult(
        success: false,
        savedPath: dl.savedPath,
        message: opened.message.isNotEmpty ? opened.message : '열 수 있는 앱이 없어요',
      );
    }
    return dl;
  }

  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sejong_downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 파일명에 들어가면 안 되는 문자 제거. Android는 관대하지만 슬래시·콜론은 금지.
  String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
  }
}

class DownloadResult {
  const DownloadResult({required this.success, this.savedPath, this.message});
  final bool success;
  final String? savedPath;
  final String? message;
}
