// Ported from gpui-kit 0.8.1: crates/base/src/input/textarea/mod.rs (`TextareaState`),
// crates/base/src/input/base/state.rs (`impl<M: MultiLineMode> InputBaseState<M>`,
// `impl InputBaseState<TextareaMode>`), crates/base/src/input/base/inline_tokens.rs
// (`token_api!(TextareaMode)`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Context;
import glaze.Range;
import glaze.TextInputConfiguration.Autocapitalize;
import glaze.TextInputConfiguration.TextInputAction;
import glaze.Window;
import glaze.kit.base.input.InputBaseState.IntoMaskPattern;

/**
 * State for editing ordinary multi-line text.
 *
 * This is the shared editing engine in its multi-line kind (Rust
 * `InputBaseState<TextareaMode>`). Code-editor facilities such as
 * languages, diagnostics, folding, and LSP belong to gpui-kit's code
 * editor (`EditorState`), which is not part of Glaze: its code editor is
 * Cityscape (plugin `cityscape`).
 *
 * The methods Rust shares between the multi-line modes (`impl<M:
 * MultiLineMode>`: scroll bounce, search, soft wrap, wrapping indent) are
 * `MultiLineInputs`, static functions `TextareaState` forwards to.
 */
@:access(glaze.kit.base.input.LayoutMode)
class TextareaState extends InputBaseState {

    /**
     * Create a multi-line text state.
     *
     * Being multi-line is carried by the mode, not by the layout, so the
     * default plain-text layout needs no adjustment here.
     */
    public function new(window:Window, cx:Context<Dynamic>) {
        super(TextareaMode.instance, window, cx);
    }

    public function setAutoGrow(minRows:Int, maxRows:Int, cx:Context<InputBaseState>):Void {
        mode = LayoutMode.autoGrow(minRows, maxRows > minRows ? maxRows : minRows);
        mode.updateAutoGrow(displayMap);
        cx.notify();
    }

    /**
     * Set the number of rows for the multi-line Textarea. The input is at
     * least this many lines tall.
     *
     * default: 1
     */
    public function rows(rows:Int):TextareaState {
        MultiLineInputs.setLayoutRows(this, rows);
        return this;
    }

    public function setRows(rows:Int, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setLayoutRows(this, rows);
        cx.notify();
    }

    /** Grow with the content from `minRows` through `maxRows`. */
    public function autoGrow(minRows:Int, maxRows:Int):TextareaState {
        mode = LayoutMode.autoGrow(minRows, maxRows);
        return this;
    }

    // `impl<M: MultiLineMode>`

    /**
     * Set whether text taller than the input stretches past its top and
     * bottom and springs back when precise scrolling runs into an end.
     */
    public function withScrollBounce(scrollBounce:Bool):TextareaState {
        this.scrollBounce = scrollBounce;
        return this;
    }

    /** Update whether the text stretches past its ends. */
    public function setScrollBounce(scrollBounce:Bool, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setScrollBounce(this, scrollBounce, cx);
    }

    /** Whether the built-in search panel and its shortcut are enabled. Off by default. */
    public function withSearchable(searchable:Bool):TextareaState {
        this.searchable = searchable;
        return this;
    }

    public function setSearchable(searchable:Bool, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setSearchable(this, searchable, cx);
    }

    /** Set the soft wrap mode, default is true. */
    public function withSoftWrap(wrap:Bool):TextareaState {
        softWrap = wrap;
        return this;
    }

    /** Update the soft wrap mode, default is true. */
    public function setSoftWrap(wrap:Bool, window:Window, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setSoftWrap(this, wrap, window, cx);
    }

    /** Set how soft-wrapped continuation lines are indented, default is `WrappingIndent.Same`. */
    public function withWrappingIndent(wrappingIndent:WrappingIndent):TextareaState {
        this.wrappingIndent = wrappingIndent;
        return this;
    }

    /** Update how soft-wrapped continuation lines are indented. */
    public function setWrappingIndent(wrappingIndent:WrappingIndent, window:Window, cx:Context<InputBaseState>):Void {
        MultiLineInputs.setWrappingIndent(this, wrappingIndent, window, cx);
    }

    // Token API (Rust `token_api!`)

    /** Replace the selection with an atomic token; no delimiter is added. Returns the error, or null. */
    public function replaceWithToken(token:InlineToken, window:Window, cx:Context<InputBaseState>):Null<InlineTokenError> {
        return InputTokens.replaceWithToken(this, token, window, cx);
    }

    /** Replace a UTF-8 byte range, expanding overlaps to whole tokens. Returns the error, or null. */
    public function replaceRangeWithToken(range:Range, token:InlineToken, window:Window, cx:Context<InputBaseState>):Null<InlineTokenError> {
        return InputTokens.replaceRangeWithToken(this, range, token, window, cx);
    }

    public function tokens():Array<InlineTokenSpan> {
        return InputTokens.tokens(this);
    }

    /** The text with its tokens, as `setValue` accepts it. */
    public function content():InputContent {
        return InputTokens.content(this);
    }

    // Builders of `InputBaseState`, with this type as their result.

    override public function contextMenu(enable:Bool):TextareaState {
        return cast super.contextMenu(enable);
    }

    override public function withReplaceable(allow:Bool):TextareaState {
        return cast super.withReplaceable(allow);
    }

    override public function withPlaceholder(placeholder:String):TextareaState {
        return cast super.withPlaceholder(placeholder);
    }

    override public function withDisabled(disabled:Bool):TextareaState {
        return cast super.withDisabled(disabled);
    }

    override public function withReadonly(readonly:Bool):TextareaState {
        return cast super.withReadonly(readonly);
    }

    override public function withCleanOnEscape():TextareaState {
        return cast super.withCleanOnEscape();
    }

    override public function withSubmitOnEnter(submit:Bool):TextareaState {
        return cast super.withSubmitOnEnter(submit);
    }

    override public function withInputAction(action:TextInputAction):TextareaState {
        return cast super.withInputAction(action);
    }

    override public function withAutocorrect(autocorrect:Bool):TextareaState {
        return cast super.withAutocorrect(autocorrect);
    }

    override public function withAutocapitalize(autocapitalize:Autocapitalize):TextareaState {
        return cast super.withAutocapitalize(autocapitalize);
    }

    override public function withShowWhitespaces(show:Bool):TextareaState {
        return cast super.withShowWhitespaces(show);
    }

    override public function withCursorSurroundingLines(lines:Null<Int>):TextareaState {
        return cast super.withCursorSurroundingLines(lines);
    }

    override public function defaultValue(value:String):TextareaState {
        return cast super.defaultValue(value);
    }

    override public function withMaskPattern(pattern:IntoMaskPattern):TextareaState {
        return cast super.withMaskPattern(pattern);
    }

}
