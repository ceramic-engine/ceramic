package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.Component;
import glaze.kit.WindowState;
import glaze.kit.base.Root;
import glaze.kit.button.Button;
import glaze.kit.button.ButtonGroup;
import glaze.kit.button.Toggle;
import glaze.kit.button.Toggle.ToggleGroup;
import glaze.kit.radio.Radio;
import glaze.kit.radio.Radio.RadioGroup;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.switch_.Switch;
import glaze.kit.base.Slider.SliderState;
import glaze.kit.base.Slider.SliderValue;
import glaze.kit.base.input.InputState;
import glaze.kit.input.Input;
import glaze.kit.select.Select;
import glaze.kit.select.SelectState;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.slider.Slider;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * `Input.component()`, `Select.component()` and `Slider.component()`: with
 * a state they are `new X(state)`; without, the state is created under the
 * identity of the call (position or `.at(key)`), kept while rendered,
 * destroyed when the component leaves the tree; `.value(v)` pushes only a
 * different value, `.onChange(f)` keeps the latest handler.
 */
class StatefulComponentTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(build:(Window, Context<Dynamic>) -> IntoElement):{view:Entity<Harness>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            final content = rootCx.newEntity((c:Context<Harness>) -> new Harness(build));
            return new Root(content, window, rootCx);
        }, 640, 480);
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        final root:Root = opened.view;
        return {view: cast root.contentView(), cx: opened.cx};
    }

    function redraw(cx:VisualTestContext, view:Entity<Harness>) {
        view.update(app, (_, c) -> c.notify());
        cx.runUntilParked();
    }

    // MARK: Input

    function testInputComponentWithAStateIsTheInputOfThatState() {
        final h = open((window, cx) -> {
            final state = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            final input = Input.component(state);
            assertTrue(input.state.equals(state));
            return input;
        });
        assertTrue(h.view != null);
    }

    function testInputComponentCreatesAndKeepsItsState() {
        var rendered:Null<Input> = null;
        final ids:Array<Int> = [];
        final h = open((window, cx) -> {
            rendered = Input.component().value('hello');
            return rendered;
        });
        assertTrue(rendered.state != null, 'the state exists after the first render');
        assertEquals('hello', rendered.state.read(app).value());
        ids.push(rendered.state.entityId());

        redraw(h.cx, h.view);
        ids.push(rendered.state.entityId());
        assertEquals(ids[0], ids[1], 'the same state across renders');
    }

    function testInputValueIsPushedOnlyWhenItDiffers() {
        var model = 'first';
        var rendered:Null<Input> = null;
        final changes:Array<String> = [];
        final h = open((window, cx) -> {
            rendered = Input.component().value(model).onChange(v -> {
                changes.push(v);
                model = v;
            });
            return rendered;
        });
        final state = rendered.state;
        assertEquals('first', state.read(app).value());

        // The user types: the model follows through onChange, the parent
        // renders the same value again, nothing is pushed
        h.cx.update((window, cx) -> state.read(cx).focusHandle.focus(window, cx));
        h.cx.simulateKeystrokes('x');
        assertEquals('firstx', state.read(app).value());
        assertEquals('firstx', changes.join(','));
        redraw(h.cx, h.view);
        assertEquals('firstx', state.read(app).value(), 'an unchanged .value() does not reset the typing');

        // The parent gives another value: it is pushed
        model = 'second';
        redraw(h.cx, h.view);
        assertEquals('second', state.read(app).value());
    }

    function testInputValueIsControlledByTheParent() {
        var rendered:Null<Input> = null;
        final h = open((window, cx) -> {
            // The parent ignores the changes: its value wins at its next render
            rendered = Input.component().value('fixed');
            return rendered;
        });
        final state = rendered.state;
        h.cx.update((window, cx) -> state.read(cx).focusHandle.focus(window, cx));
        h.cx.simulateKeystrokes('x');
        redraw(h.cx, h.view);
        assertEquals('fixed', state.read(app).value());
    }

    function testInputChangeHandlerOfTheLatestRenderIsCalled() {
        var generation = 0;
        final calls:Array<String> = [];
        var rendered:Null<Input> = null;
        final h = open((window, cx) -> {
            final g = generation;
            rendered = Input.component().onChange(v -> calls.push('$g:$v'));
            return rendered;
        });
        final state = rendered.state;
        generation = 1;
        redraw(h.cx, h.view);
        h.cx.update((window, cx) -> state.read(cx).focusHandle.focus(window, cx));
        h.cx.simulateKeystrokes('a');
        assertEquals('1:a', calls.join(','), 'the handler of the latest render, called once');
    }

    function testInputStateIsDestroyedWhenTheInputLeavesTheTree() {
        var shown = true;
        var rendered:Null<Input> = null;
        final h = open((window, cx) -> {
            rendered = shown ? Input.component() : null;
            return div().child(rendered);
        });
        final state = rendered.state;
        assertFalse(state.intoAny().destroyed);
        shown = false;
        redraw(h.cx, h.view);
        // The element state is dropped on the frame after the one it is missing from
        redraw(h.cx, h.view);
        assertTrue(state.intoAny().destroyed, 'the state is destroyed with the component');
    }

    function testInputsInALoopAreToldApartByAt() {
        final inputs:Array<Input> = [];
        final h = open((window, cx) -> {
            inputs.resize(0);
            return div().children([for (i in 0...3) {
                final input = Input.component().at('field-$i').value('v$i');
                inputs.push(input);
                input;
            }]);
        });
        assertEquals(3, inputs.length);
        assertTrue(inputs[0].state.entityId() != inputs[1].state.entityId());
        assertEquals('v2', inputs[2].state.read(app).value());
    }

    // MARK: Select

    function testSelectComponentWithAStateIsTheSelectOfThatState() {
        final h = open((window, cx) -> {
            final state = cx.newEntity((c:Context<SelectState<String>>) -> new SelectState<String>(new SearchableVec(['a', 'b']), null, window, c));
            final select = Select.component(state);
            assertTrue(select.state.equals(state));
            return select;
        });
        assertTrue(h.view != null);
    }

    function testSelectComponentCreatesItsStateOverItsOptions() {
        var value = 'Go';
        var rendered:Null<Select<String>> = null;
        final confirmed:Array<String> = [];
        final h = open((window, cx) -> {
            rendered = Select.component().options(['Rust', 'Go', 'Haxe']).value(value).onChange(v -> confirmed.push(v));
            return rendered;
        });
        final state = rendered.state;
        assertEquals('Go', (state.read(app).selectedValue() : String));
        final id = state.entityId();

        redraw(h.cx, h.view);
        assertEquals(id, rendered.state.entityId(), 'the same state across renders');

        value = 'Haxe';
        redraw(h.cx, h.view);
        assertEquals('Haxe', (state.read(app).selectedValue() : String));
    }

    function testSelectOptionsReplaceTheItemsWhenTheyDiffer() {
        var items = ['a', 'b'];
        var rendered:Null<Select<String>> = null;
        final h = open((window, cx) -> {
            rendered = Select.component().options(items).value('c');
            return rendered;
        });
        final state = rendered.state;
        assertTrue(state.read(app).selectedValue() == null, 'the value is not among the items yet');
        // Same items, a new array: nothing is replaced
        items = ['a', 'b'];
        redraw(h.cx, h.view);
        assertTrue(state.read(app).selectedValue() == null);
        // New items: they replace the previous ones, and the value is found
        items = ['a', 'b', 'c'];
        redraw(h.cx, h.view);
        assertEquals('c', (state.read(app).selectedValue() : String));
    }

    function testSelectValueDoesNotFreezeTheViewRenderingIt() {
        // The first render pushes the value into the state: the write must
        // not unbind the parent view from the model it reads
        final probe = new Probe();
        final h = open((window, cx) -> {
            final tick = probe.tick;
            return div().child('$tick').child(Select.component().options(['Rust', 'Go']).value('Go'));
        });
        final before = h.view.read(app).renders;
        probe.tick++;
        ceramic.App.app.flushImmediate();
        h.cx.runUntilParked();
        h.cx.update((window, _) -> window.drawIfDirty());
        assertTrue(h.view.read(app).renders > before, 'the view reacts to the model after the first render');
    }

    function testInputAndSliderValuesDoNotFreezeTheViewRenderingThem() {
        final probe = new Probe();
        final h = open((window, cx) -> {
            final tick = probe.tick;
            return div().child('$tick')
                .child(Input.component().value('text').placeholder('hint'))
                .child(Slider.component().min(0).max(10).value(5));
        });
        final before = h.view.read(app).renders;
        probe.tick++;
        ceramic.App.app.flushImmediate();
        h.cx.runUntilParked();
        h.cx.update((window, _) -> window.drawIfDirty());
        assertTrue(h.view.read(app).renders > before, 'the view reacts to the model after the first render');
    }

    function testInputPlaceholderIsPushedToTheState() {
        var hint = 'Search';
        var rendered:Null<Input> = null;
        final h = open((window, cx) -> {
            rendered = Input.component().placeholder(hint);
            return rendered;
        });
        final base:Entity<glaze.kit.base.input.InputBaseState> = (rendered.state : InputState);
        assertEquals('Search', base.read(app).placeholder);
        hint = 'Find';
        redraw(h.cx, h.view);
        assertEquals('Find', base.read(app).placeholder);
        // also on an input given its state
        final state = app.newEntity((c:Context<InputState>) -> new InputState(h.cx.window, c));
        final given = Input.component(state).placeholder('Given');
        final opened = open((window, cx) -> given);
        final givenBase:Entity<glaze.kit.base.input.InputBaseState> = (state : InputState);
        assertEquals('Given', givenBase.read(app).placeholder);
    }

    function testRootBuilderBuildsTheRootOfAWindow() {
        final build = Root.builder(Content.component().title('hello'));
        var window:Window = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 320, height: 240, scaleFactor: 2, autoDraw: false, bindInput: false}, build);
        });
        app.update(_ -> window.draw());
        dispatcher.runUntilParked();
        final root = Root.tryRead(window);
        assertTrue(root != null, 'the window root is a Root');
        assertTrue(root.contentView() != null);
        assertTrue(WindowState.tryRead(window) != null, 'the kit initialized with the root');
        window.destroy();
    }

    function testShortCallbacksOnKitControls() {
        final log:Array<String> = [];
        final button = Button.component('save').onClick(() -> log.push('click'));
        final buttonEvent = Button.component('save2').onClick(e -> log.push(e == null ? 'event:null' : 'event'));
        final buttonFull = Button.component('save3').onClick((e, window, cx) -> log.push('full'));
        final sw = Switch.component('wifi').onChange(on -> log.push('switch:$on'));
        final swVoid = Switch.component('wifi2').onClick(() -> log.push('switch'));
        final checkbox = Checkbox.component('remember').onChange(v -> log.push('check:$v'));
        final checkboxFull = Checkbox.component('remember2').onChange((v, window, cx) -> log.push('checkfull:$v'));
        @:privateAccess button.onClickHandler(null, null, null);
        @:privateAccess buttonEvent.onClickHandler(null, null, null);
        @:privateAccess buttonFull.onClickHandler(null, null, null);
        @:privateAccess sw.onClickHandler(true, null, null);
        @:privateAccess swVoid.onClickHandler(false, null, null);
        @:privateAccess checkbox.onClickHandler(true, null, null);
        @:privateAccess checkboxFull.onClickHandler(false, null, null);
        assertEquals('click,event:null,full,switch:true,switch,check:true,checkfull:false', log.join(','));

        log.resize(0);
        final radio = Radio.component('a').onChange(v -> log.push('radio:$v'));
        final radioVoid = Radio.component('b').onClick(() -> log.push('radio'));
        final radioGroup = RadioGroup.component('g').onChange(i -> log.push('group:$i'));
        final radioGroupFull = RadioGroup.component('g2').onClick((i, window, cx) -> log.push('groupfull:$i'));
        final toggle = Toggle.component('t').onClick(on -> log.push('toggle:$on'));
        final toggleGroup = ToggleGroup.component('tg').onClick(states -> log.push('toggles:' + states.join('')));
        final buttonGroup = ButtonGroup.component('bg').onClick(indices -> log.push('buttons:' + indices.join('')));
        final buttonGroupVoid = ButtonGroup.component('bg2').onClick(() -> log.push('buttons'));
        @:privateAccess radio.onClickHandler(true, null, null);
        @:privateAccess radioVoid.onClickHandler(true, null, null);
        @:privateAccess radioGroup.onClickHandler(2, null, null);
        @:privateAccess radioGroupFull.onClickHandler(3, null, null);
        @:privateAccess toggle.onClickHandler(false, null, null);
        @:privateAccess toggleGroup.onClickHandler([true, false], null, null);
        @:privateAccess buttonGroup.onClickHandler([0, 2], null, null);
        @:privateAccess buttonGroupVoid.onClickHandler([1], null, null);
        assertEquals('radio:true,radio,group:2,groupfull:3,toggle:false,toggles:truefalse,buttons:02,buttons', log.join(','));
    }

    // MARK: Slider

    function testSliderComponentWithAStateIsTheSliderOfThatState() {
        final h = open((window, cx) -> {
            final state = cx.newEntity((_:Context<SliderState>) -> new SliderState());
            final slider = Slider.component(state);
            assertTrue(slider.state.equals(state));
            return slider;
        });
        assertTrue(h.view != null);
    }

    function testSliderComponentCreatesAndConfiguresItsState() {
        var value = 14.;
        var rendered:Null<Slider> = null;
        final h = open((window, cx) -> {
            rendered = Slider.component().min(10).max(28).step(1).value(value).onChange(v -> value = v);
            return rendered;
        });
        final state = rendered.state;
        assertEquals(10., state.read(app).minValue());
        assertEquals(28., state.read(app).maxValue());
        assertEquals(1., state.read(app).stepValue());
        assertTrue(Type.enumEq(SliderValue.Single(14.), state.read(app).value()));
        final id = state.entityId();

        value = 20.;
        redraw(h.cx, h.view);
        assertEquals(id, rendered.state.entityId());
        assertTrue(Type.enumEq(SliderValue.Single(20.), state.read(app).value()));
    }

}

private class Harness extends Model implements Render {

    public var renders:Int = 0;

    final build:(Window, Context<Dynamic>) -> IntoElement;

    public function new(build:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.build = build;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders++;
        return div().size(px(400.)).child(build(window, cx));
    }

}

private class Probe extends Model {

    @observe public var tick:Int = 0;

    public function new() {
        super();
    }

}

private class Content extends Component {

    @prop var title:String = 'content';

    function render(window:Window, cx:App):IntoElement {
        return div().id('content').child(title);
    }

}
