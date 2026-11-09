import 'math_engine.dart';
import 'chem_engine.dart';
import 'unit_engine.dart';
import 'physics_engine.dart';
import 'symbolic_engine.dart';
import 'calculus_engine.dart';
import 'advanced_engine.dart';
import 'ai_engine.dart';

class ScientificEngine {
  static final MathEngine _math = MathEngine();
  static final ChemEngine _chem = ChemEngine();
  static final UnitEngine _unit = UnitEngine();
  static final PhysicsEngine _physics = PhysicsEngine();
  static final SymbolicEngine _symbolic = SymbolicEngine();
  static final CalculusEngine _calculus = CalculusEngine();
  static final AdvancedEngine _advanced = AdvancedEngine();
  static final AiEngine ai = AiEngine();

  static String solve(String input, {
    bool useDegrees = true, 
  }) {
    if (input.isEmpty) return '';

    String cleanInput = input.trim();
    if (cleanInput.endsWith('=')) {
      cleanInput = cleanInput.substring(0, cleanInput.length - 1).trim();
    }

    String? result;

    // 1. Try Advanced Operations (nCr, Statistics, Base, Matrices)
    result = _advanced.solve(cleanInput);

    // 2. Try Calculus (Diff/Int)
    result ??= _calculus.solve(cleanInput);

    // 3. Try Symbolic Solver (Variables / Quadratic / Linear)
    result ??= _symbolic.solve(input);

    // 4. Try Unit Conversion (e.g., "10m to km")
    result ??= _unit.convert(cleanInput);
    
    // 5. Try Physics Formula (e.g., "f=ma, m=10, a=2")
    result ??= _physics.solve(cleanInput);

    // 6. Try Chem Balancing & Molar Mass
    result ??= _chem.solve(cleanInput);

    // 7. Try Math Expression
    result ??= _math.evaluate(cleanInput, useDegrees: useDegrees);

    return result ?? '';
  }

  /// Hybrid Magic Tool - Solution as suggestion OR polished text directly
  static Future<Map<String, dynamic>> processHybrid(String input) async {
    return await ai.processHybrid(input);
  }

  /// Lightning fast deterministic agent
  static Future<String?> solveAi(String input) async {
    return await ai.solve(input);
  }

  /// Pencil Tool - Deterministic grammar & scientific reconstruction
  static Future<String?> polishText(String input) async {
    return await ai.polishText(input);
  }

  /// Scientific Polisher - Professional formatting
  static Future<String?> polishScientific(String input) async {
    return await ai.polishScientificText(input);
  }
}
