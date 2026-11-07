// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Action;
import gpui.App;
import gpui.Context;
import gpui.Div;
import gpui.Entity;
import gpui.Hitbox;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.Range;
import gpui.Window;
import ropey.Rope;

/**
 * Hooks the shared engine calls back into for mode-specific work (Rust
 * trait `InputModeKind`, implemented by the mode markers).
 *
 * The three input states are one engine seen through a mode: `InputMode`
 * (`InputState`), `TextareaMode` (`TextareaState`) and `EditorMode`
 * (`EditorState`). Rust picks it at compile time; the port keeps one
 * non-generic `InputBaseState` holding its `modeKind`, so the trait's
 * static functions become methods taking the state first. Extend
 * `InputModeKindBase` for the trait's default methods. The set is closed
 * (Rust seals the trait): `InputMode.instance`, `TextareaMode.instance`
 * and `EditorMode.instance`.
 *
 * `LayoutMode` carries how the text is laid out at runtime; the kind
 * decides what the input is.
 */
interface InputModeKind {

    /**
     * Whether this kind of input spans more than one line (Rust
     * `const MULTI_LINE`).
     *
     * The kind decides this, not the layout: `LayoutMode` carries how many
     * rows to show and how to grow, which is a different question from
     * whether the input is a text field or a document.
     */
    function multiLine():Bool;

    /** Whether this kind of input is a source-code editor (Rust `const CODE_EDITOR`). */
    function codeEditor():Bool;

    /**
     * New extra state for an input of this kind (Rust `type Extras` and its
     * `Default`). A single-line field has no use for an LSP client or a
     * search session, and an editor has no use for number stepping.
     */
    function newExtras():InputExtras;

    /**
     * Drives the syntax highlighter after the text changed. Only a code
     * editor has one.
     */
    function driveHighlighter(highlighter:HighlighterCell, edit:InputEdit, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void;

    /**
     * Drives the syntax highlighter once for several edits applied as one
     * change, each paired with the text right after it.
     */
    function driveHighlighterBatch(highlighter:HighlighterCell, edits:Array<EditedText>, folding:Bool, window:Window, cx:Context<InputBaseState>):Void;

    /** The range highlighted while Cmd-hovering a symbol, with its style. */
    function hoverDefinitionStyle(state:InputBaseState, cx:App):Null<StyledRange>;

    /** The hitbox for Cmd-hover, when the mode supports go-to-definition. */
    function hoverDefinitionHitbox(state:InputBaseState, window:Window, cx:App):Null<Hitbox>;

    /** Drops cached language-server results, e.g. after the text is replaced. */
    function resetLanguageFeatures(state:InputBaseState):Void;

    /** Drops decorations and hover state when the text is replaced wholesale. */
    function resetAnnotations(state:InputBaseState):Void;

    /**
     * Syntax context at `offset` for editing decisions. Only a code editor
     * can have a provider installed; the default answer is `Code`, which
     * preserves character-heuristic behavior.
     */
    function editingSyntaxContext(state:InputBaseState, offset:Int):SyntaxContext;

    /** Slides decoration ranges along with an edit. */
    function adjustAnnotations(state:InputBaseState, range:Range, newLen:Int):Void;

    /** Refreshes language-server state after the text changed. */
    function refreshLanguageFeatures(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Void;

    /** Takes the pending inline completion, when Tab should accept it. */
    function acceptInlineCompletion(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Bool;

    /** Whether an inline completion is waiting to be accepted. */
    function hasInlineCompletion(state:InputBaseState):Bool;

    /** Reacts to a click, for Cmd-click go-to-definition. */
    function onClick(state:InputBaseState, event:MouseDownEvent, offset:Int, window:Window, cx:Context<InputBaseState>):Bool;

    /** Drops hover state when the pointer leaves or focus moves. */
    function clearHoverState(state:InputBaseState, cx:Context<InputBaseState>):Void;

    /** Offers freshly typed text to the completion engine. */
    function onTextTyped(state:InputBaseState, range:Range, text:String, window:Window, cx:Context<InputBaseState>):Void;

    /** Drops any inline completion after the text or cursor moved. */
    function clearInlineCompletion(state:InputBaseState, cx:Context<InputBaseState>):Void;

    /** Closes any open completion or code-action menu. */
    function hideContextMenu(state:InputBaseState, cx:Context<InputBaseState>):Void;

    /** Whether a completion or code-action menu is currently open. */
    function isContextMenuOpen(state:InputBaseState, cx:App):Bool;

    /** Lets an open menu consume the action first. Returns true when it did. */
    function handleContextMenuAction(state:InputBaseState, action:Action, window:Window, cx:Context<InputBaseState>):Bool;

    /**
     * Highlights the symbol under the pointer for go-to-definition. Separate
     * from `onMouseMove`: this runs on paths that have no mouse event to
     * hand over, such as opening the context menu.
     */
    function onHoverDefinition(state:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void;

    /** Reacts to the pointer moving, for the hover popover. */
    function onMouseMove(state:InputBaseState, offset:Int, event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void;

    /** Registers the actions that only this mode handles (on the stateful div). */
    function registerActions(element:Div, entity:Entity<InputBaseState>, window:Window):Div;

}
