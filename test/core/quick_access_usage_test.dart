import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/home/quick_access_usage.dart';

void main() {
  const declared = ['azkar', 'quran', 'radio', 'tracker', 'qibla'];

  test('an untouched grid keeps its declared order', () {
    // On a fresh install every count is zero. Without a stable tie-break the
    // grid would come out arbitrary and reshuffle on every rebuild.
    expect(orderByUsage(declared, const {}), declared);
  });

  test('most-used tiles come first', () {
    final order = orderByUsage(declared, const {
      'qibla': 9,
      'radio': 4,
      'azkar': 1,
    });
    expect(order.take(3).toList(), ['qibla', 'radio', 'azkar']);
  });

  test('tiles with equal use keep their declared relative order', () {
    // quran and tracker are both on 2, so the order they were written in
    // decides — quran is declared before tracker.
    final order = orderByUsage(declared, const {'quran': 2, 'tracker': 2});
    expect(order.indexOf('quran') < order.indexOf('tracker'), isTrue);
  });

  test('every tile survives the sort', () {
    final order = orderByUsage(declared, const {'radio': 3});
    expect(order.toSet(), declared.toSet());
    expect(order, hasLength(declared.length));
  });

  test('counts for tiles that no longer exist are ignored', () {
    // A removed tile leaves its count behind in storage; it must not
    // resurrect an entry or drop a real one.
    final order = orderByUsage(declared, const {'zakat_removed': 99});
    expect(order, declared);
  });
}
