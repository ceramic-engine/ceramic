// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.Model;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.ScrollHandle;
import gpui.Window;
import gpui.base.Base;
import gpui.base.TextSelectionLayer;
import gpui.base.motion.Easing;
import gpui.base.text.BlockNode;
import gpui.base.text.MarkdownExtensions;
import gpui.base.text.MarkdownNode;
import gpui.base.text.ParsedDocument;
import gpui.base.text.RangeHighlight;
import gpui.base.text.RangeHighlightError;
import gpui.base.text.SelectionFormat;
import gpui.base.text.Span;
import gpui.base.text.TextLeafKey;
import gpui.base.text.TextView;
import gpui.base.text.TextViewFormat;
import gpui.base.text.TextViewMotion;
import gpui.base.text.TextViewState;
import gpui.util.Utf8;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.text.BlockNode.BlockNodeTools;

private class FadeRoot extends Model implements Render {
    final state:Entity<TextViewState>;

    public function new(state:Entity<TextViewState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return TextView.create(state);
    }
}

private class HighlightRoot extends Model implements Render {
    public final state:Entity<TextViewState>;

    public function new(state:Entity<TextViewState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(120.)).child(TextView.create(state).selectable(true));
    }
}

private class SelectionRoot extends Model implements Render {
    public final state:Entity<TextViewState>;

    public function new(state:Entity<TextViewState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(160.)).child(new TextSelectionLayer()).child(TextView.create(state));
    }
}

/** Where the view sits in a 200 x 100 window. */
private enum Container {
    /** A scrollable view. */
    Scrollable;
    /** A fit-content view, second row of an application list. */
    List(listState:ListState);
    /** A fit-content view in a scrolling `div`, which follows reveals through `onReveal`. */
    DivScroll(handle:ScrollHandle);
    /** A fit-content view clamped to two lines, second row of a list. */
    Clamped(listState:ListState);
    /** A fit-content view in nothing that scrolls. */
    Fixed;
}

private class RevealRoot extends Model implements Render {
    public final state:Entity<TextViewState>;
    final container:Container;

    public function new(state:Entity<TextViewState>, container:Container) {
        super();
        this.state = state;
        this.container = container;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final state = this.state;
        final frame = div().w(px(200.)).h(px(100.));
        function row(listState:ListState, clamp:Bool):IntoElement {
            return list(listState, (ix, _, _) -> {
                if (ix == 0) return div().h(px(40.));
                final view = TextView.create(state);
                return clamp ? view.maxLines(2) : view;
            }).sizeFull();
        }
        return switch container {
            case Scrollable: frame.child(TextView.create(state).scrollable(true));
            case List(listState): frame.child(row(listState, false));
            case Clamped(listState): frame.child(row(listState, true));
            case DivScroll(handle):
                final scroll = handle;
                frame.child(div()
                    .id("scroll")
                    .sizeFull()
                    .overflowYScroll()
                    .trackScroll(handle)
                    .child(TextView.create(state).onReveal((line, _, _) -> {
                        final viewport = scroll.bounds();
                        var offset = scroll.offset();
                        if (line.bottom() > viewport.bottom()) {
                            offset = new Point(offset.x, offset.y - (line.bottom() - viewport.bottom()));
                        }
                        else if (line.top() < viewport.top()) {
                            offset = new Point(offset.x, offset.y + (viewport.top() - line.top()));
                        }
                        scroll.setOffset(offset);
                    })));
            case Fixed: frame.child(TextView.create(state));
        }
    }
}

/**
 * Tests of `gpui.base.text.TextViewState` (Rust `text/state.rs`).
 *
 * Not ported: `parse_ack::acknowledging_a_parse_leaves_its_readers_retained`,
 * which only builds with the `gpui-fast` feature.
 */
@:access(gpui.base.text)
class TextViewStateTest extends KitTestCase {

    /** Long enough that a test cannot outrun the fade before it samples the first frame. */
    static inline final FADE = 10.;

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    function initBase():Void {
        app.update(cx -> {
            Base.init(cx);
            gpui.base.theme.Theme.globalMut(cx).tokens.typography.mono = 'JetBrains Mono';
        });
    }

    function newState(markdown:String):Entity<TextViewState> {
        initBase();
        return app.update(cx -> cx.newEntity(cx -> TextViewState.markdown(markdown, cx)));
    }

    function newHtml(html:String):Entity<TextViewState> {
        initBase();
        return app.update(cx -> cx.newEntity(cx -> TextViewState.html(html, cx)));
    }

    function update(state:Entity<TextViewState>, f:(TextViewState, Context<TextViewState>) -> Void):Void {
        app.update(app -> state.update(app, (state, cx) -> {
            f(state, cx);
            return true;
        }));
    }

    function addWindowView<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final result = VisualTestContext.addWindowView(app, dispatcher, build);
        contexts.push(result.cx);
        return result;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
    }

    static function ranges(ranges:Null<Array<Range>>):String {
        return ranges == null ? 'None' : [for (r in ranges) '${r.start}..${r.end}'].join(',');
    }

    static function find(haystack:String, needle:String):Range {
        final ix = haystack.indexOf(needle);
        if (ix == -1) throw '$needle not in $haystack';
        final start = Utf8.byteLength(haystack.substr(0, ix));
        return new Range(start, start + Utf8.byteLength(needle));
    }

    static function repeat(s:String, n:Int):String {
        final buf = new StringBuf();
        for (_ in 0...n) buf.add(s);
        return buf.toString();
    }

    function now():Float {
        return app.backgroundExecutor().now();
    }

    // stream_fade

    function fadingState(markdown:String):Entity<TextViewState> {
        initBase();
        final state = app.update(cx -> cx.newEntity(cx -> TextViewState.markdown(markdown, cx)
            .withMotion(new TextViewMotion().withStreamFade(FADE).withStreamFadeEasing(Easing.Linear))));
        runUntilParked();
        return state;
    }

    /** The fade ranges of `key` sampled right now, or `null` when the state has nothing fading. */
    function fades(state:Entity<TextViewState>, key:TextLeafKey):Null<Array<Range>> {
        final frame = state.read(app).streamFade.frame(now(), false);
        if (frame == null) return null;
        final fades = frame.fades(key);
        if (fades == null) return null;
        for (fade in fades) {
            assertTrue(fade.fadeOut > 0.9, 'a fade sampled right after it starts is still transparent');
        }
        return [for (fade in fades) fade.range];
    }

    function testPushStrFadesOnlyTheAppendedText() {
        final state = fadingState("hello");
        update(state, (state, cx) -> state.pushStr(" world", cx));
        runUntilParked();

        assertEquals('5..11', ranges(fades(state, TextLeafKey.block(0))));

        final later = now() + FADE + 1.;
        assertTrue(state.read(app).streamFade.frame(later, false) == null);
        assertTrue(state.read(app).streamFade.frame(now(), false) == null);
    }

    /**
     * Push `chunk` and parse it the way the background parser would, without
     * running the parser, returning the update it would send.
     */
    function pushAndParse(state:Entity<TextViewState>, chunk:String):gpui.base.text.TextViewState.ParsedUpdate {
        var revision = 0;
        var baseline:gpui.base.text.TextViewState.ParsedContent = null;
        update(state, (state, cx) -> {
            state.pushStr(chunk, cx);
            revision = state.revision;
            baseline = new gpui.base.text.TextViewState.ParsedContent(state.parsedContent.document, state.parsedContent.nodeCx);
        });
        final options = new gpui.base.text.TextViewState.UpdateOptions(revision, chunk, true, Compatible, new MarkdownExtensions());
        return new gpui.base.text.TextViewState.ParsedUpdate(revision, false, true, false,
            gpui.base.text.TextViewState.UpdateFuture.parseContent(Markdown, baseline, options), null);
    }

    function testOvertakenParsePreservesTheRemainingChunksFade() {
        final state = fadingState("hello");
        final parsed = pushAndParse(state, " one");
        update(state, (state, cx) -> {
            state.pushStr(" two", cx);
            state.commitParsedUpdate(parsed, cx);
        });
        assertEquals('5..9', ranges(fades(state, TextLeafKey.block(0))));

        runUntilParked();
        assertEquals('5..9,9..13', ranges(fades(state, TextLeafKey.block(0))));
    }

    function testOvertakenParsePreservesARemainingBlocksFade() {
        final state = fadingState("hello");
        final parsed = pushAndParse(state, " one");
        update(state, (state, cx) -> {
            state.pushStr("\n\nsecond", cx);
            state.commitParsedUpdate(parsed, cx);
        });
        assertEquals('5..9', ranges(fades(state, TextLeafKey.block(0))));

        // A third chunk arrives while the second is still uncommitted.
        update(state, (state, cx) -> state.pushStr(" third", cx));
        runUntilParked();
        final found = fades(state, TextLeafKey.block(11));
        assertTrue(found != null, 'new paragraph fades');
        final covered:Array<Int> = [];
        for (range in found) for (i in range.start...range.end) covered.push(i);
        assertEquals([for (i in 0...12) i].join(','), covered.join(','));
    }

    function testSetTextExtendingTheTextFadesLikePushStr() {
        final state = fadingState("hello");
        update(state, (state, cx) -> state.setText("hello world", cx));
        runUntilParked();

        assertEquals('5..11', ranges(fades(state, TextLeafKey.block(0))));
    }

    function testSetTextReplacingTheTextShowsItAtOnce() {
        final state = fadingState("hello");
        update(state, (state, cx) -> state.pushStr(" world", cx));
        runUntilParked();
        assertTrue(fades(state, TextLeafKey.block(0)) != null);

        update(state, (state, cx) -> state.setText("other", cx));
        runUntilParked();

        assertEquals(null, fades(state, TextLeafKey.block(0)));
    }

    function testCompletedMarkupRefadesFromTheDivergence() {
        // The paragraph renders `text` (trailing space trimmed), then
        // `text **bo` literally.
        final state = fadingState("text ");
        update(state, (state, cx) -> state.pushStr("**bo", cx));
        runUntilParked();
        assertEquals('4..9', ranges(fades(state, TextLeafKey.block(0))));

        // `text **bold**` renders `text bold`: the space keeps its fade, the
        // glyphs from byte 5 on changed and fade again as one run.
        update(state, (state, cx) -> state.pushStr("ld**", cx));
        runUntilParked();
        assertEquals('4..5,5..9', ranges(fades(state, TextLeafKey.block(0))));
    }

    function testWithoutStaggerAnUpdateFadesAsOneChunk() {
        final state = fadingState("hello");
        update(state, (state, cx) -> state.pushStr(" one two three", cx));
        runUntilParked();

        assertEquals('5..19', ranges(fades(state, TextLeafKey.block(0))));
    }

    function testWordsOfOneUpdateStartOneAfterAnother() {
        final stagger = 0.1;
        final state = fadingState("hello");
        update(state, (state, _) -> state.setMotion(new TextViewMotion()
            .withStreamFade(FADE)
            .withStreamFadeStagger(stagger)
            .withStreamFadeEasing(Easing.Linear)));
        update(state, (state, cx) -> state.pushStr(" one two three", cx));
        runUntilParked();

        final frame = state.read(app).streamFade.frame(now() + stagger * 3, false);
        assertTrue(frame != null, 'words still fading');
        final fades = frame.fades(TextLeafKey.block(0));
        assertTrue(fades != null, 'paragraph fades');
        assertEquals('5..10,10..14,14..19', ranges([for (f in fades) f.range]));
        // A later word has faded less, so it is still more transparent.
        assertTrue(fades[0].fadeOut < fades[1].fadeOut && fades[1].fadeOut < fades[2].fadeOut);
    }

    function testANewParagraphFadesAsAWhole() {
        final state = fadingState("first");
        update(state, (state, cx) -> state.pushStr("\n\nsecond", cx));
        runUntilParked();

        assertEquals(null, fades(state, TextLeafKey.block(0)));
        assertEquals('0..6', ranges(fades(state, TextLeafKey.block(7))));
    }

    function testCodeBlockTextFadesByBlock() {
        final state = fadingState("```rs\nlet");
        update(state, (state, cx) -> state.pushStr(" x", cx));
        runUntilParked();

        assertEquals('3..5', ranges(fades(state, TextLeafKey.block(0))));
    }

    function testTableCellsFadeByOrdinal() {
        final state = fadingState("| a | b |\n|---|---|\n| c | d");
        update(state, (state, cx) -> state.pushStr("e |", cx));
        runUntilParked();

        assertEquals(null, fades(state, TextLeafKey.tableCell(0, 2)));
        assertEquals('1..2', ranges(fades(state, TextLeafKey.tableCell(0, 3))));
    }

    function testZeroDurationRecordsNothing() {
        final state = newState("hello");
        runUntilParked();
        update(state, (state, cx) -> state.pushStr(" world", cx));
        runUntilParked();

        assertTrue(state.read(app).streamFade.frame(now(), false) == null);
    }

    function testReducedMotionDropsTheFade() {
        final state = fadingState("hello");
        update(state, (state, cx) -> state.pushStr(" world", cx));
        runUntilParked();

        assertTrue(state.read(app).streamFade.frame(now(), true) == null);
        assertTrue(state.read(app).streamFade.frame(now(), false) == null);
    }

    function testAFadeRepaintsOnATimerUntilNothingFades() {
        final tick = @:privateAccess TextViewState.STREAM_FADE_TICK;
        final state = fadingState("hello");
        final result = addWindowView((_, _) -> new FadeRoot(state));
        final cx = result.cx;
        var notifies = 0;
        app.observe(state, (_, _) -> notifies++);

        update(state, (state, cx) -> state.pushStr(" world", cx));
        cx.runUntilParked();
        draw(cx);
        final before = notifies;

        cx.advanceClock(tick / 2);
        cx.runUntilParked();
        assertEquals(before, notifies);

        // Each tick repaints once, and that frame schedules the next tick.
        for (tickIx in 1...4) {
            cx.advanceClock(tick);
            cx.runUntilParked();
            assertEquals(before + tickIx, notifies);
        }

        // Replacing the text drops the fade, so the ticks stop.
        update(state, (state, cx) -> state.setText("other", cx));
        cx.runUntilParked();
        cx.advanceClock(tick);
        cx.runUntilParked();
        final after = notifies;
        cx.advanceClock(tick * 10);
        cx.runUntilParked();
        assertEquals(after, notifies);
        assertTrue(state.read(app).fadeTick == null);
    }

    // parsing

    function testSmallFullReplaceParsesBeforeBackgroundExecutorRuns() {
        final markdown = "# ready";
        final state = newState(markdown);

        assertEquals(markdown, state.read(app).source());
        assertEquals(1, state.read(app).parsedContent.document.blocks.length);
    }

    function testLargeMarkdownAndHtmlFullReplacementsWaitForBackgroundExecutor() {
        final max = @:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES;
        final markdown = repeat("# x\n\n", Std.int(max / 5) + 1);
        final html = '<p>${repeat("x", max + 1)}</p>';
        assertTrue(markdown.length > max);
        assertTrue(html.length > max);

        final markdownState = newState(markdown);
        final htmlState = newHtml(html);

        assertEquals(markdown, markdownState.read(app).text);
        assertEquals('', markdownState.read(app).source());
        assertEquals(0, markdownState.read(app).parsedContent.document.blocks.length);
        assertEquals(html, htmlState.read(app).text);
        assertEquals('', htmlState.read(app).source());
        assertEquals(0, htmlState.read(app).parsedContent.document.blocks.length);

        runUntilParked();

        assertEquals(markdown, markdownState.read(app).source());
        assertTrue(markdownState.read(app).parsedContent.document.blocks.length > 0);
        assertEquals(html, htmlState.read(app).source());
        assertTrue(htmlState.read(app).parsedContent.document.blocks.length > 0);
    }

    static function formulaExtensions():MarkdownExtensions {
        return new MarkdownExtensions().plugin(new TextTestInlinePlugin("test").parseWith((node, _) -> {
            return switch node {
                case InlineMath(math): new MarkdownNode("formula", null).text(math.value);
                case _: null;
            }
        }));
    }

    function testInlineSourceRangesFollowStreamedTailReparsing() {
        final state = newState("中文 $a$\n\n尾 $x");
        update(state, (state, cx) -> state.setMarkdownExtensions(formulaExtensions(), cx));
        runUntilParked();
        update(state, (state, cx) -> state.pushStr("^2$ 后", cx));
        runUntilParked();
        final source = "中文 $a$\n\n尾 $x^2$ 后";
        assertEquals(source, state.read(app).source());
        final objects:Array<MarkdownNode> = [];
        for (block in state.read(app).parsedContent.document.blocks) {
            switch block {
                case Paragraph(paragraph):
                    for (node in paragraph.children_) if (node.custom != null) objects.push(node.custom);
                case _:
                    fail('expected paragraphs');
            }
        }
        assertEquals(2, objects.length);
        final markdowns = ["$a$", "$x^2$"];
        for (i in 0...2) {
            final range = find(source, markdowns[i]);
            final sourceRange = objects[i].sourceRange();
            assertTrue(sourceRange != null && sourceRange.equals(range), markdowns[i]);
            assertEquals(markdowns[i], objects[i].asMarkdown());
        }
    }

    function testAsyncFullReplaceThenPushStrPreservesCompleteSource() {
        final state = newState("old");
        runUntilParked();

        final replacement = repeat("x", @:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES + 1);
        final expected = '$replacement tail';
        update(state, (state, cx) -> {
            state.setText(replacement, cx);
            state.pushStr(" tail", cx);
        });
        runUntilParked();

        assertEquals(expected, state.read(app).text);
        assertEquals(expected, state.read(app).source());
    }

    function testStreamCommitsAParseThatANewerChunkOvertook() {
        final state = newState("# Answer\n\n");
        runUntilParked();

        // Chunks arriving faster than they parse always push the next chunk
        // before the previous parse lands.
        final parsed = pushAndParse(state, "Streaming");
        update(state, (state, cx) -> {
            state.pushStr(" tokens", cx);
            state.commitParsedUpdate(parsed, cx);
            assertEquals("# Answer\n\nStreaming", state.source());
        });

        runUntilParked();
        assertEquals("# Answer\n\nStreaming tokens", state.read(app).source());
    }

    function testAParseFromBeforeAReplacementIsDiscarded() {
        final state = newState("old");
        runUntilParked();

        final parsed = pushAndParse(state, " text");
        // Large enough to parse in the background, so the replacement is not
        // committed yet when the older parse lands.
        final replacement = repeat("x", @:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES + 1);
        update(state, (state, cx) -> {
            state.setText(replacement, cx);
            state.commitParsedUpdate(parsed, cx);
            assertEquals("old", state.source());
        });

        runUntilParked();
        assertEquals(replacement, state.read(app).source());
    }

    function testHtmlPushStrKeepsEarlierBlocks() {
        final state = newHtml("<p>first</p>");
        runUntilParked();

        update(state, (state, cx) -> state.pushStr("<p>second</p>", cx));
        runUntilParked();

        assertEquals("<p>first</p><p>second</p>", state.read(app).source());
        final text = [for (block in state.read(app).parsedContent.document.blocks) block.text()].join('');
        assertTrue(text.indexOf("first") != -1, 'lost the first block: $text');
        assertTrue(text.indexOf("second") != -1, 'lost the appended block: $text');
    }

    function testElementTextOfTheSameStringIsNotComparedAgain() {
        final state = newState("");
        function revision():Int return state.read(app).revision;
        final text = "hello";

        update(state, (state, cx) -> state.setElementText(text, cx));
        final parsed = revision();
        assertTrue(parsed > 0);

        // The same string again, and equal bytes in another string, both leave
        // the parsed text alone.
        update(state, (state, cx) -> state.setElementText(text, cx));
        assertEquals(parsed, revision());
        final equal = "hel" + "lo";
        update(state, (state, cx) -> state.setElementText(equal, cx));
        assertEquals(parsed, revision());

        // Once the state's text moved on, the element's string is set again.
        update(state, (state, cx) -> {
            state.pushStr(" world", cx);
            state.setElementText(equal, cx);
        });
        assertEquals("hello", state.read(app).text);
    }

    function testSetTextThenPushStrAppendsToReplacedContent() {
        final state = newState("old");
        runUntilParked();

        update(state, (state, cx) -> {
            state.setText("", cx);
            state.pushStr("new", cx);
            state.pushStr(" text", cx);
        });
        runUntilParked();

        assertEquals("new text", state.read(app).text);
        assertEquals("new text", state.read(app).source());

        update(state, (state, cx) -> state.setText("", cx));
        runUntilParked();

        assertEquals("", state.read(app).text);
        assertEquals("", state.read(app).source());
    }

    function testFullParseCoalescedWithAppendPreservesNewSelectAll() {
        final state = newState("old");
        runUntilParked();

        update(state, (state, cx) -> {
            state.setText("new", cx);
            state.pushStr(" text", cx);
            state.selectAll(cx);
        });
        runUntilParked();

        assertTrue(state.read(app)._selectAll);
        assertEquals("new text", StringTools.trim(state.read(app).selectedText()));
    }

    function parsedBlocks(state:Entity<TextViewState>):String {
        return [for (block in state.read(app).parsedContent.document.blocks) {
            final span = block.span();
            block.text() + '@' + (span != null ? '${span.start}..${span.end}' : 'None');
        }].join('|');
    }

    function testSetTextExtendingMarkdownAppendsAndKeepsSelection() {
        final state = newState("hello");
        runUntilParked();
        final initialSelection = state.read(app).selectionRevision;
        final initialFull = state.read(app).fullUpdateRevision;

        update(state, (state, cx) -> state.setText("hello world", cx));
        runUntilParked();
        assertEquals("hello world", state.read(app).source());
        assertEquals(initialSelection, state.read(app).selectionRevision);
        assertEquals(initialFull, state.read(app).fullUpdateRevision);

        update(state, (state, cx) -> state.setText("hello", cx));
        runUntilParked();
        assertEquals("hello", state.read(app).source());
        assertTrue(state.read(app).selectionRevision != initialSelection);
        assertTrue(state.read(app).fullUpdateRevision != initialFull);
    }

    function testSetTextStreamingMarkdownMatchesAFullParse() {
        final streamed = newState("# Title");
        runUntilParked();

        // Chunks continue a heading, a paragraph, an inline code span, a list
        // and a fenced code block, and the text grows past the synchronous
        // parse limit.
        final filler = repeat("word ", Std.int(@:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES / 5) + 1);
        final chunks = [
            "\n\nfirst para",
            "graph with `co",
            "de`\n\n- one\n",
            "- two\n\n```rust\nfn main() {",
            "}\n```\n\n",
            filler,
            "\n\nlast",
        ];
        final fullUpdateRevision = streamed.read(app).fullUpdateRevision;
        var text = "# Title";
        for (chunk in chunks) {
            text += chunk;
            final current = text;
            update(streamed, (state, cx) -> state.setText(current, cx));
            runUntilParked();
        }
        assertEquals(fullUpdateRevision, streamed.read(app).fullUpdateRevision);

        final parsed = newState(text);
        runUntilParked();

        assertEquals(parsed.read(app).source(), streamed.read(app).source());
        assertEquals(parsedBlocks(parsed), parsedBlocks(streamed));
    }

    function testSetTextExtendingHtmlParsesItAgain() {
        final streamed = newHtml("<ul><li>a</li>");
        runUntilParked();

        final text = "<ul><li>a</li><li>b</li></ul>";
        update(streamed, (state, cx) -> state.setText(text, cx));
        runUntilParked();
        assertTrue(streamed.read(app).fullUpdateRevision != 0);

        final parsed = newHtml(text);
        runUntilParked();
        assertEquals(parsedBlocks(parsed), parsedBlocks(streamed));
    }

    function testSetTextExtendingAfterAParseErrorParsesItAgain() {
        final state = newState("hello");
        runUntilParked();

        final fullUpdateRevision = state.read(app).fullUpdateRevision;

        update(state, (state, cx) -> {
            state.parsedError = "failed";
            state.setText("hello world", cx);
        });
        runUntilParked();

        assertEquals(null, state.read(app).parsedError);
        assertTrue(state.read(app).fullUpdateRevision != fullUpdateRevision);
        assertEquals("hello world", state.read(app).source());
    }

    function testUpdateOptionsMergeKeepsLatestFullText() {
        final options = new gpui.base.text.TextViewState.UpdateOptions(1, "old", true, Compatible, new MarkdownExtensions());
        options.merge(new gpui.base.text.TextViewState.UpdateOptions(2, "new", false, BaselineAck, new MarkdownExtensions()));
        options.merge(new gpui.base.text.TextViewState.UpdateOptions(3, " text", true, Compatible, new MarkdownExtensions()));

        assertEquals(3, options.revision);
        assertEquals("new text", options.pendingText);
        assertFalse(options.append);
    }

    function testAppendMergedIntoAsyncReplaceRemainsAReplacement() {
        final options = new gpui.base.text.TextViewState.UpdateOptions(1, "new", false, Replace, new MarkdownExtensions());
        options.merge(new gpui.base.text.TextViewState.UpdateOptions(2, " text", true, Compatible, new MarkdownExtensions()));

        assertEquals(2, options.revision);
        assertEquals("new text", options.pendingText);
        assertFalse(options.append);
        assertEquals(gpui.base.text.TextViewState.ParseMode.Replace, options.mode);
    }

    function testUpdateFutureYieldsBeforeCoalescingAllQueuedUpdates() {
        final totalUpdates = 128;
        final future = new gpui.base.text.TextViewState.UpdateFuture(Markdown, app, _ -> {});
        for (revision in 1...totalUpdates + 1) {
            future.queue.push(new gpui.base.text.TextViewState.UpdateOptions(revision, '$revision\n', revision != 1,
                revision == 1 ? BaselineAck : Compatible, new MarkdownExtensions()));
        }

        future.poll();
        final parsedUpdate = future.results.shift();
        assertTrue(parsedUpdate != null, 'parse result');
        assertTrue(parsedUpdate.revision < totalUpdates, 'single poll coalesced every queued update through revision ${parsedUpdate.revision}');

        future.poll();
        final next = future.results.shift();
        assertTrue(next != null, 'next parse result');
        assertEquals(totalUpdates, next.revision);
        future.close();
    }

    function testSelectAllReturnsRenderedText() {
        final state = newState("**quick** value");
        runUntilParked();

        update(state, (state, cx) -> state.selectAll(cx));
        assertTrue(state.read(app).hasViewSelection());
        assertEquals("quick value", StringTools.trim(state.read(app).selectedText()));

        update(state, (state, cx) -> state.clearSelection(cx));
        assertFalse(state.read(app).hasViewSelection());
        assertEquals("", state.read(app).selectedText());
    }

    function testSelectAllInSourceFormatReturnsSource() {
        final markdown = "**quick** value";
        final state = newState(markdown);
        runUntilParked();

        update(state, (state, cx) -> state.selectAll(cx));
        // The default (plain) mode strips the markup.
        assertEquals("quick value", StringTools.trim(state.read(app).selectedText()));

        update(state, (state, cx) -> state.setSelectionFormat(Source, cx));
        // Source mode yields the whole source verbatim.
        assertEquals(markdown, StringTools.trim(state.read(app).selectedText()));
    }

    function testSelectedSourceRangeReturnsFullMarkdownSourceForSelectAll() {
        final markdown = "**quick** value";
        final state = newState(markdown);
        runUntilParked();

        update(state, (state, cx) -> state.selectAll(cx));
        final range = state.read(app).selectedSourceRange();
        assertTrue(range != null && range.start == 0 && range.end == markdown.length);
    }

    function testSelectedSourceRangeReturnsNoneForHtml() {
        final state = newHtml("<b>quick</b>");
        runUntilParked();

        update(state, (state, cx) -> state.selectAll(cx));
        assertEquals(null, state.read(app).selectedSourceRange());
    }

    function testSelectedSourceRangeKeepsGlobalOffsetsAfterIncrementalTailParse() {
        final options = new gpui.base.text.TextViewState.UpdateOptions(1, "first\n\nsecond", false, Replace, new MarkdownExtensions());
        var content = gpui.base.text.TextViewState.UpdateFuture.parseContent(Markdown, new gpui.base.text.TextViewState.ParsedContent(), options);
        content = gpui.base.text.TextViewState.UpdateFuture.parseContent(Markdown, content,
            new gpui.base.text.TextViewState.UpdateOptions(2, "\n\n**écho**", true, Compatible, new MarkdownExtensions()));
        switch content.document.blocks[2] {
            case Paragraph(paragraph):
                paragraph.state.setText(paragraph.text());
                paragraph.state.selection = new gpui.base.input.Selection(0, Utf8.byteLength("écho"));
            case _:
                fail('expected appended paragraph');
        }

        final range = content.document.selectedSourceRange();
        assertTrue(range != null && range.start == 17 && range.end == 22, Range.describe(range));
    }

    function testStreamedOrderedListContinuationPreservesStart() {
        final initial = gpui.base.text.TextViewState.UpdateFuture.parseContent(Markdown, new gpui.base.text.TextViewState.ParsedContent(),
            new gpui.base.text.TextViewState.UpdateOptions(1, "3. three", false, Replace, new MarkdownExtensions()));
        final continued = gpui.base.text.TextViewState.UpdateFuture.parseContent(Markdown, initial,
            new gpui.base.text.TextViewState.UpdateOptions(2, "\n4. four", true, Compatible, new MarkdownExtensions()));

        switch continued.document.blocks[0] {
            case List(children, _, start, _):
                assertEquals(3, start);
                assertEquals(2, children.length);
            case _:
                fail('expected streamed ordered list');
        }
    }

    function testParserRevisionReparsesSameNameInlineConfiguration() {
        final state = newState("@member");
        for (pair in [{revision: 1, label: "Alice"}, {revision: 2, label: "Bob"}]) {
            final label = pair.label;
            final extensions = new MarkdownExtensions()
                .parserRevision(pair.revision)
                .plugin(new TextTestInlinePlugin("test").parseWith((node, _) -> {
                    return node.match(Text(_)) ? new MarkdownNode("mention", label).text(label) : null;
                }));
            update(state, (state, cx) -> state.setMarkdownExtensions(extensions, cx));
            runUntilParked();
            switch state.read(app).parsedContent.document.blocks[0] {
                case Paragraph(paragraph):
                    assertEquals(label, paragraph.children_[0].custom.asText());
                case _:
                    fail('expected a paragraph');
            }
        }
    }

    function testSetMarkdownExtensionsReparsesExistingText() {
        final state = newState("$TSLA.US");
        runUntilParked();

        final extensions = new MarkdownExtensions().blockParser((node, cx) -> {
            switch node {
                case Paragraph(paragraph) if (paragraph.children.length == 1):
                    switch paragraph.children[0] {
                        case Text(text) if (StringTools.startsWith(text.value, '$')):
                            final symbol = text.value.substr(1);
                            final source = cx.nodeSource(node);
                            return new MarkdownNode("ticker", symbol).text('$$$symbol').markdown(source != null ? source : '');
                        case _:
                    }
                case _:
            }
            return null;
        });

        update(state, (state, cx) -> state.setMarkdownExtensions(extensions, cx));
        runUntilParked();

        switch state.read(app).parsedContent.document.blocks[0] {
            case Custom(node, _):
                assertEquals("ticker", node.name());
                assertEquals("TSLA.US", node.data(String));
            case _:
                fail('expected custom markdown node');
        }
    }

    // range_highlights

    static function highlight(range:Range):RangeHighlight {
        return new RangeHighlight(range, hsla(0.15, 1., 0.5, 0.4));
    }

    /** Highlights `ranges` of the current rendered text: `null` when accepted, the error otherwise. */
    function set(state:Entity<TextViewState>, ranges:Array<Range>):Null<RangeHighlightError> {
        var error:Null<RangeHighlightError> = null;
        update(state, (state, cx) -> {
            try {
                state.setRangeHighlights([for (range in ranges) highlight(range)], cx);
            }
            catch (e:gpui.base.text.RangeHighlightError.RangeHighlightException) {
                error = e.error;
            }
        });
        return error;
    }

    /** The ranges leaf `key` paints, in its own byte space. */
    function painted(state:Entity<TextViewState>, key:TextLeafKey):String {
        final frame = state.read(app).rangeHighlights;
        if (frame == null) return '';
        return [for (background in frame.backgrounds(key)) '${background.range.start}..${background.range.end}'].join(',');
    }

    function hasHighlights(state:Entity<TextViewState>):Bool {
        return state.read(app).rangeHighlights != null;
    }

    function highlightState(markdown:String):Entity<TextViewState> {
        final state = newState(markdown);
        runUntilParked();
        return state;
    }

    function testRenderedTextIsThePlainCopyText() {
        final state = highlightState("# Title\n\nhello **world** \\*\n\n- item\n\n| a | b |\n|---|---|\n| c | d |\n\n```\nlet x\n```");
        assertEquals("Title\nhello world *\nitem\na b\nc d\n\nlet x\n", state.read(app).renderedText().asStr());
    }

    function testAMatchAcrossMarksPaintsInItsParagraph() {
        final state = highlightState("hello **world**");
        assertEquals(null, set(state, [new Range(0, 11)]));
        assertEquals('0..11', painted(state, TextLeafKey.block(0)));
    }

    function testRepeatedTextMapsToTheOccurrenceAddressed() {
        final state = highlightState("foo\n\nfoo");
        final second = state.read(app).renderedText().asStr().lastIndexOf("foo");
        assertEquals(null, set(state, [new Range(second, second + 3)]));
        assertEquals('', painted(state, TextLeafKey.block(0)));
        assertEquals('0..3', painted(state, TextLeafKey.block(5)));
    }

    function testARangeAcrossBlocksSkipsTheSeparator() {
        final state = highlightState("ab\n\ncd");
        // "ab\ncd\n": 1..4 is "b\nc".
        assertEquals(null, set(state, [new Range(1, 4)]));
        assertEquals('1..2', painted(state, TextLeafKey.block(0)));
        assertEquals('0..1', painted(state, TextLeafKey.block(4)));
    }

    function testTableCellsAndCodeBlocksAreLeaves() {
        final state = highlightState("| a | b |\n|---|---|\n| c | d |\n\n```\nlet x\n```");
        // "a b\nc d\n\nlet x\n"
        assertEquals(null, set(state, [new Range(0, 3), new Range(6, 7), new Range(9, 12)]));
        assertEquals('0..1', painted(state, TextLeafKey.tableCell(0, 0)));
        assertEquals('0..1', painted(state, TextLeafKey.tableCell(0, 1)));
        assertEquals('0..1', painted(state, TextLeafKey.tableCell(0, 3)));
        final codeStart = "| a | b |\n|---|---|\n| c | d |\n\n".length;
        assertEquals('0..3', painted(state, TextLeafKey.block(codeStart)));
    }

    function testInvalidRangesRejectTheWholeSet() {
        final state = highlightState("中文\n\nab");
        // "中文\nab\n"
        assertEquals(null, set(state, [new Range(0, 3)]));
        for (range in [new Range(6, 3), new Range(0, 1), new Range(0, 100)]) {
            final error = set(state, [new Range(0, 3), range]);
            assertTrue(error != null && Type.enumEq(error, InvalidRange(1)), Range.describe(range));
        }
        // The rejected sets left the earlier highlight in place.
        assertEquals('0..3', painted(state, TextLeafKey.block(0)));
    }

    function testTextOutsideEveryBlockIsLeftUnpainted() {
        final source = "foo one\n\n<div>foo two</div>\n\n| foo | x |\n|---|---|\n\nfoo three";
        final state = highlightState(source);
        final text = state.read(app).renderedText().asStr();
        // Every "foo" and " ", an empty range, and the separator after the
        // first block: they paint nothing, but nothing fails.
        final found:Array<Range> = [];
        for (needle in ["foo", " "]) {
            var from = 0;
            while (true) {
                final ix = text.indexOf(needle, from);
                if (ix == -1) break;
                found.push(new Range(ix, ix + needle.length));
                from = ix + needle.length;
            }
        }
        found.push(new Range(3, 3));
        found.push(new Range(7, 8));
        assertEquals(null, set(state, found));
        assertEquals('0..3,3..4', painted(state, TextLeafKey.block(0)));
        final table = source.indexOf("| foo");
        assertEquals('0..3', painted(state, TextLeafKey.tableCell(table, 0)));
        final last = source.indexOf("foo three");
        assertEquals('0..3,3..4', painted(state, TextLeafKey.block(last)));
    }

    function testALaterHighlightPaintsOverAnEarlierOne() {
        final state = highlightState("abcdef");
        assertEquals(null, set(state, [new Range(0, 6), new Range(2, 3)]));
        assertEquals('0..6,2..3', painted(state, TextLeafKey.block(0)));
    }

    function testHtmlTextIsUnsupported() {
        final html = newHtml("<p>one</p>");
        runUntilParked();
        final error = set(html, [new Range(0, 3)]);
        assertTrue(error != null && Type.enumEq(error, Unsupported));
    }

    function testInlineObjectsAreSkipped() {
        final state = highlightState("x $a$ y");
        update(state, (state, cx) -> state.setMarkdownExtensions(formulaExtensions(), cx));
        runUntilParked();
        // "x a y\n", where "a" is the formula.
        assertEquals(null, set(state, [new Range(2, 3)]));
        assertEquals('', painted(state, TextLeafKey.block(0)));
        assertEquals(null, set(state, [new Range(0, 5)]));
        assertEquals('0..2,3..5', painted(state, TextLeafKey.block(0)));
    }

    function testPushStrKeepsEarlierBlocksAndClipsTheChangedTail() {
        final state = highlightState("first\n\na **b");
        // "first\na **b\n"
        assertEquals(null, set(state, [new Range(0, 5), new Range(6, 11)]));

        // Closing the emphasis renders the tail as "a bc".
        update(state, (state, cx) -> state.pushStr("c**", cx));
        runUntilParked();

        assertEquals('0..5', painted(state, TextLeafKey.block(0)));
        assertEquals('0..2', painted(state, TextLeafKey.block(7)));
    }

    function testPushStrKeepsABlockWhoseTextIsUnchanged() {
        final state = highlightState("first\n\nsecond");
        assertEquals(null, set(state, [new Range(6, 12)]));
        // A setext underline turns the paragraph into a heading at the same
        // source start, rendering the same text.
        update(state, (state, cx) -> state.pushStr("\n===", cx));
        runUntilParked();
        assertEquals('0..6', painted(state, TextLeafKey.block(7)));
    }

    function testPushStrDropsHighlightsOfALeafThatIsGone() {
        final state = highlightState("first\n\n| a |");
        assertEquals(null, set(state, [new Range(0, 5), new Range(6, 11)]));
        // A delimiter row turns the paragraph into a table, whose text lives in
        // cells instead.
        update(state, (state, cx) -> state.pushStr("\n|---|", cx));
        runUntilParked();
        assertEquals('0..5', painted(state, TextLeafKey.block(0)));
        assertEquals('', painted(state, TextLeafKey.block(7)));
        assertEquals('', painted(state, TextLeafKey.tableCell(7, 0)));
    }

    function testReplacingTextDropsHighlightsOnlyWhereItChanged() {
        final state = highlightState("first\n\nsecond");
        assertEquals(null, set(state, [new Range(0, 5), new Range(6, 12)]));
        update(state, (state, cx) -> state.setText("first\n\nchanged", cx));
        runUntilParked();
        assertEquals('0..5', painted(state, TextLeafKey.block(0)));
        assertEquals('', painted(state, TextLeafKey.block(7)));

        final large = repeat("x", @:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES + 1);
        update(state, (state, cx) -> state.setText(large, cx));
        runUntilParked();
        assertFalse(hasHighlights(state));
    }

    function testAHighlightFollowsItsBlockPastAnEarlierEdit() {
        var state = highlightState("foo\n\nbar\n\nbar");
        // "foo\nbar\nbar\n": the first "bar", in the block at source 5.
        assertEquals(null, set(state, [new Range(4, 7)]));
        // Deleting "foo" moves that "bar" to 0, and the second one to 5.
        update(state, (state, cx) -> state.setText("bar\n\nbar", cx));
        runUntilParked();
        assertEquals('0..3', painted(state, TextLeafKey.block(0)));
        assertEquals('', painted(state, TextLeafKey.block(5)));

        state = highlightState("ERROR a\n\nERROR b\n\nERROR c");
        assertEquals(null, set(state, [new Range(8, 15)]));
        update(state, (state, cx) -> state.setText("ERROR b\n\nERROR c", cx));
        runUntilParked();
        assertEquals('0..7', painted(state, TextLeafKey.block(0)));
        assertEquals('', painted(state, TextLeafKey.block(9)));
    }

    function testAppendingACopyOfTheLastBlockKeepsTheHighlightOnIt() {
        final state = highlightState("a\n\nfoo");
        // "a\nfoo\n"
        assertEquals(null, set(state, [new Range(2, 5)]));
        update(state, (state, cx) -> state.setText("a\n\nfoo\n\nfoo", cx));
        runUntilParked();
        assertEquals('0..3', painted(state, TextLeafKey.block(3)));
        assertEquals('', painted(state, TextLeafKey.block(8)));
    }

    function testDeletingATableRowDropsHighlightsInTheRowsItMoves() {
        final table = "| a | b |\n|---|---|\n| x | 1 |\n| x | 2 |";
        final withoutMiddleRow = "| a | b |\n|---|---|\n| x | 2 |";
        // "a b\nx 1\nx 2\n\n": the last row's cells, then the middle row's "x".
        for (extra in [[new Range(8, 9), new Range(10, 11)], [new Range(4, 5)]]) {
            final state = highlightState(table);
            assertEquals(null, set(state, [new Range(0, 1)].concat(extra)));
            update(state, (state, cx) -> state.setText(withoutMiddleRow, cx));
            runUntilParked();
            assertEquals('0..1', painted(state, TextLeafKey.tableCell(0, 0)));
            for (cell in 1...4) {
                assertEquals('', painted(state, TextLeafKey.tableCell(0, cell)), 'cell $cell');
            }
        }
    }

    function testStreamingTableRowsKeepsTheHighlightsOfEarlierRows() {
        final state = highlightState("| a | b |\n|---|---|\n| x | 1 |");
        // "a b\nx 1\n\n"
        assertEquals(null, set(state, [new Range(0, 1), new Range(4, 5)]));
        update(state, (state, cx) -> state.setText("| a | b |\n|---|---|\n| x | 1 |\n| y | 2 |", cx));
        runUntilParked();
        assertEquals('0..1', painted(state, TextLeafKey.tableCell(0, 0)));
        assertEquals('0..1', painted(state, TextLeafKey.tableCell(0, 2)));
    }

    function testAnEditInAnEarlierBlockKeepsLaterHighlights() {
        final state = highlightState("one\n\ntwo");
        assertEquals(null, set(state, [new Range(0, 3), new Range(4, 7)]));
        update(state, (state, cx) -> state.setText("one!\n\ntwo", cx));
        runUntilParked();
        assertEquals('0..3', painted(state, TextLeafKey.block(0)));
        assertEquals('0..3', painted(state, TextLeafKey.block(6)));
    }

    function testAnAppendAfterAFullUpdateComparesEveryBlock() {
        final state = highlightState("first\n\nsecond");
        assertEquals(null, set(state, [new Range(0, 5)]));
        // An append result whose baseline was a full update that has not been
        // committed: its earlier blocks are not the current ones.
        final options = new gpui.base.text.TextViewState.UpdateOptions(0, "FIRST\n\nsecond", false, Replace, new MarkdownExtensions());
        final next = gpui.base.text.TextViewState.UpdateFuture.parseContent(Markdown, new gpui.base.text.TextViewState.ParsedContent(), options).document;
        update(state, (state, _) -> {
            state.fullUpdateRevision = state.committedRevision + 1;
            final revision = state.committedRevision + 2;
            state.reconcileRangeHighlights(next, revision, true);
        });
        assertFalse(hasHighlights(state));
    }

    function testStreamingThroughSetTextKeepsHighlights() {
        final state = highlightState("first\n\nsec");
        // "first\nsec\n"
        assertEquals(null, set(state, [new Range(0, 5), new Range(6, 9)]));
        update(state, (state, cx) -> state.setText("first\n\nsecond", cx));
        runUntilParked();
        assertEquals('0..5', painted(state, TextLeafKey.block(0)));
        assertEquals('0..3', painted(state, TextLeafKey.block(7)));
    }

    function testAFullParseMergedWithAnAppendComparesEveryBlock() {
        final state = highlightState("");
        // The small text is committed at once, and its background parse merges
        // with the append into one full parse, in which the definition turns
        // the earlier `[foo]` into the link text `foo`.
        update(state, (state, cx) -> {
            state.setText("[foo] and some text\n\nmore", cx);
            final text = state.renderedText();
            final some = text.asStr().indexOf("some");
            state.setRangeHighlights([highlight(new Range(some, some + 4))], cx);
            state.pushStr("\n\n[foo]: https://example.com", cx);
        });
        runUntilParked();
        assertTrue(StringTools.startsWith(state.read(app).renderedText().asStr(), "foo and some"));
        assertEquals('', painted(state, TextLeafKey.block(0)));
    }

    function testAFullUpdateBeforeAnAppendDropsReplacedHighlights() {
        final state = highlightState("first");
        assertEquals(null, set(state, [new Range(0, 5)]));
        final large = repeat("x", @:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES + 1);
        update(state, (state, cx) -> {
            state.setText(large, cx);
            state.pushStr(" tail", cx);
        });
        runUntilParked();
        assertFalse(hasHighlights(state));
    }

    function testReparsingUnchangedTextKeepsHighlights() {
        final state = highlightState("first");
        assertEquals(null, set(state, [new Range(0, 5)]));
        update(state, (state, cx) -> state.setMarkdownExtensions(new MarkdownExtensions().parserRevision(1), cx));
        runUntilParked();
        assertEquals('0..5', painted(state, TextLeafKey.block(0)));
    }

    function testHighlightsPaintAcrossInlineCodeTablesAndCodeBlocks() {
        initBase();
        final markdown = "wrapping text with `inline code` and a [link](https://x.y) that wraps\n\n| a | b |\n|---|---|\n| c | d |\n\n```\nlet x = 1;\n```";
        final result = addWindowView((_, cx) -> new HighlightRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx))));
        final cx = result.cx;
        cx.runUntilParked();
        final state = result.view.read(app).state;
        final text = state.read(app).renderedText().asStr();
        final code = text.indexOf("code");
        final len = Utf8.byteLength(text);
        // Part of the inline code, every character, and the whole text.
        final all:Array<Range> = [new Range(code, code + 2)];
        var offset = 0;
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            final next = offset + Utf8.codePointLength(c);
            all.push(new Range(offset, next));
            offset = next;
        }
        all.push(new Range(0, len));
        final ranges = all.filter(range -> StringTools.trim(Utf8.substring(text, range.start, range.end)).length > 0);
        update(state, (state, cx) -> state.setRangeHighlights([for (range in ranges) highlight(range)], cx));
        draw(cx);
        assertEquals('$code..${code + 2}', painted(state, TextLeafKey.block(0)).split(',')[0]);
    }

    /** The ranges of the current rendered text converted from `sources`. */
    function converted(state:Entity<TextViewState>, sources:Array<Range>):String {
        final text = state.read(app).renderedText();
        return [for (source in sources) Range.describe(text.rangeForSource(source))].join(',');
    }

    function testSourceRangesHighlightTheTextRenderedFromThem() {
        final markdown = "In Rust, we use `u128` to handle **larger** numbers\n\n| a | **b** |\n|---|---|";
        final state = highlightState(markdown);
        update(state, (state, cx) -> {
            final text = state.renderedText();
            assertEquals(markdown, text.source());
            final highlights = [for (needle in ["`u128` to handle **larger**", "**b**"]) highlight(text.rangeForSource(find(markdown, needle)))];
            state.setRangeHighlights(highlights, cx);
        });
        final rendered = "In Rust, we use u128 to handle larger numbers";
        final expected = find(rendered, "u128 to handle larger");
        assertEquals('${expected.start}..${expected.end}', painted(state, TextLeafKey.block(0)));
        final table = markdown.indexOf("| a");
        assertEquals('0..1', painted(state, TextLeafKey.tableCell(table, 1)));
    }

    function testSelectAllConvertsToEveryRenderedCharacter() {
        final markdown = "# Title\n\nhello **world**\n\n- item";
        final state = highlightState(markdown);
        update(state, (state, cx) -> state.selectAll(cx));
        final text = state.read(app).renderedText();
        assertEquals("Title\nhello world\nitem\n", text.asStr());
        final source = state.read(app).selectedSourceRange();
        // All but the separator after the last block.
        assertEquals(Range.describe(new Range(0, text.len() - 1)), Range.describe(text.rangeForSource(source)));
    }

    function testASnapshotConvertsAgainstItsOwnSource() {
        final state = highlightState("first");
        final before = state.read(app).renderedText();
        update(state, (state, cx) -> state.pushStr("\n\nsecond **part**", cx));
        final source = "first\n\nsecond **part**";
        final second = find(source, "second **part**");

        // The append is parsed in the background, so until it lands the view
        // renders the source it had.
        var text = state.read(app).renderedText();
        assertTrue(text.equals(before));
        assertEquals("first", text.source());
        assertEquals(null, text.rangeForSource(second));
        runUntilParked();

        assertEquals(Range.describe(new Range(6, 17)) + ',' + Range.describe(new Range(0, 5)), converted(state, [second, new Range(0, 5)]));
        text = state.read(app).renderedText();
        assertFalse(text.equals(before));
        assertEquals(source, text.source());
        assertEquals("second part", Utf8.substring(text.asStr(), 6, 17));
        // An earlier snapshot keeps converting against its own source.
        assertEquals("first", before.source());
        assertEquals(Range.describe(new Range(0, 5)), Range.describe(before.rangeForSource(new Range(0, 5))));
        assertEquals(null, before.rangeForSource(second));
    }

    function testAppendedBlocksConvertAtTheirPlaceInTheWholeSource() {
        final state = highlightState("first\n\nsecond");
        // The tail parse reparses from the last block, whose positions must
        // still count from the start of the whole source.
        update(state, (state, cx) -> state.pushStr(" more\n\n**écho** end", cx));
        runUntilParked();
        final source = "first\n\nsecond more\n\n**écho** end";
        final text = state.read(app).renderedText();
        assertEquals(source, text.source());
        final texts = [for (needle in ["second more", "**écho**", "end"]) {
            final range = text.rangeForSource(find(source, needle));
            Utf8.substring(text.asStr(), range.start, range.end);
        }];
        assertEquals("second more|écho|end", texts.join('|'));
    }

    function testABackgroundParseConvertsOnceItLands() {
        initBase();
        final markdown = repeat("word ", Std.int(@:privateAccess TextViewState.MAX_SYNC_FULL_REPLACE_BYTES / 4)) + "\n\n**tail**";
        final state = app.update(cx -> cx.newEntity(cx -> TextViewState.markdown(markdown, cx)));
        final tail = find(markdown, "**tail**");
        var text = state.read(app).renderedText();
        assertEquals("", text.source());
        assertTrue(text.isEmpty());
        assertEquals(null, text.rangeForSource(tail));
        runUntilParked();
        text = state.read(app).renderedText();
        assertEquals(markdown, text.source());
        final range = text.rangeForSource(tail);
        assertEquals("tail", Utf8.substring(text.asStr(), range.start, range.end));
    }

    function testInlineObjectsConvertWholeAndStayUnpainted() {
        final markdown = "x $ab$ y";
        final state = highlightState(markdown);
        update(state, (state, cx) -> state.setMarkdownExtensions(formulaExtensions(), cx));
        runUntilParked();
        // "x ab y\n", where "ab" is the formula.
        final formula = find(markdown, "$ab$");
        assertEquals([new Range(2, 4), new Range(2, 4), new Range(0, 6), new Range(2, 6)].map(Range.describe).join(','),
            converted(state, [formula, new Range(formula.start + 1, formula.start + 2), new Range(0, markdown.length), find(markdown, "ab$ y")]));
        final text = state.read(app).renderedText();
        final r0 = text.rangeForSource(formula);
        final r1 = text.rangeForSource(new Range(0, markdown.length));
        assertEquals(null, set(state, [r0]));
        assertEquals('', painted(state, TextLeafKey.block(0)));
        assertEquals(null, set(state, [r1]));
        assertEquals('0..2,4..6', painted(state, TextLeafKey.block(0)));
    }

    function testADraggedSelectionHighlightsThroughItsSourceRange() {
        initBase();
        final markdown = "hello **world** and `code` &amp; more";
        final result = addWindowView((_, cx) -> new SelectionRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx))));
        final cx = result.cx;
        cx.runUntilParked();
        final state = result.view.read(app).state;
        draw(cx);
        final bounds = state.read(app).bounds();
        assertTrue(bounds.size.height > 30., 'the text wraps, $bounds');
        final start = bounds.origin.add(new Point(2., 4.));
        final end = bounds.bottomRight().sub(new Point(2., 4.));
        cx.simulateMouseDown(start, Left);
        draw(cx);
        cx.simulateMouseMove(end, Left);
        draw(cx);
        cx.simulateMouseUp(end, Left);
        draw(cx);

        var range:Range = null;
        update(state, (state, cx) -> {
            final selected = state.selectedText();
            final source = state.selectedSourceRange();
            assertTrue(source != null, 'selection maps to source');
            final text = state.renderedText();
            range = text.rangeForSource(source);
            assertTrue(range != null, 'source renders text');
            assertTrue(selected.indexOf("code &") != -1, 'selected $selected');
            var trimmed = selected;
            while (StringTools.endsWith(trimmed, '\n')) trimmed = trimmed.substr(0, trimmed.length - 1);
            assertEquals(trimmed, Utf8.substring(text.asStr(), range.start, range.end));
            state.clearSelection(cx);
            state.setRangeHighlights([highlight(range)], cx);
        });
        draw(cx);
        assertEquals('${range.start}..${range.end}', painted(state, TextLeafKey.block(0)));
    }

    function testHtmlViewsConvertNoSource() {
        final html = newHtml("<p>one</p>");
        runUntilParked();
        final text = html.read(app).renderedText();
        assertEquals("<p>one</p>", text.source());
        assertEquals(null, text.rangeForSource(new Range(0, 10)));
        assertEquals(null, text.rangeForSource(new Range(3, 6)));
    }

    function testClearRangeHighlightsRemovesThem() {
        final state = highlightState("first");
        assertEquals(null, set(state, [new Range(0, 5)]));
        update(state, (state, cx) -> state.clearRangeHighlights(cx));
        assertFalse(hasHighlights(state));
    }

    // reveal_range

    function revealWindow(markdown:String, container:Container):{state:Entity<TextViewState>, cx:VisualTestContext} {
        initBase();
        final result = addWindowView((_, cx) -> new RevealRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx)), container));
        result.cx.runUntilParked();
        draw(result.cx);
        return {state: result.view.read(app).state, cx: result.cx};
    }

    /** Asks to reveal the first occurrence of `needle`, then runs `then` before anything is drawn. */
    function request(state:Entity<TextViewState>, needle:String, then:(TextViewState, Context<TextViewState>) -> Void):Void {
        update(state, (state, cx) -> {
            final text = state.renderedText();
            final start = Utf8.byteLength(text.asStr().substr(0, text.asStr().indexOf(needle)));
            state.revealRange(new Range(start, start + Utf8.byteLength(needle)), cx);
            then(state, cx);
        });
    }

    /** Reveals the first occurrence of `needle` and draws a few frames. */
    function reveal(state:Entity<TextViewState>, needle:String, cx:VisualTestContext):Void {
        request(state, needle, (_, _) -> {});
        for (_ in 0...3) draw(cx);
    }

    function isPending(state:Entity<TextViewState>):Bool {
        return state.read(app).pendingReveal != null;
    }

    function scrollTop(state:Entity<TextViewState>):ListOffset {
        return state.read(app).listState.logicalScrollTop();
    }

    static function paragraphs(count:Int):String {
        return [for (ix in 0...count) 'paragraph $ix'].join("\n\n");
    }

    static function words(count:Int):String {
        return [for (ix in 0...count) 'w$ix'].join(" ");
    }

    /** Reveals `range` of the current text and draws a few frames. */
    function revealAt(state:Entity<TextViewState>, range:String->Range, cx:VisualTestContext):Void {
        update(state, (state, cx) -> {
            final text = state.renderedText();
            state.revealRange(range(text.asStr()), cx);
        });
        for (_ in 0...3) draw(cx);
    }

    function assertUnmoved(state:Entity<TextViewState>, top:ListOffset, ?pos:haxe.PosInfos):Void {
        assertFalse(isPending(state), null, pos);
        final now = scrollTop(state);
        assertEquals('${top.itemIx}/${top.offsetInItem}', '${now.itemIx}/${now.offsetInItem}', null, pos);
    }

    function testAScrollableViewScrollsToAnOffscreenBlock() {
        final w = revealWindow(paragraphs(200), Scrollable);
        reveal(w.state, "paragraph 150", w.cx);
        assertFalse(isPending(w.state));
        final top = scrollTop(w.state);
        assertTrue(top.itemIx >= 140 && top.itemIx <= 150, top.toString());

        reveal(w.state, "paragraph 3", w.cx);
        assertFalse(isPending(w.state));
        assertTrue(scrollTop(w.state).itemIx <= 3);
    }

    function testAnAppendAddingBlocksKeepsTheScrollPosition() {
        final w = revealWindow(paragraphs(200), Scrollable);
        reveal(w.state, "paragraph 100", w.cx);
        final top = scrollTop(w.state);
        assertTrue(top.itemIx > 0, top.toString());

        update(w.state, (state, cx) -> state.pushStr("\n\nparagraph 200", cx));
        w.cx.runUntilParked();
        draw(w.cx);

        assertEquals(201, w.state.read(app).listState.itemCount());
        assertUnmoved(w.state, top);
    }

    function testAScrollableViewScrollsToALineInsideALongParagraph() {
        final w = revealWindow(words(400), Scrollable);
        reveal(w.state, "w390", w.cx);
        assertFalse(isPending(w.state));
        final top = scrollTop(w.state);
        assertEquals(0, top.itemIx);
        assertTrue(top.offsetInItem > 100., top.toString());
    }

    function testRevealingAVisibleLineDoesNotScroll() {
        final w = revealWindow(words(400), Scrollable);
        reveal(w.state, "w200", w.cx);
        final top = scrollTop(w.state);
        assertTrue(top.offsetInItem > 0., top.toString());
        for (word in ["w199", "w198", "w197", "w196"]) {
            reveal(w.state, word, w.cx);
            assertUnmoved(w.state, top);
        }
    }

    function testAnEnclosingListScrollsToALineOfAFitContentView() {
        final outer = new ListState(2, ListAlignment.Top, 1000.);
        final w = revealWindow(words(400), List(outer));
        reveal(w.state, "w390", w.cx);
        assertFalse(isPending(w.state));
        final top = outer.logicalScrollTop();
        assertEquals(1, top.itemIx, top.toString());
        assertTrue(top.offsetInItem > 100., top.toString());
    }

    function testOnRevealScrollsAContainerThatIgnoresScrollRequests() {
        final handle = new ScrollHandle();
        final w = revealWindow(words(400), DivScroll(handle));
        reveal(w.state, "w390", w.cx);
        assertFalse(isPending(w.state));
        assertTrue(handle.offset().y < -100., handle.offset().toString());
    }

    function testARevealThatCannotBeShownGivesUp() {
        final w = revealWindow(words(4000), Fixed);
        reveal(w.state, "w3990", w.cx);
        assertTrue(isPending(w.state));
        for (_ in 0...10) draw(w.cx);
        assertFalse(isPending(w.state));
    }

    function testARevealNotCarriedOutInTimeIsDropped() {
        final w = revealWindow(paragraphs(200), Scrollable);
        request(w.state, "paragraph 150", (_, cx) -> cx.backgroundExecutor().advanceClock(2.));
        draw(w.cx);
        assertFalse(isPending(w.state));
        assertEquals(0, scrollTop(w.state).itemIx);
    }

    function testAnEmptyRangeRevealsItsLine() {
        final w = revealWindow(words(400), Scrollable);
        reveal(w.state, "w390", w.cx);
        final top = scrollTop(w.state);
        // A position on a visible line leaves the view where it is. Rust
        // takes the start of `w391`, which its test fonts set on the line of
        // `w390`; the port's test fonts wrap it onto the next line, so the
        // position is taken on the line of `w390` itself.
        revealAt(w.state, text -> {
            final start = text.indexOf("w390") + 2;
            new Range(start, start);
        }, w.cx);
        assertUnmoved(w.state, top);
    }

    function testAPositionAfterTheLastCharacterRevealsItsLine() {
        final w = revealWindow(words(400), Scrollable);
        reveal(w.state, "w399", w.cx);
        final top = scrollTop(w.state);
        assertTrue(top.offsetInItem > 1000., top.toString());
        // The end of the text, on the visible last line.
        revealAt(w.state, text -> {
            final end = text.indexOf("w399") + 4;
            new Range(end, end);
        }, w.cx);
        assertUnmoved(w.state, top);
    }

    function testTheEndOfTheTextAndItsSeparatorsRevealTheLastLine() {
        final w = revealWindow(words(400), Scrollable);
        reveal(w.state, "w399", w.cx);
        var top = scrollTop(w.state);
        assertTrue(top.offsetInItem > 1000., top.toString());
        // The end of the text, after the separator that ends the block.
        revealAt(w.state, text -> new Range(text.length, text.length), w.cx);
        assertUnmoved(w.state, top);
        // Only that separator.
        revealAt(w.state, text -> new Range(text.length - 1, text.length), w.cx);
        assertUnmoved(w.state, top);

        final code = [for (ix in 0...200) 'line $ix'].join("\n");
        update(w.state, (state, cx) -> state.setText('```\n$code\n```', cx));
        w.cx.runUntilParked();
        reveal(w.state, "line 199", w.cx);
        top = scrollTop(w.state);
        assertTrue(top.offsetInItem > 1000., top.toString());
        revealAt(w.state, text -> new Range(text.length, text.length), w.cx);
        assertUnmoved(w.state, top);
    }

    function testTheEndOfABlockAboveRevealsItsLastLine() {
        final second = [for (ix in 0...400) 'v$ix'].join(" ");
        final w = revealWindow('${words(400)}\n\n$second', Scrollable);
        reveal(w.state, "v399", w.cx);
        assertEquals(1, scrollTop(w.state).itemIx);
        // The end of the first paragraph, on the separator after it.
        revealAt(w.state, text -> {
            final end = text.indexOf("w399") + 4;
            new Range(end, end);
        }, w.cx);
        assertFalse(isPending(w.state));
        final top = scrollTop(w.state);
        assertEquals(0, top.itemIx, top.toString());
        assertTrue(top.offsetInItem > 1000., top.toString());
    }

    function testAnEmptyViewHasNothingToReveal() {
        final state = newState("");
        runUntilParked();
        update(state, (state, cx) -> {
            state.revealRange(new Range(0, 0), cx);
            assertTrue(state.pendingReveal == null);
        });
    }

    function testRevealingAVisibleBlockDoesNotScroll() {
        final w = revealWindow('${words(400)}\n\n<div>html</div>\n\n${words(400)}', Scrollable);
        reveal(w.state, "html", w.cx);
        // Still in view a little further down.
        update(w.state, (state, _) -> state.listState.scrollBy(30.));
        draw(w.cx);
        final top = scrollTop(w.state);
        reveal(w.state, "html", w.cx);
        assertUnmoved(w.state, top);
    }

    function testALineOfAnInlineFlowCountsAsShownOnceScrolledTo() {
        // Inline code every tenth word, so the rows are taller than the body
        // line and land between pixels.
        final markdown = [for (ix in 0...400) ix % 10 == 0 ? '`c$ix`' : 'w$ix'].join(" ");
        final w = revealWindow(markdown, Scrollable);
        reveal(w.state, "c390", w.cx);
        assertFalse(isPending(w.state));
        assertTrue(scrollTop(w.state).offsetInItem > 1000.);
    }

    function testARangeStartingOnALineBreakRevealsTheNextLine() {
        final code = [for (ix in 0...200) 'line $ix'].join("\n");
        final w = revealWindow('```\n$code\n```', Scrollable);
        reveal(w.state, "\nline 190", w.cx);
        assertFalse(isPending(w.state));
        final top = scrollTop(w.state);
        assertTrue(top.offsetInItem > 1000., top.toString());
    }

    function testARangeStartingOnALineBreakInAnInlineFlowRevealsTheNextLine() {
        // Inline code lays the paragraph out as an inline flow.
        final lines = [for (ix in 0...200) 'line $ix `code`'].join("\\\n");
        final w = revealWindow(lines, Scrollable);
        reveal(w.state, "\nline 190", w.cx);
        assertFalse(isPending(w.state));
        final top = scrollTop(w.state);
        assertTrue(top.offsetInItem > 1000., top.toString());
    }

    function testARevealIsDroppedWhenItsTextBeforeItChanges() {
        final w = revealWindow(paragraphs(200), Scrollable);
        final target = "first words then the target";
        final markdown = '$target\n\n${paragraphs(200)}';
        update(w.state, (state, cx) -> state.setText(markdown, cx));
        w.cx.runUntilParked();

        // Appending to its paragraph keeps it.
        request(w.state, "target", (state, cx) -> {
            state.setText(StringTools.replace(markdown, "the target", "the target and more"), cx);
            assertTrue(state.pendingReveal != null);
        });
        // An edit before it in its paragraph drops it.
        request(w.state, "target", (state, cx) -> {
            state.setText(StringTools.replace(markdown, "first words", "first WORDS"), cx);
            assertTrue(state.pendingReveal == null);
        });
    }

    function testAClampedViewDoesNotReveal() {
        final outer = new ListState(2, ListAlignment.Top, 1000.);
        final w = revealWindow(words(400), Clamped(outer));
        reveal(w.state, "w390", w.cx);
        assertFalse(isPending(w.state));
        assertEquals(0, outer.logicalScrollTop().itemIx);
    }

    function testTextOutsideEveryBlockRevealsItsBlock() {
        final w = revealWindow('${paragraphs(100)}\n\n<div>html text</div>', Scrollable);
        reveal(w.state, "html text", w.cx);
        assertFalse(isPending(w.state));
        assertTrue(scrollTop(w.state).itemIx >= 90, scrollTop(w.state).toString());
    }

    function testARevealFollowsItsTextPastAnEditBeforeIt() {
        final w = revealWindow(paragraphs(200), Scrollable);
        // An inserted paragraph moves the target down one block.
        request(w.state, "paragraph 150", (state, cx) -> {
            state.setText('inserted\n\n${paragraphs(200)}', cx);
            assertTrue(state.pendingReveal != null);
        });
        for (_ in 0...3) draw(w.cx);
        assertFalse(isPending(w.state));
        final top = scrollTop(w.state);
        assertTrue(top.itemIx >= 141 && top.itemIx <= 151, top.toString());

        // A reveal whose text changed is dropped.
        request(w.state, "paragraph 150", (state, cx) -> {
            state.setText(StringTools.replace(paragraphs(200), "paragraph 150", "changed"), cx);
            assertTrue(state.pendingReveal == null);
        });
    }

    function testMalformedRangesAndHtmlViewsAreRejected() {
        final state = newState("first\n\nsecond");
        runUntilParked();
        update(state, (state, cx) -> {
            for (range in [new Range(5, 3), new Range(0, 100)]) {
                var error:Null<RangeHighlightError> = null;
                try state.revealRange(range, cx) catch (e:gpui.base.text.RangeHighlightError.RangeHighlightException) error = e.error;
                assertTrue(error != null && Type.enumEq(error, InvalidRange(0)));
            }
            state.revealRange(new Range(0, 5), cx);
        });

        final html = newHtml("<p>one</p>");
        runUntilParked();
        update(html, (html, cx) -> {
            var error:Null<RangeHighlightError> = null;
            try html.revealRange(new Range(0, 3), cx) catch (e:gpui.base.text.RangeHighlightError.RangeHighlightException) error = e.error;
            assertTrue(error != null && Type.enumEq(error, Unsupported));
        });
    }

}
