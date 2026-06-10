import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_aes_cipher.dart';

void main() {
  // 인스턴스 자체에 상태가 없으므로 매 테스트에 새로 만들지 않아도 OK.
  final cipher = UCheckAesCipher();

  group('UCheckAesCipher', () {
    test('daily key 라운드트립 — 학번/비밀번호 같은 평문', () {
      final samples = [
        '00000000',
        'p@ssw0rd!',
        '한글비밀번호★',
        'a' * 31, // 패딩 경계
      ];
      for (final s in samples) {
        final cipherText = cipher.encryptDaily(s);
        expect(
          cipherText,
          matches(RegExp(r'^[0-9A-F]+$')),
          reason: 'Base16 대문자만',
        );
        expect(
          cipherText.length % 32,
          0,
          reason: 'AES 블록 크기 16B × 2 hex chars',
        );
        expect(cipher.decryptDaily(cipherText), s);
      }
    });

    test('동일 입력 → 동일 출력 (IV 고정이므로 deterministic)', () {
      final a = cipher.encryptDaily('hello');
      final b = cipher.encryptDaily('hello');
      expect(a, b);
    });

    test('서버 키 라운드트립 — memo 시뮬레이션', () {
      // 실 서버 키 길이는 가변. 8/16/32/64 모두 받아내야.
      const serverKey16 = 'serverKey16bytes';
      final memo = '2026-05-25 14:57:30';
      final cipherText = cipher.encryptWithServerKey(memo, serverKey16);
      expect(cipherText, matches(RegExp(r'^[0-9A-F]+$')));
      expect(cipherText.length % 32, 0);
      // 동일 키로 다시 암호화 시 deterministic
      expect(cipher.encryptWithServerKey(memo, serverKey16), cipherText);
    });
  });
}
