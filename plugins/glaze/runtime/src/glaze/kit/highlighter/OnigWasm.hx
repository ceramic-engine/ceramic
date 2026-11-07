// Original code (not a port), written for Glaze.
// MIT License, see Ceramic's LICENSE file.
package glaze.kit.highlighter;

#if (js && glaze_onig_wasm)
import ceramic.Shortcuts.*;

/**
 * Loads vscode-oniguruma on the web, for builds with the `glaze_onig_wasm`
 * define, and makes it the regex engine of the code highlighter
 * (`Highlighter.enableWasm`).
 *
 * The plugin's `begin build` hook (`ceramic glaze setup onig-wasm`) copies
 * `vscode-oniguruma.js` (the binding, vscode-oniguruma's `release/main.js`)
 * and `onig.wasm` next to `index.html`. They are loaded with the default
 * assets (`OnigWasmAsset`), so the engine is chosen before the application
 * is ready. If anything fails, a warning is logged and the highlighter keeps
 * the pure Haxe Oniguruma engine.
 */
class OnigWasm {

    public static inline final BINDING_URL = './vscode-oniguruma.js';

    public static inline final WASM_URL = './onig.wasm';

    /** The loaded vscode-oniguruma module, once it is in use. */
    public static var onigModule(default, null):Dynamic = null;

    static var loading = false;

    static final callbacks:Array<(Bool) -> Void> = [];

    /** Loads the binding and the wasm file, then enables the engine; `done(true)` when it is in use. */
    public static function load(done:(Bool) -> Void):Void {
        if (onigModule != null) {
            done(true);
            return;
        }
        callbacks.push(done);
        if (loading)
            return;
        loading = true;

        if (!js.Browser.supported) {
            finish(null, 'no browser document');
            return;
        }

        loadScript(BINDING_URL, (module, error) -> {
            if (module == null) {
                finish(null, error);
                return;
            }
            loadBytes(WASM_URL, (data, error) -> {
                if (data == null) {
                    finish(null, error);
                    return;
                }
                final promise:js.lib.Promise<Dynamic> = try module.loadWASM(data) catch (e:Dynamic) js.lib.Promise.reject(e);
                promise.then(_ -> {
                    Highlighter.enableWasm(module, ok -> finish(ok ? module : null, 'the engine did not start'));
                }, e -> finish(null, 'loadWASM failed: $e'));
            });
        });
    }

    static function finish(module:Dynamic, error:String):Void {
        loading = false;
        onigModule = module;
        if (module != null) {
            log.info('Code highlighter: regex engine is onig.wasm (vscode-oniguruma, WasmOnigLib)');
        }
        else {
            log.warning('Code highlighter: cannot use onig.wasm ($error), keeping the pure Haxe engine. Rebuild, or run: ceramic glaze setup onig-wasm');
        }
        final ok = module != null;
        final pending = callbacks.copy();
        callbacks.resize(0);
        for (callback in pending)
            callback(ok);
    }

    /**
     * Loads the binding with a script tag. Its UMD wrapper sets `window.onig`
     * in a browser, or `module.exports` when a CommonJS `module` is visible
     * (Electron with node integration): the latter is put back as it was.
     */
    static function loadScript(src:String, done:(module:Dynamic, error:String) -> Void):Void {
        final window:Dynamic = js.Browser.window;
        final commonJs:Dynamic = js.Syntax.code("(typeof module === 'object' && module != null) ? module : null");
        final previousExports:Dynamic = commonJs != null ? commonJs.exports : null;
        final script = js.Browser.document.createScriptElement();
        script.setAttribute('type', 'text/javascript');
        script.addEventListener('load', () -> {
            var module:Dynamic = window.onig;
            if (module == null && commonJs != null && commonJs.exports != previousExports) {
                module = commonJs.exports;
                commonJs.exports = previousExports;
            }
            if (module == null || module.loadWASM == null)
                done(null, '$src did not define vscode-oniguruma');
            else
                done(module, null);
        });
        script.addEventListener('error', () -> done(null, 'failed to load $src'));
        script.setAttribute('src', src);
        js.Browser.document.head.appendChild(script);
    }

    static function loadBytes(url:String, done:(data:js.lib.ArrayBuffer, error:String) -> Void):Void {
        final request = new js.html.XMLHttpRequest();
        request.open('GET', url, true);
        request.responseType = js.html.XMLHttpRequestResponseType.ARRAYBUFFER;
        request.onload = _ -> {
            // Status 0: file:// URL
            if ((request.status == 200 || request.status == 0) && request.response != null)
                done(request.response, null);
            else
                done(null, 'failed to load $url (status ${request.status})');
        };
        request.onerror = _ -> done(null, 'failed to load $url');
        request.send();
    }

}

/**
 * Loads `OnigWasm` with the default assets, so the application starts with
 * the engine already chosen. It always completes successfully: a failure
 * only keeps the pure Haxe engine.
 */
class OnigWasmAsset extends ceramic.Asset {

    public function new() {
        super('glaze-onig-wasm', 'glaze-onig-wasm');
    }

    override public function load():Void {
        status = LOADING;
        OnigWasm.load(_ -> {
            status = READY;
            emitComplete(true);
        });
    }

}
#end
