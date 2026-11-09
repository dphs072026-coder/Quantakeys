enum KeyType {
  character,
  action, // backspace, enter, shift
  layoutSwitch,
  function, // e.g., solve
}

class KeyItem {
  final String label;
  final String value;
  final KeyType type;
  final int flex;
  final String? shortcut;
  final dynamic actionData;

  const KeyItem({
    required this.label,
    required this.value,
    this.type = KeyType.character,
    this.flex = 1,
    this.shortcut,
    this.actionData,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'type': type.index,
        'flex': flex,
        'shortcut': shortcut,
      };

  factory KeyItem.fromJson(Map<String, dynamic> json) => KeyItem(
        label: json['label'],
        value: json['value'],
        type: KeyType.values[json['type'] ?? 0],
        flex: json['flex'] ?? 1,
        shortcut: json['shortcut'],
      );
}
