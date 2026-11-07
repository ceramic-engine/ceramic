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
 * Source code, with language features: the mode of `EditorState`.
 *
 * The marker is declared with the other modes; its `InputModeKind`
 * implementation lives with the editor code (`EditorModeHooks`, Rust
 * `editor/mod.rs`), next to the language features it dispatches to.
 */
class EditorMode extends InputModeKindBase implements MultiLineMode {

    public static final instance:EditorMode = new EditorMode();

    public function multiLine():Bool {
        return EditorModeHooks.MULTI_LINE;
    }

    override public function codeEditor():Bool {
        return EditorModeHooks.CODE_EDITOR;
    }

    override public function newExtras():InputExtras {
        return new EditorExtras();
    }

    override public function driveHighlighter(highlighter:HighlighterCell, edit:InputEdit, text:Rope, folding:Bool, window:Window,
            cx:Context<InputBaseState>):Void {
        EditorModeHooks.driveHighlighter(highlighter, edit, text, folding, window, cx);
    }

    override public function driveHighlighterBatch(highlighter:HighlighterCell, edits:Array<EditedText>, folding:Bool, window:Window,
            cx:Context<InputBaseState>):Void {
        EditorModeHooks.driveHighlighterBatch(highlighter, edits, folding, window, cx);
    }

    override public function hoverDefinitionStyle(state:InputBaseState, cx:App):Null<StyledRange> {
        return EditorModeHooks.hoverDefinitionStyle(state, cx);
    }

    override public function hoverDefinitionHitbox(state:InputBaseState, window:Window, cx:App):Null<Hitbox> {
        return EditorModeHooks.hoverDefinitionHitbox(state, window, cx);
    }

    override public function resetLanguageFeatures(state:InputBaseState):Void {
        EditorModeHooks.resetLanguageFeatures(state);
    }

    override public function resetAnnotations(state:InputBaseState):Void {
        EditorModeHooks.resetAnnotations(state);
    }

    override public function editingSyntaxContext(state:InputBaseState, offset:Int):SyntaxContext {
        return EditorModeHooks.editingSyntaxContext(state, offset);
    }

    override public function adjustAnnotations(state:InputBaseState, range:Range, newLen:Int):Void {
        EditorModeHooks.adjustAnnotations(state, range, newLen);
    }

    override public function refreshLanguageFeatures(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {
        EditorModeHooks.refreshLanguageFeatures(state, window, cx);
    }

    override public function acceptInlineCompletion(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Bool {
        return EditorModeHooks.acceptInlineCompletion(state, window, cx);
    }

    override public function hasInlineCompletion(state:InputBaseState):Bool {
        return EditorModeHooks.hasInlineCompletion(state);
    }

    override public function onClick(state:InputBaseState, event:MouseDownEvent, offset:Int, window:Window, cx:Context<InputBaseState>):Bool {
        return EditorModeHooks.onClick(state, event, offset, window, cx);
    }

    override public function clearHoverState(state:InputBaseState, cx:Context<InputBaseState>):Void {
        EditorModeHooks.clearHoverState(state, cx);
    }

    override public function onTextTyped(state:InputBaseState, range:Range, text:String, window:Window, cx:Context<InputBaseState>):Void {
        EditorModeHooks.onTextTyped(state, range, text, window, cx);
    }

    override public function clearInlineCompletion(state:InputBaseState, cx:Context<InputBaseState>):Void {
        EditorModeHooks.clearInlineCompletion(state, cx);
    }

    override public function hideContextMenu(state:InputBaseState, cx:Context<InputBaseState>):Void {
        EditorModeHooks.hideContextMenu(state, cx);
    }

    override public function isContextMenuOpen(state:InputBaseState, cx:App):Bool {
        return EditorModeHooks.isContextMenuOpen(state, cx);
    }

    override public function handleContextMenuAction(state:InputBaseState, action:Action, window:Window, cx:Context<InputBaseState>):Bool {
        return EditorModeHooks.handleContextMenuAction(state, action, window, cx);
    }

    override public function onHoverDefinition(state:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        EditorModeHooks.onHoverDefinition(state, offset, window, cx);
    }

    override public function onMouseMove(state:InputBaseState, offset:Int, event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void {
        EditorModeHooks.onMouseMove(state, offset, event, window, cx);
    }

    override public function registerActions(element:Div, entity:Entity<InputBaseState>, window:Window):Div {
        return EditorModeHooks.registerActions(element, entity, window);
    }

}
