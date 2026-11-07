// New code for the Haxe port of GPUI (no GPUI origin). See NOTICE.md.
package gpui.util;

/**
 * A shared mutable value, standing for Rust's `Rc<RefCell<T>>` / `Rc<Cell<T>>`
 * when a value is shared between an element state and the listeners it
 * registers.
 */
class Ref<T> {

    public var value:T;

    public function new(value:T) {
        this.value = value;
    }

}
