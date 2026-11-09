class PhysicsEngine {
  final Map<String, String> _constants = {
    'g': '9.80665 m/s²',
    'c': '299,792,458 m/s',
    'h': '6.626e-34 J·s',
    'k': '1.38e-23 J/K',
    'e': '1.602e-19 C',
    'me': '9.109e-31 kg',
    'mp': '1.672e-27 kg',
    'nav': '6.022e23 mol⁻¹',
    'r': '8.314 J/(mol·K)',
    'sb': '5.67e-8 W/(m²K⁴)',
  };

  String? solve(String input) {
    final query = input.toLowerCase().replaceAll(' ', '');
    
    // 1. Try to solve for missing variables in common formulas
    final vars = _extractVariables(query);
    if (vars.length >= 2) {
      return _solveFormulas(vars);
    }
    
    // 2. Constants
    if (_constants.containsKey(query)) {
      return "$query = ${_constants[query]}";
    }
    
    return null;
  }

  Map<String, double> _extractVariables(String text) {
    final Map<String, double> vars = {};
    // Matches patterns like "m=10" or "m:10" or "m is 10"
    final pattern = RegExp(r'([a-z]+)[:=](\d+\.?\d*(?:e[+-]?\d+)?)');
    for (var m in pattern.allMatches(text)) {
      vars[m.group(1)!] = double.tryParse(m.group(2)!) ?? 0.0;
    }
    return vars;
  }

  String? _solveFormulas(Map<String, double> v) {
    // 1. Newton's Second Law: F = ma
    if (v.containsKey('m') && v.containsKey('a')) return "F = ${_format(v['m']! * v['a']!)} N";
    if (v.containsKey('f') && v.containsKey('m')) return "a = ${_format(v['f']! / v['m']!)} m/s²";
    if (v.containsKey('f') && v.containsKey('a')) return "m = ${_format(v['f']! / v['a']!)} kg";

    // 2. Einstein's Energy: E = mc²
    if (v.containsKey('m') && !v.containsKey('e')) {
      const c = 299792458.0;
      return "E = ${_format(v['m']! * c * c)} J";
    }

    // 3. Ohm's Law: V = IR
    if (v.containsKey('i') && v.containsKey('r')) return "V = ${_format(v['i']! * v['r']!)} V";
    if (v.containsKey('v') && v.containsKey('i')) return "R = ${_format(v['v']! / v['i']!)} Ω";
    if (v.containsKey('v') && v.containsKey('r')) return "I = ${_format(v['v']! / v['r']!)} A";

    // 4. Power: P = IV or P = W/t
    if (v.containsKey('i') && v.containsKey('v')) return "P = ${_format(v['i']! * v['v']!)} W";
    if (v.containsKey('w') && v.containsKey('t')) return "P = ${_format(v['w']! / v['t']!)} W";

    // 5. Kinetic Energy: KE = 1/2mv²
    if (v.containsKey('m') && v.containsKey('v')) {
       final ke = 0.5 * v['m']! * v['v']! * v['v']!;
       return "KE = ${_format(ke)} J";
    }

    // 6. Potential Energy: PE = mgh
    if (v.containsKey('m') && v.containsKey('h')) {
       return "PE = ${_format(v['m']! * 9.806 * v['h']!)} J";
    }

    // 7. Density: d = m/v
    if (v.containsKey('m') && v.containsKey('vol')) return "ρ = ${_format(v['m']! / v['vol']!)} kg/m³";

    // 8. Pressure: P = F/A
    if (v.containsKey('f') && v.containsKey('area')) return "P = ${_format(v['f']! / v['area']!)} Pa";

    return null;
  }

  String _format(double d) {
    if (d == d.toInt().toDouble()) return d.toInt().toString();
    if (d.abs() < 0.0001 || d.abs() > 1000000) return d.toStringAsExponential(3);
    return d.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
