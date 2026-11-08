package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.GlazeInput;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.TextInputConfiguration.TextInputMode;
import glaze.TextInputBridge;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.MaskPattern;
import glaze.kit.input.Input;
import glaze.kit.input.NumberInput;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Initial port deviation DEV-017 (see docs/DEVIATIONS.md): a number field asks the
 * web virtual keyboard for the keypad suited to what it accepts, through the
 * `inputmode` the port gives Ceramic (`Input.setTextEditingConfiguration`).
 * `decimal` for a number field that cannot hold a negative value, `numeric`
 * when its mask also drops the fraction, `text` for a field that may hold a
 * negative value (iOS's numeric keypads have no minus sign) and for every
 * other input. Checked on the configuration of the field and on what reaches
 * Ceramic, when the field gets focus and when a tap on it opens the keyboard.
 */
@:access(glaze.kit.base.input.InputBaseState)
class NumberInputKeyboardTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    /** The arguments `TextInputBridge` gave Ceramic, in order: `inputMode` only. */
    final sent:Array<String> = [];

    var previousSend:Null<(String, Null<String>, String, Bool, Bool) -> Void> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        ceramic.App.app.flushImmediate();
        previousSend = TextInputBridge.sendConfiguration;
        TextInputBridge.sendConfiguration = (inputMode, _, _, _, _) -> sent.push(inputMode);
    }

    override function teardown() {
        TextInputBridge.sendConfiguration = previousSend;
        if (window != null) {
            GlazeInput.unbind(window);
            window.destroy();
        }
        window = null;
        ceramic.App.app.flushImmediate();
    }

    /** Opens the fields of `NumberFields` in a window bound to Ceramic's input, at scale 1. */
    function open():NumberFields {
        var view:Entity<NumberFields> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 400, height: 600, scaleFactor: 1, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((c:Context<NumberFields>) -> new NumberFields(window, c));
                return cx.newEntity((rootCx:Context<Root>) -> new Root(view, window, rootCx));
            });
        });
        GlazeInput.bind(window);
        draw();
        return view.read(app);
    }

    function draw():Void {
        dispatcher.runUntilParked();
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    function mode(state:Entity<InputState>):TextInputMode {
        return state.read(app).textInputConfiguration(null, null).inputMode;
    }

    function focus(state:Entity<InputState>):Void {
        app.update(cx -> (cast state : Entity<InputBaseState>).update(cx, (s, cx) -> s.focus(window, cx)));
        draw();
    }

    /** Ceramic's tap filter (what clay's web backend asks inside touchend) at the middle of the field. */
    function tap(state:Entity<InputState>):Bool {
        final bounds = state.read(app).inputBounds;
        final point = new ceramic.Point();
        window.renderable.visualToScreen(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2, point);
        final filter = ceramic.App.app.input.textEditingTapFilter;
        assertNotNull(filter);
        return filter(point.x, point.y);
    }

    function testNumberFieldThatMayHoldANegativeValueKeepsTheTextKeyboard() {
        final fields = open();
        assertEquals(TextInputMode.Text, mode(fields.signed), 'no min: a minus sign must stay typeable');
        assertEquals(TextInputMode.Text, mode(fields.negativeMin), 'a negative min: a minus sign must stay typeable');
    }

    function testNumberFieldWithoutNegativeValuesAsksForTheDecimalKeypad() {
        final fields = open();
        assertEquals(TextInputMode.Decimal, mode(fields.decimal));
        assertEquals(TextInputMode.Decimal, mode(fields.spaceGrouped), 'a space group separator keeps the comma a decimal separator (DEV-018)');
        // Without a group separator the mask leaves the text as typed, so a
        // fraction of 0 does not drop the decimals (gpui-kit `MaskPattern::mask`).
        assertEquals(TextInputMode.Decimal, mode(fields.ungroupedNoFraction));
    }

    function testIntegerNumberFieldAsksForTheNumericKeypad() {
        final fields = open();
        assertEquals(TextInputMode.Numeric, mode(fields.integer));
        assertEquals(TextInputMode.Numeric, mode(fields.dotInteger));
    }

    /**
     * A decimal field grouping digits with a comma or a dot: the comma of a
     * comma region's decimal keypad would be a group separator there (DEV-018
     * keeps its meaning), so the field keeps the text keyboard.
     */
    function testDecimalFieldGroupedWithACommaOrADotKeepsTheTextKeyboard() {
        final fields = open();
        assertEquals(TextInputMode.Text, mode(fields.commaGrouped));
        assertEquals(TextInputMode.Text, mode(fields.dotGrouped));
    }

    function testGroupedFieldsSendTheirInputModeToCeramic() {
        final fields = open();
        sent.resize(0);
        focus(fields.commaGrouped);
        assertEquals('text', sent[sent.length - 1]);
        focus(fields.spaceGrouped);
        assertEquals('decimal', sent[sent.length - 1]);
        focus(fields.dotGrouped);
        assertEquals('text', sent[sent.length - 1]);
        focus(fields.dotInteger);
        assertEquals('numeric', sent[sent.length - 1]);

        sent.resize(0);
        assertTrue(tap(fields.commaGrouped));
        assertTrue(tap(fields.spaceGrouped));
        assertTrue(tap(fields.dotGrouped));
        assertTrue(tap(fields.integer));
        assertEquals('text,decimal,text,numeric', sent.join(','));
    }

    function testOtherInputsKeepTheTextKeyboard() {
        final fields = open();
        assertEquals(TextInputMode.Text, mode(fields.plain));
        assertEquals(TextInputMode.Text, mode(fields.plainWithMin), 'a min without a number mask is not a number field');
    }

    function testFocusSendsTheFieldsInputModeToCeramic() {
        final fields = open();
        sent.resize(0);
        focus(fields.decimal);
        assertEquals('decimal', sent[sent.length - 1]);
        focus(fields.integer);
        assertEquals('numeric', sent[sent.length - 1]);
        focus(fields.signed);
        assertEquals('text', sent[sent.length - 1]);
        focus(fields.decimal);
        focus(fields.plain);
        assertEquals('text', sent[sent.length - 1]);
    }

    function testInputModeFollowsALaterMinChange() {
        final fields = open();
        focus(fields.signed);
        sent.resize(0);
        app.update(cx -> fields.signed.update(cx, (s, cx) -> {
            s.setMin(0., window, cast cx);
            cx.notify();
        }));
        draw();
        assertEquals('decimal', sent.join(','));
        app.update(cx -> fields.signed.update(cx, (s, cx) -> {
            s.setMin(null, window, cast cx);
            cx.notify();
        }));
        draw();
        assertEquals('decimal,text', sent.join(','));
    }

    function testTapGivesCeramicTheTappedFieldsInputModeBeforeTheKeyboardOpens() {
        final fields = open();
        sent.resize(0);
        assertTrue(tap(fields.integer), 'a tap on the field opens the keyboard');
        assertEquals('numeric', sent.join(','));
        assertTrue(tap(fields.decimal));
        assertEquals('numeric,decimal', sent.join(','));
        assertTrue(tap(fields.negativeMin));
        assertEquals('numeric,decimal,text', sent.join(','));
        assertTrue(tap(fields.plain));
        assertEquals('numeric,decimal,text,text', sent.join(','));
    }

}

/** Number inputs of each kind, and plain inputs, in a column. */
private class NumberFields extends Model implements Render {

    /** No min: may hold a negative value. */
    public final signed:Entity<InputState>;

    public final negativeMin:Entity<InputState>;

    /** min 0, default number mask. */
    public final decimal:Entity<InputState>;

    /** min 0, comma group separator and 2 fraction digits. */
    public final commaGrouped:Entity<InputState>;

    /** min 0, dot group separator, fraction kept. */
    public final dotGrouped:Entity<InputState>;

    /** min 0, space group separator, fraction kept. */
    public final spaceGrouped:Entity<InputState>;

    /** min 0, dot group separator and fraction 0: integers only. */
    public final dotInteger:Entity<InputState>;

    /** min 0, no group separator and fraction 0. */
    public final ungroupedNoFraction:Entity<InputState>;

    /** min 1, group separator and fraction 0: integers only. */
    public final integer:Entity<InputState>;

    public final plain:Entity<InputState>;

    public final plainWithMin:Entity<InputState>;

    public function new(window:Window, cx:Context<NumberFields>) {
        super();
        signed = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        negativeMin = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).min(-10.));
        decimal = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).min(0.));
        commaGrouped = cx.newEntity((c:Context<InputState>) -> masked(new InputState(window, c).min(0.), Number(','.code, 2)));
        dotGrouped = cx.newEntity((c:Context<InputState>) -> masked(new InputState(window, c).min(0.), Number('.'.code, null)));
        spaceGrouped = cx.newEntity((c:Context<InputState>) -> masked(new InputState(window, c).min(0.), Number(' '.code, null)));
        dotInteger = cx.newEntity((c:Context<InputState>) -> masked(new InputState(window, c).min(0.), Number('.'.code, 0)));
        ungroupedNoFraction = cx.newEntity((c:Context<InputState>) -> masked(new InputState(window, c).min(0.), Number(null, 0)));
        integer = cx.newEntity((c:Context<InputState>) -> masked(new InputState(window, c).min(1.), Number(','.code, 0)));
        plain = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        plainWithMin = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).min(0.));
    }

    static function masked(state:InputState, pattern:MaskPattern):InputState {
        state.withMaskPattern(pattern);
        return state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final column = div().flex().flexCol().gap(px(4.)).p(px(4.));
        for (state in [signed, negativeMin, decimal, commaGrouped, dotGrouped, spaceGrouped, dotInteger, ungroupedNoFraction, integer]) {
            column.child(div().w(px(200.)).h(px(36.)).child(NumberInput.component(state)));
        }
        for (state in [plain, plainWithMin]) {
            column.child(div().w(px(200.)).h(px(36.)).child(Input.component(state)));
        }
        return column;
    }

}
