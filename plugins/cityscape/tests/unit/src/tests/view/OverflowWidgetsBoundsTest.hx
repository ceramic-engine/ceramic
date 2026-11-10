// New code for Cityscape (not a port): the Cityscape option
// `overflowWidgetsBounds` (DEVIATIONS.md, "Options added by Cityscape"). With
// 'window' (the default, Monaco's) the widgets anchored in the text choose
// their side and their height in the window and may leave the editor; with
// 'editor' the editor's bounds stand for the window and nothing extends
// outside them. The editor of these tests takes the top 300 pixels of a 800 x
// 600 window.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.codeAction.view.CodeActionMenu;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.contrib.suggest.view.SuggestController;
import cityscape.contrib.suggest.view.SuggestWidget;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.Point;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

private class ManyItems implements CompletionItemProvider {
    public var _debugDisplayName(default, null):Null<String> = 'overflow';
    public var triggerCharacters(default, null):Null<Array<String>> = [];
    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        final documentation = [for (i in 0...12) 'Paragraph ' + i + ' ' + [for (j in 0...20) 'word'].join(' ')].join('\n\n');
        resolve({suggestions: [for (i in 0...30) ({
            label: 'item' + (i < 10 ? '0' : '') + i,
            kind: cityscape.common.languages.CompletionItemKind.Variable,
            insertText: 'item' + i,
            documentation: documentation,
            range: Range.fromPositions(position)
        } : CompletionItem)]});
    }
}

private class LongHover implements HoverProvider {

    public function new() {}

    public function provideHover(model:ITextModel, position:Position, token:CancellationToken, context:Null<HoverContext>, resolve:(hover:Null<Hover>) -> Void):Void {
        final paragraphs = [for (i in 0...30) 'Paragraph ' + i + ' ' + [for (j in 0...40) 'word'].join(' ')];
        resolve({contents: [{value: paragraphs.join('\n\n')}], range: new Range(position.lineNumber, 1, position.lineNumber, 5)});
    }

}

class OverflowWidgetsBoundsTest extends TestCase {

    static inline final EDITOR_HEIGHT = 300;

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

    function open(?options:Dynamic):CityscapeEditor {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'overflow'});
        context.registerCompletionItemProvider('overflow', new ManyItems());
        context.registerHoverProvider('overflow', new LongHover());
        final model = context.modelService.createModel([for (i in 0...80) 'line ' + (i + 1)].join('\n'), 'overflow', Uri.parse('file:///overflow.test'));
        var editor:Null<CityscapeEditor> = null;
        if (window != null) {
            window.destroy();
        }
        window = Window.open(app, {width: 800, height: 600, scaleFactor: 2, autoDraw: false, bindInput: false},
            PartialEditorHost.component(context, model, options, e -> editor = e));
        draw();
        draw();
        return editor;
    }

    function editorBox(editor:CityscapeEditor):Bounds {
        return EditorWidgets.editorBounds(editor.getEditor());
    }

    function lineBox(editor:CityscapeEditor, lineNumber:Int):Bounds {
        return EditorWidgets.positionBounds(editor.getEditor(), new Position(lineNumber, 1));
    }

    /** The last line entirely visible in the editor. */
    function lastVisibleLine(editor:CityscapeEditor):Int {
        final box = editorBox(editor);
        var lineNumber = 1;
        while (lineBox(editor, lineNumber + 1) != null && lineBox(editor, lineNumber + 1).origin.y + lineBox(editor, lineNumber + 1).size.height <= box.origin.y + box.size.height) {
            lineNumber++;
        }
        return lineNumber;
    }

    function assertInside(outer:Bounds, inner:Bounds, label:String):Void {
        assertTrue(inner.origin.x >= outer.origin.x - 0.5, label + ' left ' + inner.origin.x);
        assertTrue(inner.origin.y >= outer.origin.y - 0.5, label + ' top ' + inner.origin.y);
        assertTrue(inner.origin.x + inner.size.width <= outer.origin.x + outer.size.width + 0.5, label + ' right ' + (inner.origin.x + inner.size.width));
        assertTrue(inner.origin.y + inner.size.height <= outer.origin.y + outer.size.height + 0.5, label + ' bottom ' + (inner.origin.y + inner.size.height));
    }

    function near(expected:Float, actual:Float, ?label:String):Void {
        assertTrue(Math.abs(expected - actual) <= 1, (label != null ? label + ': ' : '') + 'expected ' + expected + ', got ' + actual);
    }

    function suggestAt(editor:CityscapeEditor, lineNumber:Int, details:Bool):SuggestWidget {
        editor.getEditor().setPosition(new Position(lineNumber, 1));
        draw();
        final controller = SuggestController.get(editor.getEditor());
        controller.triggerSuggest();
        draw();
        draw();
        final widget = controller.widget;
        if (details && !widget._isDetailsVisible()) {
            widget.toggleDetails();
        }
        draw();
        draw();
        assertTrue(widget.isVisible());
        assertNotNull(widget.listBounds);
        return widget;
    }

    function testOptionValidation() {
        final editor = open();
        assertEquals('window', editor.getEditor().getOption(EditorOption.overflowWidgetsBounds));
        editor.getEditor().updateOptions(cast {overflowWidgetsBounds: 'editor'});
        assertEquals('editor', editor.getEditor().getOption(EditorOption.overflowWidgetsBounds));
        editor.getEditor().updateOptions(cast {overflowWidgetsBounds: 'page'});
        assertEquals('window', editor.getEditor().getOption(EditorOption.overflowWidgetsBounds));
        editor.getEditor().updateOptions(cast {overflowWidgetsBounds: 3});
        assertEquals('window', editor.getEditor().getOption(EditorOption.overflowWidgetsBounds));
        assertNull(EditorWidgets.overflowPage(editor.getEditor()));
    }

    /**
     * 'window': the room below the last line is the window's, so the list
     * opens below it, out of the editor (Monaco's page).
     */
    function testSuggestWindow() {
        final editor = open();
        final box = editorBox(editor);
        near(EDITOR_HEIGHT, box.size.height, 'editor height');
        final lineNumber = lastVisibleLine(editor);
        final widget = suggestAt(editor, lineNumber, true);
        assertEquals(ContentWidgetPositionPreference.BELOW, widget.preference);
        final list = widget.listBounds;
        final line = lineBox(editor, lineNumber);
        near(line.origin.y + line.size.height, list.origin.y, 'below the line');
        assertTrue(list.origin.y + list.size.height > box.origin.y + box.size.height, 'out of the editor');
        assertTrue(widget.detailsBounds.origin.y + widget.detailsBounds.size.height > box.origin.y + box.size.height, 'details out of the editor');
    }

    /**
     * 'editor': the same line has no room below inside the editor: the
     * list opens above it, capped to the room there, and the details stay
     * inside the editor too.
     */
    function testSuggestEditor() {
        final editor = open({overflowWidgetsBounds: 'editor'});
        final box = editorBox(editor);
        final lineNumber = lastVisibleLine(editor);
        final widget = suggestAt(editor, lineNumber, true);
        assertEquals(ContentWidgetPositionPreference.ABOVE, widget.preference);
        final list = widget.listBounds;
        final line = lineBox(editor, lineNumber);
        near(line.origin.y, list.origin.y + list.size.height, 'above the line');
        assertInside(box, list, 'list');
        // `_layout` with the editor for the page: 12 rows at most, the room
        // above (less 22 pixels) at most, plus the border
        final itemHeight:Float = editor.getEditor().getOption(EditorOption.fontInfo).lineHeight;
        near(Math.min(12 * itemHeight + 2, line.origin.y - box.origin.y - 22) + 2, list.size.height, 'height');
        assertInside(box, widget.detailsBounds, 'details');
        // near the top of the editor: below, still inside
        final topEditor = open({overflowWidgetsBounds: 'editor'});
        final top = suggestAt(topEditor, 2, true);
        assertEquals(ContentWidgetPositionPreference.BELOW, top.preference);
        assertInside(editorBox(topEditor), top.listBounds, 'list near the top');
        assertInside(editorBox(topEditor), top.detailsBounds, 'details near the top');
    }

    function showHover(editor:CityscapeEditor, lineNumber:Int):ContentHoverWidget {
        final controller = ContentHoverController.get(editor.getEditor());
        controller.showContentHover(new Range(lineNumber, 2, lineNumber, 2), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
        controller.getContentWidget()._flushOperation();
        draw();
        draw();
        draw();
        final widget = controller.getContentWidget().getWidget();
        assertTrue(widget.isVisible);
        assertNotNull(widget.bounds);
        return widget;
    }

    /**
     * The hover of a line near the bottom of the editor: 'window' keeps
     * Monaco's maximum height (250 pixels) and may leave the editor;
     * 'editor' caps it to the room on the larger side, inside the editor.
     */
    function testHover() {
        final windowEditor = open();
        final w = showHover(windowEditor, lastVisibleLine(windowEditor) - 1);
        near(250, w.bounds.size.height, 'window: maximum height');

        final editor = open({overflowWidgetsBounds: 'editor'});
        final box = editorBox(editor);
        final lineNumber = lastVisibleLine(editor) - 1;
        final h = showHover(editor, lineNumber);
        assertInside(box, h.bounds, 'hover');
        assertTrue(h.bounds.size.height < 250, 'capped ' + h.bounds.size.height);
        assertEquals(ContentWidgetPositionPreference.ABOVE, h.positionPreference);
        near(lineBox(editor, lineNumber).origin.y - box.origin.y - ContentWidgetPositioner.TOP_HEIGHT, h.bounds.size.height, 'the room above');
    }

    function showMenu(editor:CityscapeEditor, lineNumber:Int):CodeActionWidget {
        final menu = new CodeActionWidget(editor.getEditor());
        final group:ActionGroup = {kind: HierarchicalKind.Empty, title: 'More Actions...'};
        final items:Array<IActionListItem> = [for (i in 0...40) {kind: ActionListItemKind.Action, group: group, label: 'Action ' + i}];
        final line = lineBox(editor, lineNumber);
        menu.show(items, {onSelect: (_, _) -> {}, onHide: _ -> {}, onFocus: _ -> {}}, line);
        draw();
        draw();
        draw();
        assertTrue(menu.isVisible);
        assertNotNull(menu.menuBounds);
        return menu;
    }

    /**
     * The quick fix menu near the bottom of the editor: 'window' (the kit's
     * popup) goes below, out of the editor; 'editor' stays inside it.
     */
    function testCodeActionMenu() {
        final windowEditor = open();
        final w = showMenu(windowEditor, lastVisibleLine(windowEditor));
        final windowBox = editorBox(windowEditor);
        assertTrue(w.menuBounds.origin.y + w.menuBounds.size.height > windowBox.origin.y + windowBox.size.height, 'window: out of the editor');
        w.hide();

        final editor = open({overflowWidgetsBounds: 'editor'});
        final m = showMenu(editor, lastVisibleLine(editor));
        assertInside(editorBox(editor), m.menuBounds, 'menu');
        m.hide();
    }

    /**
     * `ContentWidgetPositioner.place` keeps a widget inside the page with
     * 'editor', even when it is larger than the room on its side, and
     * leaves the window's placement unchanged.
     */
    function testPlaceInsideThePage() {
        final page = new Bounds(new Point(100, 50), new Size(400, 200));
        final anchors:ContentWidgetAnchors = {
            primary: new Bounds(new Point(450, 230), new Size(1, 18)),
            secondary: null,
            editor: page,
            typicalFullwidthCharacterWidth: 16
        };
        final size = new Size(300, 120);
        final windowPage = new Bounds(new Point(0, 0), new Size(800, 600));
        final inWindow = ContentWidgetPositioner.place(anchors, size, windowPage, ContentWidgetPositionPreference.BELOW);
        near(248, inWindow.origin.y, 'window: below the line');
        anchors.page = page;
        final inEditor = ContentWidgetPositioner.place(anchors, size, page, ContentWidgetPositionPreference.BELOW);
        assertInside(page, inEditor, 'editor');
        assertEquals(ContentWidgetPositionPreference.ABOVE, ContentWidgetPositioner.preferredSide([BELOW, ABOVE], 120, anchors.primary, page));
        assertEquals(ContentWidgetPositionPreference.BELOW, ContentWidgetPositioner.preferredSide([BELOW, ABOVE], 120, anchors.primary, windowPage));
    }

}

class PartialEditorHost extends glaze.Component {

    final context:Cityscape;
    final model:ITextModel;
    final options:Dynamic;
    final onEditor:(editor:CityscapeEditor) -> Void;

    public function new(context:Cityscape, model:ITextModel, options:Dynamic, onEditor:(editor:CityscapeEditor) -> Void) {
        super();
        this.context = context;
        this.model = model;
        this.options = options;
        this.onEditor = onEditor;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        final editor = CityscapeEditor.component().context(context).model(model).onCreate(onEditor).flex1();
        if (options != null) {
            editor.options(cast options);
        }
        return div().flex().flexCol().sizeFull().child(div().flex().h(px(300)).flexNone().child(editor));
    }

}
