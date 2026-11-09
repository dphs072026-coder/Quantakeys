import 'package:math_expressions/math_expressions.dart';

class MathEngine {
  final Parser _parser = Parser();

  String? evaluate(String input, {bool useDegrees = true}) {
    try {
      final ContextModel cm = ContextModel();
      String query = input.trim();
      
      // 1. Handle factorial (!) - deterministic logic
      if (query.endsWith('!')) {
        int? n = int.tryParse(query.substring(0, query.length - 1));
        if (n != null && n >= 0 && n <= 20) {
          int res = 1;
          for (int i = 1; i <= n; i++) {
            res *= i;
          }
          return res.toString();
        }
      }

      // 2. Map scientific symbols to standard operators and handle implicit multiplication / percentage
      String sanitized = query
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-') // mathematical minus
          .replaceAll('√', 'sqrt')
          .replaceAll('π', 'pi')
          .replaceAll('e', 'e');

      // Handle percentage: 50% -> (50/100)
      sanitized = sanitized.replaceAllMapped(RegExp(r'(\d+\.?\d*)%'), (m) => '(${m.group(1)}/100)');

      // Handle ∛(x) -> (x)^(1/3) and ∜(x) -> (x)^(1/4)
      sanitized = sanitized.replaceAllMapped(RegExp(r'∛\(([^)]+)\)'), (m) => '(${m.group(1)})^(1/3)');
      sanitized = sanitized.replaceAllMapped(RegExp(r'∜\(([^)]+)\)'), (m) => '(${m.group(1)})^(1/4)');
      sanitized = sanitized.replaceAllMapped(RegExp(r'∛(\d+\.?\d*)'), (m) => '(${m.group(1)})^(1/3)');
      sanitized = sanitized.replaceAllMapped(RegExp(r'∜(\d+\.?\d*)'), (m) => '(${m.group(1)})^(1/4)');

      // 3. Auto-fix function syntax: sin 30 -> sin(30)
      final funcs = ['asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh', 'sin', 'cos', 'tan', 'log', 'ln', 'abs', 'sqrt'];
      for (var f in funcs) {
        sanitized = sanitized.replaceAllMapped(RegExp('$f\\s*(\\d+\\.?\\d*)'), (m) {
          return '$f(${m.group(1)})';
        });
      }

      // 4. Handle implicit multiplication (e.g. 2(3+4) -> 2*(3+4), 2x -> 2*x, 3pi -> 3*pi)
      sanitized = sanitized.replaceAllMapped(RegExp(r'(\d)(\()'), (m) => '${m.group(1)}*${m.group(2)}');
      sanitized = sanitized.replaceAllMapped(RegExp(r'(\d)([a-zpi])'), (m) => '${m.group(1)}*${m.group(2)}');
      sanitized = sanitized.replaceAllMapped(RegExp(r'(\))(\()'), (m) => '${m.group(1)}*${m.group(2)}');
      sanitized = sanitized.replaceAllMapped(RegExp(r'(\))([a-z0-9])'), (m) => '${m.group(1)}*${m.group(2)}');

      // 4. Handle specialized scientific notation and logs
      sanitized = sanitized.replaceAllMapped(RegExp(r'log(\d+)\(([^)]+)\)'), (m) {
        // logBase(x) -> log(x) / log(Base)
        return '(log(${m.group(2)}) / log(${m.group(1)}))';
      });

      // 4. Handle Degree conversion if requested
      if (useDegrees) {
        final trig = ['sin', 'cos', 'tan', 'sinh', 'cosh', 'tanh'];
        for (var f in trig) {
          sanitized = sanitized.replaceAllMapped(RegExp('$f\\(([^)]+)\\)'), (m) {
            return '$f((${m.group(1)}) * 3.141592653589793 / 180)';
          });
        }
        // Inverse trig: asin(0.5) -> asin(0.5) * 180 / pi
        final inv = ['asin', 'acos', 'atan'];
        for (var f in inv) {
          sanitized = sanitized.replaceAllMapped(RegExp('$f\\(([^)]+)\\)'), (m) {
            return '($f(${m.group(1)}) * 180 / 3.141592653589793)';
          });
        }
      }

      sanitized = sanitized.replaceAll('pi', '3.141592653589793');
      sanitized = sanitized.replaceAll('e', '2.718281828459045');
      
      // 5. Balance parentheses
      int open = '('.allMatches(sanitized).length;
      int close = ')'.allMatches(sanitized).length;
      if (open > close) sanitized += ')' * (open - close);
      
      // 6. Evaluate
      Expression exp = _parser.parse(sanitized);
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      return _format(eval);
    } catch (e) {
      return null;
    }
  }

  String _format(double d) {
    if (d.isNaN) return "Error";
    if (d.isInfinite) return "∞";
    if (d == d.toInt().toDouble()) return d.toInt().toString();
    // Use scientific notation for very large/small numbers
    if (d.abs() > 1e9 || (d.abs() < 1e-4 && d != 0)) return d.toStringAsExponential(4);
    return d.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
