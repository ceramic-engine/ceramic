// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Context;
import glaze.Entity;
import glaze.MouseButton;
import glaze.Point;
import glaze.kit.base.ColorPicker.ColorPickerState;
import glaze.kit.base.input.InputState;
import glaze.kit.colorpicker.ColorPicker.ColorSelect;
import glaze.kit.input.NumberInput;
import glaze.kit.input.NumberInput.NumberScrub;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The field additions without upstream equivalent: a number input without
 * its buttons and with a prefix to drag (KIT-035), a color field without
 * its caret or its border (KIT-045).
 */
class KitInputAdditionsTest extends KitAdditionsTestCase {

    function sprites(cx:VisualTestContext):Int {
        return cx.update((window, _) -> window.renderedScene().monochromeSprites.length);
    }

/// Number input

    /** A number input 200 wide at (20, 20), holding 10, with an X before the value. */
    function numberWindow(configure:(NumberInput) -> NumberInput):VisualTestContext {
        var state:Null<Entity<InputState>> = null;
        return open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).defaultValue('10'));
            return div().p(px(20.)).w(px(240.)).child(probe('field', configure(NumberInput.component(state).prefix(probe('lead', div().child('X'))))));
        }, 800, 600, true);
    }

    function testWithoutStepButtonsTheFieldHasNoButton() {
        // The two buttons are an icon each
        final with = sprites(numberWindow(input -> input));
        final without = sprites(numberWindow(input -> input.stepButtons(false)));
        assertEquals(2, with - without);
        // The field keeps its size
        final a = boundsOf(numberWindow(input -> input), 'field');
        final b = boundsOf(numberWindow(input -> input.stepButtons(false)), 'field');
        assertTrue(near(a, b), '$a $b');
    }

    function testAPrefixWithoutOnScrubIsNotAHandle() {
        final cx = numberWindow(input -> input.stepButtons(false));
        final lead = boundsOf(cx, 'lead').center();
        cx.simulateMouseDown(lead, MouseButton.Left);
        cx.simulateMouseMove(new Point(lead.x + 30., lead.y), MouseButton.Left);
        draw(cx);
        assertFalse(cx.update((_, app) -> app.hasActiveDrag()));
        cx.simulateMouseUp(new Point(lead.x + 30., lead.y), MouseButton.Left);
        draw(cx);
    }

    function testDraggingThePrefixTellsTheDistance() {
        final told:Array<String> = [];
        final moved:Array<Float> = [];
        final cx = numberWindow(input -> input.stepButtons(false).onScrub((phase, _, _) -> switch phase {
            case Started: told.push('started');
            case Moved(distance):
                told.push('moved');
                moved.push(distance);
            case Ended: told.push('ended');
        }));
        final lead = boundsOf(cx, 'lead').center();
        final at = (dx:Float) -> new Point((lead.x : Float) + dx, lead.y);
        cx.simulateMouseMove(lead);
        cx.simulateMouseDown(lead, MouseButton.Left);
        draw(cx);
        assertEquals(0, told.length, 'a press alone tells nothing');
        for (dx in [8., 20., 50., 35.]) {
            cx.simulateMouseMove(at(dx), MouseButton.Left);
            draw(cx);
        }
        assertEquals('started', told[0]);
        assertEquals('moved', told[told.length - 1]);
        // The distance is counted from where the drag started, to the right and back
        final last = moved.length - 1;
        assertEquals(30., moved[last - 1] - moved[last - 2]);
        assertEquals(-15., moved[last] - moved[last - 1]);
        cx.simulateMouseUp(at(35.), MouseButton.Left);
        draw(cx);
        assertEquals('ended', told[told.length - 1]);
        assertEquals(1, [for (word in told) if (word == 'started') word].length);
        assertEquals(1, [for (word in told) if (word == 'ended') word].length);
    }

/// Color field

    static final ORANGE = hsla(0.08, 0.9, 0.55, 1.);

    function colorWindow(configure:(ColorSelect) -> ColorSelect):VisualTestContext {
        var state:Null<Entity<ColorPickerState>> = null;
        return open((window, cx) -> {
            if (state == null) state = cx.newEntity((c:Context<ColorPickerState>) -> new ColorPickerState(window, c).defaultValue(ORANGE));
            return div().p(px(20.)).w(px(240.)).child(probe('field', configure(ColorSelect.component(state))));
        }, 800, 600, true);
    }

    /** The squares filled with the color of the field. */
    function swatches(cx:VisualTestContext):Array<Float> {
        return [for (entry in quadsFilled(cx, ORANGE)) if (Math.abs(entry.bounds.size.width - entry.bounds.size.height) < 0.5) (entry.bounds.size.width : Float)];
    }

    function testAColorFieldWithoutItsCaret() {
        // The caret is one icon
        assertEquals(1, sprites(colorWindow(field -> field)) - sprites(colorWindow(field -> field.caret(false))));
    }

    function testASwatchOfAGivenSize() {
        final given = swatches(colorWindow(field -> field.swatchSize(px(14.))));
        assertEquals(1, given.length);
        final regular = swatches(colorWindow(field -> field));
        assertEquals(1, regular.length);
        // The fill is drawn inside the border of the swatch: 16 pixels without the option, 14 with it
        assertEquals(2., regular[0] - given[0]);
        assertTrue(Math.abs(given[0] - 14.) <= 1., '${given[0]}');
    }

    function testWithoutItsBorderTheFieldKeepsItsSize() {
        final plain = colorWindow(field -> field);
        final bare = colorWindow(field -> field.bordered(false));
        assertTrue(near(boundsOf(plain, 'field'), boundsOf(bare, 'field')));
        // Only the color of the border changes
        assertTrue(sceneSignature(plain) != sceneSignature(bare));
        assertEquals(quads(plain).length, quads(bare).length);
    }

}
