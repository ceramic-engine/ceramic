// New code for the Haxe port of GPUI: stands for Rust's `Drop` on element
// state values (gpui-pre 0.3.10, src/window.rs element states, Zed Industries,
// Apache-2.0). See NOTICE.md.
package gpui;

/**
 * A value kept in an element state (`withElementState`, `useKeyedState`)
 * that holds entities Rust would drop with it.
 *
 * Rust drops an element state that was not accessed during a frame, and
 * every strong `Entity` handle it holds with it, which releases the entities
 * whose last handle it was. The port releases entities explicitly: such a
 * value implements `drop()` to destroy what it owns, and the window calls it
 * when the state is dropped (not accessed in a frame, or window closed).
 */
interface Droppable {

    function drop():Void;

}
