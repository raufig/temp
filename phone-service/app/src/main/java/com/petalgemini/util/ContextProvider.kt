package com.petalgemini.util

import android.annotation.SuppressLint
import android.content.Context
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Provee información contextual para enriquecer los prompts a Gemini.
 * Incluye: hora actual, día de la semana, ubicación GPS si está disponible.
 */
object ContextProvider {

    /**
     * Construye un string de contexto con la información disponible.
     * Ejemplo: "Son las 14:30 del martes. Ubicación: 19.43°N, 99.13°W"
     */
    @SuppressLint("MissingPermission")
    fun buildContext(context: Context): String {
        val parts = mutableListOf<String>()

        // Hora y día
        val dateFormat = SimpleDateFormat("EEEE, HH:mm", Locale("es"))
        parts.add("Son las ${dateFormat.format(Date())}")

        // Ubicación GPS (si está disponible)
        try {
            val fusedClient = LocationServices.getFusedLocationProviderClient(context)
            val locationTask = fusedClient.getCurrentLocation(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                null
            )
            val location = Tasks.await(locationTask, 3, TimeUnit.SECONDS)
            if (location != null) {
                parts.add(
                    "Ubicación: %.2f°%s, %.2f°%s".format(
                        Math.abs(location.latitude),
                        if (location.latitude >= 0) "N" else "S",
                        Math.abs(location.longitude),
                        if (location.longitude >= 0) "E" else "W"
                    )
                )
            }
        } catch (_: Exception) {
            // GPS no disponible — no es crítico, continuamos sin ubicación
        }

        return parts.joinToString(". ")
    }
}
