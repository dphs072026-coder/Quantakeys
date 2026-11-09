package com.latenightbuilds.quantakeys

import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "quantakeys/keyboard"
    private val IME_CHANNEL = "com.quantakeys/ime"

    override fun getInitialRoute(): String {
        return intent?.getStringExtra("route") ?: "/"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isQuantaKeysDefault" -> {
                    result.success(isQuantaKeysDefault())
                }
                "isQuantaKeysEnabled" -> {
                    result.success(isQuantaKeysEnabled())
                }
                "openKeyboardSettings" -> {
                    openKeyboardSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPersistedSettings" -> {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                    val map = HashMap<String, Any?>()
                    val doublePrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
                    for ((key, value) in prefs.all) {
                        val cleanKey = if (key.startsWith("flutter.")) key.substring(8) else key
                        var cleanValue = value
                        if (value is String && value.startsWith(doublePrefix)) {
                            val numStr = value.substring(doublePrefix.length)
                            cleanValue = numStr.toDoubleOrNull() ?: value
                        }
                        map[cleanKey] = cleanValue
                    }
                    result.success(map)
                }
                "notifySettingsChanged" -> {
                    val quantaEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("quanta_engine")
                    if (quantaEngine != null) {
                        MethodChannel(quantaEngine.dartExecutor.binaryMessenger, IME_CHANNEL)
                            .invokeMethod("notifySettingsChanged", call.arguments)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            val enabledMethods = imm.enabledInputMethodList
            val isEnabled = enabledMethods.any { it.packageName == packageName }
            val defaultIme = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            val isDefault = defaultIme != null && defaultIme.contains(packageName)

            if (isEnabled && !isDefault) {
                // Automatically show input method picker to set as default once keyboard access is enabled
                imm.showInputMethodPicker()
            }
        } catch (_: Exception) {}
    }

    private fun isQuantaKeysDefault(): Boolean {
        val defaultIme = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.DEFAULT_INPUT_METHOD
        )
        val currentPackageName = packageName
        return defaultIme != null && defaultIme.contains(currentPackageName)
    }

    private fun isQuantaKeysEnabled(): Boolean {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val enabledMethods = imm.enabledInputMethodList
        return enabledMethods.any { it.packageName == packageName }
    }

    private fun openKeyboardSettings() {
        try {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            val enabledMethods = imm.enabledInputMethodList
            val isEnabled = enabledMethods.any { it.packageName == packageName }

            if (isEnabled) {
                imm.showInputMethodPicker()
            } else {
                val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                startActivity(intent)
            }
        } catch (_: Exception) {
            val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
            startActivity(intent)
        }
    }
}
