import AppIntents
import SwiftUI
import WidgetKit

/// 위젯의 새로고침 버튼. 실행이 끝나면 WidgetKit이 타임라인을 다시 받아 지금 시각 금액을 그린다.
/// 실행되는 동안 금액이 흐려진다(invalidatableContent). 너무 빨리 끝나면 불러오는 느낌이 안 나서 잠깐 기다린다.
struct RefreshIntent: AppIntent {
  static var title: LocalizedStringResource = "새로고침"
  func perform() async throws -> some IntentResult {
    try? await Task.sleep(for: .milliseconds(500))
    return .result()
  }
}

// 앱(lib/home_widget_sync.dart)이 공유 저장소에 써 두는 달별 예상 실수령.
let appGroup = "group.com.salaryfarming.app"

struct PayMonth: Decodable {
  let start: Double
  let end: Double
  let expected: Double

  var startDate: Date { Date(timeIntervalSince1970: start) }
  var endDate: Date { Date(timeIntervalSince1970: end) }

  /// [t] 까지 이번 달이 지난 비율 0~1.
  func ratio(at t: Date) -> Double {
    (t.timeIntervalSince1970 - start) / (end - start)
  }

  /// [t] 까지 쌓인 월급. 앱 홈과 같은 계산: 예상 실수령 × 달이 지난 비율.
  func earned(at t: Date) -> Double { expected * ratio(at: t) }
}

func loadMonths() -> [PayMonth]? {
  guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: "months"),
        let data = json.data(using: .utf8)
  else { return nil }
  return try? JSONDecoder().decode([PayMonth].self, from: data)
}

struct SalaryEntry: TimelineEntry {
  let date: Date
  let months: [PayMonth]?

  /// 지금 달. 앱을 한 번도 열지 않았거나 넘겨 둔 달을 다 썼으면 nil.
  var month: PayMonth? {
    months?.first { $0.startDate <= date && date < $0.endDate }
  }
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SalaryEntry {
    SalaryEntry(date: Date(), months: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (SalaryEntry) -> Void) {
    completion(SalaryEntry(date: Date(), months: loadMonths()))
  }

  /// 위젯은 실시간으로 숫자를 세지 못해서 1분마다 금액을 바꿔 끼운다.
  /// 3시간치를 미리 넣고, 다 쓰면 iOS가 다시 요청한다.
  func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryEntry>) -> Void) {
    let months = loadMonths()
    let now = Date()
    let minute = Calendar.current.dateInterval(of: .minute, for: now)!.start
    let entries = (0..<180).map {
      SalaryEntry(date: $0 == 0 ? now : minute.addingTimeInterval(Double($0) * 60), months: months)
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// 앱의 `field` 색. 흰 글자를 얹는 초록 면.
let field = Color(hex: 0x1E7A50)

func won(_ v: Double) -> String {
  let f = NumberFormatter()
  f.numberStyle = .decimal
  return (f.string(from: NSNumber(value: Int(v))) ?? "0") + "원"
}

struct SalaryWidgetView: View {
  let entry: SalaryEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("\(Calendar.current.component(.month, from: entry.date))월 누적 월급")
        .font(.custom("Pretendard-Regular", size: 13))
        .foregroundStyle(.white.opacity(0.85))
      Spacer(minLength: 4)
      HStack(spacing: 4) {
        let earned = entry.month?.earned(at: entry.date) ?? 0
        Text(won(earned))
          .font(.custom("Pretendard-SemiBold", size: 26))
          .monospacedDigit()
          .foregroundStyle(.white)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          // 새로고침 중에는 흐려지고, 새 금액은 숫자가 굴러 올라가며 바뀐다.
          .invalidatableContent()
          .contentTransition(.numericText(value: earned))
        Spacer(minLength: 0)
        Button(intent: RefreshIntent()) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새로고침")
      }
      Spacer(minLength: 8)
      // 막대 바탕이 초록 면에 묻히지 않게 반투명 흰 바탕을 깐다.
      bar
        .background(Capsule().fill(.white.opacity(0.25)))
        .clipShape(Capsule())
      Spacer(minLength: 8)
      Text(entry.month.map { "\(Int($0.ratio(at: entry.date) * 100))% 쌓였어요" } ?? "앱을 열면 다시 계산해요")
        .font(.custom("Pretendard-Regular", size: 12))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.85))
        .minimumScaleFactor(0.8)
        .lineLimit(1)
    }
    .containerBackground(field, for: .widget)
  }

  /// 이번 달 진행 막대. 금액과 함께 1분마다 바뀐다.
  /// ProgressView(timerInterval:)은 한 달처럼 긴 구간에서 위젯 그리기가 10초를 넘겨 강제 종료된다.
  var bar: some View {
    ProgressView(value: entry.month?.ratio(at: entry.date) ?? 0)
      .tint(.white)
  }
}

@main
struct SalaryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SalaryWidget", provider: Provider()) { entry in
      SalaryWidgetView(entry: entry)
    }
    .configurationDisplayName("누적 월급")
    .description("이번 달 월급이 한 달 내내 쌓이는 걸 보여 줘요")
    .supportedFamilies([.systemSmall])
  }
}

#Preview(as: .systemSmall) {
  SalaryWidget()
} timeline: {
  SalaryEntry(date: Date(), months: [])
}
