# 월급파밍 (Salary Farming)

일하는 동안 쌓이는 실제 급여와 회사에서 얻은 혜택을 기록하고, 하루의 총 경제적 가치를 보여주는 iOS·Android 앱.
서버와 회원가입 없이 모든 데이터를 기기 안에만 저장한다.

## 실행

```
flutter pub get
flutter run
flutter test
```

## 급여 계산 기준

- 지급 주기(달력상 한 달 또는 한 주)의 급여를 그 주기 안의 근무일 수로 똑같이 나눠 하루치로 삼는다.
- 하루치는 휴게시간을 뺀 근무 시간 동안 고르게 쌓인다. 출근 전·휴게 중·퇴근 후·비근무일에는 쌓이지 않는다.
- 세금과 공제는 계산하지 않는다. 입력한 금액이 그대로 기준이다.
- 설정을 바꾸면 그날부터 적용되고, 지난 날의 급여는 바뀌지 않는다.
- 자정을 넘기는 근무는 지원하지 않는다.

## 구조

| 파일 | 내용 |
|---|---|
| `lib/models.dart` | 근무 설정, 혜택 템플릿, 적립 기록 |
| `lib/salary_calculator.dart` | 실제 급여 계산 |
| `lib/app_store.dart` | 상태와 로컬 저장(SharedPreferences) |
| `lib/period.dart` | 일간·주간·월간·연간 기간과 결산 문구 |
| `lib/screens/` | 첫 설정, 오늘, 결산, 결산 이미지, 설정 |
| `tool/screenshot_test.dart` | 화면을 PNG로 뽑아 확인하는 스크립트 (Windows 전용) |

## 참고

`android/gradle.properties`의 `kotlin.incremental=false`는 프로젝트와 pub 캐시가 서로 다른 드라이브에 있을 때 생기는 Kotlin 증분 컴파일 오류를 피하려고 넣었다.
