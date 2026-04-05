/**
 * Cache local en el reloj para respuestas frecuentes.
 * Permite responder las últimas 5 preguntas comunes sin conexión BLE.
 * Usa almacenamiento ligero de HarmonyOS (Preferences).
 */
import dataPreferences from '@ohos.data.preferences';
import { ConversationEntry } from '../models/Message';
import common from '@ohos.app.ability.common';

const PREFERENCES_NAME = 'petalgemini_cache';
const CACHE_KEY = 'cached_responses';
const MAX_CACHED = 5;

export class CacheService {
  private preferences: dataPreferences.Preferences | null = null;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    try {
      this.preferences = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
    } catch (error) {
      console.error(`[CacheService] Error inicializando: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Guarda un intercambio en el cache local del reloj.
   * Mantiene solo las últimas MAX_CACHED entradas.
   */
  async cacheResponse(entry: ConversationEntry): Promise<void> {
    if (!this.preferences) return;

    try {
      const cached = await this.getCachedResponses();
      cached.push(entry);

      // Mantener solo las últimas 5
      while (cached.length > MAX_CACHED) {
        cached.shift();
      }

      await this.preferences.put(CACHE_KEY, JSON.stringify(cached));
      await this.preferences.flush();
    } catch (error) {
      console.error(`[CacheService] Error guardando cache: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Busca en el cache una respuesta similar a la query.
   * Usa coincidencia simple por inclusión de palabras clave.
   */
  async findCachedResponse(query: string): Promise<string | null> {
    const cached = await this.getCachedResponses();
    const queryLower = query.toLowerCase().trim();

    for (const entry of cached.reverse()) {
      const cachedQuery = entry.query.toLowerCase().trim();
      if (cachedQuery === queryLower || queryLower.includes(cachedQuery) || cachedQuery.includes(queryLower)) {
        // Solo usar cache si tiene menos de 1 hora
        const ageMs = Date.now() - entry.timestamp;
        if (ageMs < 3600000) {
          return entry.response;
        }
      }
    }

    return null;
  }

  async getCachedResponses(): Promise<ConversationEntry[]> {
    if (!this.preferences) return [];

    try {
      const data = await this.preferences.get(CACHE_KEY, '[]') as string;
      return JSON.parse(data) as ConversationEntry[];
    } catch {
      return [];
    }
  }

  async clearCache(): Promise<void> {
    if (!this.preferences) return;

    try {
      await this.preferences.delete(CACHE_KEY);
      await this.preferences.flush();
    } catch (error) {
      console.error(`[CacheService] Error limpiando cache: ${JSON.stringify(error)}`);
    }
  }
}
