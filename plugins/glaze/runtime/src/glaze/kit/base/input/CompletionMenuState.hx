// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The content of the completion menu.
 */
class CompletionMenuState {

    public var open:Bool = false;

    public var triggerStartOffset:Null<Int> = null;

    public var query:String = '';

    public var items:Array<CompletionItem> = [];

    var _revision:Int = 0;

    public function new() {}

    public function clone():CompletionMenuState {
        final result = new CompletionMenuState();
        result.open = open;
        result.triggerStartOffset = triggerStartOffset;
        result.query = query;
        result.items = items.copy();
        result._revision = _revision;
        return result;
    }

    /**
     * Bumped whenever the content changes.
     *
     * A renderer that mirrors this menu compares revisions to decide whether
     * to rebuild, so it never has to compare the item list itself.
     */
    public inline function revision():Int {
        return _revision;
    }

    /** Rust `wrapping_add(1)` on a `u64` (wraps at 32 bits here) */
    public function bump():Void {
        _revision = _revision + 1;
    }

}
