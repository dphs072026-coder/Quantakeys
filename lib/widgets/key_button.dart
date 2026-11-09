import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:quantakeys/models/key_item.dart';
import 'package:quantakeys/providers/settings_provider.dart';
import 'package:quantakeys/providers/keyboard_provider.dart';

class KeyButton extends StatefulWidget {
  final KeyItem item;
  final VoidCallback? onPressed;

  const KeyButton({super.key, required this.item, this.onPressed});

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  Timer? _holdTimer;
  Timer? _backspaceTimer;
  double _dragOffset = 0.0;
  static const double _dragThreshold = 8.0;
  bool _isPressed = false;

  bool _didLongPress = false;

  BorderRadius _getBorderRadius(String shape) {
    switch (shape) {
      case 'square':
        return BorderRadius.circular(3);
      case 'pill':
        return BorderRadius.circular(22);
      case 'rounded':
      default:
        return BorderRadius.circular(10);
    }
  }

  void _handlePressStart() async {
    if (_isPressed) return;
    _dragOffset = 0.0; // Reset space bar slide tracking
    _didLongPress = false;
    
    setState(() => _isPressed = true);

    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      Vibration.hasVibrator().then((has) {
        if (has == true) {
          Vibration.vibrate(duration: 40); // Standard crisp 40ms haptic
        }
      });
    }

    final keyboard = context.read<KeyboardProvider>();
    if (widget.item.value == 'BACKSPACE') {
      // 1. Delete one character immediately on single tap/press
      keyboard.backspace();
      
      // 2. Start hold timer to trigger continuous rapid deletion if held down > 350ms
      _holdTimer = Timer(const Duration(milliseconds: 350), () {
        _startContinuousBackspace();
      });
    } else if (widget.item.value == ' ') {
      _holdTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isPressed) {
          _didLongPress = true;
          if (settings.vibrationEnabled) {
            Vibration.vibrate(duration: 80);
          }
          keyboard.showKeyboardPicker();
        }
      });
    }
  }

  void _handlePressEnd() {
    if (!_isPressed) return;
    
    setState(() => _isPressed = false);
    _holdTimer?.cancel();
    _backspaceTimer?.cancel();

    final keyboard = context.read<KeyboardProvider>();
    if (widget.item.value == 'BACKSPACE') {
      // already handled on down
    } else if (widget.item.value == ' ') {
      if (_didLongPress) return;
      if (widget.onPressed != null) {
        widget.onPressed!();
      } else {
        _handleDefaultAction(keyboard, context);
      }
    } else {
      if (widget.onPressed != null) {
        widget.onPressed!();
      } else {
        _handleDefaultAction(keyboard, context);
      }
    }
  }

  void _startContinuousBackspace() {
    final keyboard = context.read<KeyboardProvider>();
    _backspaceTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      keyboard.backspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = context.watch<KeyboardProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSpace = widget.item.value == ' ';

    if (widget.item.label.isEmpty && widget.item.value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.5),
      child: Listener(
        onPointerDown: (_) => _handlePressStart(),
        onPointerUp: (_) => _handlePressEnd(),
        onPointerCancel: (_) => _handlePressEnd(),
        onPointerMove: isSpace ? (details) {
          _dragOffset += details.delta.dx;
          if (_dragOffset.abs() > _dragThreshold) {
            final direction = _dragOffset > 0 ? 1 : -1;
            keyboard.moveCursor(direction);
            _dragOffset = 0.0;
          }
        } : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isPressed 
                  ? (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.12))
                  : _getColor(context, keyboard, settings),
              borderRadius: _getBorderRadius(settings.keyShape),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                width: _isPressed ? 1.0 : 0.5,
              ),
              boxShadow: [
                if (!_isPressed)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                    offset: const Offset(0, 2),
                    blurRadius: 2,
                  )
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: _buildKeyLabel(isDark, keyboard, settings),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const Map<String, String> _numberToShiftSymbolMap = {
    '1': '!',
    '2': '@',
    '3': '#',
    '4': '\$',
    '5': '%',
    '6': '^',
    '7': '&',
    '8': '*',
    '9': '(',
    '0': ')',
  };

  Widget _buildKeyLabel(bool isDark, KeyboardProvider keyboard, SettingsProvider settings) {
    String label = widget.item.label;
    
    // Check if Connect Mode is active for scientific layouts
    final isScientificTab = ['MATH', 'CHEM', 'PHYS'].contains(keyboard.activeTab);
    final showConnectShortcut = keyboard.isConnectModeEnabled && isScientificTab && widget.item.shortcut != null;

    // Convert top-row numbers or auto-capitalize letters if Shift/CapsLock is active
    if (keyboard.isShiftEnabled) {
      if (_numberToShiftSymbolMap.containsKey(label)) {
        label = _numberToShiftSymbolMap[label]!;
      } else if (widget.item.type == KeyType.character && label.length == 1) {
        label = label.toUpperCase();
      }
    }

    // Visual hint for Caps Lock
    if (widget.item.value == 'SHIFT' && keyboard.shiftState == ShiftState.capsLock) {
      return const Icon(Icons.keyboard_capslock, color: Colors.white, size: 24);
    }

    if (showConnectShortcut) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
            ),
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.item.shortcut!,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade800,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final fontSize = (16.0 * settings.keyboardHeightFactor).clamp(12.0, 22.0);
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
        color: isDark ? Colors.white : Colors.black87,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _getColor(BuildContext context, KeyboardProvider keyboard, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 1. Highlight Hot Keys based on context
    if (keyboard.hotKeys.contains(widget.item.label) || keyboard.hotKeys.contains(widget.item.value)) {
       return settings.accentColor.withValues(alpha: 0.15);
    }

    // 2. Highlight SHIFT key based on state
    if (widget.item.value == 'SHIFT') {
       if (keyboard.shiftState == ShiftState.capsLock) {
         return settings.accentColor;
       } else if (keyboard.shiftState == ShiftState.shift) {
         return settings.accentColor.withValues(alpha: 0.5);
       }
    }

    switch (widget.item.type) {
      case KeyType.action:
      case KeyType.layoutSwitch:
        return isDark 
            ? settings.keyboardColor.withValues(alpha: 0.6) 
            : const Color(0xFFD8DBDE); // Slightly deeper for action keys
      default:
        return isDark 
            ? settings.keyboardColor.withValues(alpha: 0.95) 
            : Colors.white;
    }
  }

  void _handleDefaultAction(KeyboardProvider keyboard, BuildContext context) {
    switch (widget.item.type) {
      case KeyType.character:
        String valToInsert = widget.item.value;
        if (keyboard.isShiftEnabled) {
          if (_numberToShiftSymbolMap.containsKey(valToInsert)) {
            valToInsert = _numberToShiftSymbolMap[valToInsert]!;
          } else if (valToInsert.length == 1) {
            valToInsert = valToInsert.toUpperCase();
          }
        }
        keyboard.appendText(valToInsert);
        break;
      case KeyType.action:
        if (widget.item.value == 'BACKSPACE') {
          keyboard.backspace();
        } else if (widget.item.value == 'SHIFT') {
          keyboard.toggleShift();
        } else if (widget.item.value == '\n') {
           keyboard.sendAction();
        }
        break;
      case KeyType.layoutSwitch:
        keyboard.setActiveTab(widget.item.value);
        break;
      default:
        break;
    }
  }
}
