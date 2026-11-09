// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic; the build features become a runtime
// switch. See NOTICE.md.
package glaze.kit.highlighter;

import glaze.App;

/**
 * The code highlighter switch.
 *
 * gpui-kit chooses its highlighter at build time: no highlighter by default,
 * tree-sitter or syntect as Cargo features. The port has one highlighter,
 * TextMate grammars (`TextMateBackend`), and it is off until the application
 * calls `Highlighter.enable(cx)`, so a default build renders like gpui-kit
 * without the features (no colors in code blocks). Once enabled:
 *
 * - text views highlight their code blocks with the theme's
 *   `highlightTheme`;
 * - `SyntaxHighlighter.captureNames` (used by the diff) names highlights.
 *
 * On targets without a file system (the web), call `preload` before the
 * grammars are needed. Web builds with the `glaze_onig_wasm` define use
 * vscode-oniguruma's onig.wasm as the regex engine (faster) once it is
 * loaded at startup (`OnigWasm`), the pure Haxe Oniguruma port otherwise.
 */
class Highlighter {

    /** Whether the TextMate highlighter is on (see `enable`). */
    public static var enabled(default, null):Bool = false;

    /**
     * Turns the TextMate highlighter on. With `cx`, the text view defaults of
     * the current theme are installed again so code blocks highlight right
     * away (otherwise from the next theme change).
     */
    public static function enable(?cx:App):Void {
        enabled = true;
        reinstall(cx);
    }

    /** Turns the highlighter off again. */
    public static function disable(?cx:App):Void {
        enabled = false;
        reinstall(cx);
    }

    static function reinstall(cx:Null<App>):Void {
        if (cx != null) {
            // A setting: made before the first render, it initializes the
            // kit, then applies
            glaze.kit.Kit.ensureInit(cx);
            glaze.kit.text.TextView.installTextViewDefaults(glaze.kit.theme.Theme.global(cx), cx);
        }
    }

    /**
     * Loads the grammar files of `languages` (and of the grammars they
     * embed), or of every bundled grammar when null. Needed before
     * highlighting on targets without a file system.
     */
    public static function preload(languages:Null<Array<String>>, done:(Bool) -> Void):Void {
        TextMateGrammars.preload(languages, done);
    }

    #if (js && glaze_onig_wasm)
    /**
     * Uses vscode-oniguruma's onig.wasm as the regex engine instead of the
     * pure Haxe Oniguruma port (web builds with the `glaze_onig_wasm` define).
     *
     * `onigModule` is the vscode-oniguruma JavaScript module on which
     * `loadWASM` already completed. The plugin calls this at startup, once
     * `OnigWasm` has loaded `vscode-oniguruma.js` and `onig.wasm` (copied
     * next to `index.html` by the plugin's build hook), before the default
     * assets are reported loaded. `done(true)` once the engine is in use;
     * `done(false)` keeps the pure Haxe engine.
     */
    public static function enableWasm(onigModule:Dynamic, done:(Bool) -> Void):Void {
        final lib = try {
            // A module whose wasm is not ready throws here, not later while highlighting.
            final scanner:Dynamic = onigModule.createOnigScanner(['a']);
            scanner.dispose();
            new textmate.onig.WasmOnigLib(onigModule);
        } catch (e:Dynamic) {
            ceramic.Shortcuts.log.warning('vscode-oniguruma is not usable: $e');
            null;
        }
        if (lib == null) {
            done(false);
            return;
        }
        TextMateGrammars.setOnigLib(lib);
        done(true);
    }
    #end

}
