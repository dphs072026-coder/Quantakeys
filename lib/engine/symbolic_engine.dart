import 'package:equations/equations.dart';

class SymbolicEngine {
  /// Solves polynomials up to degree 4, e.g., "x3 - 6x2 + 11x - 6 = 0"
  String? solve(String input) {
    try {
      final query = input.trim().toLowerCase().replaceAll(' ', '');
      if (!query.contains('x')) return null;

      // Normalize common shorthand: x2 -> x^2, x3 -> x^3, etc.
      String text = query
          .replaceAll('x4', 'x^4')
          .replaceAll('x3', 'x^3')
          .replaceAll('x2', 'x^2');

      final parts = text.split('=');
      String lhs = parts[0];
      double rhsVal = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0;

      // Map to store coefficients: Power -> Value
      // e.g. x^3 - 5x + 6  =>  {3: 1.0, 1: -5.0, 0: 6.0}
      Map<int, double> coeffMap = {};
      final terms = _splitTerms(lhs);

      for (var term in terms) {
        int power = 0;
        if (term.contains('x^4')) {
          power = 4;
        } else if (term.contains('x^3')) {
          power = 3;
        } else if (term.contains('x^2')) {
          power = 2;
        } else if (term.contains('x')) {
          power = 1;
        } else {
          power = 0;
        }

        String varPart = power == 0 ? "" : (power == 1 ? "x" : "x^$power");
        double val = _parseCoeff(term, varPart);
        coeffMap[power] = (coeffMap[power] ?? 0.0) + val;
      }

      // Subtract RHS constant
      coeffMap[0] = (coeffMap[0] ?? 0.0) - rhsVal;

      // Find the highest degree
      int degree = 0;
      for (var p in coeffMap.keys) {
        if (coeffMap[p] != 0 && p > degree) degree = p;
      }

      if (degree == 0) return null;

      // Prepare coefficients for the 'equations' package (highest power first)
      List<double> coeffs = [];
      for (int i = degree; i >= 0; i--) {
        coeffs.add(coeffMap[i] ?? 0.0);
      }

      final poly = Algebraic.fromReal(coeffs);
      final solutions = poly.solutions();
      
      List<String> results = [];
      for (var s in solutions) {
        if (s.imaginary.abs() < 0.000001) {
          results.add(_format(s.real));
        } else {
          results.add("${_format(s.real)}${s.imaginary > 0 ? '+' : ''}${_format(s.imaginary)}i");
        }
      }
      
      return "x = ${results.toSet().join(', ')}";
    } catch (e) {
      return null;
    }
  }

  double _parseCoeff(String term, String varPart) {
    if (varPart.isEmpty) return double.tryParse(term) ?? 0.0;
    String coeffSection = term.replaceAll(varPart, '');
    if (coeffSection.isEmpty || coeffSection == '+') return 1.0;
    if (coeffSection == '-') return -1.0;
    return double.tryParse(coeffSection) ?? 1.0;
  }

  List<String> _splitTerms(String text) {
    final List<String> terms = [];
    final pattern = RegExp(r'([+-]?[^+-]+)');
    for (var m in pattern.allMatches(text)) {
      terms.add(m.group(1)!);
    }
    return terms;
  }

  String _format(double d) {
    if (d == d.toInt().toDouble()) return d.toInt().toString();
    return d.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
