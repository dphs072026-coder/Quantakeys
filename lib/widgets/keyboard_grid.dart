import 'package:flutter/material.dart';
import 'package:quantakeys/models/key_layout.dart';
import 'package:quantakeys/models/key_item.dart';
import 'key_button.dart';

class KeyboardGrid extends StatelessWidget {
  final KeyLayout layout;

  const KeyboardGrid({super.key, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        children: layout.rows.map((List<KeyItem> row) {
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: row.map((KeyItem key) {
                return Expanded(
                  flex: key.flex,
                  child: KeyButton(item: key),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
