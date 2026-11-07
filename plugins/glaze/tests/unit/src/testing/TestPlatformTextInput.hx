// Ported from gpui-pre 0.3.10: src/platform/test/window.rs (text input part of TestWindow)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package testing;

import glaze.Bounds;
import glaze.PlatformTextInput;
import glaze.TextInputConfiguration;
import glaze.TextInputStateChange;

/**
 * Records what a window tells its platform about text input, like GPUI's
 * `TestWindow` (`text_input_configurations`, `text_input_state_changes`).
 */
class TestPlatformTextInput implements PlatformTextInput {

    public final textInputConfigurations:Array<TextInputConfiguration> = [];

    public final textInputStateChanges:Array<TextInputStateChange> = [];

    public final imePositions:Array<Bounds> = [];

    public function new() {}

    public function setTextInputConfiguration(configuration:TextInputConfiguration):Void {
        textInputConfigurations.push(configuration);
    }

    public function textInputStateChanged(change:TextInputStateChange):Void {
        textInputStateChanges.push(change);
    }

    public function updateImePosition(bounds:Bounds):Void {
        imePositions.push(bounds);
    }

}
