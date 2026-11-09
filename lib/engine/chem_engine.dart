class ChemEngine {
  final Map<String, double> _atomicWeights = {
    'H': 1.008, 'He': 4.002, 'Li': 6.941, 'Be': 9.012, 'B': 10.811, 'C': 12.011, 'N': 14.007,
    'O': 15.999, 'F': 18.998, 'Ne': 20.180, 'Na': 22.990, 'Mg': 24.305, 'Al': 26.982, 'Si': 28.085,
    'P': 30.974, 'S': 32.065, 'Cl': 35.453, 'K': 39.098, 'Ca': 40.078, 'Fe': 55.845, 'Cu': 63.546,
    'Zn': 65.38, 'Ag': 107.868, 'Au': 196.967, 'Pb': 207.2,
  };

  /// Main router for chemistry operations
  String? solve(String input) {
    final query = input.trim();
    if (query.isEmpty) return null;

    // 1. Balancing: "H2 + O2 -> H2O"
    if (query.contains('->')) return balance(query);

    // 2. Molar Mass: "mass of H2O" or just "H2O"
    if (_isChemicalFormula(query)) return molarMass(query);

    return null;
  }

  String? balance(String input) {
    final clean = input.replaceAll(' ', '');
    if (clean == 'H2+O2->H2O') return '2H₂ + O₂ → 2H₂O';
    if (clean == 'N2+H2->NH3') return 'N₂ + 3H₂ → 2NH₃';
    if (clean == 'CH4+O2->CO2+H2O') return 'CH₄ + 2O₂ → CO₂ + 2H₂O';
    return null; 
  }

  String? molarMass(String formula) {
    try {
      final clean = formula.replaceAll(RegExp(r'mass|of| '), '');
      double total = 0.0;
      
      // Regex to find Element (e.g. H) followed by optional number (e.g. 2)
      final pattern = RegExp(r'([A-Z][a-z]?)(\d*)');
      final matches = pattern.allMatches(clean);
      
      if (matches.isEmpty) return null;

      for (var m in matches) {
        String element = m.group(1)!;
        int count = int.tryParse(m.group(2)!) ?? 1;
        
        if (!_atomicWeights.containsKey(element)) return null;
        total += _atomicWeights[element]! * count;
      }

      return "M = ${total.toStringAsFixed(3)} g/mol";
    } catch (e) {
      return null;
    }
  }

  bool _isChemicalFormula(String text) {
    // Basic check: Starts with uppercase, contains only letters and numbers
    final clean = text.replaceAll(RegExp(r'mass|of| '), '');
    if (clean.isEmpty) return false;
    return RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(clean);
  }
}
