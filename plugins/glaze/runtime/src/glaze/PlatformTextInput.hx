// Ported from gpui-pre 0.3.10: src/platform.rs (the text input part of `PlatformWindow`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * What a window tells its platform about text input (Rust `PlatformWindow`
 * methods). Set with `window.textInputPlatform`: `TextInputBridge` drives
 * Ceramic's text editing (`input.startTextEditing()`...) from it, tests
 * record the calls (like GPUI's `TestWindow`).
 *
 * The input handler itself is not pushed: the platform takes it with
 * `window.takeInputHandler()` when it needs it and gives it back with
 * `window.setInputHandler()`.
 */
interface PlatformTextInput {

    /**
     * Apply the focused text region's configuration to the platform's text
     * input session. Called only when the configuration changes.
     */
    function setTextInputConfiguration(configuration:TextInputConfiguration):Void;

    /**
     * The text input state changed (focus gained or lost, selection or
     * content changed by the app).
     */
    function textInputStateChanged(change:TextInputStateChange):Void;

    /**
     * Where the IME candidate window should go, in window coordinates
     * (`window.invalidateCharacterCoordinates()`).
     */
    function updateImePosition(bounds:Bounds):Void;

}
