// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.Axis;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Point;
import glaze.Render;
import glaze.SpringMath;
import glaze.Subscription;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.dock.PaneNode;
import glaze.kit.base.resizable.Resizable;
import glaze.kit.base.resizable.ResizablePanelGroup.ResizablePanelEvent;
import glaze.kit.base.resizable.ResizableState;
import glaze.kit.base.resizable.ResizeHandle.ResizeHandleContext;
import glaze.util.MathUtil;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.Observe;

/**
 * The main area of the dock.
 *
 * It owns one `PaneTree` per region and the entity cache that mirrors them:
 * `TabGroup` entities for `Tabs` nodes and `ResizableState` entities for
 * splits, keyed by `NodeId`, plus the panel handles keyed by `PanelId`. After
 * any edit that reports a change it walks the trees, creates entities for ids
 * the cache does not have, drops entries for ids that are gone (telling those
 * panels `Panel.onRemoved`), pushes sizes and active indices into the
 * survivors, and emits `DockEvent.LayoutChanged`. Nothing else turns a tree
 * edit into live entities. Because node ids are stable, a steady-state pass
 * creates and drops nothing.
 *
 * Rust keeps the docks and the caches in `HashMap`s, whose iteration order is
 * random; the port iterates docks in insertion order and departed panels by
 * id, which is one of the orders the original can take.
 */
@:access(glaze.kit.base.resizable.ResizableState)
class DockArea extends Model implements Render {

    /**
     * A closed bottom dock keeps this much, so its tab bar stays clickable. A
     * closed side dock keeps nothing: there is no tab bar left to click at
     * zero width, and reopening it is the application's to offer.
     */
    public static inline final CLOSED_BOTTOM_STRIP:Pixels = 29.;

    final idValue:String;

    var versionValue:Null<Int>;

    var boundsValue:Bounds = new Bounds();

    final self:WeakEntity<DockArea>;

    var center:PaneTree;

    /**
     * Rust `HashMap<DockPlacement, DockRegion>`, in insertion order.
     */
    final docks:Array<DockRegion> = [];

    @:allow(tests)
    final groups:Map<Int, CachedGroup> = new Map();

    @:allow(tests)
    final splits:Map<Int, CachedSplit> = new Map();

    @:allow(tests)
    final panels:Map<Int, PanelView> = new Map();

    var locked:Bool = false;

    /**
     * What fills the whole area, when something does: always a tab group
     * (Rust `Zoomed::Group(NodeId)`), rendered whole through its own renderer.
     *
     * A zoom names a container, never the panel inside it: the zoomed group
     * keeps its tab bar, which is where the control that zooms back out lives.
     */
    var zoomed:Null<NodeId> = null;

    final focusHandleValue:FocusHandle;

    var renderer:DockAreaRenderer;

    /**
     * An empty area that draws nothing but its panels.
     *
     * `id` names the area for the host's own persistence; `version` is
     * written into `dump` and read back by `load`, for a host that wants to
     * reject or migrate a layout an older build wrote.
     *
     * Install appearance with `withRenderer`.
     */
    public function new(id:String, version:Null<Int>, window:Window, cx:Context<DockArea>) {
        super();
        PanelRegistry.init(cx.app);

        this.idValue = id;
        this.versionValue = version;
        this.self = cx.weakEntity();
        this.center = new PaneTree(RootKind.Split);
        this.focusHandleValue = cx.focusHandle();
        this.renderer = new BareDockArea();
    }

    /**
     * Install the appearance for this area and everything under it: the
     * renderer also supplies the `TabGroupRenderer` every group it builds
     * will use.
     */
    public function withRenderer(renderer:DockAreaRenderer):DockArea {
        this.renderer = renderer;
        return this;
    }

    /**
     * Rust `DockArea::id`, renamed: `id` is a field of Ceramic's entities.
     */
    public inline function areaId():String {
        return idValue;
    }

    public inline function version():Null<Int> {
        return versionValue;
    }

    /**
     * Change the schema version a later `dump` writes.
     */
    public function setVersion(version:Null<Int>, cx:Context<DockArea>):Void {
        versionValue = version;
        cx.notify();
    }

    /**
     * The area's own bounds, recorded each frame. Dock resizing measures
     * against it.
     */
    public inline function bounds():Bounds {
        return boundsValue;
    }

    /**
     * The tree for one region, or `null` for a dock that does not exist.
     */
    public function layout(placement:DockPlacement):Null<PaneTree> {
        if (placement == DockPlacement.Center) return center;
        final region = dock(placement);
        return region != null ? region.tree : null;
    }

    /**
     * The live view for a panel, if the dock still holds it.
     */
    public function panel(panel:PanelId):Null<PanelView> {
        return panels.get(panel.asU64());
    }

    public inline function isLocked():Bool {
        return locked;
    }

    /**
     * Whether a region currently holds no visible panel. A region that does
     * not exist (a dock that was never installed) is empty too.
     */
    public function isEmpty(placement:DockPlacement, cx:App):Bool {
        final tree = layout(placement);
        return tree == null || !isNodeVisible(tree.root(), cx);
    }

    /**
     * Lock the layout against rearranging. Resizing stays available.
     */
    public function setLocked(locked:Bool, window:Window, cx:Context<DockArea>):Void {
        if (this.locked == locked) return;
        this.locked = locked;
        // The lock is one of the facts every group is told, so it only takes
        // effect once the groups have been re-told.
        reconcile(window, cx);
    }

/// Installing layouts: the center region and the three docks.

    /**
     * Replace the center region with a described layout. Whatever was there
     * leaves the dock, so its panels are told `Panel.onRemoved`.
     */
    public function setCenter(layout:DockLayout, window:Window, cx:Context<DockArea>):Void {
        final built = PaneTree.fromLayout(layout, RootKind.Split);
        center = built.tree;
        for (panel in built.panels) panels.set(panel.id.asU64(), panel.view);
        reconcile(window, cx);
        cx.emit(DockEvent.LayoutChanged);
    }

    /**
     * Replace one dock with a described layout, creating the dock if the area
     * does not have one there yet. A new dock keeps the size and open state of
     * the one it replaces, so re-filling a dock does not resize it.
     *
     * `DockPlacement.Center` defers to `setCenter`.
     */
    public function setDock(placement:DockPlacement, layout:DockLayout, window:Window, cx:Context<DockArea>):Void {
        if (placement == DockPlacement.Center) {
            setCenter(layout, window, cx);
            return;
        }

        final built = PaneTree.fromLayout(layout, RootKind.Any);
        final existing = dock(placement);
        final dockState = existing != null ? existing.dock : new Dock(Resizable.PANEL_MIN_SIZE * 2.);
        insertDock(placement, new DockRegion(placement, built.tree, dockState));
        for (panel in built.panels) panels.set(panel.id.asU64(), panel.view);
        reconcile(window, cx);
        cx.emit(DockEvent.LayoutChanged);
    }

    /**
     * Take a dock away entirely, panels and all. Distinct from `toggleDock`,
     * which only takes it off screen.
     */
    public function removeDock(placement:DockPlacement, window:Window, cx:Context<DockArea>):Void {
        final region = dock(placement);
        if (region == null) return;
        docks.remove(region);
        // The dock's panels leave the dock entirely, so they are told, unlike
        // the panels of a dock that merely closed.
        reconcile(window, cx);
        cx.emit(DockEvent.LayoutChanged);
    }

    public function hasDock(placement:DockPlacement):Bool {
        return dock(placement) != null;
    }

    /**
     * Whether a dock is on screen. A dock the area does not have is never
     * open.
     */
    public function isDockOpen(placement:DockPlacement):Bool {
        final region = dock(placement);
        return region != null && region.dock.isOpen();
    }

    /**
     * Open a closed dock or close an open one. A dock that is not
     * collapsible refuses to close; there is nothing to refuse when opening.
     */
    public function toggleDock(placement:DockPlacement, window:Window, cx:Context<DockArea>):Void {
        final region = dock(placement);
        if (region == null) return;
        if (!region.dock.isCollapsible() && region.dock.isOpen()) return;
        region.dock.setOpen(!region.dock.isOpen());
        // A closed dock takes its displayed panel off screen, which the
        // active-state contract counts as no panel being displayed: that is
        // what `TabGroupConstraints.collapsed` carries.
        reconcile(window, cx);
        cx.emit(DockEvent.LayoutChanged);
    }

    /**
     * Whether a dock may be collapsed at all. A skin drawing a collapse
     * affordance in a tab bar reads this to decide whether to offer one.
     */
    public function isDockCollapsible(placement:DockPlacement):Bool {
        final region = dock(placement);
        return region != null && region.dock.isCollapsible();
    }

    public function setDockCollapsible(placement:DockPlacement, collapsible:Bool, window:Window, cx:Context<DockArea>):Void {
        final region = dock(placement);
        if (region != null) {
            region.dock.setCollapsible(collapsible);
            cx.notify();
        }
    }

    /**
     * The dock's size along its axis.
     */
    public function dockSize(placement:DockPlacement):Null<Pixels> {
        final region = dock(placement);
        return region != null ? region.dock.size() : null;
    }

    public function setDockSize(placement:DockPlacement, size:Pixels, window:Window, cx:Context<DockArea>):Void {
        final region = dock(placement);
        if (region == null) return;
        final previous = region.dock.size();
        region.dock.setSize(size);
        if ((region.dock.size() : Float) == (previous : Float)) return;
        cx.notify();
        cx.emit(DockEvent.LayoutChanged);
    }

/// Editing the layout.

    /**
     * Add a panel to a region, merging it into the first tab group there,
     * or starting a group when the region is empty.
     */
    public function addPanel<P:Model & Panel>(panel:Entity<P>, placement:DockPlacement, size:Null<Pixels>, window:Window, cx:Context<DockArea>):Void {
        addPanelInner(PanelId.fromEntityId(panel.entityId()), new EntityPanelView(panel), placement, size, window, cx);
    }

    /**
     * Add an already-wrapped panel handle to a region.
     *
     * The companion to `addPanel`, for a layer that hands base its own
     * concrete handle rather than a bare entity. The id comes from
     * `PanelView.panelId`.
     */
    public function addPanelView(panel:PanelView, placement:DockPlacement, size:Null<Pixels>, window:Window, cx:Context<DockArea>):Void {
        addPanelInner(panel.panelId(cx.app), panel, placement, size, window, cx);
    }

    function addPanelInner(id:PanelId, panel:PanelView, placement:DockPlacement, size:Null<Pixels>, window:Window, cx:Context<DockArea>):Void {
        // The registration is written before the target is resolved, so an add
        // that finds nowhere to put the panel has to undo it. Undo, not
        // remove: adding a panel the dock already holds is a legitimate call
        // (a host re-placing one it owns), and dropping its view would strand
        // it in a tree with no entity.
        final previous = panels.get(id.asU64());
        panels.set(id.asU64(), panel);

        // A dock is created to hold the panel; `size` seeds it.
        if (placement != DockPlacement.Center && dock(placement) == null) {
            insertDock(placement, new DockRegion(placement, new PaneTree(RootKind.Any), new Dock(size != null ? size : Resizable.PANEL_MIN_SIZE * 2.)));
        }

        final tree = layout(placement);
        if (tree == null) {
            restoreRegistration(id, previous);
            return;
        }
        final first = firstTabGroup(tree.root());
        final target = if (first != null) {
            InsertTarget.Tabs(first, null, true);
        }
        else {
            // An empty region has no container to merge into, so the panel
            // makes one beside the root. `normalize` then removes the emptied
            // root and, for a dock, collapses the wrapper away again.
            InsertTarget.Split(tree.root().id(), Placement.Right, size);
        }
        final result = tree.insertPanel(id, target);
        if (!result.changed()) {
            // Nothing took the panel, so a newly registered one must not
            // linger in the view map and be told `onRemoved` by the next
            // reconcile.
            restoreRegistration(id, previous);
            return;
        }
        commit(result, window, cx);
    }

    /**
     * Put the view map back the way an add found it, for one that placed
     * nothing.
     */
    function restoreRegistration(id:PanelId, previous:Null<PanelView>):Void {
        if (previous != null) panels.set(id.asU64(), previous);
        else panels.remove(id.asU64());
    }

    /**
     * Remove a panel from wherever it lives, telling it that it was removed.
     */
    public function removePanel<P:Model & Panel>(panel:Entity<P>, window:Window, cx:Context<DockArea>):Void {
        removePanelId(PanelId.fromEntityId(panel.entityId()), window, cx);
    }

    /**
     * Move a panel to a new home. The panel never leaves the dock, so it is
     * never told it was removed.
     */
    public function movePanel(panel:PanelId, target:InsertTarget, window:Window, cx:Context<DockArea>):Void {
        // A panel this area does not own (e.g. dropped from a nested dock) has
        // no backing entity here; inserting it would strand a ghost tab.
        if (this.panel(panel) == null) return;
        final destination = placementOfNode(targetNode(target));
        if (destination == null) return;
        final source = placementOfPanel(panel);

        // A split target divides an existing slot, so the tree needs real
        // pixels to divide.
        switch target {
            case Split(_, _, _): adoptMeasuredSizes(destination, cx.app);
            case _:
        }

        // Read what the source group last told the panel before the edit, so
        // the destination can be seeded with it. Without this a panel dragged
        // between groups while displayed is told `true` twice.
        var wasActive:Null<Bool> = null;
        final sourceTree = layout(source != null ? source : destination);
        if (sourceTree != null) {
            final node = sourceTree.findPanelNode(panel);
            if (node != null) {
                final cached = groups.get(node.asU64());
                if (cached != null) wasActive = cached.entity.read(cx.app).lastNotifiedActive(panel);
            }
        }

        final changed = if (source != null && source == destination) {
            final tree = layout(destination);
            if (tree == null) return;
            tree.movePanel(panel, target).changed();
        }
        else {
            // Across trees a move is a detach plus an insert. The panel is
            // still in the dock, so it must not hear `onRemoved`.
            //
            // Both halves are committed on, not just the insert: a target whose
            // node kind does not match the insert is a silent no-op, and
            // committing on the insert alone would leave the panel gone from
            // the source but still in the view map.
            final sourceTree = source != null ? layout(source) : null;
            final detached = sourceTree != null && sourceTree.removePanel(panel).changed();
            final tree = layout(destination);
            if (tree == null) return;
            final inserted = tree.insertPanel(panel, target).changed();
            detached || inserted;
        }

        commitChanged(changed, window, cx);

        if (wasActive != null) {
            final tree = layout(destination);
            final node = tree != null ? tree.findPanelNode(panel) : null;
            final cached = node != null ? groups.get(node.asU64()) : null;
            if (cached != null) {
                final active:Bool = wasActive;
                cached.entity.update(cx, (group, _) -> group.seedActive(panel, active));
            }
        }
    }

    /**
     * Display `panel` in the tab group that holds it, wherever that is.
     * Nothing happens for a panel the dock does not hold, or one already
     * displayed.
     */
    public function selectPanel(panel:PanelId, window:Window, cx:Context<DockArea>):Void {
        final placement = placementOfPanel(panel);
        if (placement == null) return;
        final tree = layout(placement);
        if (tree == null) return;
        final node = tree.findPanelNode(panel);
        if (node == null) return;
        final found = tree.findNode(node);
        final ix:Null<Int> = found == null ? null : switch found.kind() {
            case Tabs(panels, _): panels.indexOf(panel) >= 0 ? panels.indexOf(panel) : null;
            case Split(_, _, _): null;
        }
        if (ix == null) return;
        final result = tree.setActive(node, ix);
        commit(result, window, cx);
    }

    /**
     * Replace the slot sizes of the split at `node` in place.
     */
    public function setSplitSizes(node:NodeId, sizes:Array<Pixels>, window:Window, cx:Context<DockArea>):Void {
        final placement = placementOfNode(node);
        if (placement == null) return;
        final tree = layout(placement);
        if (tree == null) return;
        final result = tree.setSizes(node, [for (size in sizes) (size : Null<Pixels>)]);
        commit(result, window, cx);
    }

    /**
     * Put `panel` in a new tab group beside `node`.
     */
    public function splitAt(node:NodeId, panel:PanelId, placement:Placement, window:Window, cx:Context<DockArea>):Void {
        final region = placementOfNode(node);
        if (region == null) return;
        adoptMeasuredSizes(region, cx.app);
        final tree = layout(region);
        if (tree == null) return;
        final result = tree.split(node, panel, placement, null);
        commit(result, window, cx);
    }

    @:allow(tests)
    function removePanelId(panel:PanelId, window:Window, cx:Context<DockArea>):Void {
        final region = placementOfPanel(panel);
        if (region == null) return;
        final focused = window.focused(cx.app);
        final view = this.panel(panel);
        final hadFocus = view != null && view.focusHandle(cx.app).containsFocused(window, cx.app);
        // Prefer the same group, then the groups following it in layout order,
        // then preceding groups from nearest to farthest. Preserve this order
        // before normalization removes an emptied group or collapses its split.
        var candidates:Array<NodeId> = [];
        final regionTree = layout(region);
        if (hadFocus && regionTree != null) {
            regionTree.root().walk(node -> switch node.kind() {
                case Tabs(_, _): candidates.push(node.id());
                case Split(_, _, _):
            });
            final group = regionTree.findPanelNode(panel);
            final ix = group != null ? candidates.indexOf(group) : -1;
            if (ix >= 0) {
                final before = candidates.slice(0, ix);
                before.reverse();
                candidates = candidates.slice(ix).concat(before);
            }
        }
        final tree = layout(region);
        if (tree == null) return;
        final result = tree.removePanel(panel);
        commit(result, window, cx);

        // `onRemoved` may deliberately focus another control (or clear focus).
        // Automatic handoff is only the fallback when the callback left it alone.
        final nowFocused = window.focused(cx.app);
        final unchanged = focused == null ? nowFocused == null : (nowFocused != null && nowFocused.id == focused.id);
        if (!hadFocus || !unchanged) return;

        var next:Null<PanelView> = null;
        for (node in candidates) {
            next = focusTargetInGroup(node, cx.app);
            if (next != null) break;
        }
        if (next == null) {
            for (placement in [DockPlacement.Center, DockPlacement.Left, DockPlacement.Right, DockPlacement.Bottom]) {
                if (placement == region) continue;
                if (placement != DockPlacement.Center && !isDockOpen(placement)) continue;
                final tree = layout(placement);
                if (tree == null) continue;
                next = focusTargetInNode(tree.root(), cx.app);
                if (next != null) break;
            }
        }
        if (next != null) {
            next.focusHandle(cx.app).focus(window, cx.app);
        }
    }

    function focusTargetInGroup(node:NodeId, cx:App):Null<PanelView> {
        if (zoomed != null && zoomed != node) return null;
        final cached = groups.get(node.asU64());
        if (cached == null) return null;
        final group = cached.entity.read(cx);
        if (group.isCollapsed()) return null;
        return group.activePanel(cx);
    }

    function focusTargetInNode(node:PaneNode, cx:App):Null<PanelView> {
        return switch node.kind() {
            case Tabs(_, _): focusTargetInGroup(node.id(), cx);
            case Split(_, children, _):
                for (child in children) {
                    final found = focusTargetInNode(child, cx);
                    if (found != null) return found;
                }
                null;
        }
    }

/// Zooming.
///
/// There is no `setZoomedIn(panel)`. A zoom is a container's own act: only
/// the container knows whether its displayed panel is zoomable, and only the
/// container can tell that panel it was zoomed. So the way in is
/// `TabGroupContext.toggleZoom`, or `setZoomedIn` by node, which delegates to
/// the same place. The area then installs the container that reported it.

    /**
     * Zoom the tab group at `node` in, as if its own zoom control had been
     * used. Nothing happens for a node that is not a live tab group, or when
     * the group refuses.
     */
    public function setZoomedIn(node:NodeId, window:Window, cx:Context<DockArea>):Void {
        setZoom(node, window, cx);
    }

    /**
     * Clear the zoom, putting the zoomed container's own flag back with it.
     */
    public function setZoomedOut(window:Window, cx:Context<DockArea>):Void {
        setZoom(null, window, cx);
    }

    public inline function isZoomed():Bool {
        return zoomed != null;
    }

    /**
     * The tab group filling the area, if a group is what is zoomed.
     */
    public inline function zoomedGroup():Null<NodeId> {
        return zoomed;
    }

    /**
     * The one place `zoomed` is written.
     *
     * Every write drives the container's own flag through the same call, and
     * the new target is recorded only if that container accepted it.
     */
    function setZoom(zoomed:Null<NodeId>, window:Window, cx:Context<DockArea>):Void {
        if (this.zoomed == zoomed) return;

        final previous = this.zoomed;
        if (previous != null) {
            driveZoom(previous, false, window, cx);
        }
        final accepted = zoomed != null && driveZoom(zoomed, true, window, cx) ? zoomed : null;
        this.zoomed = accepted;
        cx.notify();
    }

    /**
     * Ask one container to zoom in or out, and report whether it now agrees.
     * A container already left out of the cache answers `false`.
     */
    function driveZoom(node:NodeId, zoomIn:Bool, window:Window, cx:Context<DockArea>):Bool {
        final cached = groups.get(node.asU64());
        if (cached == null) return false;
        return cached.entity.update(cx, (group, gcx) -> {
            group.setZoomed(zoomIn, window, gcx);
            group.isZoomed() == zoomIn;
        });
    }

    /**
     * The container that fills the area when something is zoomed: the
     * container, not the panel inside it, which keeps its tab bar on screen.
     */
    function zoomedView():Null<AnyView> {
        if (zoomed == null) return null;
        final cached = groups.get(zoomed.asU64());
        return cached != null ? (cached.entity : TabGroup) : null;
    }

/// Persistence.

    /**
     * Read a persisted layout, rebuilding every panel through
     * `PanelRegistry`. A panel this build does not know about becomes a
     * placeholder that carries the original `PanelState` forward, so the next
     * save does not erase it. (Rust returns `Result<()>`, always `Ok`.)
     */
    public function load(state:DockAreaState, window:Window, cx:Context<DockArea>):Void {
        versionValue = state.version;
        zoomed = null;
        // Nothing in the old layout survives a load, so the caches are
        // emptied rather than reconciled: every node id in the new trees is
        // freshly minted and would miss the old cache anyway.
        for (key in [for (key in groups.keys()) key]) dropGroup(key);
        for (key in [for (key in splits.keys()) key]) dropSplit(key);
        docks.resize(0);
        // `panels` is deliberately not cleared: leaving the outgoing panels in
        // it lets `reconcile` prune them, which is what tells them they were
        // removed.

        final built:Array<{id:PanelId, view:PanelView}> = [];
        final builder = new RegistryPanelBuilder(self, renderer, built, window, cx);
        center = PaneTree.fromState(state.center, RootKind.Split, builder);

        for (dockState in [state.leftDock, state.rightDock, state.bottomDock]) {
            if (dockState == null) continue;
            final tree = PaneTree.fromState(dockState.panel(), RootKind.Any, builder);
            final dockValue = new Dock(dockState.size());
            dockValue.setOpen(dockState.open());
            insertDock(dockState.placement(), new DockRegion(dockState.placement(), tree, dockValue));
        }

        for (panel in built) panels.set(panel.id.asU64(), panel.view);
        reconcile(window, cx);
        cx.emit(DockEvent.LayoutChanged);
    }

    /**
     * Write the layout out.
     *
     * Slot sizes are resolved to concrete pixels first. The tree represents
     * an unconstrained slot as `null` and the writer emits `0.0` for it,
     * which this reader maps back to `null`, but an older build has no notion
     * of the sentinel and would construct a real zero-pixel panel from it.
     * Preference order is the split's measured size, then the tree's own
     * size, then `PANEL_MIN_SIZE` for a slot nothing has ever measured.
     *
     * The measurement wins because the tree does not track every change to
     * it: `ResizableState` only emits `Resized` from a finished drag, while
     * its container adjustment rescales every slot silently on each window
     * resize, insert and remove. Reading the measurement for every slot of a
     * split writes one internally consistent set.
     */
    public function dump(cx:App):DockAreaState {
        final source = new LivePanels(panels, cx);
        return new DockAreaState(versionValue, resolvedTree(center, cx).toState(source), dumpDock(DockPlacement.Left, source, cx),
            dumpDock(DockPlacement.Right, source, cx), dumpDock(DockPlacement.Bottom, source, cx));
    }

    function dumpDock(placement:DockPlacement, source:LivePanels, cx:App):Null<DockState> {
        final region = dock(placement);
        if (region == null) return null;
        return new DockState(resolvedTree(region.tree, cx).toState(source), placement, region.dock.size(), region.dock.isOpen());
    }

    function resolvedTree(tree:PaneTree, cx:App):PaneTree {
        final copy = tree.clone();
        resolveSizes(copy.root(), cx);
        return copy;
    }

    function resolveSizes(node:PaneNode, cx:App):Void {
        final cached = splits.get(node.id().asU64());
        final measured:Array<Pixels> = cached != null ? cached.entity.read(cx).sizes() : [];

        switch node.kindRef() {
            case Split(_, children, sizes):
                for (ix in 0...sizes.length) {
                    // A slot already holding zero is exactly as unsafe as an
                    // absent one: it is the same byte in the file and the same
                    // zero-pixel panel in an older build. So both the
                    // measurement and the stored value have to clear zero
                    // before they can be written.
                    final onScreen:Null<Pixels> = ix < measured.length && (measured[ix] : Float) > 0 ? measured[ix] : null;
                    final stored:Null<Pixels> = sizes[ix] != null && (sizes[ix] : Float) > 0 ? sizes[ix] : null;
                    sizes[ix] = onScreen != null ? onScreen : (stored != null ? stored : Resizable.PANEL_MIN_SIZE);
                }
                for (child in children) resolveSizes(child, cx);
            case Tabs(_, _):
        }
    }

/// Reconciliation.

    /**
     * Apply one edit: bring the entity cache back in line and say so.
     *
     * `onRemoved` is fired by `reconcile` from the panels it prunes: the same
     * set for a plain removal, and it also covers the panels a wholesale
     * `setCenter`, `setDock`, `removeDock` or `load` displaces.
     */
    function commit(result:EditResult, window:Window, cx:Context<DockArea>):Void {
        commitChanged(result.changed(), window, cx);
    }

    /**
     * `commit` for an edit that took more than one `EditResult`.
     */
    function commitChanged(changed:Bool, window:Window, cx:Context<DockArea>):Void {
        if (!changed) return;
        reconcile(window, cx);
        cx.emit(DockEvent.LayoutChanged);
    }

    /**
     * Bring the entity cache in line with the trees.
     *
     * Because `NodeId` survives every edit and every normalization rule, a
     * steady-state pass creates and drops nothing; only genuinely new or dead
     * containers churn. That is what keeps a drag from resetting the state of
     * panels it did not touch.
     */
    @:allow(tests)
    function reconcile(window:Window, cx:Context<DockArea>):Void {
        // Planned first, applied second.
        final plans:Array<ContainerPlan> = [];
        planTree(center, false, locked, plans);
        for (region in docks) {
            planTree(region.tree, !region.dock.isOpen(), locked, plans);
        }

        final liveNodes:Map<Int, Bool> = new Map();
        final livePanels:Map<Int, Bool> = new Map();

        for (plan in plans) {
            switch plan {
                case Split(node, axis, children, sizes):
                    liveNodes.set(node.asU64(), true);
                    final state = splitEntity(node, cx);
                    final cached = splits.get(node.asU64());
                    final previous = cached != null ? cached.children.copy() : [];
                    final adopted = cached != null ? cached.sizes.copy() : [];
                    // Only a split the edit changed is handed anything. The
                    // state of every other split may legitimately disagree
                    // with its tree (a window resize rescales it silently), and
                    // pushing the tree's sizes back would move slots the edit
                    // never named.
                    if (!sameNodes(previous, children) || !PaneNode.sameSizes(adopted, sizes)) {
                        state.update(cx, (state, scx) -> {
                            syncSplitPanels(state, previous, children, sizes, scx);
                            state.syncPanelsCount(axis, children.length, scx);
                            // The tree is authoritative on how space divides,
                            // so its sizes land last. What the tree decides is
                            // the share, not the pixel count: the file holds
                            // pixels measured in whatever window last saved
                            // it, so hand over the share instead.
                            state.adoptSizes(scaleSizesTo(state.containerSize(), sizes), scx);
                        });
                    }
                    final cached = splits.get(node.asU64());
                    if (cached != null) {
                        cached.children = children;
                        cached.sizes = sizes;
                    }
                case Group(node, panelIds, activeIx, constraints):
                    liveNodes.set(node.asU64(), true);
                    for (panel in panelIds) livePanels.set(panel.asU64(), true);
                    final views = viewsOf(panelIds);
                    final group = groupEntity(node, window, cx);
                    group.update(cx, (group, gcx) -> {
                        // Every group must be told this. A group nobody has
                        // constrained stays `sealed()` and silently declines
                        // drags, drops and closes.
                        group.setConstraints(constraints, window, gcx);
                        group.syncFromTree(views, activeIx, window, gcx);
                    });
            }
        }

        for (key in [for (key in groups.keys()) key]) if (!liveNodes.exists(key)) dropGroup(key);
        for (key in [for (key in splits.keys()) key]) if (!liveNodes.exists(key)) dropSplit(key);

        final departedIds = [for (key in panels.keys()) if (!livePanels.exists(key)) key];
        departedIds.sort((a, b) -> a - b);
        final departed = [for (key in departedIds) panels.get(key)];
        for (key in departedIds) panels.remove(key);

        // A zoomed container fills the whole area, so one that has just left
        // the dock would otherwise keep filling it with nothing behind it. It
        // is the container going away that ends the zoom, not a panel: a group
        // survives its displayed panel closing, and the next tab takes over,
        // still zoomed.
        final zoomSurvives = zoomed == null || groups.exists(zoomed.asU64());
        if (!zoomSurvives) {
            setZoom(null, window, cx);
        }

        cx.notify();
        // Last, so a panel reacting to this sees a dock that already agrees
        // with its trees.
        for (view in departed) {
            view.onRemoved(window, cx.app);
        }
    }

    static function sameNodes(a:Array<NodeId>, b:Array<NodeId>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) if (a[i] != b[i]) return false;
        return true;
    }

    /**
     * The views for a group's panel ids, in tab order.
     */
    function viewsOf(panelIds:Array<PanelId>):Array<PanelView> {
        #if debug
        for (panel in panelIds) {
            if (!panels.exists(panel.asU64())) {
                throw 'every panel in a tree must have a live view; a missing one would silently shift the group\'s active index';
            }
        }
        #end
        return [for (panel in panelIds) if (panels.exists(panel.asU64())) panels.get(panel.asU64())];
    }

    function groupEntity(node:NodeId, window:Window, cx:Context<DockArea>):Entity<TabGroup> {
        final cached = groups.get(node.asU64());
        if (cached != null) return cached.entity;

        final tabGroupRenderer = renderer.tabGroupRenderer();
        final entity = cx.newEntity((gcx:Context<TabGroup>) -> new TabGroup(node, window, gcx).withRenderer(tabGroupRenderer));
        final subscription = cx.subscribeIn(entity, TabGroupEvent, window, (area, group, event, window, cx) -> area.onTabGroupEvent(group, event, window, cx));
        groups.set(node.asU64(), new CachedGroup(entity, subscription));
        return entity;
    }

    function splitEntity(node:NodeId, cx:Context<DockArea>):Entity<ResizableState> {
        final cached = splits.get(node.asU64());
        if (cached != null) return cached.entity;

        final entity = cx.newEntity((_:Context<ResizableState>) -> new ResizableState());
        // A drag on a resize handle changes only the measured sizes. Writing
        // them straight back keeps the tree describing the layout the user
        // arranged, which is what a later insert or removal scales from and
        // what a region with no live split entity is dumped from. Only a
        // finished drag arrives here (see `dump`).
        final subscription = cx.subscribe(entity, ResizablePanelEvent, (area, state, _, cx) -> {
            final sizes:Array<Null<Pixels>> = [for (size in state.read(cx.app).sizes()) (size : Null<Pixels>)];
            final region = area.placementOfNode(node);
            if (region == null) return;
            final tree = area.layout(region);
            if (tree == null) return;
            if (tree.setSizes(node, sizes).changed()) {
                cx.emit(DockEvent.LayoutChanged);
            }
            // The state is where these came from, so the next reconcile has
            // nothing to hand it.
            final cached = area.splits.get(node.asU64());
            if (cached != null) cached.sizes = sizes;
        });
        splits.set(node.asU64(), new CachedSplit(entity, subscription));
        return entity;
    }

    /**
     * Rust drops the cache entry, its subscription and the last handle on the
     * entity; the port disposes and destroys them explicitly.
     */
    function dropGroup(key:Int):Void {
        final cached = groups.get(key);
        groups.remove(key);
        if (cached == null) return;
        cached.subscription.dispose();
        final entity:TabGroup = cached.entity;
        if (!entity.destroyed) entity.destroy();
    }

    function dropSplit(key:Int):Void {
        final cached = splits.get(key);
        splits.remove(key);
        if (cached == null) return;
        cached.subscription.dispose();
        final entity:ResizableState = cached.entity;
        if (!entity.destroyed) entity.destroy();
    }

/// Intents arriving from the containers.

    function onTabGroupEvent(group:Entity<TabGroup>, event:TabGroupEvent, window:Window, cx:Context<DockArea>):Void {
        switch event {
            case Drop(panel, _, target):
                movePanel(panel, target, window, cx);
            case DragDrop(item, target):
                cx.emit(DockEvent.DragDrop(item.clone(), target));
            case ClosePanel(panel):
                removePanelId(panel, window, cx);
            case ActiveChanged(ix):
                final node = group.read(cx.app).node();
                final region = placementOfNode(node);
                if (region == null) return;
                final tree = layout(region);
                if (tree == null) return;
                final result = tree.setActive(node, ix);
                commit(result, window, cx);
            case ZoomIn:
                setZoom(group.read(cx.app).node(), window, cx);
            // Only the group that is actually on screen can give the dock
            // back. A group told to zoom out to make room for another one
            // reports it too, and that report must not undo the zoom that
            // replaced it.
            case ZoomOut:
                final node = group.read(cx.app).node();
                if (zoomed != null && zoomed == node) {
                    setZoom(null, window, cx);
                }
        }
    }

/// Region lookup.

    function dock(placement:DockPlacement):Null<DockRegion> {
        for (region in docks) if (region.placement == placement) return region;
        return null;
    }

    function insertDock(placement:DockPlacement, region:DockRegion):Void {
        for (ix in 0...docks.length) {
            if (docks[ix].placement == placement) {
                docks[ix] = region;
                return;
            }
        }
        docks.push(region);
    }

    /**
     * Feed every split's measured size back into the tree before an edit
     * that has to divide space.
     *
     * Done here rather than continuously: the tree is the record of what the
     * user arranged, and rewriting it on every layout pass would let a
     * transient window size become the stored layout.
     */
    function adoptMeasuredSizes(placement:DockPlacement, cx:App):Void {
        final measured:Map<Int, Array<Pixels>> = new Map();
        for (key => cached in splits) {
            // Only splits that have actually been laid out. A split created
            // earlier in this same edit has a zero container and its sizes
            // are whatever `insertPanel` left behind.
            final state = cached.entity.read(cx);
            if ((state.containerSize() : Float) > 0) measured.set(key, state.sizes().copy());
        }

        final tree = layout(placement);
        if (tree != null) tree.adoptMeasuredSizes(measured);
    }

    /**
     * Which region a container belongs to. Unambiguous because `NodeId`s are
     * allocated globally rather than per tree.
     */
    function placementOfNode(node:NodeId):Null<DockPlacement> {
        if (center.findNode(node) != null) return DockPlacement.Center;
        for (region in docks) if (region.tree.findNode(node) != null) return region.placement;
        return null;
    }

    function placementOfPanel(panel:PanelId):Null<DockPlacement> {
        if (center.findPanelNode(panel) != null) return DockPlacement.Center;
        for (region in docks) if (region.tree.findPanelNode(panel) != null) return region.placement;
        return null;
    }

    /**
     * Resize one dock from a pointer position, clamped so neither this dock
     * nor the one opposite is squeezed below its minimum.
     *
     * A collapsible bottom dock is the exception: it follows the pointer
     * below the minimum down to its closed strip, so closing it by drag is
     * one continuous motion. That size is only shown, and `endDockResize`
     * settles it on release.
     */
    @:allow(tests)
    function resizeDock(placement:DockPlacement, pointer:Point, window:Window, cx:Context<DockArea>):Void {
        final opposite:Null<Pixels> = switch placement {
            case Left: dockSize(DockPlacement.Right);
            case Right: dockSize(DockPlacement.Left);
            case _: null;
        }
        final sizing = new DockSizing(placement).withAreaBounds(boundsValue).withOppositeDockSize(opposite != null ? opposite : 0.);
        final size:Pixels = MathUtil.min(sizing.sizeFromPointer(pointer), sizing.clamp(Pixels.MAX));

        final region = dock(placement);
        if (region == null) return;
        final wasOpen = region.dock.isOpen();
        if (placement == DockPlacement.Bottom && region.dock.isCollapsible() && (size : Float) < (Resizable.PANEL_MIN_SIZE : Float)) {
            region.dock.setOpen((size : Float) > (CLOSED_BOTTOM_STRIP : Float));
            region.dock.setLiveSize(MathUtil.max(size, CLOSED_BOTTOM_STRIP));
        }
        else {
            region.dock.setOpen(true);
            region.dock.setLiveSize(null);
            region.dock.setSize(size);
        }
        if (region.dock.isOpen() != wasOpen) {
            reconcile(window, cx);
        }
        cx.notify();
    }

    /**
     * Settle a drag that ended below the minimum: nearer the closed strip it
     * closes, nearer the minimum it opens at the minimum.
     */
    @:allow(tests)
    function endDockResize(placement:DockPlacement, window:Window, cx:Context<DockArea>):Void {
        final region = dock(placement);
        if (region == null) return;
        final size = region.dock.liveSize();
        if (size == null) return;
        region.dock.setLiveSize(null);

        final open = (size : Float) >= SpringMath.f32(((CLOSED_BOTTOM_STRIP : Float) + (Resizable.PANEL_MIN_SIZE : Float)) / 2.);
        if (open) {
            region.dock.setSize(Resizable.PANEL_MIN_SIZE);
        }
        if (region.dock.isOpen() != open) {
            region.dock.setOpen(open);
            reconcile(window, cx);
        }
        cx.notify();
    }

/// Rendering.

    /**
     * Lower one container to an element.
     */
    function renderNode(node:PaneNode, window:Window, cx:App):AnyElement {
        return switch node.kind() {
            case Split(axis, children, sizes):
                final id = ElementId.NamedInteger('dock-split', node.id().asU64());
                final group = switch axis {
                    case Horizontal: Resizable.hResizable(id);
                    case Vertical: Resizable.vResizable(id);
                }
                // A container whose every panel is hidden must not keep
                // occupying its slot. No renderer hook could supply this: only
                // the area can see the panels behind a node.
                final shown = [for (child in children) isNodeVisible(child, cx)];
                // The slot that absorbs the leftover has to be one that is
                // actually drawn, so the last shown slot is the flexible one.
                var grows = -1;
                for (ix in 0...shown.length) if (shown[ix]) grows = ix;
                final panels = [];
                for (ix in 0...children.length) {
                    final panel = Resizable.resizablePanel().visible(shown[ix]).child(renderNode(children[ix], window, cx));
                    final size = sizes[ix];
                    if (size != null) {
                        // `flexNone` is what makes the size stick: a resizable
                        // panel grows by default, so a slot given a size would
                        // otherwise treat it as a flex basis and still absorb a
                        // share of the leftover. The growth slot absorbs
                        // container growth, so a later viewport resize keeps
                        // the dock filled.
                        panel.size(size);
                        if (ix != grows) panel.flexNone();
                    }
                    panels.push(panel);
                }

                final cached = splits.get(node.id().asU64());
                if (cached != null) group.withState(cached.entity);
                final renderer = this.renderer;
                group.withHandleAppearance((handle, window, cx) -> renderer.renderSplitHandle(handle, window, cx));
                group.children(cast panels);

                // A split frame with no size collapses: base puts it between a
                // resizable panel and the resizable group, and between the
                // centre frame and the centre's root split, and neither parent
                // sizes it.
                renderer.splitFrame(node.id(), axis, window, cx)
                    .sizeFull()
                    .flex1()
                    .minH(px(0.))
                    .overflowHidden()
                    .child(group)
                    .intoAnyElement();
            case Tabs(_, _):
                final cached = groups.get(node.id().asU64());
                cached != null ? (cached.entity : AnyView).intoAnyElement() : new glaze.Empty().intoAnyElement();
        }
    }

    /**
     * Whether anything in this container is on screen.
     */
    @:allow(tests)
    function isNodeVisible(node:PaneNode, cx:App):Bool {
        final source = new LivePanels(panels, cx);
        return switch node.kind() {
            case Split(_, children, _):
                for (child in children) if (isNodeVisible(child, cx)) return true;
                false;
            case Tabs(ids, _):
                for (panel in ids) if (source.isVisible(panel)) return true;
                false;
        }
    }

    function renderDock(placement:DockPlacement, window:Window, cx:App):Null<AnyElement> {
        final region = dock(placement);
        if (region == null) return null;
        final context = dockContext(placement, region.dock);

        // A closed left or right dock takes no space at all; a closed bottom
        // dock keeps a strip so its tab bar stays clickable. Nothing is drawn
        // for a dock with no extent, and the renderer is not asked for chrome
        // nobody can see.
        final size = dockExtent(context);
        if ((size : Float) <= 0) {
            return div().intoAnyElement();
        }

        final content = renderNode(region.tree.root(), window, cx);
        // The box is applied here rather than left to the renderer: a dock's
        // extent along its own axis is not presentation, it is what makes the
        // dock a column beside the centre instead of a block in the flow below
        // it.
        final chrome = renderer.renderDock(context, content, window, cx);
        return dockFrame(context, size).child(chrome).intoAnyElement();
    }

    function dockContext(placement:DockPlacement, dock:Dock):DockContext {
        final area = self;
        final live = dock.liveSize();
        return new DockContext(
            placement,
            live != null ? live : dock.size(),
            dock.isOpen(),
            dock.isCollapsible(),
            (window, cx) -> area.tryUpdate(cx, (area, cx) -> area.toggleDock(placement, window, cx)),
            (pointer, window, cx) -> area.tryUpdate(cx, (area, cx) -> area.resizeDock(placement, pointer, window, cx)),
            (window, cx) -> area.tryUpdate(cx, (area, cx) -> area.endDockResize(placement, window, cx))
        );
    }

    /**
     * How much room a dock asks for along its own axis.
     */
    public static function dockExtent(dock:DockContext):Pixels {
        return if (dock.isOpen()) dock.size() else if (dock.placement() == DockPlacement.Bottom) CLOSED_BOTTOM_STRIP else 0.;
    }

    /**
     * The box a dock occupies: its extent along its own axis, full across, and
     * held at that size rather than stretched by the row it sits in.
     * Structural, not decorative, which is why it is built here and not in a
     * renderer.
     */
    public static function dockFrame(dock:DockContext, size:Pixels):Div {
        final frame = div().flex().flexNone().relative().overflowHidden();
        switch dock.placement() {
            case Left | Right: frame.flexRow().hFull().w(px(size));
            case Bottom: frame.wFull().h(px(size));
            // Base never builds a dock for the centre.
            case Center:
        }
        return frame;
    }

    /**
     * Rust `Focusable::focus_handle`.
     */
    public function focusHandle(cx:App):FocusHandle {
        return focusHandleValue;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final area:Entity<DockArea> = this;
        final renderer = this.renderer;
        final app = cx.app;

        // Structure, applied after the hook and not inside it: a dock area
        // lays its left dock, centre and right dock out in a row.
        final frame = renderer.frame(window, app)
            .testSupport()
            .relative()
            .sizeFull()
            .overflowHidden()
            .flex()
            .flexRow()
            .onPrepaint((bounds, _, cx) -> {
                area.update(cx, (area, _) -> area.boundsValue = bounds);
            })
            .trackFocus(focusHandleValue);

        final zoomedView = this.zoomedView();
        if (zoomedView != null) {
            frame.child(zoomedView);
        }
        else {
            final left = renderDock(DockPlacement.Left, window, app);
            if (left != null) frame.child(left);
            final centerColumn = renderer.centerFrame(window, app)
                // The centre is whatever the side docks leave, in a column
                // with the bottom dock.
                .flex()
                .flex1()
                .flexCol()
                .overflowHidden()
                .child(renderNode(center.root(), window, app));
            final bottom = renderDock(DockPlacement.Bottom, window, app);
            if (bottom != null) centerColumn.child(bottom);
            frame.child(centerColumn);
            final right = renderDock(DockPlacement.Right, window, app);
            if (right != null) frame.child(right);
        }
        return frame;
    }

/// Test support (Rust `#[cfg(test)] impl DockArea`)

    /**
     * Every cached container, as `(node, entity)` sorted. Entity ids, not
     * just node ids: node ids alone would compare equal even if every
     * container entity had been torn down and rebuilt under the same key.
     */
    @:allow(tests)
    function containerEntityIds():Array<{node:Int, entity:Int}> {
        final ids:Array<{node:Int, entity:Int}> = [];
        for (key => cached in groups) ids.push({node: key, entity: cached.entity.entityId()});
        for (key => cached in splits) ids.push({node: key, entity: cached.entity.entityId()});
        ids.sort((a, b) -> a.node != b.node ? a.node - b.node : a.entity - b.entity);
        return ids;
    }

/// Plans

    static function planTree(tree:PaneTree, collapsed:Bool, locked:Bool, out:Array<ContainerPlan>):Void {
        // The root has nothing beside it by definition.
        planNode(tree.root(), true, collapsed, locked, out);
    }

    static function planNode(node:PaneNode, alone:Bool, collapsed:Bool, locked:Bool, out:Array<ContainerPlan>):Void {
        switch node.kind() {
            case Split(axis, children, sizes):
                out.push(ContainerPlan.Split(node.id(), axis, [for (child in children) child.id()], sizes.copy()));
                final childrenAlone = children.length <= 1;
                for (child in children) planNode(child, childrenAlone, collapsed, locked, out);
            case Tabs(panels, activeIx):
                out.push(ContainerPlan.Group(node.id(), panels.copy(), activeIx,
                    TabGroupConstraints.inSplit(alone).dockLocked(locked).collapsed(collapsed)));
        }
    }

    static function firstTabGroup(node:PaneNode):Null<NodeId> {
        return switch node.kind() {
            case Tabs(_, _): node.id();
            case Split(_, children, _):
                for (child in children) {
                    final found = firstTabGroup(child);
                    if (found != null) return found;
                }
                null;
        }
    }

    static function targetNode(target:InsertTarget):NodeId {
        return switch target {
            case Tabs(node, _, _) | Split(node, _, _): node;
        }
    }

    /**
     * Re-express slot sizes as shares of `container`, keeping their
     * proportions.
     *
     * Returns them unchanged unless every slot is constrained and both the
     * container and the recorded total are usable: an unconstrained slot is
     * laid out by flex and takes the leftover, so scaling only the
     * constrained ones would move a divider nothing asked to move. Computed
     * in `f32` like the original.
     */
    @:allow(tests)
    static function scaleSizesTo(container:Pixels, sizes:Array<Null<Pixels>>):Array<Null<Pixels>> {
        var total = 0.;
        var anyNone = false;
        for (size in sizes) {
            if (size == null) anyNone = true;
            else total = SpringMath.f32(total + (size : Float));
        }
        if ((container : Float) <= 0 || total <= 0 || anyNone) return sizes.copy();

        final scale = SpringMath.f32((container : Float) / total);
        return [for (size in sizes) size != null ? (SpringMath.f32((size : Float) * scale) : Pixels) : null];
    }

    /**
     * Bring one split's `ResizableState` panel list from `previous` to `next`,
     * inserting and removing at the exact index rather than at the tail.
     *
     * `ResizableState` treats the size handed to `insertPanel` as an initial
     * value only; from then on its own sizes are authoritative. So an
     * append-and-truncate sync would leave every survivor of a non-tail
     * removal wearing the width of whoever used to sit at its index.
     */
    static function syncSplitPanels(state:ResizableState, previous:Array<NodeId>, next:Array<NodeId>, sizes:Array<Null<Pixels>>,
            cx:Context<ResizableState>):Void {
        final current = previous.copy();

        // Removals from the tail, so the indices ahead of each removal stay valid.
        var ix = current.length - 1;
        while (ix >= 0) {
            if (!next.contains(current[ix])) {
                if (ix < state.sizes().length) state.removePanel(ix, cx);
                current.splice(ix, 1);
            }
            ix--;
        }

        for (ix in 0...next.length) {
            final node = next[ix];
            if (ix < current.length && current[ix] == node) continue;
            final at = ix < state.sizes().length ? ix : state.sizes().length;
            // Passed through as-is. The tree already decided this slot's share
            // when the panel was inserted.
            state.insertPanel(ix < sizes.length ? sizes[ix] : null, at, cx);
            current.insert(at < current.length ? at : current.length, node);
        }

        #if debug
        if (!sameNodes(current, next)) {
            throw 'the split\'s panel list must end up mirroring its children exactly; a reordering edit would need its own case here';
        }
        #end
    }

}

/**
 * One dock: its own layout tree plus the open/size/collapsible state.
 */
private class DockRegion {

    public final placement:DockPlacement;

    public final tree:PaneTree;

    public final dock:Dock;

    public function new(placement:DockPlacement, tree:PaneTree, dock:Dock) {
        this.placement = placement;
        this.tree = tree;
        this.dock = dock;
    }

}

/**
 * A cached tab group entity together with the subscription that carries its
 * intents back to the area.
 */
@:allow(glaze.kit.base.dock, tests)
private class CachedGroup {

    public final entity:Entity<TabGroup>;

    public final subscription:Subscription;

    public function new(entity:Entity<TabGroup>, subscription:Subscription) {
        this.entity = entity;
        this.subscription = subscription;
    }

}

/**
 * A split's cached `ResizableState`, plus the child order that state's panel
 * list currently mirrors, and the tree sizes the state last adopted. A
 * reconcile that finds them unchanged leaves the state alone: re-adopting a
 * `null` un-pins the measurement the layout pass resolved it to, and the
 * split re-flexes although the edit never touched it.
 */
@:allow(glaze.kit.base.dock, tests)
private class CachedSplit {

    public final entity:Entity<ResizableState>;

    public var children:Array<NodeId> = [];

    public var sizes:Array<Null<Pixels>> = [];

    public final subscription:Subscription;

    public function new(entity:Entity<ResizableState>, subscription:Subscription) {
        this.entity = entity;
        this.subscription = subscription;
    }

}

/**
 * One container's worth of reconciliation work, snapshotted out of the tree.
 */
private enum ContainerPlan {
    Split(node:NodeId, axis:Axis, children:Array<NodeId>, sizes:Array<Null<Pixels>>);
    Group(node:NodeId, panels:Array<PanelId>, activeIx:Int, constraints:TabGroupConstraints);
}

/**
 * Rebuilds panels out of persisted state through `PanelRegistry`.
 */
private class RegistryPanelBuilder implements PanelBuilder {

    final dockArea:WeakEntity<DockArea>;

    final renderer:DockAreaRenderer;

    final built:Array<{id:PanelId, view:PanelView}>;

    final window:Window;

    final cx:Context<DockArea>;

    public function new(dockArea:WeakEntity<DockArea>, renderer:DockAreaRenderer, built:Array<{id:PanelId, view:PanelView}>, window:Window,
            cx:Context<DockArea>) {
        this.dockArea = dockArea;
        this.renderer = renderer;
        this.built = built;
        this.window = window;
        this.cx = cx;
    }

    public function build(state:PanelState, info:PanelInfo):PanelId {
        final context = new PanelBuildContext(dockArea, state, info);
        var view = PanelRegistry.buildPanel(state.panelName, context, window, cx.app);
        if (view == null) view = renderer.buildPlaceholder(state, window, cx.app);
        if (view == null) {
            final copy = state.clone();
            view = new EntityPanelView(cx.newEntity((pcx:Context<PlaceholderPanel>) -> new PlaceholderPanel(copy, pcx)));
        }

        final id = view.panelId(cx.app);
        built.push({id: id, view: view});
        return id;
    }

}

/**
 * Stands in for a panel this build cannot construct.
 *
 * It draws nothing (an "unknown panel" message is presentation and belongs
 * above this seam), but it keeps the original `PanelState` and hands it back
 * from `Panel.dump`, so a layout written by a newer build survives a load and
 * save here instead of losing the panel.
 */
private class PlaceholderPanel extends PanelBase {

    final state:PanelState;

    final focusHandleValue:FocusHandle;

    public function new(state:PanelState, cx:Context<PlaceholderPanel>) {
        super();
        this.state = state;
        this.focusHandleValue = cx.focusHandle();
    }

    public function panelName():String {
        return 'InvalidPanel';
    }

    override public function dump(cx:App):PanelState {
        return state.clone();
    }

    public function focusHandle(cx:App):FocusHandle {
        return focusHandleValue;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new glaze.Empty();
    }

}
