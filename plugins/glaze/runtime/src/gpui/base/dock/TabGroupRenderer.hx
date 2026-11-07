// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Div;
import gpui.Window;

/**
 * Appearance for a tab group. Base draws none of it.
 *
 * The two frame hooks return the element itself rather than wrapping one,
 * because base attaches focus, keyboard grouping, and drop handling to the
 * very elements the skin styles: a wrapper would put the hit area and the
 * painted area on different elements.
 *
 * The trait's default methods are in `TabGroupRendererBase`; only
 * `renderTabBar` has no default.
 */
interface TabGroupRenderer {

    /**
     * The group's outer frame, which base tracks focus on (a `div` with an
     * id, Rust `Stateful<Div>`). Appearance only: the group is laid out as a
     * column that fills its slot around whatever this returns. A renderer
     * that needs the painted group bounds can attach `onPrepaint` here and
     * identify the group with `TabGroupContext.node`.
     */
    function frame(group:TabGroupContext, window:Window, cx:App):Div;

    /**
     * The region below the tab bar, which base installs drop handling on.
     */
    function contentFrame(group:TabGroupContext, window:Window, cx:App):Div;

    function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement;

    /**
     * How the displayed panel's view is placed in the content region. The
     * skin receives the view rather than an element so it can decide how the
     * view is cached and stretched.
     */
    function renderActivePanel(panel:AnyView, group:TabGroupContext, window:Window, cx:App):AnyElement;

    function renderDropIndicator(indicator:DropIndicator, window:Window, cx:App):Null<AnyElement>;

    function renderEmpty(group:TabGroupContext, window:Window, cx:App):Null<AnyElement>;

}
