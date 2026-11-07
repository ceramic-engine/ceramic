// Ported from gpui-kit 0.8.1: crates/base/src/input/base/native.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Action;

/**
 * Presentation-independent context-menu model produced by the editor. The
 * styled layer draws it as a popup menu (`glaze.kit.menu`).
 *
 * Not ported: the macOS `set_text_content_type` (it installs an
 * `NSTextContent` protocol on GPUI's AppKit view through the Objective-C
 * runtime, which the Ceramic backends do not have).
 */
class NativeMenu {

    public final items:Array<NativeMenuItem> = [];

    public function new() {}

    public function menu(label:String, action:Action):NativeMenu {
        return menuWithDisabled(label, false, action);
    }

    public function menuWithDisabled(label:String, disabled:Bool, action:Action):NativeMenu {
        items.push(NativeMenuItem.Action(label, disabled, action));
        return this;
    }

    public function separator():NativeMenu {
        items.push(NativeMenuItem.Separator);
        return this;
    }

}

enum NativeMenuItem {
    Separator;
    Action(label:String, disabled:Bool, action:glaze.Action);
}
