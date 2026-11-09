import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/platform_utils.dart';
import '../services/cloud_sync_service.dart';

class SettingsProvider with ChangeNotifier {
  final CloudSyncService _cloudSync = CloudSyncService();
  
  // Initialization lifecycle & write serialization queue
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;
  Future<void>? _loadingFuture;

  Future<void> _writeQueue = Future.value();
  Future<void> _enqueueWrite(Future<void> Function() task) {
    _writeQueue = _writeQueue.then((_) => task()).catchError((_) {});
    return _writeQueue;
  }

  double _latency = 0;
  bool _vibrationEnabled = true;
  double _hapticIntensity = 0.5;
  String _hapticType = 'medium'; // 'light', 'medium', 'heavy'
  ThemeMode _themeMode = ThemeMode.system;
  bool _alwaysOnTop = true;
  bool _useDegrees = true;
  bool _isOverlayMode = false;
  bool _appendAnswer = false; // "Smart Paste": if true, inserts "Question = Answer"
  bool _aiEnabled = false;
  String? _aiModelPath;
  double _keyboardHeightFactor = 1.0; // 0.8 to 1.4
  bool _isModelDownloaded = false;
  final double _downloadProgress = 0.0;
  final bool _isDownloading = false;
  
  // Theme Customization
  Color _keyboardColor = const Color(0xFF2C2C2C);
  Color _accentColor = Colors.blue;
  String _keyShape = 'rounded'; // 'rounded', 'square', 'pill'
  bool _emojiEnabled = false;

  // AI & OpenAI Settings
  String _aiProviderMode = 'userKey'; // 'local', 'userKey', 'appTier'
  String _openAiApiKey = '';
  String _openAiModel = 'gpt-6-luna';
  List<String> _availableModels = ['gpt-6-luna', 'gpt-4o-mini', 'gpt-4o', 'gpt-3.5-turbo', 'o1-mini'];
  int _dailyUsageCount = 0;
  int _dailyUsageLimit = 12;
  int _purchasedCredits = 0;
  bool _isPremiumUnlocked = false;

  int get purchasedCredits => _purchasedCredits;

  double get latency => _latency;
  bool get vibrationEnabled => _vibrationEnabled;
  double get hapticIntensity => _hapticIntensity;
  String get hapticType => _hapticType;
  ThemeMode get themeMode => _themeMode;
  bool get alwaysOnTop => _alwaysOnTop;
  bool get useDegrees => _useDegrees;
  bool get isOverlayMode => _isOverlayMode;
  bool get appendAnswer => _appendAnswer;
  bool get aiEnabled => _aiEnabled;
  String? get aiModelPath => _aiModelPath;
  double get keyboardHeightFactor => _keyboardHeightFactor;
  bool get isModelDownloaded => _isModelDownloaded;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;
  Color get keyboardColor => _keyboardColor;
  Color get accentColor => _accentColor;
  String get keyShape => _keyShape;
  bool get emojiEnabled => _emojiEnabled;

  // AI getters
  String get aiProviderMode => _aiProviderMode;
  String get openAiApiKey => _openAiApiKey;
  String get openAiModel => _openAiModel;
  List<String> get availableModels => _availableModels;
  int get dailyUsageCount => _dailyUsageCount;
  int get dailyUsageLimit => _dailyUsageLimit;
  bool get isPremiumUnlocked => _isPremiumUnlocked;

  SettingsProvider() {
    loadSettings();
  }

  num? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val;
    if (val is String) {
      final cleaned = val.replaceAll('VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu', '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  void _applyMapValues(Map<dynamic, dynamic> map) {
    if (map.containsKey('keyboardColor')) {
      final val = _parseNum(map['keyboardColor']);
      if (val != null) _keyboardColor = Color(val.toInt());
    }
    if (map.containsKey('accentColor')) {
      final val = _parseNum(map['accentColor']);
      if (val != null) _accentColor = Color(val.toInt());
    }
    if (map.containsKey('keyShape') && map['keyShape'] is String) {
      _keyShape = map['keyShape'] as String;
    }
    if (map.containsKey('emojiEnabled')) {
      final val = map['emojiEnabled'];
      if (val is bool) {
        _emojiEnabled = val;
      } else if (val is String) {
        _emojiEnabled = val.toLowerCase() == 'true';
      }
    }
    if (map.containsKey('keyboardHeightFactor')) {
      final val = _parseNum(map['keyboardHeightFactor']);
      if (val != null) {
        _keyboardHeightFactor = val.toDouble().clamp(0.8, 1.4);
      }
    }
    if (map.containsKey('vibrationEnabled')) {
      final val = map['vibrationEnabled'];
      if (val is bool) {
        _vibrationEnabled = val;
      } else if (val is String) {
        _vibrationEnabled = val.toLowerCase() == 'true';
      }
    }
    if (map.containsKey('hapticIntensity')) {
      final val = _parseNum(map['hapticIntensity']);
      if (val != null) {
        _hapticIntensity = val.toDouble();
      }
    }
    if (map.containsKey('hapticType') && map['hapticType'] is String) {
      _hapticType = map['hapticType'] as String;
    }
    if (map.containsKey('appendAnswer')) {
      final val = map['appendAnswer'];
      if (val is bool) {
        _appendAnswer = val;
      } else if (val is String) {
        _appendAnswer = val.toLowerCase() == 'true';
      }
    }
    if (map.containsKey('useDegrees')) {
      final val = map['useDegrees'];
      if (val is bool) {
        _useDegrees = val;
      } else if (val is String) {
        _useDegrees = val.toLowerCase() == 'true';
      }
    }
    if (map.containsKey('themeMode')) {
      final val = _parseNum(map['themeMode']);
      if (val != null) {
        final idx = val.toInt();
        if (idx >= 0 && idx < ThemeMode.values.length) {
          _themeMode = ThemeMode.values[idx];
        }
      }
    }
    if (map.containsKey('aiEnabled')) {
      final val = map['aiEnabled'];
      if (val is bool) {
        _aiEnabled = val;
      } else if (val is String) {
        _aiEnabled = val.toLowerCase() == 'true';
      }
    }
    if (map.containsKey('aiProviderMode') && map['aiProviderMode'] is String) {
      _aiProviderMode = map['aiProviderMode'] as String;
    }
    if (map.containsKey('isPremiumUnlocked')) {
      final val = map['isPremiumUnlocked'];
      if (val is bool) {
        _isPremiumUnlocked = val;
      } else if (val is String) {
        _isPremiumUnlocked = val.toLowerCase() == 'true';
      }
    }
  }

  Future<void> loadSettings({bool force = false}) {
    if (_loadingFuture != null && !force) {
      return _loadingFuture!;
    }
    _loadingFuture = _loadSettingsInternal();
    return _loadingFuture!;
  }

  Future<void> _loadSettingsInternal() async {
    try {
      // 1. Load local disk backup first as baseline fallback
      final backupMap = await _readSettingsBackupFromDisk();
      if (backupMap != null) {
        _applyMapValues(backupMap);
      }

      // 2. Load SharedPreferences as primary source of truth (overrides backup)
      final prefs = await SharedPreferences.getInstance();
      try { await prefs.reload(); } catch (_) {}

      _latency = _parseNum(prefs.get('latency'))?.toDouble() ?? _latency;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? _vibrationEnabled;
      _hapticIntensity = _parseNum(prefs.get('hapticIntensity'))?.toDouble() ?? _hapticIntensity;
      _hapticType = prefs.getString('hapticType') ?? _hapticType;
      _alwaysOnTop = prefs.getBool('alwaysOnTop') ?? _alwaysOnTop;
      _useDegrees = prefs.getBool('useDegrees') ?? _useDegrees;
      _appendAnswer = prefs.getBool('appendAnswer') ?? _appendAnswer;
      _aiEnabled = prefs.getBool('aiEnabled') ?? _aiEnabled;
      _aiModelPath = prefs.getString('aiModelPath') ?? _aiModelPath;
      
      final savedFactor = _parseNum(prefs.get('keyboardHeightFactor'))?.toDouble();
      if (savedFactor != null) {
        _keyboardHeightFactor = savedFactor.clamp(0.8, 1.4);
      }

      if (PlatformUtils().isDesktop) {
        _isOverlayMode = false;
        try { await prefs.setBool('isOverlayMode', false); } catch (_) {}
      } else {
        _isOverlayMode = prefs.getBool('isOverlayMode') ?? _isOverlayMode;
      }
      _isModelDownloaded = prefs.getBool('isModelDownloaded') ?? _isModelDownloaded;
      _keyShape = prefs.getString('keyShape') ?? _keyShape;
      _emojiEnabled = prefs.getBool('emojiEnabled') ?? _emojiEnabled;

      _aiProviderMode = prefs.getString('aiProviderMode') ?? _aiProviderMode;
      _openAiApiKey = prefs.getString('openAiApiKey') ?? _openAiApiKey;
      _openAiModel = prefs.getString('openAiModel') ?? _openAiModel;
      _availableModels = prefs.getStringList('availableModels') ?? _availableModels;
      _isPremiumUnlocked = prefs.getBool('isPremiumUnlocked') ?? _isPremiumUnlocked;
      _dailyUsageLimit = prefs.getInt('dailyUsageLimit') ?? _dailyUsageLimit;

      // Handle daily usage reset
      String today = DateTime.now().toIso8601String().split('T')[0];
      String lastReset = prefs.getString('lastUsageResetDate') ?? '';
      if (lastReset != today) {
        _dailyUsageCount = 0;
        await prefs.setString('lastUsageResetDate', today);
        await prefs.setInt('dailyUsageCount', 0);
        await _backupUsageToDisk(0, today);
      } else {
        _dailyUsageCount = prefs.getInt('dailyUsageCount') ?? 0;
      }

      final backupCount = await _readUsageBackupFromDisk(today);
      if (backupCount != null) {
        if (backupCount >= 999) {
          _dailyUsageCount = _dailyUsageLimit;
        } else if (backupCount > _dailyUsageCount) {
          _dailyUsageCount = backupCount;
          await prefs.setInt('dailyUsageCount', _dailyUsageCount);
        }
      }

      _purchasedCredits = prefs.getInt('purchasedCredits') ?? 0;

      final themeIndex = prefs.getInt('themeMode');
      if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIndex];
      }

      final kColorVal = prefs.getInt('keyboardColor');
      if (kColorVal != null) _keyboardColor = Color(kColorVal);

      final aColorVal = prefs.getInt('accentColor');
      if (aColorVal != null) _accentColor = Color(aColorVal);

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      notifyListeners();

      _syncCloudAsync(today, prefs);
      _backupSettingsToDisk();
    } catch (e) {
      debugPrint("Error loading settings: $e");
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<void> _syncCloudAsync(String today, SharedPreferences prefs) async {
    try {
      await _cloudSync.ensureSession().timeout(const Duration(seconds: 2));
      final cloudData = await _cloudSync.getCloudUsageAndCredits().timeout(const Duration(seconds: 2));
      final cloudUsage = cloudData['usageCount'] ?? 0;
      final cloudCredits = cloudData['purchasedCredits'] ?? 0;

      bool changed = false;
      if (cloudUsage > _dailyUsageCount) {
        _dailyUsageCount = cloudUsage;
        await prefs.setInt('dailyUsageCount', _dailyUsageCount);
        await _backupUsageToDisk(_dailyUsageCount, today);
        changed = true;
      } else if (_dailyUsageCount > cloudUsage) {
        _cloudSync.updateUsageAndCredits(_dailyUsageCount, _purchasedCredits);
      }

      if (cloudCredits > _purchasedCredits) {
        _purchasedCredits = cloudCredits;
        await prefs.setInt('purchasedCredits', _purchasedCredits);
        changed = true;
      } else if (_purchasedCredits > cloudCredits) {
        _cloudSync.updateUsageAndCredits(_dailyUsageCount, _purchasedCredits);
      }

      if (changed) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Map<String, dynamic> toMap() {
    return {
      'keyboardColor': _keyboardColor.toARGB32(),
      'accentColor': _accentColor.toARGB32(),
      'keyShape': _keyShape,
      'emojiEnabled': _emojiEnabled,
      'keyboardHeightFactor': _keyboardHeightFactor,
      'vibrationEnabled': _vibrationEnabled,
      'hapticIntensity': _hapticIntensity,
      'hapticType': _hapticType,
      'appendAnswer': _appendAnswer,
      'useDegrees': _useDegrees,
      'themeMode': _themeMode.index,
      'aiEnabled': _aiEnabled,
      'aiProviderMode': _aiProviderMode,
      'isPremiumUnlocked': _isPremiumUnlocked,
    };
  }

  Future<void> updateFromMap(Map<dynamic, dynamic> map) async {
    _applyMapValues(map);
    notifyListeners();
    await _saveMapToPrefs(map);
  }

  Future<void> _saveMapToPrefs(Map<dynamic, dynamic> map) async {
    await _enqueueWrite(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (map.containsKey('keyboardColor') && map['keyboardColor'] is int) {
          await prefs.setInt('keyboardColor', map['keyboardColor'] as int);
        }
        if (map.containsKey('accentColor') && map['accentColor'] is int) {
          await prefs.setInt('accentColor', map['accentColor'] as int);
        }
        if (map.containsKey('keyShape') && map['keyShape'] is String) {
          await prefs.setString('keyShape', map['keyShape'] as String);
        }
        if (map.containsKey('emojiEnabled') && map['emojiEnabled'] is bool) {
          await prefs.setBool('emojiEnabled', map['emojiEnabled'] as bool);
        }
        if (map.containsKey('keyboardHeightFactor') && map['keyboardHeightFactor'] is num) {
          await prefs.setDouble('keyboardHeightFactor', (map['keyboardHeightFactor'] as num).toDouble());
        }
        if (map.containsKey('vibrationEnabled') && map['vibrationEnabled'] is bool) {
          await prefs.setBool('vibrationEnabled', map['vibrationEnabled'] as bool);
        }
        if (map.containsKey('hapticIntensity') && map['hapticIntensity'] is num) {
          await prefs.setDouble('hapticIntensity', (map['hapticIntensity'] as num).toDouble());
        }
        if (map.containsKey('hapticType') && map['hapticType'] is String) {
          await prefs.setString('hapticType', map['hapticType'] as String);
        }
        if (map.containsKey('appendAnswer') && map['appendAnswer'] is bool) {
          await prefs.setBool('appendAnswer', map['appendAnswer'] as bool);
        }
        if (map.containsKey('useDegrees') && map['useDegrees'] is bool) {
          await prefs.setBool('useDegrees', map['useDegrees'] as bool);
        }
        if (map.containsKey('themeMode') && map['themeMode'] is int) {
          await prefs.setInt('themeMode', map['themeMode'] as int);
        }
        if (map.containsKey('aiEnabled') && map['aiEnabled'] is bool) {
          await prefs.setBool('aiEnabled', map['aiEnabled'] as bool);
        }
        if (map.containsKey('aiProviderMode') && map['aiProviderMode'] is String) {
          await prefs.setString('aiProviderMode', map['aiProviderMode'] as String);
        }
        if (map.containsKey('isPremiumUnlocked') && map['isPremiumUnlocked'] is bool) {
          await prefs.setBool('isPremiumUnlocked', map['isPremiumUnlocked'] as bool);
        }
      } catch (_) {}
      _backupSettingsToDisk();
    });
  }

  Future<void> _notifySettingsChanged({bool notifyIme = true}) async {
    notifyListeners();
    if (notifyIme && !PlatformUtils().isWeb) {
      try {
        await const MethodChannel('com.quantakeys/ime')
            .invokeMethod('notifySettingsChanged', toMap())
            .timeout(const Duration(milliseconds: 200), onTimeout: () => null);
      } catch (e) {
        debugPrint("MethodChannel notifySettingsChanged error: $e");
      }
    }
  }

  Future<void> setKeyboardColor(Color color) async {
    await initialized;
    _keyboardColor = color;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('keyboardColor', color.toARGB32());
    });
    await _notifySettingsChanged();
  }

  Future<void> setAccentColor(Color color) async {
    await initialized;
    _accentColor = color;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('accentColor', color.toARGB32());
    });
    await _notifySettingsChanged();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await initialized;
    _alwaysOnTop = value;
    notifyListeners();
    try {
      await windowManager.setAlwaysOnTop(value);
    } catch (_) {}
    final platform = PlatformUtils();
    if (platform.isWindows) {
       platform.applyWindowSettings(nonFocusable: _isOverlayMode, alwaysOnTop: value);
    }
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alwaysOnTop', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setUseDegrees(bool value) async {
    await initialized;
    _useDegrees = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useDegrees', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setAppendAnswer(bool value) async {
    await initialized;
    _appendAnswer = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('appendAnswer', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setAiEnabled(bool value) async {
    await initialized;
    _aiEnabled = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('aiEnabled', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setAiModelPath(String? value) async {
    await initialized;
    _aiModelPath = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove('aiModelPath');
      } else {
        await prefs.setString('aiModelPath', value);
      }
    });
    await _notifySettingsChanged();
  }

  Future<void> setDailyUsageLimit(int value) async {
    await initialized;
    _dailyUsageLimit = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dailyUsageLimit', value);
    });
    await _notifySettingsChanged();
  }

  void reloadHeightFactor(double value) {
    if ((_keyboardHeightFactor - value).abs() > 0.001) {
      _keyboardHeightFactor = value;
      notifyListeners();
    }
  }

  Future<void> setKeyboardHeightFactor(double value, {bool notifyIme = true}) async {
    await initialized;
    _keyboardHeightFactor = value.clamp(0.8, 1.4);
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('keyboardHeightFactor', _keyboardHeightFactor);
    });
    await _notifySettingsChanged(notifyIme: notifyIme);
  }

  Future<void> setKeyShape(String shape) async {
    await initialized;
    _keyShape = shape;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('keyShape', shape);
    });
    await _notifySettingsChanged();
  }

  Future<void> setEmojiEnabled(bool value) async {
    await initialized;
    _emojiEnabled = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('emojiEnabled', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setOverlayMode(bool value) async {
    await initialized;
    _isOverlayMode = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOverlayMode', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await initialized;
    _themeMode = mode;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', mode.index);
    });
    await _notifySettingsChanged();
  }

  Future<void> setLatency(double value, {bool notifyIme = true}) async {
    await initialized;
    _latency = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latency', value);
    });
    await _notifySettingsChanged(notifyIme: notifyIme);
  }

  Future<void> setVibrationEnabled(bool value) async {
    await initialized;
    _vibrationEnabled = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vibrationEnabled', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> setHapticIntensity(double value, {bool notifyIme = true}) async {
    await initialized;
    _hapticIntensity = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('hapticIntensity', value);
    });
    await _notifySettingsChanged(notifyIme: notifyIme);
  }

  Future<void> setHapticType(String type) async {
    await initialized;
    _hapticType = type;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hapticType', type);
    });
    await _notifySettingsChanged();
  }

  Future<void> setAiProviderMode(String mode) async {
    await initialized;
    _aiProviderMode = mode;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aiProviderMode', mode);
    });
    await _notifySettingsChanged();
  }

  Future<void> setOpenAiApiKey(String key) async {
    await initialized;
    _openAiApiKey = key.trim();
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('openAiApiKey', _openAiApiKey);
    });
    await _notifySettingsChanged(notifyIme: false); // Do not transmit API keys to native keyboard
  }

  Future<void> setOpenAiModel(String model) async {
    await initialized;
    _openAiModel = model;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('openAiModel', model);
    });
    await _notifySettingsChanged();
  }

  Future<void> setAvailableModels(List<String> models) async {
    await initialized;
    if (models.isNotEmpty) {
      _availableModels = models;
      if (!_availableModels.contains(_openAiModel)) {
        _openAiModel = _availableModels.first;
      }
      notifyListeners();
      await _enqueueWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('availableModels', _availableModels);
        await prefs.setString('openAiModel', _openAiModel);
      });
      await _notifySettingsChanged();
    }
  }

  Future<void> setPremiumUnlocked(bool value) async {
    await initialized;
    _isPremiumUnlocked = value;
    notifyListeners();
    await _enqueueWrite(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPremiumUnlocked', value);
    });
    await _notifySettingsChanged();
  }

  Future<void> incrementDailyUsage() async {
    try {
      await initialized;
      if (_dailyUsageCount < _dailyUsageLimit) {
        _dailyUsageCount++;
      } else if (_purchasedCredits > 0) {
        _purchasedCredits--;
      }
      await _enqueueWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('dailyUsageCount', _dailyUsageCount);
        await prefs.setInt('purchasedCredits', _purchasedCredits);
      });
      String today = DateTime.now().toIso8601String().split('T')[0];
      await _backupUsageToDisk(0, today);
      await _cloudSync.updateUsageAndCredits(_dailyUsageCount, _purchasedCredits);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addPurchasedCredits(int amount) async {
    try {
      await initialized;
      _purchasedCredits += amount;
      await _enqueueWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('purchasedCredits', _purchasedCredits);
      });
      if (_cloudSync.isSignedIn) {
        await _cloudSync.updateUsageAndCredits(_dailyUsageCount, _purchasedCredits);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<File?> _getUsageBackupFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/.quantakeys_usage.json');
    } catch (_) {
      return null;
    }
  }

  Future<File?> _getSettingsBackupFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/.quantakeys_settings_backup.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _backupSettingsToDisk() async {
    try {
      final file = await _getSettingsBackupFile();
      if (file != null) {
        await file.writeAsString(jsonEncode(toMap()));
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readSettingsBackupFromDisk() async {
    try {
      final file = await _getSettingsBackupFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _backupUsageToDisk(int count, String date) async {
    try {
      final file = await _getUsageBackupFile();
      if (file != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await file.writeAsString(jsonEncode({
          'count': count,
          'date': date,
          'timestamp': nowMs,
        }));
      }
    } catch (_) {}
  }

  Future<int?> _readUsageBackupFromDisk(String today) async {
    try {
      final file = await _getUsageBackupFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastTs = data['timestamp'] as int? ?? 0;
        if (nowMs < lastTs - 120000) {
          return 999;
        }
        if (data['date'] == today) {
          return data['count'] as int?;
        }
      }
    } catch (_) {}
    return null;
  }

  bool get isSignedIn => _cloudSync.isSignedIn;

  bool canUseCloudAi() {
    try {
      if (_aiProviderMode == 'userKey') {
        return _openAiApiKey.trim().isNotEmpty;
      }
      if (_aiProviderMode == 'appTier' || _aiProviderMode == 'local') {
        if (_isPremiumUnlocked) return true;
        if (!_cloudSync.isSignedIn) {
          _cloudSync.ensureSession();
          if (!_cloudSync.isSignedIn) return false;
        }
        return _dailyUsageCount < _dailyUsageLimit || _purchasedCredits > 0;
      }
      return true;
    } catch (_) {
      return true;
    }
  }
}
