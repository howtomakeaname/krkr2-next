
import { FlutterAbility, FlutterEngine, FlutterShellArgs } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }

  getFlutterShellArgs(): FlutterShellArgs {
    const args = super.getFlutterShellArgs();
    // Keep the Dart UI isolate off the OHOS main thread. In merged mode the
    // Dart VM sizes its stack limit from musl's pthread_getattr_np, which
    // for the main thread only reports the pages mapped so far — often a
    // few hundred KB — so a normal MaterialApp first build dies with
    // "Stack Overflow" and Flutter paints its grey ErrorWidget instead of
    // the home page. A dedicated 1.ui thread gets an explicit 2 MB stack.
    args.add('--no-enable-merged-platform-ui-thread');
    return args;
  }
}
