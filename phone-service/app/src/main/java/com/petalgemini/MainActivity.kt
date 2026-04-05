package com.petalgemini

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.petalgemini.databinding.ActivityMainBinding
import com.petalgemini.db.ConversationDatabase
import com.petalgemini.service.PetalGeminiService
import kotlinx.coroutines.*

/**
 * Activity principal del teléfono.
 * Configura la API key, muestra estado del servicio, y lista el historial.
 */
class MainActivity : AppCompatActivity() {

    companion object {
        private const val PERMISSION_REQUEST_CODE = 100
        private const val PREFS_NAME = "petalgemini"
        private const val API_KEY_PREF = "gemini_api_key"
    }

    private lateinit var binding: ActivityMainBinding
    private lateinit var database: ConversationDatabase
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        database = ConversationDatabase.getInstance(this)

        setupUI()
        requestPermissions()
    }

    override fun onResume() {
        super.onResume()
        loadHistory()
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }

    private fun setupUI() {
        // Cargar API key existente
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val existingKey = prefs.getString(API_KEY_PREF, "") ?: ""
        binding.editApiKey.setText(existingKey)

        // Botón guardar API key e iniciar servicio
        binding.btnSaveAndStart.setOnClickListener {
            val apiKey = binding.editApiKey.text.toString().trim()
            if (apiKey.isEmpty()) {
                Toast.makeText(this, "Ingresa tu API key de Google AI Studio", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            prefs.edit().putString(API_KEY_PREF, apiKey).apply()
            startPetalService()
            Toast.makeText(this, "Servicio iniciado — escuchando al reloj", Toast.LENGTH_SHORT).show()
        }

        // Botón detener servicio
        binding.btnStop.setOnClickListener {
            stopService(Intent(this, PetalGeminiService::class.java))
            Toast.makeText(this, "Servicio detenido", Toast.LENGTH_SHORT).show()
        }

        // Botón limpiar historial
        binding.btnClearHistory.setOnClickListener {
            scope.launch {
                withContext(Dispatchers.IO) {
                    database.conversationDao().clearAll()
                }
                loadHistory()
                Toast.makeText(this@MainActivity, "Historial borrado", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun startPetalService() {
        val intent = Intent(this, PetalGeminiService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }

    private fun loadHistory() {
        scope.launch {
            val entries = withContext(Dispatchers.IO) {
                database.conversationDao().getRecent(10)
            }

            if (entries.isEmpty()) {
                binding.textHistory.text = "Sin historial de conversaciones"
            } else {
                val sb = StringBuilder()
                for (entry in entries) {
                    sb.appendLine("Tú: ${entry.query}")
                    sb.appendLine("Gemini: ${entry.response}")
                    sb.appendLine("---")
                }
                binding.textHistory.text = sb.toString()
            }
        }
    }

    private fun requestPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val needed = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), PERMISSION_REQUEST_CODE)
        }
    }
}
