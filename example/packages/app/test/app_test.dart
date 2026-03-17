import 'package:app/app.dart';
import 'package:test/test.dart';

void main() {
  test('runApp includes greeting and welcome', () {
    final result = runApp('Dev');
    expect(result, contains('Hello, Dev!'));
    expect(result, contains('Welcome'));
  });
}
