import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:place_memo/ui/common.dart';

void main() {
  testWidgets('RatingStars は評価の数だけ星を塗る', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RatingStars(value: 3))),
    );
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('RatingStars は同じ星をもう一度押すと未評価に戻る', (tester) async {
    int? result = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingStars(value: 4, onChanged: (v) => result = v),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.star).at(3));
    expect(result, isNull);
  });

  test('formatDate はゼロ埋めする', () {
    expect(formatDate(DateTime(2026, 1, 5)), '2026/01/05');
  });
}
