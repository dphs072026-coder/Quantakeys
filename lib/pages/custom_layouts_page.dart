import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custom_layout_provider.dart';
import '../utils/platform_utils.dart';
import 'custom_layout_editor_page.dart';

class CustomLayoutsPage extends StatefulWidget {
  const CustomLayoutsPage({super.key});

  @override
  State<CustomLayoutsPage> createState() => _CustomLayoutsPageState();
}

class _CustomLayoutsPageState extends State<CustomLayoutsPage> {
  final _platform = PlatformUtils();

  @override
  void initState() {
    super.initState();
    // Enable focus on Windows
    if (_platform.isWindows) {
      _platform.setWindowNonFocusable(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomLayoutProvider>();
    final layouts = provider.customLayouts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Custom Layouts'),
      ),
      body: layouts.isEmpty
          ? const Center(
              child: Text('No custom layouts yet. Tap + to create one.'),
            )
          : ListView.builder(
              itemCount: layouts.length,
              itemBuilder: (context, index) {
                final layout = layouts[index];
                return ListTile(
                  leading: const Icon(Icons.keyboard),
                  title: Text(layout.name),
                  subtitle: Text('${layout.rows.fold(0, (prev, element) => prev + element.length)} keys'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _showDeleteDialog(context, provider, layout.name);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomLayoutEditorPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CustomLayoutProvider provider, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Layout'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.removeLayout(name);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
