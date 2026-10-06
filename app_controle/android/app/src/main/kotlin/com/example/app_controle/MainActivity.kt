package com.example.app_controle

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.appcontrole/app_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // ---------- Listar aplicativos instalados ----------
                "getInstalledApps" -> {
                    try {
                        val pm = packageManager
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }
                        val apps = pm.queryIntentActivities(intent, 0)
                            .mapNotNull { resolveInfo ->
                                try {
                                    val appInfo = resolveInfo.activityInfo.applicationInfo
                                    val icon = appInfo.loadIcon(pm)

                                    // Converte o Drawable em PNG (bytes)
                                    val bitmap = android.graphics.Bitmap.createBitmap(
                                        icon.intrinsicWidth.coerceAtLeast(1),
                                        icon.intrinsicHeight.coerceAtLeast(1),
                                        android.graphics.Bitmap.Config.ARGB_8888
                                    )
                                    val canvas = android.graphics.Canvas(bitmap)
                                    icon.setBounds(0, 0, canvas.width, canvas.height)
                                    icon.draw(canvas)

                                    val stream = java.io.ByteArrayOutputStream()
                                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                                    val iconBytes = stream.toByteArray()

                                    mapOf(
                                        "appName" to resolveInfo.loadLabel(pm).toString(),
                                        "packageName" to resolveInfo.activityInfo.packageName,
                                        "icon" to iconBytes
                                    )
                                } catch (e: Exception) {
                                    null
                                }
                            }
                            .filter { it["packageName"] != packageName }
                            .sortedBy { it["appName"] as String }
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("GET_APPS_ERROR", e.message, null)
                    }
                }

                // ---------- Receber regras do Flutter ----------
                "setRules" -> {
                    val json = call.argument<String>("rules") ?: "[]"
                    AppBlockingService.rulesJson = json
                    // Persiste em SharedPreferences nativo para sobreviver ao restart do serviço
                    getSharedPreferences("app_blocking", MODE_PRIVATE)
                        .edit()
                        .putString("rules_json", json)
                        .apply()
                    android.util.Log.d("MainActivity", "Regras salvas: $json")
                    result.success(true)
                }

                // ---------- Permissão de acessibilidade ----------
                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                // ---------- Permissão de overlay ----------
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "$packageName/${AppBlockingService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(":").any { it.equals(service, ignoreCase = true) }
    }
}