import 'package:math_expressions/math_expressions.dart';

class CalculusEngine {
  final Parser _parser = Parser();

  /// Handles calculus operations:
  /// - Differentiation: "diff(x^2, x)" -> "2 * x"
  /// - Numerical Integration: "int(x^2, 0, 1)" -> "0.3333"
  String? solve(String input) {
    try {
      final query = input
          .replaceAll(' ', '')
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .toLowerCase();

      // 1. Symbolic Differentiation
      if (query.startsWith('diff(')) {
        return _handleDifferentiation(query);
      }

      // 2. Numerical Integration (Simpson's rule)
      if (query.startsWith('int(')) {
        return _handleIntegration(query);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  String? _handleDifferentiation(String query) {
    // Expected format: diff(expression, variable) or diff(expression)
    final match = RegExp(r'diff\(([^,)]+)(?:,([a-z]))?\)').firstMatch(query);
    if (match == null) return null;

    final expressionStr = match.group(1)!;
    final variableStr = match.group(2) ?? 'x';

    Expression exp = _parser.parse(expressionStr);
    Expression diff = exp.derive(variableStr);
    
    // Simplify is not directly built into math_expressions, but we can return the stringified form
    return "d/d$variableStr = ${diff.toString()}";
  }

  String? _handleIntegration(String query) {
    // Expected format: int(expression, start, end)
    final match = RegExp(r'int\(([^,]+),([^,]+),([^,)]+)\)').firstMatch(query);
    if (match == null) return null;

    final expressionStr = match.group(1)!;
    final start = double.tryParse(match.group(2)!) ?? 0.0;
    final end = double.tryParse(match.group(3)!) ?? 0.0;

    Expression exp = _parser.parse(expressionStr);
    ContextModel cm = ContextModel();
    Variable x = Variable('x');

    // Numerical Integration using Simpson's 1/3 Rule
    const int n = 100; // Intervals
    double h = (end - start) / n;
    double sum = 0;

    double evaluateAt(double val) {
      cm.bindVariable(x, Number(val));
      return exp.evaluate(EvaluationType.REAL, cm);
    }

    sum += evaluateAt(start) + evaluateAt(end);

    for (int i = 1; i < n; i++) {
      double val = start + i * h;
      sum += (i % 2 == 0 ? 2 : 4) * evaluateAt(val);
    }

    double result = (h / 3) * sum;
    return "∫ = ${_format(result)}";
  }

  String _format(double d) {
    if (d == d.toInt().toDouble()) return d.toInt().toString();
    return d.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
