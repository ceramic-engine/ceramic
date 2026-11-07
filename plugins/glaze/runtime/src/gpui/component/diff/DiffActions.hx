// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`actions`, `init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.App;
import gpui.AppContext;
import gpui.KeyBinding;
import gpui.OperatingSystem;
import gpui.base.input.InputActions.Copy;
import gpui.base.input.InputActions.SelectAll;

// Private: bindings serve the focused code body only.
@:action(namespace = diff) class ScrollUp implements gpui.Action {}

@:action(namespace = diff) class ScrollDown implements gpui.Action {}

@:action(namespace = diff) class ScrollLeft implements gpui.Action {}

@:action(namespace = diff) class ScrollRight implements gpui.Action {}

@:action(namespace = diff) class PageUp implements gpui.Action {}

@:action(namespace = diff) class PageDown implements gpui.Action {}

@:action(namespace = diff) class First implements gpui.Action {}

@:action(namespace = diff) class Last implements gpui.Action {}

@:action(namespace = diff) class ExtendUp implements gpui.Action {}

@:action(namespace = diff) class ExtendDown implements gpui.Action {}

/**
 * The key bindings of the diff (Rust `diff::init`), in a module of their own
 * so that `Component.init` registers them without loading the diff itself.
 */
class DiffActions {

    public static inline final CONTEXT:String = 'Diff';

    @:allow(gpui.component)
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
