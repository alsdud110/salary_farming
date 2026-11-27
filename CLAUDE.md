# 월급파밍 (salary_farming)

일하는 동안 오늘 번 월급과 회사에서 챙긴 혜택(탕비실 커피, 점심 식대 등)을 실시간으로 보여주는 직장인용 Flutter 앱.
서버·회원가입 없음. 모든 데이터는 기기 안(SharedPreferences)에만 저장한다. iOS 홈 화면 위젯(이번 달 누적 월급)이 있다.

## 작업 규칙 (사용자 선호)

- **사용자에게 보이는 모든 글은 한국어로만 쓴다.** 최종 답변뿐 아니라 작업 중 진행 설명, 짧은 중간 메시지까지 전부. 영어로 새면 크게 화낸다. 이미지 AI 프롬프트처럼 영어가 꼭 필요한 것만 예외이고, 설명은 한국어로 붙인다.
- 커밋·푸시는 사용자가 요청할 때만. 사용자가 직접 커밋하는 경우가 많다.
- "수정하지 말고 보고해"라고 하면 코드는 건드리지 않고 분석만 보고한다.
- 동작을 설명할 때는 함수 이름만 보고 짐작하지 말고 **실제 화면이 쓰는 계산을 따라가서** 확인한다(예: 홈 월 누적은 `monthSalary`가 아니라 `monthElapsedRatio`를 쓴다).
- 화면을 바꾸면 캡처를 뽑아 직접 보고 확인한 뒤 보고한다(아래 "실행·검증").
- 사용자가 직접 정한 문구·동작(혜택 칸 spring 반응, 소개 2장 "툭 튀어나오는" 애니메이션, 적립 직후 상황별 한마디 등)은 디자인 규칙과 부딪혀도 유지하고, 바꿀지 물어본다.
- 파일 삭제(`rm`)와 첫 Bash 명령은 훅(Fact-Forcing Gate)이 막는다. 요청 한 줄과 명령이 하는 일을 먼저 적고 다시 실행한다. 삭제는 지울 파일 목록, 되돌리는 방법, 사용자 지시 원문까지 적는다.

## 실행·검증

```bash
flutter analyze                                        # 경고 0 유지
flutter test                                           # 단위·위젯 테스트 (현재 97개 통과)
flutter test tool/screenshot_test.dart --update-goldens    # 화면 캡처 → tool/shots/*.png (라이트·다크)
flutter test tool/appstore_shots_test.dart --update-goldens # 스토어용 실제 화면 캡처 → tool/appstore/{iphone,ipad}/
dart run tool/fit_marketing.dart                       # 홍보 이미지 규격 맞추기 → tool/appstore/marketing/*
dart run tool/make_icons.dart                          # 혜택 아이콘 시트 자르기 → assets/icons/*.png
dart run tool/make_app_icon.dart                       # 런처 아이콘(iOS·Android) 만들기
flutter build apk --debug                              # 안드로이드 빌드 확인
```

- 이 환경의 `python`은 Windows 스토어 가짜 실행 파일이라 쓸 수 없다. 여러 줄 치환·이미지 처리는 스크래치패드에 Dart 스크립트를 써서 돌린다. `image` 패키지가 필요하면 `dart --packages=.dart_tool/package_config.json <스크립트>`로 프로젝트 패키지를 빌려 쓴다(sed 의 `\n` 이스케이프는 자주 깨진다).
- 홈 화면은 금액이 매 프레임 오르고(LiveAmount), 살아 있는 점이 깜빡여서 `pumpAndSettle`이 끝나지 않는다. 테스트·캡처에서는 `pump(Duration)`을 여러 번 쓴다(캡처 도구의 `settle` 참고).
- 캡처에 옛 아이콘이 남아 보이면 `build/unit_test_assets` 캐시 탓이다 → `flutter clean` 후 `flutter pub get`.

## 구조

```
lib/
  main.dart                 앱 진입. 스플래시 → 설정이 없으면 온보딩(SetupScreen), 있으면 RootScreen. 라이트/다크 테마,
                            store 가 바뀔 때마다 iOS 위젯 데이터 동기화
  models.dart               WorkSettings(직업군·급여 방식·근무 시간·paidBreak), 설정 이력, 혜택 템플릿·기록
  tax.dart                  2026년 4대보험·간이세액표 방식 소득세 → 세전 연봉의 월 실수령 추정
  salary_calculator.dart    하루치·오늘 누적·근무 진행률·근무 상태(WorkPhase)·isGrowing·monthElapsedRatio
  app_store.dart            저장/불러오기, 기간 합계, 적립·삭제, 설정 이력, 파밍 효과(애니메이션·햅틱)·다크 테마 설정
  period.dart               결산 기간(일·주·월·연), 파밍 일지 한마디(buildInsights, 급여 숨김 옵션)
  home_widget_sync.dart     iOS 위젯에 앞으로 3달치 예상 실수령을 넘김(MethodChannel 'salary_farming/widget')
  benefit_icons.dart        혜택 아이콘 32종(저장 키=이모지 문자열, 파일명, 대체 아이콘, 고유색)
  default_templates.dart    기본 혜택 12개, 아이콘 고르기 목록
  theme.dart                Money Green 디자인 토큰(AppColors 고정색, AppPalette 라이트/다크, AppRadius, surfaceBox)
  motion.dart               모션 규칙(스낵바·토스트·팝업·시트·spring·로딩·한 줄씩·살아 있는 점)
  format.dart               금액·시각 표기, 천 단위 입력기, 좁은 칸용 짧은 금액
  screens/
    splash_screen.dart      브랜드 심볼 + 이름 fade in
    intro_view.dart         소개 3장(실시간 월급 데모, 혜택 톡톡 데모, 파밍 밭이 채워지는 결산 데모)
    setup_screen.dart       온보딩: 소개 → 직업 → 급여 → 근무 시간 → "월급 계산표 만드는 중" → 시작
    root_screen.dart        하단 탭(오늘 / 수확 결산 / 설정), 아이콘 미리 불러오기
    home_screen.dart        홈(아래 "홈 구성")
    stats_screen.dart       수확 결산(일·주·월·연), 파밍 수익 중심 카드, 기간별 그림, 파밍 일지, 혜택 순위
    share_screen.dart       결산 이미지(파밍 수익만 / 전체 수익 선택, 저장·공유)
    settings_screen.dart    급여·근무 시간 수정, 혜택 템플릿 관리, 파밍 효과, 테마 바꾸기, 데이터 지우기, 앱 정보
  widgets/
    work_settings_form.dart SettingsDraft + 직업 선택·급여 입력·근무 시간 입력·계산 기준 카드
    time_wheel_sheet.dart   아이폰 알람식 시간 휠 시트
    template_sheet.dart     혜택 만들기/고치기 시트
    benefit_glyph.dart      혜택 아이콘(PNG 있으면 그림, 없으면 고유색 아이콘), 미리 불러오기
    brand_symbol.dart       브랜드 심볼(동전 + 새싹). 혜택 아이콘과 섞어 쓰지 않음
    farm_burst.dart         적립 효과(동전이 수확 카드로 날아감, +금액 떠오름), 상황별 한마디(farmMessage)
    farm_charts.dart        결산 그림: 일간 시간 띠(DayTimeline), 주간 요일별 탑(WeekStacks),
                            월간 파밍 밭(FarmField), 연간 12개월 격자(YearGrid)
    top_benefits.dart       많이 파밍한 혜택 1~3위 칸(결산 화면·공유 이미지 공용)
    theme_toggle_tile.dart  라이트↔다크 버튼(해·달 Lottie, assets/lottie/theme_toggler.json)
    live_amount.dart        매 프레임 다시 계산해 끊김 없이 오르는 금액
    rolling_amount.dart     값이 바뀔 때 굴러가는 금액
ios/
  Runner/AppDelegate.swift  위젯 채널 받아 App Group 저장소에 쓰고 위젯 새로고침
  SalaryWidget/             홈 화면 위젯(SwiftUI, WidgetKit). Pretendard 글꼴 포함
android/app/                applicationId·namespace = com.salaryfarming.app (MainActivity: kotlin/com/salaryfarming/app)
docs/privacy/index.html     개인정보 처리방침(GitHub Pages, 한국어·영어)
tool/
  screenshot_test.dart      확인용 캡처(온보딩 전 과정, 홈, 시간대별 홈, 결산, 다크)
  appstore_shots_test.dart  스토어 제출용 실제 화면 캡처(iPhone 6.9" 1320×2868, iPad 13" 2064×2752)
  fit_marketing.dart        ChatGPT로 만든 홍보 이미지(marketing/src)를 규격 크기로
  make_icons.dart           4×4 혜택 아이콘 시트를 잘라 256px 투명 PNG로
  make_app_icon.dart        art/source/app_icon.png → iOS·Android 런처 아이콘
test/                       widget_test(계산·저장·화면·접근성), motion, benefit_icons, brand, farm_effects,
                            home_widget, share, stats, theme, app_icon
assets/fonts/               Pretendard(OFL). 400·600·700·800 파일이 있으나 화면은 400·600만 씀
assets/icons/               혜택 일러스트 32개(PNG)
assets/images/brand/        브랜드 심볼
art/source/                 app_icon.png, icons/(food_sheet.png, office_sheet.png, single/ 낱장 교체용)
```

## 핵심 계산 규칙

- **급여 방식**: 정규직·계약직 = 세전 연봉 / 세후 월급, 아르바이트 = 시급 / 일당, 프리랜서 = 월 계약금 / 일당(3.3% 원천징수 선택).
- **세전 연봉 → 실수령**: 12로 나눈 뒤 국민연금 4.75%(기준소득월액 41만~659만), 건강보험 3.595%, 장기요양(건보료×13.14%), 고용보험 0.9%, 간이세액표 산식의 소득세 + 지방소득세 10%. 본인 1명, 식대 20만원 비과세를 가정(입력칸 없음). 5,500만원 → 월 약 3,888,863원.
  추정이 틀리면 "아니요, 직접 입력할게요" 버튼으로 세후 월급 입력으로 바뀐다(추정치를 미리 채움). 세전 연봉 입력칸 placeholder 는 40,000,000.
- **하루치**: 월 금액 ÷ 그 달 근무일 수. 시급 = 시급 × 급여가 쌓이는 시간.
- **두 가지 누적이 다르게 쌓인다**:
  - **오늘의 총 수확·기본 수익·근무 진행률** = 근무 시간 기준. 출근~퇴근 동안만 오르고, 출근 전·퇴근 후·쉬는 날은 멈춤.
  - **n월 누적 월급(홈)·iOS 위젯** = 예상 실수령 × 이번 달이 지난 비율(`SalaryCalculator.monthElapsedRatio`). **밤·주말·자는 동안에도 24시간 고르게** 오른다(스토어 부제 "자는 동안에도 자라는 월급"의 근거).
    shortcut: 달 중간에 급여 설정을 바꾸면 바뀐 설정으로 그 달 전체를 다시 계산한다.
  - 수확 결산의 기본 수익(`AppStore.monthSalary` 등)은 날짜별 하루치 합(근무 시간 기준)이다.
- **휴게시간에도 급여 쌓기(paidBreak)**: 사용자가 켜고 끈다, 기본 켜짐(예전 저장 데이터도 켜짐으로 읽음).
  켜짐 = 출근~퇴근 내내 고르게 쌓임(시급은 휴게시간도 시급으로 침). 꺼짐 = 휴게 중 멈춤(시급은 휴게 제외).
- **실시간**: 1초 미만 단위까지 계산하고 매 프레임 그린다(1초마다 뚝뚝 오르지 않게).
- **첫 설정**: 이번 달 1일부터 일한 것으로 친다. 설정 변경은 오늘부터 적용, 지난 날은 그대로(설정 이력).
- **날짜 경계**: 기기 시간대 기준. 자정이 지나면 '오늘' 값(총 수확·근무 진행률·오늘의 파밍 일지)은 0부터, 기록·월 누적은 유지. 자정을 넘기는 야간 근무는 미지원.
- **근무 상태**: 쉬는 날 / 출근 전 / 근무 중 / 휴게 중 / 퇴근.

## 홈 구성 (위에서부터)

1. 브랜드 심볼 + "월급파밍", 날짜, 오른쪽 설정 버튼(설정 탭으로 이동)
2. 초록 메인 카드: 오늘의 총 수확(+ 살아 있는 점), "매초 +x원씩 자라는 중", 기본 수익 / 파밍 수익(골드, 0이면 '+' 없음). 적립하면 파밍 수익이 카운트업
3. 오늘의 근무: 상태 칩, %, 막대, "퇴근까지 n시간 n분" · 근무 시간(근무 없는 날은 근무 시간 숨김, 막대는 숨기지 않음)
4. n월 누적 월급 (mm/01~mm/말일): 오늘의 근무와 **같은 틀(_ProgressSection)**, "x원 쌓였어요" · 예상 실수령. 24시간 오름
5. 무엇을 파밍했나요? + 전체 보기(전체 혜택 시트) — 홈에는 3칸만(기본: 탕비실 커피·점심 식대·탕비실 간식). 탭=바로 적립(동전 효과·햅틱·스낵바 "취소"), 길게=고치기
6. 노란 "직접 추가" 버튼 → 내 혜택 만들기 시트
7. 오늘의 파밍 일지(오늘 기록, X로 삭제)

## 수확 결산·공유

- 기간: 일·주·월·연. 맨 위 카드에 **파밍 수익을 가장 크게**, 지난 기간과 비교 문구, 아래에 총 수확·기본 수익.
- 그림은 파밍 수익(골드)만: 일간 시간 띠, 주간 요일별 탑, 월간 파밍 밭(달력), 연간 12개월 격자. 가까운 것끼리 묶어 아이콘 하나 + 개수 배지, 누르면 펼침.
- 파밍 일지는 한 줄씩 넘겨 보기, 혜택은 1~3위 칸 + 4위부터 목록.
- 결산 이미지: 기본값 "파밍 수익만"(급여를 짐작할 수 있는 숫자·문구를 전부 뺌, share_test 가 확인), "전체 수익" 선택 가능. 테마와 상관없이 밝은 카드.

## 디자인 시스템 (Money Green)

- 팔레트: Primary #27875C, Secondary #BCE8C8, Accent(골드) #E8B84A, Background #F6F8F2, Surface #FFFFFF, Text #20382B, Text2 #607565.
- 대비(WCAG AA)를 위해 흰 글자를 얹는 면(메인 카드·버튼)은 `field` #1E7A50, 밝은 바탕 위 골드 글자는 `benefitInk` #8A6410, 작은 초록 글자는 `field`. 초록 면 위 큰 금액은 흰색, 파밍 수익 금액만 `benefitOnDark`.
- **다크 테마**: 테마에 따라 바뀌는 색(바탕·카드·글자·선)은 `AppPalette`(ThemeExtension) → 화면에서 `context.colors.ink`처럼 쓴다. 초록 메인 카드·골드처럼 어느 테마에서나 같은 색은 `AppColors` 상수. 설정의 해·달 버튼으로 바꾸고 `dark_theme` 키로 저장(데이터 지우기에도 유지). 다크 대비도 theme_test 가 확인.
- 카드는 테두리·그림자 없이 면 + 둥근 모서리(카드 20, 칸 18, 버튼 16). 간격은 4px 격자.
- 글꼴 Pretendard 한 가족. 굵기는 큰 글자(16 이상) 600, 작은 글자 500. 700 이상 쓰지 않음.
- 문구: 느낌표·인사말 없음, 한 문장짜리 짧은 문구는 끝 마침표 없음, 금액은 `+2,000원` 형식(0이면 '+' 없음).
  예외: 적립 직후 한마디(`farmMessage`: "커피 한 잔 파밍 완료!" 등)는 사용자가 정한 문구라 유지.
- 브랜드 용어: 오늘의 총 수확, 기본 수익, 파밍 수익, 파밍하기, 파밍 일지, 수확 결산.
- 시그니처: 돈이 실제로 쌓이는 중일 때만 금액 옆에 뜨는 작은 '살아 있는 점'(LiveDot). 다른 곳에는 쓰지 않는다.
- 브랜드 심볼(동전 + 새싹, `BrandSymbol`): 홈 헤더·스플래시·소개 첫 장·세팅 완료·결산 이미지 하단·설정 앱 정보. 원본 색 그대로, 필터·그림자 없음.
- 혜택 아이콘: 일러스트 PNG(평면 스티커 스타일, 짙은 초록·민트·골드·크림·코랄). 목록 40, 그리드 44.

## 모션 규칙 (lib/motion.dart)

- 스낵바(취소 있는 알림): 아래에서 slide in, 들어올 때 ease out · 나갈 때 ease in, **1.5초** 머묾.
- 토스트(알림만): 제자리 fade, **1.2초** 머묾.
- 팝업: 0.9→1 scale in, ease out.
- 바텀시트: 아래에서 slide in, 배경 fade. 화면의 90%까지만, 상태 표시줄 아래에서 멈춤, 제목 옆 닫기(X).
- 혜택 칸 누르기: spring으로 톡(사용자 요청으로 유지).
- 적립 효과(farm_burst): 동전이 수확 카드로 날아가고 +금액이 떠올랐다 사라짐(0.7초, 터치 막지 않음, 동시에 최대 3개). 설정에서 파밍 애니메이션·햅틱 각각 끌 수 있음.
- 로딩: linear로 같은 속도 회전.
- 제목·순서: 한 줄씩 순서대로(StaggerIn).
- 기기 "움직임 줄이기"가 켜져 있으면 전부 바로 나타남.

## iOS 홈 화면 위젯

- 작은 위젯 하나: 이번 달 누적 월급(1분마다 갱신), 진행 막대, "n% 쌓였어요". 새로고침 버튼은 금액을 흐렸다 굴려 보여줌.
- 앱이 `home_widget_sync.dart` → `AppDelegate.swift` 로 앞으로 3달치 `{start, end, expected}`를 App Group `group.com.salaryfarming.app` 의 `months` 키에 쓰고, 위젯(`ios/SalaryWidget/SalaryWidget.swift`)은 "예상 실수령 × 달이 지난 비율"만 계산한다. 앱을 안 열어도 달이 바뀌면 이어서 오른다.
- `ProgressView(timerInterval:)`은 한 달처럼 긴 구간에서 위젯 그리기가 10초를 넘겨 강제 종료되므로 쓰지 않는다.
- 안드로이드 위젯은 없다.

## 스토어·배포 정보

- 앱 이름(홈 화면 표시): **월급파밍** (iOS `CFBundleDisplayName`, Android `android:label`)
- 스토어 표시 이름: **월급파밍 - 자는 동안에도 자라는 월급** (App Store Connect·Google Play 에 직접 입력, 30자 이내)
- App Store 부제: **실시간 월급 계산기 · 홈 화면 위젯**. SKU `salaryfarming`, Apple ID 6839693654, 기본 언어 한국어.
- 카테고리: 주 **금융**(세금·실수령 계산이 핵심, "월급 계산기" 검색 기대와 맞음). 보조는 생산성으로 입력돼 있으나 라이프스타일을 추천해 둠(탕비실 혜택·공유 같은 재미 쪽). Google Play 는 금융 하나.
- 번들 ID: iOS `com.salaryfarming.app`(위젯 `com.salaryfarming.app.SalaryWidget`), Android `com.salaryfarming.app`(둘 다 같음). iOS 서명 팀 지정 완료.
- Info.plist: `ITSAppUsesNonExemptEncryption = NO`.
- 개인정보 처리방침: `docs/privacy/index.html`(GitHub Pages). 서버 없음, 수집 없음, 사진 저장 권한만 사용.
- 홍보 이미지(`tool/appstore/marketing/`): src 원본(ChatGPT 생성) → `fit_marketing.dart`.
  - iPhone **1206×2622**: App Store Connect 'Dynamic Island 지원 iPhone(중형 디스플레이)' 칸은 1206×2622·1179×2556만 받는다. 1320×2868 은 "파일 크기가 유효하지 않습니다"로 거부됨.
  - iPad 13" 2064×2752, Android 휴대폰 1080×1920, 피처 그래픽 1024×500.
- Android 릴리스 서명: `android/key.properties` + `android/upload-keystore.jks`(alias upload, 둘 다 저장소 제외, 견본은 `key.properties.example`). 없으면 디버그 키로 서명.
  업로드 키 인증서 SHA-256 `03:2E:7D:48:…:A4:3B`. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`. 키·비밀번호는 사용자가 따로 백업.

## 아이콘 에셋 다시 만들기

- 혜택 아이콘: `art/source/icons/food_sheet.png`, `office_sheet.png`(4×4, 순백 배경, 그림자 없음)를 넣고 `dart run tool/make_icons.dart`.
  - 낱장 교체: `art/source/icons/single/<영어이름>.png` → 시트에서 자른 같은 이름을 덮어씀.
  - 칸 순서는 `lib/benefit_icons.dart`의 `benefitIconSheets`와 `tool/make_icons.dart`의 `sheets`가 같아야 한다(테스트가 확인).
  - 스타일: 3D 광택은 "AI 티 난다"고 거절됨 → 평면 스티커 스타일(도형 2~4개, 색 제한, 그라데이션·광택·그림자 없음)로 확정.
- 앱 아이콘: `art/source/app_icon.png`(정사각형, 흰 배경) → `dart run tool/make_app_icon.dart`. iOS는 알파 없는 RGB, Android 적응형 아이콘은 흰 배경 + 투명 앞 그림(안전 영역 안).

## 현재 상태 (2026-11-27 기준)

- 최근 커밋: 다크 테마, 결산 개편, 적립 효과, 브랜드 심볼·앱 아이콘, 월 누적 24시간, iOS 위젯, 번들 ID, 개인정보 페이지, 스토어 캡처·홍보 이미지, iOS 서명 팀.
- 모든 변경 커밋됨(마지막: `dc9d6b1 CLAUDE.md 수정`, 그 전 `7c60d05 안드로이드 ID 변경`).
- App Store Connect 앱 정보 입력 완료(1.0 제출 준비 중).
- Google Play Console: 앱 생성(com.salaryfarming.app, 무료, 한국어), 앱 콘텐츠 선언 전부(광고 없음, 데이터 수집 없음, 만 18세 이상, 전체이용가, 금융·건강 기능 없음, 판매자 상태 예), 스토어 설정(금융), 기본 등록정보(설명·아이콘·피처 그래픽·스크린샷 6장, AI 생성 라벨 지정) 완료.
  2026-11-27 비공개 테스트(Alpha) 1 (1.0.0) 검토 제출: 국가 대한민국. 승인 뒤 사용자가 테스터 Google 그룹을 직접 지정.
  남은 것: 테스터 12명 이상 14일 이상 비공개 테스트 → 프로덕션 신청.
- `flutter analyze` 경고 0, 테스트 97개 통과.

## 남은 일 / 아이디어 (요청 시에만)

- Play 비공개 테스트(12명·14일) → 프로덕션 신청.
- 자정을 넘기면 오늘 값이 0이 되는지 확인하는 테스트 추가(제안만 해 둠).
- 월 누적이 달 중간 설정 변경을 이력대로 나눠 계산하지 않음(위 shortcut).
- 이미 설치된 기기는 기본 혜택 '휴대폰 충전'이 예전 빈도(매일)라 홈 3칸에 들어갈 수 있음 → 길게 눌러 빈도를 바꾸거나 데이터 초기화.
- 야간 근무(자정 넘김) 미지원. 주휴수당·자녀세액공제·상여금은 계산하지 않음. 백업·기기 간 동기화 없음.
