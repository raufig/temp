/**
 * Página de historial — muestra las últimas conversaciones cacheadas en el reloj.
 */
import router from '@ohos.router';
import { CacheService } from '../services/CacheService';
import { ConversationEntry } from '../models/Message';

@Entry
@Component
struct HistoryPage {
  @State entries: ConversationEntry[] = [];
  private cacheService: CacheService = new CacheService();

  async aboutToAppear() {
    await this.cacheService.initialize(getContext(this));
    this.entries = await this.cacheService.getCachedResponses();
    this.entries.reverse(); // Más recientes primero
  }

  private formatTime(ts: number): string {
    const date = new Date(ts);
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      Text('Historial')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .margin({ top: 8 })

      if (this.entries.length === 0) {
        Text('Sin historial')
          .fontSize(12)
          .fontColor('#B0B0C0')
          .margin({ top: 30 })
      } else {
        List() {
          ForEach(this.entries, (entry: ConversationEntry) => {
            ListItem() {
              Column() {
                Row() {
                  Text('Tú')
                    .fontSize(9)
                    .fontColor('#448AFF')
                  Text(this.formatTime(entry.timestamp))
                    .fontSize(8)
                    .fontColor('#B0B0C0')
                    .margin({ left: 4 })
                }
                Text(entry.query)
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(entry.response)
                  .fontSize(11)
                  .fontColor('#00C853')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
                Divider()
                  .color('#1E1E30')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .padding(4)
            }
          })
        }
        .width('90%')
        .layoutWeight(1)
        .margin({ top: 8 })
      }

      Button('← Volver')
        .fontSize(11)
        .height(28)
        .backgroundColor('#1E1E30')
        .margin({ bottom: 8 })
        .onClick(() => router.back())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0F0F1A')
    .alignItems(HorizontalAlign.Center)
  }
}
