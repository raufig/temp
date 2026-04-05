/**
 * Módulo 1 — Input en el GT 6 (STT/TTS)
 *
 * Maneja Speech-to-Text y Text-to-Speech nativos de HarmonyOS.
 * STT: máximo 8 segundos de grabación para conservar batería.
 * TTS: lee respuestas en voz alta opcionalmente.
 */
import speechRecognizer from '@ohos.ai.speechRecognizer';
import textToSpeech from '@ohos.ai.textToSpeech';

const MAX_RECORDING_MS = 8000;

type SttResultCallback = (text: string) => void;
type SttErrorCallback = (error: string) => void;
type SttStateCallback = (listening: boolean) => void;

export class SpeechService {
  private sttEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private recordingTimer: number | null = null;
  private isListening: boolean = false;

  private sttResultCallback: SttResultCallback | null = null;
  private sttErrorCallback: SttErrorCallback | null = null;
  private sttStateCallback: SttStateCallback | null = null;

  /**
   * Inicializa los motores STT y TTS.
   */
  async initialize(): Promise<void> {
    try {
      const sttParams: speechRecognizer.CreateEngineParams = {
        language: 'es-ES',
        online: 0 // offline para menor latencia
      };
      this.sttEngine = await speechRecognizer.createEngine(sttParams);

      const ttsParams: textToSpeech.CreateEngineParams = {
        language: 'es-ES',
        person: 0
      };
      this.ttsEngine = await textToSpeech.createEngine(ttsParams);
    } catch (error) {
      console.error(`[SpeechService] Error inicializando: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Inicia el reconocimiento de voz.
   * Se detiene automáticamente después de MAX_RECORDING_MS (8 segundos).
   */
  async startListening(): Promise<void> {
    if (this.isListening || !this.sttEngine) {
      return;
    }

    this.isListening = true;
    this.notifyStateChange(true);

    try {
      this.sttEngine.on('result', (result: speechRecognizer.SpeechRecognitionResult) => {
        if (result.isFinal && result.result) {
          this.stopListening();
          if (this.sttResultCallback) {
            this.sttResultCallback(result.result);
          }
        }
      });

      this.sttEngine.on('error', (error: number) => {
        this.stopListening();
        if (this.sttErrorCallback) {
          this.sttErrorCallback(`STT error: ${error}`);
        }
      });

      const recognitionParams: speechRecognizer.StartParams = {
        vadBegin: 2000,
        vadEnd: 3000,
        maxAudioDuration: MAX_RECORDING_MS
      };

      await this.sttEngine.startListening(recognitionParams);

      // Timer de seguridad: cortar a los 8 segundos máximo
      this.recordingTimer = setTimeout(() => {
        if (this.isListening) {
          this.stopListening();
        }
      }, MAX_RECORDING_MS) as unknown as number;
    } catch (error) {
      this.isListening = false;
      this.notifyStateChange(false);
      console.error(`[SpeechService] Error al iniciar STT: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Detiene el reconocimiento de voz manualmente.
   */
  async stopListening(): Promise<void> {
    if (!this.isListening) {
      return;
    }

    if (this.recordingTimer !== null) {
      clearTimeout(this.recordingTimer);
      this.recordingTimer = null;
    }

    this.isListening = false;
    this.notifyStateChange(false);

    try {
      if (this.sttEngine) {
        await this.sttEngine.finish();
      }
    } catch (error) {
      console.error(`[SpeechService] Error al detener STT: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Lee texto en voz alta usando TTS nativo.
   */
  async speak(text: string): Promise<void> {
    if (!this.ttsEngine) {
      return;
    }

    try {
      const speakParams: textToSpeech.SpeakParams = {
        requestId: `tts_${Date.now()}`,
        extraParams: { speed: 1.0, volume: 1.0, pitch: 1.0 }
      };
      await this.ttsEngine.speak(text, speakParams);
    } catch (error) {
      console.error(`[SpeechService] Error TTS: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Detiene la reproducción TTS actual.
   */
  async stopSpeaking(): Promise<void> {
    try {
      if (this.ttsEngine) {
        await this.ttsEngine.stop();
      }
    } catch (error) {
      console.error(`[SpeechService] Error al detener TTS: ${JSON.stringify(error)}`);
    }
  }

  onResult(callback: SttResultCallback): void {
    this.sttResultCallback = callback;
  }

  onError(callback: SttErrorCallback): void {
    this.sttErrorCallback = callback;
  }

  onStateChange(callback: SttStateCallback): void {
    this.sttStateCallback = callback;
  }

  getListeningState(): boolean {
    return this.isListening;
  }

  /**
   * Libera recursos de los motores.
   */
  async release(): Promise<void> {
    await this.stopListening();
    await this.stopSpeaking();

    if (this.sttEngine) {
      await this.sttEngine.shutdown();
      this.sttEngine = null;
    }
    if (this.ttsEngine) {
      await this.ttsEngine.shutdown();
      this.ttsEngine = null;
    }
  }

  private notifyStateChange(listening: boolean): void {
    if (this.sttStateCallback) {
      this.sttStateCallback(listening);
    }
  }
}
