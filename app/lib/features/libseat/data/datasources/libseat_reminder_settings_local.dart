import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LibseatReminderSettings {
  const LibseatReminderSettings({
    required this.enabled,
    required this.enabledMinutesBefore,
  });

  static const supportedMinutesBefore = <int>[
    5,
    10,
    15,
    20,
    25,
    30,
    45,
    60,
    120,
  ];

  static const defaultEnabledMinutesBefore = <int>{5, 15, 30, 60, 120};

  static const defaults = LibseatReminderSettings(
    enabled: true,
    enabledMinutesBefore: defaultEnabledMinutesBefore,
  );

  final bool enabled;
  final Set<int> enabledMinutesBefore;

  bool get hasAnyEnabled => enabled && enabledMinutesBefore.isNotEmpty;

  List<int> get sortedEnabledMinutesBefore {
    final sorted = enabledMinutesBefore.toList()..sort();
    return sorted;
  }

  LibseatReminderSettings copyWith({
    bool? enabled,
    Set<int>? enabledMinutesBefore,
  }) {
    return LibseatReminderSettings(
      enabled: enabled ?? this.enabled,
      enabledMinutesBefore: _sanitizeMinutes(
        enabledMinutesBefore ?? this.enabledMinutesBefore,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'enabledMinutesBefore': sortedEnabledMinutesBefore,
  };

  static LibseatReminderSettings fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return defaults;
    final minutes = raw['enabledMinutesBefore'];
    return LibseatReminderSettings(
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      enabledMinutesBefore: _sanitizeMinutes(
        minutes is List ? minutes.whereType<num>().map((v) => v.toInt()) : null,
      ),
    );
  }

  static Set<int> _sanitizeMinutes(Iterable<int>? raw) {
    final supported = supportedMinutesBefore.toSet();
    final sanitized = raw?.where(supported.contains).toSet();
    return sanitized ?? defaultEnabledMinutesBefore;
  }
}

class LibseatReminderSettingsLocal {
  LibseatReminderSettingsLocal({File? fileForTesting})
    : _fileForTesting = fileForTesting;

  static const _fileName = 'libseat_reminder_settings.json';

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

  Future<LibseatReminderSettings> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return LibseatReminderSettings.defaults;
      return LibseatReminderSettings.fromJson(
        jsonDecode(await file.readAsString()),
      );
    } catch (_) {
      return LibseatReminderSettings.defaults;
    }
  }

  Future<void> write(LibseatReminderSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}

String libseatReminderLabel(int minutesBefore) {
  if (minutesBefore == 60) return '1시간 전';
  if (minutesBefore == 120) return '2시간 전';
  return '$minutesBefore분 전';
}

String libseatRemainingLabel(int minutesBefore) {
  if (minutesBefore == 60) return '1시간';
  if (minutesBefore == 120) return '2시간';
  return '$minutesBefore분';
}
