import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

class LibseatReservationSnapshot {
  const LibseatReservationSnapshot({
    required this.key,
    required this.roomNo,
    required this.seatNo,
    required this.roomName,
    required this.startedAt,
    required this.expiresAt,
  });

  factory LibseatReservationSnapshot.fromMySeat(MySeat seat) {
    final startedAt = seat.startedAt;
    final expiresAt = seat.expiresAt;
    return LibseatReservationSnapshot(
      key: libseatReservationKey(
        roomNo: seat.roomNo,
        seatNo: seat.seatNo,
        startedAt: startedAt,
        expiresAt: expiresAt,
      ),
      roomNo: seat.roomNo,
      seatNo: seat.seatNo,
      roomName: seat.roomName,
      startedAt: startedAt,
      expiresAt: expiresAt,
    );
  }

  final String key;
  final int roomNo;
  final String seatNo;
  final String roomName;
  final DateTime startedAt;
  final DateTime expiresAt;

  bool hasSameSchedule(LibseatReservationSnapshot other) =>
      key == other.key &&
      startedAt.isAtSameMomentAs(other.startedAt) &&
      expiresAt.isAtSameMomentAs(other.expiresAt);

  Map<String, dynamic> toJson() => {
    'key': key,
    'roomNo': roomNo,
    'seatNo': seatNo,
    'roomName': roomName,
    'startedAt': startedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  static LibseatReservationSnapshot? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return LibseatReservationSnapshot(
        key: raw['key'] as String,
        roomNo: raw['roomNo'] as int,
        seatNo: raw['seatNo'] as String,
        roomName: raw['roomName'] as String,
        startedAt: DateTime.parse(raw['startedAt'] as String),
        expiresAt: DateTime.parse(raw['expiresAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

class LibseatNotificationState {
  const LibseatNotificationState({
    this.current,
    this.acknowledgedReturnKeys = const <String>{},
  });

  final LibseatReservationSnapshot? current;
  final Set<String> acknowledgedReturnKeys;

  LibseatNotificationState copyWith({
    LibseatReservationSnapshot? current,
    bool clearCurrent = false,
    Set<String>? acknowledgedReturnKeys,
  }) {
    return LibseatNotificationState(
      current: clearCurrent ? null : current ?? this.current,
      acknowledgedReturnKeys:
          acknowledgedReturnKeys ?? this.acknowledgedReturnKeys,
    );
  }
}

class LibseatNotificationStateLocal {
  LibseatNotificationStateLocal({File? fileForTesting})
    : _fileForTesting = fileForTesting;

  static const _fileName = 'libseat_notification_state.json';
  static const _maxAcknowledgedKeys = 80;

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

  Future<LibseatNotificationState> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const LibseatNotificationState();
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final current = LibseatReservationSnapshot.fromJson(raw['current']);
      final acknowledged = (raw['acknowledgedReturnKeys'] as List? ?? const [])
          .whereType<String>()
          .toSet();
      return LibseatNotificationState(
        current: current,
        acknowledgedReturnKeys: acknowledged,
      );
    } catch (_) {
      return const LibseatNotificationState();
    }
  }

  Future<void> saveSnapshot(LibseatReservationSnapshot snapshot) async {
    final state = await read();
    await _write(state.copyWith(current: snapshot));
  }

  Future<void> clearSnapshot() async {
    final state = await read();
    await _write(state.copyWith(clearCurrent: true));
  }

  Future<bool> hasAcknowledgedReturn(String key) async {
    final state = await read();
    return state.acknowledgedReturnKeys.contains(key);
  }

  Future<void> acknowledgeReturn(String key) async {
    final state = await read();
    final next = <String>{
      key,
      ...state.acknowledgedReturnKeys,
    }.take(_maxAcknowledgedKeys).toSet();
    await _write(state.copyWith(acknowledgedReturnKeys: next));
  }

  Future<void> _write(LibseatNotificationState state) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'current': state.current?.toJson(),
        'acknowledgedReturnKeys': state.acknowledgedReturnKeys.toList(),
      }),
    );
  }
}

String libseatReservationKey({
  required int roomNo,
  required String seatNo,
  required DateTime startedAt,
  required DateTime expiresAt,
}) => [
  roomNo,
  seatNo,
  startedAt.toIso8601String(),
  expiresAt.toIso8601String(),
].join('|');
