import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quantakeys/providers/custom_layout_provider.dart';
import 'package:quantakeys/providers/settings_provider.dart';
import 'package:quantakeys/models/key_layout.dart';
import 'package:quantakeys/models/key_item.dart';
import 'package:quantakeys/utils/platform_utils.dart';

class CustomLayoutEditorPage extends StatefulWidget {
  const CustomLayoutEditorPage({super.key});

  @override
  State<CustomLayoutEditorPage> createState() => _CustomLayoutEditorPageState();
}

class _CustomLayoutEditorPageState extends State<CustomLayoutEditorPage> {
  final _nameController = TextEditingController();
  final _keyLabelController = TextEditingController();
  final _keyValueController = TextEditingController();
  final List<KeyItem> _currentKeys = [];
  final _platform = PlatformUtils();

  @override
  void initState() {
    super.initState();
    // Temporarily enable focus on Windows so user can type
    if (_platform.isWindows) {
      _platform.setWindowNonFocusable(false);
    }
  }

  @override
  void dispose() {
    // Re-enable non-focusable mode if overlay mode was active
    final settings = context.read<SettingsProvider>();
    if (_platform.isWindows && settings.isOverlayMode) {
      _platform.setWindowNonFocusable(true);
    }
    _nameController.dispose();
    _keyLabelController.dispose();
    _keyValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomLayoutProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Layout Editor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Layout Name (e.g., My Physics)'),
            ),
          ),
          const Divider(),
          const Text('Add Key', style: TextStyle(fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _keyLabelController, decoration: const InputDecoration(labelText: 'Label'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _keyValueController, decoration: const InputDecoration(labelText: 'Value'))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () {
                    if (_keyLabelController.text.isNotEmpty) {
                      setState(() {
                        _currentKeys.add(KeyItem(label: _keyLabelController.text, value: _keyValueController.text.isEmpty ? _keyLabelController.text : _keyValueController.text));
                        _keyLabelController.clear();
                        _keyValueController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _currentKeys.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_currentKeys[index].label),
                  subtitle: Text('Value: ${_currentKeys[index].value}'),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _currentKeys.removeAt(index))),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Custom Layout'),
              onPressed: () async {
                if (_nameController.text.trim().isNotEmpty && _currentKeys.isNotEmpty) {
                  // Organize keys into grid rows of max 8 keys per row
                  final List<List<KeyItem>> layoutRows = [];
                  const int maxRowLength = 8;
                  for (int i = 0; i < _currentKeys.length; i += maxRowLength) {
                    final end = (i + maxRowLength < _currentKeys.length) ? i + maxRowLength : _currentKeys.length;
                    layoutRows.add(List<KeyItem>.from(_currentKeys.sublist(i, end)));
                  }

                  // Add a default bottom navigation row for convenience
                  layoutRows.add([
                    KeyItem(label: 'ABC', value: 'ABC', type: KeyType.layoutSwitch, flex: 2),
                    KeyItem(label: 'space', value: ' ', flex: 6),
                    KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 2),
                    KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 2),
                  ]);

                  final newLayout = KeyLayout(
                    name: _nameController.text.trim(),
                    rows: layoutRows,
                  );
                  await provider.addLayout(newLayout);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Layout "${newLayout.name}" saved & synced!')),
                    );
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
