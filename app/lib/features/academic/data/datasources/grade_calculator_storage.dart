import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:sejong_smart_campus/features/academic/domain/entities/grade_calculator_models.dart';

abstract class GradeCalculatorStorage {
  Future<GradeCalculatorSavedState?> read(String userId);
  Future<void> write(String userId, GradeCalculatorSavedState state);
  Future<void> delete(String userId);
}

class SecureGradeCalculatorStorage implements GradeCalculatorStorage {
  SecureGradeCalculatorStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'grade_calculator.snapshot.$userId';

  @override
  Future<GradeCalculatorSavedState?> read(String userId) async {
    final raw = await _storage.read(key: _key(userId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return GradeCalculatorSavedState.fromJson(decoded.cast());
  }

  @override
  Future<void> write(String userId, GradeCalculatorSavedState state) {
    return _storage.write(key: _key(userId), value: jsonEncode(state.toJson()));
  }

  @override
  Future<void> delete(String userId) => _storage.delete(key: _key(userId));
}

class GradeCalculatorSavedState {
  const GradeCalculatorSavedState({
    required this.schemaVersion,
    required this.baseFingerprints,
    required this.terms,
    required this.updatedAt,
  });

  factory GradeCalculatorSavedState.empty() {
    return GradeCalculatorSavedState(
      schemaVersion: 1,
      baseFingerprints: const {},
      terms: const [],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int schemaVersion;
  final Map<String, String> baseFingerprints;
  final List<GradeCalculatorTerm> terms;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'baseFingerprints': baseFingerprints,
    'updatedAt': updatedAt.toIso8601String(),
    'terms': terms.map((term) => term.toJson()).toList(),
  };

  factory GradeCalculatorSavedState.fromJson(Map<String, dynamic> json) {
    final rawFingerprints = (json['baseFingerprints'] as Map?) ?? const {};
    return GradeCalculatorSavedState(
      schemaVersion: ((json['schemaVersion'] as num?) ?? 1).toInt(),
      baseFingerprints: {
        for (final entry in rawFingerprints.entries)
          entry.key.toString(): entry.value.toString(),
      },
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      terms: ((json['terms'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => GradeCalculatorTerm.fromJson(row.cast()))
          .toList(),
    );
  }
}

class MemoryGradeCalculatorStorage implements GradeCalculatorStorage {
  final Map<String, GradeCalculatorSavedState> _states = {};

  @override
  Future<void> delete(String userId) async {
    _states.remove(userId);
  }

  @override
  Future<GradeCalculatorSavedState?> read(String userId) async {
    return _states[userId];
  }

  @override
  Future<void> write(String userId, GradeCalculatorSavedState state) async {
    _states[userId] = state;
  }
}
