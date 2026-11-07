// Ported from gpui-kit 0.8.1: crates/component/src/dock/tab_panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

import gpui.Anchor;
import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Div;
import gpui.ElementId;
import gpui.Empty;
import gpui.IntoElement;
import gpui.Point;
import gpui.ScrollHandle;
import gpui.Size;
import gpui.StyleBuilder;
import gpui.Window;
import gpui.base.dock.AnyDrag;
import gpui.base.dock.DockPlacement;
import gpui.base.dock.DragPanel;
import gpui.base.dock.DropIndicator;
import gpui.base.dock.NodeId;
import gpui.base.dock.PaneNode;
import gpui.base.dock.TabGroupContext;
import gpui.base.dock.TabGroupRendererBase;
import gpui.base.motion.Motion;
import gpui.base.motion.TransitionId;
import gpui.component.I18n;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.button.Button.ButtonCustomVariant;
import gpui.component.dock.DockDebugBounds.DebugSelectorTab;
import gpui.component.tab.Tab;
import gpui.component.tab.TabBar;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.component.menu.DropdownMenu;

/**
 * One tab group's appearance.
 *
 * `gpui.base.dock.TabGroup` owns the behavior (membership, the displayed
 * tab, drag hit-testing, the zoom flag) and draws none of it. Everything
 * visible is here: the tab bar, the toolbar, the ellipsis menu, the dock
 * collapse affordances, the drop placeholder, and the styled drag preview.
 *
 * Built per group (`DockAreaRenderer.tabGroupRenderer` is called once per
 * container), so the tab bar's scroll position belongs to the group whose
 * tabs it scrolls.
 */
@:allow(gpui.component.dock, tests)
class TabGroupSkin extends TabGroupRendererBase {

    /**
     * Names the tab bar's zoom button in the debug-bounds map, so a test can
     * ask a really-drawn frame whether the control was offered.
     */
    static inline final ZOOM_CONTROL_SELECTOR = 'dock-tab-bar-zoom-control';

    /**
     * Debug-bounds selector for a tab's close (X) button, for tests.
     */
    static inline final CLOSE_BUTTON_SELECTOR = 'dock-tab-close-button';

    /**
     * Debug-bounds selector prefix for a tab, suffixed with its panel index.
     */
    static inline final TAB_SELECTOR = 'dock-tab';

    /**
     * Debug-bounds selector prefix for a dock's collapse button, suffixed
     * with its placement.
     */
    static inline final DOCK_TOGGLE_SELECTOR = 'dock-toggle';

    /**
     * The size the styled drag preview occupies, reported to base so a drop
     * placeholder knows where to fly in from.
     */
    static final DRAG_PREVIEW_SIZE:Size = new Size(96., 30.);

    final shared:SkinShared;

    final scrollHandle:ScrollHandle = new ScrollHandle();

    /**
     * The displayed tab the last frame drew, so a change scrolls the new tab
     * into view. The group owns selection, so the skin notices instead of
     * being told. Rust `Rc<Cell<Option<usize>>>`.
     */
    final lastActiveIx:{value:Null<Int>} = {value: null};

    function new(shared:SkinShared) {
        super();
        this.shared = shared;
    }

/// Free functions of tab_panel.rs

    /**
     * Where the zoom affordance goes for the group's displayed panel, or
     * `null` when there is none to offer.
     *
     * Two questions, and both have to be asked. `Panel.zoomControl` says
     * where the control appears; `gpui.base.dock.Panel.zoomable` says
     * whether zooming happens at all, and base refuses a zoom that fails it.
     * A panel answering `zoomable() == false` with `zoomControl() == Toolbar`
     * would otherwise draw a button that does nothing.
     */
    static function zoomControl(group:TabGroupContext, cx:App):Null<PanelControl> {
        final panel = group.activePanel();
        if (panel == null || !panel.zoomable(cx)) return null;
        final handle = PanelHandle.of(panel);
        return handle != null ? handle.zoomControl(cx) : null;
    }

    /**
     * The payload for dragging the tab at `ix` out of its group, or `null`
     * when this group must not be rearranged.
     *
     * The guard is the skin's. `TabGroupContext.dragPanel` answers for any
     * tab in range whether or not the group may be rearranged, so a tab bar
     * that forgets to ask `TabGroupContext.isDraggable` makes a group that
     * has nowhere to go (a dock's last group, a locked dock) draggable anyway.
     */
    static function tabDrag(group:TabGroupContext, ix:Int, cx:App):Null<DragPanel> {
        return group.isDraggable() ? group.dragPanel(ix, cx) : null;
    }

    /**
     * The left-most, top-most tab group in a container, where a left dock's
     * collapse affordance goes.
     */
    static function leftTopGroup(node:PaneNode):Null<NodeId> {
        return switch node.kind() {
            case Tabs(_, _): node.id();
            case Split(_, children, _): children.length > 0 ? leftTopGroup(children[0]) : null;
        }
    }

    /**
     * The right-most, top-most tab group. A vertical split stacks its
     * children, so its first child is the top one; a horizontal split's last
     * child is the right-most.
     */
    static function rightTopGroup(node:PaneNode):Null<NodeId> {
        return switch node.kind() {
            case Tabs(_, _): node.id();
            case Split(axis, children, _):
                if (children.length == 0) null;
                else rightTopGroup(switch axis {
                    case Vertical: children[0];
                    case Horizontal: children[children.length - 1];
                });
        }
    }

    /**
     * The visible panels' indices, in tab order.
     */
    static function visibleIndices(group:TabGroupContext, cx:App):Array<Int> {
        final panels = group.panels();
        return [for (ix in 0...panels.length) if (panels[ix].visible(cx)) ix];
    }

/// Parts

    /**
     * Whether a dock's collapse affordance belongs in this group's tab bar,
     * and which way it points. `null` means this group draws none.
     */
    function dockToggleButton(placement:DockPlacement, group:TabGroupContext, cx:App):Null<IntoElement> {
        if (group.isZoomed() || !shared.isToggleButtonVisible()) return null;

        final areaEntity = shared.area().upgrade();
        if (areaEntity == null) return null;
        final area = areaEntity.read(cx);
        // A dock that does not exist is not collapsible, so this covers the
        // old `left_dock.is_some()` test too.
        if (!area.isDockCollapsible(placement)) return null;

        final designated:Null<NodeId> = switch placement {
            case Left:
                final tree = area.layout(DockPlacement.Center);
                tree != null ? leftTopGroup(tree.root()) : null;
            case Right:
                final tree = area.layout(DockPlacement.Center);
                tree != null ? rightTopGroup(tree.root()) : null;
            case Bottom:
                final tree = area.layout(DockPlacement.Bottom);
                tree != null ? leftTopGroup(tree.root()) : null;
            case Center: null;
        }
        if (designated == null || designated != group.node()) return null;

        final isOpen = area.isDockOpen(placement);
        final icon:IconName = switch [placement, isOpen] {
            case [Left, true]: IconName.PanelLeft;
            case [Left, false]: IconName.PanelLeftOpen;
            case [Right, true]: IconName.PanelRight;
            case [Right, false]: IconName.PanelRightOpen;
            case [Bottom, true]: IconName.PanelBottom;
            case [Bottom, false]: IconName.PanelBottomOpen;
            case [Center, _]: return null;
        }

        final area = shared.area();
        return DockDebugBounds.wrap(() -> '$DOCK_TOGGLE_SELECTOR-$placement', new Button('toggle-dock:$placement')
            .icon(icon)
            .xsmall()
            .ghost()
            .tabStop(false)
            .tooltip(isOpen ? I18n.t('Dock.Collapse') : I18n.t('Dock.Expand'))
            .onClick((_, window, cx) -> {
                area.tryUpdate(cx, (area, acx) -> DockSkin.toggleDockByUser(area, placement, window, acx));
            }));
    }

    /**
     * The trailing controls: the panel's own buttons, the zoom affordance,
     * and the ellipsis menu.
     */
    function renderToolbar(group:TabGroupContext, window:Window, cx:App):IntoElement {
        if (group.isCollapsed()) return div();

        final zoomed = group.isZoomed();
        final handle = PanelHandle.of(group.activePanel());
        final control = zoomControl(group, cx);
        final toolbarZoom = control != null && control.toolbarVisible();
        final menuZoom = control != null && control.menuVisible();
        final closable = group.isClosable();
        final buttons = handle != null ? handle.toolbarButtons(window, cx) : null;
        final panel:Null<PanelView> = handle != null ? handle.panel() : null;

        final toolbar = hFlex()
            .gap1()
            .occlude();
        if (buttons != null) {
            toolbar.children([for (button in buttons) (button.xsmall().ghost().tabStop(false) : IntoElement)]);
        }
        final zoom:Null<{id:String, icon:IconName, tooltip:String}> = if (zoomed) {
            {id: 'zoom-out', icon: IconName.Minimize, tooltip: I18n.t('Dock.Zoom Out')};
        } else if (toolbarZoom) {
            {id: 'zoom-in', icon: IconName.Maximize, tooltip: I18n.t('Dock.Zoom In')};
        } else null;
        if (zoom != null) {
            toolbar.child(DockDebugBounds.wrap(() -> ZOOM_CONTROL_SELECTOR, new Button(zoom.id)
                .icon(zoom.icon)
                .xsmall()
                .ghost()
                .tabStop(false)
                .tooltipWithAction(zoom.tooltip, new ToggleZoom(), null)
                .selected(zoomed)
                .onClick((_, window, cx) -> group.toggleZoom(window, cx))));
        }
        return toolbar.child(new Button('menu')
            .icon(IconName.Ellipsis)
            .xsmall()
            .ghost()
            .tabStop(false)
            .dropdownMenu((menu, window, mcx) -> {
                var menu = menu;
                if (panel != null) menu = panel.dropdownMenu(menu, window, mcx.app);
                menu = menu.separator()
                    .menuWithDisabled(zoomed ? I18n.t('Dock.Zoom Out') : I18n.t('Dock.Zoom In'), new ToggleZoom(), !menuZoom);
                if (closable) {
                    menu = menu.separator().menu(I18n.t('Dock.Close'), new ClosePanel());
                }
                return menu;
            })
            .anchor(TopRight));
    }

    /**
     * The drag listener of a tab or of the one-panel title: the styled
     * preview, and the offset and size base reads for the placeholder.
     */
    static function dragPreview(panel:gpui.base.dock.PanelView):(DragPanel, Point, Window, App) -> AnyView {
        return (drag, offset, _, cx) -> {
            cx.stopPropagation();
            drag.setDragOffset(offset);
            drag.setPreviewSize(DRAG_PREVIEW_SIZE);
            return (cx.newEntity((_:Context<DragPanelPreview>) -> new DragPanelPreview(panel)) : AnyView);
        };
    }

    /**
     * The one-panel title bar: no tabs, just the title and the controls.
     */
    function renderTitle(group:TabGroupContext, ix:Int, window:Window, cx:App):AnyElement {
        final panel = group.panels()[ix];
        final leftButton = dockToggleButton(DockPlacement.Left, group, cx);
        final bottomButton = dockToggleButton(DockPlacement.Bottom, group, cx);
        final rightButton = dockToggleButton(DockPlacement.Right, group, cx);
        final hasLeading = leftButton != null || bottomButton != null;
        final handle = PanelHandle.of(panel);
        final titleStyle = handle != null ? handle.titleStyle(cx) : null;
        final drag = tabDrag(group, ix, cx);

        final bar = hFlex()
            .justifyBetween()
            .h(px(30.))
            .py2()
            .pl3()
            .pr2()
            .when(leftButton != null, el -> el.pl2())
            .when(rightButton != null, el -> el.pr2())
            .whenSome(titleStyle, (el, style) -> el.bg(style.background).textColor(style.foreground));
        if (hasLeading) {
            final leading = hFlex()
                .flexShrink0()
                .mr1()
                .gap1();
            if (leftButton != null) leading.child(leftButton);
            if (bottomButton != null) leading.child(bottomButton);
            bar.child(leading);
        }
        final title = div()
            .id('tab')
            .flex1()
            .minW16()
            .overflowHidden()
            .textEllipsis()
            .whitespaceNowrap()
            .child(DragPanelPreview.panelTitle(panel, window, cx));
        if (drag != null) title.onDrag(drag, dragPreview(panel));
        bar.child(title);
        final suffix = handle != null ? handle.titleSuffix(window, cx) : null;
        if (suffix != null) bar.child(suffix);
        final trailing = hFlex()
            .flexShrink0()
            .ml1()
            .gap1()
            .child(renderToolbar(group, window, cx));
        if (rightButton != null) trailing.child(rightButton);
        return bar.child(trailing).intoAnyElement();
    }

    /**
     * The full tab bar.
     */
    function renderTabs(group:TabGroupContext, window:Window, cx:App):AnyElement {
        final theme = Theme.global(cx);
        final leftButton = dockToggleButton(DockPlacement.Left, group, cx);
        final bottomButton = dockToggleButton(DockPlacement.Bottom, group, cx);
        final rightButton = dockToggleButton(DockPlacement.Right, group, cx);
        final hasLeading = leftButton != null || bottomButton != null;
        final isBottomDock = bottomButton != null;
        final collapsed = group.isCollapsed();

        final droppable = group.isDroppable();
        final tabsCount = group.panels().length;
        final activeIx = group.activeIx();
        final active = group.activePanel();
        final displayed = active != null ? active.panelId(cx) : null;
        final visible = visibleIndices(group, cx);
        var displayedIx:Null<Int> = null;
        if (displayed != null) {
            final panels = group.panels();
            for (ix in 0...panels.length) {
                if (panels[ix].panelId(cx) == displayed) {
                    displayedIx = ix;
                    break;
                }
            }
        }

        // Bring a newly displayed tab into view. The group owns selection, so
        // the skin notices the change rather than being told about it.
        final previous = lastActiveIx.value;
        lastActiveIx.value = activeIx;
        if (previous != activeIx) {
            final visibleIx = visible.indexOf(activeIx);
            if (visibleIx != -1) scrollHandle.scrollToItem(visibleIx);
        }

        final bar = new TabBar('tab-bar').trackScroll(scrollHandle);
        if (hasLeading) {
            final prefix = hFlex()
                .itemsCenter()
                .top0()
                // Right -1 for avoid border overlap with the first tab
                .right(-px(1.))
                .borderR1()
                .borderB1()
                .hFull()
                .borderColor(theme.border)
                .bg(theme.tokens.tabBar.background)
                .px2();
            if (leftButton != null) prefix.child(leftButton);
            if (bottomButton != null) prefix.child(bottomButton);
            bar.prefix(prefix);
        }

        final tabs:Array<Tab> = [];
        for (ix in visible) {
            final panel = group.panels()[ix];
            final handle = PanelHandle.of(panel);
            final drag = tabDrag(group, ix, cx);

            final tab:Tab = DockDebugBounds.enabled ? new DebugSelectorTab(() -> '$TAB_SELECTOR-$ix') : new Tab();
            tab.withIx(ix).tabBarPrefix(hasLeading);
            final tabName = handle != null ? handle.tabName(cx) : null;
            tab.child(tabName != null ? (tabName : IntoElement) : DragPanelPreview.panelTitle(panel, window, cx));
            // Per-tab close (X) button. The gate mirrors `TabGroup.closePanel`,
            // plus `!collapsed`, since a collapsed strip is a way back in, not a
            // place to close. Stops propagation so the click closes by id
            // without also selecting the tab.
            if (!collapsed && shared.closeButtonVisible && group.isPanelClosable(panel.panelId(cx), cx)) {
                final panelId = panel.panelId(cx);
                final close = new Button(ElementId.NamedInteger('close-tab', ix))
                    .icon(IconName.Close)
                    .xsmall()
                    // The regular ghost hover matches the inactive tab bar
                    // background in the default theme. Use a stronger theme
                    // surface while keeping a transparent idle background and
                    // no border.
                    .custom(new ButtonCustomVariant(cx)
                        .foreground(theme.secondaryForeground)
                        .hover(theme.tokens.secondaryHover.color)
                        .active(theme.tokens.secondaryActive.color))
                    // The 20px XS button has a 12px icon: 4px inside plus 8px
                    // outside matches the label's 12px leading padding. Offset
                    // the label's own 12px right padding and the tab's 4px gap
                    // so the text-to-icon distance is also 12px.
                    .ml(-px(8.))
                    .mr2()
                    .tabStop(false)
                    .onClick((_, window, cx) -> {
                        cx.stopPropagation();
                        group.close(panelId, window, cx);
                    });
                tab.suffix(DockDebugBounds.wrap(() -> CLOSE_BUTTON_SELECTOR, close));
            }
            // A collapsed group shows no tab as active: the strip is a way back
            // in, not a selection. The comparison is against the panel on
            // screen, not the stored index: a hidden displayed tab falls back
            // to the first visible one.
            tab.selected(!collapsed && ix == displayedIx);
            final area = shared.area();
            final lastActiveIx = this.lastActiveIx;
            tab.onClick((_, window, cx) -> {
                // The tab bar reveals a clicked tab itself, so the change must
                // not snap it into view.
                lastActiveIx.value = ix;
                group.selectTab(ix, window, cx);

                // Clicking the strip of a collapsed bottom dock is how it is
                // opened again.
                if (isBottomDock && collapsed) {
                    area.tryUpdate(cx, (area, acx) -> DockSkin.toggleDockByUser(area, DockPlacement.Bottom, window, acx));
                }
            });
            // A collapsed group is a strip of tabs with no content, so there is
            // nothing to rearrange in it.
            if (!collapsed) {
                if (drag != null) tab.onDrag(drag, dragPreview(panel));
                if (droppable) {
                    tab.dragOver(DragPanel, (style, _, _, cx) -> style
                        .roundedLNone()
                        .borderL2()
                        .borderR0()
                        .borderColor(Theme.global(cx).dragBorder))
                        .onDrop(DragPanel, (drag:DragPanel, window, cx) -> group.dropPanel(drag.clone(), ix, true, window, cx))
                        .dragOver(AnyDrag, (style, _, _, cx) -> style
                            .roundedLNone()
                            .borderL2()
                            .borderR0()
                            .borderColor(Theme.global(cx).dragBorder))
                        .onDrop(AnyDrag, (item:AnyDrag, window, cx) -> group.dropItem(item.clone(), null, window, cx));
                }
            }
            tabs.push(tab);
        }
        bar.children(tabs);

        // Empty space so a panel can be moved past the last tab.
        final emptySpace = div()
            .id('tab-bar-empty-space')
            .hFull()
            .flexGrow(1.)
            .minW16();
        if (droppable) {
            final node = group.node();
            emptySpace.dragOver(DragPanel, (style, _, _, cx) -> style.bg(Theme.global(cx).tokens.dropTarget.background))
                .onDrop(DragPanel, (drag:DragPanel, window, cx) -> {
                    // A panel dropped past its own last tab lands in the final
                    // slot; one from elsewhere is appended in the background.
                    final ix:Null<Int> = drag.source() == node ? tabsCount - 1 : null;
                    group.dropPanel(drag.clone(), ix, false, window, cx);
                })
                .dragOver(AnyDrag, (style, _, _, cx) -> style.bg(Theme.global(cx).tokens.dropTarget.background))
                .onDrop(AnyDrag, (item:AnyDrag, window, cx) -> group.dropItem(item.clone(), null, window, cx));
        }
        bar.lastEmptySpace(emptySpace);

        if (!collapsed) {
            final suffix = hFlex()
                .itemsCenter()
                .top0()
                .right0()
                .borderL1()
                .borderB1()
                .hFull()
                .borderColor(theme.border)
                .bg(theme.tokens.tabBar.background)
                .px2()
                .gap1();
            final activeHandle = PanelHandle.of(group.activePanel());
            final titleSuffix = activeHandle != null ? activeHandle.titleSuffix(window, cx) : null;
            if (titleSuffix != null) suffix.child(titleSuffix);
            suffix.child(renderToolbar(group, window, cx));
            if (rightButton != null) suffix.child(rightButton);
            bar.suffix(suffix);
        }
        return (bar : IntoElement).intoAnyElement();
    }

/// TabGroupRenderer

    override public function frame(group:TabGroupContext, window:Window, cx:App):Div {
        final control = zoomControl(group, cx);

        // The column, the fill and the clip are base's, applied around this.
        // What is left is the background and the two actions.
        return div()
            .id('tab-panel')
            .bg(Theme.global(cx).tokens.background.background)
            // A collapsed group is a strip of tabs with no content, and the
            // actions act on content.
            .when(!group.isCollapsed(), el -> el
                .onAction(ToggleZoom, (_, window, cx) -> {
                    // The affordance decides the control, so a panel that
                    // offers none is not zoomed in by the keybinding either.
                    // Zooming out is never refused: a panel that stopped
                    // offering the control while zoomed would otherwise strand
                    // the user with no way back.
                    if (!group.isZoomed() && control == null) return;
                    group.toggleZoom(window, cx);
                })
                .onAction(ClosePanel, (_, window, cx) -> {
                    final panel = group.activePanel();
                    if (panel == null) return;
                    group.close(panel.panelId(cx), window, cx);
                }));
    }

    override public function contentFrame(group:TabGroupContext, window:Window, cx:App):Div {
        final handle = PanelHandle.of(group.activePanel());
        final padded = group.panels().length > 1 && (group.activePanel() == null || handle == null || handle.innerPadding(cx));

        // The fill and the collapsed-group exception are base's; the padding
        // is this skin's, and is the only reason this hook is implemented.
        return div().id('active-panel').when(padded, el -> el.pt2());
    }

    public function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement {
        final visible = visibleIndices(group, cx);

        if (visible.length == 0) return new Empty().intoAnyElement();
        if (visible.length == 1 && shared.panelStyle() == PanelStyle.Auto) {
            // A panel that draws its own chrome declines the title bar.
            final ix = visible[0];
            final handle = PanelHandle.of(group.panels()[ix]);
            if (handle != null && !handle.titleBar(cx)) return new Empty().intoAnyElement();
            return renderTitle(group, ix, window, cx);
        }
        return renderTabs(group, window, cx);
    }

    override public function renderActivePanel(panel:AnyView, group:TabGroupContext, window:Window, cx:App):AnyElement {
        if (group.isCollapsed()) return new Empty().intoAnyElement();

        return div()
            .id('tab-content')
            .overflowYScroll()
            .overflowXHidden()
            .flex1()
            .child(panel.cached(StyleBuilder.build(s -> s.absolute().sizeFull())))
            .intoAnyElement();
    }

    override public function renderDropIndicator(indicator:DropIndicator, window:Window, cx:App):Null<AnyElement> {
        final to = indicator.to();
        final theme = Theme.global(cx);
        // The placeholder chases the drop it would land in: the springs carry
        // it through crossing several drop zones in one drag.
        final id = 'drop-placeholder';
        final placeholderSpring = theme.motionTokens().springMove.withEpsilon(0.5);
        final left = Motion.spring(TransitionId.named(id, 'left'), to.origin().x, placeholderSpring, window, cx);
        final top = Motion.spring(TransitionId.named(id, 'top'), to.origin().y, placeholderSpring, window, cx);
        final width = Motion.spring(TransitionId.named(id, 'width'), to.size().width, placeholderSpring, window, cx);
        final height = Motion.spring(TransitionId.named(id, 'height'), to.size().height, placeholderSpring, window, cx);

        return div()
            .absolute()
            .bg(theme.tokens.dropTarget.background)
            .left(px(left))
            .top(px(top))
            .w(px(width))
            .h(px(height))
            .intoAnyElement();
    }

}
