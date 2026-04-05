/**
 * Página de ajustes del reloj.
 * Permite activar/desactivar TTS y limpiar cache.
 */
import router from '@ohos.router';
import dataPreferences from '@ohos.data.preferences';
import { CacheService } from '../services/CacheService';

const SETTINGS_PREFS = 'petalgemini_settings';

@Entry
@Component
struct SettingsPage {
  @State ttsEnabled: boolean = true;
  @State cacheCleared: boolean = false;
  private cacheService: CacheService = new CacheService();
  private preferences: dataPreferences.Preferences | null = null;

  async aboutToAppear() {
    await this.cacheService.initialize(getContext(this));
    this.preferences = await dataPreferences.getPreferences(getContext(this), SETTINGS_PREFS);
    this.ttsEnabled = await this.preferences.get('tts_enabled', true) as boolean;
  }

  private async toggleTts() {
    this.ttsEnabled = !this.ttsEnabled;
    if (this.preferences) {
      await this.preferences.put('tts_enabled', this.ttsEnabled);
      await this.preferences.flush();
    }
  }

  build() {
    Column() {
      Text('Ajustes')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .margin({ top: 12 })

      // Toggle TTS
      Row() {
        Text('Leer respuestas')
          .fontSize(12)
          .fontColor('#FFFFFF')
        Toggle({ type: ToggleType.Switch, isOn: this.ttsEnabled })
          .onChange(() => this.toggleTts())
      }
      .width('85%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })

      // Borrar cache
      Button(this.cacheCleared ? 'Borrado ✓' : 'Borrar historial')
        .fontSize(11)
        .height(32)
        .width('70%')
        .backgroundColor(this.cacheCleared ? '#1E1E30' : '#FF5252')
        .margin({ top: 16 })
        .onClick(async () => {
          await this.cacheService.clearCache();
          this.cacheCleared = true;
        })

      Button('← Volver')
        .fontSize(11)
        .height(28)
        .backgroundColor('#1E1E30')
        .margin({ top: 20 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0F0F1A')
    .alignItems(HorizontalAlign.Center)
  }
}
