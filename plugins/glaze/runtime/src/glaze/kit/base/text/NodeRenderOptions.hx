// Ported from gpui-kit 0.8.1: crates/base/src/text/document.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/**
 * Options of one block render (Rust `NodeRenderOptions`, a `Copy` struct:
 * use `copy()` where Rust copies it).
 */
class NodeRenderOptions {

    public var ix:Int = 0;
    public var inList:Bool = false;
    public var todo:Bool = false;
    public var ordered:Bool = false;
    public var listStart:Null<Int> = null;
    public var depth:Int = 0;
    public var isLast:Bool = false;

    /**
     * Whether this block opens its flow (the document or a blockquote) and
     * so takes no gap above it. An HTML block container passes it on to its
     * own first child.
     */
    public var isFirst:Bool = false;

    /**
     * The previous sibling block, whose own bottom gap counts toward the gap
     * above a heading or a rule.
     */
    public var prev:PrevBlock = Other;

    public function new() {}

    public function copy():NodeRenderOptions {
        final o = new NodeRenderOptions();
        o.ix = ix;
        o.inList = inList;
        o.todo = todo;
        o.ordered = ordered;
        o.listStart = listStart;
        o.depth = depth;
        o.isLast = isLast;
        o.isFirst = isFirst;
        o.prev = prev;
        return o;
    }

    /** A copy with `isLast` set (Rust builder `is_last`, renamed: clashes with the field). */
    public function withIsLast(isLast:Bool):NodeRenderOptions {
        final o = copy();
        o.isLast = isLast;
        return o;
    }

}
