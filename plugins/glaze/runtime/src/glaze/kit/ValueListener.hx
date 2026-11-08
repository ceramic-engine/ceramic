// New code for the Haxe port of gpui-kit (no gpui-kit origin): short forms of
// the value handlers of the kit's controls (gpui-kit 0.8.1,
// crates/component/src/checkbox.rs, switch.rs, radio.rs, button/toggle.rs
// `on_click`). See NOTICE.md.
package glaze.kit;

import glaze.App;
import glaze.Window;

/**
 * The handler of a value requested by a control: the checked state of a
 * `Checkbox`, a `Switch`, a `Radio` or a `Toggle`, the selected index of a
 * `RadioGroup`, the states of a `ToggleGroup`, the indices of a `ButtonGroup`.
 */
typedef ValueHandler<T> = (value:T, window:Window, cx:App) -> Void;

/**
 * A `ValueHandler<T>`, also written `() -> Void` or `value -> ...` (the
 * short forms of `glaze.Listeners`): `Switch.component('wifi').onChange(on -> prefs.wifi = on)`.
 * The full form `(value, window, cx) -> ...` is unchanged.
 */
@:callable
abstract ValueListener<T>(ValueHandler<T>) from ValueHandler<T> to ValueHandler<T> {

    inline function new(f:ValueHandler<T>) this = f;

    @:from static inline function fromVoid<T>(f:() -> Void):ValueListener<T> {
        final g:ValueHandler<T> = (_, _, _) -> f();
        return new ValueListener<T>(g);
    }

    @:from static inline function fromValue<T>(f:(value:T) -> Void):ValueListener<T> {
        final g:ValueHandler<T> = (value, _, _) -> f(value);
        return new ValueListener<T>(g);
    }

}
