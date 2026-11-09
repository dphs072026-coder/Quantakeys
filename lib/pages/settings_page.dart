import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../providers/custom_layout_provider.dart';
import '../engine/openai_engine.dart';
import '../models/key_layout.dart';
import 'custom_layouts_page.dart';
import 'history_page.dart';
import 'sign_in_page.dart';
import '../services/cloud_sync_service.dart';
import '../widgets/usage_slider.dart';
import '../utils/platform_utils.dart';
import 'package:window_manager/window_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  bool _obscureApiKey = true;
  bool _isTestingKey = false;
  final CloudSyncService _cloudSync = CloudSyncService();
  bool _isSigningIn = false;
  final _platform = PlatformUtils();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _apiKeyController = TextEditingController(text: settings.openAiApiKey);
    _modelController = TextEditingController(text: settings.openAiModel);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _testOpenAiKey(BuildContext context, SettingsProvider settings) async {
    final key = _apiKeyController.text.trim();
    final model = _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : 'gpt-6-luna';

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an OpenAI API key first.'))
      );
      return;
    }

    setState(() => _isTestingKey = true);
    
    // Save key, model, and switch AI provider mode to userKey immediately!
    await settings.setOpenAiApiKey(key);
    await settings.setOpenAiModel(model);
    await settings.setAiProviderMode('userKey');

    try {
      final res = await OpenAiEngine.polishText(
        text: 'Hello test',
        apiKey: key,
        model: model,
      );
      if (context.mounted) {
        if (res != null && res.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Key saved & Verified! Model "$model" responded successfully. Mode set to Custom API Key.'))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Key saved! API returned empty response. Mode set to Custom API Key.'))
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('💾 Key saved successfully (Mode: Custom Key), but test connection failed: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingKey = false);
    }
  }

  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    final uri = Uri.parse('https://quantakeys.edgeone.dev');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Buy Me A Coffee: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }



  Future<void> _exportLayouts(BuildContext context, CustomLayoutProvider provider) async {
    try {
      final layouts = provider.customLayouts;
      if (layouts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No custom layouts to export.")));
        return;
      }
      final jsonString = json.encode(layouts.map((e) => e.toJson()).toList());
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select where to save your layouts:',
        fileName: 'quantakeys_layouts.json',
      );
      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Layouts exported successfully!")));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    }
  }

  Future<void> _importLayouts(BuildContext context, CustomLayoutProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List<dynamic> decoded = json.decode(content);
        for (var item in decoded) {
          provider.addLayout(KeyLayout.fromJson(item));
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Layouts imported successfully!")));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import failed: $e")));
      }
    }
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (context.mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Update Available"),
              content: Text("A new version (${info.availableVersionCode}) is available. Would you like to update now?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Later")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Update")),
              ],
            ),
          );

          if (proceed == true) {
            await InAppUpdate.performImmediateUpdate();
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You are already using the latest version."))
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update check failed: $e"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final customProvider = context.read<CustomLayoutProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            title: const Text('Theme Mode'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (ThemeMode? newValue) {
                if (newValue != null) settings.setThemeMode(newValue);
              },
              items: ThemeMode.values.map<DropdownMenuItem<ThemeMode>>((ThemeMode mode) {
                return DropdownMenuItem<ThemeMode>(
                  value: mode,
                  child: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Keyboard Height', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text('${(settings.keyboardHeightFactor * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Slider(
                  value: settings.keyboardHeightFactor.clamp(0.8, 1.4),
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: '${(settings.keyboardHeightFactor * 100).round()}%',
                  onChanged: (val) => settings.setKeyboardHeightFactor(val, notifyIme: false),
                  onChangeEnd: (val) => settings.setKeyboardHeightFactor(val, notifyIme: true),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Key Shape'),
            subtitle: const Text('Choose key corner style'),
            trailing: DropdownButton<String>(
              value: settings.keyShape,
              onChanged: (String? val) {
                if (val != null) settings.setKeyShape(val);
              },
              items: const [
                DropdownMenuItem(value: 'rounded', child: Text('Rounded')),
                DropdownMenuItem(value: 'square', child: Text('Square')),
                DropdownMenuItem(value: 'pill', child: Text('Pill')),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Emoji Panel'),
            subtitle: const Text('Adds an Emoji tab (😊) to the keyboard tab bar'),
            value: settings.emojiEnabled,
            onChanged: (val) => settings.setEmojiEnabled(val),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Theme Editor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          _buildColorPreset(context, settings, 'Keyboard Color', [
            const Color(0xFF1E1E1E), // Midnight
            const Color(0xFF2C2C2C), // Slate
            const Color(0xFF102A43), // Navy
            const Color(0xFF243B53), // Blue Grey
          ], (c) => settings.setKeyboardColor(c), settings.keyboardColor),
          _buildColorPreset(context, settings, 'Accent Color', [
            Colors.blue,
            Colors.purple,
            Colors.teal,
            Colors.orange,
            Colors.redAccent,
          ], (c) => settings.setAccentColor(c), settings.accentColor),
          const Divider(),
          _buildOverlayControlsCard(context, settings),
          const Divider(),
          _buildAiSection(context, settings),
          const Divider(),
          SwitchListTile(
            title: const Text('Smart Paste (Append)'),
            subtitle: const Text('If ON, inserts "Question = Answer". Long-press a chip to use once.'),
            value: settings.appendAnswer,
            onChanged: (val) => settings.setAppendAnswer(val),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Calculations', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          SwitchListTile(
            title: const Text('Use Degrees for Trigonometry'),
            subtitle: const Text('If off, Radians will be used'),
            value: settings.useDegrees,
            onChanged: (val) => settings.setUseDegrees(val),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Customization', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            title: const Text('Custom Layouts'),
            subtitle: const Text('Manage and create your scientific keypads'),
            leading: const Icon(Icons.dashboard_customize),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomLayoutsPage())),
          ),
          ListTile(
            title: const Text('Calculation History'),
            subtitle: const Text('View daily calculations'),
            leading: const Icon(Icons.history),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Feedback & Haptics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            title: const Text('Input Latency (ms)'),
            subtitle: Slider(
              value: settings.latency,
              min: 0,
              max: 500,
              divisions: 10,
              label: '${settings.latency.toInt()} ms',
              onChanged: (val) => settings.setLatency(val, notifyIme: false),
              onChangeEnd: (val) => settings.setLatency(val, notifyIme: true),
            ),
            trailing: Text('${settings.latency.toInt()} ms'),
          ),
          SwitchListTile(
            title: const Text('Vibration Feedback'),
            value: settings.vibrationEnabled,
            onChanged: (val) => settings.setVibrationEnabled(val),
          ),
          if (settings.vibrationEnabled) ...[
            ListTile(
              title: const Text('Haptic Intensity'),
              subtitle: Slider(
                value: settings.hapticIntensity,
                onChanged: (val) => settings.setHapticIntensity(val, notifyIme: false),
                onChangeEnd: (val) => settings.setHapticIntensity(val, notifyIme: true),
              ),
            ),
            ListTile(
              title: const Text('Haptic Type'),
              trailing: DropdownButton<String>(
                value: settings.hapticType,
                onChanged: (String? newValue) {
                  if (newValue != null) settings.setHapticType(newValue);
                },
                items: ['light', 'medium', 'heavy'].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value[0].toUpperCase() + value.substring(1)),
                  );
                }).toList(),
              ),
            ),
          ],
          const Divider(),
          ListTile(
            title: const Text('Export Layouts'),
            leading: const Icon(Icons.upload),
            onTap: () => _exportLayouts(context, customProvider),
          ),
          ListTile(
            title: const Text('Import Layouts'),
            leading: const Icon(Icons.download),
            onTap: () => _importLayouts(context, customProvider),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Cloud Sync & Google Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            title: Text(_cloudSync.isSignedIn ? 'Signed in as ${_cloudSync.currentUser?.email ?? "User"}' : 'Cloud Account & Sync'),
            subtitle: Text(_cloudSync.isSignedIn ? 'Custom layouts sync automatically across your devices.' : 'Sync your custom keyboard layouts across devices.'),
            leading: Icon(_cloudSync.isSignedIn ? Icons.account_circle : Icons.login, color: _cloudSync.isSignedIn ? Colors.green : Colors.blue),
            trailing: _isSigningIn 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : _cloudSync.isSignedIn
                    ? ElevatedButton(
                        onPressed: () async {
                          setState(() => _isSigningIn = true);
                          await _cloudSync.signOut();
                          await settings.loadSettings();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
                          }
                          setState(() => _isSigningIn = false);
                        },
                        child: const Text('Sign Out'),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignInPage()),
                          );
                          await settings.loadSettings();
                          setState(() {});
                        },
                        child: const Text('Sign In / Up'),
                      ),
            onTap: _cloudSync.isSignedIn ? null : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignInPage()),
              );
              await settings.loadSettings();
              setState(() {});
            },
          ),
          if (_cloudSync.isSignedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Layouts Now (Cross-Device)'),
                  onPressed: () async {
                    await customProvider.syncWithCloud();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔄 Custom layouts synchronized successfully!')));
                    }
                  },
                ),
              ),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Software', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            title: const Text('Check for Updates'),
            subtitle: const Text('Verify and install the latest version'),
            leading: const Icon(Icons.system_update),
            onTap: () => _checkForUpdates(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAiSection(BuildContext context, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('AI Engine & OpenAI Integration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        RadioGroup<String>(
          groupValue: settings.aiProviderMode,
          onChanged: (val) {
            if (val != null) settings.setAiProviderMode(val);
          },
          child: Column(
            children: const [
              RadioListTile<String>(
                title: Text('Local Interpreter (Offline & Free)'),
                subtitle: Text('Fast, built-in rule-based solver & polisher. 100% free & offline.'),
                value: 'local',
              ),
              RadioListTile<String>(
                title: Text('User Groq / OpenAI API Key (Custom Key)'),
                subtitle: Text('Use your own Groq (gsk_...) or OpenAI (sk-...) API key for unlimited ultra-fast AI solving & text polishing.'),
                value: 'userKey',
              ),
              RadioListTile<String>(
                title: Text('App Default Cloud AI (12 Free Daily Calls)'),
                subtitle: Text('Includes 12 free daily cloud AI calls per day powered by Groq Llama/Qwen.'),
                value: 'appTier',
              ),
            ],
          ),
        ),

        // Expanded UI for User Key Mode
        if (settings.aiProviderMode == 'userKey')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.key, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('OpenAI API Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'OpenAI API Key (sk-...)',
                        hintText: 'sk-proj-...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                      ),
                      onChanged: (val) => settings.setOpenAiApiKey(val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'OpenAI Model ID',
                        hintText: 'e.g. gpt-4o-mini, gpt-4o, o1-mini, or fine-tuned model',
                        border: OutlineInputBorder(),
                        helperText: 'Type any model supported by your key or tap a quick chip below.',
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty) {
                          settings.setOpenAiModel(val.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ['gpt-6-luna', 'gpt-4o-mini', 'gpt-4o', 'gpt-3.5-turbo', 'o1-mini'].map((m) {
                        final isSelected = _modelController.text.trim() == m;
                        return ChoiceChip(
                          label: Text(m, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _modelController.text = m;
                              settings.setOpenAiModel(m);
                              setState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isTestingKey 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.verified),
                        label: Text(_isTestingKey ? 'Verifying Key...' : 'Save & Test API Key'),
                        onPressed: _isTestingKey ? null : () => _testOpenAiKey(context, settings),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Expanded UI for App Tier Mode (Separated Daily AI Usage & Support QuantaKeys)
        if (settings.aiProviderMode == 'appTier') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.analytics_outlined, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Daily AI Usage Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const UsageSlider(),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.coffee, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Support QuantaKeys', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.coffee, color: Colors.amber),
                        label: const Text('Buy Me A Coffee ☕'),
                        onPressed: () => _launchBuyMeACoffee(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverlayControlsCard(BuildContext context, SettingsProvider settings) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_in_picture, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Overlay Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: settings.isOverlayMode ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: settings.isOverlayMode ? Colors.green : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        settings.isOverlayMode ? 'Overlay Active' : 'App Mode',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: settings.isOverlayMode ? Colors.green : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Floating Overlay Mode'),
              subtitle: const Text('Keeps keyboard floating above other apps on Windows.'),
              value: settings.isOverlayMode,
              onChanged: (val) {
                settings.setOverlayMode(val);
                if (_platform.isWindows) {
                  _platform.applyWindowSettings(nonFocusable: val, alwaysOnTop: settings.alwaysOnTop);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Always on Top'),
              subtitle: const Text('Pin overlay on top of all desktop windows.'),
              value: settings.alwaysOnTop,
              onChanged: (val) {
                settings.setAlwaysOnTop(val);
                if (_platform.isWindows) {
                  _platform.applyWindowSettings(nonFocusable: settings.isOverlayMode, alwaysOnTop: val);
                }
              },
            ),
            if (_platform.isDesktop) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Show Overlay'),
                    onPressed: () async {
                      if (!settings.isOverlayMode) {
                        settings.setOverlayMode(true);
                      }
                      if (_platform.isWindows) {
                        _platform.applyWindowSettings(nonFocusable: true, alwaysOnTop: settings.alwaysOnTop);
                      }
                      await windowManager.show();
                      await windowManager.restore();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('Minimize'),
                    onPressed: () async {
                      await windowManager.minimize();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close Overlay'),
                    onPressed: () async {
                      await windowManager.hide();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorPreset(BuildContext context, SettingsProvider settings, String title, List<Color> colors, Function(Color) onSelect, Color current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final c = colors[index];
              final isSelected = c.toARGB32() == current.toARGB32();
              return GestureDetector(
                onTap: () => onSelect(c),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                    boxShadow: [if (isSelected) const BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
