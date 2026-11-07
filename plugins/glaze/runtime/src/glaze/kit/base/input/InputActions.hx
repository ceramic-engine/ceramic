// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (the input actions)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Action;

/**
 * The actions of the text inputs (namespace `input`), bound in the `Input`
 * key context by `InputKeyBindings.init`. Import this module
 * (`import glaze.kit.base.input.InputActions;`) to use them.
 *
 * The selection actions bound with them (`SelectUp`, `SelectDown`,
 * `SelectLeft`, `SelectRight`) are the shared ones of `glaze.kit.base.Actions`.
 */
class InputActions {

    /** The key context of the inputs (Rust `CONTEXT`). */
    public static inline final CONTEXT = 'Input';

}

/**
 * Enter, with whether it confirms with the secondary action and whether
 * Shift was held.
 */
@:action(namespace = input, noJson)
class Enter implements Action {

    /** Is confirm with secondary. */
    public final secondary:Bool;

    /** Whether the Shift modifier was held when Enter was pressed. */
    public final shift:Bool;

    /**
     * Returns true if `action` is a primary `Enter` action (`secondary:
     * false`), regardless of whether Shift was held.
     */
    public static function isPrimary(action:Action):Bool {
        return action.partialEq(new Enter(false, false)) || action.partialEq(new Enter(false, true));
    }

}

@:action(namespace = input) class ActivateToken implements Action {}

@:action(namespace = input) class Backspace implements Action {}

@:action(namespace = input) class Delete implements Action {}

@:action(namespace = input) class DeleteToBeginningOfLine implements Action {}

@:action(namespace = input) class DeleteToEndOfLine implements Action {}

@:action(namespace = input) class DeleteToPreviousWordStart implements Action {}

@:action(namespace = input) class DeleteToNextWordEnd implements Action {}

@:action(namespace = input) class Indent implements Action {}

@:action(namespace = input) class Outdent implements Action {}

@:action(namespace = input) class IndentInline implements Action {}

@:action(namespace = input) class OutdentInline implements Action {}

@:action(namespace = input) class MoveUp implements Action {}

@:action(namespace = input) class MoveDown implements Action {}

@:action(namespace = input) class MoveLeft implements Action {}

@:action(namespace = input) class MoveRight implements Action {}

@:action(namespace = input) class MoveHome implements Action {}

@:action(namespace = input) class MoveEnd implements Action {}

@:action(namespace = input) class MovePageUp implements Action {}

@:action(namespace = input) class MovePageDown implements Action {}

@:action(namespace = input) class AddCursorAbove implements Action {}

@:action(namespace = input) class AddCursorBelow implements Action {}

@:action(namespace = input) class SelectAll implements Action {}

@:action(namespace = input) class SelectToStartOfLine implements Action {}

@:action(namespace = input) class SelectToEndOfLine implements Action {}

@:action(namespace = input) class SelectToStart implements Action {}

@:action(namespace = input) class SelectToEnd implements Action {}

@:action(namespace = input) class SelectToPreviousWordStart implements Action {}

@:action(namespace = input) class SelectToNextWordEnd implements Action {}

@:action(namespace = input) class ShowCharacterPalette implements Action {}

@:action(namespace = input) class Copy implements Action {}

@:action(namespace = input) class Cut implements Action {}

@:action(namespace = input) class Paste implements Action {}

@:action(namespace = input) class Undo implements Action {}

@:action(namespace = input) class Redo implements Action {}

@:action(namespace = input) class MoveToStartOfLine implements Action {}

@:action(namespace = input) class MoveToEndOfLine implements Action {}

@:action(namespace = input) class MoveToStart implements Action {}

@:action(namespace = input) class MoveToEnd implements Action {}

@:action(namespace = input) class MoveToPreviousWord implements Action {}

@:action(namespace = input) class MoveToNextWord implements Action {}

@:action(namespace = input) class Escape implements Action {}

@:action(namespace = input) class ToggleCodeActions implements Action {}

@:action(namespace = input) class ShowCompletions implements Action {}

@:action(namespace = input) class Search implements Action {}

@:action(namespace = input) class Replace implements Action {}

@:action(namespace = input) class GoToDefinition implements Action {}
