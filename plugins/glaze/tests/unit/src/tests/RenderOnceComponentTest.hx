package tests;

import glaze.App;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.label.Label;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The static `component(...)` generated on every `RenderOnce` class with a
 * public constructor (`RenderOnceMacro`): same parameters as the
 * constructor, type parameters kept, nothing generated on a class that
 * defines `component` itself or has no public constructor.
 */
class RenderOnceComponentTest extends TestCase {

    function testComponentTakesTheConstructorParameters() {
        final plain = Plain.component('name', 4);
        assertTrue(Std.isOfType(plain, Plain));
        assertEquals('name', plain.name);
        assertEquals(4, plain.count);
        // Optional parameters keep their default value
        assertEquals(2, Plain.component('other').count);
    }

    function testComponentKeepsTypeParameters() {
        final box = Box.component([1, 2, 3]);
        assertEquals(3, box.value.length);
        final typed:Box<Array<Int>> = box;
        assertEquals(2, typed.value[1]);
    }

    function testComponentIsNotGeneratedTwice() {
        // The class defines its own `component`: the macro leaves it alone
        assertEquals('custom', OwnComponent.component().origin);
    }

    function testSubclassWithoutConstructorInheritsNothing() {
        // No public constructor of its own: no `component` of its own, the
        // one of the parent class is used through the parent
        final sub:Plain = new Sub('sub');
        assertEquals('sub', sub.name);
    }

    function testKitComponentsHaveComponent() {
        final button = Button.component('save').label('Save');
        assertTrue(Std.isOfType(button, Button));
        final label = Label.component('Name');
        assertTrue(Std.isOfType(label, Label));
    }

}

private class Plain implements RenderOnce {

    public final name:String;

    public final count:Int;

    public function new(name:String, count:Int = 2) {
        this.name = name;
        this.count = count;
    }

    public function render(window:Window, cx:App):IntoElement {
        return div().child(name);
    }

}

private class Sub extends Plain {}

private class Box<T> implements RenderOnce {

    public final value:T;

    public function new(value:T) {
        this.value = value;
    }

    public function render(window:Window, cx:App):IntoElement {
        return div();
    }

}

private class OwnComponent implements RenderOnce {

    public final origin:String;

    public function new(origin:String) {
        this.origin = origin;
    }

    public static function component():OwnComponent {
        return new OwnComponent('custom');
    }

    public function render(window:Window, cx:App):IntoElement {
        return div();
    }

}
