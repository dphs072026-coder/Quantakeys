import 'dart:io';
import 'dart:ffi';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'input_injector.dart';

class IOInputInjector implements InputInjector {
  @override
  Future<void> injectText(String text) async {
    if (Platform.isWindows) {
      // Small pause to ensure the target app has processing cycles
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Use Clipboard + Paste (Ctrl+V) for robust 100% reliable Unicode / AI text injection (supports all emojis, math symbols, Greek letters, etc.)
      await Clipboard.setData(ClipboardData(text: text));
      _injectVk(VK_CONTROL, isDown: true);
      _injectVk(0x56, isDown: true); // 'V'
      _injectVk(0x56, isDown: false);
      _injectVk(VK_CONTROL, isDown: false);
    }
  }

  @override
  void injectArrow(int direction) {
    if (Platform.isWindows) {
      final vkCode = direction > 0 ? VK_RIGHT : VK_LEFT;
      _injectVk(vkCode, isDown: true);
      _injectVk(vkCode, isDown: false);
    }
  }

  @override
  void injectEnter() {
    if (Platform.isWindows) {
      _injectVk(VK_RETURN, isDown: true);
      _injectVk(VK_RETURN, isDown: false);
    }
  }

  @override
  void injectBackspace() {
    if (Platform.isWindows) {
      _injectVk(VK_BACK, isDown: true);
      _injectVk(VK_BACK, isDown: false);
    }
  }

  @override
  void injectCopy() {
    if (Platform.isWindows) {
      _injectVk(VK_CONTROL, isDown: true);
      _injectVk(0x43, isDown: true); // 'C'
      _injectVk(0x43, isDown: false);
      _injectVk(VK_CONTROL, isDown: false);
    }
  }

  @override
  void injectPaste() {
    if (Platform.isWindows) {
      _injectVk(VK_CONTROL, isDown: true);
      _injectVk(0x56, isDown: true); // 'V'
      _injectVk(0x56, isDown: false);
      _injectVk(VK_CONTROL, isDown: false);
    }
  }

  void _injectVk(int vkCode, {required bool isDown}) {
    final input = calloc<INPUT>(1);
    
    input[0].type = INPUT_KEYBOARD;
    input[0].ki.wVk = vkCode;
    input[0].ki.dwFlags = isDown ? 0 : KEYEVENTF_KEYUP;

    SendInput(1, input, sizeOf<INPUT>());
    free(input);
  }
}

InputInjector getInputInjector() => IOInputInjector();
