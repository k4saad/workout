import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';

/// Seconds read as time, metres as distance, reps as reps: a 25-minute run
/// is never "1500 reps" (audit C6, and the v3 plan's runner bug).
void main() {
  test('reps are reps', () {
    expect(RepUnit.reps.rangeLabel(8, 10), '8–10 reps');
    expect(RepUnit.reps.rangeLabel(5, 5), '5 reps');
    expect(RepUnit.reps.amountLabel(8), '8');
  });

  test('short holds stay in seconds, runs read in minutes', () {
    expect(RepUnit.sec.rangeLabel(30, 45), '30–45 s');
    expect(RepUnit.sec.rangeLabel(1440, 1560), '24–26 min');
    expect(RepUnit.sec.rangeLabel(1200, 1200), '20 min');
    expect(RepUnit.sec.rangeLabel(150, 150), '2.5 min');
    expect(RepUnit.sec.amountLabel(45), '45 s');
    expect(RepUnit.sec.amountLabel(1500), '25:00');
    expect(RepUnit.sec.amountLabel(1537), '25:37');
  });

  test('distance reads in kilometres past a kilometre', () {
    expect(RepUnit.m.rangeLabel(5000, 5000), '5 km');
    expect(RepUnit.m.rangeLabel(400, 400), '400 m');
    expect(RepUnit.m.rangeLabel(2500, 3000), '2.5–3 km');
    expect(RepUnit.m.amountLabel(4870), '4.87 km');
    expect(RepUnit.m.amountLabel(800), '800 m');
  });
}
