import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/phone_directory/domain/entities/phone_directory_models.dart';
import 'package:sejong_smart_campus/features/phone_directory/presentation/providers/phone_directory_providers.dart';
import 'package:sejong_smart_campus/features/phone_directory/presentation/screens/phone_directory_screen.dart';

void main() {
  const offices = <DeptOffice>[
    DeptOffice(
      college: '인문과학대학',
      department: '국어국문학과',
      subMajor: null,
      phone: '02-3408-3301',
      isSpecial: false,
    ),
    DeptOffice(
      college: '인문과학대학',
      department: '국제학부',
      subMajor: '영어영문전공',
      phone: '02-3408-3302',
      isSpecial: false,
    ),
    DeptOffice(
      college: '경영대학',
      department: '경영학부',
      subMajor: null,
      phone: '02-3408-3310',
      isSpecial: false,
    ),
    DeptOffice(
      college: null,
      department: '법학부',
      subMajor: null,
      phone: '02-3408-3318',
      isSpecial: true,
    ),
  ];

  testWidgets('검색어 없으면 학과사무실을 단과대학별 + 특별사무실로 렌더', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deptOfficesProvider.overrideWith((ref) async => offices)],
        child: const MaterialApp(home: PhoneDirectoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 단과대학 헤더 + 특별 사무실 그룹.
    expect(find.text('인문과학대학'), findsOneWidget);
    expect(find.text('경영대학'), findsOneWidget);
    expect(find.text('특별 사무실'), findsOneWidget);

    // 학과/전공/번호.
    expect(find.text('국어국문학과'), findsOneWidget);
    expect(find.text('영어영문전공'), findsOneWidget); // 전공 muted
    expect(find.text('법학부'), findsOneWidget); // 특별사무실
    expect(find.text('02-3408-3301'), findsOneWidget);

    // 검색 입력은 항상.
    expect(find.text('이름·학과·전화번호 검색'), findsOneWidget);
    // 유형 칩은 브라우즈 모드(검색어 없음)에선 숨김 — 죽은 컨트롤 방지.
    expect(find.text('이름'), findsNothing);
    expect(find.text('전화번호'), findsNothing);
  });

  testWidgets('검색어 입력 시 유형 칩 노출 + 교직원 결과로 전환', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deptOfficesProvider.overrideWith((ref) async => offices),
          // 검색은 네트워크 대신 고정 결과로.
          staffSearchProvider.overrideWith(
            (ref, query) async => const StaffSearchResult(
              contacts: [
                StaffContact(
                  name: '최창희',
                  position: '부교수',
                  department: '사이버국방학과',
                  phone: '02-3408-3759',
                ),
              ],
              total: 1,
              hasMore: false,
            ),
          ),
        ],
        child: const MaterialApp(home: PhoneDirectoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '최창희');
    await tester.pump(const Duration(milliseconds: 350)); // 디바운스
    await tester.pumpAndSettle();

    // 유형 칩 노출.
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('이름'), findsOneWidget);
    // 교직원 결과로 전환(학과사무실 헤더 사라짐).
    // '최창희'는 입력칸 + 결과카드 2곳 → findsWidgets. 학과명은 결과에만.
    expect(find.text('최창희'), findsWidgets);
    expect(find.text('사이버국방학과'), findsOneWidget);
    expect(find.text('인문과학대학'), findsNothing);
  });

  testWidgets('비어있는 학과사무실은 안내 문구', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deptOfficesProvider.overrideWith((ref) async => const <DeptOffice>[]),
        ],
        child: const MaterialApp(home: PhoneDirectoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('표시할 번호가 없어요'), findsOneWidget);
  });
}
