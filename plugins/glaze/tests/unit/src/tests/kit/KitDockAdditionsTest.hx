// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.dock.DockArea;
import glaze.kit.base.dock.DockLayout;
import glaze.kit.base.dock.DockPlacement;
import glaze.kit.base.dock.InsertTarget;
import glaze.kit.base.dock.NodeId;
import glaze.kit.base.dock.PanelId;
import glaze.kit.theme.Theme;
import glaze.kit.dock.DockDebugBounds;
import glaze.kit.dock.DockSkin;
import glaze.kit.dock.PanelBase;
import glaze.kit.dock.PanelHandle;
import glaze.kit.dock.PanelStyle;
import glaze.kit.dock.TabGroupSkin;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The dock additions without upstream equivalent: an accent on the active
 * tab (KIT-039), the close button of a tab on hover (KIT-047), and what
 * documents shown side by side in the centre need (KIT-050 to KIT-055).
 */
@:access(glaze.kit.dock.TabGroupSkin)
@:access(glaze.kit.base.dock.DockArea)
@:access(glaze.kit.base.dock.TabGroup)
class KitDockAdditionsTest extends KitAdditionsTestCase {

    static final ACCENT = hsla(0.9, 0.8, 0.5, 1.);

    override function setup() {
        super.setup();
        DockDebugBounds.enabled = true;
    }

    override function teardown() {
        DockDebugBounds.enabled = false;
        DockDebugBounds.clear();
        super.teardown();
    }

    /** A dock of one group of three tabs, the first one active; `configure` sets its skin. */
    function dock(configure:(DockSkin, App) -> Void):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<AdditionsDock>) -> {
            final created = DockSkin.dockArea('additions', null, window, cx.app);
            created.skin.setPanelStyle(PanelStyle.TabBar, cx.app);
            created.skin.setCloseButtonVisible(true, cx.app);
            configure(created.skin, cx.app);
            final layout = DockLayout.tabs();
            for (name in ['alpha', 'beta', 'gamma']) layout.panelView(PanelHandle.panelHandle(AdditionsPanel.create(name, cx.app)), cx.app);
            created.area.update(cx.app, (area, acx) -> area.setCenter(layout, window, acx));
            return new AdditionsDock(created.area);
        }, 900, 600);
        opened.cx.window.viewCachingDisabled = true;
        contexts.push(opened.cx);
        draw(opened.cx);
        draw(opened.cx);
        return opened.cx;
    }

    /** How many of the close buttons draw their cross: an icon that is not fully transparent inside their bounds. */
    function crosses(cx:VisualTestContext):Int {
        final buttons = closeButtons(cx);
        return cx.update((window, _) -> {
            final scale = window.scaleFactor();
            var count = 0;
            for (button in buttons) {
                for (sprite in window.renderedScene().monochromeSprites) {
                    final x = (sprite.boundsX + sprite.boundsWidth * 0.5) / scale;
                    final y = (sprite.boundsY + sprite.boundsHeight * 0.5) / scale;
                    if (sprite.colorA > 0.01 && button.contains(new glaze.Point(x, y))) {
                        count++;
                        break;
                    }
                }
            }
            return count;
        });
    }

    /** The close buttons of the tabs, from left to right. */
    function closeButtons(cx:VisualTestContext):Array<Bounds> {
        final all = DockDebugBounds.all(cx.window, TabGroupSkin.CLOSE_BUTTON_SELECTOR);
        all.sort((a, b) -> (a.origin.x : Float) < (b.origin.x : Float) ? -1 : 1);
        return all;
    }

    var built:Null<{area:Entity<DockArea>, skin:DockSkin, panels:Map<String, Entity<AdditionsPanel>>}> = null;

    /** A dock whose layout `fill` installs: it gets the area, its skin and a way to make a panel by name. */
    function custom(fill:(Entity<DockArea>, DockSkin, String -> glaze.kit.base.dock.PanelView, Window, App) -> Void):VisualTestContext {
        final panels:Map<String, Entity<AdditionsPanel>> = new Map();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<AdditionsDock>) -> {
            final created = DockSkin.dockArea('additions', null, window, cx.app);
            final app = cx.app;
            fill(created.area, created.skin, name -> {
                final panel = AdditionsPanel.create(name, app);
                panels.set(name, panel);
                return PanelHandle.panelHandle(panel);
            }, window, app);
            built = {area: created.area, skin: created.skin, panels: panels};
            return new AdditionsDock(created.area);
        }, 900, 600);
        opened.cx.window.viewCachingDisabled = true;
        contexts.push(opened.cx);
        draw(opened.cx);
        draw(opened.cx);
        return opened.cx;
    }

    function panelId(name:String):PanelId {
        return PanelId.fromEntityId(built.panels.get(name).entityId());
    }

    /** Two groups side by side in the centre: alpha and beta, then gamma. */
    function twoGroups(configure:(Entity<DockArea>, DockSkin, Window, App) -> Void):VisualTestContext {
        return custom((area, skin, make, window, cx) -> {
            skin.setPanelStyle(PanelStyle.TabBar, cx);
            configure(area, skin, window, cx);
            final left = DockLayout.tabs().panelView(make('alpha'), cx).panelView(make('beta'), cx);
            final right = DockLayout.tabs().panelView(make('gamma'), cx);
            area.update(cx, (area, acx) -> area.setCenter(DockLayout.hSplit().child(left, null).child(right, null), window, acx));
        });
    }

    function centerGroups():Array<NodeId> {
        final area:DockArea = built.area;
        return area.groupNodes(DockPlacement.Center);
    }

/// KIT-050

    function testAPolicyKeepsAPanelOutOfARegion() {
        final cx = custom((area, skin, make, window, cx) -> {
            area.update(cx, (area, acx) -> {
                area.setCenter(DockLayout.tabs().panelView(make('alpha'), cx).panelView(make('beta'), cx), window, acx);
                area.setDock(DockPlacement.Left, DockLayout.tabs().panelView(make('side'), cx), window, acx);
                // What is named side stays out of the centre, the rest stays out of the docks
                area.setDropPolicy((panel, placement, cx) -> (panel.panelName(cx) == 'side') != (placement == DockPlacement.Center));
            });
        });
        final area:DockArea = built.area;
        final center = centerGroups()[0];
        final left = area.groupNodes(DockPlacement.Left)[0];
        assertFalse(area.allowsPanel(panelId('side'), DockPlacement.Center, app));
        assertTrue(area.allowsPanel(panelId('side'), DockPlacement.Left, app));
        assertFalse(area.acceptsPanelAt(panelId('alpha'), left, app));
        assertTrue(area.acceptsPanelAt(panelId('alpha'), center, app));

        // A refused move changes nothing
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.movePanel(panelId('side'), InsertTarget.Tabs(center, null, true), window, acx)));
        assertEquals(DockPlacement.Left, area.placementOf(panelId('side')));
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.movePanel(panelId('alpha'), InsertTarget.Tabs(left, null, true), window, acx)));
        assertEquals(DockPlacement.Center, area.placementOf(panelId('alpha')));

        // The group itself tells a dragged panel it has no place there
        final group = area.groups.get(left.asU64()).entity;
        assertFalse(group.read(app).acceptsPanel(panelId('alpha'), app));
        assertTrue(group.read(app).acceptsPanel(panelId('side'), app));

        // Without a policy, everything moves again
        area.setDropPolicy(null);
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.movePanel(panelId('alpha'), InsertTarget.Tabs(left, null, true), window, acx)));
        assertEquals(DockPlacement.Left, area.placementOf(panelId('alpha')));
    }

/// KIT-051

    function testTheLastPanelOfAnEmptiableCentreCloses() {
        final fill = ACCENT;
        final cx = custom((area, skin, make, window, cx) -> {
            skin.setEmptyCenter((_, _) -> div().sizeFull().bg(fill), cx);
            area.update(cx, (area, acx) -> area.setCenter(DockLayout.tabs().panelView(make('alpha'), cx), window, acx));
        });
        final area:DockArea = built.area;
        final node = centerGroups()[0];
        final group = area.groups.get(node.asU64()).entity;
        // As in the original, the last panel of the centre stays
        assertFalse(group.read(app).isClosable(app));
        cx.update((_, cx) -> group.update(cx, (group, gcx) -> group.closePanel(panelId('alpha'), gcx)));
        draw(cx);
        assertFalse(area.isEmpty(DockPlacement.Center, app));
        assertEquals(0, quadsFilled(cx, fill).length);

        // Once the centre may be emptied, it closes, and the skin fills what is left
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.setCenterEmptiable(true, window, acx)));
        assertTrue(group.read(app).isClosable(app));
        cx.update((_, cx) -> group.update(cx, (group, gcx) -> group.closePanel(panelId('alpha'), gcx)));
        draw(cx);
        draw(cx);
        assertTrue(area.isEmpty(DockPlacement.Center, app));
        assertEquals(0, centerGroups().length);
        assertEquals(1, quadsFilled(cx, fill).length);

        // A panel added to the empty centre takes it back
        final again = AdditionsPanel.create('again', app);
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.addPanelView(PanelHandle.panelHandle(again), DockPlacement.Center, null, window, acx)));
        draw(cx);
        draw(cx);
        assertFalse(area.isEmpty(DockPlacement.Center, app));
        assertEquals(0, quadsFilled(cx, fill).length);
    }

/// KIT-052

    function testAClosedTabAsksItsHandlerFirst() {
        final cx = twoGroups((_, _, _, _) -> {});
        final area:DockArea = built.area;
        final node = centerGroups()[0];
        final group = area.groups.get(node.asU64()).entity;
        final asked:Array<String> = [];
        area.setCloseHandler((panel, _, cx) -> {
            asked.push(panel.panelName(cx));
            return false;
        });
        cx.update((_, cx) -> group.update(cx, (group, gcx) -> group.closePanel(panelId('beta'), gcx)));
        draw(cx);
        assertEquals('beta', asked.join(','));
        assertEquals(DockPlacement.Center, area.placementOf(panelId('beta')));

        // The application closes it itself once it knows
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.closePanel(panelId('beta'), window, acx)));
        assertTrue(area.placementOf(panelId('beta')) == null);

        // A handler that agrees lets the dock close
        area.setCloseHandler((_, _, _) -> true);
        cx.update((_, cx) -> group.update(cx, (group, gcx) -> group.closePanel(panelId('alpha'), gcx)));
        draw(cx);
        assertTrue(area.placementOf(panelId('alpha')) == null);
    }

/// KIT-053

    function testTheCentreKnowsWhichGroupHasTheFocus() {
        final cx = twoGroups((_, skin, _, cx) -> skin.setUnfocusedTabForeground(ACCENT, cx));
        final area:DockArea = built.area;
        final nodes = centerGroups();
        assertEquals(2, nodes.length);
        // Before anything is focused: the first group
        assertTrue(built.skin.focusedCenterGroup() == nodes[0]);
        assertEquals('alpha', built.skin.focusedCenterPanel(app).panelName(app));
        assertTrue(area.groupOf(panelId('gamma')) == nodes[1]);

        // The focus in a panel of the other group makes it the focused one
        cx.update((window, cx) -> built.panels.get('gamma').read(cx).focusHandle(cx).focus(window, cx));
        draw(cx);
        draw(cx);
        assertTrue(built.skin.focusedCenterGroup() == nodes[1]);
        assertEquals('gamma', built.skin.focusedCenterPanel(app).panelName(app));

        // And back, by the tab shown in the first group
        cx.update((window, cx) -> built.panels.get('alpha').read(cx).focusHandle(cx).focus(window, cx));
        draw(cx);
        draw(cx);
        assertTrue(built.skin.focusedCenterGroup() == nodes[0]);

        // Set by the application, without moving the keyboard focus
        cx.update((_, cx) -> built.skin.setFocusedCenterGroup(nodes[1], cx));
        draw(cx);
        draw(cx);
        assertTrue(built.skin.focusedCenterGroup() == nodes[1]);

        // A focused group that goes away gives its place to the first one left
        cx.update((window, cx) -> built.area.update(cx, (area, acx) -> area.closePanel(panelId('gamma'), window, acx)));
        draw(cx);
        assertEquals(1, centerGroups().length);
        assertTrue(built.skin.focusedCenterGroup() == centerGroups()[0]);
    }

/// KIT-054

    function testALonePanelOfTheCentreKeepsItsTab() {
        final one = (always:Bool) -> custom((area, skin, make, window, cx) -> {
            skin.setCenterTabsAlways(always, cx);
            area.update(cx, (area, acx) -> {
                area.setCenter(DockLayout.tabs().panelView(make('alpha'), cx), window, acx);
                area.setDock(DockPlacement.Left, DockLayout.tabs().panelView(make('side'), cx), window, acx);
            });
        });
        // By its title, as in the original
        var cx = one(false);
        assertEquals(0, DockDebugBounds.all(cx.window, TabGroupSkin.TAB_SELECTOR + '-0').length);
        // With a tab in the centre, and the lone panel of a dock still by its title
        DockDebugBounds.clear();
        cx = one(true);
        final tabs = DockDebugBounds.all(cx.window, TabGroupSkin.TAB_SELECTOR + '-0');
        assertEquals(1, tabs.length);
        final area:DockArea = built.area;
        assertTrue((tabs[0].origin.x : Float) >= (area.dockSize(DockPlacement.Left) : Float) - 1.);
    }

/// KIT-055

    /** The heights of the vertical lines drawn in the color of the borders, tallest first. */
    function tallLines(cx:VisualTestContext):Array<Float> {
        final border = cx.update((_, cx) -> Theme.global(cx).border);
        final heights = [for (entry in quadsFilled(cx, border)) if ((entry.bounds.size.width : Float) <= 1.5 && (entry.bounds.size.height : Float) > 300.) (entry.bounds.size.height : Float)];
        heights.sort((a, b) -> a > b ? -1 : (a < b ? 1 : 0));
        return heights;
    }

    function testTheLineBetweenTwoGroupsStartsUnderTheTabs() {
        // Over the whole height, as in the original
        var lines = tallLines(twoGroups((_, _, _, _) -> {}));
        assertEquals(1, lines.length);
        assertEquals(600., lines[0]);
        // 30 pixels lower once the skin is told the height of the strips
        lines = tallLines(twoGroups((_, skin, _, cx) -> skin.setDividerTopInset(30., cx)));
        assertEquals(1, lines.length);
        assertEquals(570., lines[0]);
    }

/// KIT-057

    function testTheActiveTabTakesTheGroundOfItsPanel() {
        final ground = ACCENT;
        // No panel tells a ground: none is drawn
        assertEquals(0, quadsFilled(dock((_, _) -> {}), ground).length);
        // The first panel tells one: its tab, the active one, takes it
        AdditionsPanel.ground = ground;
        final cx = dock((_, _) -> {});
        AdditionsPanel.ground = null;
        assertEquals(1, quadsFilled(cx, ground).length);
    }

/// KIT-039

    function testTheActiveTabOfADockHasItsAccent() {
        assertEquals(0, quadsFilled(dock((_, _) -> {}), ACCENT).length);
        // One line, on the active tab: 2 pixels by default
        var lines = quadsFilled(dock((skin, cx) -> skin.setActiveTabAccent(ACCENT, cx)), ACCENT);
        assertEquals(1, lines.length);
        assertEquals(2., (lines[0].bounds.size.height : Float));
        final first = lines[0].bounds;
        // A width of its own
        lines = quadsFilled(dock((skin, cx) -> skin.setActiveTabAccent(ACCENT, cx, 1.)), ACCENT);
        assertEquals(1, lines.length);
        assertEquals(1., (lines[0].bounds.size.height : Float));
        assertEquals((first.size.width : Float), (lines[0].bounds.size.width : Float));
        // Taken away again
        final cx = dock((skin, cx) -> {
            skin.setActiveTabAccent(ACCENT, cx);
            skin.setActiveTabAccent(null, cx);
        });
        assertEquals(0, quadsFilled(cx, ACCENT).length);
    }

/// KIT-047

    function testTheCloseButtonOfAnInactiveTabShowsOnHover() {
        final always = dock((_, _) -> {});
        final onHover = dock((skin, cx) -> skin.setCloseButtonOnHover(true, cx));
        // The buttons keep their room: the tabs do not move
        final shown = closeButtons(always);
        final kept = closeButtons(onHover);
        assertEquals(3, shown.length);
        assertEquals(3, kept.length);
        for (ix in 0...3) assertTrue(near(shown[ix], kept[ix]), 'button $ix');
        // Only the active tab draws its cross
        assertEquals(3, crosses(always));
        assertEquals(1, crosses(onHover));

        // The pointer over an inactive tab brings its cross back, and only that one
        onHover.simulateMouseMove(kept[1].center());
        draw(onHover);
        draw(onHover);
        assertEquals(2, crosses(onHover));
        // Away from the tabs: hidden again
        onHover.simulateMouseMove(new glaze.Point(450., 400.));
        draw(onHover);
        draw(onHover);
        assertEquals(1, crosses(onHover));
    }

}

private class AdditionsPanel extends PanelBase {

    final name:String;

    final focus:FocusHandle;

    function new(name:String, cx:Context<AdditionsPanel>) {
        super();
        this.name = name;
        focus = cx.focusHandle();
    }

    public static function create(name:String, cx:App):Entity<AdditionsPanel> {
        return cx.newEntity((pcx:Context<AdditionsPanel>) -> new AdditionsPanel(name, pcx));
    }

    public function panelName():String {
        return name;
    }

    /** The ground the panel named alpha tells, for the test of KIT-057. */
    public static var ground:Null<Hsla> = null;

    final ownGround:Null<Hsla> = ground;

    override public function titleStyle(cx:App):Null<glaze.kit.dock.TitleStyle> {
        return name == 'alpha' && ownGround != null ? new glaze.kit.dock.TitleStyle(ownGround, ownGround) : null;
    }

    override public function title(window:Window, cx:Context<Dynamic>):IntoElement {
        return name;
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().id(name).trackFocus(focus).sizeFull();
    }

}

private class AdditionsDock extends Model implements Render {

    final area:Entity<DockArea>;

    public function new(area:Entity<DockArea>) {
        super();
        this.area = area;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(area);
    }

}
