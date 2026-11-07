// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/mod.rs (tests), crates/component/src/sidebar/menu.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.ElementId;
import gpui.Pixels;
import gpui.base.Geometry.Side;
import gpui.component.sidebar.Sidebar;
import gpui.component.sidebar.SidebarMenu;
import testing.TestCase;

/**
 * The `#[cfg(test)]` tests of gpui-component's `sidebar` module.
 */
class ComponentSidebarTest extends TestCase {

    static function layout(collapsible:SidebarCollapsible, collapsed:Bool, expandedWidth:Null<Pixels>, side:Side):SidebarLayout {
        return @:privateAccess new SidebarLayout(collapsible, collapsed, expandedWidth, side);
    }

    static function wrapper(layout:SidebarLayout):String {
        return Std.string(@:privateAccess layout.wrapper);
    }

    function testBoolCollapsibleShouldRemainBackwardCompatible() {
        assertEquals(SidebarCollapsible.Icon, SidebarCollapsible.fromBool(true));
        assertEquals(SidebarCollapsible.None, SidebarCollapsible.fromBool(false));
    }

    function testIconCollapsedShouldUseIconWidthAndIconRendering() {
        final layout = layout(SidebarCollapsible.Icon, true, 240., Left);

        assertTrue(layout.iconCollapsed);
        assertFalse(layout.offcanvasCollapsed);
        assertFalse(layout.alignChildToEnd);
        assertEquals(Std.string(SidebarWrapperLayout.Animated(Sidebar.COLLAPSED_WIDTH)), wrapper(layout));
    }

    function testIconExpandedShouldUseExpandedWidth() {
        final layout = layout(SidebarCollapsible.Icon, false, 240., Left);

        assertFalse(layout.iconCollapsed);
        assertFalse(layout.offcanvasCollapsed);
        assertEquals(Std.string(SidebarWrapperLayout.Animated(240.)), wrapper(layout));
    }

    function testIconExpandedWithNonPixelWidthShouldKeepOriginalLayout() {
        final layout = layout(SidebarCollapsible.Icon, false, null, Left);

        assertFalse(layout.iconCollapsed);
        assertFalse(layout.offcanvasCollapsed);
        assertEquals(Std.string(SidebarWrapperLayout.None), wrapper(layout));
    }

    function testNoneShouldIgnoreCollapsedState() {
        final layout = layout(SidebarCollapsible.None, true, 240., Right);

        assertFalse(layout.iconCollapsed);
        assertFalse(layout.offcanvasCollapsed);
        assertTrue(layout.alignChildToEnd);
        assertEquals(Std.string(SidebarWrapperLayout.None), wrapper(layout));
    }

    function testOffcanvasCollapsedWithPixelWidthShouldAnimateToZero() {
        final layout = layout(SidebarCollapsible.Offcanvas, true, 240., Left);

        assertFalse(layout.iconCollapsed);
        assertTrue(layout.offcanvasCollapsed);
        assertTrue(layout.alignChildToEnd);
        assertEquals(Std.string(SidebarWrapperLayout.Animated(0.)), wrapper(layout));
    }

    function testOffcanvasExpandedWithPixelWidthShouldUseExpandedWidth() {
        final layout = layout(SidebarCollapsible.Offcanvas, false, 240., Left);

        assertFalse(layout.iconCollapsed);
        assertFalse(layout.offcanvasCollapsed);
        assertEquals(Std.string(SidebarWrapperLayout.Animated(240.)), wrapper(layout));
    }

    function testOffcanvasCollapsedWithNonPixelWidthShouldStaticallyReleaseLayout() {
        final layout = layout(SidebarCollapsible.Offcanvas, true, null, Left);

        assertFalse(layout.iconCollapsed);
        assertTrue(layout.offcanvasCollapsed);
        assertEquals(Std.string(SidebarWrapperLayout.Static(0.)), wrapper(layout));
    }

    function testOffcanvasExpandedWithNonPixelWidthShouldKeepOriginalLayout() {
        final layout = layout(SidebarCollapsible.Offcanvas, false, null, Left);

        assertFalse(layout.iconCollapsed);
        assertFalse(layout.offcanvasCollapsed);
        assertEquals(Std.string(SidebarWrapperLayout.None), wrapper(layout));
    }

    function testOffcanvasShouldAnchorChildTowardTheContentEdge() {
        final left = layout(SidebarCollapsible.Offcanvas, true, 240., Left);
        final right = layout(SidebarCollapsible.Offcanvas, true, 240., Right);

        assertTrue(left.alignChildToEnd);
        assertFalse(right.alignChildToEnd);
    }

    function testAnimationIdShouldBeScopedToSidebarId() {
        final from:Pixels = 240.;
        final to = Sidebar.COLLAPSED_WIDTH;

        assertFalse(Type.enumEq(
            Sidebar.sidebarAnimationId(ElementId.Name('sidebar-a'), from, to),
            Sidebar.sidebarAnimationId(ElementId.Name('sidebar-b'), from, to)
        ));
    }

    function testAnimationStateShouldKeepChildUntilOffcanvasHideFinishes() {
        final state = @:privateAccess new SidebarAnimationState(240., true);

        final request = state.updateTarget(0., true);

        assertEquals(1, request);
        assertEquals(240., state.fromWidth);
        assertEquals(0., state.targetWidth);
        assertTrue(state.renderChild);

        assertTrue(state.finishHide(1));

        assertFalse(state.renderChild);
        assertFalse(state.hideScheduled);
    }

    function testAnimationStateShouldNotReschedulePendingOffcanvasHide() {
        final state = @:privateAccess new SidebarAnimationState(240., true);

        final request = state.updateTarget(0., true);

        assertEquals(1, request);
        assertFalse(state.needsUpdate(0., true));
        assertEquals(null, state.updateTarget(0., true));
        assertEquals(1, state.hideRequest);
    }

    function testAnimationStateShouldCancelPendingHideWhenReexpanded() {
        final state = @:privateAccess new SidebarAnimationState(240., true);

        final request = state.updateTarget(0., true);
        state.updateTarget(240., false);

        assertFalse(state.finishHide(request));
        assertTrue(state.renderChild);
        assertFalse(state.hideScheduled);
        assertEquals(0., state.fromWidth);
        assertEquals(240., state.targetWidth);
    }

    function testAnimationStateShouldIgnoreStaleHideRequest() {
        final state = @:privateAccess new SidebarAnimationState(240., true);

        final request = state.updateTarget(0., true);
        state.updateTarget(240., false);
        state.updateTarget(0., true);

        assertFalse(state.finishHide(request));
        assertTrue(state.renderChild);
        assertTrue(state.hideScheduled);
    }

    function testAnimationStateShouldStartHiddenWhenInitiallyOffcanvasCollapsed() {
        final state = @:privateAccess new SidebarAnimationState(0., false);

        assertFalse(state.renderChild);
        assertEquals(0., state.fromWidth);
        assertEquals(0., state.targetWidth);
    }

/// menu.rs

    function testCollapsedIconItemUsesLabelAsTooltip() {
        final item = new SidebarMenuItem('Projects')
            .icon(gpui.component.Icon.empty())
            .collapsed(true);

        assertEquals('Projects', item.collapsedTooltip());
    }

    function testExpandedOrIconlessItemHasNoCollapsedTooltip() {
        final expanded = new SidebarMenuItem('Projects').icon(gpui.component.Icon.empty());
        final iconless = new SidebarMenuItem('Projects').collapsed(true);

        assertEquals(null, expanded.collapsedTooltip());
        assertEquals(null, iconless.collapsedTooltip());
    }

    function testSubmenuCaretIsNamedAfterTheItem() {
        final item = new SidebarMenuItem('Projects').children([new SidebarMenuItem('Overview')]);

        assertEquals('Toggle Projects submenu', item.caretAccessibilityLabel());
    }

}
