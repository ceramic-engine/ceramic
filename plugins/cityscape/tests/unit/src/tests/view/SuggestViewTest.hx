// New code for Cityscape (not a port): the suggest widget in a Glaze window
// (headless): its size and side against Monaco's SuggestWidget `_layout`
// (below the cursor when the list fits there inside the window less 22
// pixels, else above, the height capped to the room on that side, the list
// scrolling beyond), its box against the line (contentWidgets.ts
// `_layoutBoxInPage`), the place of its details
// (suggestWidgetDetails.ts `_placeAtAnchor`), and the scrollbar of the list
// (a 10 pixel square slider in `scrollbarSlider.background`, measured on the
// real Monaco 0.52.2).
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.suggest.view.SuggestController;
import cityscape.contrib.suggest.view.SuggestWidget;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

private class ItemsProvider implements CompletionItemProvider {
    public var _debugDisplayName(default, null):Null<String> = 'suggestview';
    public var triggerCharacters(default, null):Null<Array<String>> = [];
    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    final count:Int;
    final documentation:Null<String>;

    public function new(count:Int, documentation:Null<String>) {
        this.count = count;
        this.documentation = documentation;
    }

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        final suggestions:Array<CompletionItem> = [];
        for (i in 0...count) {
            final item:CompletionItem = {
                label: 'item' + (i < 10 ? '0' : '') + i,
                kind: cityscape.common.languages.CompletionItemKind.Variable,
                insertText: 'item' + i,
                range: Range.fromPositions(position)
            };
            if (documentation != null) {
                item.documentation = documentation;
            }
            suggestions.push(item);
        }
        resolve({suggestions: suggestions});
    }
}

class SuggestViewTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    function open(count:Int, width:Int, height:Int, ?documentation:String):CityscapeEditor {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'suggestview'});
        context.registerCompletionItemProvider('suggestview', new ItemsProvider(count, documentation));
        final model = context.modelService.createModel([for (i in 0...80) ''].join('\n'), 'suggestview', Uri.parse('file:///suggest.view'));
        var editor:Null<CityscapeEditor> = null;
        if (window != null) {
            window.destroy();
        }
        window = Window.open(app, {width: width, height: height, scaleFactor: 2, autoDraw: false, bindInput: false},
            tests.view.HoverViewTest.HoverEditorHost.component(context, model, null, e -> editor = e));
        draw();
        draw();
        return editor;
    }

    function suggestAt(editor:CityscapeEditor, lineNumber:Int):SuggestWidget {
        editor.getEditor().setPosition(new Position(lineNumber, 1));
        draw();
        final controller = SuggestController.get(editor.getEditor());
        controller.triggerSuggest();
        draw();
        draw();
        final widget = controller.widget;
        assertTrue(widget.isVisible());
        assertNotNull(widget.listBounds);
        return widget;
    }

    function lineBox(editor:CityscapeEditor, lineNumber:Int):Bounds {
        return EditorWidgets.positionBounds(editor.getEditor(), new Position(lineNumber, 1));
    }

    function near(expected:Float, actual:Float, ?label:String):Void {
        assertTrue(Math.abs(expected - actual) <= 1, (label != null ? label + ': ' : '') + 'expected ' + expected + ', got ' + actual);
    }

    function itemHeight(editor:CityscapeEditor):Float {
        return editor.getEditor().getOption(EditorOption.fontInfo).lineHeight;
    }

    /**
     * Near the top: below the line (its top on the line's bottom), 12 rows
     * high (Monaco's default size: 12 items and the border, plus the border
     * of the element, content-box), 430 pixels wide plus the border.
     */
    function testBelowNearTheTop() {
        final editor = open(30, 800, 600);
        final widget = suggestAt(editor, 2);
        final h = itemHeight(editor);
        assertEquals(ContentWidgetPositionPreference.BELOW, widget.preference);
        final b = widget.listBounds;
        final line = lineBox(editor, 2);
        near(line.origin.y + line.size.height, b.origin.y, 'top on the line bottom');
        near(line.origin.x, b.origin.x, 'left on the cursor');
        near(12 * h + 2 + 2, b.size.height, 'height');
        near(432, b.size.width, 'width');
        assertEquals(12, widget.visibleRowCount());
    }

    /**
     * Near the bottom of the window: not enough room below (the window's
     * height less the line's bottom less 22 pixels), above the line (its
     * bottom on the line's top), at its full height.
     */
    function testAboveNearTheBottom() {
        final editor = open(30, 800, 600);
        final h = itemHeight(editor);
        var lineNumber = 1;
        while (lineBox(editor, lineNumber + 1) != null && lineBox(editor, lineNumber + 1).origin.y + 2 * h < 600) {
            lineNumber++;
        }
        final line = lineBox(editor, lineNumber);
        assertTrue(600 - (line.origin.y + line.size.height) - 22 < 12 * h + 2, 'no room below');
        final widget = suggestAt(editor, lineNumber);
        assertEquals(ContentWidgetPositionPreference.ABOVE, widget.preference);
        final b = widget.listBounds;
        near(line.origin.y, b.origin.y + b.size.height, 'bottom on the line top');
        near(12 * h + 2 + 2, b.size.height, 'height');
        // inside the window
        assertTrue(b.origin.y >= 0);
    }

    /**
     * Few items: as high as them (the full height, `_cappedHeight` keeps
     * the wanted 12 rows for later), below the line.
     */
    function testFewItems() {
        final editor = open(3, 800, 600);
        final widget = suggestAt(editor, 10);
        final h = itemHeight(editor);
        assertEquals(ContentWidgetPositionPreference.BELOW, widget.preference);
        near(3 * h + 2 + 2, widget.listBounds.size.height, 'height');
    }

    /**
     * suggestWidget.ts `_layout` and `_resize` (no status bar, a border of 1),
     * from the height `size` (or the default size when null): the height
     * of the content box and the side. `capped` is `_cappedHeight`.
     */
    static function monacoLayout(size:Null<Float>, itemHeight:Float, count:Int, cursorTop:Float, cursorBottom:Float, bodyHeight:Float, capped:Null<Array<Float>>):{height:Float, above:Bool, capped:Null<Array<Float>>} {
        final borderHeight = 2;
        final verticalPadding = 22;
        if (size == null) {
            size = 12 * itemHeight + borderHeight;
        }
        var height = size;
        final fullHeight = count * itemHeight + borderHeight;
        final minHeight = itemHeight;
        final maxHeightBelow = Math.min(bodyHeight - cursorBottom - verticalPadding, fullHeight);
        final maxHeightAbove = Math.min(cursorTop - verticalPadding, fullHeight);
        var maxHeight = Math.min(Math.max(maxHeightAbove, maxHeightBelow) + borderHeight, fullHeight);
        if (capped != null && height == capped[1]) {
            height = capped[0];
        }
        if (height < minHeight) height = minHeight;
        if (height > maxHeight) height = maxHeight;
        final above = height > maxHeightBelow;
        maxHeight = above ? maxHeightAbove : maxHeightBelow;
        final nextCapped = height == fullHeight ? [capped != null ? capped[0] : size, height] : null;
        // _resize, then ResizableHTMLElement.layout
        height = Math.max(minHeight, Math.min(maxHeight, height));
        return {height: height, above: above, capped: nextCapped};
    }

    /**
     * A small window where the list fits neither below nor above: Monaco's
     * `_layout` caps the height to `max(above, below) + border` (at most the
     * full height), takes `ABOVE` when that height does not fit below and
     * caps it to the room above; then the layout after `showSuggestions`
     * (from that height) finds it fits below and takes `BELOW`. The list
     * scrolls.
     */
    function testCappedWhenNeitherFits() {
        final editor = open(30, 800, 220);
        final h = itemHeight(editor);
        final lineNumber = 5;
        final line = lineBox(editor, lineNumber);
        final editorBox = EditorWidgets.editorBounds(editor.getEditor());
        final widget = suggestAt(editor, lineNumber);
        final cursorBottom = line.origin.y + line.size.height;
        // `_show` (the persisted size: none), then `showSuggestions` (the current size)
        final first = monacoLayout(null, h, 30, line.origin.y, cursorBottom, 220, null);
        assertTrue(first.above, 'first pass above');
        final second = monacoLayout(first.height, h, 30, line.origin.y, cursorBottom, 220, first.capped);
        final height = second.height;
        final above = second.above;
        assertFalse(above, 'second pass below');
        assertTrue(height < 12 * h, 'capped ' + height);
        assertEquals(above ? ContentWidgetPositionPreference.ABOVE : ContentWidgetPositionPreference.BELOW, widget.preference);
        final b = widget.listBounds;
        near(height + 2, b.size.height, 'height');
        if (above) {
            near(line.origin.y, b.origin.y + b.size.height, 'bottom on the line top');
        }
        else {
            near(cursorBottom, b.origin.y, 'top on the line bottom');
        }
        assertTrue(editorBox != null);
        // the rows shown entirely, the moves of the focus reveal the others
        final rows = widget.visibleRowCount();
        assertEquals(Std.int(Math.max(1, Math.floor(height / h))), rows);
        assertTrue(rows < 12);
        widget.selectNextPage();
        draw();
        assertEquals(rows - 1, widget.getFocusedItem().index);
        assertEquals(0, widget.firstVisibleIndex);
        widget.selectNextPage();
        draw();
        assertEquals(2 * rows - 2, widget.getFocusedItem().index);
        assertEquals(rows - 1, widget.firstVisibleIndex);
        widget.scrollBy(1000);
        assertEquals(30 - rows, widget.firstVisibleIndex);
    }

    /**
     * A small window, the line in its lower part: above the line, capped to
     * the room above (its top at 22 pixels from the window's top).
     */
    function testCappedAbove() {
        final editor = open(30, 800, 220);
        final h = itemHeight(editor);
        var lineNumber = 1;
        while (lineBox(editor, lineNumber + 1) != null && lineBox(editor, lineNumber + 1).origin.y + 3 * h < 220) {
            lineNumber++;
        }
        final line = lineBox(editor, lineNumber);
        final widget = suggestAt(editor, lineNumber);
        final cursorBottom = line.origin.y + line.size.height;
        final first = monacoLayout(null, h, 30, line.origin.y, cursorBottom, 220, null);
        final second = monacoLayout(first.height, h, 30, line.origin.y, cursorBottom, 220, first.capped);
        assertTrue(second.above);
        assertEquals(ContentWidgetPositionPreference.ABOVE, widget.preference);
        final b = widget.listBounds;
        near(second.height + 2, b.size.height, 'height');
        near(line.origin.y - 22 + 2, b.size.height, 'the room above');
        near(line.origin.y, b.origin.y + b.size.height, 'bottom on the line top');
        assertTrue(widget.visibleRowCount() < 12);
    }

    /**
     * The message (no suggestions): half the default width, a row high,
     * below.
     */
    function testMessageBelow() {
        final editor = open(0, 800, 600);
        final widget = suggestAt(editor, 3);
        final h = itemHeight(editor);
        assertNotNull(widget.message);
        assertEquals(ContentWidgetPositionPreference.BELOW, widget.preference);
        near(h + 2 + 2, widget.listBounds.size.height, 'height');
        near(215 + 2, widget.listBounds.size.width, 'width');
    }

    function showDetails(widget:SuggestWidget):Void {
        if (!widget._isDetailsVisible()) {
            widget.toggleDetails();
        }
        draw();
        draw();
        assertNotNull(widget.detailsBounds);
    }

    /**
     * The details east of the list (overlapping its border), their top on
     * the list's top when the list is below the line.
     */
    function testDetailsBelow() {
        final editor = open(30, 1000, 600, 'Short documentation.');
        final widget = suggestAt(editor, 2);
        showDetails(widget);
        final list = widget.listBounds;
        final details = widget.detailsBounds;
        near(list.origin.x + list.size.width - 1, details.origin.x, 'east');
        near(list.origin.y, details.origin.y, 'top on the list top');
        near(330 + 2, details.size.width, 'width');
    }

    /**
     * The list above the line: details lower than the list stay at its top,
     * higher ones end on its bottom.
     */
    function testDetailsAbove() {
        final paragraphs = [for (i in 0...12) 'Paragraph ' + i + ' ' + [for (j in 0...20) 'word'].join(' ')].join('\n\n');
        for (documentation in ['Short documentation.', paragraphs]) {
            final count = documentation == paragraphs ? 2 : 30;
            final editor = open(count, 1000, 600, documentation);
            final h = itemHeight(editor);
            var lineNumber = 1;
            while (lineBox(editor, lineNumber + 1) != null && lineBox(editor, lineNumber + 1).origin.y + 2 * h < 600) {
                lineNumber++;
            }
            final widget = suggestAt(editor, lineNumber);
            assertEquals(ContentWidgetPositionPreference.ABOVE, widget.preference);
            showDetails(widget);
            final list = widget.listBounds;
            final details = widget.detailsBounds;
            if (documentation == paragraphs) {
                assertTrue(details.size.height > list.size.height, 'higher ' + details.size.height);
                near(list.origin.y + list.size.height, details.origin.y + details.size.height, 'bottom on the list bottom');
                // capped to the room above the list's bottom (less the border and 22 pixels)
                assertTrue(details.origin.y >= 22 - 1, 'inside the window ' + details.origin.y);
            }
            else {
                assertTrue(details.size.height < list.size.height);
                near(list.origin.y, details.origin.y, 'top on the list top');
            }
        }
    }

    static function sameColor(q:glaze.scene.Quad, c:glaze.Hsla):Bool {
        return Math.abs(q.backgroundSolidH - c.h) < 0.0001 && Math.abs(q.backgroundSolidS - c.s) < 0.0001
            && Math.abs(q.backgroundSolidL - c.l) < 0.0001 && Math.abs(q.backgroundSolidA - c.a) < 0.0001;
    }

    /**
     * A list longer than its rows has Monaco's widget scrollbar: a slider
     * 10 pixels wide against the right of the list inside its border, in
     * `scrollbarSlider.background`, square, as long as the share of the
     * rows shown (20 pixels at least), at the bottom when the list is
     * scrolled to its end; no scrollbar when every row shows.
     */
    function testListScrollbar() {
        glaze.kit.theme.Theme.setScrollbarMode(glaze.kit.base.theme.ScrollbarMode.Always, app);
        final editor = open(40, 800, 600);
        final widget = suggestAt(editor, 2);
        draw();
        final slider = EditorWidgets.color(editor.getEditor(), 'scrollbarSlider.background', glaze.Prelude.hsla(0, 0, 0, 1));
        final b = widget.listBounds;
        final h = widget.getLayoutInfo().itemHeight;
        final listHeight = widget.getSize().height - widget.getLayoutInfo().statusBarHeight;
        function sliders():Array<glaze.scene.Quad> {
            return [for (q in window.renderedScene().quads) if (sameColor(q, slider)) q];
        }
        var found = sliders();
        assertEquals(1, found.length, 'one slider');
        var q = found[0];
        near((b.origin.x + b.size.width - 1 - 10) * 2, q.boundsX, 'slider left');
        near(20, q.boundsWidth, 'slider width');
        near((b.origin.y + 1) * 2, q.boundsY, 'slider top');
        // the visible share: 12 rows of the list plus the 28 it scrolls by
        near(Math.max(20, listHeight * listHeight / (listHeight + 28 * h)) * 2, q.boundsHeight, 'slider length');
        assertEquals(0.0, q.cornerRadiusTopLeft);
        widget.scrollToRow(1000);
        assertEquals(28, widget.firstVisibleIndex);
        draw();
        draw();
        found = sliders();
        assertEquals(1, found.length);
        q = found[0];
        near((b.origin.y + 1 + listHeight) * 2, q.boundsY + q.boundsHeight, 'slider at the bottom');
        // every row shown: no scrollbar
        final short = open(5, 800, 600);
        suggestAt(short, 2);
        draw();
        assertEquals(0, sliders().length);
    }

}
