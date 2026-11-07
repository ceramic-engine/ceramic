// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/mod.rs (`EditorState`),
// crates/base/src/input/base/state.rs (`impl InputBaseState<EditorMode>`, the multi-line builders)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Context;
import gpui.Window;

using gpui.base.input.RopeExt;

/**
 * State for source-code editing.
 *
 * This is the shared editing engine in its code-editor kind (Rust
 * `InputBaseState<EditorMode>`). Languages, line numbers, folding, indent
 * guides, diagnostics, decorations, and the LSP providers exist on this kind
 * only, so an ordinary input or textarea never exposes them.
 *
 * Like `InputState` and `TextareaState`, a subclass of the one non-generic
 * `InputBaseState`, built in the editor mode. The code editor is wave 11:
 * this declares the editor-only API of `editor/mod.rs`, the rest of its
 * `impl InputBaseState<EditorMode>` blocks are the static extensions
 * `InputLspExt`, `InputDecorationsExt` and `InputIndentExt`.
 */
@:access(gpui.base.input.InputBaseState)
@:access(gpui.base.input.LayoutMode)
class EditorState extends InputBaseState {

    /**
     * Create a source-code editor state.
     *
     * Default options: line numbers on, tab size 2 with soft tabs, indent
     * guides on, multi-line, and search enabled. Set the language for syntax
     * highlighting with `language`; without one the text is shown
     * unhighlighted.
     */
    public function new(window:Window, cx:Context<Dynamic>) {
        super(EditorMode.instance, window, cx);
        mode = LayoutMode.codeEditor(EditorLanguage.create(cx.app));
        searchable = true;
    }

    /**
     * Set the language to highlight, e.g. `"rust"`.
     *
     * See `setHighlighter` to change it after construction.
     */
    public function language(language:String):EditorState {
        if (mode.kind == CodeEditor) {
            mode.language.setName(language);
            mode._highlighter.value = null;
        }
        return this;
    }

    /** The current language name, e.g. `"rust"`. */
    public function languageName():String {
        return mode.kind == CodeEditor ? mode.language.name() : "";
    }

    /** Set enable/disable code folding. Default: true */
    public function folding(folding:Bool):EditorState {
        if (mode.kind == CodeEditor) {
            mode.folding = folding;
        }
        return this;
    }

    /**
     * Set code folding at runtime.
     *
     * When disabling, all existing folds are cleared.
     */
    public function setFolding(folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (mode.kind == CodeEditor) {
            mode.folding = folding;
        }
        if (!folding) {
            displayMap.clearFolds();
        }
        cx.notify();
    }

    /**
     * Unfold any folded ranges that hide the given position.
     *
     * A fold keeps its own first and last line visible, so a position on
     * either of them opens nothing. Nested folds all open.
     *
     * Returns whether any fold was opened.
     */
    public function unfoldAt(position:LspPosition, cx:Context<InputBaseState>):Bool {
        final offset = text.positionToOffset(position);
        final line = text.offsetToPoint(offset).row;
        // A fold hides start_line + 1 ..= end_line - 1, so a line is hidden
        // exactly when some folded range strictly contains it.
        final covering = [for (fold in displayMap.foldedRanges()) if (line > fold.startLine && line < fold.endLine) fold.startLine];
        if (covering.length == 0) {
            return false;
        }

        for (startLine in covering) {
            displayMap.setFolded(startLine, false);
        }
        cx.notify();
        return true;
    }

    /** Set enable/disable line number. */
    public function lineNumber(lineNumber:Bool):EditorState {
        if (mode.kind == CodeEditor) {
            mode._lineNumber = lineNumber;
        }
        return this;
    }

    /** Set line number. */
    public function setLineNumber(lineNumber:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (mode.kind == CodeEditor) {
            if (mode._lineNumber == lineNumber) {
                return;
            }
            mode._lineNumber = lineNumber;
        }
        cx.notify();
    }

    /**
     * Set enable/disable automatic closing brackets and quotes.
     *
     * When enabled, typing an opener from `LanguageConfig.autoClosingPairs`
     * inserts the matching closer and places the cursor inside. Typing a
     * closer that is already present just moves past it. Default: true
     */
    public function autoClose(autoClose:Bool):EditorState {
        mode.setAutoClose(autoClose);
        return this;
    }

    /** Set automatic closing brackets and quotes at runtime. */
    public function setAutoClose(autoClose:Bool, window:Window, cx:Context<InputBaseState>):Void {
        mode.setAutoClose(autoClose);
        cx.notify();
    }

    /**
     * Set enable/disable smart indent on Enter. When enabled, Enter uses
     * structural brackets and `LanguageConfig.indentationRules` to choose
     * indentation. Default: true
     */
    public function smartIndent(smartIndent:Bool):EditorState {
        mode.setSmartIndent(smartIndent);
        return this;
    }

    /** Set smart indent on Enter at runtime. */
    public function setSmartIndent(smartIndent:Bool, window:Window, cx:Context<InputBaseState>):Void {
        mode.setSmartIndent(smartIndent);
        cx.notify();
    }

    // `impl<M: MultiLineMode>` (see `MultiLineInputs`)

    public function withScrollBounce(scrollBounce:Bool):EditorState {
        this.scrollBounce = scrollBounce;
        return this;
    }

    public function setScrollBounce(scrollBounce:Bool, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setScrollBounce(this, scrollBounce, cx);
    }

    public function withSearchable(searchable:Bool):EditorState {
        this.searchable = searchable;
        return this;
    }

    public function setSearchable(searchable:Bool, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setSearchable(this, searchable, cx);
    }

    public function withSoftWrap(wrap:Bool):EditorState {
        softWrap = wrap;
        return this;
    }

    public function setSoftWrap(wrap:Bool, window:Window, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setSoftWrap(this, wrap, window, cx);
    }

    public function withWrappingIndent(wrappingIndent:WrappingIndent):EditorState {
        this.wrappingIndent = wrappingIndent;
        return this;
    }

    public function setWrappingIndent(wrappingIndent:WrappingIndent, window:Window, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setWrappingIndent(this, wrappingIndent, window, cx);
    }

    override public function defaultValue(value:String):EditorState {
        return cast super.defaultValue(value);
    }

    override public function withPlaceholder(placeholder:String):EditorState {
        return cast super.withPlaceholder(placeholder);
    }

    /**
     * The LSP providers and their cached results.
     *
     * This exists on the editor alone: an ordinary input or textarea has no
     * language server, and no field to reach one through. Configure the
     * providers through it (Rust `lsp` and `lsp_mut`).
     */
    public function lsp():Lsp {
        return (cast extras:EditorExtras).lsp;
    }

    /** Syntax context at `offset`, or `Code` when the language has no provider. */
    public function syntaxContextAt(offset:Int):SyntaxContext {
        return EditorModeHooks.syntaxContextAt(this, offset);
    }

}
