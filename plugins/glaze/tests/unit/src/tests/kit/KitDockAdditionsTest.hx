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
 * tab (KIT-039), the close button of a tab on hover (KIT-047).
 */
@:access(glaze.kit.dock.TabGroupSkin)
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
