// Ported from lsp-types 0.97 (src/lib.rs, Range), as used by gpui-kit 0.8.1: crates/base/src/input/editor
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A range in a text document expressed as (zero-based) start and end
 * positions (lsp_types `Range`, renamed: it clashes with `glaze.Range`).
 * Rust's `Range<Position>` of a `Diagnostic` is this type too.
 */
class LspRange {

    public final start:LspPosition;

    public final end:LspPosition;

    public inline function new(start:LspPosition, end:LspPosition) {
        this.start = start;
        this.end = end;
    }

    public function equals(other:Null<LspRange>):Bool {
        return other != null && start.equals(other.start) && end.equals(other.end);
    }

    public function toString():String {
        return 'Range { start: ' + start + ', end: ' + end + ' }';
    }

}
