package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseMoveEvent;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The debug check of the view cache (define `glaze_verify_cache`, on in this
 * suite): a view that would be reused renders for real and is compared with
 * its cached rendering. Also the fix it found: a notify of a model renders
 * the views cached by default that read it, like GPUI's uncached views.
 */
class CacheVerificationTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    final messages:Array<String> = [];

    var savedHandler:Null<(String) -> Void> = null;

    var savedFailures:Int = 0;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        VerifyProbe.reset();
        flushImmediate();
        // Collect the messages here: the runner fails a test that leaves one
        messages.resize(0);
        savedHandler = Window.onCacheVerificationFailure;
        savedFailures = Window.cacheVerificationFailures;
        Window.onCacheVerificationFailure = message -> messages.push(message);
        #if glaze_verify_cache
        Window.verifyCache = true;
        #end
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        flushImmediate();
        Window.onCacheVerificationFailure = savedHandler;
        Window.cacheVerificationFailures = savedFailures;
    }

    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    function openWindow(root:AnyView):Window {
        final window = Window.open(app, {width: 400, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: true}, (_, _) -> root);
        windows.push(window);
        return window;
    }

    function view(render:(Window, Context<Dynamic>) -> IntoElement):Entity<VerifyView> {
        return app.newEntity((_:Context<VerifyView>) -> new VerifyView(render));
    }

    /** Draws the dirty windows, like the GlazeSystem does every frame. */
    function frame():Void {
        flushImmediate();
        for (window in windows) {
            window.drawIfDirty();
        }
    }

/// The check

    function testTheCheckIsOnInThisSuite() {
        #if glaze_verify_cache
        assertEquals(0, Window.cacheVerificationFailures, 'no difference so far in the suite');
        #else
        assertTrue(false, 'the unit suite is built with glaze_verify_cache');
        #end
    }

    #if glaze_verify_cache

    function testAPlainFieldChangedWithoutNotifyIsReported() {
        final other = new VerifyToggle();
        final root = view((_, _) -> div()
            .child(PlainLabel.component().at('label'))
            .child(div().child(other.on ? 'on' : 'off'))
        );
        openWindow(root);
        frame();
        final label = VerifyProbe.label;
        assertEquals(1, label.renders);

        // A plain field, then a frame caused by something else
        label.text = 'changed';
        other.on = false;
        frame();
        assertEquals(1, messages.length, 'the stale cached rendering is reported');
        final message = messages.length > 0 ? messages[0] : '';
        assertTrue(message.indexOf('tests.PlainLabel') == 0, message);
        assertTrue(message.indexOf('notify() probably missing') != -1, message);
        assertTrue(message.indexOf('(element ') != -1, 'with its element id path: $message');
        // The real rendering is the one drawn
        assertEquals('changed', label.shown);

        // Nothing changed since: nothing to report
        other.on = true;
        frame();
        assertEquals(1, messages.length);
    }

    function testTheSameChangeWithNotifyIsNotReported() {
        final other = new VerifyToggle();
        final root = view((_, _) -> div()
            .child(PlainLabel.component().at('label'))
            .child(div().child(other.on ? 'on' : 'off'))
        );
        openWindow(root);
        frame();
        final label = VerifyProbe.label;
        label.text = 'changed';
        label.notify();
        other.on = false;
        frame();
        assertEquals(0, messages.length, messages.join('\n'));
        assertEquals('changed', label.shown);
    }

    function testAStatelessComponentReadingAPlainValueIsReported() {
        final other = new VerifyToggle();
        final inner = view((_, _) -> div().child(PlainStatelessLabel.component()));
        final root = view((_, _) -> div().child(inner).child(div().child(other.on ? 'on' : 'off')));
        openWindow(root);
        frame();
        VerifyProbe.plain = 'changed';
        other.on = false;
        frame();
        assertEquals(1, messages.length);
        final message = messages.length > 0 ? messages[0] : '';
        assertTrue(message.indexOf('tests.VerifyView') == 0, 'the view the component renders in: $message');

        messages.resize(0);
        VerifyProbe.plain = 'again';
        VerifyProbe.statelessLabel.notify();
        other.on = true;
        frame();
        assertEquals(0, messages.length, messages.join('\n'));
    }

    function testAHoverChangeWithoutMouseEventIsNotReported() {
        // A hover style on a cached view, then a sibling drawn over the mouse:
        // the hover of the cached view changes without any event (GPUI keeps
        // the cached hover until a mouse move notifies the view)
        final cover = new VerifyToggle();
        cover.on = false;
        final hovered = view((_, _) -> div().id('hovered').w(px(100)).h(px(100)).bg(hsla(0, 0, 0.5, 1)).hover(s -> s.bg(hsla(0.3, 0.8, 0.5, 1))));
        final root = view((_, _) -> div().relative().w(px(200)).h(px(200))
            .child(hovered)
            .child(cover.on ? div().id('cover').absolute().top(px(0)).left(px(0)).w(px(50)).h(px(50)).occlude() : null)
        );
        final window = openWindow(root);
        frame();
        window.dispatchEvent(new MouseMoveEvent(point(20, 20), null, window.modifiers()), app);
        frame();
        cover.on = true;
        frame();
        assertEquals(0, messages.length, messages.join('\n'));
    }

    function testAViewCachedWithAStyleIsCheckedToo() {
        final other = new VerifyToggle();
        final source = new PlainSource();
        final cachedView = view((_, _) -> div().child(source.text));
        final root = view((_, _) -> div()
            .child(cachedView.cached(glaze.StyleBuilder.build(s -> s.w(px(100)).h(px(40)))))
            .child(div().child(other.on ? 'on' : 'off'))
        );
        openWindow(root);
        frame();
        source.text = 'changed';
        other.on = false;
        frame();
        assertEquals(1, messages.length, 'a view cached with a style shows a stale rendering');
    }

    #end

/// A notify of a model renders the views that read it

    function testANotifiedModelRendersTheViewsThatReadIt() {
        countsRenders();
        final model = app.newEntity((_:Context<PlainModel>) -> new PlainModel());
        var lastText = '';
        final reader = view((_, cx) -> {
            lastText = model.read(cx).text;
            return div().child(lastText);
        });
        final bystander = view((_, _) -> div().child('bystander'));
        final root = view((_, _) -> div().child(reader).child(bystander));
        openWindow(root);
        frame();
        assertEquals(1, reader.read(app).renders);
        assertEquals(1, bystander.read(app).renders);

        model.update(app, (m, cx) -> {
            m.text = 'changed';
            cx.notify();
        });
        frame();
        assertEquals(2, reader.read(app).renders, 'the view that read the model renders again');
        assertEquals('changed', lastText);
        assertEquals(1, bystander.read(app).renders, 'a view that did not read it stays cached');
    }

    function testAModelNotifiedWhileDrawingRendersItsReadersInTheNextFrame() {
        countsRenders();
        // Like the kit's diff: a canvas records a painted size in a model
        // and notifies it while the window draws (no frame is scheduled, like
        // GPUI); the next frame, whatever causes it, shows the new value.
        final model = app.newEntity((_:Context<PlainModel>) -> new PlainModel());
        final other = new VerifyToggle();
        var lastText = '';
        final reader = view((_, cx) -> div().w(px(200)).h(px(50))
            .child(div().child(lastText = model.read(cx).text))
            .child(canvas((bounds, _, cx) -> {
                model.update(cx, (m, mcx) -> {
                    final text = 'width ${bounds.size.width}';
                    if (m.text != text) {
                        m.text = text;
                        mcx.notify();
                    }
                });
                return null;
            }, (_, _, _, _) -> {}).absolute().sizeFull())
        );
        final root = view((_, _) -> div().child(reader).child(div().child(other.on ? 'on' : 'off')));
        final window = openWindow(root);
        frame();
        assertFalse(window.dirty, 'a notify while drawing schedules no frame');
        assertEquals(1, reader.read(app).renders);
        other.on = false;
        frame();
        assertEquals(2, reader.read(app).renders, 'the next frame renders the reader');
        assertEquals('width 200', lastText);
        other.on = true;
        frame();
        assertEquals(2, reader.read(app).renders, 'then it stays cached');
    }

    function testAViewCachedWithAStyleKeepsGpuiRule() {
        countsRenders();
        final model = app.newEntity((_:Context<PlainModel>) -> new PlainModel());
        final reader = view((_, cx) -> div().child(model.read(cx).text));
        final root = view((_, _) -> div().child(reader.cached(glaze.StyleBuilder.build(s -> s.w(px(100)).h(px(40))))));
        openWindow(root);
        frame();
        model.update(app, (m, cx) -> {
            m.text = 'changed';
            cx.notify();
        });
        frame();
        assertEquals(1, reader.read(app).renders, 'GPUI: a view cached with a style renders only when notified itself');
    }

}

class VerifyProbe {

    public static var label:Null<PlainLabel> = null;

    public static var statelessLabel:Null<PlainStatelessLabel> = null;

    /** Read by `PlainStatelessLabel`, not observable */
    public static var plain:String = '';

    public static function reset():Void {
        label = null;
        statelessLabel = null;
        plain = '';
    }

}

class VerifyView extends Model implements Render {

    public var renders:Int = 0;

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders++;
        return renderFn(window, cx);
    }

}

class VerifyToggle extends Model {

    @observe public var on:Bool = true;

    public function new() {
        super();
    }

}

/**
 * A model with a plain field, announced by `cx.notify()` (GPUI's way).
 */
class PlainModel extends Model {

    public var text:String = 'initial';

    public function new() {
        super();
    }

}

/**
 * A source of text outside of tracker.
 */
class PlainSource {

    public var text:String = 'initial';

    public function new() {}

}

/**
 * A persistent component showing a plain field.
 */
@persist
class PlainLabel extends Component {

    public var text:String = 'initial';

    public var renders:Int = 0;

    public var shown:String = '';

    override function init(window:Window, cx:App) {
        VerifyProbe.label = this;
    }

    function render(window:Window, cx:App):IntoElement {
        renders++;
        shown = text;
        return div().child(text);
    }

}

/**
 * A stateless component showing a plain static value.
 */
class PlainStatelessLabel extends Component {

    function render(window:Window, cx:App):IntoElement {
        VerifyProbe.statelessLabel = this;
        return div().child(VerifyProbe.plain);
    }

}
