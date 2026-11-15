package tests;

import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.select.Select;
import glaze.kit.select.SelectState;
import testing.TestCase;

import glaze.Prelude.*;

/** Shows a view that makes entities when it is made itself, when asked. */
class MadeWhileDrawnHolder extends Component {

    public static var current:MadeWhileDrawnHolder = null;

    /** 0: nothing, 1: the picker with a kit select, 2: the reader of a shared entity */
    @observe public var shown:Int = 0;

    override public function init(window:Window, cx:App):Void {
        current = this;
    }

    function render(window:Window, cx:App):IntoElement {
        final column = div().flex().flexCol().gap2().p4().child('holder');
        if (shown == 1) column.child(MadeWhileDrawnPicker.component());
        if (shown == 2) column.child(MadeWhileDrawnReader.component());
        return column.child(MadeWhileDrawnCounter.component());
    }

}

/**
 * A view that makes the state of a kit `Select` when it is made itself,
 * which happens while the view that holds it is drawn.
 */
class MadeWhileDrawnPicker extends Component {

    public static var current:MadeWhileDrawnPicker = null;

    @observe public var tick:Int = 0;

    public var state:Entity<SelectState<String>> = null;

    override public function init(window:Window, cx:App):Void {
        current = this;
        state = cx.newEntity((c:Context<SelectState<String>>) ->
            new SelectState<String>(new SearchableVec<String>(['one', 'two']), null, window, c));
    }

    function render(window:Window, cx:App):IntoElement {
        return div().w(px(160)).child('tick ' + tick).child(Select.component(state));
    }

}

/** A plain entity shared by the test, read by `MadeWhileDrawnReader` when it is made. */
class MadeWhileDrawnShared extends Model {

    public var value:Int = 7;

    public function new() {
        super();
    }

}

/**
 * A view that reads an entity that exists already when it is made itself
 * (so while its holder is drawn), and never while it renders.
 */
class MadeWhileDrawnReader extends Component {

    public static var current:MadeWhileDrawnReader = null;

    public static var shared:Entity<MadeWhileDrawnShared> = null;

    @observe public var tick:Int = 0;

    var initial:Int = 0;

    override public function init(window:Window, cx:App):Void {
        current = this;
        initial = shared.read(cx).value;
    }

    function render(window:Window, cx:App):IntoElement {
        return div().w(px(160)).child('reader ' + initial + ' tick ' + tick);
    }

}

/** A view of its own, drawn again alone (in place) when its count changes. */
class MadeWhileDrawnCounter extends Component {

    public static var current:MadeWhileDrawnCounter = null;

    @observe public var count:Int = 0;

    override public function init(window:Window, cx:App):Void {
        current = this;
    }

    function render(window:Window, cx:App):IntoElement {
        return div().child('count ' + count);
    }

}

/**
 * An entity made (or read) while a view is drawn counts as accessed by that
 * view, as in GPUI (`EntityMap::insert`, `read` and `lease` all add to
 * `accessed_entities`, app/entity_map.rs, and a cached view keeps the set
 * its last render recorded, view.rs `extend_accessed`). A component is made
 * while the view that holds it is drawn, so what its `init` makes or reads
 * is in the accessed set of that holder until the holder renders again.
 *
 * The check of the frames drawn in place (`glaze_verify_cache`) renders
 * every view for real in its full frame, where the holder no longer touches
 * these entities: that is not a difference of the frame drawn in place.
 */
class EntitiesMadeWhileDrawnTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    var messages:Array<String> = [];

    var savedHandler:Null<(String) -> Void> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
        app.update(cx -> glaze.kit.Kit.init(cx));
        MadeWhileDrawnReader.shared = app.newEntity((_:Context<MadeWhileDrawnShared>) -> new MadeWhileDrawnShared());
        messages = [];
        savedHandler = Window.onCacheVerificationFailure;
        final previous = savedHandler;
        Window.onCacheVerificationFailure = message -> {
            messages.push(message);
            if (previous != null) previous(message);
        };
        window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, active: false, bindInput: false},
            (window, cx) -> Root.component().child(MadeWhileDrawnHolder.component()));
        settle();
    }

    override function teardown() {
        window.destroy();
        ceramic.App.app.flushImmediate();
        Window.onCacheVerificationFailure = savedHandler;
        MadeWhileDrawnReader.shared = null;
        MadeWhileDrawnHolder.current = null;
        MadeWhileDrawnPicker.current = null;
        MadeWhileDrawnReader.current = null;
        MadeWhileDrawnCounter.current = null;
    }

    function settle():Void {
        for (_ in 0...10) {
            dispatcher.runUntilParked();
            ceramic.App.app.flushImmediate();
            app.update(_ -> window.draw());
            if (!window.dirty) break;
        }
    }

    inline function tracked(entityId:Int):Bool {
        return @:privateAccess window.liveEntities.contains(entityId);
    }

    /** The reproduction of the Writer's translation picker (wg-wire report, section 8). */
    function testASelectStateMadeInInitThenFramesInPlace() {
        final failures = Window.inPlaceVerificationFailures;
        final frames = Window.inPlaceFramesDrawn;

        // The select state is made while the holder is drawn
        MadeWhileDrawnHolder.current.shown = 1;
        settle();
        final stateId = MadeWhileDrawnPicker.current.state.entityId();
        assertTrue(tracked(stateId), 'the entity made while the holder was drawn is tracked by the window');

        // The view of the select is drawn alone, then another one: the
        // holder is reused from its cache
        MadeWhileDrawnPicker.current.tick++;
        settle();
        MadeWhileDrawnCounter.current.count++;
        settle();

        assertTrue(Window.inPlaceFramesDrawn > frames, 'frames were drawn in place');
        assertEquals(0, Window.inPlaceVerificationFailures - failures, 'frames drawn in place that differ from a full frame: ' + messages.join(' | '));
    }

    /** The same with a read: `init` reads an entity that no render reads. */
    function testAnEntityReadInInitThenFramesInPlace() {
        final failures = Window.inPlaceVerificationFailures;
        final frames = Window.inPlaceFramesDrawn;
        final sharedId = MadeWhileDrawnReader.shared.entityId();
        assertFalse(tracked(sharedId), 'nothing drawn reads the shared entity yet');

        MadeWhileDrawnHolder.current.shown = 2;
        settle();
        assertTrue(tracked(sharedId), 'the entity read while the holder was drawn is tracked by the window');

        MadeWhileDrawnReader.current.tick++;
        settle();
        MadeWhileDrawnCounter.current.count++;
        settle();

        assertTrue(Window.inPlaceFramesDrawn > frames, 'frames were drawn in place');
        assertEquals(0, Window.inPlaceVerificationFailures - failures, 'frames drawn in place that differ from a full frame: ' + messages.join(' | '));
    }

    /** The holder renders again: it no longer touches what the component made, and nothing is reported. */
    function testTheHolderRenderingAgainIsNotADifference() {
        final failures = Window.cacheVerificationFailures;

        MadeWhileDrawnHolder.current.shown = 1;
        settle();
        MadeWhileDrawnPicker.current.tick++;
        settle();
        // Same value shown, the holder renders for real
        MadeWhileDrawnHolder.current.notify();
        settle();
        MadeWhileDrawnCounter.current.count++;
        settle();
        MadeWhileDrawnPicker.current.tick++;
        settle();

        assertEquals(0, Window.cacheVerificationFailures - failures, 'differences reported: ' + messages.join(' | '));
    }

}
