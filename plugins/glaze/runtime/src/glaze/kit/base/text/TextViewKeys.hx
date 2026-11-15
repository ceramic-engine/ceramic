// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.input.InputActions.SelectAll;

/**
 * The key bindings of the text views (Rust `text::state::init`), in a module
 * of their own so that `Base.init` registers them without loading
 * `TextViewState`.
 */
class TextViewKeys {

    public static inline final CONTEXT = 'TextView';

    public static function init(cx:App):Void {
        final macos = OperatingSystem.current == Mac;
        cx.bindKeys([
            new KeyBinding(macos ? 'cmd-c' : 'ctrl-c', new Copy(), CONTEXT),
            new KeyBinding(macos ? 'cmd-a' : 'ctrl-a', new SelectAll(), CONTEXT),
        ]);
    }

}
