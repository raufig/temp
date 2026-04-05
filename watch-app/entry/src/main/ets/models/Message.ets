/**
 * Modelo de mensaje intercambiado entre reloj y teléfono.
 * El formato JSON viaja por BLE como string.
 */
export interface QueryMessage {
  q: string;       // texto de la pregunta del usuario
  ts: number;      // timestamp para evitar duplicados
}

export interface ResponseMessage {
  r: string;       // texto de respuesta de Gemini
  ts: number;      // timestamp correspondiente a la query
  err?: string;    // código de error si hubo fallo
}

export interface ConversationEntry {
  query: string;
  response: string;
  timestamp: number;
}

export enum AppState {
  IDLE = 'idle',
  LISTENING = 'listening',
  PROCESSING = 'processing',
  DISPLAYING = 'displaying',
  ERROR = 'error'
}

export enum ErrorCode {
  NO_BLE = 'no_ble',
  NO_INTERNET = 'no_internet',
  GEMINI_UNAVAILABLE = 'gemini_unavailable',
  TIMEOUT = 'timeout',
  STT_FAILED = 'stt_failed'
}

export function errorToUserMessage(code: ErrorCode): string {
  switch (code) {
    case ErrorCode.NO_BLE:
      return 'Sin conexión al teléfono';
    case ErrorCode.NO_INTERNET:
      return 'Sin internet';
    case ErrorCode.GEMINI_UNAVAILABLE:
      return 'Gemini no disponible';
    case ErrorCode.TIMEOUT:
      return 'Tiempo agotado';
    case ErrorCode.STT_FAILED:
      return 'No entendí, intenta de nuevo';
    default:
      return 'Intenta de nuevo';
  }
}
