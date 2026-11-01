// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.App;
import gpui.Context;
import gpui.FocusHandle;
import gpui.Render;
import gpui.WeakEntity;
import gpui.Window;

/**
 * Behavior a dockable panel provides. Presentation lives in the layer above:
 * `gpui.component.dock.Panel` extends this with titles, toolbars, and menus.
 *
 * Rust `trait Panel: EventEmitter<PanelEvent> + Render + Focusable`. The
 * trait's default methods are in `PanelBase`, which a panel extends; the
 * events it emits are `PanelEvent`s.
 */
interface Panel extends Render {

    /**
     * Identifies the panel in persisted layouts. Once chosen, never change it.
     */
    function panelName():String;

    /**
     * Whether the panel is drawn at all. A hidden panel keeps its place in
     * the layout tree and its tab, and reappears when this turns back on;
     * a container whose panels are all hidden gives up its slot.
     */
    function visible(cx:App):Bool;

    /**
     * Whether the panel may be closed. A container can still refuse (the
     * last group of a dock does), so this is permission, not a guarantee.
     */
    function closable(cx:App):Bool;

    /**
     * Whether the panel can zoom at all. Where the zoom control appears is a
     * presentation decision and belongs to the layer above.
     */
    function zoomable(cx:App):Bool;

    /**
     * Called with the frame-end net state when this panel becomes, or stops
     * being, the displayed tab of its group: exactly one notification per
     * edge, delivered on the next tick after the change, never same-value
     * repeats nor false-then-true flips within one frame.
     *
     * A panel removed from its group is NOT told `false`; `onRemoved` is the
     * deactivation signal. A hidden panel occupying the active slot still
     * receives `true` even though rendering falls back to the first visible
     * panel.
     */
    function setActive(active:Bool, window:Window, cx:Context<Dynamic>):Void;

    /**
     * Called when the group displaying this panel zooms in or out.
     *
     * Only the panel that is currently displayed is told: a group has one
     * zoom state, and it is the visible panel that fills the dock.
     */
    function setZoomed(zoomed:Bool, window:Window, cx:Context<Dynamic>):Void;

    /**
     * Called when the panel joins a tab group, with a weak handle on it.
     *
     * Delivered before any `setActive`, so a panel can hold the handle and
     * act on the first activation. A panel moved between groups is told
     * again, with the new group; it is not told it was removed in between.
     */
    function onAddedTo(group:WeakEntity<TabGroup>, window:Window, cx:Context<Dynamic>):Void;

    /**
     * Called when the panel leaves the dock for good: closed, or displaced
     * by a wholesale `setCenter`, `setDock`, `removeDock` or `load`.
     *
     * This is also the deactivation signal: a panel that was displayed is not
     * told `setActive(false)` on its way out. A panel dragged from one group
     * to another never leaves the dock, so it never hears this.
     */
    function onRemoved(window:Window, cx:Context<Dynamic>):Void;

    /**
     * The panel's own persisted state, written into the layout under its
     * `panelName` and handed back to the `PanelRegistry` builder on the next
     * load.
     */
    function dump(cx:App):PanelState;

    /**
     * Rust `Focusable::focus_handle`.
     */
    function focusHandle(cx:App):FocusHandle;

}
