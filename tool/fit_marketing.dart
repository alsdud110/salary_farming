// ChatGPT로 만든 홍보 스크린샷을 App Store 규격 크기로 맞춘다.
//
//   dart run tool/fit_marketing.dart
//
// 입력: tool/appstore/marketing/src/sf_{iphone,ipad,android}_{1..6}.png, sf_android_feature.png
// 출력: tool/appstore/marketing/{iphone,ipad,android}/{1..6}.png, android/feature.png
//
// 아이폰은 App Store Connect 'Dynamic Island 지원 iPhone(중형 디스플레이)' 칸 규격
// 1206×2622 로 만든다(1320×2868 은 이 칸에서 "파일 크기가 유효하지 않습니다"로 거부됨).
// 원본(약 749×2098)은 규격보다 길쭉해서, 높이에 맞춰 키운 뒤
// 남는 양옆은 각 줄의 맨 끝 색을 이어 칠한다(배경·아래 언덕이 끊기지 않게).
// 아이패드 원본(1086×1448)은 규격(2064×2752)과 비율이 같아 크기만 바꾼다.
// 안드로이드(Google Play)는 9:16 1080×1920, 피처 그래픽은 1024×500(위아래를 조금 잘라 맞춤).
import 'dart:io';

import 'package:image/image.dart' as img;

const dir = 'tool/appstore/marketing';
const sizes = {'iphone': (1206, 2622), 'ipad': (2064, 2752), 'android': (1080, 1920)};

img.Image fit(img.Image src, int w, int h) {
  final scaled = img.copyResize(
    src,
    width: (src.width * h / src.height).round().clamp(1, w),
    height: h,
    interpolation: img.Interpolation.cubic,
  );
  final out = img.Image(width: w, height: h);
  final left = (w - scaled.width) ~/ 2;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final sx = (x - left).clamp(0, scaled.width - 1);
      out.setPixel(x, y, scaled.getPixel(sx, y));
    }
  }
  return out;
}

void main() {
  for (final MapEntry(key: device, value: (w, h)) in sizes.entries) {
    Directory('$dir/$device').createSync(recursive: true);
    for (var n = 1; n <= 6; n++) {
      final src = img.decodePng(File('$dir/src/sf_${device}_$n.png').readAsBytesSync())!;
      final out = fit(src, w, h);
      assert(out.width == w && out.height == h);
      File('$dir/$device/$n.png').writeAsBytesSync(img.encodePng(out));
      stdout.writeln('$device/$n.png ${out.width}×${out.height}');
    }
  }

  final banner = img.decodePng(File('$dir/src/sf_android_feature.png').readAsBytesSync())!;
  final wide = img.copyResize(banner, width: 1024, interpolation: img.Interpolation.cubic);
  final feature = img.copyCrop(wide, x: 0, y: (wide.height - 500) ~/ 2, width: 1024, height: 500);
  assert(feature.width == 1024 && feature.height == 500);
  File('$dir/android/feature.png').writeAsBytesSync(img.encodePng(feature));
  stdout.writeln('android/feature.png ${feature.width}×${feature.height}');
}
