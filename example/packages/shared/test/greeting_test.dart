import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  test('greet returns greeting message', () {
    expect(greet('World'), equals('Hello, World!'));
  });
}
