// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Axis;
import gpui.Pixels;

/**
 * The shape of one container. Package private in spirit (Rust
 * `pub(crate)`): every mutation goes through `PaneTree` so normalization
 * always runs.
 *
 * Rust mutates the variant's fields in place; Haxe enum values are
 * immutable, so the arrays are mutated in place and a scalar change
 * (`axis`, `activeIx`) replaces the node's kind.
 */
enum NodeKind {
    Split(axis:Axis, children:Array<PaneNode>, sizes:Array<Null<Pixels>>);
    Tabs(panels:Array<PanelId>, activeIx:Int);
}

/**
 * Read-only projection of a node (Rust `PaneRef<'a>`, which borrows the
 * node's data). The arrays are the node's own: do not mutate them.
 */
enum PaneRef {
    Split(axis:Axis, children:Array<PaneNode>, sizes:Array<Null<Pixels>>);
    Tabs(panels:Array<PanelId>, activeIx:Int);
}

class PaneNode {

    final nodeId:NodeId;

    @:allow(gpui.base.dock)
    var kindValue:NodeKind;

    @:allow(gpui.base.dock)
    function new(id:NodeId, kind:NodeKind) {
        this.nodeId = id;
        this.kindValue = kind;
    }

    public inline function id():NodeId {
        return nodeId;
    }

    public function kind():PaneRef {
        return switch kindValue {
            case Split(axis, children, sizes): PaneRef.Split(axis, children, sizes);
            case Tabs(panels, activeIx): PaneRef.Tabs(panels, activeIx);
        }
    }

    @:allow(gpui.base.dock)
    inline function kindRef():NodeKind {
        return kindValue;
    }

    /**
     * Depth-first pre-order walk over this node and its descendants.
     */
    public function walk(f:(PaneNode) -> Void):Void {
        f(this);
        switch kindValue {
            case Split(_, children, _):
                for (child in children) child.walk(f);
            case Tabs(_, _):
        }
    }

    /**
     * Rust derived `Clone`: a deep copy.
     */
    public function clone():PaneNode {
        return new PaneNode(nodeId, switch kindValue {
            case Split(axis, children, sizes): NodeKind.Split(axis, [for (child in children) child.clone()], sizes.copy());
            case Tabs(panels, activeIx): NodeKind.Tabs(panels.copy(), activeIx);
        });
    }

    /**
     * Rust derived `PartialEq`.
     */
    public function equals(other:PaneNode):Bool {
        if (nodeId != other.nodeId) return false;
        return switch [kindValue, other.kindValue] {
            case [Split(axisA, childrenA, sizesA), Split(axisB, childrenB, sizesB)]:
                if (axisA != axisB || childrenA.length != childrenB.length || !sameSizes(sizesA, sizesB)) return false;
                for (i in 0...childrenA.length) if (!childrenA[i].equals(childrenB[i])) return false;
                true;
            case [Tabs(panelsA, activeA), Tabs(panelsB, activeB)]:
                activeA == activeB && samePanels(panelsA, panelsB);
            case _: false;
        }
    }

    @:allow(gpui.base.dock)
    static function sameSizes(a:Array<Null<Pixels>>, b:Array<Null<Pixels>>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            final x = a[i];
            final y = b[i];
            if (x == null ? y != null : (y == null || (x : Float) != (y : Float))) return false;
        }
        return true;
    }

    static function samePanels(a:Array<PanelId>, b:Array<PanelId>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) if (a[i] != b[i]) return false;
        return true;
    }

}
