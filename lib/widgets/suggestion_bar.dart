import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/keyboard_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/platform_utils.dart';

class SuggestionBar extends StatelessWidget {
  final bool isOverlay;
  const SuggestionBar({super.key, this.isOverlay = false});

  @override
  Widget build(BuildContext context) {
    final keyboard = context.watch<KeyboardProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platform = PlatformUtils();
    final double suggestionH = platform.isDesktop ? 36.0 : 48.0;
    final constraints = LayoutBuilder;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject() as RenderBox?;

      if (box != null && box.hasSize) {
        debugPrint(
            'SUGGESTION BAR SIZE: ${box.size}'
        );

        debugPrint(
            'SUGGESTION BAR POSITION: ${box.localToGlobal(Offset.zero)}'
        );
      }
    });

    return GestureDetector(
      onPanStart: platform.isDesktop ? (_) => windowManager.startDragging() : null,
      child: Container(
        height: suggestionH,
        decoration: BoxDecoration(
          color: isDark 
              ? settings.keyboardColor 
              : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
            bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
            child: Stack(
              children: [
                // Clipboard & Pencil Group - Left Corner
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InstrumentButton(
                        icon: Icons.content_paste_outlined,
                        onPressed: () => keyboard.pasteFromClipboard(),
                        isDark: isDark,
                      ),
                      _InstrumentButton(
                        icon: Icons.auto_fix_high_outlined,
                        onPressed: () => keyboard.runMagicTool(),
                        isDark: isDark,
                        glow: keyboard.isThinking,
                      ),
                    ],
                  ),
                ),

                // Settings & Connect Group - Right Corner
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!platform.isAndroid)
                        _InstrumentButton(
                          icon: Icons.cable_outlined,
                          onPressed: () {
                            keyboard.toggleConnectMode();
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            if (messenger != null) {
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 2),
                                  content: Text(
                                    keyboard.isConnectModeEnabled 
                                        ? "Connect Mode ON (PHY, CHE, MAT keyboard shortcuts connected)"
                                        : "Connect Mode OFF",
                                  ),
                                ),
                              );
                            }
                          },
                          isDark: isDark,
                          glow: keyboard.isConnectModeEnabled,
                        ),
                      _InstrumentButton(
                        icon: Icons.tune_outlined,
                        onPressed: () => keyboard.openSettings(),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                
                // Main Content Area
                Padding(
                  padding: EdgeInsets.only(
                    left: 88.0,
                    right: platform.isAndroid ? 38.0 : 88.0,
                  ),
                  child: Row(
                    children: [
                      if (isOverlay)
                        _AgenticStatusIndicator(
                          connected: keyboard.isImeConnected, 
                          isThinking: keyboard.isThinking,
                          color: settings.accentColor
                        ),
                      
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                          child: keyboard.suggestion.isNotEmpty
                              ? _buildScientificSuggestion(context, keyboard, settings)
                              : _buildWordSuggestions(context, keyboard, settings),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildScientificSuggestion(BuildContext context, KeyboardProvider keyboard, SettingsProvider settings) {
    final platform = PlatformUtils();
    final double suggestionH = platform.isDesktop ? 36.0 : 48.0;

    return SizedBox(
      height: suggestionH,
      child: ListView(
        key: const ValueKey("sci"),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 4),
            child: GestureDetector(
              onTap: () => keyboard.commitSuggestion(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [settings.accentColor, settings.accentColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: settings.accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.appendAnswer)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.add_circle_outline, size: 14, color: Colors.white),
                        ),
                      Text(
                        keyboard.suggestion,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSuggestions(BuildContext context, KeyboardProvider keyboard, SettingsProvider settings) {
    final list = keyboard.wordSuggestions.isNotEmpty 
        ? keyboard.wordSuggestions 
        : const ['Hi', 'Hello', 'How', 'Thanks', 'Thankyou', 'Welcome'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platform = PlatformUtils();
    final double suggestionH = platform.isDesktop ? 36.0 : 48.0;

    return SizedBox(
      height: suggestionH,
      child: ListView.builder(
        key: const ValueKey("words"),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final word = list[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
            child: InkWell(
              onTap: () => keyboard.acceptWordSuggestion(word),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Center(
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
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

class _InstrumentButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;
  final bool glow;

  const _InstrumentButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white70 : Colors.black54;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(
          icon, 
          size: 18, 
          color: glow ? Colors.blueAccent : color,
        ),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _AgenticStatusIndicator extends StatefulWidget {
  final bool connected;
  final bool isThinking;
  final Color color;
  const _AgenticStatusIndicator({
    required this.connected, 
    required this.isThinking,
    required this.color
  });

  @override
  State<_AgenticStatusIndicator> createState() => _AgenticStatusIndicatorState();
}

class _AgenticStatusIndicatorState extends State<_AgenticStatusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.connected ? (widget.isThinking ? Colors.blueAccent : Colors.greenAccent) : Colors.redAccent,
            boxShadow: [
              if (widget.connected)
                BoxShadow(
                  color: (widget.isThinking ? Colors.blue : Colors.green).withValues(alpha: 0.5 * _controller.value),
                  blurRadius: 4 + (4 * _controller.value),
                  spreadRadius: 1 * _controller.value,
                )
            ],
          ),
        );
      },
    );
  }
}
