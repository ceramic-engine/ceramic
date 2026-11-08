// Ported from gpui-kit 0.8.1: crates/component/src/tab/tab.rs (tests), crates/component/src/tab/tab_bar.rs (tests)
// and crates/kit/tests/integration/controls.rs (checkbox_switch_and_tabs_report_controlled_state, tabs part)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Element;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.ListState;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseUpEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.TestDispatcher;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.tab.Tab;
import glaze.kit.tab.TabBar;
import glaze.kit.tab.TabVariant;
import glaze.kit.theme.Theme;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.InteractiveElementExt;
using glaze.kit.scroll.Scrollable.ScrollableElement;

/**
 * The `#[cfg(test)]` tests of gpui-component's `tab` module (`tab.rs` and
 * `tab_bar.rs`), and the tab part of gpui-kit's controls integration test.
 *
 * `debug_selector` / `debug_bounds` are stood for by `TabProbe`: a tab
 * built as a `ProbedTab` records the bounds of the element it renders, and
 * `probe(selector, element)` records the bounds of any other element. The
 * bounds are kept per window, like GPUI's.
 */
class ComponentTabTest extends TestCase {

    static final VARIANTS:Array<TabVariant> = [Tab, Outline, Pill, Segmented, Underline, Folder];

    static final LONG_LABEL = 'Account Settings & Preferences';

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        return opened.cx;
    }

    function openHarness(harness:Harness):{view:Entity<Harness>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> harness);
        contexts.push(opened.cx);
        return opened;
    }

    /** Rust `draw`: run until parked, then draw the window. */
    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    /** Rust `next_frame`: 16ms later, the next frame callbacks, then a draw. */
    static function nextFrame(cx:VisualTestContext):Void {
        cx.advanceClock(0.016);
        cx.update((window, app) -> window.simulateNextFrame(app));
        draw(cx);
    }

    static function bounds(cx:VisualTestContext, selector:String):Null<Bounds> {
        return TabProbe.boundsOf(cx.window, selector);
    }

    static function sameBounds(a:Bounds, b:Bounds):Bool {
        return a.equals(b);
    }

    function notify(view:Entity<Harness>, cx:VisualTestContext, f:(Harness) -> Void):Void {
        cx.update((_, app) -> view.update(app, (harness, c) -> {
            f(harness);
            c.notify();
        }));
    }

/// tab.rs

    /** One `TabBar`, optionally capped, holding the tab `build` returns. */
    function show(variant:TabVariant, maxWidth:Null<Pixels>, build:(Tab) -> Tab):VisualTestContext {
        return open((_, _) -> {
            final bar = new TabBar('tabs').withVariant(variant).selectedIndex(0);
            if (maxWidth != null) bar.maxWidth(maxWidth);
            return bar.child(build(new ProbedTab('tab')));
        });
    }

    /** Outer width of a labelled tab in every variant, capped or not. */
    function variantWidths(build:(Tab) -> Tab, maxWidth:Null<Pixels>):Array<Float> {
        return [for (variant in VARIANTS) {
            final cx = show(variant, maxWidth, build);
            final tab = bounds(cx, 'tab');
            assertNotNull(tab, 'tab not rendered');
            tab.size.width;
        }];
    }

    function testA11yLabelDefaultsToVisibleLabel() {
        final tab = new Tab().label('Account');
        assertEquals('Account', @:privateAccess tab.a11yLabel());
    }

    function testExplicitA11yLabelOverridesVisibleLabel() {
        final tab = new Tab().label('Acct').ariaLabel('Account settings');
        assertEquals('Account settings', @:privateAccess tab.a11yLabel());
    }

    function testMaxWidthLeavesShortTabsUntouched() {
        // The box the cap wraps the label in must not report a different
        // intrinsic width than the bare label it replaces.
        final build = (tab:Tab) -> tab.label('Go');
        final uncapped = variantWidths(build, null);
        final capped = variantWidths(build, 200.);
        assertEquals(uncapped.join(','), capped.join(','), 'a tab under the cap must not be resized');
    }

    function testMaxWidthCapsLongTabs() {
        final build = (tab:Tab) -> tab.label(LONG_LABEL);
        final uncapped = variantWidths(build, null);
        final capped = variantWidths(build, 120.);
        for (i in 0...VARIANTS.length) {
            assertTrue(uncapped[i] > 120., '${VARIANTS[i]} is not long enough to exercise the cap (${uncapped[i]})');
            assertTrue(capped[i] <= 120., '${VARIANTS[i]} width ${capped[i]} exceeds max_width');
        }
    }

    function testMaxWidthKeepsPrefixAndSuffixIntact() {
        final cx = show(Segmented, 140., tab -> tab
            .prefix(new Icon(IconName.BookOpen))
            .label(LONG_LABEL)
            .suffix(probe('suffix', div().size(px(16.)))));

        final tab = bounds(cx, 'tab');
        final suffix = bounds(cx, 'suffix');
        assertNotNull(tab, 'tab not rendered');
        assertNotNull(suffix, 'suffix not rendered');

        assertTrue(tab.size.width <= 140.);
        assertEquals(16., suffix.size.width, 'the label should absorb the truncation, not the suffix');
        assertTrue(suffix.right() <= tab.right(), 'suffix must stay within the tab');
        // A wrapping tab pushes the suffix onto a second line, which the fixed
        // tab height then clips: it keeps its size and stays inside the tab,
        // but lands back at the left edge instead of after the label.
        assertTrue(suffix.left() > tab.center().x, 'suffix must follow the label, not wrap below it');
    }

    /**
     * Icon-only tabs are sized to a square by construction, so the cap has to
     * leave them alone however narrow it is.
     */
    function testMaxWidthExemptsIconOnlyTabs() {
        final build = (tab:Tab) -> tab.icon(new Icon(IconName.BookOpen));
        final width = (maxWidth:Null<Pixels>) -> bounds(show(Tab, maxWidth, build), 'tab').size.width;

        final uncapped = width(null);
        assertTrue(uncapped > 16., 'the cap has to be narrower than the icon tab to be meaningful');
        assertEquals(uncapped, width(16.), 'an icon-only tab must ignore max_width');
    }

/// tab_bar.rs: callbacks

    function clickHarness(groupHandler:Bool, disabled:Bool):{cx:VisualTestContext, child:Array<Int>, group:Array<Int>} {
        final childClicks = [0];
        final groupClicks = [0];
        final cx = open((_, _) -> {
            final bar = new TabBar('tabs')
                .w(px(240.))
                .child(new ProbedTab('first-tab')
                    .disabled(disabled)
                    .label('First')
                    .onClick((_, _, _) -> childClicks[0]++));
            if (groupHandler) bar.onClick((ix, _, _) -> groupClicks[0] = ix + 1);
            return bar;
        });
        cx.update((window, _) -> window.draw());
        return {cx: cx, child: childClicks, group: groupClicks};
    }

    function testGroupCallbackOverridesChildCallback() {
        final h = clickHarness(true, false);
        h.cx.simulateClick(bounds(h.cx, 'first-tab').center());
        assertEquals(0, h.child[0]);
        assertEquals(1, h.group[0]);
    }

    function testChildCallbackIsPreservedWithoutGroupCallback() {
        final h = clickHarness(false, false);
        h.cx.simulateClick(bounds(h.cx, 'first-tab').center());
        assertEquals(1, h.child[0]);
        assertEquals(0, h.group[0]);
    }

    function testDisabledTabSuppressesChildAndGroupCallbacks() {
        final h = clickHarness(true, true);
        h.cx.simulateClick(bounds(h.cx, 'first-tab').center());
        assertEquals(0, h.child[0]);
        assertEquals(0, h.group[0]);
    }

/// tab_bar.rs: overflow menu

    /** Opens the overflow menu and activates its first item. */
    function chooseFirstMenuItem(groupHandler:Bool, activate:(VisualTestContext) -> Void):{clicks:Array<String>, events:Array<ClickEvent>} {
        final clicks:Array<String> = [];
        final events:Array<ClickEvent> = [];
        final tab = (label:String) -> new ProbedTab('$label-tab')
            .label(label)
            .onClick((event, _, _) -> {
                clicks.push('tab $label');
                events.push(event);
            });
        final cx = open((_, _) -> {
            final bar = new TabBar('menu-tabs')
                .w(px(240.))
                .menu(true)
                .child(tab('First'))
                .child(tab('Second'));
            if (groupHandler) bar.onClick((ix, _, _) -> clicks.push('bar $ix'));
            return div().sizeFull().child(bar);
        });
        cx.update((window, _) -> window.draw());
        final first = bounds(cx, 'First-tab');
        // The menu button is the last thing in the 240px bar.
        final more = new Point(232., first.center().y);
        cx.simulateMouseDown(more, Left);
        cx.simulateEvent(new MouseUpEvent(Left, more, Modifiers.none(), 1));
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
        activate(cx);
        cx.runUntilParked();
        return {clicks: clicks, events: events};
    }

    function testOverflowMenuRunsTheTabCallbackWithoutABarCallback() {
        assertEquals('tab First', chooseFirstMenuItem(false, cx -> cx.simulateKeystrokes('down enter')).clicks.join('|'));
    }

    function testOverflowMenuPrefersTheBarCallback() {
        assertEquals('bar 0', chooseFirstMenuItem(true, cx -> cx.simulateKeystrokes('down enter')).clicks.join('|'));
    }

    /**
     * The keyboard half of `overflow_menu_preserves_pointer_events_and_keyboard_activation`
     * (the pointer half finds the menu item through gpui-base's accessibility
     * test support, which the port does not have).
     */
    function testOverflowMenuPreservesKeyboardActivation() {
        final result = chooseFirstMenuItem(false, cx -> cx.simulateKeystrokes('down enter'));
        assertEquals('tab First', result.clicks.join('|'));
        assertEquals(1, result.events.length);
        switch result.events[0] {
            case Keyboard(_):
            case _: fail('expected a keyboard click');
        }
    }

    function testPrefixContentAndSuffixKeepTheirOrder() {
        final cx = open((_, _) -> new TabBar('content-tabs').w(px(320.)).child(new Tab()
            .prefix(probe('tab-prefix', div().child('P')))
            .child(probe('tab-child', div().child('Content')))
            .suffix(probe('tab-suffix', div().child('S')))));
        cx.update((window, _) -> window.draw());

        final prefix = bounds(cx, 'tab-prefix');
        final child = bounds(cx, 'tab-child');
        final suffix = bounds(cx, 'tab-suffix');
        assertTrue(prefix.origin.x < child.origin.x);
        assertTrue(child.origin.x < suffix.origin.x);
        assertTrue(prefix.size.width > 0.);
        assertTrue(child.size.width > 0.);
        assertTrue(suffix.size.width > 0.);
    }

/// tab_bar.rs: scrolling

    static function scrollHarnessTabs():Array<Tab> {
        return [for (ix in 0...5) new ProbedTab('tab-$ix').w(px(60.)).label('Tab $ix')];
    }

    static function dynamicTabs(h:Harness):Array<Tab> {
        return [for (ix in 0...h.tabs) new ProbedTab('dynamic-tab-$ix').w(px(60.)).label('Tab $ix')];
    }

    static function dynamicScroll(h:Harness):IntoElement {
        return probe('dynamic-bar', div().w(px(100.)).child(new TabBar('dynamic-scrolling-tabs')
            .withSize(h.size)
            .wFull()
            .segmented()
            .menu(h.menu)
            .trackScroll(h.scrollHandle)
            .selectedIndex(h.selectedIndex)
            .children(dynamicTabs(h))));
    }

    static function manualTabs(h:Harness):Array<Tab> {
        final width = h.label == 'old' ? 60. : 120.;
        final label = h.label;
        return [for (ix in 0...h.tabs) new ProbedTab('manual-tab-$ix').w(px(width)).label('Tab $ix $label')];
    }

    static function manualScroll(h:Harness):IntoElement {
        return div().w(px(160.)).h(px(40.)).child(div().relative().top(px(h.top)).wFull().child(new TabBar('manual-scrolling-tabs')
            .wFull()
            .segmented()
            .menu(true)
            .trackScroll(h.scrollHandle)
            .selectedIndex(h.selectedIndex)
            .children(manualTabs(h))));
    }

    function testScrollingToATabUsesLogicalTabIndices() {
        final scrollHandle = new ScrollHandle();
        final cx = open((_, _) -> div().w(px(100.)).child(new TabBar('scrolling-tabs')
            .wFull()
            .segmented()
            .menu(true)
            .trackScroll(scrollHandle)
            .selectedIndex(4)
            .children(scrollHarnessTabs())));

        draw(cx);
        draw(cx);
        assertEquals(0., scrollHandle.offset().x);
        scrollHandle.scrollToItem(4);
        draw(cx);
        draw(cx);

        final viewport = scrollHandle.bounds();
        final lastTab = bounds(cx, 'tab-4');
        assertTrue(lastTab.left() >= viewport.left(), 'last tab $lastTab is left of viewport $viewport, offset ${scrollHandle.offset()}');
        assertTrue(lastTab.right() <= viewport.right(), 'last tab $lastTab is right of viewport $viewport, offset ${scrollHandle.offset()}');
        assertEquals(6, scrollHandle.childrenCount());
    }

    function testScrollingToANewTabPreservesTheExplicitTarget() {
        final scrollHandle = new ScrollHandle();
        final h = new Harness(dynamicScroll);
        h.scrollHandle = scrollHandle;
        h.menu = true;
        h.tabs = 4;
        h.selectedIndex = 3;
        final opened = openHarness(h);
        final cx = opened.cx;

        draw(cx);
        draw(cx);

        notify(opened.view, cx, view -> {
            view.tabs = 5;
            view.selectedIndex = 4;
            view.scrollHandle.scrollToItem(4);
        });
        draw(cx);

        final viewport = scrollHandle.bounds();
        final lastTab = bounds(cx, 'dynamic-tab-4');
        assertTrue(lastTab.left() >= viewport.left());
        assertTrue(lastTab.right() <= viewport.right());
        assertEquals(6, scrollHandle.childrenCount());
    }

    function testScrollingToANewTabPreservesBarPadding() {
        for (entry in [{size: glaze.kit.Size.XSmall, padding: 2.}, {size: glaze.kit.Size.Small, padding: 3.}, {size: glaze.kit.Size.Medium, padding: 4.}, {size: glaze.kit.Size.Large, padding: 4.}]) {
            final scrollHandle = new ScrollHandle();
            final h = new Harness(dynamicScroll);
            h.scrollHandle = scrollHandle;
            h.menu = false;
            h.size = entry.size;
            h.tabs = 4;
            h.selectedIndex = 0;
            final opened = openHarness(h);
            final cx = opened.cx;
            draw(cx);
            draw(cx);
            notify(opened.view, cx, view -> {
                view.tabs = 5;
                view.scrollHandle.scrollToItem(4);
            });
            draw(cx);
            draw(cx);
            final bar = bounds(cx, 'dynamic-bar');
            final lastTab = bounds(cx, 'dynamic-tab-4');
            assertEquals(entry.padding, bar.right() - lastTab.right(), 'right padding for ${entry.size}');
            scrollHandle.scrollToItem(0);
            draw(cx);
            draw(cx);
            final firstTab = bounds(cx, 'dynamic-tab-0');
            assertEquals(entry.padding, firstTab.left() - bar.left(), 'left padding for ${entry.size}');
            assertEquals(5, scrollHandle.childrenCount());
        }
    }

    function manualHarness():{view:Entity<Harness>, cx:VisualTestContext, scrollHandle:ScrollHandle} {
        final scrollHandle = new ScrollHandle();
        final h = new Harness(manualScroll);
        h.scrollHandle = scrollHandle;
        h.tabs = 6;
        h.selectedIndex = 0;
        h.label = 'old';
        h.top = 0.;
        final opened = openHarness(h);
        return {view: opened.view, cx: opened.cx, scrollHandle: scrollHandle};
    }

    function testClosingAnUnselectedTrailingTabPreservesManualScrolling() {
        final m = manualHarness();
        draw(m.cx);
        m.scrollHandle.setOffset(point(px(-100.), px(0.)));
        draw(m.cx);
        assertEquals(-100., m.scrollHandle.offset().x);

        notify(m.view, m.cx, view -> view.tabs = 5);
        draw(m.cx);

        assertEquals(-100., m.scrollHandle.offset().x);
    }

    function testChangingSelectionDoesNotMoveManualScrolling() {
        final m = manualHarness();
        draw(m.cx);
        m.scrollHandle.setOffset(point(px(-100.), px(0.)));
        draw(m.cx);

        notify(m.view, m.cx, view -> view.selectedIndex = 5);
        draw(m.cx);

        assertEquals(-100., m.scrollHandle.offset().x);
    }

    function testChangingTabLabelsDoesNotMoveManualScrolling() {
        final m = manualHarness();
        draw(m.cx);
        m.scrollHandle.setOffset(point(px(-100.), px(0.)));
        draw(m.cx);

        notify(m.view, m.cx, view -> view.label = 'new');
        draw(m.cx);

        assertEquals(-100., m.scrollHandle.offset().x);
    }

    function testMovingTheTabBarPreservesManualScrolling() {
        final m = manualHarness();
        draw(m.cx);
        m.scrollHandle.setOffset(point(px(-100.), px(0.)));
        draw(m.cx);
        assertEquals(-100., m.scrollHandle.offset().x);
        final viewportSize = m.scrollHandle.bounds().size;

        notify(m.view, m.cx, view -> view.top = 20.);
        draw(m.cx);

        assertTrue(m.scrollHandle.bounds().size.equals(viewportSize));
        assertEquals(-100., m.scrollHandle.offset().x);
    }

    function testFlexTabsShareTheAvailableWidth() {
        for (variant in [Tab, Outline, Segmented, Pill, Underline]) {
            final cx = open((_, _) -> probe('flex-bar', div().w(px(200.)).child(new TabBar('flex-tabs')
                .wFull()
                .withVariant(variant)
                .selectedIndex(0)
                .child(new ProbedTab('flex-tab-0').flex1().label('A'))
                .child(new ProbedTab('flex-tab-1').flex1().label('B')))));
            draw(cx);
            draw(cx);

            final bar = bounds(cx, 'flex-bar');
            final first = bounds(cx, 'flex-tab-0');
            final second = bounds(cx, 'flex-tab-1');
            assertEquals(first.size.width, second.size.width, '$variant');
            // Only the bar's own padding may remain on either side.
            assertEquals(first.left() - bar.left(), bar.right() - second.right(), '$variant');
            assertTrue(bar.right() - second.right() <= 4., '$variant: tabs end at ${second.right()} but the bar ends at ${bar.right()}');
        }
    }

/// tab_bar.rs: click reveal

    function clickRevealHarness(groupHandler:Bool, scrollHandle:Null<ScrollHandle>, reduceMotion:Bool):VisualTestContext {
        app.update(cx -> cx.setReduceMotion(reduceMotion));
        // Neither callback notifies.
        final cx = open((_, _) -> {
            final bar = new TabBar('click-reveal-tabs').wFull();
            if (scrollHandle != null) bar.trackScroll(scrollHandle);
            bar.children([for (ix in 0...5) new ProbedTab('click-tab-$ix')
                .w(px(60.))
                .label('Tab $ix')
                .onClick((_, _, _) -> {})]);
            if (groupHandler) bar.onClick((_, _, _) -> {});
            return probe('click-bar', div().w(px(100.)).child(bar));
        });
        draw(cx);
        return cx;
    }

    function testClickingAClippedTabRevealsItAndPartOfTheNext() {
        for (groupHandler in [false, true]) {
            final cx = clickRevealHarness(groupHandler, null, true);
            final bar = bounds(cx, 'click-bar');
            var tab = bounds(cx, 'click-tab-1');
            assertTrue(tab.right() > bar.right(), 'tab 1 starts clipped');

            cx.simulateClick(tab.center());
            draw(cx);

            tab = bounds(cx, 'click-tab-1');
            final next = bounds(cx, 'click-tab-2');
            assertTrue(tab.left() >= bar.left() && tab.right() <= bar.right());
            assertEquals(32., bar.right() - next.left(), 'group: $groupHandler');
        }
    }

    function testClickingTheLastTabRevealsTheEndOfTheBar() {
        final scrollHandle = new ScrollHandle();
        final cx = clickRevealHarness(true, scrollHandle, true);
        scrollHandle.setOffset(point(px(-160.), px(0.)));
        draw(cx);

        final tab = bounds(cx, 'click-tab-4');
        cx.simulateClick(tab.origin.add(point(px(10.), px(10.))));
        draw(cx);

        assertEquals(-scrollHandle.maxOffset().x, scrollHandle.offset().x);
    }

    function testRevealAnimatesAndYieldsToManualScrolling() {
        final scrollHandle = new ScrollHandle();
        final cx = clickRevealHarness(true, scrollHandle, false);

        final tab = bounds(cx, 'click-tab-1');
        cx.simulateClick(tab.center());
        draw(cx);
        nextFrame(cx);
        final moving = scrollHandle.offset().x;
        assertTrue(moving < 0. && moving > -52., 'mid-flight at $moving');

        // The user scrolls while the reveal is still travelling.
        wheel(cx, scrollHandle.bounds().center(), Lines(point(0., 1.)), Moved);
        final manual = scrollHandle.offset().x;
        assertTrue(manual > moving);
        final afterWheel = bounds(cx, 'click-tab-1');
        for (_ in 0...30) nextFrame(cx);
        assertEquals(manual, scrollHandle.offset().x);
        assertTrue(sameBounds(afterWheel, bounds(cx, 'click-tab-1')));

        // A new click travels all the way.
        cx.simulateClick(tab.center().sub(point(px(10.), px(0.))));
        for (_ in 0...60) nextFrame(cx);
        assertEquals(-52., scrollHandle.offset().x);
    }

/// tab_bar.rs: wheel

    static function wheelTabs(handle:Null<ScrollHandle>, variant:TabVariant, tabs:Int):TabBar {
        final bar = new TabBar('wheel-tabs').wFull().withVariant(variant);
        if (handle != null) bar.trackScroll(handle);
        return bar.children([for (ix in 0...tabs) new ProbedTab('wheel-tab-$ix').w(px(60.)).label('Tab $ix')]);
    }

    static function wheel(cx:VisualTestContext, position:Point, delta:ScrollDelta, touchPhase:TouchPhase):Void {
        cx.simulateEvent(new ScrollEvent(position, delta, null, touchPhase));
        draw(cx);
    }

    function testVerticalMouseWheelScrollsEachVariantWithAndWithoutATrackedHandle() {
        for (variant in VARIANTS) {
            for (tracked in [false, true]) {
                final scrollHandle = tracked ? new ScrollHandle() : null;
                final cx = open((_, _) -> probe('wheel-bar', div().w(px(160.)).child(wheelTabs(scrollHandle, variant, 6))));
                draw(cx);
                draw(cx);
                final bar = bounds(cx, 'wheel-bar');
                final firstBefore = bounds(cx, 'wheel-tab-0');
                final lastBefore = bounds(cx, 'wheel-tab-5');
                assertTrue(lastBefore.left() > bar.right(), '$variant, tracked: $tracked');

                wheel(cx, firstBefore.center(), Lines(point(0., -100.)), Moved);
                final firstAfter = bounds(cx, 'wheel-tab-0');
                final lastAfter = bounds(cx, 'wheel-tab-5');
                assertTrue(firstAfter.left() < firstBefore.left(), '$variant, tracked: $tracked, bar $bar, first $firstBefore, after $firstAfter');
                assertTrue(lastAfter.left() >= bar.left() && lastAfter.right() <= bar.right(), '$variant, tracked: $tracked');
                if (scrollHandle != null) {
                    assertEquals(-scrollHandle.maxOffset().x, scrollHandle.offset().x);
                    assertEquals(0., scrollHandle.offset().y);
                }

                wheel(cx, firstBefore.center(), Lines(point(0., 100.)), Moved);
                assertTrue(sameBounds(firstBefore, bounds(cx, 'wheel-tab-0')), '$variant, tracked: $tracked');
                if (scrollHandle != null) {
                    assertTrue(scrollHandle.offset().equals(point(px(0.), px(0.))));
                }
            }
        }
    }

    /** `(item, offset)` as text, with `px(-0.) == px(0.)` like Rust. */
    static function describe(item:Int, offset:Float):String {
        return '$item,' + (offset == 0 ? '0' : Std.string(offset));
    }

    function testVerticalMouseWheelUsesTabsBeforeScrollingAncestors() {
        for (parentKind in 0...3) {
            for (entry in [{tabs: 6, atEnd: false}, {tabs: 6, atEnd: true}, {tabs: 1, atEnd: false}]) {
                final tabs = entry.tabs;
                final scrollHandle = new ScrollHandle();
                final parentHandle = new ScrollHandle();
                final listState = parentKind == 1 ? new ListState(10, Top, 0.).measureAll() : null;
                final cx = open((_, _) -> switch parentKind {
                    case 0:
                        vFlex()
                            .id('wheel-parent')
                            .w(px(160.))
                            .h(px(100.))
                            .overflowYScroll()
                            .lockScrollAxis()
                            .trackScroll(parentHandle)
                            .child(div().wFull().h(px(60.)).flexShrink0().child(wheelTabs(scrollHandle, Tab, tabs)))
                            .child(div().h(px(400.)).flexShrink0());
                    case 2:
                        vFlex()
                            .w(px(160.))
                            .h(px(100.))
                            .child(div().wFull().h(px(60.)).flexShrink0().child(wheelTabs(scrollHandle, Tab, tabs)))
                            .child(div().h(px(400.)).flexShrink0())
                            .overflowYScrollbar();
                    case _:
                        div()
                            .w(px(160.))
                            .h(px(100.))
                            .child(list(listState, (ix, _, _) -> {
                                if (ix == 0) {
                                    return div().wFull().h(px(60.)).child(wheelTabs(scrollHandle, Tab, tabs));
                                }
                                return div().wFull().h(px(40.));
                            }).wFull().hFull());
                });
                // Rust `WheelParent::offset`: the Scrollable keeps its handle
                // private, its movement is checked through the tab's bounds.
                function parentOffset():Null<String> {
                    return switch parentKind {
                        case 0: describe(0, -parentHandle.offset().y);
                        case 1:
                            final offset = listState.logicalScrollTop();
                            describe(offset.itemIx, offset.offsetInItem);
                        case _: null;
                    }
                }
                final atRest = describe(0, 0.);
                draw(cx);
                draw(cx);
                if (listState != null) {
                    assertTrue(listState.maxOffsetForScrollbar().y > 0.);
                }
                if (entry.atEnd) {
                    scrollHandle.setOffset(point(-scrollHandle.maxOffset().x, px(0.)));
                    draw(cx);
                }
                final beforeX = scrollHandle.offset().x;
                final firstBefore = bounds(cx, 'wheel-tab-0');
                final position = scrollHandle.bounds().center();
                final restOffset = parentOffset();
                assertEquals(atRest, restOffset != null ? restOffset : atRest);
                wheel(cx, position, Lines(point(0., -1.)), Moved);
                final firstAfter = bounds(cx, 'wheel-tab-0');
                final after = parentOffset();
                if (tabs > 1 && !entry.atEnd) {
                    assertTrue(scrollHandle.offset().x < beforeX);
                    assertTrue(firstAfter.left() < firstBefore.left());
                    assertEquals(atRest, after != null ? after : atRest);
                    assertEquals(firstBefore.top(), firstAfter.top());
                } else {
                    assertEquals(beforeX, scrollHandle.offset().x);
                    if (after != null) {
                        assertTrue(after != atRest, 'parent $parentKind, tabs $tabs, at_end ${entry.atEnd}, before_x $beforeX, first_before $firstBefore, after $firstAfter');
                    }
                    assertTrue(firstAfter.top() < firstBefore.top());
                }
            }
        }
    }

    function testVerticalMouseWheelUsesTheScrollViewportsInheritedLineHeight() {
        for (entry in [{fontSize: 12., lineHeight: 18.}, {fontSize: 24., lineHeight: 48.}]) {
            final lineHeight = entry.lineHeight;
            final scrollHandle = new ScrollHandle();
            // The scroll viewport inherits these values. Tab's own label styling
            // is below that viewport and must not determine its wheel distance.
            final cx = open((_, _) -> div()
                .w(px(160.))
                .h(px(64.))
                .textSize(px(entry.fontSize))
                .lineHeight(px(lineHeight))
                .child(wheelTabs(scrollHandle, Tab, 6)));
            draw(cx);
            draw(cx);
            final firstBefore = bounds(cx, 'wheel-tab-0');
            assertTrue(scrollHandle.maxOffset().x > lineHeight);
            assertTrue(scrollHandle.offset().equals(point(px(0.), px(0.))));

            // Use actual tab geometry: a wrapping div can have zero auto height
            // while its overflowing children still paint and accept input.
            final position = firstBefore.center();
            wheel(cx, position, Lines(point(0., -1.)), Moved);
            assertTrue(scrollHandle.offset().equals(point(-lineHeight, px(0.))), 'font ${entry.fontSize}, line height $lineHeight: ${scrollHandle.offset()}');
            final firstAfter = bounds(cx, 'wheel-tab-0');
            assertEquals(-lineHeight, firstAfter.left() - firstBefore.left());
            assertEquals(firstBefore.top(), firstAfter.top());

            wheel(cx, position, Lines(point(0., 1.)), Moved);
            assertTrue(scrollHandle.offset().equals(point(px(0.), px(0.))));
            assertTrue(sameBounds(firstBefore, bounds(cx, 'wheel-tab-0')));
        }
    }

    function testVerticalMouseWheelRespectsTheViewportAndOccludingSurfaces() {
        final scrollHandle = new ScrollHandle();
        final h = new Harness(h -> {
            final root = div()
                .relative()
                .w(px(240.))
                .h(px(64.))
                .child(wheelTabs(h.scrollHandle, Tab, 6)
                    .prefix(probe('wheel-prefix', div().w(px(40.)).h(px(32.)).child('P')))
                    .suffix(probe('wheel-suffix', div().w(px(40.)).h(px(32.)).child('S'))));
            if (h.occluded) {
                root.child(probe('wheel-occluder', div().absolute().inset0().occlude()));
            }
            return root;
        });
        h.scrollHandle = scrollHandle;
        final opened = openHarness(h);
        final cx = opened.cx;
        draw(cx);
        draw(cx);
        final firstBefore = bounds(cx, 'wheel-tab-0');
        assertTrue(scrollHandle.maxOffset().x > 0.);
        assertTrue(scrollHandle.offset().equals(point(px(0.), px(0.))));

        for (selector in ['wheel-prefix', 'wheel-suffix']) {
            final position = bounds(cx, selector).center();
            assertFalse(scrollHandle.bounds().contains(position));
            wheel(cx, position, Lines(point(0., -1.)), Moved);
            assertTrue(scrollHandle.offset().equals(point(px(0.), px(0.))));
            assertTrue(sameBounds(firstBefore, bounds(cx, 'wheel-tab-0')));
        }

        notify(opened.view, cx, view -> view.occluded = true);
        draw(cx);
        final position = scrollHandle.bounds().center();
        final occluder = bounds(cx, 'wheel-occluder');
        assertTrue(occluder.size.width > 0. && occluder.size.height > 0.);
        assertTrue(occluder.contains(position));
        wheel(cx, position, Lines(point(0., -1.)), Moved);
        assertTrue(scrollHandle.offset().equals(point(px(0.), px(0.))));
        assertTrue(sameBounds(firstBefore, bounds(cx, 'wheel-tab-0')));

        notify(opened.view, cx, view -> view.occluded = false);
        draw(cx);
        wheel(cx, position, Lines(point(0., -1.)), Moved);
        assertTrue(scrollHandle.offset().x < 0.);
        final firstAfter = bounds(cx, 'wheel-tab-0');
        assertTrue(firstAfter.left() < firstBefore.left());
        assertEquals(firstBefore.top(), firstAfter.top());
    }

/// tab_bar.rs: late bar

    /**
     * Shows a bar in a window drawn before, as a view shows one once its
     * data came, and draws the bar's first frame.
     */
    function showLateBar(width:Float):VisualTestContext {
        final h = new Harness(h -> {
            final root = div().w(px(h.width)).overflowHidden();
            if (h.shown) {
                root.child(new TabBar('late-tabs')
                    .underline()
                    .selectedIndex(0)
                    .child(new Tab().label('First'))
                    .child(new Tab().label('Second')));
            }
            return root;
        });
        h.width = width;
        final opened = openHarness(h);
        final cx = opened.cx;
        draw(cx);
        notify(opened.view, cx, view -> view.shown = true);
        draw(cx);
        return cx;
    }

    /** The underline indicators the frame drawn last painted. */
    static function paintedIndicators(cx:VisualTestContext):Array<Bounds> {
        return cx.update((window, app) -> {
            final primary = Theme.global(app).primary;
            final scaleFactor = window.scaleFactor();
            final result:Array<Bounds> = [];
            for (quad in window.renderedScene().quads) {
                if (quad.backgroundTag != 0) continue;
                if (quad.backgroundSolidH != primary.h || quad.backgroundSolidS != primary.s || quad.backgroundSolidL != primary.l || quad.backgroundSolidA != primary.a) continue;
                final b = new Bounds(new Point(quad.boundsX / scaleFactor, quad.boundsY / scaleFactor), new glaze.Size(quad.boundsWidth / scaleFactor, quad.boundsHeight / scaleFactor));
                if (b.size.height == 2.) result.push(b);
            }
            return result;
        });
    }

    /**
     * The frame after a bar's first, which measured its tabs, draws the
     * indicator under the selected tab, though nothing the view holding
     * the bar renders from changed. Then the bar asks for no more frames.
     */
    function testABarShownLaterDrawsItsIndicatorOnTheNextFrame() {
        final cx = showLateBar(300.);
        nextFrame(cx);
        final indicators = paintedIndicators(cx);
        assertEquals(1, indicators.length, '$indicators');
        assertTrue(indicators[0].size.width > 0., '$indicators');
        assertTrue(indicators[0].right() <= 150., '$indicators');
        assertEquals(0, cx.update((window, app) -> window.simulateNextFrame(app)));
    }

    /** A bar squeezed to no width asks for no frames to place its indicator. */
    function testABarWithNoWidthAsksForNoFrames() {
        final cx = showLateBar(0.);
        nextFrame(cx);
        assertEquals(0, cx.update((window, app) -> window.simulateNextFrame(app)));
    }

/// kit/tests/integration/controls.rs

    /**
     * The tab half of `checkbox_switch_and_tabs_report_controlled_state`:
     * `window.within("settings-tabs").find(ix).selected()` reads the
     * accessibility record of the tab rendered last, `click(ix)` lands in
     * its middle.
     */
    function testTabsReportControlledState() {
        final rendered:Array<Tab> = [];
        final h = new Harness(h -> {
            rendered.resize(0);
            final general = new ProbedTab('settings-tab-0').label('General');
            final advanced = new ProbedTab('settings-tab-1').label('Advanced');
            rendered.push(general);
            rendered.push(advanced);
            return div().sizeFull().flex().flexCol().gap4().child(new TabBar('settings-tabs')
                .selectedIndex(h.selectedIndex)
                .children([general, advanced])
                .onClick((index, _, cx) -> {
                    h.selectedIndex = index;
                    h.notifyView(cx);
                }));
        });
        h.selectedIndex = 0;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> h, 640, 600);
        contexts.push(opened.cx);
        final cx = opened.cx;
        draw(cx);
        final selected = (ix:Int) -> @:privateAccess rendered[ix].base.a11y.selected;
        assertEquals(true, selected(0));
        cx.simulateClick(bounds(cx, 'settings-tab-1').center());
        draw(cx);
        assertEquals(false, selected(0));
        assertEquals(true, selected(1));
    }

}

/**
 * The views of the harnesses: the state the Rust harnesses keep, and the
 * render function of the test.
 */
private class Harness extends Model implements Render {

    public var scrollHandle:Null<ScrollHandle> = null;

    public var menu:Bool = false;

    public var size:Size = Medium;

    public var tabs:Int = 0;

    public var selectedIndex:Int = 0;

    public var label:String = 'old';

    public var top:Float = 0.;

    public var occluded:Bool = false;

    public var shown:Bool = false;

    public var width:Float = 0.;

    final build:(Harness) -> IntoElement;

    public function new(build:(Harness) -> IntoElement) {
        super();
        this.build = build;
    }

    /** `cx.notify()` on this view from a callback without its context. */
    public function notifyView(cx:App):Void {
        cx.notify(entityId);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return build(this);
    }

}

/** A `Tab` whose rendered element records its bounds (Rust `debug_selector`). */
private class ProbedTab extends Tab {

    final selector:String;

    public function new(selector:String) {
        super();
        this.selector = selector;
    }

    override public function render(window:Window, cx:App):IntoElement {
        return new TabProbe(selector, super.render(window, cx));
    }

}

/**
 * Records the bounds of its child in prepaint, under a selector and per
 * window (Rust `debug_selector` / `debug_bounds`).
 */
private class TabProbe extends Element {

    static final recorded:Map<Int, Map<String, Bounds>> = new Map();

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public static function boundsOf(window:Window, selector:String):Null<Bounds> {
        final map = recorded.get(window.id);
        return map != null ? map.get(selector) : null;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        var map = recorded.get(window.id);
        if (map == null) {
            map = new Map();
            recorded.set(window.id, map);
        }
        map.set(selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

/** `probe(selector, element)`: `element.debug_selector(|| selector)`. */
private function probe(selector:String, element:IntoElement):IntoElement {
    return new TabProbe(selector, element);
}
