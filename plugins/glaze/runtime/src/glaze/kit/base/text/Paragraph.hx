// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Range;

/**
 * The text, highlights and links a text-only paragraph renders with.
 *
 * They are a pure function of the paragraph's children and the style they
 * are rendered under. Streamed fades change every frame and are layered on
 * afterwards; reference links are resolved afterwards too, since a
 * definition can arrive later in the document.
 */
class ParagraphRender {

    public final style:TextViewStyle;
    public final monoFont:String;
    public final text:String;
    public final highlights:Array<RangedHighlight>;

    /** Links as written, before reference resolution. */
    public final links:Array<RangedLink>;

    public function new(style:TextViewStyle, monoFont:String, text:String, highlights:Array<RangedHighlight>, links:Array<RangedLink>) {
        this.style = style;
        this.monoFont = monoFont;
        this.text = text;
        this.highlights = highlights;
        this.links = links;
    }

}

/**
 * The paragraph element, contains multiple text nodes.
 *
 * Unlike other Element, this is cloneable, because it is used in the Node
 * AST. We keep the selection state inside these AST nodes: `clone()` shares
 * `state` (Rust `Arc`).
 */
class Paragraph {

    @:allow(glaze.kit.base.text)
    var span:Null<Span> = null;

    @:allow(glaze.kit.base.text)
    var children_:Array<InlineNode> = [];

    /**
     * The link references in this paragraph, used for reference links.
     *
     * The key is the identifier, the value is the url.
     */
    @:allow(glaze.kit.base.text)
    var linkRefs:Map<String, String> = new Map();

    @:allow(glaze.kit.base.text)
    var state:InlineState;

    /**
     * What the plain (text-only) render path derives from `children`, kept
     * between frames; see `ParagraphRender`. Derived state, invisible to
     * equality. A clone carries what was cached so far.
     */
    @:allow(glaze.kit.base.text)
    var renderCache:Null<ParagraphRender> = null;

    /** `Paragraph::default()`. */
    public function new() {
        state = new InlineState();
    }

    /** Rust `Paragraph::new(text)`: one unmarked run. */
    public static function ofText(text:String):Paragraph {
        final paragraph = new Paragraph();
        paragraph.children_ = [new InlineNode(text)];
        return paragraph;
    }

    public function clone():Paragraph {
        final paragraph = new Paragraph();
        paragraph.span = span != null ? span.copy() : null;
        paragraph.children_ = [for (child in children_) child.clone()];
        paragraph.linkRefs = linkRefs.copy();
        paragraph.state = state;
        paragraph.renderCache = renderCache;
        return paragraph;
    }

    public function equals(other:Null<Paragraph>):Bool {
        if (other == null || !Span.eq(span, other.span) || children_.length != other.children_.length)
            return false;
        for (i in 0...children_.length) {
            if (!children_[i].equals(other.children_[i]))
                return false;
        }
        var count = 0;
        for (key => value in linkRefs) {
            if (!other.linkRefs.exists(key) || other.linkRefs.get(key) != value)
                return false;
            count++;
        }
        for (_ in other.linkRefs.keys())
            count--;
        return count == 0;
    }

    @:allow(glaze.kit.base.text)
    function take():Paragraph {
        final taken = new Paragraph();
        taken.span = span;
        taken.children_ = children_;
        taken.linkRefs = linkRefs;
        taken.state = state;
        taken.renderCache = renderCache;
        span = null;
        children_ = [];
        linkRefs = new Map();
        state = new InlineState();
        renderCache = null;
        return taken;
    }

    @:allow(glaze.kit.base.text)
    function isImage():Bool {
        return false;
    }

    @:allow(glaze.kit.base.text)
    function setSpan(span:Span):Void {
        this.span = span;
    }

    @:allow(glaze.kit.base.text)
    function pushStr(text:String):Void {
        final mark = new RangedMark(new Range(0, TextUtils.len(text)), new TextMark());
        children_.push(new InlineNode(text).marks([mark]));
        invalidateRenderCache();
    }

    /** Appends an inline run. */
    public function push(text:InlineNode):Void {
        children_.push(text);
        invalidateRenderCache();
    }

    /** The inline runs. */
    public inline function children():Array<InlineNode> {
        return children_;
    }

    /**
     * Marks this paragraph as a leaf of an external editor: while a
     * `EditorHost.collectLeafGeometry` scope is active, it reports its
     * geometry under `key` and paints the decorations given for `key`.
     * Rekeying detaches runtime state from clones.
     */
    public function withLeafKey(key:Int):Paragraph {
        state = Paragraph.leafKeyedState(state, key);
        return this;
    }

    /**
     * Rekeying creates a new rendered identity. Do not mutate the state of
     * another AST clone (or carry its transient selection into this
     * instance). Rust free `set_leaf_key`.
     */
    @:allow(glaze.kit.base.text)
    static function leafKeyedState(state:InlineState, key:Int):InlineState {
        final keyed = new InlineState();
        keyed.text = state.text;
        keyed.editorKey = key;
        return keyed;
    }

    @:allow(glaze.kit.base.text)
    function pushImage(image:ImageNode):Void {
        children_.push(InlineNode.ofImage(image));
        invalidateRenderCache();
    }

    /** The children changed, so what was derived from them is stale. */
    function invalidateRenderCache():Void {
        renderCache = null;
    }

    @:allow(glaze.kit.base.text)
    function isEmpty():Bool {
        if (children_.length == 0)
            return true;
        for (node in children_) {
            if (!(node.text_ == '' && node.image == null))
                return false;
        }
        return true;
    }

    /** Return length of children text. */
    @:allow(glaze.kit.base.text)
    function textLen():Int {
        var len = 0;
        for (node in children_)
            len += TextUtils.len(node.text_);
        return len;
    }

    @:allow(glaze.kit.base.text)
    function merge(other:Paragraph):Void {
        for (child in other.children_)
            children_.push(child);
        invalidateRenderCache();
    }

    @:allow(glaze.kit.base.text)
    function selectedText():String {
        final text = new StringBuf();

        for (c in children_) {
            final state = c.state;
            if (state.selection != null) {
                text.add(TextUtils.slice(state.text, state.selection.start, state.selection.end));
            }
            if (c.custom != null && c.customSelection.value) {
                text.add(c.custom.asText());
            }
        }

        if (state.selection != null) {
            text.add(TextUtils.slice(state.text, state.selection.start, state.selection.end));
        }

        return text.toString();
    }

    /** Map the current rendered selection to its exact Markdown source range. */
    @:allow(glaze.kit.base.text)
    function selectedSourceRange():SourceRangeSelection {
        final selected = SourceRangeSelection.unselected();
        var run:Array<RunChild> = [];
        var offset = 0;
        final pendingImages:Array<Null<Span>> = [];
        var entersImage = true;

        function includeRun(state:InlineState, run:Array<RunChild>):{range:SourceRangeSelection, run:RunSelection} {
            final selection = state.selection;
            if (selection == null) {
                return {range: SourceRangeSelection.unselected(), run: new RunSelection()};
            }
            if (selection.start >= selection.end) {
                return {range: SourceRangeSelection.unselected(), run: new RunSelection()};
            }

            final runSelection = new RunSelection();
            runSelection.atStart = selection.start == 0;
            runSelection.atEnd = selection.end >= TextUtils.len(state.text);
            final mapped = SourceRangeSelection.unselected();
            var renderedEnd = selection.start;
            for (item in run) {
                final start = item.offset;
                final child = item.node;
                final end = start + TextUtils.len(child.text_);
                final lo = selection.start > start ? selection.start : start;
                final hi = selection.end < end ? selection.end : end;
                if (lo >= hi) {
                    continue;
                }
                runSelection.emitted = true;
                if (lo > renderedEnd) {
                    return {range: SourceRangeSelection.unmapped(), run: runSelection};
                }
                final range = child.selectedSourceRange(new Range(lo - start, hi - start));
                if (range == null) {
                    return {range: SourceRangeSelection.unmapped(), run: runSelection};
                }
                mapped.merge(SourceRangeSelection.mapped(range));
                if (hi > renderedEnd)
                    renderedEnd = hi;
            }
            if (renderedEnd < selection.end) {
                return {range: SourceRangeSelection.unmapped(), run: runSelection};
            } else {
                return {range: mapped, run: runSelection};
            }
        }

        function mergeImages(selected:SourceRangeSelection, images:Array<Null<Span>>) {
            for (span in images) {
                selected.merge(span != null ? SourceRangeSelection.mapped(new Range(span.start, span.end)) : SourceRangeSelection.unmapped());
            }
            images.resize(0);
        }

        for (child in children_) {
            if (child.custom != null) {
                final result = includeRun(child.state, run);
                final runSelection = result.run;
                if (runSelection.emitted && runSelection.atStart) {
                    mergeImages(selected, pendingImages);
                }
                selected.merge(result.range);

                if (child.customSelection.value) {
                    if (run.length == 0 || (runSelection.emitted && runSelection.atEnd)) {
                        mergeImages(selected, pendingImages);
                    }
                    final sourceRange = child.custom.sourceRange();
                    selected.merge(sourceRange != null ? SourceRangeSelection.mapped(sourceRange) : SourceRangeSelection.unmapped());
                    entersImage = true;
                } else {
                    entersImage = false;
                }
                pendingImages.resize(0);
                run = [];
                offset = 0;
                continue;
            }
            if (child.image != null) {
                final image = child.image;
                final runBefore = run.length > 0;
                final result = includeRun(child.state, run);
                final runSelection = result.run;
                if (runSelection.emitted && runSelection.atStart) {
                    mergeImages(selected, pendingImages);
                }
                selected.merge(result.range);
                if (runBefore) {
                    entersImage = runSelection.emitted && runSelection.atEnd;
                }
                if (entersImage) {
                    pendingImages.push(image.span);
                } else {
                    pendingImages.resize(0);
                }
                run = [];
                offset = 0;
                continue;
            }
            run.push(new RunChild(offset, child));
            offset += TextUtils.len(child.text_);
        }

        final trailingResult = includeRun(state, run);
        final trailing = trailingResult.run;
        if (trailing.emitted && trailing.atStart) {
            mergeImages(selected, pendingImages);
        }
        selected.merge(trailingResult.range);
        if (!trailing.emitted && entersImage && !selected.isUnselected()) {
            mergeImages(selected, pendingImages);
        }
        return selected;
    }

    /**
     * Reconstruct the Markdown source for the current selection.
     *
     * Mirrors `selectedText`, but emits Markdown instead of the rendered
     * text, using each inline node's `marks`.
     *
     * Selection offsets index an `InlineState.text`, and one such state
     * spans *several* children: `Paragraph.render` concatenates children
     * until it hits an inline image, stores that run in the image child's
     * state, then starts over; whatever follows the last image is stored in
     * `this.state`. So walk the children in the same runs and map each
     * selected byte back to the child it was rendered from.
     *
     * An image has no selection of its own, so it is emitted when the
     * selection runs into it: reaching the end of the run before it, and
     * starting at the beginning of the run after it. A paragraph that begins
     * or ends with an image has no run on that side, which counts as
     * reaching it.
     */
    @:allow(glaze.kit.base.text)
    function selectedSource():String {
        return selectedMarkdown().finish();
    }

    /** How many styles the selection within this paragraph takes in. */
    @:allow(glaze.kit.base.text)
    function selectionStyles():SelectionStyles {
        return selectedMarkdown().styles();
    }

    /** The selection as Markdown pieces, before their marks are serialized. */
    function selectedMarkdown():MarkdownSource {
        final source = new MarkdownSource();
        final pendingImages:Array<String> = [];
        var run:Array<RunChild> = [];
        var offset = 0;
        var entersImage = true;

        for (child in children_) {
            if (child.custom != null) {
                final selected = MarkdownSource.emitRun(child.state, run, pendingImages, source);
                final objectSelected = child.customSelection.value;
                if (objectSelected) {
                    if (run.length == 0 || (selected.emitted && selected.atEnd)) {
                        source.pushImages(pendingImages);
                    }
                    source.pushObject(child);
                }
                pendingImages.resize(0);
                entersImage = objectSelected;
                run = [];
                offset = 0;
                continue;
            }
            final image = child.image;
            if (image == null) {
                run.push(new RunChild(offset, child));
                offset += TextUtils.len(child.text_);
                continue;
            }

            // The run before an image is stored in that image's own state.
            final runBefore = run.length > 0;
            final selected = MarkdownSource.emitRun(child.state, run, pendingImages, source);
            if (runBefore) {
                entersImage = selected.emitted && selected.atEnd;
            }
            if (entersImage) {
                pendingImages.push(MarkdownSource.imageMarkdown(image));
            } else {
                pendingImages.resize(0);
            }

            run = [];
            offset = 0;
        }

        final trailing = MarkdownSource.emitRun(state, run, pendingImages, source);
        // Trailing images have no run after them to flush them.
        if (!trailing.emitted && entersImage && !source.isEmpty()) {
            source.pushImages(pendingImages);
        }

        return source;
    }

    @:allow(glaze.kit.base.text)
    function text():String {
        final text = new StringBuf();
        for (node in children_) {
            text.add(node.text_);
        }
        return text.toString();
    }

    /**
     * Whether this paragraph carries a selection, even an empty one.
     */
    @:allow(glaze.kit.base.text)
    function hasSelection():Bool {
        for (c in children_) {
            if (c.state.selection != null || c.customSelection.value)
                return true;
        }
        return state.selection != null;
    }

    /**
     * Synchronously clear the selection stored in every inline state.
     *
     * Mirrors the `selectedText` traversal.
     */
    @:allow(glaze.kit.base.text)
    function clearSelection():Void {
        for (c in children_) {
            c.customSelection.value = false;
            c.state.selection = null;
        }
        state.selection = null;
    }

    @:allow(glaze.kit.base.text)
    function toMarkdown():String {
        var anyCustom = false;
        for (node in children_) {
            if (node.custom != null) {
                anyCustom = true;
                break;
            }
        }
        if (anyCustom) {
            final source = new MarkdownSource();
            for (node in children_) {
                if (node.custom != null) {
                    source.pushObject(node);
                } else {
                    source.pushText(node.text_, node.marks_, new Range(0, TextUtils.len(node.text_)));
                    if (node.image != null) {
                        source.pushStr(MarkdownSource.imageMarkdown(node.image));
                    }
                }
            }
            return source.finish() + '\n\n';
        }
        final buf = new StringBuf();
        for (textNode in children_) {
            var text = textNode.text_;
            for (item in textNode.marks_) {
                final style = item.mark;
                final slice = TextUtils.slice(textNode.text_, item.range.start, item.range.end);
                if (style.bold) {
                    text = '**$slice**';
                }
                if (style.italic) {
                    text = '*$slice*';
                }
                if (style.strikethrough) {
                    text = '~~$slice~~';
                }
                if (style.code) {
                    text = '`$slice`';
                }
                if (style.highlight != null) {
                    text = '==$slice==';
                }
                if (style.link != null) {
                    text = '[$slice](${style.link.url})';
                }
            }

            if (textNode.image != null) {
                final image = textNode.image;
                final alt = image.alt != null ? image.alt : '';
                final title = image.title != null ? ' "${image.title}"' : '';
                text += '![$alt](${image.url}$title)';
            }

            buf.add(text);
        }

        return buf.toString() + '\n\n';
    }

}

/** A child of a rendered run with its offset in the run's text. */
class RunChild {

    public final offset:Int;
    public final node:InlineNode;

    public inline function new(offset:Int, node:InlineNode) {
        this.offset = offset;
        this.node = node;
    }

}

/**
 * How a selection covers one rendered run, so the caller can tell whether
 * it continues into an adjacent inline image.
 */
class RunSelection {

    public var emitted:Bool = false;
    public var atStart:Bool = false;
    public var atEnd:Bool = false;

    public function new() {}

}

/**
 * Keep syntax and marks separate until all selected runs and atomic objects
 * have been collected. Wrapping every run independently creates adjacent
 * `*` delimiters that can turn italic formulas into bold ones when pasted.
 */
class MarkdownSource {

    final pieces:Array<{text:String, layers:Array<TextMark>}> = [];

    /**
     * Whether an inline object or image was emitted, whose rendered text
     * stands in for source that spells out more.
     */
    var hasObjects:Bool = false;

    public function new() {}

    public function pushStr(source:String):Void {
        pushMarked(source, new TextMark());
    }

    public function pushMarked(source:String, mark:TextMark):Void {
        if (source == '') {
            return;
        }
        // Outer-to-inner order for equally extensive marks. When a mark spans
        // more neighboring pieces, serialize it outside the shorter marks.
        final layers:Array<TextMark> = [];
        if (mark.link != null) {
            layers.push(new TextMark().withLink(mark.link.clone()));
        }
        if (mark.highlight != null) {
            layers.push(new TextMark().withHighlight(mark.highlight));
        }
        if (mark.underline) {
            layers.push(new TextMark().withUnderline());
        }
        if (mark.strikethrough) {
            layers.push(new TextMark().withStrikethrough());
        }
        if (mark.bold) {
            layers.push(new TextMark().withBold());
        }
        if (mark.italic) {
            layers.push(new TextMark().withItalic());
        }
        if (mark.code) {
            layers.push(new TextMark().withCode());
        }
        pieces.push({text: source, layers: layers});
    }

    public function pushText(text:String, marks:Array<RangedMark>, selection:Range):Void {
        final textLen = TextUtils.len(text);
        final start = selection.start < textLen ? selection.start : textLen;
        final end = selection.end < textLen ? selection.end : textLen;
        if (start >= end) {
            return;
        }
        var cursor = start;
        for (item in marks) {
            final lo = item.range.start > start ? item.range.start : start;
            final hi = item.range.end < end ? item.range.end : end;
            if (lo >= hi) {
                continue;
            }
            if (cursor < lo) {
                pushStr(TextUtils.slice(text, cursor, lo));
            }
            pushMarked(TextUtils.slice(text, lo, hi), item.mark);
            cursor = hi;
        }
        if (cursor < end) {
            pushStr(TextUtils.slice(text, cursor, end));
        }
    }

    public function pushImages(images:Array<String>):Void {
        if (images.length == 0) {
            return;
        }
        hasObjects = true;
        pushStr(images.join(''));
    }

    public function pushObject(node:InlineNode):Void {
        hasObjects = true;
        final mark = new TextMark();
        for (layer in node.marks_) {
            mark.merge(layer.mark.clone());
        }
        pushMarked(node.custom.toMarkdown(), mark);
    }

    public function isEmpty():Bool {
        return pieces.length == 0;
    }

    static function layersEqual(a:Array<TextMark>, b:Array<TextMark>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

    public function styles():SelectionStyles {
        if (isEmpty()) {
            return None;
        }
        if (!hasObjects) {
            var same = true;
            for (i in 1...pieces.length) {
                if (!layersEqual(pieces[i - 1].layers, pieces[i].layers)) {
                    same = false;
                    break;
                }
            }
            if (same)
                return One;
        }
        return Mixed;
    }

    static function containsMark(layers:Array<TextMark>, mark:TextMark):Bool {
        for (layer in layers) {
            if (layer.equals(mark))
                return true;
        }
        return false;
    }

    static function write(pieces:Array<{text:String, layers:Array<TextMark>}>, from:Int, to:Int):String {
        final out = new StringBuf();
        var offset = from;
        while (offset < to) {
            // The mark of this piece that the most following pieces share
            // (the first one on ties, like `reduce` keeping `best`).
            var best:Null<TextMark> = null;
            var bestCount = 0;
            for (mark in pieces[offset].layers) {
                var count = 0;
                var k = offset;
                while (k < to && containsMark(pieces[k].layers, mark)) {
                    count++;
                    k++;
                }
                if (best == null || count > bestCount) {
                    best = mark;
                    bestCount = count;
                }
            }
            if (best == null) {
                out.add(pieces[offset].text);
                offset += 1;
                continue;
            }
            for (k in offset...offset + bestCount) {
                final layers = pieces[k].layers;
                var i = 0;
                while (i < layers.length) {
                    if (layers[i].equals(best))
                        layers.splice(i, 1);
                    else
                        i++;
                }
            }
            final content = write(pieces, offset, offset + bestCount);
            out.add(wrapWithMark(content, best));
            offset += bestCount;
        }
        return out.toString();
    }

    public function finish():String {
        return write(pieces, 0, pieces.length);
    }

    /**
     * Wrap `text` with the Markdown syntax implied by `mark`.
     *
     * This mirrors the per-mark formatting in `Paragraph.toMarkdown` but
     * operates on an already-sliced run, so it can reconstruct the Markdown
     * source for a *partial* text selection. Applied inside-out (innermost
     * markup first) so nested emphasis like `**_x_**` round-trips.
     */
    public static function wrapWithMark(text:String, mark:TextMark):String {
        if (text == '') {
            return '';
        }

        var out = text;
        if (mark.code) {
            out = '`$out`';
        }
        if (mark.italic) {
            out = '*$out*';
        }
        if (mark.bold) {
            out = '**$out**';
        }
        if (mark.strikethrough) {
            out = '~~$out~~';
        }
        if (mark.underline) {
            // Markdown has no underline syntax, and `__` reads as bold to most
            // parsers, so fall back to the inline HTML `<u>` parses from.
            out = '<u>$out</u>';
        }
        if (mark.highlight != null) {
            out = '==$out==';
        }
        if (mark.link != null) {
            final link = mark.link;
            out = link.title != null ? '[$out](${link.url} "${link.title}")' : '[$out](${link.url})';
        }
        return out;
    }

    /**
     * Emit the selected part of one rendered run, preceded by the images the
     * selection has run into. `run` holds the run's children with their
     * offset into the run's concatenated text (Rust free `emit_run`).
     */
    public static function emitRun(state:InlineState, run:Array<RunChild>, pendingImages:Array<String>, out:MarkdownSource):RunSelection {
        final selected = new RunSelection();
        final selection = state.selection;
        if (selection == null) {
            return selected;
        }
        if (selection.start >= selection.end) {
            return selected;
        }

        selected.atStart = selection.start == 0;
        selected.atEnd = selection.end >= TextUtils.len(state.text);

        for (item in run) {
            final start = item.offset;
            final child = item.node;
            final end = start + TextUtils.len(child.text_);
            final lo = selection.start > start ? selection.start : start;
            final hi = selection.end < end ? selection.end : end;
            if (lo >= hi) {
                continue;
            }

            if (!selected.emitted) {
                if (selected.atStart) {
                    out.pushImages(pendingImages);
                }
                pendingImages.resize(0);
            }
            selected.emitted = true;

            out.pushText(child.text_, child.marks_, new Range(lo - start, hi - start));
        }

        return selected;
    }

    /** The Markdown source for an inline image, e.g. `![alt](url "title")`. */
    public static function imageMarkdown(image:ImageNode):String {
        final alt = image.alt != null ? image.alt : '';
        final title = image.title != null ? ' "${image.title}"' : '';
        return '![$alt](${image.url}$title)';
    }

    /**
     * Reconstruct the Markdown source for the `selection` sub-range of a
     * text run carrying `marks` (test helper of the original).
     */
    public static function reconstructMarkdown(text:String, marks:Array<RangedMark>, selection:Range):String {
        final source = new MarkdownSource();
        source.pushText(text, marks, selection);
        return source.finish();
    }

}
