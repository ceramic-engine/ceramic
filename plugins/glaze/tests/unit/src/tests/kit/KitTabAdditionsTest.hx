// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.AnyView;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Modifiers;
import glaze.Point;
import glaze.Render;
import glaze.ScrollHandle;
import glaze.Window;
import glaze.kit.menu.PopupMenu.PopupMenuItem;
import glaze.kit.tab.Tab;
import glaze.kit.tab.TabAppearance;
import glaze.kit.tab.TabBar;
import glaze.kit.tab.TabBar.TabRevealMode;
import glaze.kit.tab.TabVariant;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeConfigColors;
import glaze.kit.theme.ThemeToken;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * The tab additions without upstream equivalent: KIT-001 (the caller's style
 * replayed last, the tab tokens, `TabVariant.Custom`, `labelMaxWidth`) and
 * KIT-002 (hover group, hover and drag move listeners, context menu,
 * `revealSelected`).
 */
class KitTabAdditionsTest extends KitAdditionsTestCase {

    static final LONG_LABEL = 'Account Settings & Preferences';

    static function color(h:Float):Hsla {
        return hsla(h, 0.75, 0.5, 1.);
    }

    /** A bar of two tabs, the first selected; `build` finishes each tab. */
    function bar(configure:(TabBar) -> TabBar, ?build:(Tab, Int) -> Tab):VisualTestContext {
        return open((_, _) -> {
            final bar = configure(TabBar.component('tabs').selectedIndex(0));
            for (ix in 0...2) {
                final tab = new ProbedAdditionTab('tab-$ix').label(ix == 0 ? 'First' : 'Second');
                bar.child(build != null ? build(tab, ix) : tab);
            }
            return probe('bar', div().w(px(400.)).child(bar));
        });
    }

/// KIT-039

    function testTheSelectedTabHasALineAlongItsTop() {
        final accent = color(0.9);
        // Nothing without the option
        assertEquals(0, quadsFilled(bar(b -> b), accent).length);
        // Given to both tabs: only the selected one draws it, over its whole width
        var cx = bar(b -> b, (tab, _) -> tab.topAccent(accent));
        var lines = quadsFilled(cx, accent);
        assertEquals(1, lines.length);
        final first = boundsOf(cx, 'tab-0');
        assertEquals(2., (lines[0].bounds.size.height : Float));
        // From one border of the tab to the other, right under its top border
        assertTrue(Math.abs((first.size.width : Float) - (lines[0].bounds.size.width : Float)) <= 2., '${lines[0].bounds}');
        assertTrue(Math.abs((first.origin.x : Float) - (lines[0].bounds.origin.x : Float)) <= 1.);
        assertTrue(Math.abs((first.origin.y : Float) - (lines[0].bounds.origin.y : Float)) <= 1.);
        // A width of its own, and the tab keeps its size
        cx = bar(b -> b, (tab, _) -> tab.topAccent(accent, 1.));
        lines = quadsFilled(cx, accent);
        assertEquals(1, lines.length);
        assertEquals(1., (lines[0].bounds.size.height : Float));
        assertTrue(near(first, boundsOf(cx, 'tab-0')));
        assertTrue(near(first, boundsOf(bar(b -> b), 'tab-0')));
    }

/// KIT-001

    function testDefaultTabGeometryAndFillsAreUnchanged() {
        final cx = bar(bar -> bar);
        final theme = cx.update((_, app) -> Theme.global(app));
        final first = boundsOf(cx, 'tab-0');
        final second = boundsOf(cx, 'tab-1');
        assertEquals(32., first.size.height);
        assertEquals(32., second.size.height);
        assertEquals(first.right(), second.left());
        // The selected tab is filled with the active token, the inactive tab
        // with nothing (the `tab.background` token is not read by `Tab`).
        assertEquals(1, quadsFilled(cx, theme.tabActive, first).length);
        for (entry in quads(cx)) {
            if (near(entry.bounds, second)) {
                assertEquals(0., entry.quad.backgroundSolidA, 'an inactive tab has no fill');
            }
        }
    }

    function testAnOpaqueTabTokenDoesNotReachTheStockVariants() {
        final plain = bar(bar -> bar);
        final before = sceneSignature(plain);
        app.update(cx -> Theme.update(cx, theme -> {
            theme.tokens.tab = ThemeToken.fromHsla(color(0.3));
            theme.tokens.tabHover = ThemeToken.fromHsla(color(0.6));
            theme.tokens.tabHoverForeground = ThemeToken.fromHsla(color(0.9));
        }));
        rerender(plain);
        assertEquals(before, sceneSignature(plain));
    }

    function testTheCallersStyleWinsOverTheVariant() {
        final red = color(0.);
        for (variant in [TabVariant.Tab, Outline, Pill, Segmented, Underline, Folder, Custom]) {
            final cx = bar(bar -> bar.withVariant(variant), (tab, ix) -> tab.h(px(41.)).bg(red).roundedTl(px(5.)));
            nextFrame(cx);
            for (ix in 0...2) {
                final tab = boundsOf(cx, 'tab-$ix');
                assertEquals(41., tab.size.height, '$variant tab $ix');
                // A bordered variant insets its fill by the border.
                final filled = [for (entry in quadsFilled(cx, red)) if (Math.abs(entry.bounds.center().x - tab.center().x) < 0.5 && Math.abs(entry.bounds.size.width - tab.size.width) <= 2.) entry];
                assertEquals(1, filled.length, '$variant tab $ix is filled by the caller');
                // Device pixels, less the border the fill is inset by.
                final corner = filled[0].quad.cornerRadiusTopLeft;
                assertTrue(corner == 10. || corner == 9., '$variant tab $ix has a top left corner of $corner');
            }
        }
    }

    function testACallersFlexShrinkDoesNotMakeATabShrink() {
        final cx = open((_, _) -> probe('bar', div().w(px(100.)).child(TabBar.component('tabs')
            .selectedIndex(0)
            .children([for (ix in 0...4) new ProbedAdditionTab('tab-$ix').w(px(60.)).flexShrink(1.).label('Tab $ix')]))));
        for (ix in 0...4) assertEquals(60., boundsOf(cx, 'tab-$ix').size.width);
    }

    function testTheHoverTokensFallBackToTodaysColors() {
        final theme = app.update(cx -> Theme.global(cx));
        assertTrue(theme.tabHover.equals(theme.tab));
        assertTrue(theme.tokens.tabHover.equals(theme.tokens.tab));
        assertTrue(theme.tabHoverForeground.equals(theme.tabActiveForeground));
    }

    function testTheHoverTokensAreReadFromAThemeFile() {
        final colors = ThemeConfigColors.fromJson({'tab.hover.background': '#ff0000', 'tab.hover.foreground': '#00ff00'});
        assertEquals('#ff0000', colors.tabHover);
        assertEquals('#00ff00', colors.tabHoverForeground);
        final json:haxe.DynamicAccess<Dynamic> = colors.toJson();
        assertEquals('#ff0000', json.get('tab.hover.background'));
        assertEquals('#00ff00', json.get('tab.hover.foreground'));
        // A theme that does not set them serializes without them.
        final empty:haxe.DynamicAccess<Dynamic> = new ThemeConfigColors().toJson();
        assertFalse(empty.exists('tab.hover.background'));
        assertFalse(empty.exists('tab.hover.foreground'));
    }

    function testCustomTabsKeepTheGeometryOfTheTabVariant() {
        final stock = bar(bar -> bar);
        final custom = bar(bar -> bar.custom());
        for (ix in 0...2) {
            assertTrue(boundsOf(stock, 'tab-$ix').equals(boundsOf(custom, 'tab-$ix')), 'tab $ix');
        }
    }

    function testCustomTabsAreFilledFromTheTabTokens() {
        final inactive = color(0.3);
        final hover = color(0.6);
        app.update(cx -> Theme.update(cx, theme -> {
            theme.tokens.tab = ThemeToken.fromHsla(inactive);
            theme.tokens.tabHover = ThemeToken.fromHsla(hover);
        }));
        final cx = bar(bar -> bar.custom());
        final theme = cx.update((_, app) -> Theme.global(app));
        final first = boundsOf(cx, 'tab-0');
        final second = boundsOf(cx, 'tab-1');
        assertEquals(1, quadsFilled(cx, theme.tabActive, first).length);
        assertEquals(1, quadsFilled(cx, inactive, second).length);

        cx.simulateMouseMove(second.center());
        draw(cx);
        assertEquals(0, quadsFilled(cx, inactive, second).length);
        assertEquals(1, quadsFilled(cx, hover, second).length);
        // The selected tab does not take the hover fill.
        cx.simulateMouseMove(first.center());
        draw(cx);
        assertEquals(1, quadsFilled(cx, theme.tabActive, first).length);
        assertEquals(1, quadsFilled(cx, inactive, second).length);
    }

    function testAppearanceShapesCustomTabs() {
        final appearance = new TabAppearance().topRadius(6.).height(28.).paddingX(20.).textSize(13.).sideBorders(false).bottomBorder(false).gap(3.);
        final stock = bar(bar -> bar.custom());
        final cx = bar(bar -> bar.custom(appearance));
        final theme = cx.update((_, app) -> Theme.global(app));
        final first = boundsOf(cx, 'tab-0');
        final second = boundsOf(cx, 'tab-1');
        assertEquals(28., first.size.height);
        assertEquals(3., second.left() - first.right());
        // 8 px more padding on each side, no side borders (one on the first
        // stock tab, which has no left border; two on the second).
        assertTrue(first.size.width > boundsOf(stock, 'tab-0').size.width);
        final selected = quadsFilled(cx, theme.tabActive, first);
        assertEquals(1, selected.length);
        assertEquals(12., selected[0].quad.cornerRadiusTopLeft);
        assertEquals(12., selected[0].quad.cornerRadiusTopRight);
        assertEquals(0., selected[0].quad.cornerRadiusBottomLeft);
        final sideBorders = (cx:VisualTestContext) -> [for (entry in quads(cx)) if (near(entry.bounds, boundsOf(cx, 'tab-0')) && entry.quad.borderWidthRight > 0.) entry].length;
        assertTrue(sideBorders(stock) > 0);
        assertEquals(0, sideBorders(cx));
        final stockSelected = quadsFilled(stock, theme.tabActive, boundsOf(stock, 'tab-0'));
        assertEquals(0., stockSelected[0].quad.cornerRadiusTopLeft);
        // The bar's bottom line: a quad as wide as the bar with a bottom border only.
        assertTrue(bottomLines(stock).length > 0);
        assertEquals(0, bottomLines(cx).length);
    }

    function bottomLines(cx:VisualTestContext):Array<Bounds> {
        final bar = boundsOf(cx, 'bar');
        return [for (entry in quads(cx)) if (entry.quad.borderWidthBottom > 0. && entry.quad.borderWidthTop == 0.
            && Math.abs(entry.bounds.size.width - bar.size.width) < 3.) entry.bounds];
    }

    function testATabsOwnAppearanceWinsOverTheBars() {
        final cx = bar(bar -> bar.custom(new TabAppearance().height(28.)), (tab, ix) -> ix == 1 ? tab.custom(new TabAppearance().height(24.)) : tab);
        assertEquals(28., boundsOf(cx, 'tab-0').size.height);
        assertEquals(24., boundsOf(cx, 'tab-1').size.height);
    }

    function testLabelMaxWidthCapsTheLabelAlone() {
        final width = (labelMaxWidth:Null<Float>, label:String, onTab:Bool) -> {
            final cx = open((_, _) -> {
                final bar = TabBar.component('tabs').selectedIndex(0);
                if (!onTab && labelMaxWidth != null) bar.labelMaxWidth(labelMaxWidth);
                final tab = new ProbedAdditionTab('tab').label(label).suffix(probe('suffix', div().size(px(16.))));
                if (onTab && labelMaxWidth != null) tab.labelMaxWidth(labelMaxWidth);
                return bar.child(tab);
            });
            return {tab: boundsOf(cx, 'tab').size.width, suffix: boundsOf(cx, 'suffix').size.width};
        };
        final short = width(null, 'Go', false);
        final long = width(null, LONG_LABEL, false);
        assertTrue(long.tab > 180., 'the label is long enough (${long.tab})');
        for (onTab in [false, true]) {
            // A label under the cap changes nothing.
            assertEquals(short.tab, width(120., 'Go', onTab).tab);
            final capped = width(120., LONG_LABEL, onTab);
            // The tab is the short tab with a 120 px label in place of "Go".
            assertEquals(16., capped.suffix);
            assertTrue(capped.tab > 120. + 16. && capped.tab < long.tab, 'capped tab is ${capped.tab}');
            final shortLabel = width(null, 'Go', onTab).tab;
            assertTrue(Math.abs((capped.tab - 120.) - (shortLabel - labelWidth('Go'))) < 0.01, 'only the label gives way: ${capped.tab}');
        }
    }

    /** Width of a label alone: the difference two labels make on a tab. */
    function labelWidth(label:String):Float {
        final measure = (label:Null<String>) -> {
            final cx = open((_, _) -> {
                final tab = new ProbedAdditionTab('tab').suffix(div().size(px(16.)));
                if (label != null) tab.label(label);
                return TabBar.component('tabs').selectedIndex(0).child(tab);
            });
            return boundsOf(cx, 'tab').size.width;
        };
        return measure(label) - measure('');
    }

/// KIT-011, KIT-012

    function testALastEmptySpaceSetByTheCallerIsAlwaysDrawn() {
        // The default one is drawn next to a suffix or the menu only
        final plain = bar(bar -> bar);
        final plainEnd = boundsOf(plain, 'tab-1').right();
        final own = bar(bar -> bar.lastEmptySpace(probe('space', div().w(px(30.)).h(px(10.)))));
        final space = boundsOf(own, 'space');
        assertNotNull(space);
        assertEquals(30., space.size.width);
        assertEquals(boundsOf(own, 'tab-1').right(), space.left());
        // The tabs did not move
        assertEquals(plainEnd, boundsOf(own, 'tab-1').right());
        // Next to a suffix it was already drawn, and still is
        final withSuffix = bar(bar -> bar.suffix(div().w(px(20.))).lastEmptySpace(probe('space', div().w(px(30.)).h(px(10.)))));
        assertEquals(30., boundsOf(withSuffix, 'space').size.width);
    }

    function testLabelStyleStylesTheLabelAlone() {
        final red = color(0.);
        final plain = bar(bar -> bar, (tab, _) -> tab.suffix(probe('suffix', div().size(px(16.)))));
        final styled = bar(bar -> bar, (tab, ix) -> tab.suffix(probe('suffix', div().size(px(16.)))).labelStyle(ix == 0 ? (s -> s.bg(red).lineThrough()) : null));
        // Same geometry
        assertTrue(boundsOf(plain, 'tab-0').equals(boundsOf(styled, 'tab-0')));
        assertTrue(boundsOf(plain, 'tab-1').equals(boundsOf(styled, 'tab-1')));
        // One red box, inside the first tab, that leaves the suffix out
        final boxes = quadsFilled(styled, red);
        assertEquals(1, boxes.length);
        final tab = boundsOf(styled, 'tab-0');
        final suffix = boundsOf(styled, 'suffix');
        assertTrue(boxes[0].bounds.left() >= tab.left() && boxes[0].bounds.right() <= tab.right());
        assertTrue(boxes[0].bounds.size.width < tab.size.width - 16.);
        assertEquals(0, quadsFilled(plain, red).length);
        // With a capped label, the style is on the capped box
        final capped = bar(bar -> bar.labelMaxWidth(px(20.)), (tab, _) -> tab.label(LONG_LABEL).labelStyle(s -> s.bg(red)));
        final cappedBoxes = quadsFilled(capped, red);
        assertEquals(2, cappedBoxes.length);
        assertEquals(20., cappedBoxes[0].bounds.size.width);
    }

/// KIT-002

    function testAHoverGroupStylesTheSuffix() {
        final red = color(0.);
        final cx = bar(bar -> bar, (tab, ix) -> tab
            .group('tab-group-$ix')
            .suffix(probe('close-$ix', div().size(px(10.)).groupHover('tab-group-$ix', s -> s.bg(red)))));
        final close = boundsOf(cx, 'close-1');
        assertEquals(0, quadsFilled(cx, red).length);
        cx.simulateMouseMove(boundsOf(cx, 'tab-1').origin.add(point(px(3.), px(3.))));
        draw(cx);
        final filled = quadsFilled(cx, red);
        assertEquals(1, filled.length);
        assertTrue(near(filled[0].bounds, close));
    }

    function testOnHoverReportsEnterAndLeave() {
        final events:Array<String> = [];
        final cx = bar(bar -> bar, (tab, ix) -> tab.onHover((hovered, _, _) -> events.push('$ix:$hovered')));
        cx.simulateMouseMove(boundsOf(cx, 'tab-1').center());
        draw(cx);
        cx.simulateMouseMove(boundsOf(cx, 'tab-0').center());
        draw(cx);
        cx.simulateMouseMove(point(px(700.), px(500.)));
        draw(cx);
        assertEquals('1:true,1:false,0:true,0:false', events.join(','));
    }

    function testAHoverStyleOfTheCallerIsAppliedAfterTheVariants() {
        final red = color(0.);
        final cx = bar(bar -> bar, (tab, ix) -> tab.hover(s -> s.bg(red)));
        final second = boundsOf(cx, 'tab-1');
        assertEquals(0, quadsFilled(cx, red).length);
        cx.simulateMouseMove(second.center());
        draw(cx);
        assertEquals(1, quadsFilled(cx, red, second).length);
    }

    function testOnDragMoveReportsTheTabUnderADrag() {
        final moves:Array<{ix:Int, bounds:Bounds, position:Point, value:Int}> = [];
        final cx = bar(bar -> bar, (tab, ix) -> tab
            .onDrag(new TabDragValue(ix), (_, _, _, cx) -> (cx.newEntity((_:Context<TabDragPreview>) -> new TabDragPreview()) : AnyView))
            .onDragMove(TabDragValue, (event, _, cx) -> moves.push({ix: ix, bounds: event.bounds, position: event.event.position, value: event.drag(cx).ix})));
        final first = boundsOf(cx, 'tab-0');
        final second = boundsOf(cx, 'tab-1');
        cx.simulateMouseDown(first.center(), Left);
        cx.simulateMouseMove(first.center().add(point(px(8.), px(0.))), Left);
        draw(cx);
        moves.resize(0);
        final target = point(second.left() + second.size.width * 0.75, second.center().y);
        cx.simulateMouseMove(target, Left);
        draw(cx);
        // Every tab listening hears the move, with its own bounds: the one
        // holding the pointer knows which half it is on.
        assertEquals(2, moves.length);
        for (move in moves) {
            assertEquals(0, move.value);
            assertTrue(move.bounds.equals(move.ix == 0 ? first : second), 'tab ${move.ix}');
            assertEquals(move.ix == 1, move.bounds.contains(move.position));
        }
        assertTrue(target.x > second.center().x);
        cx.simulateEvent(new MouseUpEvent(Left, target, Modifiers.none(), 1));
    }

    function testAContextMenuOpensOnATabOfABar() {
        final built:Array<Int> = [];
        final chosen:Array<Int> = [];
        final build = (withMenu:Bool) -> open((_, _) -> {
            final bar = TabBar.component('tabs').selectedIndex(0);
            for (ix in 0...2) {
                final tab = new ProbedAdditionTab('tab-$ix').label(ix == 0 ? 'First' : 'Second');
                if (withMenu) tab.contextMenu((menu, _, _) -> {
                    built.push(ix);
                    return menu.item(PopupMenuItem.create('Close').onClick((_, _, _) -> chosen.push(ix)));
                });
                bar.child(tab);
            }
            return div().sizeFull().child(bar);
        }, 800, 600, true);
        final plain = build(false);
        final cx = build(true);
        // The menu does not change the layout of the tabs.
        for (ix in 0...2) assertTrue(boundsOf(plain, 'tab-$ix').equals(boundsOf(cx, 'tab-$ix')), 'tab $ix');

        final second = boundsOf(cx, 'tab-1');
        cx.simulateMouseDown(second.center(), Right);
        cx.simulateEvent(new MouseUpEvent(Right, second.center(), Modifiers.none(), 1));
        draw(cx);
        draw(cx);
        assertEquals('1', built.join(','));
        cx.simulateKeystrokes('down enter');
        draw(cx);
        assertEquals('1', chosen.join(','));

        // Each tab keeps its own menu state.
        final first = boundsOf(cx, 'tab-0');
        cx.simulateMouseDown(first.center(), Right);
        cx.simulateEvent(new MouseUpEvent(Right, first.center(), Modifiers.none(), 1));
        draw(cx);
        draw(cx);
        assertEquals('1,0', built.join(','));
    }

    function revealHarness(revealSelected:Bool, selected:Array<Int>, handle:ScrollHandle, tabs:Array<Int>):VisualTestContext {
        app.update(cx -> cx.setReduceMotion(true));
        return open((_, _) -> probe('bar', div().w(px(100.)).child(TabBar.component('reveal-tabs')
            .wFull()
            .trackScroll(handle)
            .revealSelected(revealSelected)
            .selectedIndex(selected[0])
            .children([for (ix in 0...tabs[0]) new ProbedAdditionTab('tab-$ix').w(px(60.)).label('Tab $ix')]))));
    }

    function testRevealSelectedFollowsASelectionChangedByCode() {
        final selected = [0];
        final tabs = [5];
        final handle = new ScrollHandle();
        final cx = revealHarness(true, selected, handle, tabs);
        for (_ in 0...3) nextFrame(cx);
        assertEquals(0., handle.offset().x);

        selected[0] = 3;
        rerender(cx);
        for (_ in 0...3) nextFrame(cx);
        final bar = boundsOf(cx, 'bar');
        final tab = boundsOf(cx, 'tab-3');
        assertTrue(tab.left() >= bar.left() && tab.right() <= bar.right(), 'tab 3 at ${tab.left()}..${tab.right()}');

        // A tab added and selected in the same render is revealed too.
        tabs[0] = 6;
        selected[0] = 5;
        rerender(cx);
        for (_ in 0...3) nextFrame(cx);
        assertEquals(-handle.maxOffset().x, handle.offset().x);

        // Then the bar asks for no more frames, and a manual scroll stays.
        assertEquals(0, cx.update((window, app) -> window.simulateNextFrame(app)));
        handle.setOffset(point(px(-10.), px(0.)));
        rerender(cx);
        for (_ in 0...3) nextFrame(cx);
        assertEquals(-10., handle.offset().x);
    }

    function testRevealSelectedShowsTheSelectionOfTheFirstFrame() {
        final handle = new ScrollHandle();
        final cx = revealHarness(true, [4], handle, [5]);
        for (_ in 0...3) nextFrame(cx);
        assertEquals(-handle.maxOffset().x, handle.offset().x);
    }

    function testWithoutRevealSelectedASelectionChangedByCodeDoesNotScroll() {
        final selected = [0];
        final handle = new ScrollHandle();
        final cx = revealHarness(false, selected, handle, [5]);
        selected[0] = 4;
        rerender(cx);
        for (_ in 0...3) nextFrame(cx);
        assertEquals(0., handle.offset().x);
    }

/// KIT-033

    /** Five tabs of 60 px in a 200 px bar, then 30 px of `lastEmptySpace`. */
    function nearestHarness(mode:Null<TabRevealMode>, selected:Array<Int>, handle:ScrollHandle):VisualTestContext {
        app.update(cx -> cx.setReduceMotion(true));
        return open((_, _) -> {
            final bar = TabBar.component('nearest-tabs')
                .wFull()
                .trackScroll(handle)
                .revealSelected(true)
                .selectedIndex(selected[0])
                .lastEmptySpace(div().flexShrink0().w(px(30.)).h(px(10.)))
                .onClick((_, _, _) -> {})
                .children([for (ix in 0...5) new ProbedAdditionTab('tab-$ix').w(px(60.)).label('Tab $ix')]);
            if (mode != null) bar.revealMode(mode);
            return probe('bar', div().w(px(200.)).child(bar));
        });
    }

    function select(cx:VisualTestContext, selected:Array<Int>, ix:Int):Void {
        selected[0] = ix;
        rerender(cx);
        for (_ in 0...3) nextFrame(cx);
    }

    function testRevealModePeekIsTheDefault() {
        final selected = [0];
        final handle = new ScrollHandle();
        final cx = nearestHarness(null, selected, handle);
        for (_ in 0...3) nextFrame(cx);
        select(cx, selected, 4);
        // The last tab shows the end of the strip, its empty space included.
        assertEquals(-handle.maxOffset().x, handle.offset().x);
        final explicitHandle = new ScrollHandle();
        final explicitSelected = [0];
        final explicit = nearestHarness(Peek, explicitSelected, explicitHandle);
        for (_ in 0...3) nextFrame(explicit);
        select(explicit, explicitSelected, 4);
        assertEquals(handle.offset().x, explicitHandle.offset().x);
    }

    function testRevealModeNearestScrollsOnlyWhenTheTabIsCut() {
        final selected = [0];
        final handle = new ScrollHandle();
        final cx = nearestHarness(Nearest, selected, handle);
        for (_ in 0...3) nextFrame(cx);
        assertEquals(0., handle.offset().x);
        final viewport = handle.bounds();

        // The last tab: its right edge at the end of the view, the empty
        // space after it left out.
        select(cx, selected, 4);
        final offset = handle.offset().x;
        assertTrue(offset > -handle.maxOffset().x, 'offset $offset, max ${handle.maxOffset().x}');
        assertEquals(viewport.right(), boundsOf(cx, 'tab-4').right());

        // A tab already in view: nothing moves.
        select(cx, selected, 3);
        assertEquals(offset, handle.offset().x);

        // The first tab, cut on the left: its left edge at the start of the view.
        select(cx, selected, 0);
        assertEquals(viewport.left(), boundsOf(cx, 'tab-0').left());

        // A click on a cut tab shows it whole, without its neighbour.
        final before = boundsOf(cx, 'tab-3');
        assertTrue(before.right() > viewport.right());
        cx.simulateClick(new Point(viewport.right() - 5., before.center().y));
        for (_ in 0...3) nextFrame(cx);
        assertEquals(viewport.right(), boundsOf(cx, 'tab-3').right());
    }

}

private class TabDragValue {

    public final ix:Int;

    public function new(ix:Int) {
        this.ix = ix;
    }

}

private class TabDragPreview extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(10.));
    }

}

/** A `Tab` whose rendered element records its bounds. */
private class ProbedAdditionTab extends Tab {

    final selector:String;

    public function new(selector:String) {
        super();
        this.selector = selector;
    }

    override public function render(window:Window, cx:App):IntoElement {
        return new KitAdditionsTestCase.AdditionsProbe(selector, super.render(window, cx));
    }

}
