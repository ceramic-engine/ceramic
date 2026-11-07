// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.Div;
import gpui.Window;
import gpui.base.resizable.ResizeHandle.ResizeHandleContext;

/**
 * Appearance for the dock area. Base draws none of it.
 *
 * The frame hooks return the element itself rather than wrapping one, for the
 * same reason `TabGroupRenderer`'s do: base tracks focus and records the area
 * bounds on the very element the skin styles.
 *
 * There is no separate resize handle hook. A handle needs to be positioned
 * against the dock it resizes, and positioning is the skin's; the skin draws
 * it inside `renderDock` and drives it through `DockContext.resizeTo`.
 *
 * The trait's default methods are in `DockAreaRendererBase`; only
 * `tabGroupRenderer` has no default.
 */
interface DockAreaRenderer {

    /**
     * The area's outer frame, which base records its bounds on. Appearance
     * only: the area is laid out as a row around whatever this returns.
     */
    function frame(window:Window, cx:App):Div;

    /**
     * One split container's frame, around base's resizable group. Base
     * attaches nothing to it.
     */
    function splitFrame(node:NodeId, axis:Axis, window:Window, cx:App):Div;

    /**
     * The column holding the center region and the bottom dock. Appearance
     * only.
     */
    function centerFrame(window:Window, cx:App):Div;

    /**
     * The painted part of the divider between two slots of a split. `null`
     * keeps base's own one-pixel line; the hit area, the cursor and the drag
     * stay with base either way.
     */
    function renderSplitHandle(handle:ResizeHandleContext, window:Window, cx:App):Null<AnyElement>;

    /**
     * One dock's chrome around its content: the title strip, the collapse
     * affordance, and the resize handle. Chrome only: the dock's own box is
     * applied by `DockArea` around whatever this returns.
     */
    function renderDock(dock:DockContext, content:AnyElement, window:Window, cx:App):AnyElement;

    /**
     * The stand-in for a panel this build cannot construct (one whose
     * `panelName` no `PanelRegistry` builder answers to). `null` takes base's
     * own placeholder, which draws nothing.
     *
     * A placeholder is what gets written back out on the next save, so one
     * supplied here should answer `Panel.dump` with `state` unchanged.
     */
    function buildPlaceholder(state:PanelState, window:Window, cx:App):Null<PanelView>;

    function tabGroupRenderer():TabGroupRenderer;

}
