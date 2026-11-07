// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.DragMoveEvent;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Point;
import gpui.Render;
import gpui.SpringMath;
import gpui.WeakEntity;
import gpui.Window;
import gpui.base.Geometry.Placement;

import gpui.Prelude.*;

using gpui.base.Observe;

/**
 * A tab group's behavior, with no appearance of its own.
 *
 * It owns the panel list mirrored from the layout tree, the displayed index,
 * the focus handle, drag and drop hit state, and the zoom flag. Everything
 * visible is produced by the `TabGroupRenderer` the host installs.
 *
 * The group holds no handle on its container. What the container knows (the
 * facts in `TabGroupConstraints`) is pushed in, and what the group needs done
 * is emitted as a `TabGroupEvent`. That keeps a group constructible, and
 * testable, on its own.
 */
class TabGroup extends Model implements Render {

    final nodeValue:NodeId;

    /**
     * Handed to the callbacks in `TabGroupContext`, which are built from a
     * plain `App` and so cannot ask for it.
     */
    final self:WeakEntity<TabGroup>;

    var panelsValue:Array<PanelView> = [];

    var activeIxValue:Int = 0;

    var zoomed:Bool = false;

    var constraints:TabGroupConstraints;

    final ownFocusHandle:FocusHandle;

    @:allow(gpui.base.dock, tests)
    final active:ActiveTracker = new ActiveTracker();

    @:allow(gpui.base.dock, tests)
    var dropIndicator:Null<DropIndicator> = null;

    var renderer:TabGroupRenderer;

    /**
     * Only a container builds groups: a group is the entity mirror of one
     * `Tabs` node, and it is created when that node first appears in the
     * tree. `DockArea` is the only caller outside tests.
     */
    @:allow(gpui.base.dock, tests)
    function new(node:NodeId, window:Window, cx:Context<TabGroup>) {
        super();
        this.nodeValue = node;
        this.self = cx.weakEntity();
        // A group that no container has placed yet can do nothing.
        this.constraints = TabGroupConstraints.sealed();
        this.ownFocusHandle = cx.focusHandle();
        this.renderer = new BareTabGroup();
    }

    public function withRenderer(renderer:TabGroupRenderer):TabGroup {
        this.renderer = renderer;
        return this;
    }

    /**
     * The `Tabs` node this group mirrors.
     */
    public inline function node():NodeId {
        return nodeValue;
    }

    public inline function panels():Array<PanelView> {
        return panelsValue;
    }

    public inline function activeIx():Int {
        return activeIxValue;
    }

    /**
     * The panel currently on screen, which is the displayed tab unless it has
     * gone invisible, in which case rendering falls back to the first visible
     * panel.
     */
    public function activePanel(cx:App):Null<PanelView> {
        if (activeIxValue >= panelsValue.length) return null;
        final panel = panelsValue[activeIxValue];
        if (panel.visible(cx)) return panel;
        final visible = visiblePanels(cx);
        return visible.length > 0 ? visible[0] : null;
    }

    public inline function isZoomed():Bool {
        return zoomed;
    }

    public inline function isCollapsed():Bool {
        return constraints.isCollapsed();
    }

    /**
     * Whether closing this group's displayed panel is allowed at all: the
     * container must permit it, the group must have somewhere to go, and the
     * displayed panel must itself be closable.
     */
    public function isClosable(cx:App):Bool {
        if (!constraints.isClosable() || !draggable(cx)) return false;
        final panel = activePanel(cx);
        return panel != null && panel.closable(cx);
    }

    /**
     * Display `ix`, if it names a tab that is not already displayed.
     */
    public function selectTab(ix:Int, window:Window, cx:Context<TabGroup>):Void {
        if (ix >= panelsValue.length || ix == activeIxValue) return;

        activeIxValue = ix;
        focusActivePanel(window, cx);
        scheduleActiveSync(window, cx);
        cx.emit(TabGroupEvent.ActiveChanged(ix));
        cx.notify();
    }

    /**
     * Ask the container to close `panel`. Nothing happens for a panel that is
     * not in this group, or when either the group or the panel refuses.
     */
    public function closePanel(panel:PanelId, cx:Context<TabGroup>):Void {
        if (!constraints.isClosable()) return;
        // A dock's last group has nowhere to go and must stay.
        if (!draggable(cx.app)) return;

        var closable = false;
        for (candidate in panelsValue) {
            if (candidate.panelId(cx.app) == panel && candidate.closable(cx.app)) {
                closable = true;
                break;
            }
        }
        if (!closable) return;

        cx.emit(TabGroupEvent.ClosePanel(panel));
        cx.notify();
    }

    public function toggleZoom(window:Window, cx:Context<TabGroup>):Void {
        setZoomed(!zoomed, window, cx);
    }

    /**
     * A snapshot of everything a skin needs to draw this group.
     */
    public function context(cx:App):TabGroupContext {
        final group = self;
        return new TabGroupContext(
            nodeValue,
            panelsValue.copy(),
            activePanel(cx),
            activeIxValue,
            zoomed,
            constraints,
            draggable(cx),
            droppable(),
            isClosable(cx),
            // A stale indicator would otherwise outlive a drag that was
            // cancelled while hovering this group.
            cx.hasActiveDrag() ? dropIndicator : null,
            (ix, window, cx) -> group.tryUpdate(cx, (group, cx) -> group.selectTab(ix, window, cx)),
            (panel, _, cx) -> group.tryUpdate(cx, (group, cx) -> group.closePanel(panel, cx)),
            (window, cx) -> group.tryUpdate(cx, (group, cx) -> group.toggleZoom(window, cx)),
            (drag, ix, activate, _, cx) -> group.tryUpdate(cx, (group, cx) -> group.onDrop(drag, ix, activate, cx)),
            (item, placement, _, cx) -> group.tryUpdate(cx, (group, cx) -> group.emitDragDrop(item, placement, cx))
        );
    }

/// What the container pushes into a group, and reads back out of it.

    /**
     * Mirror one `Tabs` node's membership and displayed index into this
     * group. `onAddedTo` fires for arrivals; departures are silent here
     * because only the container can tell a move from a removal.
     */
    @:allow(gpui.base.dock, tests)
    function syncFromTree(panels:Array<PanelView>, activeIx:Int, window:Window, cx:Context<TabGroup>):Void {
        final group = cx.weakEntity();
        final existing = [for (panel in panelsValue) panel.panelId(cx.app)];
        for (panel in panels) {
            if (!existing.contains(panel.panelId(cx.app))) {
                panel.onAddedTo(group, window, cx.app);
            }
        }

        panelsValue = panels;
        final last = panelsValue.length > 0 ? panelsValue.length - 1 : 0;
        activeIxValue = activeIx < last ? activeIx : last;
        scheduleActiveSync(window, cx);
        cx.notify();
    }

    /**
     * Replace everything the container knows about this group's place in the
     * dock, in one call.
     */
    @:allow(gpui.base.dock, tests)
    function setConstraints(constraints:TabGroupConstraints, window:Window, cx:Context<TabGroup>):Void {
        if (this.constraints.equals(constraints)) return;

        // Collapsing takes the displayed panel off screen, which the
        // active-state contract counts as no panel being displayed.
        final collapseChanged = this.constraints.isCollapsed() != constraints.isCollapsed();
        this.constraints = constraints;
        if (collapseChanged) {
            scheduleActiveSync(window, cx);
        }
        cx.notify();
    }

    /**
     * Zoom this group in or out, in full: the flag flips, the displayed
     * panel is told, and the container is asked to install or clear the
     * zoomed view.
     *
     * Zooming in is refused, leaving the flag alone, when there is no
     * displayed panel or that panel is not zoomable. Zooming out is never
     * refused: a group that became unzoomable while zoomed still has to be
     * able to give the dock back.
     */
    @:allow(gpui.base.dock, tests)
    function setZoomed(zoomed:Bool, window:Window, cx:Context<TabGroup>):Void {
        if (this.zoomed == zoomed) return;
        final panel = activePanel(cx.app);
        if (zoomed && !(panel != null && panel.zoomable(cx.app))) return;

        this.zoomed = zoomed;
        cx.emit(zoomed ? TabGroupEvent.ZoomIn : TabGroupEvent.ZoomOut);

        // Delivered outside this update so a `setZoomed` handler may call
        // back into the group. The old `TabPanel` sent this to itself, where
        // `Panel::set_zoomed` defaulted to a no-op, so no panel ever heard it.
        if (panel != null) {
            cx.spawn((_, acx) -> {
                if (!window.isDestroyed()) {
                    acx.update(cx -> panel.setZoomed(zoomed, window, cx));
                }
                return null;
            });
        }
        cx.notify();
    }

    /**
     * What this group last told `panel` about being active, for handing to
     * `seedActive` on the group it is moving to.
     */
    @:allow(gpui.base.dock, tests)
    function lastNotifiedActive(panel:PanelId):Null<Bool> {
        return active.lastNotified(panel);
    }

    /**
     * Record what an arriving panel already believes, so a move between
     * groups does not read as a fresh activation.
     */
    @:allow(gpui.base.dock, tests)
    function seedActive(panel:PanelId, active:Bool):Void {
        this.active.seed(panel, active);
    }

/// Internals

    /**
     * Every visible panel, in tab order.
     */
    function visiblePanels(cx:App):Array<PanelView> {
        return [for (panel in panelsValue) if (panel.visible(cx)) panel];
    }

    /**
     * A locked group cannot be rearranged. Zooming locks it too: a zoomed
     * group is the only thing on screen, so there is nowhere to drop.
     */
    function isLocked():Bool {
        return constraints.isLocked() || zoomed;
    }

    /**
     * True when this group holds the last visible panel that anything could
     * be rearranged around. Only visible panels count, so a hidden panel does
     * not keep the last visible one draggable and leave the dock empty.
     */
    function isLastPanel(cx:App):Bool {
        return constraints.isAlone() && visiblePanels(cx).length <= 1;
    }

    function draggable(cx:App):Bool {
        return !isLocked() && !isLastPanel(cx);
    }

    function droppable():Bool {
        return !isLocked();
    }

    function focusActivePanel(window:Window, cx:Context<TabGroup>):Void {
        final panel = activePanel(cx.app);
        if (panel != null) {
            panel.focusHandle(cx.app).focus(window, cx.app);
        }
    }

    /**
     * Queue one reconcile per frame that notifies panels of their frame-end
     * net active state. A spawned task, not `defer`, so it runs after every
     * same-frame mutation including a deferred collapse.
     */
    function scheduleActiveSync(window:Window, cx:Context<TabGroup>):Void {
        if (!active.scheduleSync()) return;

        cx.spawn((group, acx) -> {
            if (window.isDestroyed()) return null;
            acx.update(cx -> {
                var changes:Null<Array<{panel:PanelView, active:Bool}>> = null;
                if (!group.tryUpdate(cx, (group, cx) -> changes = group.reconcileActive(cx.app))) return;
                // Dispatched outside the group's update so a `setActive`
                // handler may call back into it.
                for (change in changes) {
                    change.panel.setActive(change.active, window, cx);
                }
            });
            return null;
        });
    }

    /**
     * The deliveries this frame owes, deactivations first. The displayed slot
     * is `activeIx` even when the panel there is invisible: rendering falls
     * back to another panel, but the active-state contract does not.
     */
    function reconcileActive(cx:App):Array<{panel:PanelView, active:Bool}> {
        active.syncFinished();

        final ids = [for (panel in panelsValue) panel.panelId(cx)];
        final displayed:Null<PanelId> = constraints.isCollapsed() ? null : (activeIxValue < ids.length ? ids[activeIxValue] : null);

        final result:Array<{panel:PanelView, active:Bool}> = [];
        for (change in active.reconcile(ids, displayed)) {
            final ix = ids.indexOf(change.panel);
            if (ix >= 0) result.push({panel: panelsValue[ix], active: change.active});
        }
        return result;
    }

    /**
     * Where a dragged panel would land, tracked while it moves over the
     * group's content.
     */
    @:allow(gpui.base.dock, tests)
    function onPanelDragMove(drag:DragMoveEvent<DragPanel>, window:Window, cx:Context<TabGroup>):Void {
        final bounds = drag.bounds;
        if (!bounds.contains(drag.event.position)) {
            clearDropIndicator(cx);
            return;
        }

        final placement = Drag.splitPlacementAt(bounds, drag.event.position);
        final dragged = drag.drag(cx.app);
        // The placeholder flies in from wherever the preview currently is.
        final position = drag.event.position;
        final offset = dragged.dragOffset();
        final source = new DropPlaceholderBounds(
            new Point(SpringMath.f32(SpringMath.f32(position.x - offset.x) - bounds.origin.x),
                SpringMath.f32(SpringMath.f32(position.y - offset.y) - bounds.origin.y)),
            dragged.previewSize());

        syncDropPlaceholder(bounds, placement, dragged.dragSessionId(), source, cx);
    }

    /**
     * Same as `onPanelDragMove`, for a host-owned drag item.
     *
     * A drag item has no dragged tab to fly the placeholder in from, so it
     * starts at its resting position and only animates between placements.
     */
    @:allow(gpui.base.dock, tests)
    function onItemDragMove(drag:DragMoveEvent<AnyDrag>, window:Window, cx:Context<TabGroup>):Void {
        final bounds = drag.bounds;
        if (!bounds.contains(drag.event.position)) {
            clearDropIndicator(cx);
            return;
        }

        final placement = Drag.splitPlacementAt(bounds, drag.event.position);
        final source = DropPlaceholderBounds.forPlacement(bounds, placement);

        syncDropPlaceholder(bounds, placement, Drag.ITEM_DRAG_SESSION_ID, source, cx);
    }

    @:allow(gpui.base.dock, tests)
    function syncDropPlaceholder(bounds:Bounds, placement:Null<Placement>, dragSessionId:Int, source:DropPlaceholderBounds,
            cx:Context<TabGroup>):Void {
        final to = DropPlaceholderBounds.forPlacement(bounds, placement);
        final indicator = dropIndicator;

        final restart = indicator == null || indicator.dragSessionId() != dragSessionId || indicator.placement() != placement;

        var from:DropPlaceholderBounds;
        var epoch:Int;
        if (!restart && indicator != null) {
            from = indicator.from();
            epoch = indicator.epoch();
        }
        else if (indicator != null) {
            from = indicator.dragSessionId() == dragSessionId ? indicator.to() : source;
            epoch = indicator.epoch() + 1;
        }
        else {
            from = source;
            epoch = 0;
        }

        dropIndicator = new DropIndicator(bounds, placement, from, to, dragSessionId, epoch);
        cx.notify();
    }

    function clearDropIndicator(cx:Context<TabGroup>):Void {
        if (dropIndicator != null) {
            dropIndicator = null;
            cx.notify();
        }
    }

    /**
     * Report a host-owned drag landing on this group. `placement` is `null`
     * to merge into the tab group instead of splitting.
     */
    @:allow(gpui.base.dock, tests)
    function emitDragDrop(item:AnyDrag, placement:Null<Placement>, cx:Context<TabGroup>):Void {
        dropIndicator = null;
        cx.emit(TabGroupEvent.DragDrop(item.clone(), new DropTarget(nodeValue, placement)));
        cx.notify();
    }

    /**
     * Resolve where a dropped panel lands and report it as one move.
     *
     * `ix` names a tab slot, which the tab bar supplies and the content area
     * does not; a slot always merges, so it overrides any split the hovering
     * drag had resolved. `activate` decides whether the arriving panel
     * becomes the displayed tab.
     */
    @:allow(gpui.base.dock, tests)
    function onDrop(drag:DragPanel, ix:Null<Int>, activate:Bool, cx:Context<TabGroup>):Void {
        final indicator = dropIndicator;
        dropIndicator = null;
        final placement:Null<Placement> = ix != null ? null : (indicator != null ? indicator.placement() : null);

        // Dropping a panel back onto its own group is a move only when it
        // splits out of a group holding more than itself, or when it lands on
        // a specific tab slot.
        if (drag.source() == nodeValue && ix == null && (placement == null || panelsValue.length == 1)) {
            cx.notify();
            return;
        }

        final target = placement != null
            ? InsertTarget.Split(nodeValue, placement, null)
            : InsertTarget.Tabs(nodeValue, ix, activate);

        cx.emit(TabGroupEvent.Drop(drag.panel(), drag.source(), target));
        cx.notify();
    }

    /**
     * Rust `Focusable::focus_handle`: the displayed panel's handle, or the
     * group's own when it displays nothing.
     */
    public function focusHandle(cx:App):FocusHandle {
        final panel = activePanel(cx);
        return panel != null ? panel.focusHandle(cx) : ownFocusHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final context = this.context(cx.app);
        final renderer = this.renderer;
        final focusHandle = this.focusHandle(cx.app);
        final droppable = context.isDroppable();
        final indicator = context.dropIndicator();
        final groupCx:Context<TabGroup> = cast cx;

        // Structure, applied around whatever the renderer returns.
        //
        // A column, and not a block: in block layout a child's `flexGrow` is
        // ignored, and the content region below the tab bar resolves to zero
        // height. The hooks run in the original's order: frame, tab bar,
        // content frame, then the panel (or the empty state) and the drop
        // indicator.
        final frame = renderer.frame(context, window, cx.app)
            .testSupport()
            .flex()
            .flexCol()
            .sizeFull()
            .overflowHidden()
            .trackFocus(focusHandle)
            .tabGroup();
        frame.child(renderer.renderTabBar(context, window, cx.app));

        final content = renderer.contentFrame(context, window, cx.app)
            .testSupport()
            .flex()
            .flexCol()
            // The region below the tab bar takes the rest of the group, except
            // in a collapsed one, which is a strip of tabs with no content and
            // must claim no space at all.
            .when(!context.isCollapsed(), el -> el.flex1())
            // A flex item's `min-height` is `auto`; flooring it at zero lets
            // the region win over the height its content wants.
            .minH(px(0.))
            .overflowHidden()
            // Both drag kinds hang off `droppable` alone.
            .when(droppable, el -> el
                .onDragMove(DragPanel, groupCx.listener((group:TabGroup, drag:DragMoveEvent<DragPanel>, window, cx) -> group.onPanelDragMove(drag, window, cx)))
                .onDrop(DragPanel, groupCx.listener((group:TabGroup, drag:DragPanel, _, cx) -> group.onDrop(drag, null, true, cx)))
                .onDragMove(AnyDrag, groupCx.listener((group:TabGroup, drag:DragMoveEvent<AnyDrag>, window, cx) -> group.onItemDragMove(drag, window, cx)))
                .onDrop(AnyDrag, groupCx.listener((group:TabGroup, item:AnyDrag, _, cx) -> {
                    final placement = group.dropIndicator != null ? group.dropIndicator.placement() : null;
                    group.emitDragDrop(item, placement, cx);
                })));

        final activePanel = context.activePanel();
        if (activePanel != null) {
            content.child(renderer.renderActivePanel(activePanel.view(), context, window, cx.app));
        }
        else {
            final empty = renderer.renderEmpty(context, window, cx.app);
            if (empty != null) content.child(empty);
        }
        if (indicator != null) {
            final drawn = renderer.renderDropIndicator(indicator, window, cx.app);
            if (drawn != null) content.child(drawn);
        }

        return frame.child(content);
    }

}
