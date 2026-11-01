// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.AnyElement;
import gpui.App;
import gpui.Range;
import gpui.Window;
import gpui.base.input.Selection;
import gpui.base.input.StyledRange;

/** Highlights of a code block cached with the highlighter that made them. */
class CachedCodeBlockHighlights {

    public final highlighter:CodeBlock->Array<StyledRange>;
    public final styles:Array<StyledRange>;

    public function new(highlighter:CodeBlock->Array<StyledRange>, styles:Array<StyledRange>) {
        this.highlighter = highlighter;
        this.styles = styles;
    }

}

/** Shared holder of a code block's highlight cache (Rust `Arc<Mutex<..>>`). */
class CodeBlockHighlightCache {

    public var value:Null<CachedCodeBlockHighlights> = null;

    public function new() {}

}

/**
 * A fenced or indented code block.
 */
class CodeBlock {

    var lang_:Null<String>;
    var meta_:Null<String> = null;

    @:allow(gpui.base.text)
    var state:InlineState;

    var highlightCache:CodeBlockHighlightCache;

    /**
     * Rendered UTF-8 byte spans of the code paired with their exact Markdown
     * source spans.
     */
    @:allow(gpui.base.text)
    var sourceSegments_:Array<SourceSegment> = [];

    public var span:Null<Span>;

    /** A code block of `code` in `lang`. */
    public function new(code:String, lang:Null<String>, span:Null<Span>) {
        state = new InlineState();
        state.setText(code);
        this.lang_ = lang;
        this.highlightCache = new CodeBlockHighlightCache();
        this.span = span;
    }

    /**
     * Builds a code block that is not tied to a parsed document.
     *
     * `TextView.codeBlockHighlighter` hands a `CodeBlock` to the highlighter
     * it is given, so anyone writing one needs a way to build a block to
     * exercise it against.
     */
    public static function fromCode(code:String, ?lang:String):CodeBlock {
        return new CodeBlock(code, lang, null);
    }

    /** Rust `Clone`: the state and the highlight cache are shared. */
    public function clone():CodeBlock {
        final block = new CodeBlock('', lang_, span != null ? span.copy() : null);
        block.meta_ = meta_;
        block.state = state;
        block.highlightCache = highlightCache;
        block.sourceSegments_ = sourceSegments_.copy();
        return block;
    }

    public function equals(other:Null<CodeBlock>):Bool {
        return other != null && lang_ == other.lang_ && meta_ == other.meta_ && code() == other.code() && Span.eq(span, other.span);
    }

    /** Get the language of the code block. */
    public inline function lang():Null<String> {
        return lang_;
    }

    /** The rest of the fence's info string after the language, when any. */
    public inline function meta():Null<String> {
        return meta_;
    }

    /**
     * Sets the fence's info string after the language. It is kept for round
     * trips and is not rendered.
     */
    public function withMeta(meta:Null<String>):CodeBlock {
        this.meta_ = meta;
        return this;
    }

    /**
     * Marks this code block as a leaf of an external editor, like
     * `Paragraph.withLeafKey`. Rekeying detaches runtime state from clones.
     */
    public function withLeafKey(key:Int):CodeBlock {
        state = Paragraph.leafKeyedState(state, key);
        return this;
    }

    /** Get the code content of the code block. */
    public function code():String {
        return state.text;
    }

    @:allow(gpui.base.text)
    function sourceSegments(sourceSegments:Array<SourceSegment>):CodeBlock {
        this.sourceSegments_ = sourceSegments;
        return this;
    }

    /** Test helper of the original (`#[cfg(test)]`). */
    @:allow(gpui.base.text)
    function setSelection(selection:Range):Void {
        state.selection = Selection.fromRange(selection);
    }

    @:allow(gpui.base.text)
    function selectedSourceRange():SourceRangeSelection {
        final selection = state.selection;
        if (selection == null) {
            return SourceRangeSelection.unselected();
        }
        if (selection.start >= selection.end) {
            return SourceRangeSelection.unselected();
        }
        final range = SourceSegment.sourceRangeForSegments(sourceSegments_, new Range(selection.start, selection.end));
        return range != null ? SourceRangeSelection.mapped(range) : SourceRangeSelection.unmapped();
    }

    @:allow(gpui.base.text)
    function highlightedStyles(highlighter:CodeBlock->Array<StyledRange>):Array<StyledRange> {
        final cache = highlightCache.value;
        if (cache != null && Reflect.compareMethods(cache.highlighter, highlighter)) {
            return cache.styles.copy();
        }

        final codeLen = TextUtils.len(code());
        final styles = [
            for (item in highlighter(this))
                if (item.range.start <= item.range.end && item.range.end <= codeLen) item
        ];
        highlightCache.value = new CachedCodeBlockHighlights(highlighter, styles);
        return styles.copy();
    }

    @:allow(gpui.base.text)
    function selectedText():String {
        final selection = state.selection;
        if (selection != null) {
            return TextUtils.slice(state.text, selection.start, selection.end);
        }
        return '';
    }

    /**
     * Markdown source for the current selection.
     *
     * The selected code is wrapped in a fenced code block carrying the
     * block's language, so a selected code block round-trips as Markdown
     * instead of pasting as bare, unfenced text. A partial selection is
     * still emitted as a valid fenced block.
     */
    @:allow(gpui.base.text)
    function selectedSource():String {
        final code = selectedText();
        if (code == '') {
            return '';
        }
        final lang = lang_ != null ? lang_ : '';
        // Trim trailing newlines so the closing fence sits on its own line
        // directly after the last code line (no blank line before it).
        final code = TextUtils.trimEndMatches(code, '\n');
        return '```$lang\n$code\n```';
    }

    @:allow(gpui.base.text)
    function text():String {
        return state.text;
    }

    @:allow(gpui.base.text)
    function hasSelection():Bool {
        return state.selection != null;
    }

    /**
     * Synchronously clear the selection stored in the inline state.
     */
    @:allow(gpui.base.text)
    function clearSelection():Void {
        state.selection = null;
    }

    @:allow(gpui.base.text)
    function render(options:NodeRenderOptions, nodeCx:NodeContext, window:Window, cx:App):AnyElement {
        return NodeRender.renderCodeBlock(this, options, nodeCx, window, cx);
    }

}
