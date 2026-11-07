// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * The content of the code action menu.
 */
class CodeActionMenuState {

    public var open:Bool = false;

    public var items:Array<CodeActionItem> = [];

    var _revision:Int = 0;

    public function new() {}

    public function clone():CodeActionMenuState {
        final result = new CodeActionMenuState();
        result.open = open;
        result.items = items.copy();
        result._revision = _revision;
        return result;
    }

    /** Bumped whenever the content changes. See `CompletionMenuState.revision`. */
    public inline function revision():Int {
        return _revision;
    }

    public function bump():Void {
        _revision = _revision + 1;
    }

}
