import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sejong_smart_campus/features/notices/data/datasources/notice_attachment_downloader.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late _RecordingDio dio;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notice-download-test-');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    dio = _RecordingDio();
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('NoticeAttachmentDownloader', () {
    test('uses a fallback file name for empty and dot-only names', () async {
      final downloader = NoticeAttachmentDownloader(dio: dio);

      final emptyResult = await downloader.download(
        _attachment(fileName: '   '),
      );
      final dotResult = await downloader.download(_attachment(fileName: '..'));

      expect(emptyResult.success, isTrue);
      expect(dotResult.success, isTrue);
      expect(_fileName(dio.savedPaths[0]), 'attachment');
      expect(_fileName(dio.savedPaths[1]), 'attachment (1)');
    });

    test(
      'avoids overwriting existing files by adding a numeric suffix',
      () async {
        final downloadsDir = Directory('${tempDir.path}/sejong_downloads');
        await downloadsDir.create(recursive: true);
        await File('${downloadsDir.path}/report.pdf').writeAsString('old');

        final downloader = NoticeAttachmentDownloader(dio: dio);
        final result = await downloader.download(
          _attachment(fileName: 'report.pdf'),
        );

        expect(result.success, isTrue);
        expect(_fileName(dio.savedPaths.single), 'report (1).pdf');
        expect(
          await File('${downloadsDir.path}/report.pdf').readAsString(),
          'old',
        );
      },
    );

    test('removes control characters and truncates long names', () async {
      final downloader = NoticeAttachmentDownloader(dio: dio);
      final longBase = 'a' * 180;

      final result = await downloader.download(
        _attachment(fileName: ' bad\u0000:name?$longBase.pdf '),
      );

      final savedName = _fileName(dio.savedPaths.single);
      expect(result.success, isTrue);
      expect(savedName, isNot(contains(RegExp(r'[\x00-\x1F\x7F\\/:*?"<>|]'))));
      expect(savedName.length, lessThanOrEqualTo(120));
      expect(savedName.endsWith('.pdf'), isTrue);
    });
  });
}

NoticeAttachment _attachment({required String fileName}) {
  return NoticeAttachment(
    fileName: fileName,
    fileUrl: 'https://example.invalid/file',
    fileSize: 12,
  );
}

String _fileName(String path) {
  return path.split(Platform.pathSeparator).last;
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class _RecordingDio with DioMixin implements Dio {
  _RecordingDio() {
    options = BaseOptions();
  }

  final List<String> savedPaths = [];

  @override
  Future<Response<dynamic>> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    FileAccessMode fileAccessMode = FileAccessMode.write,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) async {
    final path = savePath as String;
    savedPaths.add(path);
    await File(path).writeAsString('new');
    onReceiveProgress?.call(3, 3);
    return Response<dynamic>(requestOptions: RequestOptions(path: urlPath));
  }
}
