// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs, crates/component/src/dock/dock.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Axis;
import gpui.Bounds;
import gpui.Context;
import gpui.Div;
import gpui.ElementId;
import gpui.Element;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Model;
import gpui.MouseMoveEvent;
import gpui.Render;
import gpui.Style;
import gpui.Window;
import gpui.base.dock.DockArea;
import gpui.base.dock.DockAreaRendererBase;
import gpui.base.dock.DockContext;
import gpui.base.dock.DockEvent;
import gpui.base.dock.DockPlacement;
import gpui.base.dock.NodeId;
import gpui.base.dock.PanelRegistry;
import gpui.base.dock.PanelState;
import gpui.base.dock.TabGroupRenderer;
import gpui.base.resizable.ResizeHandle.HandleEdge;
import gpui.base.resizable.ResizeHandle.ResizeHandleContext;
import gpui.component.resizable.Resizable;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

/**
 * The gpui-component appearance for a `DockArea`, and the handle its
 * settings are changed through.
 *
 * The layout tree, the persisted schema, the drag geometry, the
 * active-panel state machine and the container entities all live in
 * `gpui.base.dock`. This is the skin over them: the outer frame, the split
 * frames, one dock's chrome (its resize handle) and, through `TabGroupSkin`,
 * every tab group's tab bar, toolbar, menu and drop placeholder.
 *
 * Install it at construction, where the area's own weak handle is available:
 *
 * ```haxe
 * final skin = new DockSkin(cx);
 * new DockArea('main', null, window, cx).withRenderer(skin);
 * ```
 *
 * or build both at once with `DockSkin.dockArea`. Keep the skin to change a
 * setting later. A `DockArea` built without it still docks, drags and
 * persists; it simply draws no chrome at all.
 */
class DockSkin extends DockAreaRendererBase {

    final shared:SkinShared;

    /**
     * Rust `DockSkin::new(cx)`, inside the area's constructor.
     */
    public function new(cx:Context<DockArea>) {
        super();
        this.shared = new SkinShared(cx.weakEntity());
    }

    /**
     * Build a `DockArea` wearing this appearance, together with the handle
     * its settings are changed through.
     *
     * The skin needs the area's own weak handle, so it can only be built
     * while the area is being constructed; this is that dance done once.
     */
    public static function dockArea(id:String, version:Null<Int>, window:Window, cx:App):{area:Entity<DockArea>, skin:DockSkin} {
        var skin:Null<DockSkin> = null;
        final area = cx.newEntity((acx:Context<DockArea>) -> {
            final created = new DockSkin(acx);
            skin = created;
            new DockArea(id, version, window, acx).withRenderer(created);
        });
        // The closure above runs before `newEntity` returns.
        return {area: area, skin: skin};
    }

    /**
     * Rust `dock::init`, run by `gpui.component.Component.init`.
     *
     * `PanelRegistry.init` is base's own, but the global it installs is not:
     * `DockArea`'s constructor and `PanelRegistry.registerPanel` both create
     * it on demand, and this keeps the guarantee that it exists as soon as
     * the component layer is initialized.
     */
    public static function init(cx:App):Void {
        if (cx.tryGlobal(PanelRegistry) == null) {
            cx.setGlobal(new PanelRegistry());
        }
    }

    @:allow(gpui.component.dock)
    function sharedState():SkinShared {
        return shared;
    }

    /**
     * Whether a single-panel tab group draws a plain title or a full tab bar.
     */
    public function panelStyle():PanelStyle {
        return shared.panelStyle();
    }

    public function setPanelStyle(style:PanelStyle, cx:App):Void {
        shared.panelStyleValue = style;
        shared.notify(cx);
    }

    /**
     * Whether tab bars offer the affordance that collapses a neighbouring
     * dock.
     */
    public function isToggleButtonVisible():Bool {
        return shared.isToggleButtonVisible();
    }

    public function setToggleButtonVisible(visible:Bool, cx:App):Void {
        shared.toggleButtonVisible = visible;
        shared.notify(cx);
    }

    /**
     * Show close buttons on closable tabs. Hidden by default; a panel's own
     * close constraints still decide whether its button appears.
     */
    public function setCloseButtonVisible(visible:Bool, cx:App):Void {
        shared.closeButtonVisible = visible;
        shared.notify(cx);
    }

/// User toggles (Rust `toggle_dock_by_user` / `report_user_toggle`)

    /**
     * Toggle a dock on the user's behalf and report it with
     * `DockToggleEvent`. A dock that refuses to close emits nothing.
     */
    @:allow(gpui.component.dock, tests)
    static function toggleDockByUser(area:DockArea, placement:DockPlacement, window:Window, cx:Context<DockArea>):Void {
        final wasOpen = area.isDockOpen(placement);
        area.toggleDock(placement, window, cx);
        reportUserToggle(area, placement, wasOpen, cx);
    }

    /**
     * Emit `DockToggleEvent` if a user action moved the dock away from
     * `wasOpen`.
     */
    @:allow(gpui.component.dock)
    static function reportUserToggle(area:DockArea, placement:DockPlacement, wasOpen:Bool, cx:Context<DockArea>):Void {
        final open = area.isDockOpen(placement);
        if (open != wasOpen) {
            cx.emit(new DockToggleEvent(placement, open));
        }
    }

/// DockAreaRenderer (dock.rs)

    // The row, the fill and the clip are base's, applied around whatever these
    // return, so a skin that has no appearance to add returns a bare frame and
    // still gets a dock area the right shape.

    override public function frame(window:Window, cx:App):Div {
        return div().id('dock-area');
    }

    override public function centerFrame(window:Window, cx:App):Div {
        return div().id('dock-area-center');
    }

    override public function renderSplitHandle(handle:ResizeHandleContext, window:Window, cx:App):Null<AnyElement> {
        return @:privateAccess Resizable.renderResizeHandle(handle, window, cx);
    }

    override public function splitFrame(node:NodeId, axis:Axis, window:Window, cx:App):Div {
        // The size is base's; the background is this skin's, and is the only
        // reason this hook is implemented at all.
        return div()
            .id(ElementId.NamedInteger('dock-split-frame', node.asU64()))
            .bg(Theme.global(cx).tokens.tabBar.background);
    }

    override public function renderDock(dock:DockContext, content:AnyElement, window:Window, cx:App):AnyElement {
        // No box here. A dock's extent is structural, so `DockArea.renderDock`
        // applies it around whatever this returns, which also means a renderer
        // that draws no chrome still gets a dock the right shape. This adds the
        // edge you drag and nothing else.
        return div()
            .flex()
            .sizeFull()
            .relative()
            .child(content)
            .child(renderResizeHandle(dock, window, cx))
            .child(new DockResizeTracker(dock, shared))
            .intoAnyElement();
    }

    /**
     * The "unknown panel" message the old `InvalidPanel` drew.
     *
     * It answers `dump` with the state it was handed, so a layout written by
     * a build that knows the panel survives a load and save here.
     */
    override public function buildPlaceholder(state:PanelState, window:Window, cx:App):Null<gpui.base.dock.PanelView> {
        final state = state.clone();
        return PanelHandle.panelHandle(cx.newEntity((pcx:Context<InvalidPanel>) -> new InvalidPanel(state, pcx)));
    }

    public function tabGroupRenderer():TabGroupRenderer {
        return new TabGroupSkin(shared);
    }

    function renderResizeHandle(dock:DockContext, window:Window, cx:App):IntoElement {
        final placement = dock.placement();
        final open = dock.isOpen();
        final shared = this.shared;

        // One id per placement: the docks all render under the same stateful
        // ancestor, so a shared literal would collapse the handles into one
        // global element id and share their element state: a press on the left
        // handle then starts the right handle's drag.
        final id = switch placement {
            case Left: 'resize-handle-left';
            case Right: 'resize-handle-right';
            case Bottom: 'resize-handle-bottom';
            case Center: 'resize-handle-center';
        }

        // Every dock's handle lives inside the dock, because the dock frame
        // clips to the dock's box. The left dock hugs its trailing edge; the
        // right and bottom docks hug their leading one.
        final edge:HandleEdge = switch placement {
            case Left: Trailing;
            case _: Leading;
        }

        return Resizable.resizeHandle(id, placement.axis()).inside(edge).onDrag(new ResizePanel(), (info:ResizePanel, _, _, cx:App) -> {
            cx.stopPropagation();
            shared.resizingDock = placement;
            shared.resizeStartedOpen = open;
            return (cx.newEntity((_:Context<ResizePanel>) -> info.clone()) : AnyView);
        });
    }

}

/**
 * The payload a dock's resize handle drags. It draws nothing: the handle
 * itself is the affordance.
 */
private class ResizePanel extends Model implements Render {

    public function new() {
        super();
    }

    public function clone():ResizePanel {
        return new ResizePanel();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}

/**
 * Turns the window's mouse stream into dock resizing.
 *
 * A resize is driven by pointer moves that land anywhere in the window, not
 * only on the handle, so it cannot be expressed as a listener on the handle
 * itself. This element paints nothing and exists for its `paint` hook, which
 * is the only place a window-level mouse listener can be registered.
 */
private class DockResizeTracker extends Element {

    final dock:DockContext;

    final shared:SkinShared;

    public function new(dock:DockContext, shared:SkinShared) {
        this.dock = dock;
        this.shared = shared;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.requestLayout(new Style(), null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final placement = dock.placement();
        final dock = this.dock;
        final shared = this.shared;

        window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
            if (!phase.bubble() || shared.resizingDock != placement) return;
            // Base opens, closes and sizes the dock from the pointer, so a drag
            // that started on a closed dock reopens it too.
            dock.resizeTo((cast event : MouseMoveEvent).position, window, cx);
        });

        window.onMouseEvent(MouseUp, (_, phase, window, cx) -> {
            if (!phase.bubble() || shared.resizingDock != placement) return;
            shared.resizingDock = null;
            dock.endResize(window, cx);
            final wasOpen = shared.resizeStartedOpen;
            // The size lives on the dock, not in the layout tree, so nothing
            // else tells a subscriber to persist it.
            shared.area().tryUpdate(cx, (area, acx) -> {
                acx.emit(DockEvent.LayoutChanged);
                DockSkin.reportUserToggle(area, placement, wasOpen, acx);
            });
        });
    }

}
