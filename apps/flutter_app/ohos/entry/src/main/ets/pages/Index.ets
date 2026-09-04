
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  @Builder
  splashScreen() {
    Column() {
      Image($r('app.media.icon'))
        .width(32)
        .height(32)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Black)
  }

  build() {
    Column() {
      FlutterPage({
        viewId: this.viewId,
        splashScreenView: this.splashScreen
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
