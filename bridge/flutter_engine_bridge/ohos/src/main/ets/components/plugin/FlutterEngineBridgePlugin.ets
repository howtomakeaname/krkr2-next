import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterEngine,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  SurfaceTextureEntry,
  SurfaceTextureRegistryEntry,
  TextureRegistry,
} from '@ohos/flutter_ohos';
import deviceInfo from '@ohos.deviceInfo';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import bundleManager from '@ohos.bundle.bundleManager';
import common from '@ohos.app.ability.common';
import UIAbility from '@ohos.app.ability.UIAbility';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import data_preferences from '@ohos.data.preferences';
import display from '@ohos.display';
import { displaySync } from '@kit.ArkGraphics2D';

const TAG = 'FlutterEngineBridgePlugin';
const THEME_PREFERENCES_NAME = 'Krkr2ThemePreferences';
const THEME_MODE_KEY = 'themeMode';

/**
 * OpenHarmony side of the krkr2 engine bridge ("flutter_engine_bridge"
 * MethodChannel). Mirrors the Android Kotlin plugin:
 *
 *  - createSurfaceTexture registers a texture in the embedder's
 *    TextureRegistry and returns its OHNativeWindow* so the Dart side can
 *    attach it as the engine's EGL render target via FFI (zero copy).
 *    Rendering into that window with eglSwapBuffers presents frames to the
 *    Flutter compositor automatically — no per-frame notification needed.
 *  - createTexture / updateTextureRgba / disposeTexture keep the legacy
 *    (slow) RGBA path available as a fallback.
 */
export default class FlutterEngineBridgePlugin
  implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private textureRegistry: TextureRegistry | null = null;

  // Zero-copy window-backed textures (key: textureId).
  private surfaceTextures: Map<number, SurfaceTextureEntry> = new Map();
  // Legacy RGBA texture entries (key: textureId).
  private legacyTextures: Map<number, SurfaceTextureEntry> = new Map();

  private ability: UIAbility | null = null;
  private flutterEngine: FlutterEngine | null = null;
  private gameDisplaySync: displaySync.DisplaySync | null = null;
  private gameDisplaySyncCallback: ((info: displaySync.IntervalInfo) => void) | null = null;
  private gameDisplaySyncGeneration: number = 0;
  private gameVsyncMessageInFlight: boolean = false;
  private highFrameRateTimer: number = -1;

  constructor() {
  }

  getUniqueClassName(): string {
    return 'FlutterEngineBridgePlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.flutterEngine = binding.getFlutterEngine();
    this.textureRegistry = binding.getTextureRegistry();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'flutter_engine_bridge');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.releaseAllTextures();
    this.stopGameDisplaySync();
    this.flutterEngine = null;
    this.textureRegistry = null;
  }

  // --- AbilityAware (for the document picker) ---

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.ability = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.stopGameDisplaySync();
    this.ability = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getPlatformVersion':
        result.success(`OpenHarmony ${deviceInfo.sdkApiVersion}`);
        break;

      // OHOS apps are sandboxed; bundled/sandbox game data is always
      // readable, so the "all files access" dance is unnecessary there.
      case 'hasManageExternalStorage':
        result.success(true);
        break;
      case 'requestManageExternalStorage':
        result.success(true);
        break;

      case 'setApplicationColorMode': {
        const ability = this.ability;
        if (ability == null) {
          result.error('no_ability', 'No ability available', null);
          break;
        }
        const mode = call.argument('mode') as string;
        const colorMode = mode === 'light'
          ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
          : mode === 'system'
            ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
            : ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        try {
          ability.context.getApplicationContext().setColorMode(colorMode);
          const preferences: data_preferences.Preferences = data_preferences.getPreferencesSync(
            ability.context,
            { name: THEME_PREFERENCES_NAME },
          );
          preferences.putSync(THEME_MODE_KEY, mode);
          preferences.flushSync();
          result.success(null);
        } catch (error) {
          Log.e(TAG, `setApplicationColorMode failed: ${JSON.stringify(error)}`);
          result.error('color_mode_failed', 'Unable to update the application color mode', error);
        }
        break;
      }

      // --- Zero-copy OHNativeWindow textures ---

      case 'createSurfaceTexture': {
        const width = (call.argument('width') as number) ?? 1;
        const height = (call.argument('height') as number) ?? 1;
        const registry = this.textureRegistry;
        if (registry == null) {
          result.error('detached', 'Flutter engine is detached', null);
          break;
        }
        const textureId = registry.getTextureId();
        const entry = registry.registerTexture(textureId);
        registry.setTextureBufferSize(textureId, width, height);
        this.surfaceTextures.set(textureId, entry);
        // The engine attaches the OHNativeWindow through Dart FFI
        // (engine_set_render_target_surface); handed over as a string to
        // keep the full 64-bit pointer through the standard codec.
        // SurfaceTextureEntry (the interface) predates the bigint accessor,
        // the concrete entry class carries it.
        const nativeWindowPtr = (entry as SurfaceTextureRegistryEntry).getNativeWindowPtr();
        Log.i(TAG,
          `createSurfaceTexture: id=${textureId} size=${width}x${height} window=0x${nativeWindowPtr.toString(16)}`);
        result.success({
          textureId: textureId,
          width: width,
          height: height,
          nativeWindowPtr: nativeWindowPtr.toString(),
        });
        break;
      }

      case 'resizeSurfaceTexture': {
        const textureId = call.argument('textureId') as number;
        const width = (call.argument('width') as number) ?? 1;
        const height = (call.argument('height') as number) ?? 1;
        if (textureId == null) {
          result.error('invalid_args', 'textureId is required', null);
          break;
        }
        const registry = this.textureRegistry;
        if (registry != null && this.surfaceTextures.has(textureId)) {
          // Only resize the buffers. Re-registering would hand out a new
          // OHNativeWindow and invalidate the engine's EGL window surface
          // (same lesson as Android's setDefaultBufferSize-only path).
          registry.setTextureBufferSize(textureId, width, height);
          Log.i(TAG, `resizeSurfaceTexture: id=${textureId} size=${width}x${height}`);
          result.success({
            textureId: textureId,
            width: width,
            height: height,
          });
        } else {
          result.error('not_found', `SurfaceTexture ${textureId} not found`, null);
        }
        break;
      }

      case 'disposeSurfaceTexture': {
        const textureId = call.argument('textureId') as number;
        if (textureId == null) {
          result.error('invalid_args', 'textureId is required', null);
          break;
        }
        // Detaching the EGL target is driven from the Dart side before this
        // call; here we only drop the registry entry.
        this.unregisterTexture(this.surfaceTextures, textureId);
        result.success(null);
        break;
      }

      case 'notifyFrameAvailable':
        // Window-backed textures are presented by eglSwapBuffers through
        // the embedder; nothing to push manually (API parity with macOS).
        result.success(null);
        break;

      case 'setGameFrameRate': {
        const preferred = (call.argument('preferred') as number) ?? 0;
        try {
          result.success(this.setGameFrameRate(preferred));
        } catch (e) {
          Log.e(TAG, `setGameFrameRate failed: ${JSON.stringify(e)}`);
          result.error('frame_rate_failed', 'Unable to update the game frame rate', e);
        }
        break;
      }

      // --- Legacy RGBA texture mode (fallback, slower) ---

      case 'createTexture': {
        const width = (call.argument('width') as number) ?? 1;
        const height = (call.argument('height') as number) ?? 1;
        const registry = this.textureRegistry;
        if (registry == null) {
          result.error('detached', 'Flutter engine is detached', null);
          break;
        }
        const textureId = registry.getTextureId();
        const entry = registry.registerTexture(textureId);
        registry.setTextureBufferSize(textureId, width, height);
        this.legacyTextures.set(textureId, entry);
        result.success(textureId);
        break;
      }

      case 'updateTextureRgba':
        // Kept for API parity; the Dart FFI side reads pixels itself.
        result.success(null);
        break;

      case 'disposeTexture': {
        const textureId = call.argument('textureId') as number;
        if (textureId != null) {
          this.unregisterTexture(this.legacyTextures, textureId);
        }
        result.success(null);
        break;
      }

      // --- IOSurface methods (macOS only) ---

      case 'createIOSurfaceTexture':
      case 'resizeIOSurfaceTexture':
      case 'disposeIOSurfaceTexture':
        result.success(null);
        break;

      case 'resolveContentUri':
        result.success(null);
        break;

      case 'pickFile': {
        const ability = this.ability;
        if (ability == null) {
          result.error('no_activity', 'No ability available', null);
          break;
        }
        try {
          const documentPicker = new picker.DocumentViewPicker(ability.context);
          documentPicker.select({
            maxSelectNumber: 1,
            fileSuffixFilters: ['.xp3'],
          }).then((uris: Array<string>) => {
            // Note: the picker returns a docs:// URI, not a plain sandbox
            // path, so the caller must treat it as best-effort input.
            result.success(uris.length > 0 ? uris[0] : null);
          }).catch((err: Error) => {
            Log.e(TAG, `pickFile failed: ${err.message}`);
            result.success(null);
          });
        } catch (e) {
          Log.e(TAG, `pickFile threw: ${JSON.stringify(e)}`);
          result.success(null);
        }
        break;
      }

      case 'ensurePublicGamesDir': {
        const ability = this.ability;
        if (ability == null) {
          result.error('no_ability', 'No ability available', null);
          break;
        }
        this.ensurePublicGamesDir(ability.context, result);
        break;
      }

      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * Make sure `Download/<bundleName>/games/` exists and hand back its sandbox
   * path (`/storage/Users/currentUser/Download/<bundleName>/games`).
   *
   * The app has persistent access to `Download/<bundleName>/` with no
   * permission prompt (Core File Kit FAQ: "使用DOWNLOAD模式保存的文件如何访问").
   * The bundle directory itself is created by the system on the first
   * DOWNLOAD-mode DocumentViewPicker.save(); that call shows no UI. Users
   * copy whole game folders into games/ with the file manager and the Dart
   * side scans it on launch / resume / pull-to-refresh.
   *
   * Resolves to `{ path, display }` or `null` when the directory cannot be
   * set up (old API, picker refused, ...).
   */
  private ensurePublicGamesDir(context: common.UIAbilityContext, result: MethodResult): void {
    let bundleName = '';
    try {
      bundleName = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).name;
    } catch (e) {
      Log.e(TAG, `ensurePublicGamesDir: getBundleInfoForSelfSync failed: ${JSON.stringify(e)}`);
      result.success(null);
      return;
    }
    const display = `Download/${bundleName}/games`;

    const finish = (rootPath: string): void => {
      try {
        const gamesPath = `${rootPath}/games`;
        if (!fs.accessSync(gamesPath)) {
          fs.mkdirSync(gamesPath);
        }
        Log.i(TAG, `ensurePublicGamesDir: ${gamesPath}`);
        result.success({ path: gamesPath, display: display });
      } catch (e) {
        Log.e(TAG, `ensurePublicGamesDir: mkdir failed: ${JSON.stringify(e)}`);
        result.success(null);
      }
    };

    try {
      const rootUri = `file://docs/storage/Users/currentUser/Download/${bundleName}`;
      const rootPath = new fileUri.FileUri(rootUri).path;
      if (fs.accessSync(rootPath)) {
        finish(rootPath);
        return;
      }
      // First run: let the system create Download/<bundleName>/ for us.
      const options = new picker.DocumentSaveOptions();
      options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      new picker.DocumentViewPicker(context).save(options)
        .then((uris: Array<string>) => {
          if (uris.length === 0) {
            Log.e(TAG, 'ensurePublicGamesDir: DOWNLOAD-mode save returned no uri');
            result.success(null);
            return;
          }
          finish(new fileUri.FileUri(uris[0]).path);
        })
        .catch((err: Error) => {
          Log.e(TAG, `ensurePublicGamesDir: save failed: ${err.message}`);
          result.success(null);
        });
    } catch (e) {
      Log.e(TAG, `ensurePublicGamesDir threw: ${JSON.stringify(e)}`);
      result.success(null);
    }
  }

  private unregisterTexture(map: Map<number, SurfaceTextureEntry>, textureId: number): void {
    map.delete(textureId);
    this.textureRegistry?.unregisterTexture(textureId);
  }

  /** Drive the Dart-side game loop from the cadence selected by HarmonyOS. */
  private setGameFrameRate(preferred: number): number {
    this.stopGameDisplaySync();
    // Negative values release the game request. Zero means uncapped: request
    // the display's highest advertised rate, while leaving min at zero so the
    // system can select a lower LTPO tier. Positive values are user limits.
    if (preferred < 0) {
      Log.i(TAG, 'setGameFrameRate: released');
      return 0;
    }
    const maximumFps = this.getMaximumDisplayRefreshRate();
    const expectedFps = preferred > 0
      ? Math.min(Math.round(preferred), maximumFps)
      : maximumFps;
    const frameSync = displaySync.create();
    const generation = ++this.gameDisplaySyncGeneration;
    const callback = (info: displaySync.IntervalInfo): void => {
      this.dispatchGameVsync(generation, info);
    };
    frameSync.setExpectedFrameRateRange({
      min: 0,
      expected: expectedFps,
      max: expectedFps,
    });
    frameSync.on('frame', callback);
    this.gameDisplaySync = frameSync;
    this.gameDisplaySyncCallback = callback;
    frameSync.start();
    this.startHighFrameRateVote(expectedFps);
    Log.i(TAG,
      `setGameFrameRate: preferred=${Math.round(preferred)}, expected=${expectedFps}, DisplaySync active`);
    return expectedFps;
  }

  private dispatchGameVsync(generation: number, info: displaySync.IntervalInfo): void {
    const channel = this.channel;
    if (generation !== this.gameDisplaySyncGeneration ||
      this.gameDisplaySync == null || channel == null || this.gameVsyncMessageInFlight) {
      return;
    }
    this.gameVsyncMessageInFlight = true;
    const complete = (): void => {
      if (generation === this.gameDisplaySyncGeneration) {
        this.gameVsyncMessageInFlight = false;
      }
    };
    channel.invokeMethod(
      'onGameVsync',
      [Math.round(info.timestamp / 1000), Math.round(info.targetTimestamp / 1000)],
      {
        success: complete,
        error: complete,
        notImplemented: complete,
      },
    );
  }

  private getMaximumDisplayRefreshRate(): number {
    const displayInfo = display.getDefaultDisplaySync();
    let maximum = displayInfo.refreshRate > 0 ? Math.round(displayInfo.refreshRate) : 60;
    const supportedRates = displayInfo.supportedRefreshRates;
    if (supportedRates != null) {
      for (const rate of supportedRates) {
        maximum = Math.max(maximum, Math.round(rate));
      }
    }
    Log.i(TAG,
      `display refresh: current=${displayInfo.refreshRate}, supported=${JSON.stringify(supportedRates)}, maximum=${maximum}`);
    return maximum;
  }

  private stopGameDisplaySync(): void {
    this.stopHighFrameRateVote();
    ++this.gameDisplaySyncGeneration;
    this.gameVsyncMessageInFlight = false;
    const frameSync = this.gameDisplaySync;
    const callback = this.gameDisplaySyncCallback;
    this.gameDisplaySync = null;
    this.gameDisplaySyncCallback = null;
    if (frameSync == null) {
      return;
    }
    frameSync.stop();
    if (callback != null) {
      frameSync.off('frame', callback);
    }
  }

  /**
   * Ask Flutter's window-bound NativeVSync for high refresh while DisplaySync
   * delivers the system-selected cadence to the producer. Without this window
   * vote, a standalone DisplaySync request can remain at the idle 60 Hz tier.
   */
  private startHighFrameRateVote(expectedFps: number): void {
    if (expectedFps <= 60) {
      return;
    }
    const flutterEngine = this.flutterEngine;
    if (flutterEngine == null) {
      throw new Error('Flutter engine is not attached');
    }
    const vote = (): void => {
      flutterEngine.getFlutterNapi().LTPODispatchHighFrameRate();
    };
    vote();
    // The embedder's touch-up vote expires after three seconds.
    this.highFrameRateTimer = setInterval(vote, 2000);
  }

  private stopHighFrameRateVote(): void {
    if (this.highFrameRateTimer < 0) {
      return;
    }
    clearInterval(this.highFrameRateTimer);
    this.highFrameRateTimer = -1;
  }

  private releaseAllTextures(): void {
    for (const textureId of this.surfaceTextures.keys()) {
      this.textureRegistry?.unregisterTexture(textureId);
    }
    this.surfaceTextures.clear();
    for (const textureId of this.legacyTextures.keys()) {
      this.textureRegistry?.unregisterTexture(textureId);
    }
    this.legacyTextures.clear();
  }
}
