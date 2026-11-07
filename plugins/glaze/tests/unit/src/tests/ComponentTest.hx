package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Glaze;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * `glaze.Component`: stateless components (rendered with their parent like a
 * `RenderOnce`) and persistent components (found by identity, props
 * assigned, destroyed when they leave the tree).
 */
class ComponentTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        Counters.reset();
        flushImmediate();
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        flushImmediate();
    }

    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    function openWindow(root:AnyView):Window {
        final window = Window.open(app, {width: 400, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: true}, (_, _) -> root);
        windows.push(window);
        return window;
    }

    function view(render:(Window, Context<Dynamic>) -> IntoElement):Entity<ParentView> {
        return app.newEntity((_:Context<ParentView>) -> new ParentView(render));
    }

    /** Draws the dirty windows, like the GlazeSystem does every frame. */
    function frame():Void {
        flushImmediate();
        for (window in windows) {
            window.drawIfDirty();
        }
    }

    function notify(entity:Model):Void {
        app.notify(entity.entityId);
    }

/// Stateless

    function testStatelessComponentIsBuiltAndRenderedWithItsParent() {
        final parent = view((_, _) -> div().id('root').child(Label.component().text('hello')));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.labelsBuilt);
        assertEquals(1, Counters.labelRenders);
        assertEquals('hello', Counters.lastLabelText);
        assertEquals(1, parent.read(app).renders);

        notify(parent);
        frame();
        assertEquals(2, Counters.labelsBuilt, 'a new instance at each render of the parent');
        assertEquals(2, Counters.labelRenders);

        // Nothing to draw: nothing renders
        frame();
        assertEquals(2, Counters.labelRenders);
    }

    function testStatelessPropsAreReadByTheirNameInTheClass() {
        final parent = view((_, _) -> div().child(Label.component().text('a').count(3)));
        openWindow(parent);
        frame();
        // `render` reads `text` and `count`, in code and in an interpolated string
        assertEquals('a', Counters.lastLabelText);
        assertEquals('a x3', Counters.lastLabelSummary);
        // The prop is stored as `textProp`
        final label = Label.component().text('b');
        assertEquals('b', label.textProp);
    }

    function testStatelessChildrenAreGivenToRender() {
        final parent = view((_, _) -> div().child(
            Row.component().label('name')
                .child(Label.component().text('first'))
                .child(null)
                .children([Label.component().text('second'), null])
        ));
        openWindow(parent);
        frame();
        assertEquals(2, Counters.rowChildren, 'null children are skipped');
        assertEquals(2, Counters.labelRenders);
    }

    function testStatelessAtKeyIsolatesElementStates() {
        // Two instances of the same component in a loop: with `.at(i)` their
        // element states are distinct, without it they would share one
        final parent = view((window, cx) -> div().children([for (i in 0...2) Stamp.component().at(i)]));
        openWindow(parent);
        frame();
        assertEquals('0,1', Counters.stamps.join(','), 'each instance got its own state');
        notify(parent);
        frame();
        assertEquals('0,1,0,1', Counters.stamps.join(','), 'the states are found again');

        final shared = view((window, cx) -> div().children([for (i in 0...2) Stamp.component()]));
        final window = openWindow(shared);
        Counters.stamps = [];
        frame();
        assertEquals('2,2', Counters.stamps.join(','), 'without a key the two instances share the state of their class');
    }

    function testStatelessHandWrittenSetterIsKept() {
        final label = Label.component().shout('hey');
        assertEquals('HEY', label.textProp, 'the class defines `shout`, which writes the prop');
        // A method with the name of a prop is not generated again
        final row = Row.component().label('x');
        assertEquals('x!', row.labelProp, 'the class defines its own `label` setter');
    }

    function testStatelessComponentAsRootView() {
        final window = openWindow(Label.component().text('root'));
        frame();
        assertEquals(1, Counters.labelRenders);
        assertEquals('root', Counters.lastLabelText);
        assertNotNull(window.rootView());
    }

/// Persistent

    function testPersistentComponentIsCreatedOnceAndReused() {
        final parent = view((_, _) -> div().child(Counter.component().label('a')));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.countersBuilt);
        assertEquals(1, Counters.counterInits);
        assertEquals(1, Counters.counterRenders);
        assertEquals(1, parent.read(app).renders);

        for (_ in 0...3) {
            notify(parent);
            frame();
        }
        assertEquals(4, parent.read(app).renders);
        assertEquals(1, Counters.countersBuilt, 'the instance is found again');
        assertEquals(1, Counters.counterInits);
        assertEquals(1, Counters.counterRenders, 'same props: the component does not render again');
        assertEquals(0, Counters.counterDestroys);
    }

    function testPersistentComponentIsDestroyedWhenItLeavesTheTree() {
        final toggle = app.newEntity(_ -> new Toggle());
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? Counter.component().label('a') : null));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.countersBuilt);
        assertEquals(0, Counters.counterDestroys);

        toggle.read(app).on = false;
        frame();
        assertEquals(1, Counters.counterDestroys, 'destroy() ran when the parent stopped rendering it');
        assertEquals(1, Counters.countersBuilt);

        toggle.read(app).on = true;
        frame();
        assertEquals(2, Counters.countersBuilt, 'a new instance when it comes back');
        assertEquals(2, Counters.counterInits);
        assertEquals(1, Counters.counterDestroys);
    }

    function testPersistentComponentIsDestroyedWithTheWindow() {
        final parent = view((_, _) -> div().child(Counter.component().label('a')));
        final window = openWindow(parent);
        frame();
        assertEquals(1, Counters.countersBuilt);
        window.destroy();
        windows.remove(window);
        flushImmediate();
        assertEquals(1, Counters.counterDestroys);
    }

    function testPersistentIdentityByKeyInALoop() {
        final list = app.newEntity(_ -> new Items(['a', 'b', 'c']));
        final parent = view((_, cx) -> div().children([for (item in list.read(cx).items) Counter.component().at(item).label(item)]));
        openWindow(parent);
        frame();
        assertEquals(3, Counters.countersBuilt);
        assertEquals('a,b,c', [for (c in Counters.liveCounters) c.labelProp].join(','));

        // Each instance keeps its own state
        Counters.liveCounters[1].clicks = 5;
        frame();
        assertEquals(1, Counters.counterRenders - 3, 'only the changed component rendered again');

        // Removing the middle item destroys its component only
        list.read(app).items = ['a', 'c'];
        frame();
        assertEquals(1, Counters.counterDestroys);
        assertEquals(3, Counters.countersBuilt);
        assertEquals('a,c', [for (c in Counters.liveCounters) c.labelProp].join(','));

        // Two components of a loop at the same position without a key share one identity
        final collided = view((_, cx) -> div().children([for (item in ['x', 'y']) Counter.component().label(item)]));
        Counters.reset();
        openWindow(collided);
        frame();
        assertEquals(1, Counters.countersBuilt, 'one instance for the two calls');
    }

    function testDataPropChangeRendersTheComponent() {
        final model = app.newEntity(_ -> new Items(['a']));
        final parent = view((_, cx) -> div().child(Counter.component().label(model.read(cx).items[0])));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.counterRenders);
        assertEquals('a', Counters.lastCounterLabel);

        // Same value: the parent renders, the component does not
        model.read(app).items = ['a'];
        frame();
        assertEquals(2, parent.read(app).renders);
        assertEquals(1, Counters.counterRenders);

        // New value: the component renders in the same frame, with the new value
        model.read(app).items = ['b'];
        frame();
        assertEquals(3, parent.read(app).renders);
        assertEquals(2, Counters.counterRenders);
        assertEquals('b', Counters.lastCounterLabel);

        // Nothing changed: nothing renders (no pending dirty view left behind)
        frame();
        assertEquals(3, parent.read(app).renders);
        assertEquals(2, Counters.counterRenders);
    }

    function testFunctionPropIsNotObservableButStaysUpToDate() {
        final calls:Array<String> = [];
        final model = app.newEntity(_ -> new Items(['v1']));
        final parent = view((_, cx) -> {
            final version = model.read(cx).items[0];
            return div().child(Counter.component().label('a').onClick(n -> calls.push('$version:$n')));
        });
        openWindow(parent);
        frame();
        final counter = Counters.liveCounters[0];
        counter.fire(1);
        assertEquals('v1:1', calls.join(','));

        model.read(app).items = ['v2'];
        frame();
        assertEquals(2, parent.read(app).renders);
        assertEquals(1, Counters.counterRenders, 'a new closure does not render the component again');
        counter.fire(2);
        assertEquals('v1:1,v2:2', calls.join(','), 'the component holds the latest closure');
    }

    function testUnobservedDataProp() {
        final model = app.newEntity(_ -> new Items(['a']));
        final parent = view((_, cx) -> div().child(Counter.component().label('a').hint(model.read(cx).items[0])));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.counterRenders);
        model.read(app).items = ['b'];
        frame();
        assertEquals(1, Counters.counterRenders, '@prop(unobserved): a new value does not render the component');
        assertEquals('b', Counters.liveCounters[0].hintProp, 'but it is assigned');
    }

    function testPropNotSetKeepsItsValue() {
        final toggle = app.newEntity(_ -> new Toggle());
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? Counter.component().label('a').hint('h') : Counter.component().label('a')));
        openWindow(parent);
        frame();
        assertEquals('h', Counters.liveCounters[0].hintProp);
        toggle.read(app).on = false;
        frame();
        assertEquals('h', Counters.liveCounters[0].hintProp, 'a prop the parent did not set keeps its value');
        assertEquals(1, Counters.countersBuilt, 'the same identity (one line) is one instance');
    }

    function testChildrenRenderThePersistentComponentAgain() {
        final model = app.newEntity(_ -> new Items(['a']));
        final parent = view((_, cx) -> div().child(Box.component().child(Label.component().text(model.read(cx).items[0]))));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.boxRenders);
        assertEquals('a', Counters.lastLabelText);

        model.read(app).items = ['b'];
        frame();
        assertEquals(2, Counters.boxRenders, 'new children: the component renders again');
        assertEquals('b', Counters.lastLabelText);

        notify(parent);
        frame();
        assertEquals(3, Counters.boxRenders, 'children are new elements at each parent render');
    }

    function testInternalObservableRendersTheComponentNotItsSiblings() {
        final parent = view((_, _) -> div().child(Counter.component().label('a')).child(Box.component().child(Label.component().text('sibling'))));
        final window = openWindow(parent);
        frame();
        assertEquals(1, parent.read(app).renders);
        assertEquals(1, Counters.counterRenders);
        assertEquals(1, Counters.boxRenders);

        Counters.liveCounters[0].clicks = 1;
        frame();
        // Like any view of the port, a dirty view renders with its ancestors
        // (the parent gives it its props again) but not its siblings
        assertEquals(2, parent.read(app).renders);
        assertEquals(2, Counters.counterRenders);
        assertEquals(1, Counters.lastCounterClicks);
        assertEquals(2, Counters.boxRenders, 'the sibling was given new children by the parent');
        assertEquals(3, window.renderedViewCount, 'the parent and the two components rendered');

        Counters.liveCounters[0].clicks = 1;
        frame();
        assertEquals(2, Counters.counterRenders, 'same value: no render');
    }

    function testObservablePropIsReadByTheComponentItself() {
        // An autorun of the component reads a prop: it runs again when the
        // parent changes the prop, not when it passes the same value
        final model = app.newEntity(_ -> new Items(['a']));
        final parent = view((_, cx) -> div().child(Counter.component().label(model.read(cx).items[0])));
        openWindow(parent);
        frame();
        assertEquals('a', Counters.labelsSeen.join(','));
        model.read(app).items = ['a'];
        frame();
        assertEquals('a', Counters.labelsSeen.join(','));
        model.read(app).items = ['b'];
        frame();
        flushImmediate();
        assertEquals('a,b', Counters.labelsSeen.join(','));
    }

    function testAutorunLivesWithTheComponent() {
        final toggle = app.newEntity(_ -> new Toggle());
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? Counter.component().label('a') : null));
        openWindow(parent);
        frame();
        final counter = Counters.liveCounters[0];
        assertEquals(1, Counters.autorunRuns, 'the autorun ran once, at creation');
        counter.clicks = 2;
        flushImmediate();
        assertEquals(2, Counters.autorunRuns, 'and again when what it reads changes');

        toggle.read(app).on = false;
        frame();
        assertEquals(1, Counters.counterDestroys);
        counter.clicks = 3;
        flushImmediate();
        assertEquals(2, Counters.autorunRuns, 'destroyed with the component');
    }

    function testComputeField() {
        final parent = view((_, _) -> div().child(Counter.component().label('ab')));
        openWindow(parent);
        frame();
        final counter = Counters.liveCounters[0];
        assertEquals(2, counter.labelLength);
        assertEquals('ab:2', Counters.lastCounterSummary);
        counter.clicks = 1;
        frame();
        assertEquals(2, counter.labelLength);
    }

    function testPersistMetaMakesAPropsOnlyComponentPersistent() {
        final parent = view((_, _) -> div().child(Box.component()));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.boxesBuilt);
        assertEquals(1, Counters.boxRenders);
        notify(parent);
        frame();
        assertEquals(1, Counters.boxesBuilt, 'created once');
        assertEquals(1, Counters.boxRenders, 'not rendered again without a change');
    }

    function testConstructorArgumentsBecomeThoseOfComponent() {
        final parent = view((_, _) -> div().child(Titled.component('T', 2).text('x')));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.titledBuilt);
        assertEquals('T2:x', Counters.lastTitled);
        notify(parent);
        frame();
        assertEquals(1, Counters.titledBuilt, 'the constructor runs once');
    }

    function testDifferentComponentClassesAtTheSamePosition() {
        final toggle = app.newEntity(_ -> new Toggle());
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? (Counter.component().label('a') : IntoElement) : Box.component()));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.countersBuilt);
        toggle.read(app).on = false;
        frame();
        assertEquals(1, Counters.counterDestroys, 'the first component left the tree');
        assertEquals(1, Counters.boxesBuilt);
    }

    function testPersistentComponentAsRootView() {
        final window = openWindow(Counter.component().label('root'));
        frame();
        assertEquals(1, Counters.countersBuilt);
        assertEquals(1, Counters.counterInits);
        assertEquals('root', Counters.lastCounterLabel);
        Counters.liveCounters[0].clicks = 2;
        frame();
        assertEquals(2, Counters.counterRenders);
        window.destroy();
        windows.remove(window);
        flushImmediate();
        assertEquals(1, Counters.counterDestroys, 'destroyed with the window');
    }

    function testPersistentComponentInsideAStatelessOne() {
        final toggle = app.newEntity(_ -> new Toggle());
        final parent = view((_, cx) -> div().child(toggle.read(cx).on ? Row.component().label('r').child(Counter.component().label('in')) : null));
        openWindow(parent);
        frame();
        assertEquals(1, Counters.countersBuilt);
        notify(parent);
        frame();
        assertEquals(1, Counters.countersBuilt, 'found again through the stateless parent');
        toggle.read(app).on = false;
        frame();
        assertEquals(1, Counters.counterDestroys);
    }

/// Short listeners

    function testShortListenersOnElements() {
        final log:Array<String> = [];
        final window = openWindow(Clickable.component().log(log));
        frame();
        // The component focused its root in init(): draw the focus state
        frame();
        final position = point(10, 10);
        window.dispatchEvent(new MouseMoveEvent(position, null, window.modifiers()), app);
        window.dispatchEvent(new MouseDownEvent(Left, position), app);
        window.dispatchEvent(new MouseUpEvent(Left, position), app);
        window.dispatchEvent(new KeyDownEvent(Keystroke.parse('escape')), app);
        assertEquals('hover:true,down,click,full,escape', log.slice(0, 5).join(','));
    }

    function testGlazeAppIsTheCurrentApp() {
        assertTrue(Glaze.app == app);
        assertTrue(Glaze.app == App.current);
    }

}

/**
 * Counters shared by the components of the tests.
 */
class Counters {

    public static var labelsBuilt:Int = 0;
    public static var labelRenders:Int = 0;
    public static var lastLabelText:String = null;
    public static var lastLabelSummary:String = null;
    public static var rowChildren:Int = 0;
    public static var stamps:Array<Int> = [];
    public static var nextStamp:Int = 0;

    public static var countersBuilt:Int = 0;
    public static var counterInits:Int = 0;
    public static var counterRenders:Int = 0;
    public static var counterDestroys:Int = 0;
    public static var lastCounterLabel:String = null;
    public static var lastCounterClicks:Int = -1;
    public static var lastCounterSummary:String = null;
    public static var liveCounters:Array<Counter> = [];
    public static var labelsSeen:Array<String> = [];
    public static var autorunRuns:Int = 0;

    public static var boxesBuilt:Int = 0;
    public static var boxRenders:Int = 0;

    public static var titledBuilt:Int = 0;
    public static var lastTitled:String = null;

    public static function reset():Void {
        labelsBuilt = 0;
        labelRenders = 0;
        lastLabelText = null;
        lastLabelSummary = null;
        rowChildren = 0;
        stamps = [];
        nextStamp = 0;
        countersBuilt = 0;
        counterInits = 0;
        counterRenders = 0;
        counterDestroys = 0;
        lastCounterLabel = null;
        lastCounterClicks = -1;
        lastCounterSummary = null;
        liveCounters = [];
        labelsSeen = [];
        autorunRuns = 0;
        boxesBuilt = 0;
        boxRenders = 0;
        titledBuilt = 0;
        lastTitled = null;
    }

}

/**
 * A view rendering through a function, counting its renders.
 */
class ParentView extends Model implements Render {

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

class Toggle extends Model {

    @observe public var on:Bool = true;

    public function new() {
        super();
    }

}

class Items extends Model {

    @observe public var items:Array<String>;

    public function new(items:Array<String>) {
        super();
        this.items = items;
    }

}

/**
 * A stateless component: props only.
 */
class Label extends Component {

    @prop public var text:String = '';

    @prop var count:Int = 0;

    public function new() {
        super();
        Counters.labelsBuilt++;
    }

    /** A hand written setter writing a prop */
    public function shout(text:String):Label {
        this.text = text.toUpperCase();
        return this;
    }

    function render(window:Window, cx:App):IntoElement {
        Counters.labelRenders++;
        Counters.lastLabelText = text;
        Counters.lastLabelSummary = '$text x$count';
        return div().id('label').child(text);
    }

}

/**
 * A stateless component with children and a hand written setter named like
 * its prop.
 */
class Row extends Component {

    @prop public var label:String = '';

    public function label(label:String):Row {
        this.label = label + '!';
        return this;
    }

    function render(window:Window, cx:App):IntoElement {
        Counters.rowChildren = children != null ? children.length : 0;
        return div().id('row').flex().child(div().child(label)).child(div().children(children));
    }

}

/**
 * A stateless component with an element state (keyed by its own position):
 * the state records which instance created it.
 */
class Stamp extends Component {

    function render(window:Window, cx:App):IntoElement {
        final state = window.useState(cx, _ -> Counters.nextStamp++);
        Counters.stamps.push(state.read(cx).value);
        return div().id('stamp').w(px(10)).h(px(10));
    }

}

/**
 * A persistent component: an observable, an autorun, a compute, init and destroy.
 */
class Counter extends Component {

    @prop public var label:String = '';

    @prop var onClick:(count:Int) -> Void = null;

    @prop(unobserved) public var hint:String = null;

    @observe public var clicks:Int = 0;

    @compute public function labelLength():Int {
        return label.length;
    }

    public function new() {
        super();
        Counters.countersBuilt++;
    }

    override function init(window:Window, cx:App) {
        Counters.counterInits++;
        Counters.liveCounters.push(this);
    }

    override function destroy() {
        Counters.counterDestroys++;
        Counters.liveCounters.remove(this);
    }

    @autorun function watch() {
        final clicks = this.clicks;
        final label = this.label;
        tracker.Autorun.unobserve();
        Counters.autorunRuns++;
        if (Counters.labelsSeen.length == 0 || Counters.labelsSeen[Counters.labelsSeen.length - 1] != label) {
            Counters.labelsSeen.push(label);
        }
        tracker.Autorun.reobserve();
    }

    public function fire(count:Int):Void {
        if (onClick != null) onClick(count);
    }

    function render(window:Window, cx:App):IntoElement {
        Counters.counterRenders++;
        Counters.lastCounterLabel = label;
        Counters.lastCounterClicks = clicks;
        Counters.lastCounterSummary = '$label:$labelLength';
        return div().id('counter').child('$label $clicks');
    }

}

/**
 * A props only component made persistent by `@persist`, with children.
 */
@persist
class Box extends Component {

    public function new() {
        super();
        Counters.boxesBuilt++;
    }

    function render(window:Window, cx:App):IntoElement {
        Counters.boxRenders++;
        return div().id('box').children(children);
    }

}

/**
 * A component using the three forms of the element listeners: `() -> Void`,
 * `event -> Void` and `(event, window, cx) -> Void`.
 */
class Clickable extends Component {

    @prop var log:Array<String> = null;

    final focus:FocusHandle;

    public function new() {
        super();
        focus = Glaze.app.focusHandle();
    }

    override function init(window:Window, cx:App) {
        window.focus(focus, cx);
    }

    function render(window:Window, cx:App):IntoElement {
        return div().id('clickable').w(px(100)).h(px(100))
            .trackFocus(focus)
            .onHover(hovered -> log.push('hover:$hovered'))
            .onMouseDown(Left, () -> log.push('down'))
            .onClick(e -> log.push(e != null ? 'click' : 'no event'))
            .onClick((e, window, cx) -> log.push(window != null && cx != null ? 'full' : 'no context'))
            .onKeyDown(e -> if (e.keystroke.key == 'escape') log.push('escape'));
    }

}

/**
 * A persistent component with constructor arguments.
 */
class Titled extends Component {

    final title:String;

    final level:Int;

    @prop var text:String = '';

    public function new(title:String, level:Int) {
        super();
        this.title = title;
        this.level = level;
        Counters.titledBuilt++;
    }

    override function init(window:Window, cx:App) {}

    function render(window:Window, cx:App):IntoElement {
        Counters.lastTitled = '$title$level:$text';
        return div().child(title);
    }

}
