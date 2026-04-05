package com.petalgemini.gemini

import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.*
import com.petalgemini.db.ConversationEntity

/**
 * Módulo 4 — Integración Gemini API
 *
 * Usa Gemini 1.5 Flash — el más rápido y barato.
 * - System prompt: respuestas concisas para smartwatch (1-2 oraciones)
 * - Temperatura: 0.7 para respuestas naturales pero consistentes
 * - Max output tokens: 100 (suficiente para 2 oraciones)
 * - La API key vive solo en el teléfono, nunca en el reloj
 */
class GeminiClient(apiKey: String) {

    private val model = GenerativeModel(
        modelName = "gemini-1.5-flash",
        apiKey = apiKey,
        generationConfig = generationConfig {
            temperature = 0.7f
            maxOutputTokens = 100
            topP = 0.95f
        },
        systemInstruction = content {
            text(SYSTEM_PROMPT)
        }
    )

    /**
     * Envía una query a Gemini con contexto de conversación previa.
     *
     * @param query El texto del usuario
     * @param recentHistory Los últimos 3 intercambios para dar contexto
     * @param contextInfo Información adicional (hora, ubicación GPS)
     * @return Texto de respuesta de Gemini
     */
    suspend fun ask(
        query: String,
        recentHistory: List<ConversationEntity> = emptyList(),
        contextInfo: String? = null
    ): Result<String> {
        return try {
            val chat = model.startChat(
                history = buildHistory(recentHistory, contextInfo)
            )

            val response = chat.sendMessage(query)
            val text = response.text?.trim()

            if (text.isNullOrEmpty()) {
                Result.failure(Exception("Respuesta vacía de Gemini"))
            } else {
                Result.success(text)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Construye el historial de conversación para dar contexto a Gemini.
     * Incluye los últimos 3 intercambios previos + info contextual.
     */
    private fun buildHistory(
        recentHistory: List<ConversationEntity>,
        contextInfo: String?
    ): List<Content> {
        val history = mutableListOf<Content>()

        // Inyectar contexto actual si está disponible
        if (!contextInfo.isNullOrEmpty()) {
            history.add(content(role = "user") { text("[Contexto: $contextInfo]") })
            history.add(content(role = "model") { text("Entendido, usaré ese contexto.") })
        }

        // Añadir historial previo (ordenado cronológicamente)
        for (entry in recentHistory.reversed()) {
            history.add(content(role = "user") { text(entry.query) })
            history.add(content(role = "model") { text(entry.response) })
        }

        return history
    }

    companion object {
        private const val SYSTEM_PROMPT = """
            Eres un asistente conciso para smartwatch llamado PetalGemini.
            Reglas estrictas:
            - Responde siempre en 1-2 oraciones cortas
            - No uses listas, viñetas ni markdown
            - No uses emojis
            - Formatea números de forma compacta: "23°C" no "23 grados Celsius", "8km" no "8 kilómetros"
            - Si te dan contexto de ubicación u hora, úsalo sin mencionarlo explícitamente
            - Si te piden recordatorios, responde confirmando la hora y el recordatorio
            - Responde en el mismo idioma que te hablen
        """
    }
}
