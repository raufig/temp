/**
 * Página principal del reloj — Módulo 1
 *
 * Pantalla circular con dos modos de input:
 * - Botón de micrófono (input de voz, máx 8 seg)
 * - Teclado mínimo (letras grandes para pantalla pequeña)
 *
 * Muestra estados visuales: idle, escuchando, procesando, respuesta, error.
 */
import router from '@ohos.router';
import { BleService } from '../services/BleService';
import { SpeechService } from '../services/SpeechService';
import { CacheService } from '../services/CacheService';
import { AppState, ErrorCode, errorToUserMessage, ResponseMessage } from '../models/Message';

@Entry
@Component
struct MainPage {
  @State appState: AppState = AppState.IDLE;
  @State responseText: string = '';
  @State queryText: string = '';
  @State isConnected: boolean = false;
  @State showKeyboard: boolean = false;
  @State inputText: string = '';
  @State errorMessage: string = '';
  @State pulseAnimation: boolean = false;

  private bleService: BleService = new BleService();
  private speechService: SpeechService = new SpeechService();
  private cacheService: CacheService = new CacheService();
  private ttsEnabled: boolean = true;

  async aboutToAppear() {
    await this.speechService.initialize();
    await this.cacheService.initialize(getContext(this));

    // Configurar callbacks BLE
    this.bleService.onConnectionChange((connected: boolean) => {
      this.isConnected = connected;
      if (!connected && this.appState === AppState.PROCESSING) {
        this.showError(ErrorCode.NO_BLE);
      }
    });

    this.bleService.onResponse((response: ResponseMessage) => {
      if (response.err) {
        this.showError(response.err as ErrorCode);
        return;
      }
      this.showResponse(response.r);
      this.cacheService.cacheResponse({
        query: this.queryText,
        response: response.r,
        timestamp: response.ts
      });
    });

    // Configurar callbacks STT
    this.speechService.onResult((text: string) => {
      this.queryText = text;
      this.sendQuery(text);
    });

    this.speechService.onError((_error: string) => {
      this.showError(ErrorCode.STT_FAILED);
    });

    this.speechService.onStateChange((listening: boolean) => {
      if (listening) {
        this.appState = AppState.LISTENING;
        this.pulseAnimation = true;
      }
    });

    // Conectar BLE
    const connected = await this.bleService.connect();
    this.isConnected = connected;
  }

  async aboutToDisappear() {
    await this.speechService.release();
    await this.bleService.disconnect();
  }

  private async sendQuery(text: string) {
    this.appState = AppState.PROCESSING;
    this.pulseAnimation = false;

    // Comando especial: "olvida todo" limpia historial
    if (text.toLowerCase().trim() === 'olvida todo') {
      await this.cacheService.clearCache();
      this.showResponse('Historial borrado');
      return;
    }

    // Intentar cache primero si no hay conexión
    if (!this.isConnected) {
      const cached = await this.cacheService.findCachedResponse(text);
      if (cached) {
        this.showResponse(cached + ' (cache)');
        return;
      }
      this.showError(ErrorCode.NO_BLE);
      return;
    }

    const sent = await this.bleService.sendQuery(text);
    if (!sent) {
      this.showError(ErrorCode.NO_BLE);
    }

    // Timeout de 15 segundos
    setTimeout(() => {
      if (this.appState === AppState.PROCESSING) {
        this.showError(ErrorCode.TIMEOUT);
      }
    }, 15000);
  }

  private showResponse(text: string) {
    this.responseText = text;
    this.appState = AppState.DISPLAYING;
    if (this.ttsEnabled) {
      this.speechService.speak(text);
    }
  }

  private showError(code: ErrorCode) {
    this.errorMessage = errorToUserMessage(code);
    this.appState = AppState.ERROR;
    this.pulseAnimation = false;
  }

  private async onMicTap() {
    if (this.appState === AppState.LISTENING) {
      await this.speechService.stopListening();
      return;
    }

    if (!this.isConnected) {
      this.showError(ErrorCode.NO_BLE);
      return;
    }

    this.responseText = '';
    this.errorMessage = '';
    await this.speechService.startListening();
  }

  private onKeyboardSubmit() {
    const text = this.inputText.trim();
    if (text.length === 0) return;

    this.queryText = text;
    this.inputText = '';
    this.showKeyboard = false;
    this.sendQuery(text);
  }

  build() {
    Column() {
      // --- Estado de conexión ---
      Row() {
        Circle({ width: 8, height: 8 })
          .fill(this.isConnected ? '#00C853' : '#FF5252')
        Text(this.isConnected ? 'Conectado' : 'Desconectado')
          .fontSize(10)
          .fontColor('#B0B0C0')
          .margin({ left: 4 })
      }
      .margin({ top: 8 })

      // --- Área de contenido principal ---
      if (this.appState === AppState.IDLE) {
        this.IdleView()
      } else if (this.appState === AppState.LISTENING) {
        this.ListeningView()
      } else if (this.appState === AppState.PROCESSING) {
        this.ProcessingView()
      } else if (this.appState === AppState.DISPLAYING) {
        this.DisplayView()
      } else if (this.appState === AppState.ERROR) {
        this.ErrorView()
      }

      // --- Botones de acción ---
      if (!this.showKeyboard) {
        Row() {
          // Botón micrófono
          Button() {
            Image($r('app.media.icon'))
              .width(28)
              .height(28)
          }
          .width(56)
          .height(56)
          .borderRadius(28)
          .backgroundColor(this.appState === AppState.LISTENING ? '#FF5252' : '#00C853')
          .onClick(() => this.onMicTap())

          // Botón teclado
          Button() {
            Text('⌨')
              .fontSize(20)
              .fontColor('#FFFFFF')
          }
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#1E1E30')
          .margin({ left: 16 })
          .onClick(() => {
            this.showKeyboard = true;
            this.appState = AppState.IDLE;
          })
        }
        .margin({ top: 12 })
      }

      // --- Teclado mínimo ---
      if (this.showKeyboard) {
        this.KeyboardView()
      }

      // --- Navegación ---
      Row() {
        Text('Historial')
          .fontSize(10)
          .fontColor('#448AFF')
          .onClick(() => router.pushUrl({ url: 'pages/HistoryPage' }))
      }
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0F0F1A')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  IdleView() {
    Column() {
      Text('PetalGemini')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
      Text('Toca para hablar')
        .fontSize(12)
        .fontColor('#B0B0C0')
        .margin({ top: 4 })
    }
    .margin({ top: 20 })
  }

  @Builder
  ListeningView() {
    Column() {
      // Indicador visual de "escuchando" — círculos pulsantes
      Stack() {
        Circle({ width: 60, height: 60 })
          .fill('#00C85330')
          .scale({ x: this.pulseAnimation ? 1.5 : 1.0, y: this.pulseAnimation ? 1.5 : 1.0 })
          .animation({ duration: 800, iterations: -1, curve: Curve.EaseInOut })
        Circle({ width: 40, height: 40 })
          .fill('#00C85360')
          .scale({ x: this.pulseAnimation ? 1.3 : 1.0, y: this.pulseAnimation ? 1.3 : 1.0 })
          .animation({ duration: 800, iterations: -1, curve: Curve.EaseInOut, delay: 200 })
        Text('🎤')
          .fontSize(24)
      }
      Text('Escuchando...')
        .fontSize(13)
        .fontColor('#00C853')
        .margin({ top: 8 })
    }
    .margin({ top: 16 })
  }

  @Builder
  ProcessingView() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color('#448AFF')
      Text('Pensando...')
        .fontSize(13)
        .fontColor('#448AFF')
        .margin({ top: 8 })
      if (this.queryText) {
        Text(this.queryText)
          .fontSize(10)
          .fontColor('#B0B0C0')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)
      }
    }
    .margin({ top: 16 })
  }

  @Builder
  DisplayView() {
    Column() {
      Scroll() {
        Text(this.responseText)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .padding(8)
      }
      .scrollable(ScrollDirection.Vertical)
      .height(80)

      // Toca para nueva consulta
      Text('Toca el mic para otra pregunta')
        .fontSize(9)
        .fontColor('#B0B0C0')
        .margin({ top: 4 })
    }
    .margin({ top: 12 })
    .onClick(() => {
      this.appState = AppState.IDLE;
      this.responseText = '';
    })
  }

  @Builder
  ErrorView() {
    Column() {
      Text('⚠')
        .fontSize(28)
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor('#FF5252')
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
      Text('Toca para reintentar')
        .fontSize(10)
        .fontColor('#B0B0C0')
        .margin({ top: 8 })
    }
    .margin({ top: 16 })
    .onClick(() => {
      this.appState = AppState.IDLE;
      this.errorMessage = '';
    })
  }

  @Builder
  KeyboardView() {
    Column() {
      TextInput({ placeholder: 'Escribe aquí...', text: this.inputText })
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#1E1E30')
        .height(36)
        .width('85%')
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => this.onKeyboardSubmit())

      Row() {
        Button('Enviar')
          .fontSize(12)
          .height(30)
          .backgroundColor('#00C853')
          .onClick(() => this.onKeyboardSubmit())
        Button('✕')
          .fontSize(12)
          .height(30)
          .backgroundColor('#1E1E30')
          .margin({ left: 8 })
          .onClick(() => {
            this.showKeyboard = false;
            this.inputText = '';
          })
      }
      .margin({ top: 6 })
    }
    .margin({ top: 8 })
  }
}
