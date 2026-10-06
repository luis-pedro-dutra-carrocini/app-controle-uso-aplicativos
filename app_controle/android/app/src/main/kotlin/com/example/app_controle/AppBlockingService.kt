package com.example.app_controle

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray
import android.os.Build

class AppBlockingService : AccessibilityService() {

    companion object {
        var currentForegroundPackage: String? = null
        var rulesJson: String = "[]"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            return
        }

        // Verifica qual é a janela REALMENTE ativa agora
        val activePackage = getActiveWindowPackage()
        android.util.Log.d("AppBlocking", "Evento: ${event.packageName} | janela ativa: $activePackage")

        if (activePackage == null) {
            // Sem janela ativa clara → esconde o overlay para não prender o usuário
            hideBlockOverlay()
            return
        }

        // Ignora pacotes do sistema (systemui, launcher, settings, etc.)
        if (isSystemPackage(activePackage)) {
            hideBlockOverlay()
            return
        }

        // Ignora o próprio app de controle
        if (activePackage == packageName) {
            hideBlockOverlay()
            return
        }

        currentForegroundPackage = activePackage

        val blocked = isBlocked(activePackage)
        android.util.Log.d("AppBlocking", "isBlocked($activePackage) = $blocked")

        if (blocked) {
            showBlockOverlay(activePackage)
        } else {
            hideBlockOverlay()
        }
    }

    /// Retorna o packageName da janela atualmente ativa
    private fun getActiveWindowPackage(): String? {
        return try {
            val windowsList = windows ?: return null
            if (windowsList.isEmpty()) return null
            val active = windowsList.firstOrNull { it.isActive } ?: windowsList.first()
            active.root?.packageName?.toString()
        } catch (e: Exception) {
            android.util.Log.e("AppBlocking", "Erro ao obter janela ativa: ${e.message}")
            null
        }
    }

    private fun isSystemPackage(pkg: String): Boolean {
        return pkg == "com.android.systemui" ||
            pkg == "com.android.settings" ||
            pkg == "android" ||
            pkg == "com.samsung.android.app.aodservice" ||
            pkg.contains("launcher") ||
            pkg.contains("systemui") ||
            pkg.contains("permissioncontroller")
    }

    private fun isBlocked(pkg: String): Boolean {
        // Proteção extra: nunca bloqueia pacotes do sistema
        if (isSystemPackage(pkg)) return false

        if (rulesJson.isEmpty() || rulesJson == "[]") {
            android.util.Log.d("AppBlocking", "Sem regras carregadas (rulesJson vazio)")
            return false
        }
        try {
            val rules = JSONArray(rulesJson)
            android.util.Log.d("AppBlocking", "Verificando $pkg contra ${rules.length()} regras")
            for (i in 0 until rules.length()) {
                val rule = rules.getJSONObject(i)
                if (rule.getString("packageName") != pkg) continue

                val schedules = rule.getJSONArray("schedules")
                android.util.Log.d("AppBlocking", "Regra encontrada para $pkg com ${schedules.length()} schedule(s)")
                for (j in 0 until schedules.length()) {
                    val s = schedules.getJSONObject(j)
                    val within = isWithinSchedule(s)
                    android.util.Log.d("AppBlocking", "Schedule $j dentro? $within")
                    if (within) return false
                }
                return true
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlocking", "Erro ao parsear regras: ${e.message}")
        }
        return false
    }

    private fun hideBlockOverlayIfNeeded() {
        // Se o app atual ainda é o que estava bloqueado, não esconde.
        // Só esconde quando o app permitido ou sem regra assume o primeiro plano.
        val intent = Intent(this, BlockOverlayService::class.java)
        stopService(intent)
    }

    private fun isWithinSchedule(schedule: org.json.JSONObject): Boolean {
        val cal = java.util.Calendar.getInstance()
        val today = cal.get(java.util.Calendar.DAY_OF_WEEK) // 1=Dom, 2=Seg...

        // Converte para 1=Seg...7=Dom (igual ao app)
        val day = if (today == java.util.Calendar.SUNDAY) 7 else today - 1

        val weekdays = schedule.getJSONArray("weekdays")
        var dayOk = false
        for (k in 0 until weekdays.length()) {
            if (weekdays.getInt(k) == day) { dayOk = true; break }
        }
        if (!dayOk) return false

        val nowMinutes = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
                cal.get(java.util.Calendar.MINUTE)

        val start = parseTime(schedule.getString("start"))
        val end = parseTime(schedule.getString("end"))

        return if (start <= end) {
            nowMinutes in start until end
        } else {
            // Atravessa meia-noite
            nowMinutes >= start || nowMinutes < end
        }
    }

    private fun parseTime(t: String): Int {
        val parts = t.split(":")
        return parts[0].toInt() * 60 + parts[1].toInt()
    }

    private fun showBlockOverlay(pkg: String) {
        if (BlockOverlayService.isOverlayVisible &&
            BlockOverlayService.currentBlockedPackage == pkg) {
            return
        }

        val intent = Intent(this, BlockOverlayService::class.java).apply {
            putExtra("blockedPackage", pkg)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlocking", "Erro ao iniciar overlay: ${e.message}")
        }
    }

    private fun hideBlockOverlay() {
        if (!BlockOverlayService.isOverlayVisible) return
        val intent = Intent(this, BlockOverlayService::class.java)
        stopService(intent)
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Relê as regras persistidas (sobrevive a kill do serviço)
        val prefs = getSharedPreferences("app_blocking", MODE_PRIVATE)
        val saved = prefs.getString("rules_json", null)
        if (!saved.isNullOrEmpty()) {
            rulesJson = saved
        }
        android.util.Log.d("AppBlocking", "Serviço conectado. Regras carregadas: $rulesJson")
    }
}