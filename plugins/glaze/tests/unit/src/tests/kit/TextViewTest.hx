// Ported from gpui-kit 0.8.1: crates/base/src/text/text_view.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Entity;
import glaze.Hsla;
import glaze.ImageFormat;
import glaze.IntoElement;
import glaze.ListAlignment;
import glaze.ListState;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.base.Base;
import glaze.kit.base.TextSelection;
import glaze.kit.base.TextSelectionLayer;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.text.InlineElement;
import glaze.kit.base.text.LineSpan;
import glaze.kit.base.text.MarkdownExtensions;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.SelectionFormat;
import glaze.kit.base.text.TextView;
import glaze.kit.base.text.TextViewState;
import glaze.kit.base.text.TextViewStyle;
import glaze.kit.base.theme.ColorTokens;
import glaze.util.Utf8;
import testing.VisualTestContext;

import glaze.Prelude.*;

private class TextColorRoot extends Model implements Render {
    public final inherited:Entity<TextViewState>;
    public final explicit:Entity<TextViewState>;
    public final surfaceText:Hsla;

    public function new(inherited:Entity<TextViewState>, explicit:Entity<TextViewState>, surfaceText:Hsla) {
        super();
        this.inherited = inherited;
        this.explicit = explicit;
        this.surfaceText = surfaceText;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .w(px(300.))
            .textColor(ColorTokens.light().foreground)
            .child(div()
                .textColor(surfaceText)
                .child(TextView.create(inherited))
                .child(TextView.create(explicit).withStyle(TextViewStyle.defaultValue())));
    }
}

/** Rust `TextViewTestRoot`: a selectable view clipped to 24px, then a footer. */
private class TextViewTestRoot extends Model implements Render {
    public final textView:Entity<TextViewState>;

    public function new(text:String, cx:Context<TextViewTestRoot>) {
        super();
        textView = cx.newEntity(cx -> TextViewState.markdown(text, cx));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .w(px(160.))
            .child(div().h(px(24.)).overflowHidden().child(TextView.create(textView).selectable(true)))
            .child(div().h(px(40.)).child("footer"));
    }
}

/** A root with a text selection layer around one view (several Rust test roots). */
private class LayerRoot extends Model implements Render {
    public final textView:Entity<TextViewState>;
    public var width:Float;
    public var height:Null<Float>;
    public var scrollable:Bool;
    public var format:SelectionFormat = Plain;
    public var extensions:Null<MarkdownExtensions> = null;
    public var linkClicks:Null<Array<{url:String, event:ClickEvent}>> = null;

    public function new(textView:Entity<TextViewState>, width:Float, ?height:Float, scrollable:Bool = false) {
        super();
        this.textView = textView;
        this.width = width;
        this.height = height;
        this.scrollable = scrollable;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var view = TextView.create(textView).scrollable(scrollable).selectionFormat(format);
        if (extensions != null) view = view.markdownExtensions(extensions);
        final clicks = linkClicks;
        if (clicks != null) view = view.onLinkClick((url, event, _, _) -> clicks.push({url: url, event: event}));
        var root = div().w(px(width));
        if (height != null) root = root.h(px(height));
        return root.child(new TextSelectionLayer()).child(view);
    }
}

/** Rust `InlinePluginTestRoot`. */
private class InlinePluginTestRoot extends Model implements Render {
    public final textView:Entity<TextViewState>;
    public var width:Float = 420.;
    public var fontSize:Float = 16.;
    public var sourceFormat:Bool = false;
    public var preparedSize:Null<{value:Int}> = null;

    public function new(textView:Entity<TextViewState>) {
        super();
        this.textView = textView;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final preparedSize = this.preparedSize;
        return div().w(px(width)).textSize(px(fontSize)).child(new TextSelectionLayer()).child(
            TextView.create(textView)
                .selectionFormat(sourceFormat ? Source : Plain)
                .markdownPlugin(new TextTestInlinePlugin("math").parseWith((node, _) -> {
                    return switch node {
                        case InlineMath(math): new MarkdownNode("math", null).text('${math.value}²');
                        case _: null;
                    }
                }).renderWith((_, context, _, _) -> {
                    if (preparedSize == null) return null;
                    final value:Float = preparedSize.value;
                    final image = glaze.Image.fromBytes(ImageFormat.Svg, haxe.io.Bytes.ofString(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><path d="M0 0L40 40" stroke="black"/></svg>'));
                    final unit:Float = context.fontSize() / 16.;
                    return new InlineElement(img(image).w(px(unit * value)).h(px(unit * value))).withBaseline(px(unit * value * 0.75));
                })));
    }
}

/** A view rendered in a plain container (several Rust test roots). */
private class PlainRoot extends Model implements Render {
    final build:() -> IntoElement;

    public function new(build:() -> IntoElement) {
        super();
        this.build = build;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return build();
    }
}

/**
 * Tests of `glaze.kit.base.text.TextView` (Rust `text/text_view.rs`).
 */
@:access(glaze.kit.base.text)
class TextViewTest extends KitTestCase {

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    function addWindowView<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final result = VisualTestContext.addWindowView(app, dispatcher, build);
        contexts.push(result.cx);
        return result;
    }

    /**
     * Rust `crate::init(cx)`. The test fonts have no `Menlo` (the macOS
     * monospace family of the theme): code is set in JetBrains Mono.
     */
    public static function initBase(cx:App):Void {
        Base.init(cx);
        glaze.kit.base.theme.Theme.globalMut(cx).tokens.typography.mono = 'JetBrains Mono';
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
    }

    function testTextViewFollowsTheTextColorOfItsContainer() {
        final colors = ColorTokens.light();
        app.update(cx -> {
            initBase(cx);
            new glaze.kit.base.text.TextView.TextViewDefaults()
                .withStyle(TextViewStyle.defaultValue())
                .withInheritTextColor(true)
                .install(cx);
        });
        final result = addWindowView((_, cx) -> new TextColorRoot(
            cx.newEntity(cx -> TextViewState.markdown('[link](https://a.b) `code`', cx)),
            cx.newEntity(cx -> TextViewState.markdown('text', cx)),
            colors.primaryForeground
        ));
        result.cx.runUntilParked();
        draw(result.cx);

        final root = result.view.read(app);
        final inherited = root.inherited.read(app).textViewStyle;
        assertTrue(inherited.foreground().equals(colors.primaryForeground));
        assertTrue(inherited.link().equals(colors.primaryForeground));
        assertTrue(inherited.isDark());

        final explicit = root.explicit.read(app).textViewStyle;
        assertTrue(explicit.foreground().equals(colors.foreground));
        assertTrue(explicit.link().equals(TextViewStyle.defaultValue().link()));
    }

    // Helpers

    function initApp():Void {
        app.update(cx -> initBase(cx));
    }

    function addRoot(text:String):{view:Entity<TextViewTestRoot>, cx:VisualTestContext} {
        initApp();
        return addWindowView((_, cx) -> new TextViewTestRoot(text, cx));
    }

    static function drawn(cx:VisualTestContext):Void {
        cx.runUntilParked();
        draw(cx);
    }

    static function clickEvent(cx:VisualTestContext, position:Point, clickCount:Int, ?modifiers:Modifiers):Void {
        cx.simulateEvent(new MouseDownEvent(Left, position, modifiers != null ? modifiers : Modifiers.none(), clickCount, false));
        cx.simulateEvent(new MouseUpEvent(Left, position, modifiers != null ? modifiers : Modifiers.none(), clickCount));
    }

    static function dragFrom(cx:VisualTestContext, start:Point, end:Point):Void {
        cx.simulateMouseDown(start, Left);
        draw(cx);
        cx.simulateMouseMove(end, Left);
        draw(cx);
        cx.simulateMouseUp(end, Left);
        draw(cx);
    }

    function selectedOf(state:Entity<TextViewState>):String {
        return state.read(app).selectedText();
    }

    function windowSelectedText(cx:VisualTestContext):String {
        return cx.update((window, app) -> TextSelection.selectedText(window, app));
    }

    function captureOpenedUrls():Array<String> {
        final opened:Array<String> = [];
        app.platformOpenUrl = url -> opened.push(url);
        return opened;
    }

    // Construction and style

    function testTextViewConstructorsAreSelectableByDefault() {
        initApp();
        final state = app.update(cx -> cx.newEntity(cx -> TextViewState.markdown("state", cx)));
        assertTrue(TextView.create(state)._selectable);
        assertTrue(TextView.markdown("markdown", "text")._selectable);
        assertTrue(TextView.html("html", "<p>text</p>")._selectable);
    }

    function testPluginAcceptsTextViewPluginsBeyondMarkdown() {
        final plugin:glaze.kit.base.text.TextView.TextViewPlugin = new DummyTextViewPlugin();
        final view = TextView.markdown("plugin-test", "").selectable(false).plugin(plugin);
        assertTrue(view._selectable);
    }

    function testSyntaxHighlightingIsOptIn() {
        final defaultView = TextView.markdown("default-code", "```rust\nfn main() {}\n```");
        assertTrue(defaultView._codeBlockHighlighter == null);
        final view = defaultView.codeBlockHighlighter(block -> [
            new glaze.kit.base.input.StyledRange(new glaze.Range(0, Utf8.byteLength(block.code())), new glaze.HighlightStyle())
        ]);
        assertTrue(view._codeBlockHighlighter != null);
    }

    function testUnstyledTextViewUsesBaseTokensForLinkAndInputSelection() {
        initApp();
        app.update(cx -> {
            final colors = glaze.kit.base.theme.Theme.globalMut(cx).tokens.colors;
            colors.primary = rgb(0x55aaff).toHsla();
            colors.selection = rgb(0x335577).toHsla();
        });
        final result = addWindowView((_, cx) -> new TextViewTestRoot("[link](url)", cx));
        result.cx.runUntilParked();
        draw(result.cx);
        final style = result.view.read(app).textView.read(app).textViewStyle;
        assertTrue(style.link().equals(rgb(0x55aaff).toHsla()));
        assertTrue(style.selection().equals(rgb(0x335577).toHsla()));
    }

    function testInlineCodeViewRefinementKeepsUnspecifiedStyleProperties() {
        initApp();
        app.update(cx -> {
            final base = new StyleRefinement();
            base.text = new glaze.TextStyleRefinement();
            base.text.fontSize = glaze.AbsoluteLength.Rems(1.);
            base.background = new glaze.Background(Solid, Srgb, red());
            new glaze.kit.base.text.TextView.TextViewDefaults()
                .withStyle(TextViewStyle.defaultValue().withInlineCodeStyle(base))
                .install(cx);
        });
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown("before `code` after", cx));
            final s = state;
            final refinement = new StyleRefinement();
            refinement.borderWidthLeft = glaze.AbsoluteLength.Pixels(1.);
            refinement.borderWidthRight = glaze.AbsoluteLength.Pixels(1.);
            refinement.borderWidthTop = glaze.AbsoluteLength.Pixels(1.);
            refinement.borderWidthBottom = glaze.AbsoluteLength.Pixels(1.);
            refinement.borderColor = blue();
            return new PlainRoot(() -> TextView.create(s).inlineCodeStyle(refinement));
        });
        drawn(result.cx);
        final style = state.read(app).textViewStyle.inlineCodeStyle();
        assertTrue(style.text != null && Type.enumEq(style.text.fontSize, glaze.AbsoluteLength.Rems(1.)));
        assertTrue(style.background != null);
        assertTrue(style.borderColor != null && style.borderColor.equals(blue()));
        assertTrue(Type.enumEq(style.borderWidthLeft, glaze.AbsoluteLength.Pixels(1.)));
    }

    function testListAndBlockquoteViewRefinementsKeepUnspecifiedStyleProperties() {
        initApp();
        app.update(cx -> {
            final list = new StyleRefinement();
            list.text = new glaze.TextStyleRefinement();
            list.text.fontWeight = glaze.FontWeight.BOLD;
            final quote = new StyleRefinement();
            quote.borderWidthLeft = glaze.AbsoluteLength.Pixels(4.);
            new glaze.kit.base.text.TextView.TextViewDefaults()
                .withStyle(TextViewStyle.defaultValue().withListStyle(list).withBlockquoteStyle(quote))
                .install(cx);
        });
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown("- item\n\n> quote", cx));
            final s = state;
            final listRefinement = new StyleRefinement();
            listRefinement.text = new glaze.TextStyleRefinement();
            listRefinement.text.color = blue();
            final quoteRefinement = new StyleRefinement();
            quoteRefinement.borderColor = blue();
            return new PlainRoot(() -> TextView.create(s).listStyle(listRefinement).blockquoteStyle(quoteRefinement));
        });
        drawn(result.cx);
        final style = state.read(app).textViewStyle;
        final marker = style.listStyle();
        assertTrue(marker.text.color.equals(blue()));
        assertEquals(glaze.FontWeight.BOLD, marker.text.fontWeight);
        final quote = style.blockquoteStyle();
        assertTrue(quote.borderColor.equals(blue()));
        assertTrue(Type.enumEq(quote.borderWidthLeft, glaze.AbsoluteLength.Pixels(4.)));
    }

    // Documents

    static function documentOf(count:Int, words:Int):String {
        return [for (i in 1...count + 1) 'Block $i: ' + [for (_ in 0...words) "lorem ipsum dolor "].join('')].join("\n\n");
    }

    function testReplacingADocumentWithAnEqualBlockCountRemeasures() {
        initApp();
        final blocks = 24;
        final short = documentOf(blocks, 1);
        final tall = documentOf(blocks, 60);
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown(short, cx));
            final s = state;
            return new PlainRoot(() -> div().w(px(400.)).h(px(200.)).overflowHidden().child(TextView.create(s).scrollable(true)));
        });
        final cx = result.cx;
        function settle() {
            cx.runUntilParked();
            draw(cx);
            cx.runUntilParked();
        }
        settle();
        final shortExtent = state.read(app).listState.maxOffsetForScrollbar().y;
        app.update(app -> state.update(app, (state, cx) -> state.setText(tall, cx)));
        settle();
        assertEquals(blocks, state.read(app).listState.itemCount(), 'the replacement must keep the block count');
        final tallExtent = state.read(app).listState.maxOffsetForScrollbar().y;
        assertTrue(tallExtent > shortExtent * 5., 'a much taller document must grow the scroll extent: $shortExtent to $tallExtent');
    }

    function testInlineImageKeepsSurroundingTextOnSameLine() {
        initApp();
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown("Build Status ![inline image](https://example.com/image.svg) after", cx));
            final s = state;
            return new PlainRoot(() -> div().w(px(420.)).child(TextView.create(s).selectable(true)));
        });
        drawn(result.cx);
        final inlineBounds = state.read(app).selectionAdapter.textBounds();
        assertEquals(2, inlineBounds.length);
        assertEquals(inlineBounds[0].top(), inlineBounds[1].top(), 'text before and after an inline image should share a rendered line');
        assertTrue(inlineBounds[1].left() - inlineBounds[0].right() > 8., 'inline image should reserve horizontal space in the text layout');
        assertTrue(inlineBounds[1].left() - inlineBounds[0].right() < 40., 'unloaded inline image fallback should stay generic and compact');
    }

    function testInlineHtmlImageAfterNewlineDoesNotPanic() {
        final result = addRoot("Hi\n[<img src=\"https://example.com/image.svg\">](https://google.com/)");
        drawn(result.cx);
        assertTrue(true);
    }

    function testStatelessMarkdownWithRebuiltParserSettles() {
        initApp();
        var renders = 0;
        final source = [for (i in 0...40) '## Section $i\n\nSome **text** with `code` and a [link](https://example.com).'].join("\n\n");
        final result = addWindowView((_, _) -> new PlainRoot(() -> {
            renders++;
            return div().child(TextView.markdown("stateless-markdown", source).markdownBlockParser((_, _) -> null));
        }));
        final cx = result.cx;
        cx.runUntilParked();
        draw(cx);
        final rendersAfterRedraw = renders;
        cx.runUntilParked();
        assertEquals(rendersAfterRedraw, renders, 'an unchanged TextView must not schedule another render after its parser is rebuilt');
    }

    // Clip

    function testTheClipOnlyMovesForAStraddlingGlyphLine() {
        final spans = [
            // Lines end at 20 / 40 / 60.
            new LineSpan(0., 60., 20.),
            // A second block after an 8px gap; lines end at 88 / 108 / 128.
            new LineSpan(68., 128., 20.),
        ];
        // Content continues well past the box in every case but the last.
        final below = 400.;
        // A box ending inside the line 88..108 leaves that line out whole.
        assertEquals(88., TextView.lineSafeClipBottom(spans, 100., below));
        // A box ending on a line boundary has nothing to pull the clip up for.
        assertEquals(null, TextView.lineSafeClipBottom(spans, 88., below));
        // A strip below the last line shorter than a line is not worth showing.
        assertEquals(60., TextView.lineSafeClipBottom(spans, 64., below));
        // One taller than a line is.
        final oneBlock = [new LineSpan(0., 60., 20.)];
        assertEquals(null, TextView.lineSafeClipBottom(oneBlock, 200., below));
        // Nothing crosses the edge at all.
        assertEquals(null, TextView.lineSafeClipBottom(spans, 130., 128.));
    }

    function testALineTallerThanTheBudgetKeepsThePartThatFits() {
        // A heading line of 28px, in a box capped at one 26px body line.
        final heading = [new LineSpan(70., 98., 28.)];
        assertEquals(null, TextView.lineSafeClipBottom(heading, 96., 400.));
    }

    function testTheClipDoesNotStopOnARowOfBorderAndPadding() {
        // Two table rows, each one line of text, 9px of border and padding
        // between them.
        final rows = [new LineSpan(100., 126., 26.), new LineSpan(135., 161., 26.)];
        // Leaving out the second row's text would strand the 9px it leads
        // with, so the clip goes back to the row above it.
        assertEquals(126., TextView.lineSafeClipBottom(rows, 148., 400.));
    }

    function maxLinesRoot(text:String, maxLines:Int):{state:Entity<TextViewState>, cx:VisualTestContext} {
        initApp();
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown(text, cx));
            final s = state;
            return new PlainRoot(() -> div().w(px(200.)).child(TextView.create(s).maxLines(maxLines)));
        });
        return {state: state, cx: result.cx};
    }

    function testMaxLinesClampsOverflowingContent() {
        final root = maxLinesRoot("first\n\nsecond\n\nthird\n\nfourth\n\nfifth\n\nsixth", 2);
        assertTrue(root.state.read(app).isClamped());
    }

    function testMaxLinesLeavesShortContentUnclamped() {
        final root = maxLinesRoot("only line", 3);
        assertFalse(root.state.read(app).isClamped());
    }

    function testMaxLinesMeasuresOverflowInsideASizedPage() {
        initApp();
        var state:Entity<TextViewState> = null;
        addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown("first\n\nsecond\n\nthird\n\nfourth\n\nfifth\n\nsixth\n\nseventh", cx));
            final s = state;
            return new PlainRoot(() -> glaze.kit.base.Prelude.vFlex()
                .sizeFull()
                .p4()
                .gap4()
                .child(glaze.kit.base.Prelude.hFlex().maxW(px(480.)).gap3().child("header"))
                .child(glaze.kit.base.Prelude.vFlex()
                    .flex1()
                    .minH0()
                    .gap4()
                    .id("clamped-page-scroll")
                    .child(glaze.kit.base.Prelude.vFlex().maxW(px(480.)).p3().gap2().child(TextView.create(s).maxLines(3)))
                    .overflowYScroll()));
        });
        assertTrue(state.read(app).isClamped());
    }

    function testMaxLinesDisablesLinksHiddenByTheClamp() {
        final opened = captureOpenedUrls();
        final root = maxLinesRoot("first\n\nsecond\n\nthird\n\n[hidden](https://example.com)", 2);
        // Click far below the clamped box, where the link would sit unclamped.
        root.cx.simulateClick(new Point(10., 150.));
        assertEquals(0, opened.length);
    }

    // Links

    function testMarkdownLinkOpensUrlWithoutHandler() {
        final opened = captureOpenedUrls();
        final result = addRoot("[example](https://example.com)");
        result.cx.simulateClick(new Point(10., 10.));
        assertEquals("https://example.com", opened.join(','));
    }

    function testRightClickDoesNotOpenUrlWithoutHandler() {
        final opened = captureOpenedUrls();
        final result = addRoot("[example](https://example.com)");
        result.cx.simulateMouseDown(new Point(10., 10.), Right);
        result.cx.simulateMouseUp(new Point(10., 10.), Right);
        assertEquals(0, opened.length);
    }

    function testClippedMarkdownLinkDoesNotOpen() {
        final opened = captureOpenedUrls();
        final result = addRoot("visible\n\n[hidden](https://example.com)");
        result.cx.simulateClick(new Point(10., 34.));
        assertEquals(0, opened.length);
    }

    function testLinkHandlerReceivesButtonAndModifiers() {
        final opened = captureOpenedUrls();
        initApp();
        final clicks:Array<{url:String, event:ClickEvent}> = [];
        final result = addWindowView((_, cx) -> {
            final root = new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("[example](https://example.com)", cx)), 240.);
            root.linkClicks = clicks;
            return root;
        });
        final cx = result.cx;
        cx.simulateClick(new Point(10., 10.), Modifiers.none().withControl(true));
        cx.simulateMouseDown(new Point(10., 10.), Middle);
        cx.simulateMouseUp(new Point(10., 10.), Middle);
        cx.simulateMouseDown(new Point(10., 10.), Right);
        cx.simulateMouseUp(new Point(10., 10.), Right);

        assertEquals(3, clicks.length);
        assertEquals("https://example.com", clicks[0].url);
        assertTrue(!glaze.ClickEvent.ClickEventTools.isRightClick(clicks[0].event) && !glaze.ClickEvent.ClickEventTools.isMiddleClick(clicks[0].event));
        assertTrue(glaze.ClickEvent.ClickEventTools.modifiers(clicks[0].event).control);
        assertTrue(glaze.ClickEvent.ClickEventTools.isMiddleClick(clicks[1].event));
        assertTrue(glaze.ClickEvent.ClickEventTools.isRightClick(clicks[2].event));
        assertEquals(0, opened.length);
    }

    function testScaledInlineCodeKeepsLinksAndDragSelection() {
        final opened = captureOpenedUrls();
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("[`code`](https://example.com) after", cx)), 160.));
        final cx = result.cx;
        cx.runUntilParked();
        cx.simulateClick(new Point(10., 10.));
        assertEquals("https://example.com", opened.join(','));
        // Just past the code span's leading padding, on its first glyph.
        cx.simulateMouseDown(new Point(5., 8.), Left);
        draw(cx);
        cx.simulateMouseMove(new Point(155., 20.), Left);
        draw(cx);
        cx.simulateMouseUp(new Point(155., 20.), Left);
        draw(cx);
        final state = result.view.read(app).textView;
        assertEquals("code after", StringTools.trim(selectedOf(state)));
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.format = Source;
            cx.notify();
        }));
        draw(cx);
        assertEquals("[`code`](https://example.com) after", StringTools.trim(selectedOf(state)));
    }

    // Selection

    function testClippedMarkdownCannotStartSelection() {
        final result = addRoot("visible\n\nhidden selection text");
        final cx = result.cx;
        cx.simulateMouseDown(new Point(10., 34.), Left);
        cx.simulateMouseMove(new Point(90., 34.), Left);
        cx.simulateMouseUp(new Point(90., 34.), Left);
        final selected = selectedOf(result.view.read(app).textView);
        assertEquals("", selected);
    }

    function testSelectionBandBeyondClipCopiesOffscreenText() {
        initApp();
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown("alpha\n\nbravo\n\ncharlie\n\ndelta", cx));
            final s = state;
            return new PlainRoot(() -> div()
                .w(px(200.))
                .child(new TextSelectionLayer())
                .child(div().h(px(40.)).overflowHidden().child(TextView.create(s).selectable(true)))
                .child(div().h(px(160.))));
        });
        final cx = result.cx;
        drawn(cx);
        dragFrom(cx, new Point(2., 8.), new Point(180., 150.));
        final selected = selectedOf(state);
        assertTrue(selected.indexOf("delta") != -1, 'clipped-out text was not copied: $selected');
        assertTrue(selected.indexOf("charlie") != -1, 'clipped-out text was not copied: $selected');
    }

    function testDoubleClickSelectsWord() {
        final result = addRoot("quick select value");
        final cx = result.cx;
        drawn(cx);
        clickEvent(cx, new Point(10., 16.), 2);
        draw(cx);
        assertEquals("quick", StringTools.trim(selectedOf(result.view.read(app).textView)));
    }

    static function longPressEvent(cx:VisualTestContext, phase:glaze.TouchPhase, start:Point, position:Point):Void {
        cx.simulateEvent(new glaze.LongPressEvent(phase, start, position));
    }

    function testLongPressSelectsWordThenDragExtendsSelection() {
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("quick select value", cx)), 300.));
        final cx = result.cx;
        drawn(cx);
        final startPosition = new Point(10., 16.);
        longPressEvent(cx, Started, startPosition, startPosition);
        draw(cx);
        assertEquals("quick", StringTools.trim(selectedOf(result.view.read(app).textView)));
        for (phase in [glaze.TouchPhase.Moved, glaze.TouchPhase.Ended]) {
            longPressEvent(cx, phase, startPosition, new Point(220., 16.));
        }
        draw(cx);
        assertEquals("quick select value", StringTools.trim(selectedOf(result.view.read(app).textView)));
    }

    function testLongPressReleaseKeepsHandlesWhichDragTheSelection() {
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("quick select value", cx)), 300.));
        final cx = result.cx;
        final view = result.view;
        function selected():String {
            return StringTools.trim(selectedOf(view.read(app).textView));
        }
        drawn(cx);

        final startPosition = new Point(70., 16.);
        for (phase in [glaze.TouchPhase.Started, glaze.TouchPhase.Ended]) {
            longPressEvent(cx, phase, startPosition, startPosition);
            draw(cx);
        }
        assertEquals("select", selected());
        var snapshot = cx.update((window, app) -> TextSelection.touchSelection(window, app));
        assertNotNull(snapshot, "a released long press keeps its handles");
        assertTrue(snapshot.isMenuOpen());
        assertFalse(snapshot.isEmpty());
        assertTrue(snapshot.start().left() < snapshot.end().left());

        // Drag the end handle to the end of the line. The finger holds the
        // knob below the line, the selection follows along the line.
        final end = snapshot.end();
        final finger = new Point(end.left(), end.bottom() + 20.);
        cx.update((window, app) -> TextSelection.beginEdgeDrag(glaze.kit.base.input.SelectionEdge.End, finger, window, app));
        draw(cx);
        snapshot = cx.update((window, app) -> TextSelection.touchSelection(window, app));
        assertEquals(glaze.kit.base.input.SelectionEdge.End, snapshot.dragging());
        assertFalse(snapshot.isMenuOpen());
        cx.update((window, app) -> TextSelection.updateEdgeDrag(new Point(290., finger.y), window, app));
        draw(cx);
        assertEquals("select value", selected());
        cx.update((window, app) -> TextSelection.endEdgeDrag(window, app));
        draw(cx);
        snapshot = cx.update((window, app) -> TextSelection.touchSelection(window, app));
        assertTrue(snapshot.isMenuOpen());
        assertNull(snapshot.dragging());
        final selectStart = snapshot.start().left();

        // Select All from the menu is a view-local selection; its handles
        // still drag, turning it back into a point selection.
        cx.update((_, app) -> view.read(app).textView.update(app, (state, cx) -> state.selectAll(cx)));
        draw(cx);
        assertEquals("quick select value", selected());
        snapshot = cx.update((window, app) -> TextSelection.touchSelection(window, app));
        assertNotNull(snapshot, "select all keeps the touch selection");
        final start = snapshot.start();
        cx.update((window, app) -> {
            TextSelection.beginEdgeDrag(glaze.kit.base.input.SelectionEdge.Start, start.origin, window, app);
            TextSelection.updateEdgeDrag(new Point(selectStart, start.origin.y), window, app);
            TextSelection.endEdgeDrag(window, app);
        });
        draw(cx);
        assertEquals("select value", selected());

        // A press on the menu leaves the selection alone; one on the text
        // clears it.
        final menu = new glaze.Bounds(new Point(0., 200.), new glaze.Size(120., 32.));
        cx.update((window, app) -> TextSelection.registerTouchUi(menu, window, app));
        cx.simulateEvent(new MouseDownEvent(Left, new Point(10., 210.), Modifiers.none(), 1, false));
        assertEquals("select value", selected());
        cx.simulateEvent(new MouseDownEvent(Left, new Point(10., 16.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(10., 16.), Modifiers.none(), 1));
        draw(cx);
        assertNull(cx.update((window, app) -> TextSelection.touchSelection(window, app)));
    }

    function testTripleClickSelectsParagraph() {
        final result = addRoot("quick select value");
        final cx = result.cx;
        drawn(cx);
        clickEvent(cx, new Point(10., 10.), 3);
        draw(cx);
        assertEquals("quick select value", StringTools.trim(selectedOf(result.view.read(app).textView)));
    }

    function inlinePluginRoot(markdown:String):{view:Entity<InlinePluginTestRoot>, cx:VisualTestContext} {
        initApp();
        return addWindowView((_, cx) -> new InlinePluginTestRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx))));
    }

    function testTripleClickOnFormulaSelectsItsEntireMixedLine() {
        final result = inlinePluginRoot("before $x$ after");
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final regions = state.read(app).selectionAdapter.textBounds();
        clickEvent(cx, regions[1].center(), 3);
        draw(cx);
        assertEquals("before x² after", StringTools.trim(selectedOf(state)));
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.sourceFormat = true;
            cx.notify();
        }));
        draw(cx);
        assertEquals("before $x$ after", StringTools.trim(selectedOf(state)));
    }

    function testDoubleClickOnFormulaSelectsOnlyThatObject() {
        final result = inlinePluginRoot("before $x$ after");
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final regions = state.read(app).selectionAdapter.textBounds();
        clickEvent(cx, regions[1].center(), 2);
        draw(cx);
        // Two clicks stop at the object; only three take the whole line.
        assertEquals("x²", StringTools.trim(selectedOf(state)));
    }

    function testInlinePluginsDragAndCopyAcrossFormulasInBothDirections() {
        final result = inlinePluginRoot("中文 $x$ $y$ English");
        final cx = result.cx;
        final state = result.view.read(app).textView;
        for (fontSize in [16., 24., 32.]) {
            for (width in [60., 160., 420.]) {
                for (prepared in [null, 32]) {
                    for (sourceFormat in [false, true]) {
                        app.update(app -> result.view.update(app, (root, cx) -> {
                            root.sourceFormat = sourceFormat;
                            root.width = width;
                            root.fontSize = fontSize;
                            root.preparedSize = prepared != null ? {value: prepared} : null;
                            cx.notify();
                        }));
                        drawn(cx);
                        final textBounds = state.read(app).selectionAdapter.textBounds();
                        final first = textBounds[0];
                        final last = textBounds[textBounds.length - 1];
                        final left = new Point(first.left() + 0.1, first.top() + first.size.height / 2.);
                        final right = new Point(last.right() - 0.1, last.top() + last.size.height / 2.);
                        for (pair in [[left, right], [right, left]]) {
                            dragFrom(cx, pair[0], pair[1]);
                            assertEquals(sourceFormat ? "中文 $x$ $y$ English" : "中文 x² y² English", StringTools.trim(selectedOf(state)),
                                'width=$width font_size=$fontSize prepared=$prepared');
                        }
                    }
                }
            }
        }
    }

    function testInlineResourceSizeUpdateReflowsWithoutChangingSelection() {
        final result = inlinePluginRoot("中文 $x$ $y$ English");
        final prepared = {value: 16};
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.width = 160.;
            root.preparedSize = prepared;
            cx.notify();
        }));
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final before = state.read(app).bounds();
        final regions = state.read(app).selectionAdapter.textBounds();
        final first = regions[0];
        final last = regions[regions.length - 1];
        dragFrom(cx, new Point(first.left() + 0.1, first.top() + 10.), new Point(last.right() - 0.1, last.top() + 10.));
        assertEquals("中文 x² y² English", StringTools.trim(selectedOf(state)));
        prepared.value = 100;
        app.update(app -> state.update(app, (state, cx) -> state.invalidateInlineLayout(cx)));
        drawn(cx);
        final after = state.read(app).bounds();
        assertTrue(after.size.height > before.size.height * 2.);
        assertEquals("中文 x² y² English", StringTools.trim(selectedOf(state)));
    }

    // Tables

    static final TABLE = "| Header 1 | Header 2 |\n| --- | --- |\n| Cell A | Cell B |\n| Cell C | Cell D |";

    function testTableDragSelectionSettlesWithoutRequestingIdleFrames() {
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown(TABLE, cx)), 520.));
        final cx = result.cx;
        drawn(cx);
        // Rust reads the root's debug bounds: the view fills the root's width.
        final bounds = result.view.read(app).textView.read(app).bounds();
        final start = new Point(bounds.left() + 24., bounds.top() + 16.);
        final end = new Point(bounds.right() - 24., bounds.bottom() - 16.);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(end, Left);
        cx.simulateMouseUp(end, Left);

        assertTrue(cx.update((window, app) -> TextSelection.hasSelection(window, app)));
        assertEquals(0, cx.update((window, app) -> window.simulateNextFrame(app)), 'finished table selection must not continuously request frames');
    }

    function testTableDragFromACellStaysInThatCell() {
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown('Intro\n\n$TABLE', cx)), 520.));
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final textBounds = state.read(app).selectionAdapter.textBounds();
        assertEquals(7, textBounds.length);
        final intro = textBounds[0];
        final cellA = textBounds[3];
        final cellB = textBounds[4];
        final cellD = textBounds[6];
        // Rust reads the root's debug bounds: the view fills the root's width.
        final table = state.read(app).bounds();
        function startOf(bounds:Bounds):Point return new Point(bounds.left() + 0.1, bounds.center().y);
        function endOf(bounds:Bounds):Point return new Point(bounds.right() - 0.1, bounds.center().y);
        function drag(start:Point, end:Point):Array<String> {
            dragFrom(cx, start, end);
            return [StringTools.trim(selectedOf(state)), StringTools.trim(windowSelectedText(cx))];
        }

        // Down and right, out of the table: the rest of the cell, nothing else.
        final below = new Point(table.right() - 2., table.bottom() - 1.);
        assertEquals("Cell A|Cell A", drag(startOf(cellA), below).join('|'));

        // Back along its line into the cell before it, and up and out of the
        // table: the start of the cell, nothing else.
        final left = new Point(cellA.center().x, cellB.center().y);
        assertEquals("Cell B|Cell B", drag(endOf(cellB), left).join('|'));
        final above = new Point(table.left() + 2., intro.top());
        assertEquals("Cell B|Cell B", drag(endOf(cellB), above).join('|'));

        // From the paragraph before the table, the selection goes through it.
        final both = drag(startOf(intro), endOf(cellD));
        for (text in ["Intro", "Header 1", "Cell A", "Cell B", "Cell C", "Cell D"]) {
            assertTrue(both[0].indexOf(text) != -1, '$text not in ${both[0]}');
            assertTrue(both[1].indexOf(text) != -1, '$text not in ${both[1]}');
        }

        // Copy before the frame that paints the last move.
        cx.simulateMouseDown(startOf(cellA), Left);
        draw(cx);
        cx.simulateMouseMove(endOf(cellA), Left);
        draw(cx);
        cx.simulateMouseMove(below, Left);
        cx.simulateMouseUp(below, Left);
        assertEquals("Cell A", StringTools.trim(windowSelectedText(cx)));
    }

    function testTableCellCopyExcludesFollowingBlocksInAScrollableView() {
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown(
            "| Header | Other |\n| --- | --- |\n| Cell A | Cell B |\n\nMiddle paragraph\n\nLast paragraph", cx)), 520., 400., true));
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final rows = state.read(app).selectionAdapter.textBounds();
        assertEquals(6, rows.length);
        final start = new Point(rows[2].left() + 0.1, rows[2].center().y);
        final inside = new Point(rows[2].right() - 0.1, rows[2].center().y);
        final end = new Point(rows[5].right() - 0.1, rows[5].center().y);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(inside, Left);
        draw(cx);
        // The copy callback must constrain the logical block range even before paint.
        cx.simulateMouseMove(end, Left);
        cx.simulateMouseUp(end, Left);
        for (format in [SelectionFormat.Plain, SelectionFormat.Source]) {
            app.update(app -> state.update(app, (state, cx) -> state.setSelectionFormat(format, cx)));
            assertEquals("Cell A", StringTools.trim(windowSelectedText(cx)), Std.string(format));
        }
        draw(cx);
        assertEquals("Cell A", StringTools.trim(selectedOf(state)));
    }

    function testTableCellSelectionDoesNotLeakIntoAnotherWindow() {
        initApp();
        final first = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("| Header | Other |\n| --- | --- |\n| Cell A | Cell B |", cx)), 520.));
        drawn(first.cx);
        final firstRows = first.view.read(app).textView.read(app).selectionAdapter.textBounds();
        final start = new Point(firstRows[0].left() + 0.1, firstRows[0].center().y);
        final firstEnd = new Point(firstRows[0].right() - 0.1, firstRows[0].center().y);
        first.cx.simulateMouseDown(start, Left);
        first.cx.simulateMouseMove(firstEnd, Left);
        first.cx.simulateMouseUp(firstEnd, Left);
        draw(first.cx);
        assertEquals("Header", StringTools.trim(windowSelectedText(first.cx)));

        final second = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("ordinary text in another window", cx)), 520.));
        drawn(second.cx);
        final state = second.view.read(app).textView;
        final rows = state.read(app).selectionAdapter.textBounds();
        assertTrue(rows[0].contains(start), '$start, $rows');
        final end = new Point(rows[0].right() - 0.1, rows[0].center().y);
        second.cx.simulateMouseDown(start, Left);
        second.cx.simulateMouseMove(end, Left);
        second.cx.simulateMouseUp(end, Left);
        draw(second.cx);
        final selected = selectedOf(state);
        assertTrue(StringTools.trim(selected).length > 0);
        assertEquals(selected, windowSelectedText(second.cx));
    }

    // Multi-click drags

    function multiClickSetup(markdown:String):{state:Entity<TextViewState>, cx:VisualTestContext} {
        initApp();
        final result = addWindowView((_, cx) -> new LayerRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx)), 400.));
        drawn(result.cx);
        return {state: result.view.read(app).textView, cx: result.cx};
    }

    function position(state:Entity<TextViewState>, text:String, index:Int):Point {
        return state.read(app).selectionAdapter.textPosition(text, index);
    }

    static function press(cx:VisualTestContext, position:Point, clickCount:Int, shift:Bool):Void {
        cx.simulateEvent(new MouseDownEvent(Left, position, Modifiers.none().withShift(shift), clickCount, false));
    }

    static function drag(cx:VisualTestContext, position:Point):Void {
        cx.simulateEvent(new MouseMoveEvent(position, Left, Modifiers.none()));
    }

    static function release(cx:VisualTestContext, position:Point, clickCount:Int):Void {
        cx.simulateEvent(new MouseUpEvent(Left, position, Modifiers.none(), clickCount));
    }

    function selected(state:Entity<TextViewState>, cx:VisualTestContext):String {
        draw(cx);
        return StringTools.trim(state.read(app).selectedText());
    }

    function testDoubleClickDragExtendsTheSelectionByWords() {
        final first = "alpha beta gamma";
        final second = "delta epsilon zeta";
        final m = multiClickSetup('$first\n\n$second');
        press(m.cx, position(m.state, first, 7), 2, false);
        assertEquals("beta", selected(m.state, m.cx));
        drag(m.cx, position(m.state, first, 8));
        assertEquals("beta", selected(m.state, m.cx));
        drag(m.cx, position(m.state, first, 13));
        assertEquals("beta gamma", selected(m.state, m.cx));
        // Backward, the whole of the word the drag started from stays.
        drag(m.cx, position(m.state, first, 1));
        assertEquals("alpha beta", selected(m.state, m.cx));
        final end = position(m.state, second, 8);
        drag(m.cx, end);
        assertEquals("beta gamma\ndelta epsilon", selected(m.state, m.cx));
        release(m.cx, end, 2);
        assertEquals("beta gamma\ndelta epsilon", selected(m.state, m.cx));
    }

    function testTripleClickDragExtendsTheSelectionByParagraphs() {
        final m = multiClickSetup("first one\n\nsecond one\n\nthird one");
        press(m.cx, position(m.state, "second one", 2), 3, false);
        assertEquals("second one", selected(m.state, m.cx));
        drag(m.cx, position(m.state, "third one", 2));
        assertEquals("second one\nthird one", selected(m.state, m.cx));
        final end = position(m.state, "first one", 2);
        drag(m.cx, end);
        assertEquals("first one\nsecond one", selected(m.state, m.cx));
        release(m.cx, end, 3);
        assertEquals("first one\nsecond one", selected(m.state, m.cx));
    }

    /** A hard break adds a line to a paragraph without ending that paragraph. */
    function testTripleClickDragAndShiftClickKeepHardBreakParagraphsWhole() {
        final first = "first top\nfirst bottom";
        final last = "last top\nlast bottom";
        final m = multiClickSetup("first top  \nfirst bottom\n\nmiddle\n\nlast top  \nlast bottom");
        press(m.cx, position(m.state, "middle", 2), 3, false);
        assertEquals("middle", selected(m.state, m.cx));
        final after = position(m.state, last, 2);
        drag(m.cx, after);
        assertEquals('middle\n$last', selected(m.state, m.cx));
        final before = position(m.state, first, "first top\n".length + 2);
        drag(m.cx, before);
        assertEquals('$first\nmiddle', selected(m.state, m.cx));
        release(m.cx, before, 3);

        press(m.cx, after, 1, true);
        release(m.cx, after, 1);
        assertEquals('middle\n$last', selected(m.state, m.cx));
        press(m.cx, before, 1, true);
        release(m.cx, before, 1);
        assertEquals('$first\nmiddle', selected(m.state, m.cx));
    }

    /** Inline code lays a paragraph out in pieces; the drag snaps the same. */
    function testMultiClickDragSnapsAcrossInlineCode() {
        final m = multiClickSetup("plain words\n\nuse `code` in here");
        press(m.cx, position(m.state, "plain words", 8), 2, false);
        drag(m.cx, position(m.state, " in here", 6));
        assertEquals("words\nuse code in here", selected(m.state, m.cx));
        release(m.cx, position(m.state, " in here", 6), 2);

        press(m.cx, position(m.state, "plain words", 2), 3, false);
        assertEquals("plain words", selected(m.state, m.cx));
        drag(m.cx, position(m.state, "use ", 1));
        assertEquals("plain words\nuse code in here", selected(m.state, m.cx));
    }

    function testShiftClickAfterADoubleClickExtendsByWords() {
        final text = "alpha beta gamma";
        final m = multiClickSetup(text);
        final word = position(m.state, text, 7);
        press(m.cx, word, 2, false);
        release(m.cx, word, 2);
        final after = position(m.state, text, 13);
        press(m.cx, after, 1, true);
        release(m.cx, after, 1);
        assertEquals("beta gamma", selected(m.state, m.cx));
        final before = position(m.state, text, 1);
        press(m.cx, before, 1, true);
        release(m.cx, before, 1);
        assertEquals("alpha beta", selected(m.state, m.cx));
    }

    // Copy before paint

    static final MARKDOWN = "中文 **café**\n\nβeta `\u{2009}code\u{2009}` 👩‍💻\n\n終わり";
    static final PLAIN = "中文 café\nβeta \u{2009}code\u{2009} 👩‍💻\n終わり\n";

    function copyDocument(markdown:String, format:SelectionFormat, scrollable:Bool):{view:Entity<LayerRoot>, cx:VisualTestContext} {
        initApp();
        final result = addWindowView((_, cx) -> {
            final root = new LayerRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx)), 520., scrollable ? 160. : null, scrollable);
            root.format = format;
            return root;
        });
        drawn(result.cx);
        return result;
    }

    function copySetup(format:SelectionFormat):{state:Entity<TextViewState>, cx:VisualTestContext} {
        final result = copyDocument(MARKDOWN, format, false);
        return {state: result.view.read(app).textView, cx: result.cx};
    }

    function endpoints(state:Entity<TextViewState>):Array<Point> {
        final rows = state.read(app).selectionAdapter.textBounds();
        final first = rows[0];
        final last = rows[rows.length - 1];
        return [
            new Point(first.left() + 0.1, first.center().y),
            new Point(first.right() - 0.1, first.center().y),
            new Point(last.right() - 0.1, last.center().y),
        ];
    }

    // Raw dispatch: no draw after each packet.
    static function rawPress(position:Point, window:Window, cx:App):Void {
        window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false), cx);
    }

    static function rawExtend(position:Point, window:Window, cx:App):Void {
        window.dispatchEvent(new MouseMoveEvent(position, Left, Modifiers.none()), cx);
    }

    static function rawRelease(position:Point, window:Window, cx:App):Void {
        window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1), cx);
    }

    function assertCopy(expected:String, window:Window, cx:App, ?pos:haxe.PosInfos):Void {
        // Dispatch synchronously on the native current focus.
        final focus = window.focused(cx);
        assertTrue(focus != null, 'gesture focuses TextView', pos);
        focus.dispatchAction(new Copy(), window, cx);
        final item = cx.readFromClipboard();
        assertEquals(StringTools.trim(expected), item != null ? item.text() : null, null, pos);
        assertTrue(focus.isFocused(window), null, pos);
        assertEquals(expected, TextSelection.selectedText(window, cx), null, pos);
    }

    function testANewRangeCopiesBeforeItsFirstSelectionPaint() {
        final c = copySetup(Plain);
        final points = endpoints(c.state);
        c.cx.update((window, cx) -> {
            rawPress(points[0], window, cx);
            rawExtend(points[2], window, cx);
            assertCopy(PLAIN, window, cx);
            return true;
        });
    }

    function testAnEstablishedRangeExtendsAndRetractsWithoutPaint() {
        final c = copySetup(Plain);
        final points = endpoints(c.state);
        c.cx.update((window, cx) -> {
            rawPress(points[0], window, cx);
            rawExtend(points[1], window, cx);
            return true;
        });
        draw(c.cx);
        c.cx.update((window, cx) -> {
            assertCopy("中文 café\n", window, cx);
            rawExtend(points[2], window, cx);
            assertCopy(PLAIN, window, cx);
            rawExtend(points[1], window, cx);
            assertCopy("中文 café\n", window, cx);
            return true;
        });
    }

    function testSourceCopyProjectsTheCurrentRangeWithoutPaint() {
        final c = copySetup(Source);
        final points = endpoints(c.state);
        c.cx.update((window, cx) -> {
            rawPress(points[0], window, cx);
            rawExtend(points[1], window, cx);
            assertCopy("中文 **café**", window, cx);
            rawExtend(points[2], window, cx);
            assertCopy(MARKDOWN, window, cx);
            rawExtend(points[1], window, cx);
            assertEquals("中文 **café**", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    function testABlankGestureDoesNotReuseThePreviousRange() {
        final c = copySetup(Plain);
        final points = endpoints(c.state);
        c.cx.update((window, cx) -> {
            rawPress(points[0], window, cx);
            rawExtend(points[2], window, cx);
            assertEquals(PLAIN, TextSelection.selectedText(window, cx));
            rawRelease(points[2], window, cx);
            rawPress(points[1].add(new Point(20., 0.)), window, cx);
            rawExtend(points[1].add(new Point(60., 0.)), window, cx);
            assertEquals("", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    function testReplacingSourceCannotReprojectOldContent() {
        for (format in [SelectionFormat.Plain, SelectionFormat.Source]) {
            for (replacement in ["replacement", [for (_ in 0...500) "replacement "].join('')]) {
                final c = copySetup(format);
                final points = endpoints(c.state);
                c.cx.update((window, cx) -> {
                    rawPress(points[0], window, cx);
                    rawExtend(points[2], window, cx);
                    assertEquals(format == Plain ? PLAIN : MARKDOWN, TextSelection.selectedText(window, cx));
                    // Large replacements leave the previous parsed document in
                    // place while parsing; neither size may reuse it.
                    c.state.update(cx, (state, cx) -> state.setText(replacement, cx));
                    assertEquals("", TextSelection.selectedText(window, cx));
                    return true;
                });
            }
        }
    }

    function testCustomInlineAndBlockCopyProjectWithTheText() {
        for (format in [SelectionFormat.Plain, SelectionFormat.Source]) {
            initApp();
            final extensions = new MarkdownExtensions()
                .plugin(new TextTestInlinePlugin("math").parseWith((node, _) -> switch node {
                    case InlineMath(math): new MarkdownNode("math", null).text('${math.value}²');
                    case _: null;
                }))
                .blockParser((node, _) -> node.match(ThematicBreak(_)) ? new MarkdownNode("block", null).text("BLOCK").markdown("---") : null)
                .blockRenderer("block", (_, _, _) -> div().w(px(520.)).h(px(40.)));
            final result = addWindowView((_, cx) -> {
                final root = new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("before $x$ after\n\n---\n\nlast", cx)), 520.);
                root.format = format;
                root.extensions = extensions;
                return root;
            });
            drawn(result.cx);
            final state = result.view.read(app).textView;
            final points = endpoints(state);
            final expected = format == Plain ? "before x² after\nBLOCK\nlast\n" : "before $x$ after\n\n---\n\nlast";
            result.cx.update((window, cx) -> {
                rawPress(points[0], window, cx);
                rawExtend(points[2], window, cx);
                assertCopy(expected, window, cx);
                rawRelease(points[2], window, cx);
                return true;
            });
            draw(result.cx);
            result.cx.update((window, cx) -> {
                assertCopy(expected, window, cx);
                return true;
            });
        }
    }

    function testScrollingBeforePaintKeepsTheCompletedFrameCoordinates() {
        final markdown = [for (_ in 0...30) "alpha beta gamma delta epsilon zeta "].join('') + "\n\nlast";
        final result = copyDocument(markdown, Plain, true);
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.width = 180.;
            cx.notify();
        }));
        draw(result.cx);
        final state = result.view.read(app).textView;
        final rows = state.read(app).selectionAdapter.textBounds();
        final first = rows[0];
        final start = state.read(app).selectionAdapter.firstTextPosition(0);
        final end = state.read(app).selectionAdapter.firstTextPosition(5);
        result.cx.update((window, cx) -> {
            rawPress(start, window, cx);
            rawExtend(end, window, cx);
            return true;
        });
        draw(result.cx);
        result.cx.update((window, cx) -> {
            state.read(cx).listState.scrollBy(first.size.height);
            // The logical offset changed, registration and native pixels have
            // not. This must not select the next wrapped row.
            assertCopy("alpha\n", window, cx);
            return true;
        });
    }

    function testOffscreenRemeasurementIsNotACopyProjection() {
        final markdown = [for (ix in 0...180) 'row ${StringTools.lpad(Std.string(ix), "0", 3)} café 中文'].join("\n\n");
        final result = copyDocument(markdown, Plain, true);
        final state = result.view.read(app).textView;
        function scrollTo(ix:Int) {
            state.read(app).listState.scrollTo(new glaze.ListOffset(ix, 0.));
            draw(result.cx);
        }
        scrollTo(90);
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.width = 260.;
            cx.notify();
        }));
        draw(result.cx);
        scrollTo(90);
        // Only this completed paint supplies Copy geometry.
        final points = endpoints(state);
        result.cx.update((window, cx) -> {
            rawPress(points[0], window, cx);
            rawExtend(points[1], window, cx);
            assertCopy("row 090 café 中文\n", window, cx);
            return true;
        });
    }

    function testVirtualizedFlowRetainsItsSourceOwnedPartialAnchor() {
        for (format in [SelectionFormat.Plain, SelectionFormat.Source]) {
            final tail = [for (ix in 1...180) 'row ${StringTools.lpad(Std.string(ix), "0", 3)} café 中文'];
            final markdown = 'PREFIX `code` suffix\n\n${tail.join("\n\n")}';
            final expected = format == Plain ? 'code suffix\n${tail.join("\n")}\n' : '`code` suffix\n\n${tail.join("\n\n")}';
            final result = copyDocument(markdown, format, true);
            final state = result.view.read(app).textView;
            final rows = state.read(app).selectionAdapter.textBounds();
            final code = rows[1];
            final suffix = rows[2];
            assertTrue(code.left() < suffix.left());
            result.cx.update((window, cx) -> {
                rawPress(new Point(code.left() + 0.1, code.center().y), window, cx);
                rawExtend(new Point(suffix.right() - 0.1, suffix.center().y), window, cx);
                return true;
            });
            draw(result.cx);
            state.read(app).listState.scrollTo(new glaze.ListOffset(179, 0.));
            draw(result.cx);
            // Two completed frames let GPUI retire temporary flow fragments.
            draw(result.cx);
            final points = endpoints(state);
            result.cx.update((window, cx) -> {
                rawExtend(points[2], window, cx);
                assertCopy(expected, window, cx);
                return true;
            });
        }
    }

    function testOuterListContentTotalStableWhileScrolling() {
        final items = [
            "# Heading\n\nA paragraph long enough to wrap across several lines and produce a non-trivial height.",
            "Short.",
            "Paragraph A\n\nParagraph B\n\nParagraph C with more words to increase the height.",
            "## Subheading\n\n- One\n- Two\n- Three\n\nClosing paragraph.",
            "Only one line.",
            "**Bold**: medium length text with `code` mixed with regular words.",
            "1. First\n2. Second\n3. Third\n\nA short closing paragraph.",
            "A long message with enough words to wrap across multiple lines, create a taller item, and verify that off-screen measurement matches visible measurement.",
        ];
        final n = 40;
        initApp();
        final state = new ListState(n, ListAlignment.Top, 2048.).measureAll();
        final result = addWindowView((_, _) -> new PlainRoot(() -> div().w(px(360.)).h(px(500.)).child(
            list(state, (ix, _, _) -> div().wFull().child(TextView.markdown(glaze.ElementId.NamedInteger("md", ix), items[ix % items.length]))).sizeFull()
        )));
        final cx = result.cx;
        cx.runUntilParked();
        draw(cx);
        cx.runUntilParked();
        draw(cx);
        function total():Float return state.maxOffsetForScrollbar().y + state.viewportBounds().size.height;
        final totals = [total()];
        for (_ in 0...20) {
            state.scrollBy(150.);
            draw(cx);
            cx.runUntilParked();
            totals.push(total());
        }
        var min = Math.POSITIVE_INFINITY;
        var max = Math.NEGATIVE_INFINITY;
        for (t in totals) {
            if (t < min) min = t;
            if (t > max) max = t;
        }
        assertTrue(max - min < 2.0, 'list content total jittered while scrolling: min=$min max=$max');
    }


    // More links, plugins and tables

    function testInlinePluginReusesRenderAndPreservesNativeChildEvents() {
        initApp();
        final clicks:Array<String> = [];
        var state:Entity<TextViewState> = null;
        final plugin = new TextTestInlinePlugin("control").parseWith((node, _) -> {
            return switch node {
                case Link(link) if (StringTools.startsWith(link.url, "control:")):
                    new MarkdownNode("control", null).text(link.url.substr("control:".length));
                case _: null;
            }
        }).renderWith((node, _, _, _) -> {
            final label = node.asText();
            return new InlineElement(div()
                .id("same-control-id")
                .w(px(60.))
                .h(px(24.))
                .onMouseDown(Left, (_, _, cx) -> cx.stopPropagation())
                .onClick((_, _, _) -> clicks.push(label))
                .child(label));
        });
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown("[one](control:one)[two](control:two)", cx));
            final s = state;
            return new PlainRoot(() -> div().w(px(300.)).child(new TextSelectionLayer()).child(TextView.create(s).markdownPlugin(plugin)));
        });
        final cx = result.cx;
        drawn(cx);
        final bounds = state.read(app).selectionAdapter.textBounds();
        assertEquals(2, bounds.length);
        for (b in bounds) {
            cx.simulateClick(b.center());
            draw(cx);
        }
        assertEquals("one,two", clicks.join(','));
    }

    function testInlineHoverCardIsLazyAndRetainsAtomicCopy() {
        initApp();
        var builds = 0;
        final source = "[@member](mention:member)";
        var format:SelectionFormat = Plain;
        var state:Entity<TextViewState> = null;
        final recorder = new DebugBoundsRecorder();
        final plugin = new TextTestInlinePlugin("mention").parseWith((node, _) -> {
            return switch node {
                case Link(link) if (StringTools.startsWith(link.url, "mention:")):
                    new MarkdownNode("mention", null).text('@' + link.url.substr("mention:".length));
                case _: null;
            }
        }).renderWith((_, _, _, _) -> {
            return new InlineElement(new glaze.kit.base.HoverCard("mention-hover")
                .anchor(TopCenter)
                .trigger(div().child("@member"))
                .content((_, _, cx) -> {
                    builds++;
                    return div()
                        .id("hover-content")
                        .child(cx.newEntity(_ -> new InlineHoverCard(recorder)));
                }));
        });
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown(source, cx));
            final s = state;
            return new PlainRoot(() -> div()
                .pl(px(150.))
                .w(px(300.))
                .textSize(px(16.))
                .child(new TextSelectionLayer())
                .child(TextView.create(s).selectionFormat(format).markdownPlugin(plugin)));
        });
        final cx = result.cx;
        drawn(cx);
        assertEquals(0, builds);
        final bounds = state.read(app).selectionAdapter.textBounds()[0];
        cx.simulateMouseMove(new Point(bounds.right() - 1., bounds.center().y));
        cx.runUntilParked();
        cx.advanceClock(1.);
        cx.runUntilParked();
        draw(cx);
        assertTrue(builds > 0, "hover did not build the card");
        draw(cx);
        final card = recorder.bounds(cx.window, "inline-test-card");
        assertTrue(card != null, "hover card should be painted");
        assertTrue(Math.abs(card.center().x - bounds.center().x) < 1., 'card $card must be centered on mention $bounds');
        assertTrue(card.top() >= bounds.bottom(), "card should be below the mention");
        for (entry in [{format: SelectionFormat.Plain, expected: "@member"}, {format: SelectionFormat.Source, expected: source}]) {
            format = entry.format;
            result.view.update(app, (_, cx) -> cx.notify());
            state.update(app, (view, cx) -> {
                view.setSelectionFormat(entry.format, cx);
                view.selectAll(cx);
            });
            draw(cx);
            assertEquals(entry.expected, StringTools.trim(state.read(app).selectedText()));
        }
    }

    function testMarkdownDataUrlImageIsDecodedInline() {
        // A 1x1 red PNG.
        final pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==";

        initApp();
        final markdown = 'Inline ![dot](data:image/png;base64,$pngBase64) image';
        final result = addWindowView((_, cx) -> new TextViewTestRoot(markdown, cx));
        final cx = result.cx;

        drawn(cx);

        // `Image` keys the asset system by a hash of its bytes, so rebuilding it
        // from the same body finds the entry the text view's `img` registered
        // when it rendered: proof the body was decoded in place instead of
        // being fetched over HTTP.
        final bytes = glaze.kit.base.text.DataUrl.process('data:image/png;base64,$pngBase64').decodeToVec().body;
        final image = glaze.Image.fromBytes(ImageFormat.Png, bytes);
        assertTrue(glaze.ImageSource.ImageSourceTools.isAssetCached(glaze.ImageSource.Image(image), app),
            "the data URL image must be handed to GPUI as decoded bytes");
    }

    function testListItemRendersFencedCodeBlockAtDocumentWidth() {
        initApp();
        final recorder = new DebugBoundsRecorder();
        final result = addWindowView((_, _) -> new PlainRoot(() -> div().w(px(840.)).h(px(400.)).child(
            glaze.kit.base.resizable.Resizable.hResizable("markdown-width-test")
                .child(glaze.kit.base.resizable.Resizable.resizablePanel().child(div()))
                .child(glaze.kit.base.resizable.Resizable.resizablePanel().child(
                    TextView.markdown(
                        "list-with-code",
                        "1. List item\n   ```rust\n   nested code\n   ```\n\n```rust\ntop-level code\n```"
                    )
                    .codeBlockActions((codeBlock, _, _) -> {
                        final selector = codeBlock.code().indexOf("nested") >= 0 ? "nested-code-action" : "top-level-code-action";
                        return recorder.wrap(selector, div().child("Copy"));
                    })
                    .scrollable(true)
                    .p5()
                    .flexNone()
                ))
        )));
        final cx = result.cx;

        cx.runUntilParked();
        draw(cx);

        final nestedAction = recorder.bounds(cx.window, "nested-code-action");
        final topLevelAction = recorder.bounds(cx.window, "top-level-code-action");
        assertTrue(nestedAction != null && topLevelAction != null);
        assertTrue(topLevelAction.right() - nestedAction.right() < 32.,
            "nested code block should fill the list item's available width");
    }

    function testInlineObjectInheritsBoldAndLinkClicksWithoutOpeningOnDrag() {
        initApp();
        final clicks:Array<String> = [];
        var sawBold = true;
        final extensions = new MarkdownExtensions().plugin(new TextTestInlinePlugin("math")
            .parseWith((node, _) -> node.match(InlineMath(_)) ? new MarkdownNode("math", null).text("formula") : null)
            .renderWith((_, context, _, _) -> {
                if (context.textStyle().fontWeight != glaze.FontWeight.BOLD) sawBold = false;
                return new InlineElement(div().child("formula"));
            }));
        final result = addWindowView((_, cx) -> {
            final root = new LayerRoot(cx.newEntity(cx -> TextViewState.markdown("**[$x$](https://example.com)**", cx)), 300.);
            root.extensions = extensions;
            return root;
        });
        app.update(app -> result.view.update(app, (root, _) -> root.linkClicks = []));
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final bounds = state.read(app).selectionAdapter.textBounds()[0];
        for (button in [MouseButton.Left, MouseButton.Middle, MouseButton.Right]) {
            cx.simulateMouseDown(bounds.center(), button);
            cx.simulateMouseUp(bounds.center(), button);
        }
        assertTrue(sawBold);
        final recorded = result.view.read(app).linkClicks;
        assertEquals(3, recorded.length);
        final start = new Point(bounds.left() + 1., bounds.center().y);
        final end = new Point(bounds.right() - 1., bounds.center().y);
        cx.simulateMouseDown(start, Left);
        draw(cx);
        cx.simulateMouseMove(end, Left);
        draw(cx);
        cx.simulateMouseUp(end, Left);
        assertEquals(3, recorded.length);
    }

    function testLinkedImageHandlerReceivesLeftMiddleAndRightClicks() {
        final opened = captureOpenedUrls();
        initApp();
        final clicks:Array<{url:String, event:ClickEvent}> = [];
        var state:Entity<TextViewState> = null;
        final result = addWindowView((_, cx) -> {
            state = cx.newEntity(cx -> TextViewState.markdown('Before [<img src="https://example.com/image.svg" width="32" height="32">](https://example.com/image-link) after.', cx));
            final s = state;
            return new PlainRoot(() -> div().w(px(160.)).child(TextView.create(s).selectable(true).onLinkClick((url, event, _, _) -> clicks.push({url: url, event: event}))));
        });
        final cx = result.cx;
        drawn(cx);
        final inlineBounds = state.read(app).selectionAdapter.textBounds();
        assertTrue(inlineBounds.length >= 2, 'linked image needs text bounds on both sides');
        assertTrue(inlineBounds[1].left() - inlineBounds[0].right() >= 24., 'linked image did not reserve the expected click target');
        final position = new Point(inlineBounds[0].right() + (inlineBounds[1].left() - inlineBounds[0].right()) * 0.5, inlineBounds[0].top() + 8.);
        for (button in [MouseButton.Left, MouseButton.Middle, MouseButton.Right]) {
            cx.simulateMouseDown(position, button);
            cx.simulateMouseUp(position, button);
        }
        assertEquals(3, clicks.length);
        for (click in clicks) assertEquals("https://example.com/image-link", click.url);
        assertTrue(!glaze.ClickEvent.ClickEventTools.isRightClick(clicks[0].event) && !glaze.ClickEvent.ClickEventTools.isMiddleClick(clicks[0].event));
        assertTrue(glaze.ClickEvent.ClickEventTools.isMiddleClick(clicks[1].event));
        assertTrue(glaze.ClickEvent.ClickEventTools.isRightClick(clicks[2].event));
        assertEquals(0, opened.length);
    }

    function testTableActionsRenderBelowTheTable() {
        for (scroll in [false, true]) {
            initApp();
            final captured:Array<glaze.kit.base.text.TableData> = [];
            var actionBounds:Null<Bounds> = null;
            final tableStyle = new StyleRefinement();
            if (scroll) tableStyle.overflowX = Scroll;
            final result = addWindowView((_, _) -> new PlainRoot(() -> div().w(px(320.)).child(
                TextView.markdown("table-actions", "| Name | Age |\n|:--|--:|\n| Alice | 30 |\n| Bob | 41 |")
                    .withStyle(TextViewStyle.defaultValue().withTable(tableStyle))
                    .tableActions((table, _, _) -> {
                        captured.push(table);
                        // Rust reads the action's debug bounds.
                        return glaze.kit.base.ElementExt.onPrepaint(div(), (bounds, _, _) -> actionBounds = bounds).child("Copy");
                    })
            )));
            drawn(result.cx);
            assertTrue(actionBounds != null, 'table actions should be painted');
            assertTrue(actionBounds.top() > 40., 'actions should sit below the table (scroll: $scroll), got ${actionBounds.top()}');
            final data = captured[captured.length - 1];
            assertEquals("Name,Age", data.headers.join(','));
            assertEquals("Alice,30|Bob,41", [for (row in data.rows) row.join(',')].join('|'));
            assertEquals("| Name | Age |\n| :-- | --: |\n| Alice | 30 |\n| Bob | 41 |", data.markdown);
            assertTrue(data.span != null && data.span.start == 0 && data.span.end == 52);
        }
    }

    function testHeadingRefinementChangesRenderedHeadingGeometry() {
        initApp();
        final boxes = new Map<String, Bounds>();
        function probe(name:String, view:TextView):IntoElement {
            // Rust reads the wrappers' debug bounds.
            return glaze.kit.base.ElementExt.onPrepaint(div(), (bounds, _, _) -> boxes.set(name, bounds)).child(view);
        }
        function custom():TextViewStyle {
            return TextViewStyle.defaultValue().withHeading(level -> {
                final refinement = new StyleRefinement();
                if (level == 1) refinement.paddingBottom = glaze.DefiniteLength.Absolute(glaze.AbsoluteLength.Rems(2.));
                return refinement;
            });
        }
        final result = addWindowView((_, _) -> new PlainRoot(() -> div()
            .flex()
            .itemsStart()
            .child(probe("default-h1", TextView.markdown("default-h1-view", "# Heading")))
            .child(probe("custom-h1", TextView.markdown("custom-heading-view", "# Heading").withStyle(custom())))
            .child(probe("default-h2", TextView.markdown("default-h2-view", "## Heading")))
            .child(probe("custom-h2", TextView.markdown("custom-h2-view", "## Heading").withStyle(custom())))
        ));
        draw(result.cx);
        assertTrue(boxes.get("custom-h1").size.height > boxes.get("default-h1").size.height);
        assertEquals(boxes.get("default-h2").size.height, boxes.get("custom-h2").size.height);
    }


    function testUnicode180ParagraphCopyExtendsAndRetractsBeforePaint() {
        final markdown = [for (ix in 0...180) 'p${StringTools.lpad(Std.string(ix), "0", 3)} **café** 中文 👩‍💻 `\u{2009}code\u{2009}`'].join("\n\n");
        // Expected bytes are constructed independently of renderedText(),
        // selectedText(), and the document's selection serializer.
        final expected = [for (ix in 0...180) 'p${StringTools.lpad(Std.string(ix), "0", 3)} café 中文 👩‍💻 \u{2009}code\u{2009}\n'].join('');
        initApp();
        // Rust resizes the window to 800 x 12000 (`simulate_resize`).
        final result = VisualTestContext.addWindowView(app, dispatcher, (_, cx) -> {
            final root = new LayerRoot(cx.newEntity(cx -> TextViewState.markdown(markdown, cx)), 520.);
            return root;
        }, 800., 12000.);
        contexts.push(result.cx);
        final cx = result.cx;
        drawn(cx);
        final state = result.view.read(app).textView;
        final rows = state.read(app).selectionAdapter.textBounds();
        final first = rows[0];
        var firstEnd = first;
        for (row in rows) {
            if (row.top() < first.bottom()) firstEnd = row else break;
        }
        final last = rows[rows.length - 1];
        assertTrue(last.top() > first.top() + 3000.);
        final start = new Point(first.left() + 0.1, first.center().y);
        final shortEnd = new Point(firstEnd.right() - 0.1, firstEnd.center().y);
        final end = new Point(last.right() - 0.1, last.center().y);
        final short = "p000 café 中文 👩‍💻 \u{2009}code\u{2009}\n";
        cx.update((window, cx) -> {
            rawPress(start, window, cx);
            rawExtend(shortEnd, window, cx);
            assertCopy(short, window, cx);
            return true;
        });
        draw(cx);
        cx.update((window, cx) -> {
            rawExtend(end, window, cx);
            assertCopy(expected, window, cx);
            rawExtend(shortEnd, window, cx);
            assertCopy(short, window, cx);
            return true;
        });
    }

    function testScrollingCodeBlockKeepsWheelFromTheList() {
        final codeHeight = 60.;
        final code = [for (i in 0...50) 'line $i\n'].join('');
        final tail = [for (_ in 0...20) "Paragraph after the code.\n\n"].join('');
        final markdown = '```\n${code}```\n\n$tail';

        // Scrolling must not depend on `codeBlockActions`, which is what gives
        // a non-scrolling block its id.
        for (actions in [false, true]) {
            initApp();
            var state:Entity<TextViewState> = null;
            var action:Null<Bounds> = null;
            final result = addWindowView((_, cx) -> {
                state = cx.newEntity(cx -> TextViewState.markdown(markdown, cx));
                final s = state;
                return new PlainRoot(() -> {
                    final codeBlock = new StyleRefinement();
                    codeBlock.maxSizeHeight = glaze.Length.Definite(glaze.DefiniteLength.Absolute(glaze.AbsoluteLength.Pixels(codeHeight)));
                    codeBlock.overflowY = Scroll;
                    var view = TextView.create(s).withStyle(TextViewStyle.defaultValue().withCodeBlock(codeBlock)).scrollable(true);
                    if (actions) {
                        // Rust reads the action's debug bounds.
                        view = view.codeBlockActions((_, _, _) -> glaze.kit.base.ElementExt.onPrepaint(div(), (bounds, _, _) -> action = bounds).child("Copy"));
                    }
                    return div().w(px(320.)).h(px(200.)).child(view);
                });
            });
            final cx = result.cx;
            final step = 20.;
            function wheelAt(y:Float) {
                cx.simulateEvent(new glaze.ScrollEvent(new Point(20., y), glaze.ScrollDelta.Pixels(new Point(0., -step))));
            }
            // The code block is first in the view, and painted lines are
            // clipped to its viewport.
            function edges():Array<Float> {
                final lines = state.read(app).selectionAdapter.textBounds();
                var paragraph:Null<Bounds> = null;
                for (line in lines) {
                    if (line.top() >= codeHeight) {
                        paragraph = line;
                        break;
                    }
                }
                return [lines[0].bottom(), paragraph.top()];
            }
            drawn(cx);
            final before = edges();
            final actionBefore = action;

            // Over the code block: the code scrolls, the list and the pinned
            // actions stay put.
            wheelAt(codeHeight / 2.);
            drawn(cx);
            final over = edges();
            assertEquals(before[0] - step, over[0], 'actions: $actions');
            assertEquals(before[1], over[1], 'actions: $actions');
            assertTrue(actionBefore == null ? action == null : actionBefore.equals(action));

            // Below the code block the list still scrolls.
            wheelAt(codeHeight * 2.5);
            drawn(cx);
            assertTrue(edges()[1] != before[1], 'actions: $actions');
        }
    }

}

private class DummyTextViewPlugin implements glaze.kit.base.text.TextView.TextViewPlugin {
    public function new() {}

    public function setup(textView:TextView):TextView {
        return textView.selectable(true);
    }
}

/** Rust `InlineHoverCard`: the card content, `debug_selector("inline-test-card")`. */
private class InlineHoverCard extends Model implements Render {
    final recorder:DebugBoundsRecorder;

    public function new(recorder:DebugBoundsRecorder) {
        super();
        this.recorder = recorder;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return recorder.wrap("inline-test-card", div()
            .w(px(120.))
            .h(px(40.))
            .child("Member profile"));
    }
}

/**
 * Stands for GPUI's `debug_selector` / `VisualTestContext::debug_bounds` in
 * these tests: the port's `debugSelector` records nothing, so the elements a
 * test looks up are wrapped in an element that records its bounds in prepaint,
 * per window and draw.
 */
private class DebugBoundsRecorder {
    final recorded:Map<String, {window:Int, draw:Int, bounds:glaze.Bounds}> = new Map();

    public function new() {}

    public function wrap(selector:String, element:IntoElement):IntoElement {
        return new DebugBoundsElement(this, selector, element);
    }

    public function record(window:Window, selector:String, bounds:glaze.Bounds):Void {
        recorded.set(selector, {window: window.id, draw: window.drawCount, bounds: bounds});
    }

    /** The bounds `selector` was drawn at by the last frame of `window`. */
    public function bounds(window:Window, selector:String):Null<glaze.Bounds> {
        final entry = recorded.get(selector);
        return entry != null && entry.window == window.id && entry.draw == window.drawCount - 1 ? entry.bounds : null;
    }
}

private class DebugBoundsElement extends glaze.Element {
    final recorder:DebugBoundsRecorder;
    final selector:String;
    final child:glaze.AnyElement;

    public function new(recorder:DebugBoundsRecorder, selector:String, child:IntoElement) {
        this.recorder = recorder;
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public function requestLayout(id:Null<glaze.GlobalElementId>, window:Window, cx:App):glaze.LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<glaze.GlobalElementId>, bounds:glaze.Bounds, window:Window, cx:App):Void {
        recorder.record(window, selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<glaze.GlobalElementId>, bounds:glaze.Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }
}
