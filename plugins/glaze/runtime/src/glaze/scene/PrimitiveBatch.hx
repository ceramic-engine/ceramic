// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

/**
 * A run of primitives of the same kind (and same atlas texture for
 * sprites) that can be drawn together: indices `start` (inclusive) to
 * `end` (exclusive) in the matching `Scene` array.
 */
class PrimitiveBatch {

    public var kind:PrimitiveKind = Quad;

    public var start:Int = 0;

    public var end:Int = 0;

    /** Atlas texture index for sprite batches, -1 otherwise */
    public var textureIndex:Int = -1;

    public function new() {}

    public inline function length():Int {
        return end - start;
    }

    public function toString():String {
        return 'PrimitiveBatch($kind, $start..$end' + (textureIndex >= 0 ? ', texture $textureIndex)' : ')');
    }

}
