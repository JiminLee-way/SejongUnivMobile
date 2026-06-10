import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/phone_directory/data/datasources/sejong_phone_remote.dart';
import 'package:sejong_smart_campus/features/phone_directory/domain/entities/phone_directory_models.dart';

void main() {
  group('SejongPhoneRemote.parsePage', () {
    test('content[] → StaffContact 목록 + 페이지 메타', () {
      // 실제 응답의 `data`(Pageable) 모양.
      final data = <String, dynamic>{
        'content': <dynamic>[
          {
            'name': '최창희',
            'position': '부교수',
            'department': '사이버국방학과',
            'phone': '02-3408-3759',
          },
        ],
        'totalElements': 1,
        'last': true,
        'first': true,
        'empty': false,
      };
      final result = SejongPhoneRemote.parsePage(data);
      expect(result.contacts.length, 1);
      expect(result.total, 1);
      expect(result.hasMore, false);
      expect(result.contacts.first.name, '최창희');
      expect(result.contacts.first.position, '부교수');
      expect(result.contacts.first.department, '사이버국방학과');
      expect(result.contacts.first.phone, '02-3408-3759');
    });

    test('last=false → hasMore=true', () {
      final result = SejongPhoneRemote.parsePage(<String, dynamic>{
        'content': <dynamic>[
          {
            'name': '홍길동',
            'position': '교수',
            'department': '컴퓨터공학과',
            'phone': '02-1',
          },
        ],
        'totalElements': 250,
        'last': false,
      });
      expect(result.hasMore, true);
      expect(result.total, 250);
    });

    test('빈 content / 깨진 입력은 빈 결과(throw 없음)', () {
      expect(
        SejongPhoneRemote.parsePage(<String, dynamic>{
          'content': <dynamic>[],
        }).contacts,
        isEmpty,
      );
      expect(SejongPhoneRemote.parsePage(null).contacts, isEmpty);
      expect(SejongPhoneRemote.parsePage('garbage').contacts, isEmpty);
      expect(SejongPhoneRemote.parsePage(null).total, 0);
    });

    test('이름 없는 행은 스킵', () {
      final result = SejongPhoneRemote.parsePage(<String, dynamic>{
        'content': <dynamic>[
          {'name': '', 'position': '조교', 'department': 'X', 'phone': '02-2'},
          {'name': '김교수', 'position': '교수', 'department': 'Y', 'phone': '02-3'},
        ],
      });
      expect(result.contacts.length, 1);
      expect(result.contacts.first.name, '김교수');
    });
  });

  group('DeptOffice.fromJson', () {
    test('전공 있는 행', () {
      final o = DeptOffice.fromJson(<String, dynamic>{
        'college': '인문과학대학',
        'department': '국제학부',
        'sub_major': '영어영문전공',
        'phone': '02-3408-3302',
        'is_special': false,
      });
      expect(o.college, '인문과학대학');
      expect(o.department, '국제학부');
      expect(o.subMajor, '영어영문전공');
      expect(o.phone, '02-3408-3302');
      expect(o.isSpecial, false);
    });

    test('빈/누락 전공·단과대학은 null', () {
      final o = DeptOffice.fromJson(<String, dynamic>{
        'college': null,
        'department': '법학부',
        'sub_major': '',
        'phone': '02-3408-3318',
        'is_special': true,
      });
      expect(o.college, isNull);
      expect(o.subMajor, isNull);
      expect(o.isSpecial, true);
    });
  });

  group('PhoneSearchType', () {
    test('apiValue 매핑 (전체는 null)', () {
      expect(PhoneSearchType.all.apiValue, isNull);
      expect(PhoneSearchType.name.apiValue, 'name');
      expect(PhoneSearchType.major.apiValue, 'major');
      expect(PhoneSearchType.phone.apiValue, 'phone');
    });
  });
}
