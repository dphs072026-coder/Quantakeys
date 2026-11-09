import 'package:flutter_test/flutter_test.dart';
import 'package:quantakeys/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider & Map Deserialization Tests', () {
    late SettingsProvider settings;

    setUp(() {
      settings = SettingsProvider();
    });

    test('updateFromMap applies numbers, booleans, and double prefixes correctly', () async {
      await settings.updateFromMap({
        'keyboardHeightFactor': 0.8,
        'vibrationEnabled': false,
        'hapticIntensity': 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu0.8',
        'keyShape': 'pill',
        'emojiEnabled': 'true',
        'themeMode': 2,
      });

      expect(settings.keyboardHeightFactor, closeTo(0.8, 0.001));
      expect(settings.vibrationEnabled, isFalse);
      expect(settings.hapticIntensity, closeTo(0.8, 0.001));
      expect(settings.keyShape, equals('pill'));
      expect(settings.emojiEnabled, isTrue);
    });

    test('keyboardHeightFactor is clamped between 0.8 and 1.4', () async {
      await settings.initialized;
      await settings.setKeyboardHeightFactor(1.8);
      expect(settings.keyboardHeightFactor, equals(1.4));

      await settings.setKeyboardHeightFactor(0.5);
      expect(settings.keyboardHeightFactor, equals(0.8));
    });

    test('toMap produces serializable dictionary', () {
      final map = settings.toMap();
      expect(map.containsKey('keyboardHeightFactor'), isTrue);
      expect(map.containsKey('keyboardColor'), isTrue);
      expect(map.containsKey('vibrationEnabled'), isTrue);
    });
  });

  group('Keyboard Height Geometry Calculation Tests', () {
    double calculateGridHeight(double baseGridDp, double heightFactor) {
      return baseGridDp * heightFactor;
    }

    double calculateTotalHeight({
      required double heightFactor,
      bool isLandscape = false,
      bool isDesktop = false,
      double bottomInset = 0.0,
      bool isGestureNavigation = false,
    }) {
      final double suggestionH = 48.0;
      final double tabBarH = isLandscape ? 36.0 : 42.0;
      final double stripsDp = suggestionH + tabBarH;

      final double baseGridDp = isLandscape ? 160.0 : 320.0;
      final double gridDp = baseGridDp * heightFactor;

      final double chinDp = bottomInset > 0
          ? (bottomInset + 2.0)
          : (isGestureNavigation
              ? (isLandscape ? 6.0 : 8.0)
              : (isLandscape ? 10.0 : 16.0));

      final double titleBarH = isDesktop ? 32.0 : 0.0;

      return stripsDp + gridDp + chinDp + titleBarH;
    }

    test('100%, 120%, and 140% produce distinct grid and total heights in portrait', () {
      final grid100 = calculateGridHeight(340.0, 1.0);
      final grid120 = calculateGridHeight(340.0, 1.2);
      final grid140 = calculateGridHeight(340.0, 1.4);

      expect(grid100, equals(340.0));
      expect(grid120, equals(408.0));
      expect(grid140, closeTo(476.0, 0.001));

      final total100 = calculateTotalHeight(heightFactor: 1.0);
      final total120 = calculateTotalHeight(heightFactor: 1.2);
      final total140 = calculateTotalHeight(heightFactor: 1.4);

      expect(total100, equals(450.0));
      expect(total120, equals(518.0));
      expect(total140, equals(586.0));

      expect(total120 - total100, equals(68.0));
      expect(total140 - total120, equals(68.0));
    });
  });
}
