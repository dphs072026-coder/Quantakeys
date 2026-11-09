import 'package:flutter_test/flutter_test.dart';
import 'package:quantakeys/models/key_item.dart';
import 'package:quantakeys/models/key_layout.dart';

void main() {
  group('KeyLayout JSON & Validation Tests', () {
    test('KeyLayout toJson and fromJson roundtrip', () {
      final layout = KeyLayout(
        name: 'TestLayout',
        rows: [
          [
            KeyItem(label: '1', value: '1', type: KeyType.character, flex: 1),
            KeyItem(label: '+', value: '+', type: KeyType.character, flex: 1),
          ],
        ],
      );

      final jsonMap = layout.toJson();
      expect(jsonMap['name'], 'TestLayout');
      expect(jsonMap['rows'], isA<List>());

      final decoded = KeyLayout.fromJson(jsonMap);
      expect(decoded.name, 'TestLayout');
      expect(decoded.rows.length, 1);
      expect(decoded.rows[0].length, 2);
      expect(decoded.rows[0][0].label, '1');
      expect(decoded.rows[0][1].value, '+');
    });

    test('KeyLayout.fromJson throws FormatException on invalid structure', () {
      expect(() => KeyLayout.fromJson({'invalid': 'data'}), throwsA(isA<FormatException>()));
      expect(() => KeyLayout.fromJson({'name': 'Test', 'rows': 'not-a-list'}), throwsA(isA<FormatException>()));
    });
  });
}
