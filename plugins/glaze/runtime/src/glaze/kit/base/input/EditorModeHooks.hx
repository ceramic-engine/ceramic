// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/mod.rs (`impl InputModeKind for EditorMode`,
// `EditorState::syntax_context_at`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.Hitbox;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.Range;
import glaze.Window;
import ropey.Rope;

import glaze.kit.base.input.InputActions;

using glaze.kit.base.input.InputLspExt;

/**
 * The body of Rust's `impl InputModeKind for EditorMode` (written in
 * `editor/mod.rs`): `EditorMode` (declared with `kind.rs`) implements the
 * `InputModeKind` methods by calling these. `MULTI_LINE` and
 * `CODE_EDITOR` are both true for the editor.
 */
@:access(glaze.kit.base.input.InputBaseState)
class EditorModeHooks {

    public static inline final MULTI_LINE:Bool = true;

    public static inline final CODE_EDITOR:Bool = true;

    static inline function extras(state:InputBaseState):EditorExtras {
        return cast state.extras;
    }

    public static function hoverDefinitionStyle(state:InputBaseState, cx:App):Null<StyledRange> {
        return state.hoverDefinitionStyle();
    }

    public static function hoverDefinitionHitbox(state:InputBaseState, window:Window, cx:App):Null<Hitbox> {
        return state.hoverDefinitionHitbox(window);
    }

    public static function resetLanguageFeatures(state:InputBaseState):Void {
        extras(state).lsp.reset();
    }

    public static function resetAnnotations(state:InputBaseState):Void {
        final extras = extras(state);
        extras.hoverPopover = null;
        extras.decorations.clear();
        extras.rangeDecorationCollections.clear();
    }

    public static function editingSyntaxContext(state:InputBaseState, offset:Int):SyntaxContext {
        return syntaxContextAt(state, offset);
    }

    public static function adjustAnnotations(state:InputBaseState, range:Range, newLen:Int):Void {
        final extras = extras(state);
        extras.decorations.adjustForEdit(range, newLen);
        extras.rangeDecorationCollections.adjustForEdit(range, newLen);
    }

    public static function refreshLanguageFeatures(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {
        final text = state.text.clone();
        extras(state).lsp.update(text, window, cx);
    }

    public static function acceptInlineCompletion(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Bool {
        return state.acceptInlineCompletion(window, cx);
    }

    public static function hasInlineCompletion(state:InputBaseState):Bool {
        return state.hasInlineCompletion();
    }

    public static function onClick(state:InputBaseState, event:MouseDownEvent, offset:Int, window:Window, cx:Context<InputBaseState>):Bool {
        return state.handleClickHoverDefinition(event, offset, window, cx);
    }

    public static function clearHoverState(state:InputBaseState, cx:Context<InputBaseState>):Void {
        state.clearHoverState(cx);
    }

    public static function onTextTyped(state:InputBaseState, range:Range, text:String, window:Window, cx:Context<InputBaseState>):Void {
        state.handleCompletionTrigger(range, text, window, cx);
    }

    public static function clearInlineCompletion(state:InputBaseState, cx:Context<InputBaseState>):Void {
        state.clearInlineCompletion(cx);
    }

    public static function hideContextMenu(state:InputBaseState, cx:Context<InputBaseState>):Void {
        state.hideContextMenu(cx);
    }

    public static function isContextMenuOpen(state:InputBaseState, cx:App):Bool {
        return state.isContextMenuOpen(cx);
    }

    public static function handleContextMenuAction(state:InputBaseState, action:glaze.Action, window:Window, cx:Context<InputBaseState>):Bool {
        return state.handleActionForContextMenu(action, window, cx);
    }

    public static function onHoverDefinition(state:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        state.handleHoverDefinition(offset, window, cx);
    }

    public static function onMouseMove(state:InputBaseState, offset:Int, event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void {
        state.handleMouseMove(offset, event, window, cx);
    }

    /**
     * Rust `drive_highlighter`: the highlighter is shared with the layout
     * mode (`Rc<RefCell<Option<Box<dyn InputHighlighter>>>>`, a `HighlighterCell`).
     */
    public static function driveHighlighter(highlighter:HighlighterCell, edit:InputEdit, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        final highlighter = highlighter.value;
        if (highlighter == null)
            return;
        highlighter.update(edit, text, folding, window, cx);
    }

    public static function driveHighlighterBatch(highlighter:HighlighterCell, edits:Array<EditedText>, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        final highlighter = highlighter.value;
        if (highlighter == null)
            return;
        highlighter.updateBatch(edits, folding, window, cx);
    }

    /**
     * Rust `register_actions`: `window.listener_for(entity, f)` is a listener
     * updating the entity with `f`. The port's `Stateful<Div>` is `Div`.
     */
    public static function registerActions(element:Div, entity:Entity<InputBaseState>, window:Window):Div {
        return element
            .keyContext("Input mode=editor")
            .onAction(ToggleCodeActions, (action, window, cx) -> entity.update(cx, (state, cx) -> state.onActionToggleCodeActions(action, window, cx)))
            .onAction(ShowCompletions, (action, window, cx) -> entity.update(cx, (state, cx) -> state.onActionShowCompletions(action, window, cx)))
            .onAction(GoToDefinition, (action, window, cx) -> entity.update(cx, (state, cx) -> state.onActionGoToDefinition(action, window, cx)));
    }

    /** Rust `EditorState::syntax_context_at`: `Code` when the language has no provider. */
    public static function syntaxContextAt(state:InputBaseState, offset:Int):SyntaxContext {
        return state.mode.syntaxContextAt(state.text, offset);
    }

}
