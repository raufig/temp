package com.petalgemini.util

/**
 * Módulo 5 — Resumen y formato para el reloj
 *
 * Trunca respuestas respetando palabras completas (máx 200 chars).
 * Formatea números compactos y maneja mensajes de error predefinidos.
 */
object ResponseFormatter {

    private const val MAX_LENGTH = 200

    /**
     * Trunca el texto a MAX_LENGTH caracteres respetando palabras completas.
     * No corta a mitad de palabra.
     */
    fun truncate(text: String, maxLength: Int = MAX_LENGTH): String {
        if (text.length <= maxLength) return text

        val truncated = text.substring(0, maxLength)
        val lastSpace = truncated.lastIndexOf(' ')

        return if (lastSpace > maxLength / 2) {
            truncated.substring(0, lastSpace) + "…"
        } else {
            truncated + "…"
        }
    }

    /**
     * Formatea números para pantalla pequeña:
     * - "23 grados Celsius" → "23°C"
     * - "8 kilómetros" → "8km"
     * - "5 millas" → "5mi"
     * - "1.609 kilómetros" → "1.6km"
     */
    fun compactNumbers(text: String): String {
        var result = text
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*grados?\\s*[Cc]elsius"), "$1°C")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*grados?\\s*[Ff]ahrenheit"), "$1°F")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*kilómetros?"), "$1km")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*metros?\\b"), "$1m")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*millas?"), "$1mi")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*por\\s*ciento"), "$1%")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*kilogramos?"), "$1kg")
        result = result.replace(Regex("(\\d+(?:\\.\\d+)?)\\s*libras?"), "$1lb")
        return result
    }

    /**
     * Pipeline completo de formateo para enviar al reloj.
     */
    fun formatForWatch(text: String): String {
        val compacted = compactNumbers(text.trim())
        return truncate(compacted)
    }

    /**
     * Mensajes de error predefinidos y cortos para el reloj.
     */
    fun errorMessage(type: ErrorType): String {
        return when (type) {
            ErrorType.NO_INTERNET -> "Sin internet"
            ErrorType.GEMINI_UNAVAILABLE -> "Gemini no disponible"
            ErrorType.TIMEOUT -> "Tiempo agotado"
            ErrorType.UNKNOWN -> "Intenta de nuevo"
        }
    }

    enum class ErrorType {
        NO_INTERNET,
        GEMINI_UNAVAILABLE,
        TIMEOUT,
        UNKNOWN
    }
}
