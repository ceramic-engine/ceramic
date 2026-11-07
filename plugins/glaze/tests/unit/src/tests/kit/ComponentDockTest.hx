// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs, panel.rs, dock.rs, tab_panel.rs, test_support.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.Point;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.dock.DockArea;
import glaze.kit.base.dock.DockAreaRendererBase;
import glaze.kit.base.dock.DockLayout;
import glaze.kit.base.dock.DockPlacement;
import glaze.kit.base.dock.PanelRegistry;
import glaze.kit.base.dock.TabGroupContext;
import glaze.kit.base.dock.TabGroupRenderer;
import glaze.kit.base.dock.TabGroupRendererBase;
import glaze.kit.base.resizable.Resizable as BaseResizable;
import glaze.kit.Component;
import glaze.kit.dock.ClosePanel;
import glaze.kit.dock.DockDebugBounds;
import glaze.kit.dock.DockSkin;
import glaze.kit.dock.DockToggleEvent;
import glaze.kit.dock.PanelBase;
import glaze.kit.dock.PanelControl;
import glaze.kit.dock.PanelHandle;
import glaze.kit.dock.TabGroupSkin;
import glaze.kit.dock.ToggleZoom;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;

/**
 * The `#[cfg(test)]` tests of gpui-component's dock skin (`dock/mod.rs`,
 * `panel.rs`, `dock.rs`, `tab_panel.rs`, with the probes of
 * `test_support.rs`).
 *
 * `cx.debug_bounds(selector)` reads `DockDebugBounds` (the skin's debug
 * selectors, recorded while the tests run); the windows draw every view on
 * every frame like GPUI (`window.viewCaching = false`), so a frame reports
 * exactly what it drew. `simulate_resize` is the window size given at
 * creation.
 */
@:access(glaze.kit.dock.TabGroupSkin)
@:access(glaze.kit.dock.DockSkin)
class ComponentDockTest extends TestCase {

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

    /** Rust `crate::init(cx)`. */
    function init():Void {
        app.update(cx -> Component.init(cx));
    }

    function open(build:(Window, Context<DockArea>) -> DockArea, width:Float = 1920, height:Float = 1080):{area:Entity<DockArea>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build, width, height);
        opened.cx.window.viewCaching = false;
        contexts.push(opened.cx);
        return {area: opened.view, cx: opened.cx};
    }

    function skinned(width:Float = 1920, height:Float = 1080):{area:Entity<DockArea>, cx:VisualTestContext, skin:DockSkin} {
        var skin:Null<DockSkin> = null;
        final opened = open((window, cx) -> {
            skin = new DockSkin(cx);
            new DockArea('skin', null, window, cx).withRenderer(skin);
        }, width, height);
        return {area: opened.area, cx: opened.cx, skin: skin};
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    static function debugBounds(cx:VisualTestContext, selector:String):Null<Bounds> {
        return DockDebugBounds.bounds(cx.window, selector);
    }

    function toggleEvents(area:Entity<DockArea>, cx:VisualTestContext):Array<String> {
        final events:Array<String> = [];
        cx.update((_, cx) -> cx.subscribe(area, DockToggleEvent, (_, event, _) -> events.push('${event.placement()} ${event.isOpen()}')).detach());
        return events;
    }

/// mod.rs

    /**
     * Every name `gpui_base::dock` exports has to be reachable from the
     * component dock, or an application cannot write its own skin without
     * depending on the foundation package directly.
     *
     * Reads both Rust export lists like the original, plus the names the
     * Haxe component package re-exports (its `typedef X =
     * glaze.kit.base.dock.X` modules), embedded at compile time.
     */
    function testEveryBaseDockExportIsReachableFromHere() {
        final base = exportedNames(ComponentDockExports.baseModRs(), 'pub use ');
        assertTrue(base.length > 30, 'the parse found only ${base.length} names in base\'s dock module');

        final reachable = exportedNames(ComponentDockExports.componentModRs(), 'pub use gpui_base::dock::');
        final renamed = ['Panel', 'PanelView'];
        final omitted = ['Dock'];
        final missing = [for (name in base) if (!reachable.contains(name) && !renamed.contains(name) && !omitted.contains(name)) name];
        assertEquals('', missing.join(', '), 'gpui_base::dock exports these, and gpui_component::dock does not re-export them');

        // The port's own re-exports: every reachable name but the function
        // `register_panel` (`PanelRegistry.registerPanel`) is a typedef of
        // the component package, and the two renamed ones are `BasePanel`
        // and `BasePanelView`.
        final haxe = ComponentDockExports.haxeReexports();
        final expected = [for (name in reachable) if (~/^[A-Za-z_]+$/.match(name) && name != 'register_panel') switch name {
            case 'Panel': 'BasePanel';
            case 'PanelView': 'BasePanelView';
            case _: name;
        }];
        expected.sort(Reflect.compare);
        assertEquals(expected.join(','), haxe.join(','));
    }

    /**
     * The crude parse of the original test: the braces of each
     * `pub use ...::{..}` and the tail of each single-name `pub use a::b;`.
     */
    static function exportedNames(source:String, prefix:String):Array<String> {
        final names:Array<String> = [];
        var rest = source;
        while (true) {
            final at = rest.indexOf(prefix);
            if (at == -1) break;
            rest = rest.substr(at + prefix.length);
            final end = rest.indexOf(';');
            if (end == -1) break;
            final item = StringTools.trim(rest.substr(0, end));
            rest = rest.substr(end);
            final open = item.indexOf('{');
            final close = item.lastIndexOf('}');
            final list = open != -1 && close != -1 && open < close ? item.substring(open + 1, close) : item.split('::').pop();
            for (name in list.split(',')) {
                final trimmed = StringTools.trim(name.split(' as ')[0]);
                if (trimmed != '' && !names.contains(trimmed)) names.push(trimmed);
            }
        }
        names.sort(Reflect.compare);
        return names;
    }

/// panel.rs

    function seamArea(recovered:Recovered):{area:Entity<DockArea>, cx:VisualTestContext} {
        app.update(cx -> glaze.kit.base.theme.Theme.globalMut(cx));
        return open((window, cx) -> new DockArea('seam', null, window, cx).withRenderer(new SeamSkin(recovered)));
    }

    /**
     * The seam this module exists for: a panel wrapped in a `PanelHandle`,
     * installed through base's `DockLayout`, comes back to the skin's tab bar
     * as a handle it can read presentation off.
     */
    function testTheTabBarRecoversPresentationFromABasePanelHandle() {
        final recovered = new Recovered();
        final s = seamArea(recovered);
        s.cx.update((window, cx) -> {
            final panel = PanelHandle.create(SkinProbe.create('Probe', cx, p -> p.tabNameValue = 'Probe Tab'));
            final layout = DockLayout.tabs().panelView(panel, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        recovered.tabNames.resize(0);
        draw(s.cx);

        assertEquals('Probe Tab', recovered.tabNames.join(','), 'the skin read its own panel trait off base\'s handle');

        // And the handle it kept still answers once the frame that recovered
        // it is over, which is what an ellipsis menu's callback needs.
        final deferred = recovered.deferred;
        assertTrue(deferred != null);
        final later = s.cx.update((window, cx) -> deferred(window, cx));
        assertEquals('Probe Tab', later);
    }

    /**
     * A panel rebuilt from persisted state is recoverable too: the skin's
     * registry builder returns a `PanelHandle` and base stores it as-is.
     */
    function testAPanelRebuiltFromPersistedStateIsRecoverable() {
        final recovered = new Recovered();
        final s = seamArea(recovered);
        s.cx.update((window, cx) -> {
            PanelRegistry.registerPanel(cx, 'Probe', (_, _, cx) -> PanelHandle.create(SkinProbe.create('Probe', cx, p -> p.tabNameValue = 'Restored Tab')));
            final panel = PanelHandle.create(SkinProbe.create('Probe', cx, p -> p.tabNameValue = 'Probe Tab'));
            final layout = DockLayout.tabs().panelView(panel, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();

        final state = s.cx.update((_, cx) -> s.area.read(cx).dump(cx));
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.load(state, window, acx)));
        s.cx.runUntilParked();
        recovered.tabNames.resize(0);
        draw(s.cx);

        assertEquals('Restored Tab', recovered.tabNames.join(','), 'the rebuilt panel reached the tab bar as a handle, not a bare entity');
    }

    /**
     * A panel base was handed directly is not this crate's handle, and the
     * skin is told so rather than being handed something wrong.
     */
    function testAPanelBaseWasHandedDirectlyIsNotRecoverable() {
        final recovered = new Recovered();
        final s = seamArea(recovered);
        s.cx.update((window, cx) -> {
            final layout = DockLayout.tabs().panel(SkinProbe.create('Probe', cx, p -> p.tabNameValue = 'Probe Tab'));
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        recovered.tabNames.resize(0);
        draw(s.cx);

        assertEquals('None', recovered.tabNames.join(','), 'an unwrapped panel is reported as unrecoverable, not wrongly recovered');
    }

/// dock.rs

    /**
     * A dock's box is base's, not its renderer's: under a renderer that draws
     * no chrome at all, a dock is still its own width, the centre is what the
     * docks leave, and a group fills its slot.
     */
    function testADockIsItsOwnWidthUnderARendererThatDrawsNoChrome() {
        init();
        final measured = new SizeCell();
        final centre = new SizeCell();
        final s = open((window, cx) -> new DockArea('test', null, window, cx).withRenderer(new ChromelessDockSkin()), 800, 600);
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setCenter(DockLayout.tabs().panel(SkinProbe.create('SizedProbe', cx, p -> p.sizeCell = centre)), window, acx);
            area.setDock(DockPlacement.Right, DockLayout.tabs().panel(SkinProbe.create('SizedProbe', cx, p -> p.sizeCell = measured)), window, acx);
            area.setDockSize(DockPlacement.Right, 200., window, acx);
        }));
        s.cx.runUntilParked();
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            if (!area.isDockOpen(DockPlacement.Right)) area.toggleDock(DockPlacement.Right, window, acx);
        }));
        s.cx.runUntilParked();
        draw(s.cx);

        assertEquals(200., measured.size.width, 'the right dock has to be its own width, not the area\'s');
        assertEquals(600., centre.size.width, 'the centre has to be what the docks leave');
        assertEquals(600., centre.size.height, 'a group has to fill its slot, or its panel gets no height');
    }

    function areaWithSideDocks():{area:Entity<DockArea>, cx:VisualTestContext} {
        init();
        final s = skinned(800, 600);
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setCenter(DockLayout.tabs().panel(SkinProbe.create('MeasuredProbe', cx)), window, acx);
            area.setDock(DockPlacement.Left, DockLayout.tabs().panel(SkinProbe.create('MeasuredProbe', cx)), window, acx);
            area.setDock(DockPlacement.Right, DockLayout.tabs().panel(SkinProbe.create('MeasuredProbe', cx)), window, acx);
        }));
        s.cx.runUntilParked();
        return {area: s.area, cx: s.cx};
    }

    /**
     * Every dock's handle once shared the literal element id, so GPUI handed
     * them one element state: pressing the left handle let the right dock's
     * drag listener claim the drag.
     */
    function testDraggingTheLeftHandleResizesOnlyTheLeftDock() {
        final s = areaWithSideDocks();
        draw(s.cx);

        // The left dock is 200px wide, so its handle sits at x in [198, 199).
        s.cx.simulateMouseDown(new Point(198.5, 300.), Left);
        // Past the drag threshold: the drag starts and claims a dock.
        s.cx.simulateMouseMove(new Point(204., 300.), Left);
        // The move the claimed dock resizes to.
        s.cx.simulateMouseMove(new Point(240., 300.), Left);
        s.cx.simulateMouseUp(new Point(240., 300.), Left);
        s.cx.runUntilParked();

        final sizes = s.cx.update((_, cx) -> {
            final area = s.area.read(cx);
            {left: area.dockSize(DockPlacement.Left), right: area.dockSize(DockPlacement.Right)};
        });
        assertEquals(200., sizes.right, 'the right dock must not move when the left handle is dragged');
        assertEquals(240., sizes.left, 'the left dock follows the pointer');
    }

    function bottomDockArea():{area:Entity<DockArea>, cx:VisualTestContext} {
        init();
        final s = skinned(800, 600);
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> {
            area.setCenter(DockLayout.tabs().panel(SkinProbe.create('MeasuredProbe', cx)), window, acx);
            area.setDock(DockPlacement.Bottom, DockLayout.tabs().panel(SkinProbe.create('MeasuredProbe', cx)), window, acx);
            area.setDockSize(DockPlacement.Bottom, 200., window, acx);
        }));
        return {area: s.area, cx: s.cx};
    }

    static function dragVertically(cx:VisualTestContext, ys:Array<Float>):Void {
        draw(cx);
        cx.simulateMouseDown(new Point(400., ys[0]), Left);
        for (ix in 1...ys.length) cx.simulateMouseMove(new Point(400., ys[ix]), Left);
        cx.simulateMouseUp(new Point(400., ys[ys.length - 1]), Left);
        cx.runUntilParked();
    }

    function testDraggingTheBottomDockClosedAndOpenReportsEachToggle() {
        final s = bottomDockArea();
        final events = toggleEvents(s.area, s.cx);
        s.cx.runUntilParked();

        // A resize that keeps the dock open is not a toggle.
        dragVertically(s.cx, [400.5, 380., 350.]);
        assertEquals('', events.join(','), 'a plain resize is not reported');

        // Same handle, same strip geometry as the snapping test below.
        dragVertically(s.cx, [350.5, 356., 580., 540.]);
        dragVertically(s.cx, [571.5, 565., 520.]);
        assertEquals('Bottom false,Bottom true', events.join(','));
    }

    function testDraggingTheBottomHandleBelowTheMinimumSnapsToTheNearerEnd() {
        final s = bottomDockArea();
        s.cx.runUntilParked();
        final bottom = () -> s.cx.update((_, cx) -> {
            final area = s.area.read(cx);
            final size:Null<Float> = area.dockSize(DockPlacement.Bottom);
            '${area.isDockOpen(DockPlacement.Bottom)} $size';
        });

        // From the 200px dock's handle at y in [400, 401), through the closed
        // strip and back, released 60px tall: nearer the strip than the
        // minimum, so it closes.
        dragVertically(s.cx, [400.5, 406., 580., 540.]);
        assertTrue(StringTools.startsWith(bottom(), 'false'), 'released nearer the strip, the dock closes');

        // From the closed strip's handle at y in [571, 572), released 80px
        // tall: nearer the minimum, so it opens at the minimum.
        dragVertically(s.cx, [571.5, 565., 520.]);
        assertEquals('true ${(BaseResizable.PANEL_MIN_SIZE : Float)}', bottom(), 'released nearer the minimum, the dock opens at the minimum');
    }

/// tab_panel.rs

    function recordingArea(log:Array<Bool>):{area:Entity<DockArea>, cx:VisualTestContext} {
        init();
        return open((window, cx) -> new DockArea('skin', null, window, cx).withRenderer(new RecorderSkin(log)));
    }

    /**
     * The gate carried forward from the old `TabPanel::render`. Base does not
     * enforce it: `TabGroupContext.dragPanel` answers for any tab in range.
     */
    function testTheLastGroupInADockOffersNoDrag() {
        final log:Array<Bool> = [];
        final s = recordingArea(log);
        s.cx.update((window, cx) -> {
            final layout = DockLayout.tabs().panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        log.resize(0);
        draw(s.cx);

        assertEquals('false', log.join(','), 'the only visible panel in the dock has nowhere to go, so its tab must not start a drag');
    }

    function testAGroupBesideAnotherOffersADrag() {
        final log:Array<Bool> = [];
        final s = recordingArea(log);
        s.cx.update((window, cx) -> {
            final layout = DockLayout.hSplit()
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx), null)
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx), null);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        log.resize(0);
        draw(s.cx);

        assertEquals('true,true', log.join(','), 'each group has somewhere to go, so both tabs start a drag');
    }

    /**
     * Draw one panel through the real `DockSkin` and report whether its tab
     * bar offered a zoom control.
     */
    function drewZoomControl(panel:(App) -> glaze.kit.base.dock.PanelView):Bool {
        init();
        final s = skinned();
        s.cx.update((window, cx) -> {
            final layout = DockLayout.tabs().panelView(panel(cx), cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        draw(s.cx);
        return debugBounds(s.cx, TabGroupSkin.ZOOM_CONTROL_SELECTOR) != null;
    }

    /**
     * A control drawn against base's refusal is dead: pressing it does nothing.
     */
    function testAPanelBaseWillNotZoomGetsNoZoomControl() {
        final drew = drewZoomControl(cx -> PanelHandle.panelHandle(SkinProbe.create('UnzoomableProbe', cx, p -> {
            p.zoomableValue = false;
            p.zoomControlValue = Toolbar;
        })));
        assertFalse(drew, 'the panel names a place for the control, but base refuses the zoom');
    }

    function testAZoomablePanelGetsItsZoomControl() {
        final drew = drewZoomControl(cx -> PanelHandle.panelHandle(SkinProbe.create('ToolbarZoomProbe', cx, p -> p.zoomControlValue = Toolbar)));
        assertTrue(drew, 'a zoomable panel asking for a toolbar control gets one');
    }

    /**
     * The centre and the bottom dock share the centre column, and both get
     * height.
     */
    function testTheCentreAndTheBottomDockShareTheColumn() {
        init();
        final centre = new HeightCell();
        final bottom = new HeightCell();
        final s = skinned();
        s.cx.update((window, cx) -> {
            final centrePanel = SkinProbe.create('MeasuredProbe', cx, p -> p.heightCell = centre);
            final bottomPanel = SkinProbe.create('MeasuredProbe', cx, p -> p.heightCell = bottom);
            s.area.update(cx, (area, acx) -> {
                // A split inside a split, so the nested split frame is
                // exercised too, not only the centre's root.
                area.setCenter(DockLayout.vSplit().child(DockLayout.hSplit().child(DockLayout.tabs().panelView(PanelHandle.panelHandle(centrePanel), cx), null), null), window, acx);
                area.setDock(DockPlacement.Bottom, DockLayout.tabs().panelView(PanelHandle.panelHandle(bottomPanel), cx), window, acx);
                area.setDockSize(DockPlacement.Bottom, 200., window, acx);
            });
        });
        s.cx.runUntilParked();
        draw(s.cx);

        final windowHeight = s.cx.update((window, _) -> window.viewportSize().height);
        assertTrue(centre.height > 0., 'the centre panel must receive height; it got ${centre.height}');
        assertTrue(bottom.height > 0., 'the bottom dock\'s panel must receive height; it got ${bottom.height}');
        assertTrue(centre.height < windowHeight - 150., 'the centre must give the 200px bottom dock its share; the centre got ${centre.height} of $windowHeight');
    }

    /**
     * Whichever slots of a split are hidden, the drawn ones fill it.
     */
    function testASplitFillsItsContainerWhicheverSlotsAreHidden() {
        init();
        final heights = [for (_ in 0...3) new HeightCell()];
        final s = skinned();
        final probes = s.cx.update((window, cx) -> {
            final probes = [for (height in heights) SkinProbe.create('HideableProbe', cx, p -> p.heightCell = height)];
            s.area.update(cx, (area, acx) -> {
                var split = DockLayout.vSplit();
                final sizes = [260., 320., 200.];
                for (ix in 0...3) split = split.child(DockLayout.tabs().panelView(PanelHandle.panelHandle(probes[ix]), cx), sizes[ix]);
                area.setDock(DockPlacement.Right, split, window, acx);
                area.setDockSize(DockPlacement.Right, 380., window, acx);
            });
            probes;
        });
        s.cx.runUntilParked();
        final drawTwice = () -> {
            s.cx.update((window, _) -> window.refresh());
            draw(s.cx);
            draw(s.cx);
        };
        drawTwice();

        final dockHeight = s.cx.update((window, _) -> window.viewportSize().height);
        // Each slot spends a tab bar out of its height and the probe under it
        // measures the rest.
        var drawn = 0.;
        for (height in heights) drawn += height.height;
        final bar = (dockHeight - drawn) / 3.;
        assertTrue(bar > 0. && bar < 60., 'the three slots fill the dock to begin with, one tab bar each; that leaves $bar per slot of $dockHeight');

        // Every subset except "all three hidden".
        for (hidden in 1...7) {
            s.cx.update((_, cx) -> {
                for (slot in 0...3) {
                    // A sentinel, so a slot that stopped drawing is not read
                    // as one that kept the height it had.
                    heights[slot].height = -1.;
                    probes[slot].update(cx, (probe, pcx) -> probe.setVisible(hidden & (1 << slot) == 0, pcx));
                }
            });
            s.cx.runUntilParked();
            drawTwice();

            var count = 0;
            var total = 0.;
            for (slot in 0...3) {
                if (hidden & (1 << slot) != 0) continue;
                assertTrue(heights[slot].height != -1., 'hiding $hidden: slot $slot is shown and must draw');
                count++;
                total += heights[slot].height;
            }
            final empty = dockHeight - total - bar * count;
            assertTrue(Math.abs(empty) < 1., 'hiding $hidden: the drawn slots must take the hidden ones\' space between them; they left $empty of $dockHeight empty');
        }
    }

    function focusedSkinnedArea(build:(App) -> {panel:Entity<SkinProbe>, layout:DockLayout}, ?bottom:Bool):{area:Entity<DockArea>, cx:VisualTestContext} {
        init();
        final s = skinned();
        final panel = s.cx.update((window, cx) -> {
            final built = build(cx);
            s.area.update(cx, (area, acx) -> {
                if (bottom == true) {
                    area.setDock(DockPlacement.Bottom, built.layout, window, acx);
                    area.toggleDock(DockPlacement.Bottom, window, acx);
                } else {
                    area.setCenter(built.layout, window, acx);
                }
            });
            built.panel;
        });
        s.cx.runUntilParked();
        s.cx.update((window, cx) -> panel.read(cx).focusHandle(cx).focus(window, cx));
        s.cx.runUntilParked();
        return {area: s.area, cx: s.cx};
    }

    static function isZoomed(s:{area:Entity<DockArea>, cx:VisualTestContext}):Bool {
        return s.cx.update((_, cx) -> s.area.read(cx).isZoomed());
    }

    static function dispatch(cx:VisualTestContext, action:glaze.Action):Void {
        cx.update((window, cx) -> window.dispatchAction(action, cx));
        cx.runUntilParked();
    }

    /**
     * Base installs neither `ToggleZoom` nor `ClosePanel`, so the skin's
     * `frame` is the only place the keybindings reach.
     */
    function testTheZoomActionReachesTheGroupThroughTheSkin() {
        final s = focusedSkinnedArea(cx -> {
            final panel = SkinProbe.create('Probe', cx);
            {panel: panel, layout: DockLayout.tabs().panelView(PanelHandle.panelHandle(panel), cx)};
        });
        assertFalse(isZoomed(s));
        dispatch(s.cx, new ToggleZoom());
        assertTrue(isZoomed(s), 'the skin\'s frame is what carries the ToggleZoom handler');
        dispatch(s.cx, new ToggleZoom());
        assertFalse(isZoomed(s));
    }

    /**
     * Withholding the control withholds the whole affordance, keybinding
     * included.
     */
    function testTheZoomActionRefusesAPanelThatOffersNoControl() {
        final s = focusedSkinnedArea(cx -> {
            final panel = SkinProbe.create('NoControlProbe', cx, p -> p.zoomControlValue = null);
            {panel: panel, layout: DockLayout.tabs().panelView(PanelHandle.panelHandle(panel), cx)};
        });
        dispatch(s.cx, new ToggleZoom());
        assertFalse(isZoomed(s), 'no control means no zoom, however the zoom was asked for');
    }

    /**
     * The tab group's own frame has to be a flex column, or the content
     * region resolves to zero height.
     */
    function testThePanelContentRegionGetsTheHeightBelowTheTabBar() {
        init();
        final height = new HeightCell();
        final s = skinned();
        s.cx.update((window, cx) -> {
            final panel = SkinProbe.create('MeasuredProbe', cx, p -> p.heightCell = height);
            final layout = DockLayout.tabs().panelView(PanelHandle.panelHandle(panel), cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        draw(s.cx);

        final windowHeight = s.cx.update((window, _) -> window.viewportSize().height);
        final content = height.height;
        assertTrue(content > 0., 'the panel must receive height; it got $content in a $windowHeight window');
        assertTrue(content > windowHeight - 60., 'the panel should fill what the tab bar leaves; it got $content of $windowHeight');
    }

    /**
     * A collapsed group is a strip of tabs with no content, and the actions
     * act on content. The bottom dock, not a side one: a closed left or right
     * dock draws nothing at all.
     */
    function testACollapsedDockIgnoresTheZoomAction() {
        final s = focusedSkinnedArea(cx -> {
            final panel = SkinProbe.create('Probe', cx);
            {panel: panel, layout: DockLayout.tabs().panelView(PanelHandle.panelHandle(panel), cx)};
        }, true);
        dispatch(s.cx, new ToggleZoom());
        assertFalse(isZoomed(s), 'a collapsed group installs no action handler');
    }

    /**
     * A panel that carries its own chrome declines the one-panel title bar
     * and gets the whole group.
     */
    function testAPanelWithoutATitleBarGetsTheWholeGroup() {
        init();
        final measure = (chromeless:Bool) -> {
            final height = new HeightCell();
            final s = skinned();
            s.cx.update((window, cx) -> {
                final panel = SkinProbe.create(chromeless ? 'Chromeless' : 'MeasuredProbe', cx, p -> {
                    p.heightCell = height;
                    p.titleBarValue = !chromeless;
                });
                final layout = DockLayout.tabs().panelView(PanelHandle.panelHandle(panel), cx);
                s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
            });
            s.cx.runUntilParked();
            draw(s.cx);
            height.height;
        };
        final withTitle = measure(false);
        final without = measure(true);
        assertTrue(withTitle > 0., 'the probe must have been drawn');
        assertEquals(withTitle + 30., without, 'the 30px the title bar took go to the panel instead');
    }

    /**
     * Render a two-tab group through the real `DockSkin` and report whether
     * the first tab drew a close button.
     */
    function drewCloseButton(closable:Bool, enabled:Bool):Bool {
        init();
        final s = skinned();
        if (enabled) s.cx.update((_, cx) -> s.skin.setCloseButtonVisible(true, cx));
        s.cx.update((window, cx) -> {
            final underTest = SkinProbe.create('TabProbe', cx, p -> p.closableValue = closable);
            final filler = SkinProbe.create('TabProbe', cx, p -> p.closableValue = false);
            final layout = DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(underTest), cx)
                .panelView(PanelHandle.panelHandle(filler), cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        draw(s.cx);
        final button = debugBounds(s.cx, TabGroupSkin.CLOSE_BUTTON_SELECTOR);
        if (enabled && closable) {
            assertEquals(20., button != null ? button.size.width : -1., 'the close button keeps the standard XS hover target');
        }
        return button != null;
    }

    function testAClosablePanelGetsACloseButton() {
        assertTrue(drewCloseButton(true, true), 'a closable panel\'s tab must draw a close button');
    }

    function testANonClosablePanelGetsNoCloseButton() {
        assertFalse(drewCloseButton(false, true), 'a panel that reports itself non-closable must draw no close button');
    }

    function testCloseButtonsAreOffByDefault() {
        assertFalse(drewCloseButton(true, false));
    }

    function testCloseButtonVisibilityUpdatesAfterTheSkinSettingChanges() {
        init();
        final s = skinned();
        s.cx.update((window, cx) -> {
            final panel = SkinProbe.create('TabProbe', cx, p -> p.closableValue = true);
            final filler = SkinProbe.create('TabProbe', cx, p -> p.closableValue = false);
            s.area.update(cx, (area, acx) -> area.setCenter(DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(panel), cx)
                .panelView(PanelHandle.panelHandle(filler), cx), window, acx));
        });

        for (step in [{visible: false, expected: false}, {visible: true, expected: true}, {visible: false, expected: false}]) {
            s.cx.update((_, cx) -> s.skin.setCloseButtonVisible(step.visible, cx));
            s.cx.runUntilParked();
            draw(s.cx);
            assertEquals(step.expected, debugBounds(s.cx, TabGroupSkin.CLOSE_BUTTON_SELECTOR) != null);
        }
    }

    /**
     * Clicking a non-active tab's close button removes that panel by id and
     * does not select it.
     */
    function testClickingACloseButtonRemovesOnlyThatTab() {
        init();
        final s = skinned();
        s.cx.update((_, cx) -> s.skin.setCloseButtonVisible(true, cx));

        final ids = s.cx.update((window, cx) -> {
            final filler = SkinProbe.create('TabProbe', cx, p -> p.closableValue = false);
            final closable = SkinProbe.create('TabProbe', cx, p -> p.closableValue = true);
            final activated = closable.read(cx).activated;
            final fillerHandle = PanelHandle.panelHandle(filler);
            final closableHandle = PanelHandle.panelHandle(closable);
            // Filler at ix 0 is the displayed tab; the closable tab at ix 1 is
            // never active, so its close button is the only one drawn.
            final layout = DockLayout.tabs()
                .panelView(fillerHandle, cx)
                .panelView(closableHandle, cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
            {closable: closableHandle.panelId(cx), filler: fillerHandle.panelId(cx), activated: activated};
        });
        s.cx.runUntilParked();
        draw(s.cx);

        assertTrue(s.cx.update((_, cx) -> s.area.read(cx).panel(ids.closable) != null), 'the closable tab starts owned by the area');

        final button = debugBounds(s.cx, TabGroupSkin.CLOSE_BUTTON_SELECTOR);
        assertTrue(button != null, 'the non-active closable tab draws a close button');
        s.cx.simulateMouseDown(button.center(), Left);
        s.cx.simulateMouseUp(button.center(), Left);
        s.cx.runUntilParked();

        assertTrue(s.cx.update((_, cx) -> s.area.read(cx).panel(ids.closable) == null), 'the close click removes exactly the tab it belongs to');
        assertTrue(s.cx.update((_, cx) -> s.area.read(cx).panel(ids.filler) != null), 'the displayed filler tab is untouched');
        assertFalse(ids.activated.value, 'stop_propagation keeps the close click from also selecting the tab');
    }

    /**
     * A click is left to the tab bar's animated reveal: the skin's own snap
     * for a changed tab would land the strip on the first frame and cut the
     * animation short.
     */
    function testAClickedTabIsRevealedByTheTabBarNotSnapped() {
        init();
        app.update(cx -> cx.setReduceMotion(false));
        final s = skinned(300, 300);
        s.cx.update((window, cx) -> {
            var layout = DockLayout.tabs();
            for (_ in 0...8) layout = layout.panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx);
            s.area.update(cx, (area, acx) -> area.setCenter(layout, window, acx));
        });
        s.cx.runUntilParked();
        draw(s.cx);

        final tab = (ix:Int) -> debugBounds(s.cx, '${TabGroupSkin.TAB_SELECTOR}-$ix');
        final firstLeft = () -> tab(0).left();
        final start = firstLeft();
        // The tab that runs off the strip: only its first few pixels show
        // before the bar's toolbar. Rust picks the first tab past the 300px
        // window, whose left edge its text metrics put before the toolbar;
        // the unit tests' font draws "Unnamed" wider, so the tab past the
        // window starts under the toolbar here. The tab running under the
        // toolbar (its suffix: 8 + 20 + 8 pixels and a 1 pixel border) is
        // the same tab in both.
        var clipped:Null<Bounds> = null;
        for (ix in 0...8) {
            final bounds = tab(ix);
            if (bounds.right() > 300. - 37.) {
                clipped = bounds;
                break;
            }
        }
        assertTrue(clipped != null);

        s.cx.simulateClick(clipped.origin.add(new Point(4., 16.)));
        draw(s.cx);
        assertEquals(start, firstLeft(), 'the first frame has not snapped');

        final lefts:Array<Float> = [];
        for (_ in 0...60) {
            s.cx.advanceClock(0.016);
            s.cx.update((window, cx) -> {
                window.simulateNextFrame(cx);
                window.draw();
            });
            lefts.push(firstLeft());
        }
        final end = lefts[lefts.length - 1];
        assertTrue(end < start, 'the strip scrolled');
        assertTrue(Lambda.exists(lefts, left -> left < start && left > end), 'the strip slid rather than jumped: $lefts');
    }

    /**
     * The collapse button reports the user's toggle; a toggle made by code
     * does not.
     */
    function testTheCollapseButtonReportsTheToggle() {
        init();
        final s = skinned(800, 600);
        final events = toggleEvents(s.area, s.cx);
        s.cx.update((window, cx) -> {
            final center = DockLayout.tabs().panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx);
            final left = DockLayout.tabs().panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx);
            s.area.update(cx, (area, acx) -> {
                area.setCenter(center, window, acx);
                area.setDock(DockPlacement.Left, left, window, acx);
            });
        });
        s.cx.runUntilParked();
        draw(s.cx);

        final button = debugBounds(s.cx, '${TabGroupSkin.DOCK_TOGGLE_SELECTOR}-${DockPlacement.Left}');
        assertTrue(button != null, 'the left dock offers a toggle');
        s.cx.simulateClick(button.center());
        s.cx.runUntilParked();
        assertFalse(s.cx.update((_, cx) -> s.area.read(cx).isDockOpen(DockPlacement.Left)));
        assertEquals('Left false', events.join(','));

        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.toggleDock(DockPlacement.Left, window, acx)));
        s.cx.runUntilParked();
        assertEquals(1, events.length, 'a toggle made by code is not reported');
    }

    /**
     * Clicking a tab on a collapsed bottom dock's strip opens the dock and
     * reports it.
     */
    function testOpeningTheBottomStripReportsTheToggle() {
        init();
        final s = skinned(800, 600);
        final events = toggleEvents(s.area, s.cx);
        s.cx.update((window, cx) -> {
            // Two panels: a group with one panel draws its title, not a tab bar.
            final layout = DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx)
                .panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx);
            s.area.update(cx, (area, acx) -> {
                area.setDock(DockPlacement.Bottom, layout, window, acx);
                area.toggleDock(DockPlacement.Bottom, window, acx);
            });
        });
        s.cx.runUntilParked();
        draw(s.cx);
        assertFalse(s.cx.update((_, cx) -> s.area.read(cx).isDockOpen(DockPlacement.Bottom)));

        final tab = debugBounds(s.cx, '${TabGroupSkin.TAB_SELECTOR}-0');
        assertTrue(tab != null, 'the collapsed strip still draws its tab');
        s.cx.simulateClick(tab.center());
        s.cx.runUntilParked();
        assertEquals('Bottom true', events.join(','));
    }

    /**
     * A dock that refuses to close is not reported as toggled.
     */
    function testARefusedToggleIsNotReported() {
        init();
        final s = skinned();
        final events = toggleEvents(s.area, s.cx);
        s.cx.update((window, cx) -> {
            final layout = DockLayout.tabs().panelView(PanelHandle.panelHandle(SkinProbe.create('Probe', cx)), cx);
            s.area.update(cx, (area, acx) -> {
                area.setDock(DockPlacement.Left, layout, window, acx);
                area.setDockCollapsible(DockPlacement.Left, false, window, acx);
            });
        });
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> DockSkin.toggleDockByUser(area, DockPlacement.Left, window, acx)));
        s.cx.runUntilParked();
        assertTrue(s.cx.update((_, cx) -> s.area.read(cx).isDockOpen(DockPlacement.Left)));
        assertEquals(0, events.length);
    }

    /**
     * A collapsed group offers no close button, though the same group does
     * while open.
     */
    function testACollapsedGroupDrawsNoCloseButton() {
        init();
        final s = skinned();
        s.cx.update((_, cx) -> s.skin.setCloseButtonVisible(true, cx));
        // Two closable panels so the group is draggable (not on its last
        // visible panel) and offers close buttons while open.
        s.cx.update((window, cx) -> {
            final layout = DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(SkinProbe.create('TabProbe', cx, p -> p.closableValue = true)), cx)
                .panelView(PanelHandle.panelHandle(SkinProbe.create('TabProbe', cx, p -> p.closableValue = true)), cx);
            s.area.update(cx, (area, acx) -> {
                area.setDock(DockPlacement.Bottom, layout, window, acx);
                if (!area.isDockOpen(DockPlacement.Bottom)) area.toggleDock(DockPlacement.Bottom, window, acx);
            });
        });
        s.cx.runUntilParked();
        draw(s.cx);
        assertTrue(debugBounds(s.cx, TabGroupSkin.CLOSE_BUTTON_SELECTOR) != null, 'an open group with two closable panels offers a close button');

        // Collapse the bottom dock: its strip stays clickable, but the close
        // buttons on it must not.
        s.cx.update((window, cx) -> s.area.update(cx, (area, acx) -> area.toggleDock(DockPlacement.Bottom, window, acx)));
        s.cx.runUntilParked();
        draw(s.cx);
        assertTrue(debugBounds(s.cx, TabGroupSkin.CLOSE_BUTTON_SELECTOR) == null, 'a collapsed group must not offer a close button');
    }

}

/**
 * The test panels (Rust `Probe`, `MeasuredProbe`, `SizedProbe`,
 * `HideableProbe`, `ToolbarZoomProbe`, `NoControlProbe`, `UnzoomableProbe`,
 * `TabProbe`, `Chromeless`): one configurable probe. It draws a full-size
 * div recording the box it was given when asked to.
 */
class SkinProbe extends PanelBase {

    final name:String;

    final focus:FocusHandle;

    public var tabNameValue:Null<String> = null;

    public var zoomControlValue:Null<PanelControl> = Menu;

    public var zoomableValue:Bool = true;

    public var closableValue:Bool = true;

    public var titleBarValue:Bool = true;

    @observe public var visibleValue:Bool = true;

    public var heightCell:Null<HeightCell> = null;

    public var sizeCell:Null<SizeCell> = null;

    public final activated:{value:Bool} = {value: false};

    function new(name:String, cx:Context<SkinProbe>) {
        super();
        this.name = name;
        this.focus = cx.focusHandle();
    }

    public static function create(name:String, cx:App, ?configure:(SkinProbe) -> Void):Entity<SkinProbe> {
        return cx.newEntity((pcx:Context<SkinProbe>) -> {
            final probe = new SkinProbe(name, pcx);
            if (configure != null) configure(probe);
            probe;
        });
    }

    public function setVisible(visible:Bool, cx:Context<SkinProbe>):Void {
        visibleValue = visible;
        cx.notify();
    }

    public function panelName():String {
        return name;
    }

    override public function tabName(cx:App):Null<String> {
        return tabNameValue;
    }

    override public function zoomControl(cx:App):Null<PanelControl> {
        return zoomControlValue;
    }

    override public function zoomable(cx:App):Bool {
        return zoomableValue;
    }

    override public function closable(cx:App):Bool {
        return closableValue;
    }

    override public function visible(cx:App):Bool {
        return visibleValue;
    }

    override public function titleBar(cx:App):Bool {
        return titleBarValue;
    }

    override public function setActive(active:Bool, window:Window, cx:Context<Dynamic>):Void {
        if (active) activated.value = true;
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        if (heightCell == null && sizeCell == null) return new glaze.Empty();
        final height = heightCell;
        final size = sizeCell;
        return div().sizeFull().onPrepaint((bounds, _, _) -> {
            if (height != null) height.height = bounds.size.height;
            if (size != null) size.size = bounds.size;
        });
    }

}

/**
 * What the seam skin's tab bar read off each panel while it drew (`null`
 * for a panel it could not recover), and a read it deferred, the way an
 * ellipsis menu defers building its items.
 */
private class Recovered {

    public final tabNames:Array<String> = [];

    public var deferred:Null<(Window, App) -> Null<String>> = null;

    public function new() {}

}

/**
 * The skin of the panel.rs tests: a tab bar that recovers this crate's
 * handle out of base's and reads presentation off it.
 */
private class SeamSkin extends DockAreaRendererBase {

    final recovered:Recovered;

    public function new(recovered:Recovered) {
        super();
        this.recovered = recovered;
    }

    override public function frame(window:Window, cx:App):Div {
        return div().id('skin-dock-area').sizeFull();
    }

    public function tabGroupRenderer():TabGroupRenderer {
        return new SeamTabs(recovered);
    }

}

private class SeamTabs extends TabGroupRendererBase {

    final recovered:Recovered;

    public function new(recovered:Recovered) {
        super();
        this.recovered = recovered;
    }

    public function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement {
        final tabs:Array<IntoElement> = [];
        for (panel in group.panels()) {
            final handle = PanelHandle.of(panel);
            if (handle == null) {
                recovered.tabNames.push('None');
                continue;
            }
            recovered.tabNames.push(handle.tabName(cx));
            // `title` takes the window and the app while `group` is still
            // borrowed, which is the shape every tab in a real tab bar is
            // built from.
            tabs.push(handle.title(window, cx));
            // And the shape an ellipsis menu needs: an owned handle, called
            // back long after this frame.
            final panel = handle.panel();
            recovered.deferred = (window, cx) -> {
                panel.title(window, cx);
                return panel.tabName(cx);
            };
        }
        return div().children(tabs).intoAnyElement();
    }

}

/**
 * A renderer that draws no chrome at all: every hook at its trait default.
 */
private class ChromelessDockSkin extends DockAreaRendererBase {

    public function new() {
        super();
    }

    public function tabGroupRenderer():TabGroupRenderer {
        return new ChromelessTabs();
    }

}

private class ChromelessTabs extends TabGroupRendererBase {

    public function new() {
        super();
    }

    // The one hook with no default. Drawn as nothing, so the height it
    // leaves the content is the whole group.
    public function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement {
        return new glaze.Empty().intoAnyElement();
    }

}

/**
 * Draws nothing, but runs the real gates the skin's tab bar runs and records
 * whether every tab would start a drag.
 */
private class RecorderSkin extends DockAreaRendererBase {

    final log:Array<Bool>;

    public function new(log:Array<Bool>) {
        super();
        this.log = log;
    }

    override public function frame(window:Window, cx:App):Div {
        return div().id('recorder').sizeFull();
    }

    public function tabGroupRenderer():TabGroupRenderer {
        return new RecorderTabs(log);
    }

}

@:access(glaze.kit.dock.TabGroupSkin)
private class RecorderTabs extends TabGroupRendererBase {

    final log:Array<Bool>;

    public function new(log:Array<Bool>) {
        super();
        this.log = log;
    }

    public function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement {
        for (ix in 0...group.panels().length) log.push(TabGroupSkin.tabDrag(group, ix, cx) != null);
        return new glaze.Empty().intoAnyElement();
    }

}

/** Rust `Rc<Cell<Pixels>>`: the height a probe was given. */
class HeightCell {

    public var height:Float = 0.;

    public function new() {}

}

/** Rust `Rc<Cell<Size<Pixels>>>`: the box a probe was given. */
class SizeCell {

    public var size:Size = new Size(0, 0);

    public function new() {}

}
