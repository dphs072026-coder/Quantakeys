import 'dart:math' as math;

class AdvancedEngine {
  /// Handles advanced scientific operations:
  /// - Combinatorics: "5nCr2", "10nPr3"
  /// - Statistics: "mean(1,2,3,4)", "stddev(1,2,3)"
  /// - Matrices: "det([1,2],[3,4])"
  /// - Base Conversion: "hex(FF)", "bin(1010)"
  String? solve(String input) {
    try {
      final query = input.toLowerCase().replaceAll(' ', '');

      // 1. Combinatorics (nCr, nPr)
      if (query.contains('ncr')) {
        return _handleCombinatorics(query, 'ncr');
      }
      if (query.contains('npr')) {
        return _handleCombinatorics(query, 'npr');
      }

      // 2. Statistics (mean, stddev)
      if (query.startsWith('mean(')) {
        return _handleStatistics(query, 'mean');
      }
      if (query.startsWith('stddev(')) {
        return _handleStatistics(query, 'stddev');
      }

      // 3. Matrices (Simple 2x2 or 3x3 Determinant)
      if (query.startsWith('det([')) {
        return _handleMatrix(query);
      }

      // 4. Base Conversions
      if (query.startsWith('hex(')) return _handleBase(query, 16);
      if (query.startsWith('bin(')) return _handleBase(query, 2);
      if (query.startsWith('oct(')) return _handleBase(query, 8);

      return null;
    } catch (e) {
      return null;
    }
  }

  String? _handleCombinatorics(String query, String type) {
    final parts = query.split(type);
    if (parts.length != 2) return null;
    int? n = int.tryParse(parts[0]);
    int? r = int.tryParse(parts[1]);
    if (n == null || r == null || n < r) return "Error";

    if (type == 'ncr') {
       return _format(_factorial(n) / (_factorial(r) * _factorial(n - r)));
    } else {
       return _format(_factorial(n) / _factorial(n - r));
    }
  }

  String? _handleStatistics(String query, String type) {
    final content = query.substring(query.indexOf('(') + 1, query.lastIndexOf(')'));
    final nums = content.split(',').map((e) => double.tryParse(e) ?? 0.0).toList();
    if (nums.isEmpty) return null;

    if (type == 'mean') {
      double sum = nums.reduce((a, b) => a + b);
      return "μ = ${_format(sum / nums.length)}";
    } else {
      double mean = nums.reduce((a, b) => a + b) / nums.length;
      double variance = nums.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / nums.length;
      return "σ = ${_format(math.sqrt(variance))}";
    }
  }

  String? _handleMatrix(String query) {
    // Simple determinant for [a,b],[c,d]
    final pattern = RegExp(r'\[(.*?)\]');
    final matches = pattern.allMatches(query).toList();
    if (matches.length == 2) {
      // 2x2 Matrix
      final row1 = matches[0].group(1)!.split(',').map(double.parse).toList();
      final row2 = matches[1].group(1)!.split(',').map(double.parse).toList();
      double det = (row1[0] * row2[1]) - (row1[1] * row2[0]);
      return "det = ${_format(det)}";
    }
    return null;
  }

  String? _handleBase(String query, int base) {
    final val = query.substring(query.indexOf('(') + 1, query.lastIndexOf(')'));
    try {
      int dec = int.parse(val, radix: base);
      return "dec = $dec";
    } catch (_) {
      return "Error";
    }
  }

  double _factorial(int n) {
    double res = 1;
    for (int i = 1; i <= n; i++) {
      res *= i;
    }
    return res;
  }

  String _format(double d) {
    if (d == d.toInt().toDouble()) return d.toInt().toString();
    return d.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
