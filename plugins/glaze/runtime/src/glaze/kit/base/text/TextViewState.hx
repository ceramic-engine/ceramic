// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.ListAlignment;
import glaze.ListState;
import glaze.Model;
import glaze.OperatingSystem;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.TextStyle;
import glaze.Window;
import glaze.kit.base.AutoScroll;
import glaze.kit.base.TextSelection;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.input.InputActions.SelectAll;
import glaze.kit.base.input.TouchSelectionSnapshot;
import glaze.kit.base.text.RangeHighlightError;
import glaze.kit.base.text.TextViewSelectionAdapter.BoundsPoints;
import glaze.kit.base.text.RenderedText.RenderedIndexCell;
import glaze.util.Utf8;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.AbsoluteLengthTools;
using glaze.kit.base.ElementExt;

/** Rust `ParsedContent`: a parsed document with the node context it was parsed with. */
class ParsedContent {

    public var document:ParsedDocument;

    public var nodeCx:NodeContext;

    public function new(?document:ParsedDocument, ?nodeCx:NodeContext) {
        this.document = document != null ? document : new ParsedDocument();
        this.nodeCx = nodeCx != null ? nodeCx : new NodeContext();
    }

    public function clone():ParsedContent {
        return new ParsedContent(document.clone(), nodeCx.clone());
    }

    public function equals(other:Null<ParsedContent>):Bool {
        return other != null && document.equals(other.document) && nodeCx.equals(other.nodeCx);
    }

}

/**
 * The state of a TextView.
 */
class TextViewState extends Model implements Render {

    static inline final CONTEXT = 'TextView';
    /** Keep coalescing bounded so sustained streams still render intermediate updates. */
    static inline final MAX_COALESCED_UPDATES_PER_PARSE = 64;
    /**
     * Preserve exact first-layout height for small documents while bounding
     * the amount of source parsed synchronously on the UI thread.
     */
    static inline final MAX_SYNC_FULL_REPLACE_BYTES = 4 * 1024;
    /** Repaint a streamed fade at about 30 fps, not at the display refresh rate. */
    static inline final STREAM_FADE_TICK = 0.033;

    public static function init(cx:App):Void {
        final macos = OperatingSystem.current == Mac;
        cx.bindKeys([
            new KeyBinding(macos ? 'cmd-c' : 'ctrl-c', new Copy(), CONTEXT),
            new KeyBinding(macos ? 'cmd-a' : 'ctrl-a', new SelectAll(), CONTEXT),
        ]);
    }

    final _entityId:Int;
    @:allow(glaze.kit.base.text) final focusHandle:FocusHandle;
    @:allow(glaze.kit.base.text) final listState:ListState;

    /** The bounds of the text view */
    var _bounds:Bounds = new Bounds();

    @:allow(glaze.kit.base.text) var selectable:Bool = false;
    @:allow(glaze.kit.base.text) var selectionFormat:SelectionFormat = Plain;
    @:allow(glaze.kit.base.text) var scrollable:Bool = false;
    @:allow(glaze.kit.base.text) var maxLines:Null<Int> = null;
    /**
     * Line spans reported by `Inline` during prepaint (collected only while
     * `maxLines` is set); cleared by `TextView` at each frame start.
     */
    @:allow(glaze.kit.base.text) final lineSpans:Array<LineSpan> = [];
    /** Whether the last painted frame clipped content due to `maxLines`. */
    @:allow(glaze.kit.base.text) var clamped:Bool = false;
    @:allow(glaze.kit.base.text) var textViewStyle:TextViewStyle;
    @:allow(glaze.kit.base.text) var codeBlockActions:Null<CodeBlockActionsFn> = null;
    @:allow(glaze.kit.base.text) var codeBlockHighlighter:Null<CodeBlockHighlighterFn> = null;
    @:allow(glaze.kit.base.text) var tableActions:Null<TableActionsFn> = null;
    @:allow(glaze.kit.base.text) var imageSource:Null<ImageSourceFn> = null;
    @:allow(glaze.kit.base.text) var linkClickHandler:Null<LinkClickHandlerFn> = null;
    @:allow(glaze.kit.base.text) var markdownExtensions:MarkdownExtensions;

    @:allow(glaze.kit.base.text) var _isSelecting:Bool = false;
    /** Logical ranges retained across compatible resource or presentation reflow. */
    @:allow(glaze.kit.base.text) var preserveInlineSelection:Bool = false;
    var _multiClickSelection:Null<TextViewMultiClickSelection> = null;
    var selectedTextOverride:Null<String> = null;
    var _selectAll:Bool = false;
    @:allow(glaze.kit.base.text) final autoScroll:AutoScroll = new AutoScroll();
    @:allow(glaze.kit.base.text) final selectionAdapter:TextViewSelectionAdapter;

    @:allow(glaze.kit.base.text) var parsedContent:ParsedContent = new ParsedContent();
    @:allow(glaze.kit.base.text) final streamFade:StreamFadeTracker = new StreamFadeTracker();
    var fadeTick:Null<glaze.Task<glaze.Unit>> = null;
    /**
     * Content format (markdown / html), used for bounded synchronous parsing of
     * small full-replace updates.
     */
    final format:TextViewFormat;
    var text:String;
    /**
     * The text a `TextView` element last handed over, to recognize the same
     * string next frame without comparing its bytes.
     */
    var elementText:Null<String> = null;
    var revision:Int = 0;
    /** The revision of the update `parsedContent` was committed from. */
    var committedRevision:Int = 0;
    /** The revision of the last update that replaced the text rather than appending to it. */
    var fullUpdateRevision:Int = 0;
    /** The rendered text of `parsedContent`, built when first read. */
    var renderedIndex:RenderedIndexCell = new RenderedIndexCell();
    var rangeHighlights:Null<RangeHighlightFrame> = null;
    @:allow(glaze.kit.base.text) var pendingReveal:Null<PendingReveal> = null;
    @:allow(glaze.kit.base.text) var selectionRevision:Int = 0;
    var compatibleLayoutUpdate:Bool = false;
    var layoutTextStyle:Null<{style:TextStyle, remSize:Float}> = null;
    var parsedError:Null<String> = null;
    /** Rust's channel to the background parser (`tx`) and the parser itself (`_parse_task`). */
    final updateFuture:UpdateFuture;

    /** Create a Markdown TextViewState. */
    public static function markdown(text:String, cx:Context<TextViewState>):TextViewState {
        return new TextViewState(Markdown, text, cx);
    }

    /** Create a HTML TextViewState. */
    public static function html(text:String, cx:Context<TextViewState>):TextViewState {
        return new TextViewState(Html, text, cx);
    }

    /** Create a new TextViewState. */
    function new(format:TextViewFormat, text:String, cx:Context<TextViewState>) {
        super();
        _entityId = cx.entityId();
        focusHandle = cx.focusHandle();
        textViewStyle = TextViewStyle.defaultValue();
        markdownExtensions = new MarkdownExtensions();
        selectionAdapter = new TextViewSelectionAdapter(cx.weakEntity(), cx.app);
        // Measure all blocks (not just visible ones) so the scrollbar thumb
        // size stays stable.
        listState = new ListState(0, ListAlignment.Top, 1000.).measureAll();
        this.format = format;
        this.text = text;

        // Rust spawns a receive task that commits the background parser's
        // results; here the parser hands them over through `deliver`, which
        // runs on the foreground like the task.
        final weakSelf = cx.weakEntity();
        final app = cx.app;
        updateFuture = new UpdateFuture(format, app, parsedUpdate -> {
            final state = weakSelf.upgrade();
            if (state == null) return;
            // A result that commits nothing (the background parser
            // acknowledging a synchronous parse) leaves the state alone.
            if (!state.read(app).commits(parsedUpdate)) {
                return;
            }
            state.update(app, (state, cx) -> state.commitParsedUpdate(parsedUpdate, cx));
        });

        incrementUpdate(text, false, cx);
    }

    override function destroy() {
        updateFuture.close();
        if (fadeTick != null) fadeTick.cancel();
        autoScroll.stop();
        super.destroy();
    }

    /** Get the text content. */
    public function source():String {
        return parsedContent.document.source;
    }

    /** Set whether the text is selectable, default false (builder). */
    public function withSelectable(selectable:Bool):TextViewState {
        this.selectable = selectable;
        return this;
    }

    /** Set whether the text is selectable, default false. */
    public function setSelectable(selectable:Bool, cx:Context<TextViewState>):Void {
        this.selectable = selectable;
        cx.notify();
    }

    /** Set the `SelectionFormat`, default is `SelectionFormat.Plain` (builder). */
    public function withSelectionFormat(selectionFormat:SelectionFormat):TextViewState {
        this.selectionFormat = selectionFormat;
        return this;
    }

    /** Set the `SelectionFormat`, default is `SelectionFormat.Plain`. */
    public function setSelectionFormat(selectionFormat:SelectionFormat, cx:Context<TextViewState>):Void {
        this.selectionFormat = selectionFormat;
        cx.notify();
    }

    /** Set whether the text view scrolls internally, default false (builder). */
    public function withScrollable(scrollable:Bool):TextViewState {
        this.scrollable = scrollable;
        return this;
    }

    /** Set whether the text view scrolls internally, default false. */
    public function setScrollable(scrollable:Bool, cx:Context<TextViewState>):Void {
        if (!scrollable) {
            resetSelectionAndAdapter(cx.app);
        }
        this.scrollable = scrollable;
        cx.notify();
    }

    /** Whether the last painted frame clipped content because of `TextView.maxLines`. */
    public function isClamped():Bool {
        return clamped;
    }

    /**
     * Set the text content.
     *
     * Markdown that extends the current non-empty text is appended like
     * `pushStr`, keeping the selection; any other text replaces it. With a
     * streamed fade-in enabled, extended text fades in; a replacement shows at
     * once.
     */
    public function setText(text:String, cx:Context<TextViewState>):Void {
        if (this.text == text) {
            return;
        }
        // HTML blocks carry no spans, so an append would parse the delta as a
        // standalone document. After a failed parse the background parser's
        // document lacks that text, so only a full parse resynchronizes it.
        if (format == Markdown && parsedError == null && this.text.length > 0 && StringTools.startsWith(text, this.text)) {
            final delta = text.substr(this.text.length);
            pushStr(delta, cx);
            return;
        }
        streamFade.noteReplace();

        this.text = text;
        parsedError = null;
        incrementUpdate(text, false, cx);
    }

    /**
     * `setText` for the text a `TextView` element hands over every frame: the
     * string it handed over last time is recognized without a comparison, as
     * long as the state still holds a text of its length.
     *
     * Haxe strings have no identity to compare: the same string compares equal
     * here, which is what Rust's pointer test stands for.
     */
    @:allow(glaze.kit.base.text)
    function setElementText(text:String, cx:Context<TextViewState>):Void {
        final sameString = elementText != null && elementText == text;
        if (sameString && this.text.length == text.length) {
            return;
        }
        elementText = text;
        setText(text, cx);
    }

    /** Append partial text content to the existing text. */
    public function pushStr(newText:String, cx:Context<TextViewState>):Void {
        if (newText.length == 0) {
            return;
        }
        streamFade.noteExtend(Utf8.byteLength(text));
        text += newText;
        incrementUpdate(newText, true, cx);
    }

    /** Set the motion policy; see `TextViewMotion` (builder). */
    public function withMotion(motion:TextViewMotion):TextViewState {
        setMotion(motion);
        return this;
    }

    /** Set the motion policy; see `TextViewMotion`. */
    public function setMotion(motion:TextViewMotion):Void {
        streamFade.setMotion(motion);
    }

    @:allow(glaze.kit.base.text)
    function setMarkdownExtensions(markdownExtensions:MarkdownExtensions, cx:Context<TextViewState>):Void {
        if (@:privateAccess this.markdownExtensions.revision() == @:privateAccess markdownExtensions.revision()) {
            return;
        }

        final parserConfigurationChanged = !@:privateAccess this.markdownExtensions.hasSameParserConfiguration(markdownExtensions);
        this.markdownExtensions = markdownExtensions;
        if (parserConfigurationChanged && format == Markdown) {
            final text = this.text;
            incrementUpdate(text, false, cx);
        }
    }

    /** Return the selected text, in the view's `SelectionFormat`. */
    public function selectedText():String {
        return selectedTextIn(null);
    }

    /**
     * Return the original Markdown source byte range corresponding to the
     * rendered selection.
     *
     * HTML views and selections without an exact source mapping return
     * `null`. Select-all in a Markdown view returns the full source range.
     */
    public function selectedSourceRange():Null<Range> {
        if (format != Markdown) {
            return null;
        }
        if (_selectAll) {
            return new Range(0, Utf8.byteLength(source()));
        }
        return @:privateAccess parsedContent.document.selectedSourceRange();
    }

    /**
     * The format to copy in, which is `SelectionFormat.Plain` whenever the
     * requested one cannot be produced: only a Markdown view can return source.
     */
    function effectiveFormat():SelectionFormat {
        return switch format {
            case Markdown: selectionFormat;
            case Html: Plain;
        }
    }

    /**
     * A pending full replacement leaves the previous document on screen, but
     * that document must no longer supply clipboard content.
     */
    @:allow(glaze.kit.base.text)
    function hasCurrentCopyDocument():Bool {
        return committedRevision >= fullUpdateRevision;
    }

    /**
     * Return the selected text, with `blocks` (an inclusive `[start, end]`)
     * bounding which top-level blocks the selection covers.
     */
    @:allow(glaze.kit.base.text)
    function selectedTextIn(blocks:Null<Array<Int>>):String {
        final format = effectiveFormat();

        if (_selectAll) {
            if (format != Plain) {
                return source();
            }

            return @:privateAccess parsedContent.document.text();
        }

        // A multi-click stores the plain text it selected, which is a shortcut
        // past the block walk. Source mode cannot take it: the word it stored
        // has lost its markup.
        if (format == Plain && selectedTextOverride != null) {
            return selectedTextOverride;
        }

        return @:privateAccess parsedContent.document.selectedText(format, blocks);
    }

    /**
     * Force a full re-measure of the block list after the document has been
     * replaced (the list only resets when the block count changes).
     */
    function invalidateMeasuredHeights():Void {
        final count = listState.itemCount();
        if (count > 0) {
            listState.remeasureItems(0, count);
        }
    }

    /**
     * Remeasure inline resources after their prepared content or metrics
     * change. This does not reparse the document. Existing logical selection
     * is retained until the next selection gesture.
     */
    public function invalidateInlineLayout(cx:Context<TextViewState>):Void {
        preserveSelectionForReflow();
        cx.notify();
    }

    @:allow(glaze.kit.base.text)
    function preserveSelectionForReflow():Void {
        preserveInlineSelection = true;
        compatibleLayoutUpdate = true;
        invalidateMeasuredHeights();
    }

    function incrementUpdate(text:String, append:Bool, cx:Context<TextViewState>):Void {
        revision += 1;
        if (!append) {
            fullUpdateRevision = revision;
            selectionRevision = selectionRevision + 1;
            // Old native layouts must not project a still-active gesture back
            // into replaced content, including while a large parse is pending.
            selectionAdapter.clearCopyProjections(cx.app);
            @:privateAccess parsedContent.document.clearSelection();
        }
        final parseSynchronously = !append && Utf8.byteLength(text) <= MAX_SYNC_FULL_REPLACE_BYTES;
        final updateOptions = new UpdateOptions(revision, text, append,
            append ? Compatible : (parseSynchronously ? BaselineAck : Replace),
            markdownExtensions);

        // Keep small full replacements synchronous so their first layout has
        // the exact content height. Larger replacements use the background
        // parser.
        if (parseSynchronously) {
            try {
                final content = UpdateFuture.parseContent(format, new ParsedContent(), updateOptions);
                reconcileRangeHighlights(content.document, revision, false);
                streamFade.record(parsedContent.document, content.document, cx.backgroundExecutor().now());
                parsedContent = content;
                parsedError = null;
                invalidateMeasuredHeights();
                if (!_isSelecting) {
                    resetSelectionAndAdapter(cx.app);
                }
            }
            catch (error:String) {
                streamFade.discardPending();
                parsedError = error;
            }
            // Keep the background parser's accumulated document in sync so a
            // later append extends this baseline instead of parsing the delta
            // as a standalone document.
            updateFuture.trySend(updateOptions);
            cx.notify();
            return;
        }

        updateFuture.trySend(updateOptions);
    }

    /**
     * Whether `commitParsedUpdate` commits `parsedUpdate`: it is not older than
     * what is committed or than the last replacement, nor the background
     * parser acknowledging a synchronous parse.
     */
    function commits(parsedUpdate:ParsedUpdate):Bool {
        if (parsedUpdate.revision < fullUpdateRevision || parsedUpdate.revision <= committedRevision) {
            return false;
        }
        return !parsedUpdate.baselineAck;
    }

    /**
     * Commit a result of the background parser.
     *
     * A result parsed since the text was last replaced is a prefix of the
     * current text and is committed; one from before that replacement, or
     * older than what is already committed, is discarded.
     */
    function commitParsedUpdate(parsedUpdate:ParsedUpdate, cx:Context<TextViewState>):Void {
        if (!commits(parsedUpdate)) {
            return;
        }

        final content = parsedUpdate.content;
        if (content != null) {
            final append = parsedUpdate.selectionCompatible && !parsedUpdate.fullParse;
            if (append && fullUpdateRevision <= committedRevision) {
                spliceAppendedBlocks(content.document);
            }
            reconcileRangeHighlights(content.document, parsedUpdate.revision, append);
            streamFade.record(parsedContent.document, content.document, cx.backgroundExecutor().now());
            // This result may cover only part of the queued appends. Keep the
            // uncommitted tail pending from this document's end, rather than
            // consuming its fade with the earlier chunk.
            if (parsedUpdate.revision < revision) {
                streamFade.noteExtend(Utf8.byteLength(content.document.source));
            }
            parsedContent = content;
            parsedError = null;
            compatibleLayoutUpdate = parsedUpdate.selectionCompatible;
            if (parsedUpdate.fullParse) {
                invalidateMeasuredHeights();
            }
        }
        else {
            streamFade.discardPending();
            parsedError = parsedUpdate.error;
        }
        // Don't interrupt an active drag-selection; the stored positions remain
        // valid for append-only updates and will self-correct on the next
        // mouse-move event.
        if (!parsedUpdate.selectionCompatible && !_isSelecting) {
            resetSelectionAndAdapter(cx.app);
        }
        cx.notify();
    }

    /**
     * The text this view renders, which `RangeHighlight` ranges index.
     *
     * This is the string plain copy produces, as of the last parse that
     * landed; text set since then is not in it until its parse lands.
     */
    public function renderedText():RenderedText {
        return new RenderedText(_entityId, committedRevision, parsedContent.document, renderedIndex);
    }

    /**
     * Replace the range highlights, whose ranges index the current rendered
     * text. Any invalid range rejects the set: throws `RangeHighlightException`
     * (Rust `Err(RangeHighlightError)`).
     *
     * Highlights follow unchanged text through updates. Text backgrounds such
     * as `<mark>` paint over a highlight; inline code backgrounds paint under it.
     */
    public function setRangeHighlights(highlights:Iterable<RangeHighlight>, cx:Context<TextViewState>):Void {
        if (format != Markdown) {
            throw new RangeHighlightException(Unsupported);
        }
        final text = renderedText();
        rangeHighlights = RangeHighlightFrame.create(text, highlights);
        cx.notify();
    }

    /**
     * Scroll the line `range` starts on into view, `range` indexing the current
     * rendered text, as with `setRangeHighlights`.
     *
     * A `scrollable` view scrolls itself. Otherwise the nearest enclosing
     * `glaze.list` scrolls, as long as the row holding the view is laid out.
     * Any other scroll container scrolls through `TextView.onReveal`.
     *
     * Only the latest reveal is carried out, and it is dropped when its text
     * changes, when the view clamps its lines, or when it cannot be shown
     * within a second. Throws `RangeHighlightException` for an invalid range.
     */
    public function revealRange(range:Range, cx:Context<TextViewState>):Void {
        if (format != Markdown) {
            throw new RangeHighlightException(Unsupported);
        }
        final text = renderedText();
        if (text.isEmpty() && range.start == 0 && range.end == 0) {
            // Nothing to reveal in an empty view.
            pendingReveal = null;
            return;
        }
        final now = cx.backgroundExecutor().now();
        final reveal = PendingReveal.create(text, range, now);
        if (reveal == null) {
            throw new RangeHighlightException(InvalidRange(0));
        }
        pendingReveal = reveal;
        cx.notify();
    }

    /** Remove all range highlights. */
    public function clearRangeHighlights(cx:Context<TextViewState>):Void {
        if (rangeHighlights != null) {
            rangeHighlights = null;
            cx.notify();
        }
    }

    /**
     * Carry the range highlights over to `next`, the document the update of
     * `revision` parsed, before it replaces the current one.
     */
    function reconcileRangeHighlights(next:ParsedDocument, revision:Int, append:Bool):Void {
        final tailOnly = append && fullUpdateRevision <= committedRevision;
        committedRevision = revision;
        renderedIndex = new RenderedIndexCell();
        if (rangeHighlights != null || pendingReveal != null) {
            final remap = new LeafRemap(parsedContent.document, next, tailOnly);
            final highlights = rangeHighlights;
            rangeHighlights = highlights != null ? highlights.remap(remap) : null;
            final reveal = pendingReveal;
            pendingReveal = reveal != null ? reveal.remap(remap) : null;
        }
    }

    /**
     * Tell the scrollable list which blocks an append replaced, before `next`,
     * the appended document, replaces the current one.
     */
    function spliceAppendedBlocks(next:ParsedDocument):Void {
        final old = parsedContent.document.blocks;
        final oldCount = old.length;
        final newCount = next.blocks.length;
        if (oldCount == 0 || newCount <= oldCount || listState.itemCount() != oldCount) {
            return;
        }

        // The last block is always measured again: it was parsed again, and it
        // is no longer the last one.
        var unchanged = 0;
        while (unchanged < oldCount - 1) {
            final span = old[unchanged].span();
            if (span == null || !span.equals(next.blocks[unchanged].span())) break;
            unchanged++;
        }
        // Keeps the replaced blocks' heights as hints and the scroll offset
        // inside them, and has the next layout measure only the blocks that are
        // not measured.
        listState.remeasureItems(unchanged, oldCount);
        listState.splice(oldCount, oldCount, newCount - oldCount);
    }

    /** Save bounds and unselect if bounds changed. */
    @:allow(glaze.kit.base.text)
    function updateBounds(bounds:Bounds, _cx:App):Void {
        _bounds = bounds;
    }

    /**
     * The index of the top-level block at `contentY`, in this view's content
     * coordinates (the same space the base selection endpoint stores its point
     * in). Returns `null` for a view that is not virtualized.
     */
    @:allow(glaze.kit.base.text)
    function blockIxAt(contentY:Float):Null<Int> {
        if (!scrollable) {
            return null;
        }

        final origin = _bounds.origin.y + scrollOffset().y;
        final count = listState.itemCount();
        var ix = listState.logicalScrollTop().itemIx;
        while (ix < count) {
            final bounds = listState.boundsForItem(ix);
            if (bounds == null) return null;
            if (contentY < bounds.bottom() - origin) {
                return ix;
            }
            ix += 1;
        }

        return count > 0 ? count - 1 : null;
    }

    public function bounds():Bounds {
        return _bounds;
    }

    public function getListState():ListState {
        return listState;
    }

    public function isSelecting():Bool {
        return _isSelecting;
    }

    public function getFocusHandle():FocusHandle {
        return focusHandle;
    }

    /**
     * Whether this view has a view-local selection (select-all, multi-click,
     * or override), independent of the window-level selection.
     */
    @:allow(glaze.kit.base.text)
    function hasViewSelection():Bool {
        return _selectAll || _multiClickSelection != null || selectedTextOverride != null;
    }

    @:allow(glaze.kit.base.text)
    function stopAutoScroll():Void {
        autoScroll.stop();
    }

    @:allow(glaze.kit.base.text)
    function resetSelection():Void {
        preserveInlineSelection = false;
        _multiClickSelection = null;
        selectedTextOverride = null;
        _selectAll = false;
        _isSelecting = false;
        autoScroll.stop();
        // Clear the inline selection state synchronously, so offscreen
        // (virtualized) views that won't repaint don't leak stale selection
        // text into a new cross-view copy.
        @:privateAccess parsedContent.document.clearSelection();
    }

    function resetSelectionAndAdapter(cx:App):Void {
        resetSelection();
        selectionAdapter.setLocalSelection(false, cx);
    }

    /** Clear the current text selection. */
    public function clearSelection(cx:Context<TextViewState>):Void {
        resetSelectionAndAdapter(cx.app);
        cx.notify();
    }

    @:allow(glaze.kit.base.text)
    function scrollOffset():Point {
        return scrollable ? listState.scrollPxOffsetForScrollbar() : new Point(0, 0);
    }

    /** Select all rendered text in this view. */
    public function selectAll(cx:Context<TextViewState>):Void {
        _multiClickSelection = null;
        selectedTextOverride = null;
        _selectAll = true;
        _isSelecting = false;
        autoScroll.stop();
        selectionAdapter.setLocalSelection(true, cx.app);
        cx.notify();
    }

    /**
     * Selects what a multi-click at `pos` selected, from the caret `start` to
     * the caret `end` in window coordinates. A drag from the click extends it
     * by the same unit.
     */
    @:allow(glaze.kit.base.text)
    function setMultiClickSelection(pos:Point, kind:TextViewMultiClickKind, selectedText:String, start:Bounds, end:Bounds, cx:App):Void {
        preserveInlineSelection = false;
        final scrollOffset = this.scrollOffset();
        final pos = pos.sub(_bounds.origin).sub(scrollOffset);
        _multiClickSelection = new TextViewMultiClickSelection(pos, kind, null);
        selectedTextOverride = selectedText;
        _selectAll = false;
        _isSelecting = false;
        autoScroll.stop();
        selectionAdapter.setLocalSelection(true, cx);
        final clickCount = switch kind {
            case Word: 2;
            case Paragraph | Line: 3;
        }
        selectionAdapter.holdMultiClick(start, end, clickCount, cx);
    }

    /**
     * Hands a multi-click selection over to the window selection, which a drag
     * from the click has taken beyond what the click selected.
     */
    @:allow(glaze.kit.base.text)
    function endMultiClickSelection(cx:App):Void {
        if (_multiClickSelection != null) {
            _multiClickSelection = null;
            selectedTextOverride = null;
            selectionAdapter.setLocalSelection(false, cx);
        }
    }

    @:allow(glaze.kit.base.text)
    function setMultiClickLine(bounds:Bounds, cx:App):Void {
        setMultiClickSelection(bounds.center(), Line, '',
            TouchSelectionSnapshot.caretLineBox(bounds.origin, bounds.size.height),
            TouchSelectionSnapshot.caretLineBox(bounds.topRight(), bounds.size.height), cx);
        selectedTextOverride = null;
        final offset = _bounds.origin.add(scrollOffset());
        final selection = _multiClickSelection;
        if (selection != null) {
            _multiClickSelection = new TextViewMultiClickSelection(selection.pos, selection.kind, new Bounds(bounds.origin.sub(offset), bounds.size));
        }
    }

    @:allow(glaze.kit.base.text)
    function setAutoScroll(delta:Null<Float>, cx:Context<TextViewState>):Void {
        autoScroll.set(delta, cx, (delta, state, cx) -> {
            state.listState.scrollBy(delta);
            cx.notify();
        });
    }

    /**
     * Return the window selection (anchor, cursor) in window coordinates if
     * this view participates in it.
     */
    @:allow(glaze.kit.base.text)
    function selectionPoints(cx:App):Null<BoundsPoints> {
        if (!selectable) {
            return null;
        }
        return selectionAdapter.selectionPoints(cx);
    }

    /**
     * `selectionPoints` for the text that paints now: a drag that started in a
     * table cell selects only in that cell. Call it only while painting.
     */
    @:allow(glaze.kit.base.text)
    function paintedSelectionPoints(cx:App):Null<BoundsPoints> {
        if (!selectable) {
            return null;
        }
        return selectionAdapter.paintedSelectionPoints(cx);
    }

    @:allow(glaze.kit.base.text)
    function hasSelection(cx:App):Bool {
        return hasViewSelection() || selectionPoints(cx) != null;
    }

    @:allow(glaze.kit.base.text)
    function onActionSelectAll(_:SelectAll, _:Window, cx:Context<TextViewState>):Void {
        if (!selectable) {
            cx.propagate();
            return;
        }

        selectAll(cx);
    }

    @:allow(glaze.kit.base.text)
    function isSelectable():Bool {
        return selectable;
    }

    @:allow(glaze.kit.base.text)
    function isAllSelected():Bool {
        return _selectAll;
    }

    @:allow(glaze.kit.base.text)
    function multiClickSelection():Null<TextViewMultiClickSelection> {
        final selection = _multiClickSelection;
        if (selection == null) return null;
        final scrollOffset = this.scrollOffset();
        final pos = selection.pos.add(scrollOffset).add(_bounds.origin);
        final lineBounds = selection.lineBounds != null
            ? new Bounds(selection.lineBounds.origin.add(scrollOffset).add(_bounds.origin), selection.lineBounds.size)
            : null;
        return new TextViewMultiClickSelection(pos, selection.kind, lineBounds);
    }

    /**
     * Starts a frame of the pending reveal: the line to hand to rendering, and
     * the block a scrollable view has to scroll to first, because it is off
     * screen or the reveal is of a whole block.
     */
    function revealFrame(now:Float, window:Window):{request:Null<RevealRequest>, block:Null<Int>} {
        if (maxLines != null || (pendingReveal != null && pendingReveal.isExpired(now))) {
            pendingReveal = null;
        }
        final pending = pendingReveal;
        if (pending == null) {
            return {request: null, block: null};
        }

        final blockIx = pending.blockIx(parsedContent.document);
        function blockOffScreen(ix:Int):Bool {
            final viewport = listState.viewportBounds();
            final item = listState.boundsForItem(ix);
            return item == null || item.bottom() <= viewport.top() || item.top() >= viewport.bottom();
        }
        final revealBlock = blockIx != null && scrollable && (pending.isBlock() || !pending.wasLaidOut()) && blockOffScreen(blockIx) ? blockIx : null;
        final request = pending.request();
        if (pending.isBlock()) {
            // A block has no line to wait for.
            pendingReveal = null;
        }
        else {
            window.requestAnimationFrame();
        }
        return {request: request, block: revealBlock};
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TextViewState> = cast cx;
        final textStyle = window.textStyle();
        final remSize:Float = window.remSize();
        final bodyFontSize = textStyle.fontSize.toPixels(remSize);
        final previous = layoutTextStyle;
        if (previous != null && !(previous.style.equals(textStyle) && previous.remSize == remSize)) {
            // ListState invalidates its cached rows for width changes, but does
            // not know that an inherited font or rem change affects offscreen
            // inline metrics. Retain logical selections just as for resources.
            preserveSelectionForReflow();
        }
        layoutTextStyle = {style: textStyle, remSize: remSize};
        final state = cx.entity();
        final streamFadeFrame = streamFade.frame(cx.backgroundExecutor().now(), cx.app.reduceMotion());
        if (streamFadeFrame != null && fadeTick == null) {
            fadeTick = cx.spawn((weak, async) -> {
                return async.backgroundExecutor().timer(STREAM_FADE_TICK).map(_ -> {
                    weak.tryUpdate(async, (state, cx) -> {
                        state.fadeTick = null;
                        cx.notify();
                    });
                    glaze.Unit.unit;
                });
            });
        }
        final reveal = revealFrame(cx.backgroundExecutor().now(), window);
        // Built every frame, so everything in it is shared, not copied.
        final nodeCx = new NodeContext();
        nodeCx.offset = parsedContent.nodeCx.offset;
        nodeCx.linkRefs = parsedContent.nodeCx.linkRefs;
        nodeCx.style = textViewStyle;
        nodeCx.codeBlockActions = codeBlockActions;
        nodeCx.codeBlockHighlighter = codeBlockHighlighter;
        nodeCx.tableActions = tableActions;
        nodeCx.linkClickHandler = linkClickHandler;
        nodeCx.imageSource = imageSource;
        nodeCx.markdownExtensions = markdownExtensions;
        nodeCx.streamFade = streamFadeFrame;
        nodeCx.rangeHighlights = rangeHighlights;
        nodeCx.reveal = reveal.request;
        nodeCx.bodyFontSize = bodyFontSize;

        final content = vFlex()
            .wFull()
            // Clamped content must keep its natural height: stretching it to
            // the capped box would hide the overflow the clamp has to measure.
            .when(maxLines == null, el -> el.hFull())
            .map(el -> {
                if (parsedError == null) {
                    return el.child(@:privateAccess parsedContent.document.renderRoot(scrollable ? listState : null, nodeCx, window, cx.app));
                }
                else {
                    return el.child(vFlex().gap1().child('Failed to parse content').child(parsedError));
                }
            })
            .onPrepaint((bounds, window, cx) -> {
                final current = state.read(cx);
                final hasSelectionSnapshot = current.selectionAdapter.hasSelectionSnapshot(cx);
                final preserveWidthSelection = !current._isSelecting
                    && current.bounds().size.width != bounds.size.width
                    && (hasSelectionSnapshot || current.hasViewSelection());
                final sizeChanged = !current.bounds().size.equals(bounds.size);
                final selectionInvolvesView = current.selectionAdapter.isPartOfWindowSelection(cx);
                final isSelecting = current._isSelecting;
                // A measurement prepaint must not consume compatibility before
                // the same entity's visible column prepaints.
                final compatibleLayoutUpdate = current.compatibleLayoutUpdate
                    || preserveWidthSelection
                    || current.preserveInlineSelection;
                var revisionChanged = false;
                state.update(cx, (state, cx) -> {
                    revisionChanged = state.selectionAdapter.updateLayoutRevision(state.selectionRevision, state._isSelecting);
                    if (preserveWidthSelection) {
                        // ListState already remeasures width changes. Arm
                        // logical retention before inline paint without
                        // invalidating rows again.
                        state.preserveInlineSelection = true;
                    }
                    state.updateBounds(bounds, cx.app);
                    state.compatibleLayoutUpdate = false;
                });
                if (!isSelecting
                    && ((sizeChanged && selectionInvolvesView && !compatibleLayoutUpdate)
                        || (revisionChanged && hasSelectionSnapshot))) {
                    TextSelection.clear(window, cx);
                }
            });
        // After `renderRoot`, which resets the list when the block count
        // changed other than by an append, and with it the scroll position.
        if (reveal.block != null) {
            listState.scrollToRevealItem(reveal.block);
        }
        return content;
    }

}

/** Rust `ParseMode`. */
enum abstract ParseMode(Int) {
    var BaselineAck = 0;
    var Replace = 1;
    var Compatible = 2;
}

/** Rust `UpdateOptions`. */
class UpdateOptions {

    public var revision:Int;
    public var pendingText:String;
    public var append:Bool;
    public var mode:ParseMode;
    public var markdownExtensions:MarkdownExtensions;

    public function new(revision:Int, pendingText:String, append:Bool, mode:ParseMode, markdownExtensions:MarkdownExtensions) {
        this.revision = revision;
        this.pendingText = pendingText;
        this.append = append;
        this.mode = mode;
        this.markdownExtensions = markdownExtensions;
    }

    public function merge(next:UpdateOptions):Void {
        if (next.append) {
            pendingText += next.pendingText;
            revision = next.revision;
            if (mode != Replace) {
                mode = Compatible;
            }
        }
        else {
            revision = next.revision;
            pendingText = next.pendingText;
            append = next.append;
            mode = next.mode;
            markdownExtensions = next.markdownExtensions;
        }
    }

}

/** Rust `ParsedUpdate`: `content` is set for `Ok`, `error` for `Err`. */
class ParsedUpdate {

    public final revision:Int;
    public final fullParse:Bool;
    public final selectionCompatible:Bool;
    public final baselineAck:Bool;
    public final content:Null<ParsedContent>;
    public final error:Null<String>;

    public function new(revision:Int, fullParse:Bool, selectionCompatible:Bool, baselineAck:Bool, content:Null<ParsedContent>, error:Null<String>) {
        this.revision = revision;
        this.fullParse = fullParse;
        this.selectionCompatible = selectionCompatible;
        this.baselineAck = baselineAck;
        this.content = content;
        this.error = error;
    }

}

/**
 * The background parser (Rust `UpdateFuture`, spawned on the background
 * executor, with its update and result channels).
 *
 * The port has no threads: "background" work is dispatched like Rust's
 * background tasks, on the app's dispatcher. Each poll takes the queued
 * updates (coalescing at most `MAX_COALESCED_UPDATES_PER_PARSE`), parses them
 * onto the document it accumulated, and delivers the result, which the state
 * commits on a later dispatch, like the receive task.
 */
class UpdateFuture {

    final format:TextViewFormat;
    var content:ParsedContent = new ParsedContent();
    /** Rust's update channel (`rx`). */
    final queue:Array<UpdateOptions> = [];
    /** Rust's result channel (`rx_result`). */
    final results:Array<ParsedUpdate> = [];
    final app:App;
    final onResult:(ParsedUpdate) -> Void;
    var pollScheduled:Bool = false;
    var deliverScheduled:Bool = false;
    var closed:Bool = false;

    public function new(format:TextViewFormat, app:App, onResult:(ParsedUpdate) -> Void) {
        this.format = format;
        this.app = app;
        this.onResult = onResult;
    }

    /** Rust `tx.try_send(options)`. */
    public function trySend(options:UpdateOptions):Void {
        if (closed) return;
        queue.push(options);
        schedulePoll();
    }

    /** Drops the channels with the state: pending work is discarded. */
    public function close():Void {
        closed = true;
        queue.resize(0);
        results.resize(0);
    }

    function schedulePoll():Void {
        if (pollScheduled || closed) return;
        pollScheduled = true;
        app.backgroundExecutor().spawn(() -> {
            pollScheduled = false;
            poll();
            return glaze.Unit.unit;
        });
    }

    function poll():Void {
        while (!closed && queue.length > 0) {
            final options = queue.shift();
            final hitCoalesceBudget = mergePendingOptions(options);

            var parsed:Null<ParsedContent> = null;
            var error:Null<String> = null;
            try {
                parsed = parseContent(format, new ParsedContent(content.document, content.nodeCx), options);
                content = new ParsedContent(parsed.document, parsed.nodeCx);
            }
            catch (e:String) {
                error = e;
            }
            send(new ParsedUpdate(options.revision, !options.append, options.mode == Compatible, options.mode == BaselineAck, parsed, error));
            if (hitCoalesceBudget) {
                schedulePoll();
                return;
            }
        }
    }

    function mergePendingOptions(options:UpdateOptions):Bool {
        var updateCount = 1;
        while (updateCount < @:privateAccess TextViewState.MAX_COALESCED_UPDATES_PER_PARSE) {
            if (queue.length == 0) {
                return false;
            }
            options.merge(queue.shift());
            updateCount += 1;
        }
        return true;
    }

    function send(update:ParsedUpdate):Void {
        results.push(update);
        if (deliverScheduled) return;
        deliverScheduled = true;
        app.foregroundExecutor().dispatcher.dispatch(() -> {
            deliverScheduled = false;
            while (!closed && results.length > 0) {
                onResult(results.shift());
            }
        });
    }

    /**
     * Rust `parse_content`. Throws the parser's error message (Rust
     * `Err(SharedString)`).
     */
    public static function parseContent(format:TextViewFormat, content:ParsedContent, options:UpdateOptions):ParsedContent {
        final nodeCx = new NodeContext();
        nodeCx.markdownExtensions = options.markdownExtensions;

        // Re-parse the last block together with the appended text, so a block
        // the new text continues (an unclosed list, a fenced code block) is not
        // split in two. A block without a span cannot be located in `source`,
        // so it is left in place and only the appended text is parsed,
        // positioned at the end of the current source.
        final blocks = content.document.blocks;
        final lastSpan = options.append && blocks.length > 0 ? blocks[blocks.length - 1].span() : null;

        var source:String;
        final keptBlocks = blocks.copy();
        if (lastSpan != null) {
            keptBlocks.pop();
            nodeCx.offset = lastSpan.start;
            source = Utf8.substringFrom(content.document.source, lastSpan.start) + options.pendingText;
        }
        else {
            if (options.append) {
                nodeCx.offset = Utf8.byteLength(content.document.source);
            }
            source = options.pendingText;
        }

        final newDocument = switch format {
            case Markdown: glaze.kit.base.text.format.MarkdownFormat.parse(source, nodeCx);
            case Html: glaze.kit.base.text.format.HtmlFormat.parse(source, nodeCx);
        }

        if (options.append) {
            final document = new ParsedDocument(content.document.source + options.pendingText, keptBlocks.concat(newDocument.blocks));
            content.document = document;
        }
        else {
            content.document = newDocument;
        }

        return content;
    }

}
