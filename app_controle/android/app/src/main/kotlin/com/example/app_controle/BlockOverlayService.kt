package com.example.app_controle

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.view.WindowInsets

class BlockOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    companion object {
        private const val CHANNEL_ID = "block_overlay_channel"
        private const val NOTIFICATION_ID = 1001
        var currentBlockedPackage: String? = null
        var isOverlayVisible: Boolean = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("BlockOverlay", "onStartCommand chamado")

        // Torna-se foreground imediatamente
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        if (!android.provider.Settings.canDrawOverlays(this)) {
            android.util.Log.e("BlockOverlay", "SEM PERMISSÃO DE OVERLAY — abortando")
            stopSelf()
            return START_NOT_STICKY
        }

        val blockedPackage = intent?.getStringExtra("blockedPackage")
        if (blockedPackage == null) {
            android.util.Log.e("BlockOverlay", "blockedPackage nulo")
            stopSelf()
            return START_NOT_STICKY
        }

        android.util.Log.d("BlockOverlay", "Exibindo overlay para $blockedPackage")

        // Sempre chama showOverlay — ele mesmo decide se cria ou só atualiza
        try {
            showOverlay(blockedPackage)
            android.util.Log.d("BlockOverlay", "Overlay garantido para $blockedPackage")
        } catch (e: Exception) {
            android.util.Log.e("BlockOverlay", "Erro ao adicionar overlay: ${e.message}")
            e.printStackTrace()
        }

        return START_STICKY
    }

    private fun showOverlay(blockedPackage: String) {
        if (overlayView != null) {
            overlayView?.findViewById<TextView>(R.id.overlay_text)?.text =
                "Aplicativo bloqueado\n\n$blockedPackage"
            currentBlockedPackage = blockedPackage
            isOverlayVisible = true
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.overlay_block, null)

        view.findViewById<TextView>(R.id.overlay_text)?.text =
            "Aplicativo bloqueado\n\n$blockedPackage"

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager?.addView(view, params)
            overlayView = view
            currentBlockedPackage = blockedPackage
            isOverlayVisible = true
            android.util.Log.d("BlockOverlay", "Overlay adicionado")
        } catch (e: Exception) {
            android.util.Log.e("BlockOverlay", "Erro ao adicionar overlay: ${e.message}")
        }
    }

    private fun getStatusBarHeight(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else 0
    }

    private fun getNavigationBarHeight(): Int {
        val id = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        val fromRes = if (id > 0) resources.getDimensionPixelSize(id) else 0
        if (fromRes > 0) return fromRes
        // Fallback para navigation bar gestual (~48dp)
        return (48 * resources.displayMetrics.density).toInt()
    }

    override fun onDestroy() {
        overlayView?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
        }
        overlayView = null
        isOverlayVisible = false
        currentBlockedPackage = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bloqueio de aplicativos",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Controle de Apps")
            .setContentText("Aplicativo bloqueado no momento")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()
    }
}