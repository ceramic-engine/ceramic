// Ported from gpui-kit 0.8.1: crates/component/src/sidebar/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.sidebar;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ListAlignment;
import glaze.ListState;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Collapsible;
import glaze.kit.base.Geometry.Side;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.animation.Easings;
import glaze.kit.base.animation.EffectTransition;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.scroll.Scrollable;

/**
 * The way a `Sidebar` behaves when it is collapsed.
 *
 * This follows the shadcn/ui sidebar modes:
 * - `Icon` collapses the sidebar to icon width.
 * - `Offcanvas` slides the sidebar out and releases its layout width.
 * - `None` keeps the sidebar expanded and ignores collapsed state.
 */
enum abstract SidebarCollapsible(Int) {

    /** Collapse the sidebar to icon width. */
    var Icon;

    /** Collapse the sidebar completely out of the layout. */
    var Offcanvas;

    /** Disable sidebar collapse. */
    var None;

    /**
     * Rust `From<bool>`: `true` is `Icon`, `false` is `None`.
     */
    @:from public static inline function fromBool(collapsible:Bool):SidebarCollapsible {
        return collapsible ? Icon : None;
    }

}

/**
 * How the animated wrapper of a sidebar is laid out.
 */
enum SidebarWrapperLayout {
    None;
    Static(width:Pixels);
    Animated(targetWidth:Pixels);
}

/**
 * The layout a sidebar resolves from its collapse mode, collapsed state,
 * expanded width and side.
 */
@:allow(glaze.kit.sidebar, tests)
class SidebarLayout {

    final iconCollapsed:Bool;

    final offcanvasCollapsed:Bool;

    final alignChildToEnd:Bool;

    final wrapper:SidebarWrapperLayout;

    function new(collapsible:SidebarCollapsible, collapsed:Bool, expandedWidth:Null<Pixels>, side:Side) {
        final collapsed = collapsed && collapsible != SidebarCollapsible.None;
        final wrapper = switch collapsible {
            case SidebarCollapsible.None: SidebarWrapperLayout.None;
            case SidebarCollapsible.Icon:
                if (expandedWidth != null) {
                    SidebarWrapperLayout.Animated(collapsed ? Sidebar.COLLAPSED_WIDTH : expandedWidth);
                } else {
                    SidebarWrapperLayout.None;
                }
            case _:
                if (expandedWidth != null && collapsed) {
                    SidebarWrapperLayout.Animated(0.);
                } else if (expandedWidth != null) {
                    SidebarWrapperLayout.Animated(expandedWidth);
                } else if (collapsed) {
                    SidebarWrapperLayout.Static(0.);
                } else {
                    SidebarWrapperLayout.None;
                }
        };
        final alignChildToEnd = switch collapsible {
            case SidebarCollapsible.Offcanvas: side.isLeft();
            case _: side.isRight();
        };

        this.iconCollapsed = collapsed && collapsible == SidebarCollapsible.Icon;
        this.offcanvasCollapsed = collapsed && collapsible == SidebarCollapsible.Offcanvas;
        this.alignChildToEnd = alignChildToEnd;
        this.wrapper = wrapper;
    }

}

/**
 * The width animation of a sidebar, kept in keyed state across renders.
 */
@:allow(glaze.kit.sidebar, tests)
class SidebarAnimationState {

    var fromWidth:Pixels;

    var targetWidth:Pixels;

    var renderChild:Bool;

    var hideScheduled:Bool = false;

    var hideRequest:Int = 0;

    function new(targetWidth:Pixels, renderChild:Bool) {
        this.fromWidth = targetWidth;
        this.targetWidth = targetWidth;
        this.renderChild = renderChild;
    }

    function copy():SidebarAnimationState {
        final result = new SidebarAnimationState(targetWidth, renderChild);
        result.fromWidth = fromWidth;
        result.hideScheduled = hideScheduled;
        result.hideRequest = hideRequest;
        return result;
    }

    function needsUpdate(targetWidth:Pixels, offcanvasCollapsed:Bool):Bool {
        final childStateChanged = if (offcanvasCollapsed) {
            renderChild && !hideScheduled;
        } else {
            !renderChild || hideScheduled;
        };

        return (this.targetWidth : Float) != (targetWidth : Float) || childStateChanged;
    }

    function updateTarget(targetWidth:Pixels, offcanvasCollapsed:Bool):Null<Int> {
        if ((this.targetWidth : Float) != (targetWidth : Float)) {
            this.fromWidth = this.targetWidth;
            this.targetWidth = targetWidth;
        }

        if (offcanvasCollapsed) {
            if (renderChild && !hideScheduled) {
                hideScheduled = true;
                hideRequest = hideRequest + 1;
                return hideRequest;
            } else {
                return null;
            }
        } else {
            renderChild = true;
            if (hideScheduled) {
                hideRequest = hideRequest + 1;
            }
            hideScheduled = false;
            return null;
        }
    }

    function finishHide(request:Int):Bool {
        if (renderChild && hideScheduled && hideRequest == request && (targetWidth : Float) == 0.) {
            renderChild = false;
            hideScheduled = false;
            return true;
        } else {
            return false;
        }
    }

}

/**
 * An item of a `Sidebar` (Rust trait `SidebarItem: Collapsible + Clone`).
 */
interface SidebarItem extends Collapsible {

    /**
     * Rust `Clone`: the list renders its items on demand, from copies.
     */
    function cloneItem():SidebarItem;

    /**
     * Rust `SidebarItem::render`.
     */
    function renderItem(id:ElementId, window:Window, cx:App):IntoElement;

}

/**
 * A Sidebar element that can contain collapsible child elements.
 */
class Sidebar<E:SidebarItem> extends Component implements Styled {

    @:allow(glaze.kit.sidebar, tests)
    static inline final DEFAULT_WIDTH:Pixels = 255.;

    @:allow(glaze.kit.sidebar, tests)
    static inline final COLLAPSED_WIDTH:Pixels = 48.;

    /** Seconds. */
    static inline final SIDEBAR_TRANSITION_DURATION:Float = 0.2;

    final id:ElementId;

    final sidebarStyle:StyleRefinement = new StyleRefinement();

    final content:Array<E> = [];

    /** header view */
    var headerValue:Null<AnyElement> = null;

    /** footer view */
    var footerValue:Null<AnyElement> = null;

    /**
     * Set the side of the sidebar.
     *
     * Default is `Side.Left`.
     */
    @prop var side:Side = Left;

    /**
     * Set how the sidebar collapses.
     *
     * Passing `true` keeps the previous behavior and maps to
     * `SidebarCollapsible.Icon`. Passing `false` maps to
     * `SidebarCollapsible.None`.
     */
    @prop var collapsible:SidebarCollapsible = SidebarCollapsible.Icon;

    /**
     * Set the sidebar to be collapsed
     */
    @prop var collapsed:Bool = false;

    /**
     * Create a new Sidebar with the given ID.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    /**
     * Set the header of the sidebar.
     */
    public function header(header:IntoElement):Sidebar<E> {
        headerValue = header.intoAnyElement();
        return this;
    }

    /**
     * Set the footer of the sidebar.
     */
    public function footer(footer:IntoElement):Sidebar<E> {
        footerValue = footer.intoAnyElement();
        return this;
    }

    /**
     * Add a child element to the sidebar, the child must implement `Collapsible`
     */
    public function child(child:E):Sidebar<E> {
        if (child != null) content.push(child);
        return this;
    }

    /**
     * Add multiple children to the sidebar, the children must implement `Collapsible`
     */
    public function children(children:Iterable<E>):Sidebar<E> {
        glaze.util.Iterables.appendNonNull(content, children);
        return this;
    }

    public inline function style():StyleRefinement {
        return sidebarStyle;
    }

    @:allow(glaze.kit.sidebar, tests)
    static function sidebarExpandedWidth(style:StyleRefinement):Null<Pixels> {
        return switch style.sizeWidth {
            case Definite(Absolute(Pixels(px))): px;
            case null: DEFAULT_WIDTH;
            case _: null;
        }
    }

    /**
     * Rust packs both widths into a `NamedInteger`; the port names them,
     * which keeps them distinct the same way.
     */
    @:allow(glaze.kit.sidebar, tests)
    static function sidebarAnimationId(id:ElementId, from:Pixels, to:Pixels):ElementId {
        return ElementId.NamedChild(ElementId.Name('${elementIdString(id)}-anim-w'), '$from:$to');
    }

    static function sidebarWrapper(id:ElementIdArg, alignChildToEnd:Bool):glaze.Div {
        final wrapper = div()
            .id(id)
            .flex()
            .hFull()
            .flexShrink0()
            .overflowHidden();
        if (alignChildToEnd) wrapper.justifyEnd();
        return wrapper;
    }

    /**
     * Rust `format!("{}", id)` (`Display for ElementId`).
     */
    @:allow(glaze.kit)
    static function elementIdString(id:ElementId):String {
        return switch id {
            case View(entityId): 'view-$entityId';
            case Integer(ix): '$ix';
            case Name(name): name;
            case NamedInteger(name, ix): '$name-$ix';
            case CodeLocation(file, line): '$file:$line';
            case NamedChild(parent, name): '${elementIdString(parent)}-$name';
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        sidebarStyle.paddingTop = null;
        sidebarStyle.paddingRight = null;
        sidebarStyle.paddingBottom = null;
        sidebarStyle.paddingLeft = null;

        final id = this.id;
        final idString = elementIdString(id);
        final contentLen = content.length;
        final overdraw = window.viewportSize().height * 0.3;
        final listState:ListState = window.useKeyedState('$idString-list-state', cx, _ -> new ListState(contentLen, ListAlignment.Top, overdraw)).read(cx).value;
        if (listState.itemCount() != contentLen) {
            listState.reset(contentLen);
        }

        // Determine effective expanded width from user's custom style or default.
        // Non-pixel widths still render correctly, but cannot use pixel width transitions.
        final expandedWidth = sidebarExpandedWidth(sidebarStyle);
        final layout = new SidebarLayout(collapsible, collapsed, expandedWidth, side);

        // Sidebar content renders at its target width immediately. A wrapper
        // div animates clip-width for smooth transitions without re-laying out
        // sidebar content each animation frame.
        final sidebar = vFlex()
            .id(id)
            .flexShrink0()
            .hFull()
            .overflowHidden()
            .relative()
            .bg(theme.tokens.sidebar.background)
            .textColor(theme.sidebarForeground)
            .borderColor(theme.sidebarBorder);
        switch side {
            case Left: sidebar.borderR1();
            case Right: sidebar.borderL1();
        }
        if (sidebarStyle.sizeWidth == null) {
            sidebar.w(DEFAULT_WIDTH);
        }
        sidebar.refineStyle(sidebarStyle);
        if (layout.iconCollapsed) {
            sidebar.w(COLLAPSED_WIDTH).gap2();
        }
        if (headerValue != null) {
            final header = hFlex()
                .id('header')
                .pt3()
                .px3()
                .gap2();
            if (layout.iconCollapsed) header.pt2().px2();
            sidebar.child(header.child(headerValue));
            headerValue = null;
        }
        final content = this.content;
        final inner = vFlex()
            .id('inner')
            .sizeFull()
            .px3()
            .gapY3();
        if (layout.iconCollapsed) inner.p2();
        inner.child(new ScrollBounce('bounce', listState, list(listState, (ix, window, cx) -> {
            final group:Null<SidebarItem> = ix < content.length ? content[ix].cloneItem() : null;
            final isFirst = ix == 0;
            final isLast = contentLen > 0 && ix == (contentLen > 0 ? contentLen - 1 : 0);
            final row = div().id(ix);
            if (group != null) {
                group.setCollapsed(layout.iconCollapsed);
                row.child(group.renderItem(ElementId.Integer(ix), window, cx).intoAnyElement());
            }
            if (isFirst) row.pt3();
            if (isLast) row.pb3();
            return row.intoAnyElement();
        }).sizeFull()));
        inner.verticalScrollbar(listState);
        sidebar.child(vFlex().id('content').flex1().minH0().child(inner));
        if (footerValue != null) {
            final footer = hFlex()
                .id('footer')
                .pb3()
                .px3()
                .gap2();
            if (layout.iconCollapsed) footer.pt2().px2();
            sidebar.child(footer.child(footerValue));
            footerValue = null;
        }

        final targetWidth:Pixels = switch layout.wrapper {
            case None: return sidebar;
            case Static(width):
                final wrapper = sidebarWrapper('$idString-anim', layout.alignChildToEnd).w(width);
                if (!layout.offcanvasCollapsed) wrapper.child(sidebar);
                return wrapper;
            case Animated(targetWidth): targetWidth;
        };

        // Store animation state in keyed state so it remains stable across
        // re-renders (GPUI re-renders the whole tree on each animation frame).
        // The target width is derived from the current layout, so changes to
        // collapsible mode or expanded width are handled even if `collapsed`
        // itself does not change. Offcanvas keeps content mounted while the
        // close transition runs, then unmounts it so hidden controls leave the
        // tab order.
        final animationState = window.useKeyedState('$idString-anim-w', cx, _ -> new SidebarAnimationState(targetWidth, !layout.offcanvasCollapsed));

        final hideRequest:Null<Int> = if (animationState.read(cx).value.needsUpdate(targetWidth, layout.offcanvasCollapsed)) {
            animationState.update(cx, (state, _) -> state.value.updateTarget(targetWidth, layout.offcanvasCollapsed));
        } else {
            null;
        };
        if (hideRequest != null) {
            cx.spawn(acx -> acx.backgroundExecutor().timer(SIDEBAR_TRANSITION_DURATION).then(_ -> {
                animationState.update(acx, (state, cx) -> {
                    if (state.value.finishHide(hideRequest)) {
                        cx.notify();
                    }
                });
            }));
        }
        final animation = animationState.read(cx).value.copy();
        final fromW = animation.fromWidth;
        final toW = animation.targetWidth;

        final wrapper = sidebarWrapper('$idString-anim', layout.alignChildToEnd);
        if (animation.renderChild) wrapper.child(sidebar);

        return new EffectTransition(SIDEBAR_TRANSITION_DURATION)
            .ease(Easings.easeInOutCubic)
            .width(fromW, toW)
            .apply(wrapper, sidebarAnimationId(id, fromW, toW));
    }

}

/**
 * Toggle button to collapse/expand the `Sidebar`.
 */
class SidebarToggleButton extends Component {

    var btn:Button;

    /**
     * Set the collapsed state of the toggle button.
     */
    @prop var collapsed:Bool = false;

    /**
     * Set the side of the toggle button.
     *
     * Default is `Side.Left`.
     */
    @prop var side:Side = Left;

    var onClickValue:Null<(ClickEvent, Window, App) -> Void> = null;

    /**
     * Create a new SidebarToggleButton.
     */
    public function new() {
        super();
        btn = Button.component('collapse').ghost().small();
    }

    /**
     * Set the accessibility label of the toggle button.
     *
     * The default toggle is icon-only; without an explicit label it has no
     * accessible name.
     */
    public function accessibilityLabel(label:String):SidebarToggleButton {
        btn = btn.accessibilityLabel(label);
        return this;
    }

    /**
     * Add a click handler to the toggle button.
     */
    public function onClick(onClick:(ClickEvent, Window, App) -> Void):SidebarToggleButton {
        onClickValue = onClick;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final collapsed = this.collapsed;
        final onClick = onClickValue;

        final icon = if (collapsed) {
            side.isLeft() ? IconName.PanelLeftOpen : IconName.PanelRightOpen;
        } else {
            side.isLeft() ? IconName.PanelLeftClose : IconName.PanelRightClose;
        };

        if (onClick != null) {
            btn.onClick((ev, window, cx) -> onClick(ev, window, cx));
        }
        return btn.icon(glaze.kit.Icon.component(icon).size4());
    }

}
