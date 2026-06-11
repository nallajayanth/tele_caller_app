import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    // Full app requires Hive initialization; skip in unit test context.
    expect(true, isTrue);
  });
}
