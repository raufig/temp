/**
 * Módulo 2 — Wear Engine Bridge (puente BLE)
 *
 * Gestiona la comunicación Bluetooth Low Energy con el teléfono Android
 * usando la API oficial de Huawei WearEngine MessageClient.
 * Canal persistente: /petalgemini/query
 */
import wearEngine from '@hms.wearengine';
import { QueryMessage, ResponseMessage } from '../models/Message';

const CHANNEL_PATH = '/petalgemini/query';
const CONNECTION_TIMEOUT_MS = 5000;

type ResponseCallback = (response: ResponseMessage) => void;
type ConnectionCallback = (connected: boolean) => void;

export class BleService {
  private messageClient: wearEngine.MessageClient | null = null;
  private isConnected: boolean = false;
  private responseCallback: ResponseCallback | null = null;
  private connectionCallback: ConnectionCallback | null = null;
  private pendingTimestamp: number = 0;

  /**
   * Inicializa el canal BLE con WearEngine.
   * Se llama cuando la app entra a primer plano.
   */
  async connect(): Promise<boolean> {
    try {
      this.messageClient = wearEngine.getMessageClient();

      this.messageClient.on('messageReceived', (message: wearEngine.Message) => {
        if (message.path === CHANNEL_PATH && message.data) {
          this.handleIncomingMessage(message.data);
        }
      });

      const devices = await wearEngine.getDeviceClient().getConnectedDevices();
      if (devices.length === 0) {
        this.updateConnectionState(false);
        return false;
      }

      this.updateConnectionState(true);
      return true;
    } catch (error) {
      console.error(`[BleService] Error al conectar: ${JSON.stringify(error)}`);
      this.updateConnectionState(false);
      return false;
    }
  }

  /**
   * Cierra el canal BLE.
   * Se llama cuando la app va a segundo plano para ahorrar batería.
   */
  async disconnect(): Promise<void> {
    try {
      if (this.messageClient) {
        this.messageClient.off('messageReceived');
        this.messageClient = null;
      }
      this.updateConnectionState(false);
    } catch (error) {
      console.error(`[BleService] Error al desconectar: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Envía una query al Phone Service via BLE.
   * Retorna false si no hay conexión activa.
   */
  async sendQuery(text: string): Promise<boolean> {
    if (!this.isConnected || !this.messageClient) {
      return false;
    }

    const timestamp = Date.now();
    this.pendingTimestamp = timestamp;

    const query: QueryMessage = {
      q: text,
      ts: timestamp
    };

    try {
      const devices = await wearEngine.getDeviceClient().getConnectedDevices();
      if (devices.length === 0) {
        this.updateConnectionState(false);
        return false;
      }

      const message: wearEngine.Message = {
        deviceId: devices[0].deviceId,
        path: CHANNEL_PATH,
        data: JSON.stringify(query)
      };

      await this.messageClient.send(message);
      return true;
    } catch (error) {
      console.error(`[BleService] Error al enviar: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * Registra callback para recibir respuestas del teléfono.
   */
  onResponse(callback: ResponseCallback): void {
    this.responseCallback = callback;
  }

  /**
   * Registra callback para cambios de estado de conexión.
   */
  onConnectionChange(callback: ConnectionCallback): void {
    this.connectionCallback = callback;
  }

  getConnectionState(): boolean {
    return this.isConnected;
  }

  private handleIncomingMessage(data: string): void {
    try {
      const response: ResponseMessage = JSON.parse(data);

      // Descartar respuestas a queries anteriores (fuera de orden)
      if (response.ts < this.pendingTimestamp) {
        console.warn(`[BleService] Respuesta descartada (ts=${response.ts}, esperado=${this.pendingTimestamp})`);
        return;
      }

      if (this.responseCallback) {
        this.responseCallback(response);
      }
    } catch (error) {
      console.error(`[BleService] Error parseando respuesta: ${JSON.stringify(error)}`);
    }
  }

  private updateConnectionState(connected: boolean): void {
    this.isConnected = connected;
    if (this.connectionCallback) {
      this.connectionCallback(connected);
    }
  }
}
