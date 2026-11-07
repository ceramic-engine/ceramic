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
 * The default methods of `InputModeKind`.
 */
abstract class InputModeKindBase implements InputModeKind {

    function new() {}

    public abstract function multiLine():Bool;

    public function codeEditor():Bool {
        return false;
    }

    public function newExtras():InputExtras {
        return new InputExtrasBase();
    }

    public function driveHighlighter(highlighter:HighlighterCell, edit:InputEdit, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {}

    public function driveHighlighterBatch(highlighter:HighlighterCell, edits:Array<EditedText>, folding:Bool, window:Window,
        cx:Context<InputBaseState>):Void {}

    public function hoverDefinitionStyle(state:InputBaseState, cx:App):Null<StyledRange> {
        return null;
    }

    public function hoverDefinitionHitbox(state:InputBaseState, window:Window, cx:App):Null<Hitbox> {
        return null;
    }

    public function resetLanguageFeatures(state:InputBaseState):Void {}

    public function resetAnnotations(state:InputBaseState):Void {}

    public function editingSyntaxContext(state:InputBaseState, offset:Int):SyntaxContext {
        return SyntaxContext.Code;
    }

    public function adjustAnnotations(state:InputBaseState, range:Range, newLen:Int):Void {}

    public function refreshLanguageFeatures(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {}

    public function acceptInlineCompletion(state:InputBaseState, window:Window, cx:Context<InputBaseState>):Bool {
        return false;
    }

    public function hasInlineCompletion(state:InputBaseState):Bool {
        return false;
    }

    public function onClick(state:InputBaseState, event:MouseDownEvent, offset:Int, window:Window, cx:Context<InputBaseState>):Bool {
        return false;
    }

    public function clearHoverState(state:InputBaseState, cx:Context<InputBaseState>):Void {}

    public function onTextTyped(state:InputBaseState, range:Range, text:String, window:Window, cx:Context<InputBaseState>):Void {}

    public function clearInlineCompletion(state:InputBaseState, cx:Context<InputBaseState>):Void {}

    public function hideContextMenu(state:InputBaseState, cx:Context<InputBaseState>):Void {}

    public function isContextMenuOpen(state:InputBaseState, cx:App):Bool {
        return false;
    }

    public function handleContextMenuAction(state:InputBaseState, action:Action, window:Window, cx:Context<InputBaseState>):Bool {
        return false;
    }

    public function onHoverDefinition(state:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {}

    public function onMouseMove(state:InputBaseState, offset:Int, event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void {}

    public function registerActions(element:Div, entity:Entity<InputBaseState>, window:Window):Div {
        return element;
    }

}
