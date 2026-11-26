// 아이콘 시트(4×4)를 아이콘 하나씩 잘라 투명 배경 PNG로 만든다.
// haru_sari 의 tool/make_icons.dart 와 같은 방식이다.
//
//   dart run tool/make_icons.dart
//
// 입력: art/source/icons/food_sheet.png, art/source/icons/office_sheet.png
//       (흰 배경, 아이콘 16개씩. 칸 순서는 lib/benefit_icons.dart 의 benefitIconSheets)
// 출력: assets/icons/<이름>.png (256×256, 투명 배경), art/source/icons/_preview.png (확인용)
//
// 시트가 하나만 있으면 그 시트만 자른다. 없는 아이콘은 앱에서 선 아이콘으로 대신 보인다.
//
// 낱장 다시 뽑기: art/source/icons/single/<이름>.png (흰 배경에 아이콘 하나)를 넣으면
// 시트에서 자른 같은 이름의 아이콘을 그것으로 바꾼다. 이름은 아래 sheets 의 영어 이름.
//
// 방법
// 1. 가장자리에서 흰 배경을 따라 번져 가며 배경을 찾는다 (외곽선 안쪽의 밝은 칠은 건드리지 않는다).
// 2. 배경과 맞닿은 가장자리 픽셀은 흰 배경과 섞인 만큼을 투명도로 되돌려 흰 테두리가 남지 않게 한다.
// 3. 이어진 덩어리를 찾아 중심이 속한 칸(4×4)에 모은 뒤, 칸마다 내용에 맞게 잘라 정사각형으로 줄인다.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const size = 256;
const sheetGrid = 4;

/// lib/benefit_icons.dart 의 benefitIconSheets 와 같은 순서여야 한다.
/// (Flutter 패키지를 쓰는 파일이라 dart run 에서 바로 가져올 수 없어 이름만 옮겨 둔다.)
const sheets = {
  'art/source/icons/food_sheet.png': [
    'coffee', 'lunchbox', 'cookie', 'drink',
    'ramen', 'rice', 'pizza', 'cake',
    'apple', 'juice', 'gift', 'coin',
    'money', 'party', 'sprout', 'ticket',
  ],
  'art/source/icons/office_sheet.png': [
    'bus', 'taxi', 'parking', 'fuel',
    'dumbbell', 'massage', 'battery', 'printer',
    'book', 'pill', 'lotion', 'tissue',
    'umbrella', 'laptop', 'shirt', 'phone',
  ],
};

void main() {
  final made = <img.Image>[];
  var found = 0;
  // 시트를 먼저 자르고, 낱장이 있으면 그 뒤에 덮어쓴다.
  final jobs = <MapEntry<String, List<String>>>[
    ...sheets.entries,
    for (final name in sheets.values.expand((v) => v))
      if (File('art/source/icons/single/$name.png').existsSync())
        MapEntry('art/source/icons/single/$name.png', [name]),
  ];
  for (final e in jobs) {
    final file = File(e.key);
    if (!file.existsSync()) {
      stdout.writeln('${e.key} 없음 — 건너뜀');
      continue;
    }
    found++;
    final grid = e.value.length == 1 ? 1 : sheetGrid; // 낱장은 칸을 나누지 않는다
    final src = img.decodeImage(file.readAsBytesSync())!.convert(numChannels: 4);
    final w = src.width, h = src.height;
    bool white(int x, int y) {
      final p = src.getPixel(x, y);
      final lo = math.min(p.r, math.min(p.g, p.b)), hi = math.max(p.r, math.max(p.g, p.b));
      return lo >= 246 && hi - lo <= 8;
    }

    // 1. 배경
    final bg = List.filled(w * h, false);
    final queue = <int>[];
    void seed(int x, int y) {
      if (!bg[y * w + x] && white(x, y)) {
        bg[y * w + x] = true;
        queue.add(y * w + x);
      }
    }

    for (var x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }
    for (var i = 0; i < queue.length; i++) {
      final x = queue[i] % w, y = queue[i] ~/ w;
      if (x > 0) seed(x - 1, y);
      if (x < w - 1) seed(x + 1, y);
      if (y > 0) seed(x, y - 1);
      if (y < h - 1) seed(x, y + 1);
    }

    // 2. 가장자리 (배경에서 2픽셀 안쪽까지)
    final dist = List.filled(w * h, 99);
    var frontier = [for (var i = 0; i < w * h; i++) if (bg[i]) i];
    for (final i in frontier) {
      dist[i] = 0;
    }
    for (var d = 1; d <= 2; d++) {
      final next = <int>[];
      for (final i in frontier) {
        final x = i % w, y = i ~/ w;
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          if (dist[j] > d) {
            dist[j] = d;
            next.add(j);
          }
        }
      }
      frontier = next;
    }
    final out = img.Image(width: w, height: h, numChannels: 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (bg[i]) continue; // 투명
        final p = src.getPixel(x, y);
        if (dist[i] <= 2) {
          // 배경과 맞닿은 가장자리: 흰 배경과 섞인 만큼을 투명도로 되돌린다(un-blend).
          // 외곽선이 있든 없든(3D 느낌 아이콘) 흰 테두리 없이 제 색으로 남는다.
          final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
          final a = ((255 - math.min(r, math.min(g, b))) / 255).clamp(0.0, 1.0);
          if (a < 0.02) continue;
          int un(double c) => ((c - 255 * (1 - a)) / a).round().clamp(0, 255);
          out.setPixelRgba(x, y, un(r), un(g), un(b), (a * 255).round());
        } else {
          out.setPixelRgba(x, y, p.r, p.g, p.b, 255);
        }
      }
    }

    // 3. 덩어리 → 칸
    final label = List.filled(w * h, -1);
    final boxes = List.generate(grid * grid, (_) => [w, h, -1, -1]); // minX, minY, maxX, maxY
    final owner = <int, int>{};
    var n = 0;
    for (var s = 0; s < w * h; s++) {
      if (bg[s] || label[s] >= 0) continue;
      final comp = <int>[s];
      label[s] = n;
      var sx = 0, sy = 0, minX = w, minY = h, maxX = -1, maxY = -1;
      for (var k = 0; k < comp.length; k++) {
        final x = comp[k] % w, y = comp[k] ~/ w;
        sx += x;
        sy += y;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          if (bg[j] || label[j] >= 0) continue;
          label[j] = n;
          comp.add(j);
        }
      }
      if (comp.length >= 12) {
        final cell = (sy / comp.length * grid ~/ h).clamp(0, grid - 1) * grid +
            (sx / comp.length * grid ~/ w).clamp(0, grid - 1);
        owner[n] = cell;
        final b = boxes[cell];
        b[0] = math.min(b[0], minX);
        b[1] = math.min(b[1], minY);
        b[2] = math.max(b[2], maxX);
        b[3] = math.max(b[3], maxY);
      }
      n++;
    }

    for (var c = 0; c < grid * grid; c++) {
      final b = boxes[c];
      if (b[2] < 0) {
        stderr.writeln('${e.key}: 칸 $c (${e.value[c]}) 가 비어 있다');
        exit(1);
      }
      final bw = b[2] - b[0] + 1, bh = b[3] - b[1] + 1;
      final side = (math.max(bw, bh) * 1.06).ceil();
      final square = img.Image(width: side, height: side, numChannels: 4);
      final ox = (side - bw) ~/ 2, oy = (side - bh) ~/ 2;
      for (var y = 0; y < bh; y++) {
        for (var x = 0; x < bw; x++) {
          final i = (b[1] + y) * w + b[0] + x;
          if (bg[i] || owner[label[i]] != c) continue; // 옆 칸에서 넘어온 조각은 뺀다
          square.setPixel(ox + x, oy + y, out.getPixel(b[0] + x, b[1] + y));
        }
      }
      final icon = img.copyResize(square, width: size, height: size, interpolation: img.Interpolation.average);
      File('assets/icons/${e.value[c]}.png').writeAsBytesSync(img.encodePng(icon));
      made.add(icon);
      stdout.writeln('${e.value[c].padRight(10)} ${bw}x$bh');
    }
  }

  if (found == 0) {
    stderr.writeln('시트가 없다. art/source/icons/food_sheet.png, office_sheet.png 를 넣어 주세요.');
    exit(1);
  }

  // 확인용: 흰 바탕과 차콜 바탕 위에 나란히
  const cols = 8, pad = 16, cell = size + pad;
  final rows = (made.length / cols).ceil();
  final sheet = img.Image(width: cols * cell + pad, height: rows * cell * 2 + pad, numChannels: 4);
  img.fill(sheet, color: img.ColorRgba8(0xFF, 0xFF, 0xFF, 255));
  final half = rows * cell;
  img.fillRect(sheet,
      x1: 0, y1: half + pad ~/ 2, x2: sheet.width, y2: sheet.height, color: img.ColorRgba8(0x1C, 0x1B, 0x19, 255));
  for (var i = 0; i < made.length; i++) {
    final x = pad + (i % cols) * cell, y = pad + (i ~/ cols) * cell;
    img.compositeImage(sheet, made[i], dstX: x, dstY: y);
    img.compositeImage(sheet, made[i], dstX: x, dstY: y + half);
  }
  File('art/source/icons/_preview.png').writeAsBytesSync(img.encodePng(sheet));
  stdout.writeln('확인용: art/source/icons/_preview.png');
}
