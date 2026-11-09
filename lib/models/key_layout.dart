import 'package:quantakeys/models/key_item.dart';

class KeyLayout {
  final String name;
  final List<List<KeyItem>> rows;

  KeyLayout({
    required this.name,
    required this.rows,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rows': rows
            .map((row) => row.map((key) => key.toJson()).toList())
            .toList(),
      };

  factory KeyLayout.fromJson(Map<String, dynamic> json) {
    if (json['name'] == null || json['rows'] == null || json['rows'] is! List) {
      throw FormatException("Invalid layout JSON format: missing 'name' or 'rows'");
    }
    var rowsJson = json['rows'] as List;
    List<List<KeyItem>> rows = rowsJson.map((rowJson) {
      if (rowJson is! List) throw FormatException("Invalid row format in layout");
      return rowJson.map((keyJson) {
        if (keyJson is! Map<String, dynamic>) throw FormatException("Invalid key item format");
        return KeyItem.fromJson(keyJson);
      }).toList();
    }).toList();

    return KeyLayout(
      name: json['name'] as String,
      rows: rows,
    );
  }
}
