package com.petalgemini.service

import android.app.*
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.petalgemini.MainActivity
import com.petalgemini.R
import com.petalgemini.ble.WearBridge
import com.petalgemini.db.ConversationDatabase
import com.petalgemini.db.ConversationEntity
import com.petalgemini.gemini.GeminiClient
import com.petalgemini.util.ContextProvider
import com.petalgemini.util.ResponseFormatter
import kotlinx.coroutines.*

/**
 * Módulo 3 — Phone Service (el cerebro)
 *
 * ForegroundService que:
 * 1. Escucha queries del reloj via BLE continuamente
 * 2. Construye prompts con contexto (hora, GPS, historial últimos 3 mensajes)
 * 3. Llama a Gemini 1.5 Flash
 * 4. Formatea y envía respuesta de vuelta al reloj
 * 5. Guarda en Room DB para historial con memoria
 *
 * Manejo de errores: reintento automático una vez si falla la red.
 */
class PetalGeminiService : Service() {

    companion object {
        private const val TAG = "PetalGeminiService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "petalgemini_service"
        private const val API_KEY_PREF = "gemini_api_key"
    }

    private lateinit var wearBridge: WearBridge
    private lateinit var database: ConversationDatabase
    private var geminiClient: GeminiClient? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "PetalGemini Service creado")

        database = ConversationDatabase.getInstance(this)
        wearBridge = WearBridge(this)

        // Cargar API key desde SharedPreferences
        val prefs = getSharedPreferences("petalgemini", MODE_PRIVATE)
        val apiKey = prefs.getString(API_KEY_PREF, null)
        if (apiKey != null) {
            geminiClient = GeminiClient(apiKey)
        } else {
            Log.w(TAG, "API key de Gemini no configurada")
        }

        // Registrar listener de queries del reloj
        wearBridge.onQuery { query, timestamp ->
            handleQuery(query, timestamp)
        }

        wearBridge.startListening()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        wearBridge.stopListening()
        serviceScope.cancel()
        Log.i(TAG, "PetalGemini Service destruido")
    }

    /**
     * Procesa una query recibida del reloj.
     * Flujo: contexto → Gemini → formato → enviar respuesta → guardar historial
     */
    private fun handleQuery(query: String, timestamp: Long) {
        serviceScope.launch {
            Log.i(TAG, "Procesando query: '$query'")

            // Comando especial: limpiar historial
            if (query.lowercase().trim() == "olvida todo") {
                database.conversationDao().clearAll()
                wearBridge.sendResponse("Historial borrado", timestamp)
                return@launch
            }

            val client = geminiClient
            if (client == null) {
                wearBridge.sendResponse(
                    ResponseFormatter.errorMessage(ResponseFormatter.ErrorType.UNKNOWN),
                    timestamp,
                    error = "no_api_key"
                )
                return@launch
            }

            try {
                // Obtener historial para contexto
                val recentHistory = database.conversationDao().getLastThree()

                // Obtener contexto ambiental (hora, GPS)
                val contextInfo = withContext(Dispatchers.Main) {
                    ContextProvider.buildContext(this@PetalGeminiService)
                }

                // Llamar a Gemini (con un reintento si falla)
                val result = client.ask(query, recentHistory, contextInfo)

                val responseText = result.getOrElse { firstError ->
                    Log.w(TAG, "Primer intento falló, reintentando...", firstError)
                    delay(1000) // Esperar 1 segundo antes de reintentar

                    client.ask(query, recentHistory, contextInfo).getOrElse { secondError ->
                        Log.e(TAG, "Segundo intento también falló", secondError)
                        val errorType = classifyError(secondError)
                        wearBridge.sendResponse(
                            ResponseFormatter.errorMessage(errorType),
                            timestamp,
                            error = errorType.name.lowercase()
                        )
                        return@launch
                    }
                }

                // Formatear para pantalla del reloj
                val formatted = ResponseFormatter.formatForWatch(responseText)

                // Enviar al reloj
                wearBridge.sendResponse(formatted, timestamp)

                // Guardar en historial
                database.conversationDao().insert(
                    ConversationEntity(
                        query = query,
                        response = formatted,
                        timestamp = timestamp
                    )
                )
                database.conversationDao().pruneOld()

                Log.i(TAG, "Respuesta enviada: '$formatted'")

            } catch (e: Exception) {
                Log.e(TAG, "Error procesando query", e)
                val errorType = classifyError(e)
                wearBridge.sendResponse(
                    ResponseFormatter.errorMessage(errorType),
                    timestamp,
                    error = errorType.name.lowercase()
                )
            }
        }
    }

    private fun classifyError(error: Throwable): ResponseFormatter.ErrorType {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("timeout") || message.contains("timed out") ->
                ResponseFormatter.ErrorType.TIMEOUT
            message.contains("network") || message.contains("connect") || message.contains("unreachable") ->
                ResponseFormatter.ErrorType.NO_INTERNET
            message.contains("429") || message.contains("quota") || message.contains("rate") ->
                ResponseFormatter.ErrorType.GEMINI_UNAVAILABLE
            else -> ResponseFormatter.ErrorType.UNKNOWN
        }
    }

    private fun createNotification(): Notification {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PetalGemini Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Mantiene la conexión con tu reloj Huawei"
        }
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PetalGemini")
            .setContentText("Escuchando a tu reloj")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
