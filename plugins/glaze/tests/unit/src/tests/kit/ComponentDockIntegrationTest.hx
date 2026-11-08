// Ported from gpui-kit 0.8.1: crates/kit/tests/integration/dock.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.dock.DockArea;
import glaze.kit.base.dock.DockLayout;
import glaze.kit.base.dock.DockPlacement;
import glaze.kit.base.dock.PanelId;
import glaze.kit.base.input.InputState;
import glaze.kit.dock.DockDebugBounds;
import glaze.kit.dock.DockSkin;
import glaze.kit.dock.PanelBase;
import glaze.kit.dock.PanelControl;
import glaze.kit.dock.PanelHandle;
import glaze.kit.dock.PanelStyle;
import glaze.kit.dock.TabGroupSkin;
import glaze.kit.input.Input;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * gpui-kit's dock integration tests (`crates/kit/tests/integration/dock.rs`),
 * all of which draw through `DockSkin`.
 *
 * gpui-kit's UI query layer (`window.find`, `within`, `click`, `drag_to`,
 * `wait_for`) is not ported. Its queries are answered from the skin's debug
 * selectors (`DockDebugBounds`, every view drawn on every frame) and from the
 * documents' own: a document records its bounds as `panel-<name>` and its
 * input's as `editor-<name>`. `within(group)` is the group whose tab bar sits
 * above the named panel, `click` lands in the middle of the element after a
 * pointer move, and `drag` moves in eight steps like gpui-kit's helper.
 */
@:access(glaze.kit.dock.TabGroupSkin)
@:access(glaze.kit.dock.DockDebugBounds)
class ComponentDockIntegrationTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        DockDebugBounds.enabled = true;
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DockDebugBounds.enabled = false;
        DockDebugBounds.clear();
        ceramic.App.app.flushImmediate();
    }

    function openWindow<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build, 900, 600);
        opened.cx.window.viewCachingDisabled = true;
        contexts.push(opened.cx);
        return opened;
    }

/// The query layer

    static function renderFrame(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    static function find(cx:VisualTestContext, name:String):Null<Bounds> {
        return DockDebugBounds.bounds(cx.window, 'panel-$name');
    }

    static function visible(cx:VisualTestContext, name:String):Bool {
        final bounds = find(cx, name);
        return bounds != null && bounds.size.width > 0 && bounds.size.height > 0;
    }

    /**
     * The tab bar drawn above `name`'s panel: the selector's bounds that
     * share the panel's columns and end above it.
     */
    static function inGroupOf(cx:VisualTestContext, name:String, selector:String):Null<Bounds> {
        final panel = find(cx, name);
        if (panel == null) return null;
        for (bounds in DockDebugBounds.all(cx.window, selector)) {
            final x = bounds.center().x;
            if (x >= panel.left() && x <= panel.right() && bounds.top() <= panel.top()) return bounds;
        }
        return null;
    }

    static function tab(cx:VisualTestContext, ix:Int):Null<Bounds> {
        return DockDebugBounds.bounds(cx.window, '${TabGroupSkin.TAB_SELECTOR}-$ix');
    }

    static function clickAt(cx:VisualTestContext, position:Point):Void {
        renderFrame(cx);
        cx.simulateMouseMove(position);
        cx.simulateEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1));
    }

    /** gpui-kit's `Window::drag`: down, eight interpolated moves, up. */
    static function drag(cx:VisualTestContext, from:Point, to:Point):Void {
        renderFrame(cx);
        cx.simulateMouseMove(from);
        cx.simulateMouseDown(from, Left);
        for (step in 1...9) {
            final fraction = step / 8;
            cx.simulateMouseMove(new Point(from.x + (to.x - from.x) * fraction, from.y + (to.y - from.y) * fraction), Left);
        }
        cx.simulateMouseUp(to, Left);
    }

    /** `TestAppContextExt::wait_for`: a frame every 10 ms of test time. */
    function waitFor(cx:VisualTestContext, predicate:() -> Bool, label:String):Void {
        var elapsed = 0.;
        while (true) {
            cx.runUntilParked();
            renderFrame(cx);
            if (predicate()) return;
            if (elapsed >= 1.) {
                fail('UI condition timed out after 1s: $label');
                return;
            }
            cx.advanceClock(0.010);
            elapsed += 0.010;
        }
    }

    function editorFocused(cx:VisualTestContext, document:Entity<Document>):Bool {
        return cx.update((window, cx) -> document.read(cx).input.read(cx).focusHandle.isFocused(window));
    }

    static function focused(cx:VisualTestContext, document:Entity<Document>):Bool {
        return cx.update((window, cx) -> document.read(cx).focus.isFocused(window));
    }

    /** `window.within(name).click("editor")`. */
    static function clickEditor(cx:VisualTestContext, name:String):Void {
        renderFrame(cx);
        clickAt(cx, DockDebugBounds.bounds(cx.window, 'editor-$name').center());
    }

    /** The `close_visible_tab` helper: the close button of tab `ix` in the group of `name`. */
    static function closeVisibleTab(cx:VisualTestContext, name:String, ix:Int):Void {
        renderFrame(cx);
        final tab = inGroupOf(cx, name, '${TabGroupSkin.TAB_SELECTOR}-$ix');
        var button:Null<Bounds> = null;
        for (bounds in DockDebugBounds.all(cx.window, TabGroupSkin.CLOSE_BUTTON_SELECTOR)) {
            if (tab != null && bounds.center().x >= tab.left() && bounds.center().x <= tab.right()) button = bounds;
        }
        clickAt(cx, button.center());
    }

/// Tests

    function testDockSwitchesAndReordersRealTabs() {
        final opened = openWindow((window, cx:Context<DockEditor>) -> {
            final created = DockSkin.dockArea('editor', null, window, cx.app);
            created.skin.setPanelStyle(PanelStyle.TabBar, cx.app);
            final a = Document.create('alpha', window, cx.app);
            final b = Document.create('beta', window, cx.app);
            final layout = DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(a), cx.app)
                .panelView(PanelHandle.panelHandle(b), cx.app);
            created.area.update(cx.app, (area, acx) -> area.setCenter(layout, window, acx));
            new DockEditor(created.area);
        });
        final cx = opened.cx;
        final area = opened.view.read(app).area;
        renderFrame(cx);
        assertTrue(visible(cx, 'alpha'));
        clickAt(cx, tab(cx, 1).center());
        renderFrame(cx);
        assertTrue(visible(cx, 'beta'));
        assertTrue(find(cx, 'alpha') == null);
        drag(cx, tab(cx, 1).center(), tab(cx, 0).center());

        waitFor(cx, () -> {
            // `within("tab-bar").find(0).selected()`: the group's first tab
            // is the displayed one (the centre's root split holds the group).
            final tabs = cx.update((_, cx) -> switch area.read(cx).layout(DockPlacement.Center).root().kind() {
                case Split(_, children, _): switch children[0].kind() {
                    case Tabs(_, activeIx): activeIx;
                    case _: -1;
                }
                case _: -1;
            });
            tabs == 0 && find(cx, 'beta') != null;
        }, 'the first tab is selected and beta is shown');

        clickAt(cx, tab(cx, 1).center());
        renderFrame(cx);
        assertTrue(visible(cx, 'alpha'), 'dragging beta to slot zero must move alpha to slot one');
        assertTrue(find(cx, 'beta') == null);
    }

    function testDockMovesATabBetweenGroupsAndZoomsTheResult() {
        final opened = openWindow((window, cx:Context<DockEditor>) -> {
            final created = DockSkin.dockArea('editor', null, window, cx.app);
            final a = Document.create('alpha', window, cx.app);
            final b = Document.create('beta', window, cx.app);
            final c = Document.create('gamma', window, cx.app);
            final layout = DockLayout.hSplit()
                .child(DockLayout.tabs()
                    .panelView(PanelHandle.panelHandle(a), cx.app)
                    .panelView(PanelHandle.panelHandle(b), cx.app), null)
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(c), cx.app), null);
            created.area.update(cx.app, (area, acx) -> area.setCenter(layout, window, acx));
            new DockEditor(created.area);
        });
        final cx = opened.cx;
        renderFrame(cx);
        final right = find(cx, 'gamma');
        assertTrue(find(cx, 'alpha').right() <= right.left());
        final from = inGroupOf(cx, 'alpha', '${TabGroupSkin.TAB_SELECTOR}-1').center();
        drag(cx, from, right.center());

        waitFor(cx, () -> {
            final beta = find(cx, 'beta');
            beta != null && beta.left() >= right.left();
        }, 'beta moved into the right group');

        assertTrue(visible(cx, 'alpha'));
        assertTrue(find(cx, 'gamma') == null);
        // The zoom-in button of beta's group.
        clickAt(cx, inGroupOf(cx, 'beta', TabGroupSkin.ZOOM_CONTROL_SELECTOR).center());

        waitFor(cx, () -> find(cx, 'beta').size.width > right.size.width, 'beta is zoomed');

        assertTrue(find(cx, 'alpha') == null);
        clickAt(cx, DockDebugBounds.bounds(cx.window, TabGroupSkin.ZOOM_CONTROL_SELECTOR).center());

        waitFor(cx, () -> find(cx, 'alpha') != null && find(cx, 'beta').size.width <= right.size.width, 'zoomed out');
    }

    function twoTabs():{view:Entity<TwoTabs>, cx:VisualTestContext} {
        return openWindow((window, cx:Context<TwoTabs>) -> {
            final created = DockSkin.dockArea('editor', null, window, cx.app);
            created.skin.setPanelStyle(PanelStyle.TabBar, cx.app);
            created.skin.setCloseButtonVisible(true, cx.app);
            final alpha = Document.create('alpha', window, cx.app);
            final beta = Document.create('beta', window, cx.app);
            final layout = DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(alpha), cx.app)
                .panelView(PanelHandle.panelHandle(beta), cx.app);
            created.area.update(cx.app, (area, acx) -> area.setCenter(layout, window, acx));
            new TwoTabs(created.area, alpha, beta, cx.focusHandle());
        });
    }

    function testDockHandsTheFocusToTheTabThatReplacesAClosedOne() {
        final t = twoTabs();
        final cx = t.cx;
        final view = t.view.read(app);
        renderFrame(cx);
        cx.update((window, cx) -> view.alpha.read(cx).focus.focus(window, cx));
        renderFrame(cx);
        assertTrue(focused(cx, view.alpha));

        cx.update((window, cx) -> view.area.update(cx, (area, acx) -> area.removePanel(view.alpha, window, acx)));
        renderFrame(cx);
        assertTrue(visible(cx, 'beta'));
        assertTrue(focused(cx, view.beta), 'closing the focused tab must leave the keyboard on the one shown in its place');
    }

    function testDockLeavesTheFocusAloneWhenATabWithoutItCloses() {
        final t = twoTabs();
        final cx = t.cx;
        final view = t.view.read(app);
        renderFrame(cx);
        cx.update((window, cx) -> view.elsewhere.focus(window, cx));
        renderFrame(cx);

        cx.update((window, cx) -> view.area.update(cx, (area, acx) -> area.removePanel(view.alpha, window, acx)));
        renderFrame(cx);
        assertTrue(cx.update((window, _) -> view.elsewhere.isFocused(window)));
    }

    function testDockCloseButtonTransfersFocusFromAChildInput() {
        final t = twoTabs();
        final cx = t.cx;
        final view = t.view.read(app);
        renderFrame(cx);
        clickEditor(cx, 'alpha');
        assertTrue(editorFocused(cx, view.alpha));
        closeVisibleTab(cx, 'alpha', 0);

        waitFor(cx, () -> find(cx, 'alpha') == null && visible(cx, 'beta') && focused(cx, view.beta), 'beta has the focus');
    }

    function testDockCloseButtonPreservesFocusChosenByOnRemoved() {
        final t = twoTabs();
        final cx = t.cx;
        final view = t.view.read(app);
        view.alpha.read(app).removedFocus = view.elsewhere;
        renderFrame(cx);
        clickEditor(cx, 'alpha');
        closeVisibleTab(cx, 'alpha', 0);

        waitFor(cx, () -> find(cx, 'alpha') == null && cx.update((window, _) -> view.elsewhere.isFocused(window)), 'on_removed chose the focus');
    }

    function testDockCloseButtonFocusesTheRemainingSplitWhenAGroupDisappears() {
        for (closeAlpha in [true, false]) {
            final t = twoTabs();
            final cx = t.cx;
            final view = t.view.read(app);
            cx.update((window, cx) -> {
                final layout = DockLayout.hSplit()
                    .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(view.alpha), cx), null)
                    .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(view.beta), cx), null);
                view.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
            });
            renderFrame(cx);
            final name = closeAlpha ? 'alpha' : 'beta';
            final next = closeAlpha ? view.beta : view.alpha;
            clickEditor(cx, name);
            closeVisibleTab(cx, name, 0);

            waitFor(cx, () -> find(cx, name) == null && focused(cx, next) && visible(cx, next.read(app).name), 'the remaining split has the focus');
        }
    }

    function testDockCloseButtonPreservesFocusWhenClosingAnInactiveTab() {
        final t = twoTabs();
        final cx = t.cx;
        final view = t.view.read(app);
        renderFrame(cx);
        clickEditor(cx, 'alpha');
        closeVisibleTab(cx, 'alpha', 1);

        waitFor(cx, () -> cx.update((_, cx) -> view.area.read(cx).panel(PanelId.fromEntityId(view.beta.entityId())) == null)
            && editorFocused(cx, view.alpha), 'beta closed, the editor kept the focus');
    }

    function testDockCloseButtonSkipsAHiddenNeighborWhenHandingOffFocus() {
        final t = twoTabs();
        final cx = t.cx;
        final view = t.view.read(app);
        cx.update((window, cx) -> {
            final hidden = Document.create('hidden', window, cx, false);
            final layout = DockLayout.hSplit()
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(view.alpha), cx), null)
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(hidden), cx), null)
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(view.beta), cx), null);
            view.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        renderFrame(cx);
        assertTrue(find(cx, 'hidden') == null);
        clickEditor(cx, 'alpha');
        closeVisibleTab(cx, 'alpha', 0);

        waitFor(cx, () -> find(cx, 'alpha') == null && visible(cx, 'beta') && focused(cx, view.beta), 'beta has the focus');
    }

}

/**
 * The test document: a named panel holding an input (Rust `Document`).
 */
@:allow(tests.kit)
private class Document extends PanelBase {

    final name:String;

    final focus:FocusHandle;

    final input:Entity<InputState>;

    var removedFocus:Null<FocusHandle> = null;

    final visibleValue:Bool;

    function new(name:String, visible:Bool, window:Window, cx:Context<Document>) {
        super();
        this.name = name;
        this.focus = cx.focusHandle();
        this.input = cx.newEntity((icx:Context<InputState>) -> new InputState(window, icx));
        this.visibleValue = visible;
    }

    public static function create(name:String, window:Window, cx:App, visible:Bool = true):Entity<Document> {
        return cx.newEntity((dcx:Context<Document>) -> new Document(name, visible, window, dcx));
    }

    public function panelName():String {
        return name;
    }

    override public function visible(cx:App):Bool {
        return visibleValue;
    }

    override public function onRemoved(window:Window, cx:Context<Dynamic>):Void {
        if (removedFocus != null) removedFocus.focus(window, cx.app);
    }

    override public function title(window:Window, cx:Context<Dynamic>):IntoElement {
        return name;
    }

    override public function zoomControl(cx:App):Null<PanelControl> {
        return Toolbar;
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final name = this.name;
        return @:privateAccess DockDebugBounds.wrap(() -> 'panel-$name', div()
            .id(name)
            .trackFocus(focus)
            .sizeFull()
            .child(name)
            .child(@:privateAccess DockDebugBounds.wrap(() -> 'editor-$name', Input.component(input).id('editor'))));
    }

}

/** Rust `Editor`: the area filling the window. */
private class DockEditor extends Model implements Render {

    public final area:Entity<DockArea>;

    public function new(area:Entity<DockArea>) {
        super();
        this.area = area;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(area);
    }

}

/** Rust `TwoTabs`: a focusable strip above the area. */
@:allow(tests.kit)
private class TwoTabs extends Model implements Render {

    final area:Entity<DockArea>;

    final alpha:Entity<Document>;

    final beta:Entity<Document>;

    final elsewhere:FocusHandle;

    public function new(area:Entity<DockArea>, alpha:Entity<Document>, beta:Entity<Document>, elsewhere:FocusHandle) {
        super();
        this.area = area;
        this.alpha = alpha;
        this.beta = beta;
        this.elsewhere = elsewhere;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .child(div().trackFocus(elsewhere).h(px(20.)))
            .child(area);
    }

}
