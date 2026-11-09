import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/settings_provider.dart';
import '../utils/platform_utils.dart';

class OverlayTitleBar extends StatelessWidget {
  const OverlayTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final platform = PlatformUtils();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!platform.isDesktop) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          // Drag handle area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                windowManager.startDragging();
              },
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'QuantaKeys Overlay',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Always-On-Top / Pin Toggle Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: Icon(
              settings.alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
              size: 15,
              color: settings.alwaysOnTop ? settings.accentColor : Colors.grey,
            ),
            tooltip: 'Always on top',
            onPressed: () {
              final newMode = !settings.alwaysOnTop;
              settings.setAlwaysOnTop(newMode);
              if (platform.isWindows) {
                platform.applyWindowSettings(
                  nonFocusable: settings.isOverlayMode,
                  alwaysOnTop: newMode,
                );
              }
            },
          ),

          // Minimize Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.remove, size: 15, color: Colors.grey),
            tooltip: 'Minimize overlay',
            onPressed: () async {
              await windowManager.minimize();
            },
          ),

          // Close / Hide Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.close, size: 15, color: Colors.grey),
            tooltip: 'Close overlay',
            onPressed: () async {
              await windowManager.hide();
            },
          ),
        ],
      ),
    );
  }
}
