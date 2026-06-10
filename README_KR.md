[English README](README.md)

# SejongUnivMobile

세종대학교 공식 2025-2 해커톤 금상 작품을 바탕으로,
세종대학교 공식 창의학기제 2026-1학기에 진행된 프로젝트 파일입니다.

본 프로젝트는 세종대학교 학생 생활에 필요한 기능을 하나의 흐름으로
묶는 비공식 통합 모바일 슈퍼 앱을 목표로 제작되었습니다. 전자 출결,
모바일 학생증, 시간표, 열람실, 시설 예약, 커뮤니티, 학교 공지 등
반복적으로 사용하는 기능을 더 직관적인 UI로 제공하는 데 초점을
두었습니다.

- 지도교수: 한동일 세종대학교 인공지능융합대학 학장
- 출시 이력: Google Play Store에 `세종대역`이라는 이름으로 출시한
  이력이 있습니다.
- 성격: 세종대학교의 공식 서비스가 아닌 비공식 학생 프로젝트입니다.

## 로고 및 상표 안내

프로젝트 화면에 포함된 세종대학교 공식 로고 사용은 세종대학교
홍보실장님과 홍보처장님의 승인을 받아 진행된 범위에 한정됩니다.
세종대학교 공식 로고, 교표, 상징물 등을 별도로 사용하려는 경우에는
세종대학교의 별도 허가를 받아야 합니다.

## 주요 기능

- 전자 출결: U-Check 기반 출결 확인과 출석 체크 동선 개선
- 모바일 학생증: 도서관 게이트와 도서 대출을 고려한 학생증 화면
- 시간표: 학기별 수업 시간표와 친구 시간표 기반 공강 찾기
- 열람실: 실시간 열람실 현황, 좌석 상태, 좌석 예약 흐름
- 시설 예약: 스터디룸, 강의실 등 학교 시설 현황 확인과 예약
- 커뮤니티: 공지, 뉴스, 게시판을 한 화면에서 탐색
- MY 세종: 학사 캘린더, 성적, 알림 설정 등 개인화 메뉴

## 인증 및 포털 API

본 프로젝트는 세종대학교 구성원 인증과 공식 포털 API 연동 구조 검증에
[Sejong-University-Portal-Auth](https://github.com/JiminLee-way/Sejong-University-Portal-Auth)를
사용했습니다. 해당 companion library는 세종대학교 통합 앱 API를 기반으로
한 TypeScript 라이브러리이며, JWT 인증, 구조화된 JSON 응답, 모바일
학생증 QR 생성, 시간표 조회, 공지사항, 열람실, 시설 예약 등 포털
워크플로우를 문서화하고 검증하는 데 활용되었습니다.

## 화면 미리보기

<table>
  <tr>
    <td align="center"><img src="readme-assets/screenshots/01-home.jpg" width="220" alt="메인 화면"><br>메인</td>
    <td align="center"><img src="readme-assets/screenshots/02-home-library-notice.jpg" width="220" alt="메인 열람실 공지"><br>실시간 열람실</td>
    <td align="center"><img src="readme-assets/screenshots/03-library-seat.jpg" width="220" alt="열람실 좌석"><br>좌석 예약</td>
  </tr>
  <tr>
    <td align="center"><img src="readme-assets/screenshots/04-facility-reservation.jpg" width="220" alt="시설 예약"><br>시설 예약</td>
    <td align="center"><img src="readme-assets/screenshots/05-facility-list.jpg" width="220" alt="시설 목록"><br>시설 현황</td>
    <td align="center"><img src="readme-assets/screenshots/13-facility-detail.jpg" width="220" alt="시설 상세"><br>시설 상세</td>
  </tr>
  <tr>
    <td align="center"><img src="readme-assets/screenshots/06-student-id.jpg" width="220" alt="모바일 학생증"><br>모바일 학생증</td>
    <td align="center"><img src="readme-assets/screenshots/09-ucheck.jpg" width="220" alt="U-Check"><br>U-Check</td>
    <td align="center"><img src="readme-assets/screenshots/10-timetable.jpg" width="220" alt="시간표"><br>시간표</td>
  </tr>
  <tr>
    <td align="center"><img src="readme-assets/screenshots/11-free-time.jpg" width="220" alt="공강 찾기"><br>공강 찾기</td>
    <td align="center"><img src="readme-assets/screenshots/07-community.jpg" width="220" alt="커뮤니티"><br>커뮤니티</td>
    <td align="center"><img src="readme-assets/screenshots/08-my-sejong.jpg" width="220" alt="MY 세종"><br>MY 세종</td>
  </tr>
  <tr>
    <td align="center"><img src="readme-assets/screenshots/12-facility-status.jpg" width="220" alt="학교 시설 대여"><br>학교 시설 대여</td>
    <td></td>
    <td></td>
  </tr>
</table>

모바일 학생증 미리보기의 QR 영역은 공개 저장소 노출을 피하기 위해
README용 이미지에서 가림 처리했습니다.

## 공개 저장소 운영 정책

이 저장소는 공개 저장소로 운영되므로 다음 항목을 의도적으로 제외합니다.

- `wiki/`, 비공개 구현 노트, 원본 API 캡처
- `.env`, `local.properties`, `key.properties`, keystore, provisioning profile
- 서비스 base URL, Supabase project URL/key, table/RPC/function 이름 등
  배포 시점에 주입되는 설정값
- APK, AAB, IPA 등 빌드 산출물

런타임 설정은 Dart define으로 주입합니다.

```bash
cd app
flutter pub get
flutter run --dart-define-from-file=config/dart_defines.local.json
```

`app/config/dart_defines.example.json`을 로컬에서
`app/config/dart_defines.local.json`으로 복사한 뒤 내부 서비스 URL,
Supabase URL/key, table 이름, Edge Function 이름, RPC 이름을 채워서
사용합니다.

빌드도 같은 방식으로 진행합니다.

```bash
flutter build apk --debug --dart-define-from-file=config/dart_defines.local.json
```

## 내부 테스트 APK

일상적인 내부 테스트는 GitHub Actions의 `Android internal APK` workflow를
사용합니다. 이 workflow는 debug-signed APK를 만들고 Actions artifact로
업로드합니다. release signing key는 커밋하지 않으며 필요하지도 않습니다.

연결된 내부 빌드를 위해 repository secrets에 다음 값을 설정합니다.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SEJONG_API_BASE_URL`, `SEJONG_WEB_BASE_URL`, `UCHECK_API_BASE_URL`
- `LIBSEAT_BASE_URL`, `SJPT_BASE_URL`, `HAPPYDORM_BASE_URL`
- `ANDROID_STORE_URL`
- `UCHECK_USER_AGENT`, `UCHECK_CLIENT_VERSION`, `UCHECK_DEVICE_MODEL`
- `UCHECK_AES_IV`, `UCHECK_DAILY_KEY_SALT`
- `app/config/dart_defines.example.json`에 있는 모든
  `SUPABASE_TABLE_*`, `SUPABASE_FUNCTION_*`, `SUPABASE_RPC_*` 키
- `SENTRY_DSN` (선택)

release signing은 저장소 밖에서 관리합니다. 로컬 release build는
`app/android/key.properties.template`을 `app/android/key.properties`로
복사한 뒤 private keystore 경로를 지정해서 사용할 수 있습니다. CI release
signing은 protected GitHub Environment, Play Console, Firebase App
Distribution 등 별도 배포 파이프라인에서 secret으로 처리해야 합니다.

공개 Android network security config는 cleartext attendance host를 pin하지
않습니다. host 값 자체가 이 저장소 밖에서 주입되기 때문입니다. 비공개
배포 채널에서는 host-pinned config로 교체할 수 있습니다.

## 로컬 검사

```bash
cd app
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
