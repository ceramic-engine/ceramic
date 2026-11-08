// Ported from gpui-kit 0.8.1: crates/component/src/setting/tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.Window.StateModel;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.groupbox.GroupBox.GroupBoxVariant;
import glaze.kit.setting.SettingGroup;
import glaze.kit.setting.SettingItem;
import glaze.kit.setting.SettingPage;
import glaze.kit.setting.Settings;
import glaze.kit.theme.Theme;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `setting` module. Element
 * bounds are read through `DebugProbe` (Rust `debug_selector`).
 *
 * Not ported: the two integration tests of `crates/kit/tests/integration/
 * controls.rs` that look setting controls up by accessible name
 * (`bool_settings_are_named_after_their_titles`,
 * `value_settings_are_named_after_their_titles`): the port has no
 * accessibility tree to query. The names they check are the
 * `accessibilityLabel` / `ariaLabel` each field renderer passes (see
 * `testFieldControlsAreNamedAfterTheirTitles`).
 */
class ComponentSettingTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> {
            Theme.globalMut(cx).fontSize = 16.;
        });
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    static function item(keyword:String):SettingItem {
        return itemWithHeight(keyword, 80.);
    }

    static function itemWithHeight(keyword:String, height:Float):SettingItem {
        return SettingItem.render((options, _, _) -> {
            final selector = 'setting-${options.pageIx()}-${options.groupIx()}-${options.itemIx()}';
            return new DebugProbe(selector, div().h(px(height)).child('Setting'));
        }).keywords([keyword]);
    }

    function setupHost():{host:Entity<SettingsHost>, cx:VisualTestContext} {
        final pages = [
            new SettingPage('General').group(new SettingGroup().item(item('language'))),
            new SettingPage('Appearance').defaultOpen(true).groups([
                new SettingGroup().item(item('unrelated')),
                new SettingGroup()
                    .title('Colors')
                    .item(item('theme colors')),
                new SettingGroup()
                    .title('Fonts')
                    .items([item('unrelated'), item('theme font')]),
            ]),
            new SettingPage('Editor').group(new SettingGroup().item(item('theme editor'))),
        ];
        var host:Null<Entity<SettingsHost>> = null;
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
            final view = rootCx.newEntity((_:Context<SettingsHost>) -> new SettingsHost(pages));
            host = view;
            return view;
        }, 1000, 700);
        contexts.push(opened.cx);
        draw(opened.cx);
        return {host: host, cx: opened.cx};
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        DebugProbe.clear();
        cx.update((window, _) -> window.draw());
    }

    static function search(host:Entity<SettingsHost>, query:String, cx:VisualTestContext):Void {
        cx.update((window, cx) -> {
            final input = host.read(cx).state.read(cx).value.searchInput;
            input.update(cx, (input, cx) -> input.setValue(query, window, cast cx));
        });
        draw(cx);
    }

    static function selection(host:Entity<SettingsHost>, cx:VisualTestContext):String {
        return cx.update((_, cx) -> {
            final selected = host.read(cx).state.read(cx).value.selectedIndex;
            return '${selected.pageIx},${selected.groupIx}';
        });
    }

    static function clickNav(y:Float, cx:VisualTestContext):Void {
        // Fixed-size fixture with a 16px rem; click the label area, away from carets.
        cx.simulateClick(new Point(50., y));
        draw(cx);
    }

    /**
     * Rust reads `debug_bounds("settings-no-results")`, the `debug_selector`
     * of the no results placeholder, which the port does not record inside
     * the component: the placeholder is rendered exactly when no page has a
     * matching group.
     */
    static function noResults(host:Entity<SettingsHost>, cx:VisualTestContext):Bool {
        return cx.update((_, cx) -> {
            final query = host.read(cx).state.read(cx).value.searchInput.read(cx).value();
            final filter = @:privateAccess new glaze.kit.setting.Settings.SettingsFilter(host.read(cx).pages, query, cx);
            return filter.visiblePages().length == 0;
        });
    }

    static inline function b(selector:String):Null<Bounds> {
        return DebugProbe.bounds(selector);
    }

    function testSearchPreservesThePageAndClicksUseOriginalIndices() {
        final opened = setupHost();
        final host = opened.host;
        final cx = opened.cx;
        // The old numeric index is still in range, but would point to Editor.
        search(host, 'theme', cx);
        assertEquals('1,null', selection(host, cx));
        assertTrue(b('setting-1-1-0') != null);
        assertTrue(b('setting-2-0-0') == null);

        // Only Appearance matches; the old implementation renders a blank page.
        search(host, 'font', cx);
        assertEquals('1,null', selection(host, cx));
        assertTrue(b('setting-1-2-1') != null);

        // Select Editor from the compressed result list, then clear the query.
        search(host, 'theme', cx);
        clickNav(156., cx);
        assertEquals('2,null', selection(host, cx));
        search(host, '', cx);
        assertEquals('2,null', selection(host, cx));
        assertTrue(b('setting-2-0-0') != null);

        // The current page disappears: choose the first matching page.
        search(host, 'font', cx);
        assertEquals('1,null', selection(host, cx));
        assertTrue(b('setting-1-2-1') != null);
        search(host, 'no matching setting', cx);
        assertEquals('1,null', selection(host, cx));
        assertTrue(b('setting-1-2-1') == null);
        assertTrue(noResults(host, cx));
        search(host, '', cx);
        assertEquals('1,null', selection(host, cx));
        assertFalse(noResults(host, cx));
    }

    function testScrollingMarksTheGroupAtTheTop() {
        final opened = setupHost();
        final host = opened.host;
        final cx = opened.cx;
        cx.update((_, cx) -> {
            host.update(cx, (host, cx) -> {
                host.pages[1].groupsValue[1].itemsValue = [itemWithHeight('theme colors', 900.)];
                cx.notify();
            });
        });
        draw(cx);
        assertEquals('1,null', selection(host, cx));

        function scroll(delta:Float) {
            cx.simulateEvent(new ScrollEvent(new Point(600., 400.), ScrollDelta.Pixels(new Point(0., delta))));
            draw(cx);
        }
        // Past the untitled first group, Colors reaches the top.
        scroll(-200.);
        assertEquals('1,1', selection(host, cx));
        // At the end of the list, the last group is marked.
        scroll(-2000.);
        assertEquals('1,2', selection(host, cx));
        // Back at the top, the untitled group marks the page itself.
        scroll(4000.);
        assertEquals('1,null', selection(host, cx));
    }

    function testSearchPreservesGroupAndItemIdentity() {
        final opened = setupHost();
        final host = opened.host;
        final cx = opened.cx;
        // Make the target group require scrolling, with an unnamed group before it.
        cx.update((_, cx) -> {
            host.update(cx, (host, cx) -> {
                host.pages[1].groupsValue[1].itemsValue = [itemWithHeight('theme colors', 450.)];
                cx.notify();
            });
        });
        draw(cx);
        clickNav(156., cx);
        assertEquals('1,2', selection(host, cx));
        search(host, 'theme', cx);
        assertEquals('1,2', selection(host, cx));
        assertTrue(b('setting-1-2-1') != null);
        assertTrue(b('setting-1-2-0') == null);
        // Click Fonts after the leading page/group/item have been filtered out.
        clickNav(120., cx);
        assertEquals('1,2', selection(host, cx));
        final target = b('setting-1-2-1');
        assertTrue(target.top() >= 0. && target.bottom() <= 700.);
        search(host, 'font', cx);
        assertEquals('1,2', selection(host, cx));
        search(host, '', cx);
        assertEquals('1,2', selection(host, cx));
        search(host, 'colors', cx);
        assertEquals('1,null', selection(host, cx));
        assertTrue(b('setting-1-1-0') != null);
    }

    function testFooterFollowsGroupSearchVisibility() {
        final opened = setupHost();
        final host = opened.host;
        final cx = opened.cx;
        cx.update((_, cx) -> {
            host.update(cx, (host, cx) -> {
                host.pages[1].groupsValue[2] = host.pages[1].groupsValue[2].clone().footer((_, _) -> {
                    new DebugProbe('font-footer', div().child('Changes apply to this device only.'));
                });
                cx.notify();
            });
        });
        search(host, 'font', cx);
        assertTrue(b('setting-1-2-1') != null);
        assertTrue(b('font-footer') != null);

        // Footer copy does not independently make a group match the query.
        search(host, 'colors', cx);
        assertTrue(b('setting-1-1-0') != null);
        assertTrue(b('font-footer') == null);

        search(host, 'font', cx);
        assertTrue(b('font-footer') != null);
        assertEquals('1,null', selection(host, cx));
    }

    function testResettingSearchResultsLeavesHiddenSettingsUnchanged() {
        final opened = setupHost();
        final cx = opened.cx;
        var visible = false;
        var hidden = true;
        final group = new SettingGroup().items([
            item('theme').onReset(_ -> visible, (_, _) -> visible = false),
            item('hidden').onReset(_ -> hidden, (_, _) -> hidden = false),
        ]);
        cx.update((window, cx) -> {
            assertFalse(group.isResettable('theme', cx));
            visible = true;
            assertTrue(group.isResettable('theme', cx));
            group.reset('theme', window, cx);
        });
        assertFalse(visible);
        assertTrue(hidden);
    }

    static function variantPages(overrideFirstGroup:Bool):Array<SettingPage> {
        final first = overrideFirstGroup ? new SettingGroup().variant(GroupBoxVariant.Normal) : new SettingGroup();
        return [new SettingPage('General').groups([
            first.item(item('plain')),
            new SettingGroup().item(item('outlined')),
        ])];
    }

    function testGroupVariantOverridesTheSettingsDefault() {
        function openWindow(pages:Array<SettingPage>, outline:Bool):{first:Bounds, second:Bounds} {
            final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
                final view = rootCx.newEntity((_:Context<VariantHost>) -> new VariantHost(pages, outline));
                return view;
            }, 1000, 700);
            contexts.push(opened.cx);
            draw(opened.cx);
            return {first: b('setting-0-0-0'), second: b('setting-0-1-0')};
        }

        // Baseline: no global variant, so both groups present their items directly.
        final baseline = openWindow(variantPages(false), false);
        // A global Outline default with the first group overriding back to Normal.
        final overridden = openWindow(variantPages(true), true);

        // The override presents the group exactly like the settings-level default.
        assertEquals(0., overridden.first.top() - baseline.first.top());
        // A group without the override keeps the global Outline chrome:
        // a 1px border and 16px padding above its items.
        assertEquals(17., overridden.second.top() - baseline.second.top());
    }

    function testSelectingAGroupFromAnotherPageScrollsToIt() {
        final opened = setupHost();
        final host = opened.host;
        final cx = opened.cx;
        // Push Fonts below the viewport.
        cx.update((_, cx) -> {
            host.update(cx, (host, cx) -> {
                host.pages[1].groupsValue[1].itemsValue = [itemWithHeight('theme colors', 900.)];
                cx.notify();
            });
        });
        draw(cx);
        function select(pageIx:Int, groupIx:Null<Int>) {
            cx.update((_, cx) -> {
                final state = host.read(cx).state;
                state.update(cx, (state, cx) -> {
                    state.value.selectedIndex = new glaze.kit.setting.Settings.SelectIndex(pageIx, groupIx);
                    state.value.deferredScrollGroupIx = groupIx;
                    cx.notify();
                });
            });
            draw(cx);
        }

        // Leaving the page drops its list state; the jump back must not land at the top.
        select(0, null);
        select(1, 2);
        final target = b('setting-1-2-1');
        assertTrue(target.top() >= 0. && target.bottom() <= 700.);
    }

}

private class SettingsHost extends Model implements Render {

    public var pages:Array<SettingPage>;

    public var state:Null<Entity<StateModel<glaze.kit.setting.Settings.SettingsState>>> = null;

    public function new(pages:Array<SettingPage>) {
        super();
        this.pages = pages;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final settings = Settings.component('search-test')
            .pages([for (page in pages) page.clone()])
            .defaultSelectedIndex(new glaze.kit.setting.Settings.SelectIndex(1, null))
            .render(window, cx.app)
            .intoAnyElement();
        state = @:privateAccess Settings.keyedState(window, 'search-test', cx.app);
        return div().sizeFull().child(settings);
    }

}

private class VariantHost extends Model implements Render {

    final pages:Array<SettingPage>;

    final outline:Bool;

    public function new(pages:Array<SettingPage>, outline:Bool) {
        super();
        this.pages = pages;
        this.outline = outline;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var settings = Settings.component('variant-test').pages([for (page in pages) page.clone()]);
        if (outline) {
            settings = settings.withGroupVariant(GroupBoxVariant.Outline);
        }
        return div()
            .sizeFull()
            .child(settings.render(window, cx.app).intoAnyElement());
    }

}
