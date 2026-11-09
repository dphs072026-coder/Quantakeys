import 'package:flutter_test/flutter_test.dart';
import 'package:quantakeys/engine/math_engine.dart';

void main() {
  group('MathEngine Tests', () {
    final mathEngine = MathEngine();

    test('Basic arithmetic evaluation', () {
      expect(mathEngine.evaluate('2 + 3 * 4'), '14');
      expect(mathEngine.evaluate('10 / 2'), '5');
      expect(mathEngine.evaluate('2^3'), '8');
    });

    test('Trigonometric evaluation with degrees', () {
      expect(mathEngine.evaluate('sin(30)', useDegrees: true), '0.5');
      expect(mathEngine.evaluate('cos(0)', useDegrees: true), '1');
    });

    test('Factorial calculation', () {
      expect(mathEngine.evaluate('5!'), '120');
      expect(mathEngine.evaluate('0!'), '1');
    });

    test('Percentage evaluation', () {
      expect(mathEngine.evaluate('50% * 200'), '100');
    });

    test('Invalid expression returns null or Error', () {
      expect(mathEngine.evaluate('invalid++'), anyOf(isNull, 'Error'));
    });
  });
}
