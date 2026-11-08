// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`actions`, `init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.input.InputActions.SelectAll;

// Private: bindings serve the focused code body only.
@:action(namespace = diff) class ScrollUp implements glaze.Action {}

@:action(namespace = diff) class ScrollDown implements glaze.Action {}

@:action(namespace = diff) class ScrollLeft implements glaze.Action {}

@:action(namespace = diff) class ScrollRight implements glaze.Action {}

@:action(namespace = diff) class PageUp implements glaze.Action {}

@:action(namespace = diff) class PageDown implements glaze.Action {}

@:action(namespace = diff) class First implements glaze.Action {}

@:action(namespace = diff) class Last implements glaze.Action {}

@:action(namespace = diff) class ExtendUp implements glaze.Action {}

@:action(namespace = diff) class ExtendDown implements glaze.Action {}

/**
 * The key bindings of the diff (Rust `diff::init`), in a module of their own
 * so that `Kit.init` registers them without loading the diff itself.
 */
class DiffActions {

    public static inline final CONTEXT:String = 'Diff';

    @:allow(glaze.kit)
    static function init(cx:AppContext):Void {
        final mac = OperatingSystem.current.isMac();
        (cx : App).bindKeys([
            new KeyBinding('up', new ScrollUp(), CONTEXT),
            new KeyBinding('down', new ScrollDown(), CONTEXT),
            new KeyBinding('left', new ScrollLeft(), CONTEXT),
            new KeyBinding('right', new ScrollRight(), CONTEXT),
            new KeyBinding('pageup', new PageUp(), CONTEXT),
            new KeyBinding('pagedown', new PageDown(), CONTEXT),
            new KeyBinding('home', new First(), CONTEXT),
            new KeyBinding('end', new Last(), CONTEXT),
            new KeyBinding('shift-up', new ExtendUp(), CONTEXT),
            new KeyBinding('shift-down', new ExtendDown(), CONTEXT),
            new KeyBinding(mac ? 'cmd-c' : 'ctrl-c', new Copy(), CONTEXT),
            new KeyBinding(mac ? 'cmd-a' : 'ctrl-a', new SelectAll(), CONTEXT),
        ]);
    }

}
