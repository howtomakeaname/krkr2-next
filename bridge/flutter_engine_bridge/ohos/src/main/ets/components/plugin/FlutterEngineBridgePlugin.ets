import {
  AbilityAware,
  AbilityPluginBinding,
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

const TAG = 'FlutterEngineBridgePlugin';

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

  constructor() {
  }

  getUniqueClassName(): string {
    return 'FlutterEngineBridgePlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
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
    this.textureRegistry = null;
  }

  // --- AbilityAware (for the document picker) ---

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.ability = binding.getAbility();
  }

  onDetachedFromAbility(): void {
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
