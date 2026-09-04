
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'
import data_preferences from '@ohos.data.preferences';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
// Kept separate from the Flutter shared_preferences file. Opening that file a
// second time while its plugin is attaching can race its asynchronous load and
// return the fallback value on a cold start.
const PREFERENCES_NAME = 'Krkr2ThemePreferences'
const THEME_MODE_KEY = 'themeMode'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  aboutToAppear() {
    try {
      const preferences: data_preferences.Preferences = data_preferences.getPreferencesSync(
        this.context,
        { name: PREFERENCES_NAME }
      )
      const themeMode = preferences.getSync(THEME_MODE_KEY, 'dark') as string
      const colorMode = themeMode === 'light'
        ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : themeMode === 'system'
          ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
          : ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      this.context.getApplicationContext().setColorMode(colorMode)
    } catch (error) {
      console.error(`Failed to restore application color mode: ${JSON.stringify(error)}`)
    }
  }

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
    .backgroundColor($r('app.color.start_window_background'))
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
    .backgroundColor($r('app.color.start_window_background'))
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
