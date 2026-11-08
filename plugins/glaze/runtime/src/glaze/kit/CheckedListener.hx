// New code for the Haxe port of gpui-kit (no gpui-kit origin). See NOTICE.md.
package glaze.kit;

/**
 * The handler of the checked value requested by a `Checkbox`, a `Switch`, a
 * `Radio` or a `Toggle`: `(checked, window, cx) -> ...`, also written
 * `checked -> ...` or `() -> ...` (`ValueListener`).
 */
typedef CheckedListener = ValueListener<Bool>;
