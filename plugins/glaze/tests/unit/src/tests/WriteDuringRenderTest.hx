package tests;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.ViewTracker;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * A view whose render writes an observable value it read earlier in the
 * same render: tracker unbinds the view from everything it read before the
 * write, so the view must render again on the next frame (and that frame
 * must happen), otherwise it reacts to nothing until something else draws
 * the window.
 */
class WriteDuringRenderTest extends TestCase {

    var app:App;

    var window:Null<Window> = null;

    var warnings:Int = 0;

    var previousOnWrite:Null<(ViewTracker) -> Void> = null;

    override function setup() {
        app = new App(new TestDispatcher());
        previousOnWrite = ViewTracker.onWriteDuringCapture;
        ViewTracker.onWriteDuringCapture = _ -> warnings++;
        warnings = 0;
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        ViewTracker.onWriteDuringCapture = previousOnWrite;
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    function open(view:Entity<WritingView>):Void {
        window = Window.open(app, {width: 200, height: 200, scaleFactor: 2, autoDraw: false, bindInput: false}, (_, _) -> view);
        app.update(_ -> window.draw());
        ceramic.App.app.flushImmediate();
    }

    function frame():Bool {
        ceramic.App.app.flushImmediate();
        return app.update(_ -> window.drawIfDirty());
    }

    function testAViewWritingWhatItReadRendersAgainOnTheNextFrame() {
        final probe = new Probe();
        final view:Entity<WritingView> = app.newEntity((_:Context<WritingView>) -> new WritingView(probe));
        open(view);
        assertEquals(1, view.read(app).renders);
        assertTrue(probe.flag, 'the render wrote the value');
        #if debug
        assertEquals(1, warnings, 'the write during render is reported');
        #end

        // The write unbound the view: the next frame is scheduled and renders it again
        assertTrue(window.dirty, 'a frame is scheduled after the write');
        assertTrue(frame());
        assertEquals(2, view.read(app).renders);
        assertFalse(frame(), 'the second render wrote nothing: no third frame');
        assertEquals(2, view.read(app).renders);

        // and the view reacts to its observables again
        probe.tick++;
        assertTrue(frame(), 'the view is dirty after a change of a value it read');
        assertEquals(3, view.read(app).renders);
    }

    function testAViewWritingWhatItPaintedFromIsNotRedrawnForever() {
        // The existing behaviour of a write during prepaint or paint (the
        // resizable panels report their bounds on every prepaint): the view
        // is marked for the next frame but no frame is scheduled
        final probe = new Probe();
        final view:Entity<WritingView> = app.newEntity((_:Context<WritingView>) -> new WritingView(probe, true));
        open(view);
        assertEquals(1, view.read(app).renders);
        assertFalse(window.dirty, 'no frame is scheduled by a write during paint');
    }

}

private class Probe extends Model {

    @observe public var flag:Bool = false;

    @observe public var tick:Int = 0;

    public function new() {
        super();
    }

}

private class WritingView extends Model implements Render {

    public var renders:Int = 0;

    final probe:Probe;

    final writeInPaint:Bool;

    public function new(probe:Probe, writeInPaint:Bool = false) {
        super();
        this.probe = probe;
        this.writeInPaint = writeInPaint;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders++;
        final tick = probe.tick;
        final flag = probe.flag;
        if (writeInPaint) {
            return new PaintWriter(probe).intoAnyElement();
        }
        if (!flag) {
            // Converges: the second render reads `true` and writes nothing
            probe.flag = true;
        }
        return div().size(px(10.)).child('$tick $flag');
    }

}

private class PaintWriter extends glaze.Element {

    final probe:Probe;

    final child:glaze.AnyElement;

    public function new(probe:Probe) {
        this.probe = probe;
        this.child = div().size(px(10.)).intoAnyElement();
    }

    public function requestLayout(id:Null<glaze.GlobalElementId>, window:Window, cx:App):glaze.LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<glaze.GlobalElementId>, bounds:glaze.Bounds, window:Window, cx:App):Void {
        child.prepaint(window, cx);
    }

    public function paint(id:Null<glaze.GlobalElementId>, bounds:glaze.Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
        probe.tick = probe.tick + 1;
    }

}
