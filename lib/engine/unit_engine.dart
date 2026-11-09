import 'package:units_converter/units_converter.dart';

class UnitEngine {
  final RegExp _convertRegex = RegExp(r'^([\d.]+)\s*([a-zA-Z°]+)\s+to\s+([a-zA-Z°]+)$', caseSensitive: false);

  String? convert(String input) {
    final match = _convertRegex.firstMatch(input.trim());
    if (match == null) return null;

    try {
      double value = double.parse(match.group(1)!);
      String fromUnitStr = match.group(2)!.toLowerCase();
      String toUnitStr = match.group(3)!.toLowerCase();

      // Find the category and perform conversion
      // This is a simplified mapping for demonstration
      if (_isLength(fromUnitStr)) {
        return _performLengthConversion(value, fromUnitStr, toUnitStr);
      } else if (_isMass(fromUnitStr)) {
        return _performMassConversion(value, fromUnitStr, toUnitStr);
      } else if (_isTemperature(fromUnitStr)) {
        return _performTempConversion(value, fromUnitStr, toUnitStr);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  bool _isLength(String unit) => ['m', 'km', 'cm', 'mm', 'in', 'ft', 'yd', 'mi'].contains(unit);
  bool _isMass(String unit) => ['g', 'kg', 'mg', 'lb', 'oz'].contains(unit);
  bool _isTemperature(String unit) => ['c', 'f', 'k', '°c', '°f'].contains(unit);

  String? _performLengthConversion(double val, String from, String to) {
    var converter = val.convertFromTo(LENGTH.values.byName(_mapLength(from)), LENGTH.values.byName(_mapLength(to)));
    return converter?.toStringAsFixed(4);
  }

  String? _performMassConversion(double val, String from, String to) {
    var converter = val.convertFromTo(MASS.values.byName(_mapMass(from)), MASS.values.byName(_mapMass(to)));
    return converter?.toStringAsFixed(4);
  }

  String? _performTempConversion(double val, String from, String to) {
    var converter = val.convertFromTo(TEMPERATURE.values.byName(_mapTemp(from)), TEMPERATURE.values.byName(_mapTemp(to)));
    return converter?.toStringAsFixed(4);
  }

  String _mapLength(String u) {
    switch(u) {
      case 'in': return 'inches';
      case 'ft': return 'feet';
      case 'mi': return 'miles';
      case 'yd': return 'yards';
      case 'mm': return 'millimeters';
      case 'cm': return 'centimeters';
      case 'm': return 'meters';
      case 'km': return 'kilometers';
      default: return 'meters';
    }
  }

  String _mapMass(String u) {
    switch(u) {
      case 'g': return 'grams';
      case 'kg': return 'kilograms';
      case 'lb': return 'pounds';
      case 'oz': return 'ounces';
      case 'mg': return 'milligrams';
      default: return 'grams';
    }
  }

  String _mapTemp(String u) {
    switch(u) {
      case 'c':
      case '°c': return 'celsius';
      case 'f':
      case '°f': return 'fahrenheit';
      case 'k': return 'kelvin';
      default: return 'celsius';
    }
  }
}
