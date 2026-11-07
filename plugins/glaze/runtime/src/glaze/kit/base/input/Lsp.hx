// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/mod.rs, lsp/document_colors.rs,
// lsp/semantic_tokens.rs (the `Lsp` parts)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Context;
import gpui.Hsla;
import gpui.Range;
import gpui.Rgba;
import gpui.Task;
import gpui.Unit;
import gpui.Window;
import ropey.Rope;

using gpui.base.input.RopeExt;

/**
 * A document color (Rust tuple `(lsp_types::Range, Hsla)`).
 */
class DocumentColor {

    public final range:LspRange;

    public final color:Hsla;

    public inline function new(range:LspRange, color:Hsla) {
        this.range = range;
        this.color = color;
    }

    public function equals(other:DocumentColor):Bool {
        return other != null && range.equals(other.range) && color.equals(other.color);
    }

}

/**
 * A decoded semantic token: its range and theme token-type name (Rust tuple
 * `(lsp_types::Range, SharedString)`).
 */
class SemanticTokenSpan {

    public final range:LspRange;

    public final name:String;

    public inline function new(range:LspRange, name:String) {
        this.range = range;
        this.name = name;
    }

    public function equals(other:SemanticTokenSpan):Bool {
        return other != null && name == other.name && range.equals(other.range);
    }

}

/**
 * LSP ServerCapabilities: the providers of an editor and their cached results.
 *
 * The provider requests run as tasks owned by the editor state: a new request
 * replaces (and cancels) the previous one, like dropping a Rust `Task`.
 */
class Lsp {

    static inline final MAX_DOCUMENT_COLORS:Int = 10000;

    /** The completion provider. */
    public var completionProvider:Null<CompletionProvider> = null;

    /** The code action providers. */
    public var codeActionProviders:Array<CodeActionProvider> = [];

    /** The hover provider. */
    public var hoverProvider:Null<HoverProvider> = null;

    /** The definition provider. */
    public var definitionProvider:Null<DefinitionProvider> = null;

    /** The document color provider. */
    public var documentColorProvider:Null<DocumentColorProvider> = null;

    /** The range semantic tokens provider. */
    public var semanticTokensProvider:Null<DocumentRangeSemanticTokensProvider> = null;

    /**
     * Optional host hook to show documents for Go to Definition locations,
     * following the `window/showDocument` request (see `ShowDocumentHandler`).
     */
    public var showDocument:Null<ShowDocumentHandler> = null;

    /** Display options for the completion popover. */
    public var completionMenu:CompletionMenuOptions = new CompletionMenuOptions();

    /**
     * Decides which bytes of each completion label the menu paints.
     *
     * Defaults to `Completions.highlightPrefix`.
     */
    var _completionHighlighter:CompletionHighlighter = Completions.highlightPrefix;

    public var documentColors:Array<DocumentColor> = [];

    /**
     * Cached semantic tokens as absolute position ranges + theme token-type
     * names. Color is resolved from the name at paint time so theme switches
     * take effect without a refetch.
     */
    public var semanticTokens:Array<SemanticTokenSpan> = [];

    public var _hoverTask:Task<Unit> = Task.done();

    public var _definitionTask:Task<Unit> = Task.done();

    public var _documentColorTask:Task<Unit> = Task.done();

    public var _semanticTokensTask:Task<Unit> = Task.done();

    public function new() {}

    public static inline function defaultValue():Lsp {
        return new Lsp();
    }

    /** Set the completion label highlighter when constructing the LSP configuration. */
    public function withCompletionHighlighter(highlighter:CompletionHighlighter):Lsp {
        setCompletionHighlighter(highlighter);
        return this;
    }

    /** Return the completion label highlighter. */
    public inline function completionHighlighter():CompletionHighlighter {
        return _completionHighlighter;
    }

    /**
     * Replace the completion label highlighter.
     *
     * Notify the editor after updating its LSP configuration to repaint an open menu.
     */
    public function setCompletionHighlighter(highlighter:CompletionHighlighter):Void {
        _completionHighlighter = highlighter;
    }

    /** Update the LSP when the text changes. */
    public function update(text:Rope, window:Window, cx:Context<InputBaseState>):Void {
        updateDocumentColors(text, window, cx);
        updateSemanticTokens(text, window, cx);
    }

    /** Reset all LSP states. */
    public function reset():Void {
        documentColors = [];
        semanticTokens = [];
        _hoverTask.cancel();
        _hoverTask = Task.done();
        _definitionTask.cancel();
        _definitionTask = Task.done();
        _documentColorTask.cancel();
        _documentColorTask = Task.done();
        _semanticTokensTask.cancel();
        _semanticTokensTask = Task.done();
    }

/// Document colors (lsp/document_colors.rs)

    public static function documentColorsFromResponse(colors:Array<ColorInformation>):Null<Array<DocumentColor>> {
        if (colors.length > MAX_DOCUMENT_COLORS)
            return null;

        final documentColors = [for (info in colors) new DocumentColor(info.range, new Rgba(info.color.red, info.color.green, info.color.blue, info.color.alpha).toHsla())];
        // sort_by_key(|(range, _)| range.start) is stable
        haxe.ds.ArraySort.sort(documentColors, (a, b) -> comparePositions(a.range.start, b.range.start));

        return documentColors;
    }

    static function comparePositions(a:LspPosition, b:LspPosition):Int {
        return a.line != b.line ? (a.line < b.line ? -1 : 1) : (a.character != b.character ? (a.character < b.character ? -1 : 1) : 0);
    }

    public function documentColorsForRange(text:Rope, visibleRange:Range):Array<ColorSwatch> {
        final result:Array<ColorSwatch> = [];
        for (documentColor in documentColors) {
            final range = documentColor.range;
            if (range.start.line > visibleRange.end || range.end.line < visibleRange.start)
                continue;

            final start = text.positionToOffset(range.start);
            final end = text.positionToOffset(range.end);
            if (start >= end)
                continue;

            result.push(new ColorSwatch(new Range(start, end), documentColor.color));
        }
        return result;
    }

    /**
     * Rust `update_document_colors`: asks the document color provider after
     * 100 ms and stores the colors.
     */
    public function updateDocumentColors(text:Rope, window:Window, cx:Context<InputBaseState>):Void {
        final provider = documentColorProvider;
        if (provider == null)
            return;

        final text = text.clone();
        final inputState = cx.entity();

        // debounce timer 100ms
        _documentColorTask.cancel();
        _documentColorTask = cx.spawn((_, acx) -> acx.backgroundExecutor().timer(0.1).andThen(_ -> {
            if (window.isDestroyed())
                return null;
            final task = provider.documentColors(text, window, acx);
            return task.catchError(_ -> null).then(colors -> {
                if (colors == null)
                    return;
                inputState.update(acx, (inputState, cx) -> {
                    final documentColors = documentColorsFromResponse(colors);
                    if (documentColors == null)
                        return;

                    final lsp = (cast inputState.extras : EditorExtras).lsp;
                    if (!sameDocumentColors(documentColors, lsp.documentColors)) {
                        lsp.documentColors = documentColors;
                        cx.notify();
                    }
                });
            });
        }).then(_ -> {}));
    }

    static function sameDocumentColors(a:Array<DocumentColor>, b:Array<DocumentColor>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

/// Semantic tokens (lsp/semantic_tokens.rs)

    public function semanticTokensForRange(text:Rope, visibleRange:Range, theme:HighlightStyleResolver):Array<StyledRange> {
        if (semanticTokens.length == 0)
            return [];

        final visibleStart = text.offsetToPosition(visibleRange.start);
        final visibleEnd = text.offsetToPosition(visibleRange.end);

        // partition_point(|(range, _)| range.start < visible_end)
        var lo = 0;
        var hi = semanticTokens.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (comparePositions(semanticTokens[mid].range.start, visibleEnd) < 0)
                lo = mid + 1;
            else
                hi = mid;
        }
        final upper = lo;
        // partition_point(|(range, _)| range.start.line < visible_start.line)
        lo = 0;
        hi = semanticTokens.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (semanticTokens[mid].range.start.line < visibleStart.line)
                lo = mid + 1;
            else
                hi = mid;
        }
        final lower = lo;

        final result:Array<StyledRange> = [];
        for (i in lower...upper) {
            final token = semanticTokens[i];
            final start = text.positionToOffset(token.range.start);
            final end = text.positionToOffset(token.range.end);
            if (start >= end || start >= visibleRange.end || end <= visibleRange.start)
                continue;

            final style = theme.style(token.name);
            if (style == null)
                continue;
            result.push(new StyledRange(new Range(start, end), style));
        }
        return result;
    }

    /**
     * Rust `update_semantic_tokens`: asks the semantic tokens provider after
     * 100 ms and stores the decoded tokens.
     */
    public function updateSemanticTokens(text:Rope, window:Window, cx:Context<InputBaseState>):Void {
        final provider = semanticTokensProvider;
        if (provider == null)
            return;

        final legend = provider.legend();
        final text = text.clone();
        // Fetch the whole document; results are cached and filtered to the
        // viewport at paint time (mirrors `update_document_colors`), so a
        // scroll never needs a refetch.
        final range = new Range(0, text.len());
        final inputState = cx.entity();

        // debounce timer 100ms
        _semanticTokensTask.cancel();
        _semanticTokensTask = cx.spawn((_, acx) -> acx.backgroundExecutor().timer(0.1).andThen(_ -> {
            if (window.isDestroyed())
                return null;
            final task = provider.semanticTokens(text, range, window, acx);
            return task.catchError(_ -> null).then(tokens -> {
                if (tokens == null)
                    return;
                final decoded = decodeSemanticTokens(tokens, legend);
                inputState.update(acx, (inputState, cx) -> {
                    final lsp = (cast inputState.extras : EditorExtras).lsp;
                    if (!sameSemanticTokens(decoded, lsp.semanticTokens)) {
                        lsp.semanticTokens = decoded;
                        cx.notify();
                    }
                });
            });
        }).then(_ -> {}));
    }

    static function sameSemanticTokens(a:Array<SemanticTokenSpan>, b:Array<SemanticTokenSpan>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

    public static function decodeSemanticTokens(tokens:SemanticTokens, legend:SemanticTokensLegend):Array<SemanticTokenSpan> {
        final names = legend.tokenTypes;

        final out:Array<SemanticTokenSpan> = [];
        var line = 0;
        var character = 0;

        for (token in tokens.data) {
            if (token.deltaLine > 0) {
                line += token.deltaLine;
                character = token.deltaStart;
            }
            else {
                character += token.deltaStart;
            }

            if (token.tokenType < 0 || token.tokenType >= names.length)
                continue;
            final name = names[token.tokenType];

            final start = new LspPosition(line, character);
            final end = new LspPosition(line, character + token.length);
            out.push(new SemanticTokenSpan(new LspRange(start, end), name));
        }

        haxe.ds.ArraySort.sort(out, (a, b) -> comparePositions(a.range.start, b.range.start));
        return out;
    }

}
