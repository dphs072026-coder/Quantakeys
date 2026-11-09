import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantakeys/engine/scientific_engine.dart';
import 'package:quantakeys/engine/openai_engine.dart';
import 'package:quantakeys/engine/word_suggestion_engine.dart';
import 'package:quantakeys/engine/input_injector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quantakeys/utils/platform_utils.dart';
import 'package:quantakeys/providers/settings_provider.dart';
import 'package:quantakeys/providers/calculation_history_provider.dart';
import 'package:quantakeys/providers/custom_layout_provider.dart';
import 'package:quantakeys/layouts/default_layouts.dart';
import 'package:quantakeys/models/key_item.dart';
import 'package:quantakeys/models/key_layout.dart';

enum ShiftState { off, shift, capsLock }

class KeyboardProvider with ChangeNotifier {
  static const _channel = MethodChannel('com.quantakeys/ime');
  static final WordSuggestionEngine _suggestionEngine = WordSuggestionEngine();
  final _injector = InputInjector();
  final _platform = PlatformUtils();
  
  String _activeTab = 'ABC';
  String _inputBuffer = '';
  String _suggestion = '';
  List<String> _wordSuggestions = [];
  bool _isThinking = false;
  bool _isCommitting = false; // Transaction Lock
  ShiftState _shiftState = ShiftState.off;
  DateTime? _lastShiftTap;
  bool _isExternalInputEnabled = true;
  bool _isImeConnected = false;
  bool _isGestureNavigation = false;
  bool _isConnectModeEnabled = false;
  Set<String> _hotKeys = {};
  CalculationHistoryProvider? _historyProvider;
  SettingsProvider? _settingsProvider;
  CustomLayoutProvider? _customLayoutProvider;

  String get activeTab => _activeTab;
  String get inputBuffer => _inputBuffer;
  String get suggestion => _suggestion;
  List<String> get wordSuggestions => _wordSuggestions;
  bool get isThinking => _isThinking;
  ShiftState get shiftState => _shiftState;
  bool get isShiftEnabled => _shiftState != ShiftState.off;
  bool get isCapsLock => _shiftState == ShiftState.capsLock;
  bool get isConnectModeEnabled => _isConnectModeEnabled;
  bool get isExternalInputEnabled => _isExternalInputEnabled;
  bool get isImeConnected => _isImeConnected;
  bool get isGestureNavigation => _isGestureNavigation;
  Set<String> get hotKeys => _hotKeys;

  void toggleConnectMode() {
    _isConnectModeEnabled = !_isConnectModeEnabled;
    notifyListeners();
  }

  KeyItem? _findKeyByShortcut(String tabName, String shortcutChar) {
    KeyLayout? layout;
    switch (tabName) {
      case 'MATH':
        layout = DefaultLayouts.math;
        break;
      case 'CHEM':
        layout = DefaultLayouts.chem;
        break;
      case 'PHYS':
        layout = DefaultLayouts.phys;
        break;
    }
    if (layout == null) return null;

    for (var row in layout.rows) {
      for (var keyItem in row) {
        if (keyItem.shortcut == shortcutChar) {
          return keyItem;
        }
      }
    }
    return null;
  }

  KeyboardProvider() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _checkConnection();
    _calculateSuggestions();
  }

  Future<void> _checkConnection() async {
    if (_platform.isWeb) {
      return;
    }
    try {
      final connected = await _channel.invokeMethod<bool>('ping');
      if (connected != null && _isImeConnected != connected) {
        _isImeConnected = connected;
        if (_isImeConnected) {
          _refreshAllData();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void setHistoryProvider(CalculationHistoryProvider provider) { _historyProvider = provider; }
  void setSettingsProvider(SettingsProvider provider) { _settingsProvider = provider; }
  void setCustomLayoutProvider(CustomLayoutProvider provider) { _customLayoutProvider = provider; }

  Future<void> showKeyboardPicker() async {
    try {
      if (_platform.isMobile) {
        await const MethodChannel('com.quantakeys/ime').invokeMethod('showKeyboardPicker');
      }
    } catch (_) {}
  }

  Future<void> refreshAllData() async {
    await _settingsProvider?.loadSettings();
    await _customLayoutProvider?.refresh();
    notifyListeners();
  }

  Future<void> _refreshAllData() async { await refreshAllData(); }
  void setIsExternalInputEnabled(bool value) { _isExternalInputEnabled = value; }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'notifySettingsChanged':
        if (call.arguments is Map) {
          final map = Map<String, dynamic>.from(call.arguments as Map);
          _settingsProvider?.updateFromMap(map);
          try {
            final prefs = await SharedPreferences.getInstance();
            for (var entry in map.entries) {
              final key = entry.key.toString();
              final val = entry.value;
              if (val is bool) {
                await prefs.setBool(key, val);
              } else if (val is int) {
                await prefs.setInt(key, val);
              } else if (val is double) {
                await prefs.setDouble(key, val);
              } else if (val is String) {
                await prefs.setString(key, val);
              }
            }
          } catch (_) {}
        } else {
          await _settingsProvider?.loadSettings();
        }
        await _customLayoutProvider?.refresh();
        notifyListeners();
        break;
      case 'connectionStatus':
        final connected = call.arguments['connected'] as bool;
        final gesture = call.arguments['isGestureNavigation'] as bool? ?? false;
        bool changed = false;
        if (connected) {
          _refreshAllData();
          if (!_isImeConnected) { 
            _isImeConnected = true; 
            changed = true; 
          }
        } else {
          if (_isImeConnected) { 
            _isImeConnected = false; 
            changed = true; 
          }
        }
        if (_isGestureNavigation != gesture) { 
          _isGestureNavigation = gesture; 
          changed = true; 
        }
        if (changed) {
          notifyListeners();
        }
        break;
      case 'updateContext':
        if (_isCommitting) {
          return; // IGNORE updates during Smart Append
        }
        final textBefore = call.arguments['textBefore'] as String;
        final textAfter = call.arguments['textAfter'] as String? ?? "";
        final newBuffer = _extractPossibleFormula(textBefore, textAfter);
        if (_inputBuffer != newBuffer) {
          _inputBuffer = newBuffer;
          _calculateSuggestions();
          notifyListeners();
        }
        break;
    }
  }

  String _extractPossibleFormula(String textBefore, String textAfter) {
    if (textBefore.isEmpty && textAfter.isEmpty) {
      return "";
    }
    final lastLine = textBefore.split('\n').last;
    return lastLine.trim();
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void updateInput(String text) {
    _inputBuffer = text;
    _calculateSuggestions();
    notifyListeners();
  }

  void appendText(String text) {
    if (_isCommitting) {
      return;
    }
    String processedText = text;

    // Check if Connect Mode is active on PHY, CHE, MAT tabs
    final isScientificTab = ['MATH', 'CHEM', 'PHYS'].contains(_activeTab);
    if (_isConnectModeEnabled && isScientificTab && text.length == 1) {
      final shortcutItem = _findKeyByShortcut(_activeTab, text.toLowerCase());
      if (shortcutItem != null) {
        processedText = shortcutItem.value;
      }
    } else if (_shiftState != ShiftState.off && text.length == 1) {
      processedText = text.toUpperCase();
      if (_shiftState == ShiftState.shift) {
        _shiftState = ShiftState.off;
      }
    }
    _inputBuffer += processedText;
    _calculateSuggestions();
    bool shouldInject = _isExternalInputEnabled;
    if (_platform.isDesktop) {
      shouldInject = _settingsProvider?.isOverlayMode ?? false;
    }
    if (shouldInject) {
      if (_platform.isWeb) {
         // Internal
      } else if (_platform.isMobile) {
        _commitToIME(processedText);
      } else {
        _injector.injectText(processedText);
      }
    }
    notifyListeners();
  }

  void acceptWordSuggestion(String word) async {
    if (_isCommitting) {
      return;
    }
    _isCommitting = true;
    final lastWord = _inputBuffer.contains(' ') 
        ? _inputBuffer.split(' ').last 
        : _inputBuffer;
    final int deleteLen = lastWord.length;
    if (_platform.isMobile) {
      await _deleteFromIME(length: deleteLen);
      await _commitToIME("$word ");
    } else {
      for (int i=0; i<deleteLen; i++) { 
        _injector.injectBackspace(); 
        await Future.delayed(const Duration(milliseconds: 5)); 
      }
      await Future.delayed(const Duration(milliseconds: 20));
      await _injector.injectText("$word ");
    }
    if (_inputBuffer.contains(' ')) {
      final parts = _inputBuffer.split(' ');
      parts.removeLast();
      _inputBuffer = "${parts.join(' ')} $word ";
    } else {
      _inputBuffer = "$word ";
    }
    _wordSuggestions = [];
    _isCommitting = false;
    notifyListeners();
  }

  /// THE FINAL SMART APPEND ENGINE
  void commitSuggestion() async {
    if (_suggestion.isEmpty || _isThinking || _isCommitting) {
      return;
    }

    // 1. Snapshot everything immediately
    _isCommitting = true;
    final String questionSnapshot = _inputBuffer; 
    final String answerSnapshot = _suggestion;
    final bool appendMode = _settingsProvider?.appendAnswer ?? false;

    _historyProvider?.addEntry(questionSnapshot.trim(), answerSnapshot);

    // 2. State cleanup
    _suggestion = '';
    _wordSuggestions = [];
    notifyListeners();

    // 3. Document Interaction
    if (appendMode) {
      // Append mode: e.g. "root 144 = 12"
      String suffix = " = $answerSnapshot";
      if (questionSnapshot.trim().endsWith('=')) {
        suffix = " $answerSnapshot";
      }
      if (_platform.isMobile) {
        await _commitToIME(suffix);
      } else {
        await _injector.injectText(suffix);
      }
      _inputBuffer = "$questionSnapshot$suffix";
    } else {
      // Replace mode: delete question, type ONLY answer
      if (_platform.isMobile) {
        await _deleteFromIME(length: questionSnapshot.length);
        await _commitToIME(answerSnapshot);
      } else {
        // High-precision Windows deletion
        final int count = questionSnapshot.length;
        for (int i = 0; i < count; i++) {
          _injector.injectBackspace();
          await Future.delayed(const Duration(milliseconds: 12));
        }
        await Future.delayed(const Duration(milliseconds: 50));
        await _injector.injectText(answerSnapshot);
      }
      _inputBuffer = answerSnapshot;
    }

    // 4. Reset transaction
    await Future.delayed(const Duration(milliseconds: 150));
    _isCommitting = false;
    _calculateSuggestions();
    notifyListeners();
  }

  void backspace() {
    if (_isCommitting) {
      return;
    }
    if (_inputBuffer.isNotEmpty) {
      _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      _calculateSuggestions();
    }
    bool shouldInject = _isExternalInputEnabled;
    if (_platform.isDesktop) {
      shouldInject = _settingsProvider?.isOverlayMode ?? false;
    }
    if (shouldInject) {
      if (_platform.isMobile) {
        _deleteFromIME();
      } else if (!_platform.isWeb) {
        _injector.injectBackspace();
      }
    }
    notifyListeners();
  }

  void clearInput() { 
    if (!_isCommitting) { 
      _inputBuffer = ''; 
      _calculateSuggestions(); 
    } 
  }

  void toggleShift() {
    final now = DateTime.now();
    if (_shiftState == ShiftState.off) {
      _shiftState = ShiftState.shift;
    } else if (_shiftState == ShiftState.shift) {
      if (_lastShiftTap != null && now.difference(_lastShiftTap!) < const Duration(milliseconds: 300)) {
        _shiftState = ShiftState.capsLock;
      } else {
        _shiftState = ShiftState.off;
      }
    } else {
      _shiftState = ShiftState.off;
    }
    _lastShiftTap = now;
    notifyListeners();
  }

  Future<void> pasteFromClipboard() async {
    String? text;
    if (_platform.isMobile) {
      text = await _channel.invokeMethod<String>('getClipboard');
    } else { 
      final data = await Clipboard.getData(Clipboard.kTextPlain); 
      text = data?.text; 
    }
    if (text != null && text.isNotEmpty) {
      appendText(text);
    }
  }

  Future<void> sendAction() async {
    bool shouldInject = _isExternalInputEnabled;
    if (_platform.isDesktop) {
      shouldInject = _settingsProvider?.isOverlayMode ?? false;
    }
    if (shouldInject) {
      if (_platform.isMobile) {
        try { await _channel.invokeMethod('sendAction'); } catch (_) {}
      } else {
        _injector.injectEnter();
      }
    } else {
      appendText('\n');
    }
  }

  Future<void> moveCursor(int direction) async {
    bool shouldInject = _isExternalInputEnabled;
    if (_platform.isDesktop) {
      shouldInject = _settingsProvider?.isOverlayMode ?? false;
    }
    if (shouldInject) {
      if (_platform.isMobile) {
        try { await _channel.invokeMethod('moveCursor', {'direction': direction}); } catch (_) {}
      } else {
        _injector.injectArrow(direction);
      }
    }
  }

  Future<void> openSettings() async {
    if (_platform.isMobile) {
      try { await _channel.invokeMethod('openSettings'); } catch (_) {}
    }
  }

  Future<void> runMagicTool() async {
    if (_isCommitting) {
      return;
    }
    String textToProcess = _inputBuffer;
    bool hadSelection = false;

    if (_platform.isMobile) {
      final selected = await _channel.invokeMethod<String>('getSelectedText');
      if (selected != null && selected.isNotEmpty) { 
        textToProcess = selected; 
        hadSelection = true; 
      }
    } else if (_platform.isWindows) {
      _injector.injectCopy();
      await Future.delayed(const Duration(milliseconds: 200));
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) { 
        textToProcess = data.text!; 
        hadSelection = true; 
      }
    }

    if (textToProcess.length < 2) {
      return;
    }
    _isThinking = true;
    notifyListeners();

    final settings = _settingsProvider;
    final mode = settings?.aiProviderMode ?? 'appTier';

    if (settings != null && !settings.canUseCloudAi()) {
      _isThinking = false;
      _suggestion = !settings.isSignedIn
          ? "Please sign in with your email in Settings to use App Default AI!"
          : "Daily Limit Reached (${settings.dailyUsageCount}/${settings.dailyUsageLimit}). Buy +15 Pack or Add API Key in Settings!";
      notifyListeners();
      return;
    }

    String? result;

    // 1. Check if it's a math formula or word problem
    final localSolution = await ScientificEngine.solveAi(textToProcess);
    final isMath = (localSolution != null && localSolution.isNotEmpty) || _isMathOrWordProblem(textToProcess);

    if (localSolution != null && localSolution.isNotEmpty) {
      result = localSolution;
    } else if (isMath) {
      // Complex Math / Scientific Word Problem Solving via Cloud AI or Local
      if (mode == 'userKey' && (settings?.openAiApiKey.isNotEmpty ?? false)) {
        try {
          result = await OpenAiEngine.solveWordProblem(
            query: textToProcess,
            apiKey: settings!.openAiApiKey,
            model: settings.openAiModel,
          );
        } catch (e) {
          debugPrint("OpenAI solveWordProblem error (userKey): $e");
          result = localSolution ?? textToProcess;
        }
      } else if (mode == 'appTier' && settings != null) {
        try {
          const appDefaultApiKey = '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';
          const appDefaultModel = 'qwen/qwen3.8-27b';
          result = await OpenAiEngine.solveWordProblem(
            query: textToProcess,
            apiKey: appDefaultApiKey,
            model: appDefaultModel,
          );
          if (result != null && result.isNotEmpty && !settings.isPremiumUnlocked) {
            await settings.incrementDailyUsage();
          }
        } catch (e) {
          debugPrint("OpenAI solveWordProblem error (appTier): $e");
          result = localSolution ?? textToProcess;
        }
      } else {
        result = localSolution ?? textToProcess;
      }
    } else {
      // Text Polishing & Grammar Correction Mode via Cloud AI or Local
      if (mode == 'userKey' && (settings?.openAiApiKey.isNotEmpty ?? false)) {
        try {
          result = await OpenAiEngine.polishText(
            text: textToProcess,
            apiKey: settings!.openAiApiKey,
            model: settings.openAiModel,
          );
        } catch (e) {
          debugPrint("OpenAI polishText error (userKey): $e");
          result = await ScientificEngine.polishText(textToProcess);
        }
      } else if (mode == 'appTier' && settings != null) {
        try {
          const appDefaultApiKey = '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';
          const appDefaultModel = 'qwen/qwen3.8-27b';
          result = await OpenAiEngine.polishText(
            text: textToProcess,
            apiKey: appDefaultApiKey,
            model: appDefaultModel,
          );
          if (result != null && result.isNotEmpty && !settings.isPremiumUnlocked) {
            await settings.incrementDailyUsage();
          }
        } catch (e) {
          debugPrint("OpenAI polishText error (appTier): $e");
          result = await ScientificEngine.polishText(textToProcess);
        }
      } else {
        result = await ScientificEngine.polishText(textToProcess);
      }
    }

    _isThinking = false;

    if (result != null && result.isNotEmpty) {
      _inputBuffer = textToProcess; // Ensure inputBuffer holds the exact query for Smart Append ("Question = Answer")
      if (_platform.isMobile) {
        _isCommitting = true;
        if (!hadSelection) {
          await _deleteFromIME(length: textToProcess.length);
        }
        await _commitToIME(result);
        _inputBuffer = result;
        _isCommitting = false;
      } else {
        // On Windows / Desktop: show as suggestion only in SuggestionBar, 
        // letting the user tap it to print simply or use Smart Append.
        _suggestion = result;
      }
    }
    notifyListeners();
  }

  bool _isMathOrWordProblem(String text) {
    final lower = text.toLowerCase();
    return lower.contains(RegExp(r'[0-9.+\-*/^=×÷π∑∫]')) ||
           lower.contains(RegExp(r'\b(solve|calculate|equation|integral|derivative)\b'));
  }

  void _calculateSuggestions() {
    if (_inputBuffer.isEmpty) {
      _suggestion = '';
      _wordSuggestions = _suggestionEngine.getSuggestions('');
      _isThinking = false;
      notifyListeners();
      return;
    }
    final scientificResult = ScientificEngine.solve(_inputBuffer, useDegrees: _settingsProvider?.useDegrees ?? true);
    final trimmedBuffer = _inputBuffer.trim();
    final bool isComplexResult = scientificResult.contains('x =') || scientificResult.contains('d/d') || scientificResult.contains('∫ =');
    if (isComplexResult && !trimmedBuffer.endsWith('=')) {
      _suggestion = '';
    } else {
      _suggestion = scientificResult;
    }
    _updateHotKeys(trimmedBuffer);
    if (_suggestion.isEmpty) {
      final lastWord = _inputBuffer.contains(' ') 
          ? _inputBuffer.split(' ').last 
          : _inputBuffer;
      _wordSuggestions = _suggestionEngine.getSuggestions(lastWord);
    } else {
      _wordSuggestions = [];
    }
  }

  void _updateHotKeys(String buffer) {
    _hotKeys = {};
    if (buffer.isEmpty) {
      return;
    }
    if (buffer.contains('x')) {
      _hotKeys.addAll(['^', '2', '3', '=', '(', ')', '+', '-']);
    }
    if (buffer.contains('sin') || buffer.contains('cos') || buffer.contains('tan')) {
      _hotKeys.addAll(['(', ')', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']);
    }
    notifyListeners();
  }

  Future<void> _commitToIME(String text) async {
    try { 
      await _channel.invokeMethod('commitText', {'text': text}); 
      _isImeConnected = true; 
    } 
    on PlatformException catch (_) { 
      _isImeConnected = false; 
    }
    notifyListeners();
  }

  Future<void> _deleteFromIME({int length = 1}) async {
    try { 
      await _channel.invokeMethod('deleteText', {'length': length}); 
    } catch (_) {}
  }
}
