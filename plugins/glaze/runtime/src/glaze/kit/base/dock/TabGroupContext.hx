// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.App;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;

/**
 * What a skin needs to draw a tab group, and the callbacks it invokes rather
 * than reimplementing behavior.
 */
class TabGroupContext {

    final nodeValue:NodeId;

    final panelsValue:Array<PanelView>;

    final activePanelValue:Null<PanelView>;

    final activeIxValue:Int;

    final zoomed:Bool;

    final constraints:TabGroupConstraints;

    final draggable:Bool;

    final droppable:Bool;

    final activePanelClosable:Bool;

    final dropIndicatorValue:Null<DropIndicator>;

    final onSelectTab:(Int, Window, App) -> Void;

    final onClose:(PanelId, Window, App) -> Void;

    final onToggleZoom:(Window, App) -> Void;

    final onDropPanel:(DragPanel, Null<Int>, Bool, Window, App) -> Void;

    final onDropItem:(AnyDrag, Null<Placement>, Window, App) -> Void;

    @:allow(glaze.kit.base.dock)
    function new(node:NodeId, panels:Array<PanelView>, activePanel:Null<PanelView>, activeIx:Int, zoomed:Bool,
            constraints:TabGroupConstraints, draggable:Bool, droppable:Bool, activePanelClosable:Bool,
            dropIndicator:Null<DropIndicator>, onSelectTab:(Int, Window, App) -> Void, onClose:(PanelId, Window, App) -> Void,
            onToggleZoom:(Window, App) -> Void, onDropPanel:(DragPanel, Null<Int>, Bool, Window, App) -> Void,
            onDropItem:(AnyDrag, Null<Placement>, Window, App) -> Void) {
        this.nodeValue = node;
        this.panelsValue = panels;
        this.activePanelValue = activePanel;
        this.activeIxValue = activeIx;
        this.zoomed = zoomed;
        this.constraints = constraints;
        this.draggable = draggable;
        this.droppable = droppable;
        this.activePanelClosable = activePanelClosable;
        this.dropIndicatorValue = dropIndicator;
        this.onSelectTab = onSelectTab;
        this.onClose = onClose;
        this.onToggleZoom = onToggleZoom;
        this.onDropPanel = onDropPanel;
        this.onDropItem = onDropItem;
    }

    /**
     * The `Tabs` node this group mirrors, for a skin that needs to name the
     * group in a drag payload or a drop target.
     */
    public inline function node():NodeId {
        return nodeValue;
    }

    /**
     * Every panel in the group, in tab order, visible or not. A skin filters
     * with `PanelView.visible` when it draws.
     */
    public inline function panels():Array<PanelView> {
        return panelsValue;
    }

    public inline function activeIx():Int {
        return activeIxValue;
    }

    /**
     * The panel on screen, which is the displayed tab unless that panel has
     * gone invisible.
     */
    public inline function activePanel():Null<PanelView> {
        return activePanelValue;
    }

    public inline function dropIndicator():Null<DropIndicator> {
        return dropIndicatorValue;
    }

    public inline function isZoomed():Bool {
        return zoomed;
    }

    public inline function isCollapsed():Bool {
        return constraints.isCollapsed();
    }

    /**
     * Whether the active panel can be closed.
     */
    public inline function isClosable():Bool {
        return activePanelClosable;
    }

    /**
     * Whether `panel` can be closed from this group. Uses the same constraints
     * as `TabGroup.closePanel`, including the panel's own `closable` flag.
     */
    public function isPanelClosable(panel:PanelId, cx:App):Bool {
        if (!constraints.isClosable() || !draggable) return false;
        for (candidate in panelsValue) {
            if (candidate.panelId(cx) == panel && candidate.closable(cx)) return true;
        }
        return false;
    }

    public inline function isLocked():Bool {
        return constraints.isLocked() || zoomed;
    }

    public inline function isDraggable():Bool {
        return draggable;
    }

    public inline function isDroppable():Bool {
        return droppable;
    }

    public function selectTab(ix:Int, window:Window, cx:App):Void {
        onSelectTab(ix, window, cx);
    }

    public function close(panel:PanelId, window:Window, cx:App):Void {
        onClose(panel, window, cx);
    }

    public function toggleZoom(window:Window, cx:App):Void {
        onToggleZoom(window, cx);
    }

    /**
     * The drag payload for the tab at `ix`, for a skin wiring `onDrag` onto
     * its tabs. `null` when `ix` names no panel.
     */
    public function dragPanel(ix:Int, cx:App):Null<DragPanel> {
        return ix >= 0 && ix < panelsValue.length ? new DragPanel(panelsValue[ix].panelId(cx), nodeValue) : null;
    }

    /**
     * A panel dropped on the tab bar. `ix` names the slot it lands in, or
     * `null` to append; `activate` decides whether it becomes displayed.
     */
    public function dropPanel(drag:DragPanel, ix:Null<Int>, activate:Bool, window:Window, cx:App):Void {
        onDropPanel(drag, ix, activate, window, cx);
    }

    /**
     * A host-owned drag dropped on the tab bar. `placement` is `null` to
     * merge into this group rather than split beside it.
     */
    public function dropItem(item:AnyDrag, placement:Null<Placement>, window:Window, cx:App):Void {
        onDropItem(item, placement, window, cx);
    }

}
