import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quantakeys/providers/keyboard_provider.dart';
import 'package:quantakeys/providers/settings_provider.dart';
import 'package:quantakeys/providers/custom_layout_provider.dart';
import 'package:quantakeys/providers/calculation_history_provider.dart';
import 'package:quantakeys/pages/home_page.dart';
import 'package:quantakeys/pages/settings_page.dart';
import 'package:quantakeys/widgets/suggestion_bar.dart';
import 'package:quantakeys/widgets/keyboard_grid.dart';
import 'package:quantakeys/widgets/overlay_title_bar.dart';
import 'package:quantakeys/layouts/default_layouts.dart';
import 'package:quantakeys/models/key_layout.dart';
import 'package:quantakeys/models/key_item.dart';
import 'package:quantakeys/utils/platform_utils.dart';
import 'package:quantakeys/utils/desktop_utils.dart';

import 'package:quantakeys/config/supabase_config.dart';
import 'package:app_links/app_links.dart';

final platform = PlatformUtils();
final desktop = DesktopUtils();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final sessionJson = prefs.getString('supabase_session_json');
      if (sessionJson != null && sessionJson.isNotEmpty && Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth.recoverSession(sessionJson);
      }
    } catch (e) {
      debugPrint("Session recovery error: $e");
    }
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  final historyProvider = CalculationHistoryProvider();
  final settingsProvider = SettingsProvider();
  final customLayoutProvider = CustomLayoutProvider();

  // Await settings so app starts with exact saved preferences on first frame
  await settingsProvider.loadSettings();
  await customLayoutProvider.refresh();
  
  final keyboardProvider = KeyboardProvider()
    ..setHistoryProvider(historyProvider)
    ..setSettingsProvider(settingsProvider)
    ..setIsExternalInputEnabled(false);

  // Run app UI immediately so splash screen logo disappears instantly!
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: historyProvider),
        ChangeNotifierProvider.value(value: keyboardProvider),
        ChangeNotifierProvider.value(value: customLayoutProvider),
      ],
      child: const QuantaKeysApp(isOverlay: false),
    ),
  );

  // Asynchronous background services (non-blocking)
  _initAppBackgroundServices(settingsProvider, customLayoutProvider);
}

void _initAppBackgroundServices(SettingsProvider settingsProvider, CustomLayoutProvider customLayoutProvider) async {
  try {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) async {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint("Deep link stream error: $e");
      }
    });

    final initialUri = await appLinks.getInitialLink().timeout(const Duration(seconds: 2));
    if (initialUri != null) {
      await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
    }
  } catch (e) {
    debugPrint("AppLinks init error: $e");
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    if (session != null) {
      await settingsProvider.loadSettings();
      await customLayoutProvider.syncWithCloud();
    }
  });

  if (platform.isDesktop) {
    try {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(450, 720),
        minimumSize: Size(360, 480),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'QuantaKeys Hub',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setAlwaysOnTop(settingsProvider.alwaysOnTop);
        await windowManager.show();
        await windowManager.focus();
      });
      
      if (platform.isWindows) {
        for (int delay in [100, 300, 700, 1500, 3000]) {
          Future.delayed(Duration(milliseconds: delay), () {
            windowManager.setAlwaysOnTop(settingsProvider.alwaysOnTop);
            platform.applyWindowSettings(
              nonFocusable: false, 
              alwaysOnTop: settingsProvider.alwaysOnTop
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Desktop window init error: $e");
    }
  }
}

@pragma('vm:entry-point')
void keyboardMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final sessionJson = prefs.getString('supabase_session_json');
      if (sessionJson != null && sessionJson.isNotEmpty && Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth.recoverSession(sessionJson);
      }
    } catch (e) {
      debugPrint("Session recovery error in keyboardMain: $e");
    }
  } catch (e) {
    debugPrint("Supabase init error in keyboardMain: $e");
  }
  
  final settingsProvider = SettingsProvider();
  final historyProvider = CalculationHistoryProvider();
  final customLayoutProvider = CustomLayoutProvider();

  await settingsProvider.loadSettings();
  await customLayoutProvider.refresh();

  final keyboardProvider = KeyboardProvider()
    ..setSettingsProvider(settingsProvider)
    ..setHistoryProvider(historyProvider)
    ..setCustomLayoutProvider(customLayoutProvider)
    ..setIsExternalInputEnabled(true);
    
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: historyProvider),
        ChangeNotifierProvider.value(value: keyboardProvider),
        ChangeNotifierProvider.value(value: customLayoutProvider),
      ],
      child: const QuantaKeysApp(isOverlay: true),
    ),
  );

  // Background async refresh
  customLayoutProvider.refresh();
}

class QuantaKeysApp extends StatelessWidget {
  final bool isOverlay;
  const QuantaKeysApp({super.key, required this.isOverlay});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    return MaterialApp(
      title: 'QuantaKeys',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: settings.accentColor),
        useMaterial3: true,
        fontFamily: 'monospace',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.accentColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1C1E),
        ),
        useMaterial3: true,
        fontFamily: 'monospace',
      ),
      themeMode: settings.themeMode,
      initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName.isNotEmpty 
          ? WidgetsBinding.instance.platformDispatcher.defaultRouteName 
          : '/',
      routes: {
        '/': (context) => isOverlay 
          ? Builder(
              builder: (context) {
                return MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  removeLeft: true,
                  removeRight: true,
                  child: const Material(
                    color: Colors.transparent,
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      resizeToAvoidBottomInset: false,
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: QuantaKeyboardWidget(isOverlay: true),
                      ),
                    ),
                  ),
                );
              },
            )
          : const HomePage(),
        '/keyboard': (context) => MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: const Material(
                color: Colors.transparent,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  resizeToAvoidBottomInset: false,
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: QuantaKeyboardWidget(isOverlay: true),
                  ),
                ),
              ),
            ),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

class QuantaKeyboardWidget extends StatefulWidget {
  final bool isOverlay;
  const QuantaKeyboardWidget({super.key, this.isOverlay = false});

  @override
  State<QuantaKeyboardWidget> createState() => _QuantaKeyboardWidgetState();
}

class _QuantaKeyboardWidgetState extends State<QuantaKeyboardWidget> {
  final FocusNode _focusNode = FocusNode();
  double? _lastSentDp;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _calculateTotalDp(BuildContext context, KeyboardProvider keyboard, SettingsProvider settings) {
    final view = View.of(context);
    final isLandscape = view.display.size.width > view.display.size.height;
    
    final double suggestionH = 48.0;
    final double tabBarH = isLandscape ? 36.0 : 42.0;
    final double stripsDp = suggestionH + tabBarH;
    
    final double baseGridDp = isLandscape ? 160.0 : 320.0;
    final double gridDp = baseGridDp * settings.keyboardHeightFactor.clamp(0.8, 1.4);
    
    final double chinDp = keyboard.isGestureNavigation 
        ? (isLandscape ? 10.0 : 14.0)
        : (isLandscape ? 14.0 : 22.0);
         
    final titleBarH = platform.isDesktop ? 32.0 : 0.0;
    
    return stripsDp + gridDp + chinDp + titleBarH;
  }

  void _sendHeightToNative(double totalDp, {bool force = false}) {
    if (platform.isMobile && (force || _lastSentDp == null || (_lastSentDp! - totalDp).abs() > 0.1)) {
      _lastSentDp = totalDp;
      try {
        debugPrint("QuantaKeyboard: calling setKeyboardHeight with totalDp=$totalDp");
        const MethodChannel('com.quantakeys/ime').invokeMethod('setKeyboardHeight', {'heightDp': totalDp});
      } catch (e) {
        debugPrint("QuantaKeyboard: setKeyboardHeight error: $e");
      }
    }
  }

  String? _getCharFromLogicalKey(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.length == 1) return label;
    if (key == LogicalKeyboardKey.space) return ' ';
    if (key == LogicalKeyboardKey.period || key == LogicalKeyboardKey.numpadDecimal) return '.';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.numpadDivide) return '/';
    if (key == LogicalKeyboardKey.semicolon) return ';';
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) return '=';
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) return '-';
    
    final debugName = key.debugName;
    if (debugName != null && debugName.startsWith('Key ')) {
      return debugName.substring(4).toLowerCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = context.watch<KeyboardProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? Color.lerp(settings.keyboardColor, Colors.black, 0.3)
        : const Color(0xFFE8EBEE);

    final view = View.of(context);
    final isLandscape = view.display.size.width > view.display.size.height;
    final double chinHeight = keyboard.isGestureNavigation 
        ? (isLandscape ? 10.0 : 14.0) 
        : (isLandscape ? 14.0 : 22.0);

    final double suggestionH = 48.0;
    final double tabBarH = isLandscape ? 36.0 : 42.0;

    final double totalDp = _calculateTotalDp(context, keyboard, settings);
    _sendHeightToNative(totalDp, force: true);

    final Widget keyboardContent = Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          String? char = event.character;
          if (char == null || char.isEmpty) {
            char = _getCharFromLogicalKey(event.logicalKey);
          }
          if (char != null && char.isNotEmpty) {
            keyboard.appendText(char);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            keyboard.backspace();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            keyboard.sendAction();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: widget.isOverlay
          ? Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: suggestionH,
                    child: ColoredBox(
                      color: Colors.red,
                      child: SuggestionBar(isOverlay: widget.isOverlay),
                    ),
                  ),
                  SizedBox(height: tabBarH, child: _KeyboardTabBar(keyboard: keyboard)),
                  Expanded(
                    child: RepaintBoundary(child: _ActiveLayoutView(keyboard: keyboard)),
                  ),
                  SizedBox(height: chinHeight),
                ],
              ),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              height: totalDp,
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (platform.isDesktop) const OverlayTitleBar(),
                  SizedBox(height: suggestionH, child: SuggestionBar(isOverlay: widget.isOverlay)),
                  SizedBox(height: tabBarH, child: _KeyboardTabBar(keyboard: keyboard)),
                  Expanded(
                    child: RepaintBoundary(child: _ActiveLayoutView(keyboard: keyboard)),
                  ),
                  SizedBox(height: chinHeight),
                  if (platform.isDesktop)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (details) async {
                          final currentSize = await windowManager.getSize();
                          final newWidth = (currentSize.width + details.delta.dx).clamp(320.0, 1200.0);
                          final newHeight = (currentSize.height + details.delta.dy).clamp(280.0, 900.0);
                          await windowManager.setSize(Size(newWidth, newHeight));
                        },
                        child: Container(
                          width: 18,
                          height: 18,
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.south_east,
                            size: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );

    if (widget.isOverlay) {
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: keyboardContent,
      );
    }

    return keyboardContent;
  }
}

class _KeyboardTabBar extends StatelessWidget {
  final KeyboardProvider keyboard;
  const _KeyboardTabBar({required this.keyboard});

  @override
  Widget build(BuildContext context) {
    final customLayouts = context.watch<CustomLayoutProvider>().customLayouts;
    final settings = context.watch<SettingsProvider>();
    final systemTabs = ['ABC', 'SYMB', 'MATH', 'CHEM', 'PHYS', 'TRIG', 'NUM', if (settings.emojiEnabled) '😊'];
    final allTabs = [...systemTabs, ...customLayouts.map((l) => l.name)];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: double.infinity,
      margin: EdgeInsets.zero,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: allTabs.length,
        itemBuilder: (context, index) {
          final tab = allTabs[index];
          final isActive = keyboard.activeTab == tab;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: GestureDetector(
              onTap: () => keyboard.setActiveTab(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive 
                      ? settings.accentColor.withValues(alpha: 0.2) 
                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(14), // More rounded "pill" look
                  border: Border.all(
                    color: isActive 
                        ? settings.accentColor.withValues(alpha: 0.6) 
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    width: isActive ? 1.5 : 0.8,
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? settings.accentColor : (isDark ? Colors.white54 : Colors.black54),
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActiveLayoutView extends StatelessWidget {
  final KeyboardProvider keyboard;
  const _ActiveLayoutView({required this.keyboard});

  @override
  Widget build(BuildContext context) {
    final customLayouts = context.watch<CustomLayoutProvider>().customLayouts;
    KeyLayout? activeLayout;

    if (keyboard.activeTab == '😊') {
      final emojiList = ['😀', '😂', '🥳', '😎', '❤️', '👍', '🔥', '✨', '🚀', '💡', '💻', '📐', '🔬', '⚡', '🌟', '🎯', '🎉', '💯', '🧠', '🔍', '📈'];
      List<List<KeyItem>> rows = [];
      for (int i = 0; i < emojiList.length; i += 8) {
        final end = (i + 8 < emojiList.length) ? i + 8 : emojiList.length;
        rows.add(emojiList.sublist(i, end).map((e) => KeyItem(label: e, value: e)).toList());
      }
      rows.add([
        KeyItem(label: 'ABC', value: 'ABC', type: KeyType.layoutSwitch, flex: 2),
        KeyItem(label: 'space', value: ' ', flex: 6),
        KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 2),
        KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 2),
      ]);
      activeLayout = KeyLayout(name: '😊', rows: rows);
    } else {
      for (var l in customLayouts) {
        if (l.name == keyboard.activeTab) {
          activeLayout = l;
          break;
        }
      }

      activeLayout ??= switch (keyboard.activeTab) {
        'MATH' => DefaultLayouts.math,
        'CHEM' => DefaultLayouts.chem,
        'PHYS' => DefaultLayouts.phys,
        'TRIG' => DefaultLayouts.trig,
        'NUM' => DefaultLayouts.custom,
        'SYMB' => DefaultLayouts.symbols,
        _ => DefaultLayouts.abc,
      };
    }

    return KeyboardGrid(
      key: ValueKey(keyboard.activeTab),
      layout: activeLayout,
    );
  }
}
