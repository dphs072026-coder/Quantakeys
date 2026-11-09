package com.latenightbuilds.quantakeys

import android.view.View
import android.view.Window
import android.view.WindowManager
import android.inputmethodservice.InputMethodService
import android.view.inputmethod.InputConnection
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.ExtractedTextRequest
import android.view.inputmethod.ExtractedText
import android.text.InputType
import android.view.ViewGroup
import android.view.Gravity
import android.widget.FrameLayout
import android.graphics.Color
import android.util.Log

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterView
import io.flutter.plugins.GeneratedPluginRegistrant

import java.util.HashMap

class QuantaKeysIME : InputMethodService() {
    private var flutterEngine: io.flutter.embedding.engine.FlutterEngine? = null
    private var channel: io.flutter.plugin.common.MethodChannel? = null
    private var keyboardHeightPx: Int = 0
    private var currentEditorInfo: android.view.inputmethod.EditorInfo? = null
    private var flutterView: io.flutter.embedding.android.FlutterView? = null
    private var containerView: android.widget.FrameLayout? = null

    override fun onConfigureWindow(win: Window, isFullscreen: Boolean, isFocused: Boolean) {
        super.onConfigureWindow(win, isFullscreen, isFocused)
        win.addFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
        )
        win.setGravity(Gravity.BOTTOM)
        win.setBackgroundDrawable(android.graphics.drawable.ColorDrawable(Color.TRANSPARENT))
    }

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("QuantaKeysIME", "onCreate - Final Stable Bridge")

        try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            flutterEngine = io.flutter.embedding.engine.FlutterEngine(this)
            
            // Set initial route to bypass Hub logic in overlay mode
            flutterEngine?.navigationChannel?.setInitialRoute("/keyboard")

            io.flutter.plugins.GeneratedPluginRegistrant.registerWith(flutterEngine!!)

            val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            if (messenger != null) {
                channel = io.flutter.plugin.common.MethodChannel(messenger, "com.quantakeys/ime")
                channel?.setMethodCallHandler { call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result ->
                    val ic: android.view.inputmethod.InputConnection? = getCurrentInputConnection()
                    
                    when (call.method) {
                        "isImeService" -> result.success(true)
                        "ping" -> result.success(ic != null)
                        "getPersistedSettings" -> {
                            val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
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
                        "showKeyboardPicker" -> {
                            val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                            imm.showInputMethodPicker()
                            result.success(null)
                        }
                        "notifySettingsChanged" -> {
                            val args = call.arguments as? Map<*, *>
                            val nativeHeight = args?.get("native_last_keyboard_height_dp")
                            val heightDp = when (nativeHeight) {
                                is Double -> nativeHeight
                                is Float -> nativeHeight.toDouble()
                                is Number -> nativeHeight.toDouble()
                                is String -> nativeHeight.toDoubleOrNull()
                                else -> null
                            }
                            if (heightDp != null) {
                                val density = resources.displayMetrics.density
                                updateKeyboardHeightPx((heightDp * density).toInt())
                            }

                            channel?.invokeMethod("notifySettingsChanged", call.arguments)
                            result.success(null)
                        }
                        "setKeyboardHeight" -> {
                            val rawHeight = call.argument<Any>("heightDp")
                            val heightDp = when (rawHeight) {
                                is Double -> rawHeight
                                is Float -> rawHeight.toDouble()
                                is Number -> rawHeight.toDouble()
                                is String -> rawHeight.toDoubleOrNull() ?: 350.0
                                else -> 350.0
                            }
                            val density = resources.displayMetrics.density
                            val heightPx = (heightDp * density).toInt()
                            android.util.Log.d("QuantaKeysIME", "setKeyboardHeight received: totalDp=$heightDp, px=$heightPx")
                            
                            // Persist in SharedPreferences so first frame opens at correct size
                            val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
                            prefs.edit().putFloat("flutter.native_last_keyboard_height_dp", heightDp.toFloat()).apply()

                            updateKeyboardHeightPx(heightPx)
                            result.success(null)
                        }
                        else -> {
                            if (ic == null) {
                                result.error("NO_IC", "InputConnection is null", null)
                                return@setMethodCallHandler
                            }
                            when (call.method) {
                                "commitText" -> {
                                    val text: String = call.argument<String>("text") ?: ""
                                    android.util.Log.d("QuantaKeysIME", "commitText: '$text', ic=$ic")
                                    ic.beginBatchEdit()
                                    ic.commitText(text, 1)
                                    ic.endBatchEdit()
                                    result.success(null)
                                }
                                "deleteText" -> {
                                    val length: Int = call.argument<Int>("length") ?: 1
                                    ic.beginBatchEdit()
                                    val request = ExtractedTextRequest()
                                    val et = ic.getExtractedText(request, 0)
                                    if (et != null && et.selectionStart != et.selectionEnd) {
                                        ic.commitText("", 1)
                                    } else {
                                        ic.deleteSurroundingText(length, 0)
                                    }
                                    ic.endBatchEdit()
                                    result.success(null)
                                }
                                "sendAction" -> {
                                    handleEnterAction(ic)
                                    result.success(null)
                                }
                                "moveCursor" -> {
                                    val direction: Int = call.argument<Int>("direction") ?: 0
                                    if (direction != 0) {
                                        val request = android.view.inputmethod.ExtractedTextRequest()
                                        val et: android.view.inputmethod.ExtractedText? = ic.getExtractedText(request, 0)
                                        if (et != null) {
                                            val newPos: Int = Math.max(0, et.selectionStart + direction)
                                            ic.setSelection(newPos, newPos)
                                        }
                                    }
                                    result.success(null)
                                }
                                "openSettings" -> {
                                    val intent = android.content.Intent(applicationContext, MainActivity::class.java)
                                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                    intent.putExtra("route", "/settings")
                                    startActivity(intent)
                                    result.success(null)
                                }
                                "getClipboard" -> {
                                    val cm = getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                                    val item = cm.primaryClip?.getItemAt(0)
                                    val text = item?.text?.toString() ?: ""
                                    result.success(text)
                                }
                                "getSelectedText" -> {
                                    val request = ExtractedTextRequest()
                                    val et = ic.getExtractedText(request, 0)
                                    if (et != null && et.selectionStart != et.selectionEnd) {
                                        val selected = et.text.substring(et.selectionStart, et.selectionEnd)
                                        result.success(selected)
                                    } else {
                                        result.success(null)
                                    }
                                }
                                else -> result.notImplemented()
                            }
                        }
                    }
                }
            }

            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "keyboardMain"
                )
            )
            io.flutter.embedding.engine.FlutterEngineCache.getInstance().put("quanta_engine", flutterEngine)

        } catch (e: java.lang.Exception) {
            android.util.Log.e("QuantaKeysIME", "Failed to init FlutterEngine", e)
        }
    }

    private fun getNavigationMode(): Int {
        val resourceId = resources.getIdentifier("config_navBarInteractionMode", "integer", "android")
        return if (resourceId > 0) resources.getInteger(resourceId) else 0
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        channel?.invokeMethod("onConfigurationChanged", mapOf("orientation" to newConfig.orientation))
    }

    private fun handleEnterAction(ic: android.view.inputmethod.InputConnection) {
        val info = currentEditorInfo
        if (info == null) {
            ic.commitText("\n", 1)
            return
        }

        val actionId = info.imeOptions and EditorInfo.IME_MASK_ACTION
        val isMultiLine = (info.inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE) != 0

        if (actionId == EditorInfo.IME_ACTION_SEARCH || actionId == EditorInfo.IME_ACTION_GO) {
            ic.performEditorAction(actionId)
        } else if (isMultiLine) {
            ic.commitText("\n", 1)
        } else if (actionId != EditorInfo.IME_ACTION_NONE && actionId != EditorInfo.IME_ACTION_UNSPECIFIED) {
            ic.performEditorAction(actionId)
        } else {
            ic.commitText("\n", 1)
        }
    }

    private fun getSafeFloatPref(key: String, defaultVal: Float): Float {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
            val obj = prefs.all[key]
            when (obj) {
                is Number -> obj.toFloat()
                is String -> obj.toFloatOrNull() ?: defaultVal
                else -> defaultVal
            }
        } catch (_: Exception) {
            defaultVal
        }
    }

    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        currentEditorInfo = info
        android.util.Log.d("QuantaKeysIME", "onStartInputView: editorInfo=$info, restarting=$restarting")
        
        val lastDp = getSafeFloatPref("flutter.native_last_keyboard_height_dp", 460f).toDouble()
        val density = resources.displayMetrics.density
        updateKeyboardHeightPx((lastDp * density).toInt())

        val data = HashMap<String, Any>()
        data["connected"] = true
        data["isGestureNavigation"] = (getNavigationMode() == 2)
        channel?.invokeMethod("connectionStatus", data)
        channel?.invokeMethod("connectionStatus", data)

        val ic: android.view.inputmethod.InputConnection? = getCurrentInputConnection()
        if (ic != null && channel != null) {
            val textBefore: CharSequence? = ic.getTextBeforeCursor(100, 0)
            val textAfter: CharSequence? = ic.getTextAfterCursor(100, 0)
            val ctxData = java.util.HashMap<String, String>()
            ctxData["textBefore"] = textBefore?.toString() ?: ""
            ctxData["textAfter"] = textAfter?.toString() ?: ""
            channel?.invokeMethod("updateContext", ctxData)
        }
        
        channel?.invokeMethod("notifySettingsChanged", emptyMap<String, Any>())
        flutterEngine?.lifecycleChannel?.appIsResumed()
    }

    override fun onFinishInputView(finishInput: Boolean) {
        super.onFinishInputView(finishInput)
        currentEditorInfo = null
        channel?.invokeMethod("connectionStatus", mapOf("connected" to false))
        flutterEngine?.lifecycleChannel?.appIsPaused()
    }

    override fun onUpdateSelection(
        oldSelStart: Int, oldSelEnd: Int,
        newSelStart: Int, newSelEnd: Int,
        candidatesStart: Int, candidatesEnd: Int
    ) {
        super.onUpdateSelection(oldSelStart, oldSelEnd, newSelStart, newSelEnd, candidatesStart, candidatesEnd)
        val ic: android.view.inputmethod.InputConnection? = getCurrentInputConnection()
        if (ic != null && channel != null) {
            val textBefore: CharSequence? = ic.getTextBeforeCursor(100, 0)
            val textAfter: CharSequence? = ic.getTextAfterCursor(100, 0)
            val data = java.util.HashMap<String, String>()
            data["textBefore"] = textBefore?.toString() ?: ""
            data["textAfter"] = textAfter?.toString() ?: ""
            channel?.invokeMethod("updateContext", data)
        }
    }

    private fun updateKeyboardHeightPx(newHeightPx: Int) {
        if (newHeightPx <= 0) return

        keyboardHeightPx = newHeightPx

        containerView?.let { container ->
            val params = container.layoutParams
                ?: ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    keyboardHeightPx
                )

            params.width = ViewGroup.LayoutParams.MATCH_PARENT
            params.height = keyboardHeightPx

            container.layoutParams = params
            container.requestLayout()
        }

        flutterView?.let { view ->
            val params = view.layoutParams
                ?: FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )

            params.width = ViewGroup.LayoutParams.MATCH_PARENT
            params.height = ViewGroup.LayoutParams.MATCH_PARENT

            view.layoutParams = params
            view.requestLayout()
        }

        Log.d(
            "QuantaKeysIME",
            "Keyboard height updated: ${keyboardHeightPx}px"
        )
    }
    override fun onCreateInputView(): android.view.View {
        val lastDp = getSafeFloatPref(
            "flutter.native_last_keyboard_height_dp",
            460f
        ).toDouble()

        val density = resources.displayMetrics.density
        updateKeyboardHeightPx((lastDp * density).toInt())
        keyboardHeightPx = (lastDp * density).toInt()

        if (containerView != null && flutterView != null) {
            (flutterView?.parent as? ViewGroup)?.removeView(flutterView)
            (containerView?.parent as? ViewGroup)?.removeView(containerView)
        }

        val container = containerView ?: android.widget.FrameLayout(this).also { containerView = it }
        container.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        container.isFocusable = true
        container.isFocusableInTouchMode = true

        if (flutterView == null) {
            val textureView = io.flutter.embedding.android.FlutterTextureView(this)
            val fView = io.flutter.embedding.android.FlutterView(this, textureView)
            flutterView = fView
            fView.attachToFlutterEngine(flutterEngine!!)
            fView.isFocusable = true
            fView.isFocusableInTouchMode = true
        } else {
            (flutterView?.parent as? ViewGroup)?.removeView(flutterView)
        }

        if (flutterView?.parent == null) {
            val params = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            params.gravity = android.view.Gravity.BOTTOM
            container.addView(flutterView, params)
            container.addOnLayoutChangeListener {
                    view, left, top, right, bottom,
                    _, _, _, _ ->

                Log.d(
                    "QuantaKeysIME",
                    "CONTAINER: ${right - left} x ${bottom - top}"
                )

                Log.d(
                    "QuantaKeysIME",
                    "FLUTTER VIEW: ${flutterView?.width} x ${flutterView?.height}"
                )
            }
        }

        val containerParams = android.widget.FrameLayout.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            keyboardHeightPx
        )
        container.layoutParams = containerParams

        return container
    }

    override fun onComputeInsets(outInsets: InputMethodService.Insets) {
        super.onComputeInsets(outInsets)
        outInsets.contentTopInsets = 0
        outInsets.visibleTopInsets = 0
        outInsets.touchableInsets = InputMethodService.Insets.TOUCHABLE_INSETS_CONTENT
        android.util.Log.d("QuantaKeysIME", "onComputeInsets: contentTopInsets=0, keyboardHeightPx=$keyboardHeightPx")
    }

    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onDestroy() {
        try {
            flutterView?.detachFromFlutterEngine()
            flutterView = null
        } catch (_: Exception) {}

        try {
            containerView?.removeAllViews()
            containerView = null
        } catch (_: Exception) {}

        try {
            flutterEngine?.destroy()
            flutterEngine = null
        } catch (_: Exception) {}

        super.onDestroy()
    }
}
