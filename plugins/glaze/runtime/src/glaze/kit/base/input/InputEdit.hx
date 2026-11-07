// Ported from gpui-kit 0.8.1: crates/base/src/input/base/rope_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Parser-independent description of an incremental text replacement.
 */
class InputEdit {

    public final startByte:Int;

    public final oldEndByte:Int;

    public final newEndByte:Int;

    public final startPosition:RopePoint;

    public final oldEndPosition:RopePoint;

    public final newEndPosition:RopePoint;

    public function new(startByte:Int, oldEndByte:Int, newEndByte:Int, startPosition:RopePoint, oldEndPosition:RopePoint, newEndPosition:RopePoint) {
        this.startByte = startByte;
        this.oldEndByte = oldEndByte;
        this.newEndByte = newEndByte;
        this.startPosition = startPosition;
        this.oldEndPosition = oldEndPosition;
        this.newEndPosition = newEndPosition;
    }

}
