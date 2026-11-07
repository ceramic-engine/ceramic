// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.ElementId;

/**
 * Identifies one run of rendered text across re-parses: the source start of
 * the block that owns it, plus the cell ordinal inside a table.
 *
 * Keys order as their leaves appear in the document (`compare`).
 */
class TextLeafKey {

    final _blockStart:Int;

    final ordinal:Int;

    inline function new(blockStart:Int, ordinal:Int) {
        _blockStart = blockStart;
        this.ordinal = ordinal;
    }

    public static inline function block(start:Int):TextLeafKey {
        return new TextLeafKey(start, 0);
    }

    public static inline function tableCell(tableStart:Int, ordinal:Int):TextLeafKey {
        return new TextLeafKey(tableStart, ordinal + 1);
    }

    public inline function blockStart():Int {
        return _blockStart;
    }

    /**
     * The index of the table cell the leaf is, among all the cells of its
     * table, or `null` when it is not a cell.
     */
    public inline function cellIx():Null<Int> {
        return ordinal > 0 ? ordinal - 1 : null;
    }

    /** The same leaf in its block moved to start at `blockStart`. */
    public inline function movedTo(blockStart:Int):TextLeafKey {
        return new TextLeafKey(blockStart, ordinal);
    }

    public inline function equals(other:Null<TextLeafKey>):Bool {
        return other != null && other._blockStart == _blockStart && other.ordinal == ordinal;
    }

    /** `Option<TextLeafKey>` equality. */
    public static function eq(a:Null<TextLeafKey>, b:Null<TextLeafKey>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    /** Rust's derived `Ord`: by block start, then ordinal. */
    public static function compare(a:TextLeafKey, b:TextLeafKey):Int {
        if (a._blockStart != b._blockStart) return a._blockStart < b._blockStart ? -1 : 1;
        if (a.ordinal != b.ordinal) return a.ordinal < b.ordinal ? -1 : 1;
        return 0;
    }

    /**
     * The key as an element id, for a leaf that needs element state or an
     * accessibility identity: unique per leaf (Rust `ElementId::OpaqueId`).
     */
    public function toElementId():ElementId {
        return ElementId.Name('text-leaf-$_blockStart-$ordinal');
    }

    public function toString():String {
        return 'TextLeafKey { block_start: $_blockStart, ordinal: $ordinal }';
    }

}
