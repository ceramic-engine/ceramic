// New code for Cityscape (not a port): the language features of editors
// fed by a language server (the fake in-process server of LspClientTest):
// diagnostics, completion, hover, go to definition, quick fixes, F8.
package tests.contrib;

import cityscape.Cityscape;
import cityscape.base.common.Uri;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.codeAction.view.CodeActionController;
import cityscape.contrib.codeAction.view.CodeActionMenu;
import cityscape.contrib.gotoError.view.GotoError;
import cityscape.contrib.gotoSymbol.view.GoToCommands;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.contrib.hover.view.MarkdownHoverParticipant;
import cityscape.contrib.hover.view.MarkerHoverParticipant;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.contrib.suggest.view.SuggestController;
import cityscape.lsp.InProcessTransport;
import cityscape.lsp.LspClient;
import cityscape.platform.markers.common.Markers;
import cityscape.view.EditorBrowser;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.lsp.LspClientTest.FakeLspServer;

/**
 * A hover render context recording the status bar (the hover view does
 * this when it renders).
 */
private class RecordingHoverContext implements IEditorHoverRenderContext {
    public final actions:Array<{label:String, commandId:String, run:() -> Void}> = [];
    public final texts:Array<{text:Null<String>}> = [];
    public var hidden = false;

    public function new() {}

    public function addStatusBarAction(label:String, commandId:String, run:() -> Void):Void {
        actions.push({label: label, commandId: commandId, run: run});
    }

    public function addStatusBarText(text:String):(text:Null<String>) -> Void {
        final entry = {text: (text : Null<String>)};
        texts.push(entry);
        return value -> entry.text = value;
    }

    public function hide():Void {
        hidden = true;
    }

    public function onContentsChanged():Void {}

    public function statusBarBounds():Null<glaze.Bounds> {
        return null;
    }
}

class LanguageFeaturesTest extends TestCase {

    static inline final URI = 'file:///main.fake';

    var context:Cityscape;
    var server:FakeLspServer;
    var client:LspClient;
    var model:ITextModel;
    final editors:Array<TestCodeEditor> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'fakelang'});
        server = new FakeLspServer();
        client = new LspClient(context, new InProcessTransport(server), {languageIds: ['fakelang'], rootUri: 'file:///project'});
        client.start();
        model = context.modelService.createModel('foo bar\nbaz qux\n', 'fakelang', Uri.parse(URI));
    }

    override public function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors.resize(0);
        client.dispose();
        model.dispose();
    }

    function newEditor():TestCodeEditor {
        final ids = [
            SnippetController2.ID,
            SuggestController.ID,
            ContentHoverController.ID,
            CodeActionController.ID,
            cityscape.contrib.codeAction.view.LightBulbWidget.ID,
            MarkerController.ID,
            GotoDefinitionAtPosition.ID
        ];
        final editor = new TestCodeEditor(context, cast model, {}, context.editorExtensions.getSomeEditorContributions(ids));
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        return editor;
    }

    function publishError():Void {
        server.publish(URI, [{
            range: {start: {line: 0, character: 0}, end: {line: 0, character: 3}},
            severity: 1,
            source: 'fake',
            code: 'E1',
            message: 'Bad foo'
        }]);
    }

    function testDiagnosticsBecomeMarkersAndSquiggles() {
        publishError();
        final markers = context.markerService.read({resource: model.uri});
        assertEquals(1, markers.length);
        assertEquals('Bad foo', markers[0].message);
        assertEquals(MarkerSeverity.Error, markers[0].severity);
        assertEquals(1, markers[0].startColumn);
        assertEquals(4, markers[0].endColumn);
        var squiggles = 0;
        for (d in model.getLineDecorations(1)) {
            if (d.options.className == 'squiggly-error') {
                squiggles++;
            }
        }
        assertEquals(1, squiggles);
        server.publish(URI, []);
        assertEquals(0, context.markerService.read({resource: model.uri}).length);
    }

    function testCompletionAppearsAndAccepts() {
        final editor = newEditor();
        // before 'bar': no word to filter with
        editor.setPosition(new Position(1, 5));
        final controller = SuggestController.get(editor);
        controller.triggerSuggest();
        final widget = controller.widget;
        assertTrue(widget.isVisible());
        final labels = [for (item in widget.items) item.textLabel];
        assertTrue(labels.indexOf('alpha') >= 0, labels.join(','));
        // beta replaces 'foo ': filtered out by 'foo ' like in Monaco
        assertEquals(-1, labels.indexOf('beta'));
        final index = labels.indexOf('alpha');
        widget.selectAt(index);
        assertFalse(widget.isVisible());
        // alpha($1) is a snippet: the cursor is inside the parentheses
        assertEquals('foo alpha()bar', model.getLineContent(1));
        assertEquals(11, editor.getPosition().column);
    }

    /**
     * Monaco creates the `BeforeFirstInteraction` contributions (the
     * suggest controller...) in idle time too, not only before a mouse or
     * key event: an editor typed into through its API alone
     * (`trigger('keyboard', 'type', ...)`) shows its quick suggestions.
     */
    function asyncTestQuickSuggestionsWithoutInteraction(done:() -> Void) {
        final editor = newEditor();
        final contributions = @:privateAccess editor._contributions;
        assertFalse(@:privateAccess contributions._instances.exists(SuggestController.ID));
        ceramic.Timer.delay(null, 0.05, () -> {
            assertTrue(@:privateAccess contributions._instances.exists(SuggestController.ID));
            editor.setPosition(new Position(1, 5));
            editor.trigger('keyboard', 'type', {text: 'a'});
            final controller:SuggestController = @:privateAccess cast contributions._instances.get(SuggestController.ID);
            controller.model._flushQuickSuggest();
            assertTrue(controller.widget.isVisible());
            final labels = [for (item in controller.widget.items) item.textLabel];
            assertTrue(labels.indexOf('alpha') >= 0, labels.join(','));
            done();
        });
    }

    function testCompletionResolvesDocumentation() {
        final editor = newEditor();
        editor.setPosition(new Position(1, 5));
        final controller = SuggestController.get(editor);
        controller.triggerSuggest();
        final focused = controller.widget.getFocusedItem();
        assertNotNull(focused);
        // the focused item is resolved by its provider (completionItem/resolve)
        assertTrue(server.messagesOf('completionItem/resolve').length > 0);
        assertTrue(focused.item.isResolved);
        assertNotNull(focused.item.completion.documentation);
    }

    function testHoverShowsMarkdown() {
        final editor = newEditor();
        final controller = ContentHoverController.get(editor);
        controller.showContentHover(new Range(1, 2, 1, 2), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
        assertTrue(controller.isHoverVisible);
        final rendered = controller.getContentWidget().getRenderedHover();
        assertNotNull(rendered);
        var markdown:Null<MarkdownHover> = null;
        for (part in rendered.hoverParts) {
            if (Std.isOfType(part, MarkdownHover)) {
                markdown = cast part;
            }
        }
        assertNotNull(markdown);
        assertEquals('**hover**', markdown.contents[0].value);
        // the range of the hover (LSP 0..5 on line 0)
        assertEquals(1, markdown.range.startColumn);
        assertEquals(6, markdown.range.endColumn);
        assertEquals(1, rendered.showAtPosition.lineNumber);
        controller.hideContentHover();
        assertFalse(controller.isHoverVisible);
    }

    function testMarkerHoverWithQuickFixApplies() {
        publishError();
        final editor = newEditor();
        final controller = ContentHoverController.get(editor);
        controller.showContentHover(new Range(1, 2, 1, 2), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
        final rendered = controller.getContentWidget().getRenderedHover();
        var marker:Null<MarkerHover> = null;
        for (part in rendered.hoverParts) {
            if (Std.isOfType(part, MarkerHover)) {
                marker = cast part;
            }
        }
        assertNotNull(marker);
        assertEquals('Bad foo', marker.marker.message);
        assertEquals('fake', marker.marker.source);

        // the status bar of the marker: View Problem, Quick Fix...
        final hoverContext = new RecordingHoverContext();
        marker.owner.renderHoverParts(hoverContext, [marker], null, null);
        final labels = [for (a in hoverContext.actions) a.label];
        assertTrue(labels.indexOf('View Problem') >= 0, labels.join(','));
        assertTrue(labels.indexOf('Quick Fix...') >= 0, labels.join(','));
        for (a in hoverContext.actions) {
            if (a.label == 'Quick Fix...') {
                a.run();
            }
        }
        assertTrue(hoverContext.hidden);

        // the quick fixes show in the code action menu
        final menu = CodeActionController.get(editor).getActionWidget();
        assertTrue(menu.isVisible);
        final items = menu.getItems();
        var fixIndex = -1;
        for (i in 0...items.length) {
            if (items[i].label == 'Fix it') {
                fixIndex = i;
            }
        }
        assertTrue(fixIndex >= 0);
        // the original LSP diagnostic went back with the request
        final request = server.lastOf('textDocument/codeAction');
        assertEquals('Bad foo', request.params.context.diagnostics[0].message);
        menu.select(fixIndex);
        assertEquals('fixed bar', model.getLineContent(1));
        assertFalse(menu.isVisible);
    }

    function testQuickFixCommandCmdPeriod() {
        publishError();
        final editor = newEditor();
        editor.setPosition(new Position(1, 2));
        editor.trigger('keyboard', 'editor.action.quickFix', null);
        final menu = CodeActionController.get(editor).getActionWidget();
        assertTrue(menu.isVisible);
        final titles = [for (item in menu.getItems()) if (item.kind == ActionListItemKind.Action) item.label];
        assertEquals('Fix it', titles[0]);
        // the quick fix group has a header
        assertEquals(ActionListItemKind.Header, menu.getItems()[0].kind);
        menu.hide();
        assertFalse(menu.isVisible);
    }

    function testLightbulbOnTheLineOfAQuickFix() {
        publishError();
        final editor = newEditor();
        editor.setPosition(new Position(1, 2));
        final controller = CodeActionController.get(editor);
        final oracle = @:privateAccess controller._getModel()._getOracle();
        oracle._flushAutoTrigger();
        final lightbulb = cityscape.contrib.codeAction.view.LightBulbWidget.get(editor);
        assertTrue(lightbulb.isVisible());
        assertEquals(1, lightbulb.getLineNumber());
    }

    function testCmdClickGoesToDefinitionThroughTheOpener() {
        final editor = newEditor();
        final opened:Array<{resource:String, line:Int, column:Int}> = [];
        context.codeEditorService.registerCodeEditorOpenHandler((input, source, sideBySide, resolve) -> {
            opened.push({resource: input.resource.toString(), line: input.options.selection.startLineNumber, column: input.options.selection.startColumn});
            resolve(source);
        });
        final contribution = GotoDefinitionAtPosition.get(editor);
        final position = new Position(1, 2);
        final target = new MouseTarget(MouseTargetType.CONTENT_TEXT, position, 2, new Range(1, 2, 1, 3));
        final data = new EditorMouseEventData(true, false, false, true, false, false, true, 1);
        // Cmd hover: the word is a link
        @:privateAccess editor._fireMouseMove(new EditorMouseEvent(data, target));
        final ranges = contribution.getLinkRanges();
        assertEquals(1, ranges.length);
        assertEquals(1, ranges[0].startColumn);
        assertEquals(4, ranges[0].endColumn);
        // Cmd+click: the definition opens through the opener
        @:privateAccess editor._fireMouseDown(new EditorMouseEvent(data, target));
        @:privateAccess editor._fireMouseUp(new EditorMouseEvent(data, target));
        assertEquals(1, opened.length);
        assertEquals('file:///other.fake', opened[0].resource);
        assertEquals(4, opened[0].line);
        assertEquals(3, opened[0].column);
        assertEquals(0, contribution.getLinkRanges().length);
    }

    function testF12GoesToDefinition() {
        final other = context.modelService.createModel('a\nb\nc\n  target here\n', 'fakelang', Uri.parse('file:///other.fake'));
        final editor = newEditor();
        var openedModel:Null<ITextModel> = null;
        context.codeEditorService.registerCodeEditorOpenHandler((input, source, sideBySide, resolve) -> {
            // a host switches the model of the editor
            final target = context.modelService.getModel(input.resource);
            source.setModel(target);
            openedModel = target;
            source.setSelection(input.options.selection);
            resolve(source);
        });
        editor.setPosition(new Position(1, 2));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        assertTrue(openedModel == other);
        assertEquals(4, editor.getPosition().lineNumber);
        assertEquals(3, editor.getPosition().column);
        editor.setModel(cast model);
        other.dispose();
    }

    function testF8ShowsTheMarkerInTheHover() {
        server.publish(URI, [{
            range: {start: {line: 1, character: 4}, end: {line: 1, character: 7}},
            severity: 2,
            message: 'Careful'
        }]);
        final editor = newEditor();
        editor.setPosition(new Position(1, 1));
        editor.trigger('keyboard', 'editor.action.marker.next', null);
        assertEquals(2, editor.getPosition().lineNumber);
        assertEquals(5, editor.getPosition().column);
        final shown = MarkerController.get(editor).getShownMarker();
        assertNotNull(shown);
        assertEquals('Careful', shown.marker.message);
        assertEquals(1, shown.index);
        assertEquals(1, shown.total);
        final hover = ContentHoverController.get(editor);
        assertTrue(hover.isHoverVisible);
        final rendered = hover.getContentWidget().getRenderedHover();
        var found = false;
        for (part in rendered.hoverParts) {
            if (Std.isOfType(part, MarkerHover) && (cast part : MarkerHover).marker.message == 'Careful') {
                found = true;
            }
        }
        assertTrue(found);
    }

    function testTwoEditorsHaveIndependentWidgets() {
        final a = newEditor();
        final b = newEditor();
        a.setPosition(new Position(1, 5));
        b.setPosition(new Position(1, 4));
        SuggestController.get(a).triggerSuggest();
        assertTrue(SuggestController.get(a).widget.isVisible());
        assertFalse(SuggestController.get(b).widget.isVisible());
        ContentHoverController.get(b).showContentHover(new Range(1, 2, 1, 2), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
        assertTrue(ContentHoverController.get(b).isHoverVisible);
        assertFalse(ContentHoverController.get(a).isHoverVisible);
        // accepting in one editor edits the shared model, the other keeps its state
        final widget = SuggestController.get(a).widget;
        final labels = [for (item in widget.items) item.textLabel];
        widget.selectAt(labels.indexOf('alpha'));
        assertEquals('foo alpha()bar', model.getLineContent(1));
        assertEquals(11, a.getPosition().column);
        assertEquals(4, b.getPosition().column);
        assertFalse(SuggestController.get(b).widget.isVisible());
    }


    /**
     * formatActions.ts `FormatOnType`: with `formatOnType`, typing a trigger
     * character of the server (`}` and `;` here) applies the edits of
     * `textDocument/onTypeFormatting` (two spaces at the start of the line),
     * in their own undo stop; other characters, or the option off, send
     * nothing.
     */
    function testFormatOnType() {
        final ids = [cityscape.contrib.format.view.Format.FormatOnType.ID];
        final editor = new TestCodeEditor(context, cast model, {formatOnType: true}, context.editorExtensions.getSomeEditorContributions(ids));
        editors.push(editor);
        // a BeforeFirstInteraction contribution, created here at once
        assertNotNull(editor.getContribution(cityscape.contrib.format.view.Format.FormatOnType.ID));
        editor.setPosition(new Position(2, 4));
        editor.trigger('keyboard', 'type', {text: 'x'});
        assertEquals(0, server.messagesOf('textDocument/onTypeFormatting').length);
        editor.trigger('keyboard', 'type', {text: ';'});
        final request:Dynamic = server.lastOf('textDocument/onTypeFormatting');
        assertNotNull(request);
        assertEquals(';', request.params.ch);
        assertDeepEquals({line: 1, character: 5}, request.params.position);
        assertEquals('  bazx; qux', model.getLineContent(2));
        // the cursor moved with the text
        assertEquals(8, editor.getPosition().column);
        // the formatting is undone alone
        model.undo();
        assertEquals('bazx; qux', model.getLineContent(2));

        // option off
        final count = server.messagesOf('textDocument/onTypeFormatting').length;
        final off = new TestCodeEditor(context, cast model, {}, context.editorExtensions.getSomeEditorContributions(ids));
        editors.push(off);
        off.getContribution(cityscape.contrib.format.view.Format.FormatOnType.ID);
        off.setPosition(new Position(1, 1));
        off.trigger('keyboard', 'type', {text: '}'});
        assertEquals(count, server.messagesOf('textDocument/onTypeFormatting').length);
        assertEquals('}foo bar', model.getLineContent(1));
    }

}
