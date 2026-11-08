// Ported from gpui-kit 0.8.1: crates/component/src/tab/tab_bar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-014 (no indicator under a disabled selected tab). See docs/DEVIATIONS.md.
package glaze.kit.tab;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Edges;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.IntoBackground;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.RenderOnce;
import glaze.ScrollHandle;
import glaze.Window.StateModel;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ScrollableMask;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu.PopupMenuItem;
import glaze.kit.tab.TabVariant.FolderTabConstants;
import glaze.kit.tab.TabVariant.FolderTabMetrics;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.InteractiveElementExt;
using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;
using glaze.kit.menu.DropdownMenu;

/**
 * The measured bounds the sliding indicator is placed from (Rust
 * `Rc<RefCell<TabIndicatorBounds>>`: written in prepaint without notifying).
 */
private class TabIndicatorBounds {

    public var container:Bounds = new Bounds();

    public final tabs:Array<Bounds>;

    /**
     * Where the last render placed the indicator: its left edge from the
     * first tab's, and its width (zero before the tabs were measured).
     */
    public var placedLeft:Float = 0.;

    public var placedWidth:Float = 0.;

    public function new(numTabs:Int) {
        tabs = [for (_ in 0...numTabs) new Bounds()];
    }

    public function resize(numTabs:Int):Void {
        while (tabs.length > numTabs) tabs.pop();
        while (tabs.length < numTabs) tabs.push(new Bounds());
    }

}

/** The indicator animation parameters: `(to_left, to_width, epoch)`. */
private typedef AnimParams = {left:Float, width:Float, epoch:Int};

/**
 * A TabBar element that contains multiple `Tab` items.
 */
class TabBar implements RenderOnce implements Styled implements Sizable {

    final id:ElementIdArg;

    final idString:String;

    final base:glaze.kit.base.Tabs;

    final tabBarStyle:StyleRefinement = new StyleRefinement();

    var scrollHandle:Null<ScrollHandle> = null;

    var prefixValue:Null<AnyElement> = null;

    var suffixValue:Null<AnyElement> = null;

    final childTabs:Array<Tab> = [];

    var lastEmptySpaceValue:AnyElement;

    var selectedIndexValue:Null<Int> = null;

    var variant:TabVariant = TabVariant.defaultValue();

    var size:Size = Medium;

    var menuValue:Bool = false;

    var maxWidthValue:Null<Pixels> = null;

    var onClickHandler:Null<(Int, Window, App) -> Void> = null;

    /** Create a new TabBar. */
    public function new(id:ElementIdArg) {
        this.id = id;
        this.idString = Std.string((id : ElementId));
        this.base = glaze.kit.base.Tabs.component(id).px(glaze.Prelude.px(-1.));
        this.lastEmptySpaceValue = div().w3().intoAnyElement();
    }

    /** Set the Tab variant, all children will inherit the variant. */
    public function withVariant(variant:TabVariant):TabBar {
        this.variant = variant;
        return this;
    }

    public function pill():TabBar {
        variant = Pill;
        return this;
    }

    public function outline():TabBar {
        variant = Outline;
        return this;
    }

    /** Set the Tab variant to Segmented, all children will inherit the variant. */
    public function segmented():TabBar {
        variant = Segmented;
        return this;
    }

    public function underline():TabBar {
        variant = Underline;
        return this;
    }

    public function folder():TabBar {
        variant = Folder;
        return this;
    }

    /** Set whether to show the menu button when tabs overflow, default is false. */
    public function menu(menu:Bool):TabBar {
        menuValue = menu;
        return this;
    }

    /**
     * Set the maximum width of each tab. Labels longer than this width are
     * truncated with an ellipsis. Does not apply to icon-only tabs. The
     * overflow menu still shows the full label.
     */
    public function maxWidth(width:Pixels):TabBar {
        maxWidthValue = width;
        return this;
    }

    /**
     * Track the scroll of the TabBar.
     *
     * Clicking a tab scrolls it into view along with part of the next tab,
     * but changing the selection, the tabs or the layout does not. Use the
     * tracked `ScrollHandle` to request an explicit reveal when needed.
     */
    public function trackScroll(scrollHandle:ScrollHandle):TabBar {
        this.scrollHandle = scrollHandle;
        return this;
    }

    /** Set the prefix element of the TabBar */
    public function prefix(prefix:IntoElement):TabBar {
        prefixValue = prefix;
        return this;
    }

    /** Set the suffix element of the TabBar */
    public function suffix(suffix:IntoElement):TabBar {
        suffixValue = suffix;
        return this;
    }

    /** Add children of the TabBar, all children will inherit the variant. */
    public function children(children:Array<Tab>):TabBar {
        for (child in children) if (child != null) childTabs.push(child);
        return this;
    }

    /** Add child of the TabBar, tab will inherit the variant. */
    public function child(child:Tab):TabBar {
        if (child != null) childTabs.push(child);
        return this;
    }

    /** Set the selected index of the TabBar. */
    public function selectedIndex(index:Int):TabBar {
        selectedIndexValue = index;
        return this;
    }

    /** Set the last empty space element of the TabBar. */
    public function lastEmptySpace(lastEmptySpace:IntoElement):TabBar {
        lastEmptySpaceValue = lastEmptySpace;
        return this;
    }

    /**
     * Set the on_click callback of the TabBar, the first parameter is the index of the clicked tab.
     *
     * When this is set, the children's on_click will be ignored.
     */
    public function onClick(onClick:(Int, Window, App) -> Void):TabBar {
        onClickHandler = onClick;
        return this;
    }

    public inline function style():StyleRefinement {
        return tabBarStyle;
    }

    public function withSize(size:IntoSize):TabBar {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    /**
     * Render the sliding indicator element for animated tab switching.
     *
     * Returns the indicator element together with the current animation
     * `epoch`, which increments on every tab switch. Tabs key their own
     * transitions (e.g. text color fade) on this epoch so they restart in sync
     * with the indicator slide.
     */
    function renderIndicator(boundsRc:Null<TabIndicatorBounds>, window:Window, cx:App):Null<{element:AnyElement, epoch:Int}> {
        final hasIndicator = variant == Segmented || variant == Pill || variant == Underline;
        final numTabs = childTabs.length;
        final selectedIx = selectedIndexValue != null ? selectedIndexValue : 0x7FFFFFFF;

        if (!(hasIndicator && numTabs > 0 && selectedIx < numTabs)) {
            return null;
        }

        final prevKey = '$idString-tab-prev';
        final animKey = '$idString-tab-anim';
        final initKey = '$idString-tab-init';

        final prevSelected = window.useKeyedState(prevKey, cx, _ -> new KeyedCell(selectedIx)).read(cx).value;
        final animParams = window.useKeyedState(animKey, cx, _ -> new KeyedCell(({left: 0., width: 0., epoch: 0} : AnimParams))).read(cx).value;
        final initialized = window.useKeyedState(initKey, cx, _ -> new KeyedCell(false)).read(cx).value;

        // First frame: trigger re-render to capture bounds via on_prepaint
        if (!initialized.value) {
            initialized.value = true;
        }

        updateAnimParams(selectedIx, boundsRc, prevSelected, animParams, cx);

        final params = animParams.value;
        if (boundsRc != null) {
            boundsRc.placedLeft = params.left;
            boundsRc.placedWidth = params.width;
        }
        if (params.width <= 0.) {
            return null;
        }

        final theme = Theme.global(cx);
        // The springs hold the indicator's own position and velocity, so a tab
        // switched again mid-slide is redirected from where the indicator
        // actually is rather than restarted from the tab it left.
        final indicatorKey = '$idString-tab-indicator';
        final left = Motion.spring(TransitionId.named(indicatorKey, 'left'), params.left, theme.motionTokens().springMove, window, cx);
        final width = Motion.spring(TransitionId.named(indicatorKey, 'width'), params.width, theme.motionTokens().springMove, window, cx);

        final innerHeight = variant.innerHeight(size);
        final innerRadius = variant.innerRadius(size, cx);

        final indicator = div()
            .absolute()
            .top0()
            .bottom0()
            .left(glaze.Prelude.px(left))
            .w(glaze.Prelude.px(width));
        switch variant {
            case Segmented:
                indicator.flex().itemsCenter().child(div()
                    .wFull()
                    .h(innerHeight)
                    .bg(theme.tokens.background.background)
                    .rounded(innerRadius)
                    .shadow(ThemeStyled.raisedShadow()));
            case Pill:
                indicator.flex().itemsCenter().child(div()
                    .sizeFull()
                    .bg(theme.tokens.primary.background)
                    .rounded(theme.radiusFull()));
            case Underline:
                indicator.child(div()
                    .absolute()
                    .left0()
                    .right0()
                    .bottom0()
                    .h(glaze.Prelude.px(2.))
                    .bg(theme.tokens.primary.background));
            case _:
        }

        return {element: indicator.intoAnyElement(), epoch: params.epoch};
    }

    /** Update animation parameters based on current and previous selection. */
    function updateAnimParams(selectedIx:Int, boundsRc:Null<TabIndicatorBounds>, prevSelected:KeyedCell<Int>, animParams:KeyedCell<AnimParams>, cx:App):Void {
        if (boundsRc == null) {
            return;
        }
        final prevIx = prevSelected.value;
        final bounds = boundsRc;
        final container = bounds.container;

        if (container.size.width == 0.) {
            if (prevIx != selectedIx) {
                prevSelected.value = selectedIx;
            }
            return;
        }

        // The indicator is nested in the first tab wrapper, so its position is
        // relative to that wrapper rather than the scroll container.
        final firstTabOrigin = bounds.tabs.length > 0 ? bounds.tabs[0].origin.x : container.origin.x;

        if (prevIx != selectedIx) {
            if (selectedIx < bounds.tabs.length) {
                final toB = bounds.tabs[selectedIx];
                final left = f32(toB.origin.x - firstTabOrigin);
                final width = toB.size.width;
                // Only a switch away from a tab that still exists restarts the
                // tabs' own epoch-keyed transitions.
                var epoch = animParams.value.epoch;
                if (prevIx >= 0 && prevIx < bounds.tabs.length) {
                    epoch = epoch + 1;
                }
                animParams.value = {left: left, width: width, epoch: epoch};
            }
            prevSelected.value = selectedIx;
            return;
        }

        if (selectedIx < bounds.tabs.length) {
            final toB = bounds.tabs[selectedIx];
            final left = f32(toB.origin.x - firstTabOrigin);
            final width = toB.size.width;
            final params = animParams.value;

            if (left != params.left || width != params.width) {
                animParams.value = {left: left, width: width, epoch: params.epoch};
            }
        }
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final defaultGap:Float = switch size {
            case Small | XSmall: 8.;
            case Large: 16.;
            case _: 12.;
        }
        var bg:IntoBackground;
        var paddings:Edges;
        var gap:Float;
        switch variant {
            case Tab:
                bg = theme.tokens.tabBar.background;
                paddings = new Edges(0., 0., 0., 0.);
                gap = 0.;
            case Outline:
                bg = theme.transparent;
                paddings = new Edges(0., 0., 0., 0.);
                gap = defaultGap;
            case Pill:
                bg = theme.transparent;
                paddings = new Edges(0., 0., 0., 0.);
                gap = 4.;
            case Segmented:
                final paddingX:Float = switch size {
                    case XSmall: 2.;
                    case Small: 3.;
                    case _: 4.;
                }
                bg = theme.tokens.tabBarSegmented.background;
                paddings = new Edges(0., paddingX, 0., paddingX);
                gap = 2.;
            case Underline:
                // This gap is same as the tab inner_paddings
                gap = switch size {
                    case XSmall: 10.;
                    case Small: 12.;
                    case Large: 20.;
                    case _: 16.;
                }
                bg = theme.transparent;
                paddings = new Edges(0., 0., 0., 0.);
            case Folder:
                bg = theme.tokens.tabBar.background;
                paddings = new Edges(0., 0., 0., 0.);
                gap = @:privateAccess FolderTabConstants.FOLDER_TAB_GAP;
        }
        final overhang = variant.overhang(size, cx);
        // Inside the tabs rather than on the bar, so the bar's prefix and
        // suffix center on the full height like the tabs' content does.
        final tabsTopPadding:Float = variant == Folder ? new FolderTabMetrics(size, cx).topPadding : 0.;

        final hasIndicator = variant == Segmented || variant == Pill || variant == Underline;
        final numTabs = childTabs.length;

        // Bounds tracking for tab indicator animation, written in prepaint
        // without triggering re-renders.
        var boundsRc:Null<TabIndicatorBounds> = null;
        if (hasIndicator && numTabs > 0) {
            boundsRc = window.useKeyedState('$idString-tab-bounds', cx, _ -> new TabIndicatorBounds(numTabs)).read(cx).value;
            boundsRc.resize(numTabs);
        }

        // Without a tracked handle the bar still needs one to reveal a clicked tab.
        final scrollHandle = this.scrollHandle != null ? this.scrollHandle : window.useKeyedState('$idString-scroll', cx, _ -> new ScrollHandle()).read(cx).value;
        final reveal = new TabReveal(
            '$idString-reveal',
            window.useKeyedState('$idString-reveal', cx, _ -> new KeyedCell((null : Null<RevealTarget>))).read(cx).value,
            scrollHandle,
            window.currentView(),
            switch size {
                case XSmall | Small: 24.;
                case Large: 40.;
                case _: 32.;
            },
            numTabs
        );
        reveal.advance(window, cx);

        final paddingX = paddings.left;
        final indicator = renderIndicator(boundsRc, window, cx);
        final indicatorEpoch = indicator != null ? indicator.epoch : 0;
        var indicatorElement:Null<AnyElement> = indicator != null ? indicator.element : null;
        final indicatorReady = indicatorElement != null;
        // Deviation DEV-014: no sliding indicator under a disabled selected
        // tab, which paints its own dimmed selected style.
        if (selectedIndexValue != null && selectedIndexValue >= 0 && selectedIndexValue < childTabs.length
            && childTabs[selectedIndexValue].disabledValue) {
            indicatorElement = null;
        }

        final hasSuffixOrMenu = suffixValue != null || menuValue;
        final view = window.currentView();
        final itemMetas:Array<{label:Null<String>, icon:Null<Icon>, disabled:Bool, onClick:Null<(ClickEvent, Window, App) -> Void>}> = [];
        final selectedIndex = selectedIndexValue;
        final tabs = base;
        final renderedTabs:Array<AnyElement> = [];
        final maxWidth = maxWidthValue;
        // A hovered folder tab shows its fill and hides the separators beside
        // it, one of which belongs to its neighbor, so the bar tracks the hover.
        final hoveredTab:Null<Entity<StateModel<Null<Int>>>> = variant == Folder ? window.useKeyedState('$idString-tab-hovered', cx, _ -> (null : Null<Int>)) : null;
        final hoveredIx:Null<Int> = hoveredTab != null ? hoveredTab.read(cx).value : null;
        final hasShape = (ix:Int) -> selectedIndex == ix || hoveredIx == ix;

        for (ix in 0...childTabs.length) {
            final child = childTabs[ix];
            itemMetas.push({label: child.labelValue, icon: child.iconValue, disabled: child.disabledValue, onClick: null});
            final tabBarPrefix = child.tabBarPrefixValue != null ? child.tabBarPrefixValue : true;
            final tab = child
                .withIx(ix)
                .tabBarPrefix(tabBarPrefix)
                .maxWidth(maxWidth)
                .withVariant(variant)
                .withSize(size);
            tab.indicatorActive = hasIndicator;
            tab.indicatorReady = indicatorReady;
            tab.indicatorEpoch = indicatorEpoch;
            tab.hovered = hoveredIx == ix;
            tab.separator = variant == Folder && ix + 1 < numTabs && !hasShape(ix) && !hasShape(ix + 1);
            final disabled = tab.disabledValue;
            if (selectedIndex != null) {
                tab.selected(selectedIndex == ix);
            }
            // The bar's callback replaces the tab's own.
            final barOnClick = onClickHandler;
            final onClick:Null<(ClickEvent, Window, App) -> Void> = barOnClick != null ? (_, window, cx) -> barOnClick(ix, window, cx) : tab.onClickHandler;
            tab.onClickHandler = onClick != null ? (event, window, cx) -> {
                reveal.reveal(ix, cx);
                onClick(event, window, cx);
            } : null;
            // The overflow menu item runs the same handler as the visible tab:
            // the bar's callback when set, otherwise the tab's own.
            itemMetas[itemMetas.length - 1].onClick = tab.onClickHandler;
            // The wrapper below is the flex item the bar lays out, so a tab's
            // own `flex_grow` / `flex_basis` (e.g. `flex_1()`) must size it.
            final flexGrow = tab.style().flexGrow;
            final flexBasis = tab.style().flexBasis;

            if (boundsRc != null) {
                final rc = boundsRc;
                final selected = selectedIndex == ix;
                // `tabs-inner` is tracked by `ScrollHandle`, which indexes its
                // direct children. Keep the indicator inside the first tab so
                // only logical tabs occupy those indices.
                final wrapper = div().flexShrink0();
                wrapper.style().flexGrow = flexGrow;
                wrapper.style().flexBasis = flexBasis;
                wrapper.onPrepaint((bounds, window, _) -> {
                    final measured = rc;
                    if (ix < measured.tabs.length) {
                        measured.tabs[ix] = bounds;
                    }
                    // Render places the indicator from the bounds an
                    // earlier frame measured, and a view that nothing
                    // changed may not render again. When the selected tab
                    // is measured elsewhere than its indicator (on the
                    // bar's first frame above all), render the view again
                    // on the next frame. Not while the bar has no width:
                    // render leaves the indicator where it was then.
                    if (selected && measured.container.size.width > 0.) {
                        final first = measured.tabs.length > 0 ? measured.tabs[0].origin.x : bounds.origin.x;
                        if (f32(bounds.origin.x - first) != measured.placedLeft || bounds.size.width != measured.placedWidth) {
                            window.onNextFrame((_, cx) -> cx.notify(view));
                        }
                    }
                });
                wrapper.relative();
                if (ix == 0 && indicatorElement != null) {
                    wrapper.child(indicatorElement);
                    indicatorElement = null;
                }
                renderedTabs.push(wrapper.child(tab).intoAnyElement());
            } else if (hoveredTab != null) {
                final state = hoveredTab;
                final wrapper = div().id(ElementId.NamedInteger('folder-tab', ix)).flexShrink0();
                wrapper.style().flexGrow = flexGrow;
                wrapper.style().flexBasis = flexBasis;
                if (!disabled) {
                    wrapper.onHover((hovered, _, cx) -> {
                        state.update(cx, (state, cx) -> {
                            final next:Null<Int> = if (hovered) ix else if (state.value == ix) null else state.value;
                            if (next != state.value) {
                                state.value = next;
                                cx.notify();
                            }
                        });
                    });
                }
                renderedTabs.push(wrapper.child(tab).intoAnyElement());
            } else {
                renderedTabs.push((tab : IntoElement).intoAnyElement());
            }
        }

        tabs.group('tab-bar')
            .relative()
            .flex()
            .itemsCenter()
            .bg(bg)
            .textColor(theme.tabForeground);
        if (variant == Underline || variant == Tab) {
            tabs.child(div()
                .id('border-b')
                .absolute()
                .left0()
                .bottom0()
                .sizeFull()
                .borderB1()
                .borderColor(theme.border));
        }
        tabs.rounded(variant.tabBarRadius(size, cx))
            .paddingsEdges(paddings)
            .refineStyle(tabBarStyle);
        if (prefixValue != null) tabs.child(prefixValue);

        final tabsInner = hFlex()
            .id('tabs-inner')
            // Fill the bar so tabs can grow into the free space;
            // as a scroll container it still shrinks below its content.
            .flex1()
            // Keep the scroll viewport inside the wrapper padding so
            // explicit reveals leave space at both ends of the bar.
            .relative()
            // Room for the end tabs' curves inside the viewport.
            .px(glaze.Prelude.px(overhang))
            .pt(glaze.Prelude.px(tabsTopPadding))
            .gap(glaze.Prelude.px(gap))
            .overflowXScroll()
            .lockScrollAxis()
            .trackScroll(scrollHandle)
            .children([for (tab in renderedTabs) (tab : IntoElement)]);
        if (hasSuffixOrMenu) tabsInner.child(lastEmptySpaceValue);

        final tabsElement = hFlex()
            .id('tabs')
            .flex1()
            .minW0()
            .mx(glaze.Prelude.px(-paddingX))
            .px(glaze.Prelude.px(paddingX))
            .overflowXHidden();
        // `on_prepaint` adds a canvas child. Keep that helper on
        // the non-scrolling wrapper so it cannot shift tab indices.
        if (boundsRc != null) {
            final rc = boundsRc;
            tabsElement.onPrepaint((bounds, _, _) -> {
                rc.container = bounds;
            });
        }
        tabsElement.child(tabsInner)
            // Outside the tracked children so tab indices stay unchanged.
            .child(ScrollableMask.verticalWheel(scrollHandle));
        tabs.child(tabsElement);

        if (menuValue) {
            final metas = itemMetas;
            tabs.child(Button.component('more')
                .xsmall()
                .ghost()
                .dropdownCaret(true)
                .dropdownMenu((menu, _, _) -> {
                    var menu = menu.scrollable(true);
                    for (ix in 0...metas.length) {
                        final meta = metas[ix];
                        final item = if (meta.label != null) {
                            PopupMenuItem.create(meta.label);
                        } else if (meta.icon != null) {
                            final icon = meta.icon;
                            PopupMenuItem.element((_, _) -> icon);
                        } else {
                            PopupMenuItem.create(I18n.t('Dock.Unnamed'));
                        }
                        item.checked(selectedIndex == ix).disabled(meta.disabled);
                        final onClick = meta.onClick;
                        if (onClick != null) {
                            item.onClick((event, window, cx) -> onClick(event, window, cx));
                        }
                        menu = menu.item(item);
                    }
                    return menu;
                })
                .anchor(Anchor.TopRight));
        }
        if (suffixValue != null) tabs.child(suffixValue);
        return tabs;
    }

}

/** The offset a reveal is travelling to, while one is. */
private typedef RevealTarget = {
    to:Float,
    /** The offset the previous frame set, `null` before the first frame. */
    last:Null<Float>,
};

/**
 * Scrolls a clicked tab into view, the way an `NSScrollView` reveals a
 * clicked row, and leaves part of the tab beyond it showing so the strip
 * visibly continues. Only a click starts this; selection, tab and layout
 * changes leave the offset where the user put it.
 */
private class TabReveal {

    final springId:String;

    /** The offset a reveal is travelling to, while one is. */
    final target:KeyedCell<Null<RevealTarget>>;

    final scrollHandle:ScrollHandle;

    final view:Int;

    /** How much of the neighbouring tab stays visible. */
    final peek:Float;

    final numTabs:Int;

    public function new(springId:String, target:KeyedCell<Null<RevealTarget>>, scrollHandle:ScrollHandle, view:Int, peek:Float, numTabs:Int) {
        this.springId = springId;
        this.target = target;
        this.scrollHandle = scrollHandle;
        this.view = view;
        this.peek = peek;
        this.numTabs = numTabs;
    }

    public function reveal(ix:Int, cx:App):Void {
        final to = offsetRevealing(ix);
        if (to == null) {
            return;
        }
        final running = target.value != null;
        if (!running && to == scrollHandle.offset().x) {
            return;
        }
        final current = target.value;
        // Retargeting keeps the spring's velocity.
        target.value = current != null ? {to: to, last: current.last} : {to: to, last: null};
        cx.notify(view);
    }

    /**
     * The horizontal offset that shows tab `ix` and `peek` of each neighbour,
     * moving as little as possible. The tab itself wins on a narrow bar.
     */
    function offsetRevealing(ix:Int):Null<Float> {
        final handle = scrollHandle;
        final viewport = handle.bounds();
        final tab = handle.boundsForItem(ix);
        if (tab == null) return null;
        final max = handle.maxOffset().x;
        // Child bounds are laid out unscrolled: content at x is on screen at
        // x + offset, so the visible content spans `viewport - offset`.
        final prev = ix > 0 ? handle.boundsForItem(ix - 1) : null;
        final wantLeft = prev != null ? Math.max(f32(prev.right() - peek), prev.left()) : viewport.left();
        final next = ix + 1 < numTabs ? handle.boundsForItem(ix + 1) : null;
        final wantRight = next != null ? Math.min(f32(next.left() + peek), next.right()) : f32(viewport.right() + max);

        var offset = handle.offset().x;
        function showLeft(left:Float):Void {
            if (left < f32(viewport.left() - offset)) {
                offset = f32(viewport.left() - left);
            }
        }
        function showRight(right:Float):Void {
            if (right > f32(viewport.right() - offset)) {
                offset = f32(viewport.right() - right);
            }
        }
        // Whichever is applied last wins: the neighbour the click heads
        // toward over the one behind it, and the tab over both.
        if (f32(tab.center().x + offset) > viewport.center().x) {
            showLeft(wantLeft);
            showRight(wantRight);
        } else {
            showRight(wantRight);
            showLeft(wantLeft);
        }
        showRight(tab.right());
        showLeft(tab.left());
        return Math.max(Math.min(offset, 0.), -max);
    }

    /** Steps a running reveal by one frame. */
    public function advance(window:Window, cx:App):Void {
        final target = this.target.value;
        if (target == null) {
            return;
        }
        final offset = scrollHandle.offset();
        // A wheel or trackpad scroll since the last frame hands the strip back.
        if (target.last != null && target.last != offset.x) {
            this.target.value = null;
            return;
        }

        final policy = Theme.global(cx).motionTokens().springMove;
        if (target.last == null) {
            // Start from where the strip is, not where a previous reveal ended.
            Motion.spring(springId, offset.x, policy.withTravel(false), window, cx);
        }
        final x = Motion.spring(springId, target.to, policy, window, cx);
        scrollHandle.setOffset(point(x, offset.y));
        this.target.value = x != target.to ? {to: target.to, last: x} : null;
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}

/**
 * A keyed state written without notifying, like Rust's `entity.update(cx,
 * |v, _| ...)` without `cx.notify()`: the `StateModel` holding it never
 * changes, so writing its fields draws nothing again.
 */
private class KeyedCell<T> {

    public var value:T;

    public function new(value:T) {
        this.value = value;
    }

}
