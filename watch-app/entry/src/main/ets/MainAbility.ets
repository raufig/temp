/**
 * Ability principal de PetalGemini Watch App.
 * Gestiona el ciclo de vida de la aplicación en el GT 6.
 */
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import type AbilityConstant from '@ohos.app.ability.AbilityConstant';
import type Want from '@ohos.app.ability.Want';

export default class MainAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('[PetalGemini] MainAbility onCreate');
  }

  onDestroy() {
    console.info('[PetalGemini] MainAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info('[PetalGemini] MainAbility onWindowStageCreate');
    windowStage.loadContent('pages/MainPage', (err, _data) => {
      if (err.code) {
        console.error(`[PetalGemini] Error cargando página: ${JSON.stringify(err)}`);
        return;
      }
      console.info('[PetalGemini] MainPage cargada correctamente');
    });
  }

  onWindowStageDestroy() {
    console.info('[PetalGemini] MainAbility onWindowStageDestroy');
  }

  onForeground() {
    console.info('[PetalGemini] App en primer plano');
  }

  onBackground() {
    console.info('[PetalGemini] App en segundo plano — BLE se desconectará');
  }
}
