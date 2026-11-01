// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/builder.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.App;
import gpui.Axis;
import gpui.Entity;
import gpui.Model;
import gpui.Pixels;
import gpui.base.dock.PaneNode;

/**
 * Describes a layout without constructing any entity.
 *
 * Building a layout used to require `window` and `cx` because every node was
 * an entity. Now a layout is data, and `DockArea` reconciles it into entities
 * when it is installed.
 *
 * Misuse (a panel added to a split, a child container added to a tab group,
 * an active index on anything but a tab group) trips an assertion in debug
 * builds and is otherwise ignored.
 */
class DockLayout {

    var kind:BuilderKind;

    function new(kind:BuilderKind) {
        this.kind = kind;
    }

    /**
     * A split whose children sit side by side.
     */
    public static function hSplit():DockLayout {
        return split(Axis.Horizontal);
    }

    /**
     * A split whose children stack.
     */
    public static function vSplit():DockLayout {
        return split(Axis.Vertical);
    }

    /**
     * A tab group: panels stacked one at a time, selected from a tab bar.
     */
    public static function tabs():DockLayout {
        return new DockLayout(BuilderKind.Tabs([], 0));
    }

    static function split(axis:Axis):DockLayout {
        return new DockLayout(BuilderKind.Split(axis, []));
    }

    /**
     * Add a child container to a split. `size` is the child's slot along the
     * split's axis; `null` leaves it unconstrained.
     */
    public function child(child:DockLayout, size:Null<Pixels>):DockLayout {
        switch kind {
            case Split(_, children): children.push({layout: child, size: size});
            case _: debugAssert('child() is only valid on hSplit() or vSplit()');
        }
        return this;
    }

    /**
     * Add a panel to a tab group.
     */
    public function panel<P:Model & Panel>(panel:Entity<P>):DockLayout {
        switch kind {
            case Tabs(panels, _): panels.push({id: PanelId.fromEntityId(panel.entityId()), view: new EntityPanelView(panel)});
            case _: debugAssert('panel() is only valid on tabs()');
        }
        return this;
    }

    /**
     * Add an already-wrapped panel handle to a tab group.
     *
     * The companion to `panel`, for a layer that hands base its own concrete
     * handle rather than a bare entity. `cx` is here because the id has to
     * come from `PanelView.panelId`.
     */
    public function panelView(panel:PanelView, cx:App):DockLayout {
        switch kind {
            case Tabs(panels, _): panels.push({id: panel.panelId(cx), view: panel});
            case _: debugAssert('panelView() is only valid on tabs()');
        }
        return this;
    }

    /**
     * Which tab is displayed. Out-of-range values are clamped by `normalize`
     * once the layout is installed.
     */
    public function activeIndex(ix:Int):DockLayout {
        switch kind {
            case Tabs(panels, _): kind = BuilderKind.Tabs(panels, ix);
            case _: debugAssert('activeIndex() is only valid on tabs()');
        }
        return this;
    }

    static inline function debugAssert(message:String):Void {
        #if debug
        throw message;
        #end
    }

    /**
     * Lower into a tree plus the panel views the area must register, paired
     * with the ids the tree was built from.
     */
    @:allow(gpui.base.dock)
    function build(tree:PaneTree):{node:PaneNode, panels:Array<{id:PanelId, view:PanelView}>} {
        final panels:Array<{id:PanelId, view:PanelView}> = [];
        final node = buildNode(tree, panels);
        return {node: node, panels: panels};
    }

    function buildNode(tree:PaneTree, collected:Array<{id:PanelId, view:PanelView}>):PaneNode {
        final id = tree.allocateNodeId();
        return switch kind {
            case Split(axis, children):
                final nodes:Array<PaneNode> = [];
                final sizes:Array<Null<Pixels>> = [];
                for (child in children) {
                    nodes.push(child.layout.buildNode(tree, collected));
                    sizes.push(child.size);
                }
                new PaneNode(id, NodeKind.Split(axis, nodes, sizes));
            case Tabs(panels, activeIx):
                final ids = [for (panel in panels) panel.id];
                for (panel in panels) collected.push(panel);
                new PaneNode(id, NodeKind.Tabs(ids, activeIx));
        }
    }

}

private enum BuilderKind {
    Split(axis:Axis, children:Array<{layout:DockLayout, size:Null<Pixels>}>);
    Tabs(panels:Array<{id:PanelId, view:PanelView}>, activeIx:Int);
}
