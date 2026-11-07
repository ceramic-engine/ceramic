// Ported from gpui-pre 0.3.10: src/action.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Actions are used to implement keyboard-driven UI. When you declare an
 * action, you can bind keys to the action in the keymap and listeners for that
 * action in the element tree.
 *
 * Any class implementing `Action` goes through `glaze.ActionMacro.build()`
 * (Rust: `#[derive(Action)]`), which generates every method the class does not
 * define itself:
 *
 * - `name()` and the static `nameForType()`: `namespace::ClassName`;
 * - `boxedClone()` (Rust `boxed_clone`) and `partialEq()`, comparing the
 *   class (exact type, like `downcast_ref`) and every instance field;
 * - a constructor taking every instance field, when there is none;
 * - the static `build(value:Dynamic):Action`, building the action from a JSON
 *   value (parsed with `haxe.Json.parse`): unit actions ignore it, actions with
 *   fields read them by snake_case name (`replaceNewest` reads
 *   `replace_newest`, override with `@:json("name")` on the field);
 * - `deprecatedAliases()`, `deprecationMessage()`, `documentation()` (from
 *   the class doc comment);
 * - the registration of the action, so that `App.buildAction(name, json)`
 *   can build it by name (Rust: `inventory`).
 *
 * The equivalent of `actions!(editor, [MoveUp, MoveDown])` is:
 *
 * ```haxe
 * @:action(namespace = editor) class MoveUp implements Action {}
 * @:action(namespace = editor) class MoveDown implements Action {}
 * ```
 *
 * Several actions can share one module (e.g. `EditorActions.hx`), imported
 * with `import editor.EditorActions;`.
 *
 * `@:action(...)` takes the arguments of Rust's `#[action(...)]`: `namespace`,
 * `name = "Name"`, `noJson`, `noRegister`, `deprecatedAliases = ["a::B"]`,
 * `deprecated = "message"`.
 *
 * Registering two actions with the same name throws when the first
 * `ActionRegistry` (one per `App`) is created.
 */
@:autoBuild(glaze.ActionMacro.build())
interface Action {

    /**
     * Clone the action (Rust: `boxed_clone`).
     */
    function boxedClone():Action;

    /**
     * Do a partial equality check on this action and the other.
     */
    function partialEq(action:Action):Bool;

    /**
     * Get the name of this action, for displaying in UI.
     */
    function name():String;

}
