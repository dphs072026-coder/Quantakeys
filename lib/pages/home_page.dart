import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../main.dart';
import '../utils/platform_utils.dart';
import '../providers/settings_provider.dart';
import 'settings_page.dart';
import 'instruction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener, WidgetsBindingObserver {
  final _platform = PlatformUtils();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_platform.isDesktop) {
      windowManager.addListener(this);
    }
    _applyFocusState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_platform.isAndroid) {
        QuantaKeysSetup.checkKeyboard(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_platform.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _platform.isAndroid) {
      QuantaKeysSetup.checkKeyboard(context);
    }
  }

  @override
  void onWindowClose() async {
    final settings = context.read<SettingsProvider>();
    await settings.setOverlayMode(false);
    await windowManager.destroy();
  }

  void _applyFocusState() {
    final settings = context.read<SettingsProvider>();
    if (_platform.isWindows) {
      _platform.applyWindowSettings(
        nonFocusable: settings.isOverlayMode, 
        alwaysOnTop: settings.alwaysOnTop
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>(); 

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuantaKeys Hub'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // 1. Restore normal window behavior to interact with Settings
              if (_platform.isWindows) {
                _platform.setWindowNonFocusable(false);
              }
              
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );

              // 2. Re-apply the user's preferred mode (Overlay or Full App)
              // this runs when returning from Settings
              _applyFocusState();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Upper section for instructions
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: SwitchListTile(
                    secondary: const Icon(Icons.picture_in_picture, color: Colors.blue),
                    title: const Text('Floating Overlay Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Turn on to use the keyboard overlay.', style: TextStyle(fontSize: 12)),
                    value: settings.isOverlayMode,
                    onChanged: (val) async {
                      settings.setOverlayMode(val);
                      _applyFocusState();
                      if (_platform.isWindows) {
                        if (val) {
                          await windowManager.setSize(const Size(420, 380));
                        } else {
                          await windowManager.setSize(const Size(450, 720));
                          await windowManager.center();
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildInstructionCard(
                  context,
                  'Enable QuantaKeys',
                  'Activate the scientific agent in your system settings to use it in any app.',
                  Icons.settings_suggest,
                ),
                const SizedBox(height: 12),
                _buildInstructionCard(
                  context,
                  'Hybrid Magic Tool',
                  'Tap the Wand icon to solve complex equations OR instantly polish scrambled text.',
                  Icons.auto_fix_high,
                ),
                const SizedBox(height: 12),
                _buildInstructionCard(
                  context,
                  'Professional Science',
                  'Perform calculus, physics variable extraction, and daily greetings with zero latency.',
                  Icons.calculate,
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'LIVE PREVIEW BELOW',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.center,
                  child: const Text(
                    'Developed by Ponmukesh P and Hariharan S\nof Sri Ramana Academy Senior Secondary CBSE, Rajapalayam',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          // Fixed bottom section for keyboard or prompt
          settings.isOverlayMode
              ? const QuantaKeyboardWidget(isOverlay: false)
              : Container(
                  height: 160,
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.keyboard_hide_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Keyboard is currently turned off',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Turn on "Floating Overlay Mode" above to use the keyboard.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(BuildContext context, String title, String desc, IconData icon) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 13)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstructionPage())),
      ),
    );
  }
}

class QuantaKeysSetup {
  static const MethodChannel _channel = MethodChannel('quantakeys/keyboard');

  static Future<void> checkKeyboard(BuildContext context) async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isQuantaKeysEnabled');
      final bool isDefault = await _channel.invokeMethod('isQuantaKeysDefault');

      if (!context.mounted || (isEnabled && isDefault)) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(!isEnabled ? 'Enable QuantaKeys' : 'Set as Default Keyboard'),
            content: Text(
              !isEnabled
                  ? 'Step 1 of 2: Please enable QuantaKeys in your device settings so it becomes available as a keyboard.'
                  : 'Step 2 of 2: QuantaKeys is enabled! Tap below to set it as your default keyboard.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  try {
                    await _channel.invokeMethod('openKeyboardSettings');
                  } on PlatformException catch (e) {
                    debugPrint('Could not open keyboard settings: ${e.message}');
                  }
                },
                child: Text(!isEnabled ? 'Turn on Keyboard' : 'Set as Default'),
              ),
            ],
          );
        },
      );
    } on PlatformException catch (e) {
      debugPrint('Keyboard check failed: ${e.message}');
    }
  }
}
