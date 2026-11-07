// Ported from gpui-pre 0.3.10: src/taffy.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A unique identifier for a layout node, generated when requesting a layout from Taffy.
 */
abstract LayoutId(Int) from Int to Int {

    public inline function new(id:Int) {
        this = id;
    }

    @:from static inline function fromNodeId(nodeId:taffy.tree.NodeId):LayoutId {
        return new LayoutId((nodeId : Int));
    }

    @:to inline function toNodeId():taffy.tree.NodeId {
        return new taffy.tree.NodeId(this);
    }

}
