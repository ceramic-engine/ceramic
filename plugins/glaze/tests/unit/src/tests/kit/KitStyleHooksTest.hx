// New code for Ceramic (not a port): the style hooks of the kit that are not
// in gpui-kit (Glaze additions used by Cityscape): `Input.placeholderColor`,
// `Scrollable.scrollbarStyles` and `PopupMenu.scrollbarStyles`.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.base.input.InputState;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.input.Input;
import glaze.kit.menu.PopupMenu;
import glaze.kit.theme.Theme;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.kit.scroll.Scrollable;

class KitStyleHooksTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):Void {
        app.update(cx -> {
            glaze.kit.Kit.init(cx);
            Theme.setScrollbarMode(ScrollbarMode.Always, cx);
            window = Window.open(cx, {width: 640, height: 480, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                final view = cx.newEntity((_:Context<HooksView>) -> new HooksView(render));
                return Root.component().child(view);
            });
        });
        draw();
        draw();
    }

    function draw():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    static function isRed(h:Float, s:Float, l:Float, a:Float):Bool {
        return a > 0.99 && Math.abs(s - 1) < 0.01 && Math.abs(l - 0.5) < 0.01 && (h < 0.01 || h > 0.99);
    }

    function redGlyphs():Int {
        var count = 0;
        for (sprite in window.renderedScene().monochromeSprites) {
            if (isRed(sprite.colorH, sprite.colorS, sprite.colorL, sprite.colorA)) {
                count++;
            }
        }
        return count;
    }

    function redQuads():Array<glaze.scene.Quad> {
        return [for (q in window.renderedScene().quads) if (isRed(q.backgroundSolidH, q.backgroundSolidS, q.backgroundSolidL, q.backgroundSolidA)) q];
    }

    function openInput(color:Null<Hsla>):Void {
        var state:Null<Entity<InputState>> = null;
        open((window, cx) -> {
            if (state == null) {
                state = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).withPlaceholder('Find'));
            }
            final input = Input.component(state).w(px(200));
            if (color != null) {
                input.placeholderColor(color);
            }
            return div().p4().child(input);
        });
    }

    /** The placeholder in `placeholderColor`, else in the theme's muted foreground. */
    function testInputPlaceholderColor() {
        openInput(red());
        assertEquals(4, redGlyphs());
        window.destroy();
        window = null;
        openInput(null);
        assertEquals(0, redGlyphs());
    }

    /** `Scrollable.scrollbarStyles`: the thumb of the scrollbar in the given look. */
    function testScrollableScrollbarStyles() {
        open((window, cx) -> {
            final content = div().flex().flexCol().h(px(200)).w(px(300));
            for (i in 0...50) {
                content.child(div().h(px(20)).child('Row ' + i));
            }
            return div().p4().child(content.overflowYScrollbar().id('hooks-scroll')
                .scrollbarStyles(s -> s.thumb(t -> t.bg(red()).width(10).inset(0).radius(0))));
        });
        final thumbs = redQuads();
        assertEquals(1, thumbs.length);
        assertEquals(20.0, thumbs[0].boundsWidth);
        assertEquals(0.0, thumbs[0].cornerRadiusTopLeft);
    }

    /** `PopupMenu.scrollbarStyles`: the scrollbar of a scrollable menu. */
    function testPopupMenuScrollbarStyles() {
        var menu:Null<Entity<PopupMenu>> = null;
        open((window, cx) -> {
            if (menu == null) {
                menu = PopupMenu.build(window, cx, (m, _, _) -> {
                    for (i in 0...40) {
                        m.label('Item ' + i);
                    }
                    return m.scrollable(true).scrollbarStyles(s -> s.thumb(t -> t.bg(red()).width(10).inset(0).radius(0))).maxH(px(160));
                });
            }
            return div().p4().child(menu);
        });
        final thumbs = redQuads();
        assertEquals(1, thumbs.length);
        assertEquals(20.0, thumbs[0].boundsWidth);
    }

}

private class HooksView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}
