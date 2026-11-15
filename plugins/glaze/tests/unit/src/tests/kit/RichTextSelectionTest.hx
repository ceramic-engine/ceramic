// New tests for the Haxe port of gpui-kit (no gpui-kit origin): text selection in a standalone `RichText`
// (`RichText.selectable`), which goes through the selection code of the markdown view. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.Point;
import glaze.Render;
import glaze.Transformation;
import glaze.Window;
import glaze.kit.base.TextSelection;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.input.InputActions.SelectAll;
import glaze.kit.text.RichText;
import glaze.kit.text.RichText.RichSpan;
import glaze.kit.text.RichText.RichTextStyle;
import glaze.kit.text.TextView;
import testing.VisualTestContext;

import glaze.Prelude.*;

/** A view rendering through a function that the test can change. */
private class RichSelectionView extends Model implements Render {

    public var renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

/**
 * `RichText.selectable(true)` outside of a `TextView`: drag, double click,
 * triple click, shift click, select all and copy, in a window whose root is
 * the kit's `Root`. The paragraph is at the left of the window, 10 pixels
 * under its top, as the text views of `TextWindowSelectionTest`.
 */
class RichTextSelectionTest extends KitTestCase {

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):{view:glaze.Entity<RichSelectionView>, cx:VisualTestContext} {
        app.update(cx -> {
            // The test fonts have no `Menlo` (the macOS monospace family of the theme).
            glaze.kit.base.theme.Theme.globalMut(cx).tokens.typography.mono = 'JetBrains Mono';
        });
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> rootCx.newEntity((_:Context<RichSelectionView>) -> new RichSelectionView(render)));
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        draw(opened.cx);
        return {view: opened.view, cx: opened.cx};
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
    }

    static function drag(cx:VisualTestContext, from:Point, to:Point):Void {
        cx.simulateMouseDown(from, Left);
        draw(cx);
        cx.simulateMouseMove(to, Left);
        draw(cx);
        cx.simulateMouseUp(to, Left);
        draw(cx);
    }

    static function click(cx:VisualTestContext, position:Point, modifiers:Modifiers):Void {
        cx.simulateMouseDown(position, Left, modifiers);
        cx.simulateMouseUp(position, Left, modifiers);
        draw(cx);
    }

    static function multiClick(cx:VisualTestContext, position:Point, count:Int):Void {
        cx.simulateEvent(new glaze.MouseDownEvent(Left, position, Modifiers.none(), count, false));
        cx.simulateEvent(new glaze.MouseUpEvent(Left, position, Modifiers.none(), count));
        draw(cx);
    }

    static function selected(cx:VisualTestContext):String {
        return cx.update((window, cx) -> TextSelection.selectedText(window, cx));
    }

    static function twoLines(selectable:Bool):RichText {
        return RichText.component('rich')
            .spans([
                RichSpan.text('Hello '),
                RichSpan.text('world', new RichTextStyle().fontWeight(glaze.FontWeight.BOLD)),
                RichSpan.lineBreak(),
                RichSpan.text('Second line'),
            ])
            .selectable(selectable);
    }

    static function page(child:IntoElement):IntoElement {
        return div().sizeFull().pt(px(10.)).child(child);
    }

    /** The middle of the first and of the second line of `twoLines`. */
    static inline final FIRST:Float = 20.;

    function secondLineY(cx:VisualTestContext):Float {
        return cx.update((window, _) -> 10. + window.lineHeight() * 1.5);
    }

    function testADragSelectsAcrossSpansOfOneLine() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(FIRST)));
        assertEquals('Hello world', StringTools.trim(selected(cx)));
    }

    function testADragOverTwoLinesKeepsTheLineBreak() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(secondLineY(cx))));
        assertEquals('Hello world\nSecond line', StringTools.trim(selected(cx)));
    }

    function testNotSelectableByDefault() {
        final cx = open((_, _) -> page(twoLines(false))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(secondLineY(cx))));
        assertEquals('', selected(cx));
        multiClick(cx, point(px(10.), px(FIRST)), 2);
        assertEquals('', selected(cx));
    }

    function testADoubleClickSelectsAWord() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        multiClick(cx, point(px(10.), px(FIRST)), 2);
        assertEquals('Hello', StringTools.trim(selected(cx)));
    }

    function testATripleClickSelectsALine() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        multiClick(cx, point(px(10.), px(FIRST)), 3);
        assertEquals('Hello world', StringTools.trim(selected(cx)));
        multiClick(cx, point(px(10.), px(secondLineY(cx))), 3);
        assertEquals('Second line', StringTools.trim(selected(cx)));
    }

    function testAShiftClickExtendsFromTheLastClick() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        click(cx, point(px(0.), px(FIRST)), Modifiers.none());
        assertEquals('', selected(cx));
        click(cx, point(px(700.), px(FIRST)), Modifiers.none().withShift(true));
        assertEquals('Hello world', StringTools.trim(selected(cx)));
        click(cx, point(px(700.), px(secondLineY(cx))), Modifiers.none().withShift(true));
        assertEquals('Hello world\nSecond line', StringTools.trim(selected(cx)));
    }

    function testSelectAllAndCopyWhenFocused() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        // A selection that starts in the paragraph gives it the focus
        drag(cx, point(px(0.), px(FIRST)), point(px(30.), px(FIRST)));
        cx.update((window, cx) -> {
            cx.writeToClipboard(glaze.ClipboardItem.newString('sentinel'));
            final focus = window.focused(cx);
            assertTrue(focus != null, 'the selection gives the paragraph the focus');
            focus.dispatchAction(new Copy(), window, cx);
            final part = cx.readFromClipboard().text();
            assertTrue(part.length > 0 && part != 'sentinel' && StringTools.startsWith('Hello world', part), 'the dragged part is copied: "$part"');
            focus.dispatchAction(new SelectAll(), window, cx);
            return true;
        });
        draw(cx);
        assertEquals('Hello world\nSecond line', selected(cx));
        cx.update((window, cx) -> {
            window.focused(cx).dispatchAction(new Copy(), window, cx);
            assertEquals('Hello world\nSecond line', cx.readFromClipboard().text());
            return true;
        });
    }

    function testAPlainClickClearsTheSelection() {
        final cx = open((_, _) -> page(twoLines(true))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(FIRST)));
        assertTrue(selected(cx) != '');
        cx.simulateClick(point(px(700.), px(300.)), Modifiers.none());
        draw(cx);
        assertEquals('', selected(cx));
    }

    function testCollapsedWhiteSpaceAndCaseAreCopiedAsShown() {
        final cx = open((_, _) -> page(RichText.component('rich')
            .spans([
                RichSpan.text('  Several   spaces\n and '),
                RichSpan.text('shouting', new RichTextStyle().textTransform(Uppercase)),
            ])
            .selectable(true))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(FIRST)));
        assertEquals('Several spaces and SHOUTING', StringTools.trim(selected(cx)));
    }

    static function withTransformedSpan():IntoElement {
        return page(RichText.component('rich')
            .spans([
                RichSpan.text('Moving', new RichTextStyle().transformation(Transformation.scaled(size(1.2, 1.2)))),
                RichSpan.text(' tail text'),
            ])
            .selectable(true));
    }

    function testNoWordSelectionStartsInATransformedSpan() {
        final cx = open((_, _) -> withTransformedSpan()).cx;
        multiClick(cx, point(px(10.), px(FIRST)), 2);
        assertEquals('', selected(cx));
    }

    function testADragOverATransformedSpanSelectsTheRest() {
        final cx = open((_, _) -> withTransformedSpan()).cx;
        // From the transformed span to the middle of the text after it
        drag(cx, point(px(2.), px(FIRST)), point(px(90.), px(FIRST)));
        final text = selected(cx);
        assertTrue(text.length > 0 && StringTools.startsWith(' tail text', text), 'a part of the text after the span, not the span: "$text"');
    }

    function testATransformedSpanBetweenSelectedTextIsCopiedWithIt() {
        final cx = open((_, _) -> page(RichText.component('rich')
            .spans([
                RichSpan.text('Before '),
                RichSpan.text('moving', new RichTextStyle().transformation(Transformation.scaled(size(1.2, 1.2)))),
                RichSpan.text(' after'),
            ])
            .selectable(true))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(FIRST)));
        assertEquals('Before moving after', StringTools.trim(selected(cx)));
    }

    function testATextChangeDropsTheSelection() {
        final opened = open((_, _) -> page(twoLines(true)));
        final cx = opened.cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(FIRST)));
        assertEquals('Hello world', StringTools.trim(selected(cx)));
        // The same text rendered again keeps it
        opened.view.update(app, (_, cx) -> cx.notify());
        draw(cx);
        assertEquals('Hello world', StringTools.trim(selected(cx)));
        // Another text does not
        opened.view.update(app, (view, cx) -> {
            view.renderFn = (_, _) -> page(RichText.component('rich').spans([RichSpan.text('Other words here')]).selectable(true));
            cx.notify();
        });
        draw(cx);
        draw(cx);
        assertEquals('', selected(cx));
        // And the new text can be selected
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(FIRST)));
        assertEquals('Other words here', StringTools.trim(selected(cx)));
    }

    function testASelectionRunsFromARichTextIntoATextView() {
        final cx = open((_, _) -> div().sizeFull().pt(px(10.))
            .child(div().h(px(60.)).child(twoLines(true)))
            .child(div().h(px(40.)).child(TextView.markdown('md', 'Markdown **below**').selectable(true)))).cx;
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(85.)));
        final text = selected(cx);
        assertTrue(text.indexOf('Hello world\nSecond line') != -1, 'the rich text is in the selection: $text');
        assertTrue(text.indexOf('Markdown below') != -1, 'the text view is in the selection: $text');
    }

    function testALinkOfASelectableRichTextIsStillClickable() {
        final clicked:Array<String> = [];
        final cx = open((_, _) -> page(RichText.component('rich')
            .spans([
                RichSpan.text('Open the documentation', new RichTextStyle().link('https://example.org/docs')),
                RichSpan.text(' and plain text'),
            ])
            .selectable(true)
            .onLinkClick((url, _, _) -> clicked.push(url)))).cx;
        cx.simulateMouseMove(point(px(30.), px(FIRST)));
        cx.simulateClick(point(px(30.), px(FIRST)));
        draw(cx);
        assertEquals('https://example.org/docs', clicked.join(','));
    }

    function testTwoSelectableRichTextsKeepTheirOwnText() {
        final cx = open((_, _) -> div().sizeFull().pt(px(10.))
            .child(div().h(px(40.)).child(RichText.component('a').spans([RichSpan.text('First paragraph')]).selectable(true)))
            .child(div().h(px(40.)).child(RichText.component('b').spans([RichSpan.text('Second paragraph')]).selectable(true)))).cx;
        multiClick(cx, point(px(10.), px(FIRST)), 3);
        assertEquals('First paragraph', StringTools.trim(selected(cx)));
        multiClick(cx, point(px(10.), px(60.)), 3);
        assertEquals('Second paragraph', StringTools.trim(selected(cx)));
        drag(cx, point(px(0.), px(FIRST)), point(px(700.), px(60.)));
        final text = selected(cx);
        assertTrue(text.indexOf('First paragraph') != -1 && text.indexOf('Second paragraph') != -1, 'both paragraphs: $text');
    }

}
