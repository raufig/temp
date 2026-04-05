package com.petalgemini.ble

import android.content.Context
import android.util.Log
import com.huawei.wearengine.HiWear
import com.huawei.wearengine.device.DeviceClient
import com.huawei.wearengine.p2p.Message
import com.huawei.wearengine.p2p.P2pClient
import com.huawei.wearengine.p2p.Receiver
import org.json.JSONObject

/**
 * Módulo 2 — Wear Engine Bridge (lado teléfono)
 *
 * Escucha mensajes del reloj por el canal BLE /petalgemini/query
 * y envía respuestas de vuelta.
 */
class WearBridge(private val context: Context) {

    companion object {
        private const val TAG = "WearBridge"
        private const val CHANNEL_PATH = "/petalgemini/query"
    }

    private var p2pClient: P2pClient? = null
    private var deviceClient: DeviceClient? = null
    private var queryListener: ((query: String, timestamp: Long) -> Unit)? = null

    /**
     * Inicia la escucha de mensajes del reloj.
     */
    fun startListening() {
        try {
            p2pClient = HiWear.getP2pClient(context)
            deviceClient = HiWear.getDeviceClient(context)

            val receiver = object : Receiver {
                override fun onReceiveMessage(message: Message) {
                    handleMessage(message)
                }
            }

            p2pClient?.registerReceiver(receiver)
                ?.addOnSuccessListener {
                    Log.i(TAG, "Receptor BLE registrado en canal $CHANNEL_PATH")
                }
                ?.addOnFailureListener { e ->
                    Log.e(TAG, "Error registrando receptor BLE", e)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Error iniciando WearBridge", e)
        }
    }

    /**
     * Envía una respuesta al reloj.
     */
    fun sendResponse(responseText: String, timestamp: Long, error: String? = null) {
        try {
            val json = JSONObject().apply {
                put("r", responseText)
                put("ts", timestamp)
                if (error != null) put("err", error)
            }

            deviceClient?.connectedDevices
                ?.addOnSuccessListener { devices ->
                    if (devices.isEmpty()) {
                        Log.w(TAG, "No hay dispositivos conectados para enviar respuesta")
                        return@addOnSuccessListener
                    }

                    val message = Message.Builder()
                        .setPayload(json.toString().toByteArray())
                        .build()

                    val device = devices[0]
                    p2pClient?.send(device, message)
                        ?.addOnSuccessListener {
                            Log.i(TAG, "Respuesta enviada al reloj (ts=$timestamp)")
                        }
                        ?.addOnFailureListener { e ->
                            Log.e(TAG, "Error enviando respuesta al reloj", e)
                        }
                }
                ?.addOnFailureListener { e ->
                    Log.e(TAG, "Error obteniendo dispositivos", e)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Error en sendResponse", e)
        }
    }

    /**
     * Registra callback para queries recibidas del reloj.
     */
    fun onQuery(listener: (query: String, timestamp: Long) -> Unit) {
        this.queryListener = listener
    }

    fun stopListening() {
        try {
            p2pClient?.unregisterReceiver()
            Log.i(TAG, "Receptor BLE desregistrado")
        } catch (e: Exception) {
            Log.e(TAG, "Error deteniendo WearBridge", e)
        }
    }

    private fun handleMessage(message: Message) {
        try {
            val data = String(message.data)
            val json = JSONObject(data)
            val query = json.getString("q")
            val timestamp = json.getLong("ts")

            Log.i(TAG, "Query recibida del reloj: '$query' (ts=$timestamp)")
            queryListener?.invoke(query, timestamp)
        } catch (e: Exception) {
            Log.e(TAG, "Error parseando mensaje del reloj", e)
        }
    }
}
