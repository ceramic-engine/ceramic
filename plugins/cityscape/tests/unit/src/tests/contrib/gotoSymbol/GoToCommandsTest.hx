// New code for Cityscape (not a port): the symbol navigation commands of
// goToCommands.ts, symbolNavigation.ts and the references peek view
// (referencesController.ts). vscode has no tests of these commands: these
// check Monaco's rules (the `gotoLocation` modes, the alternative command,
// F12 through the remaining locations, the peek view's model and title, the
// next and previous reference, Escape) with providers of the test.
package tests.contrib.gotoSymbol;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.gotoSymbol.view.GoToCommands;
import cityscape.contrib.gotoSymbol.view.SymbolNavigation;
import cityscape.contrib.gotoSymbol.view.peek.ReferencesController;
import testing.TestCase;
import testing.TestCodeEditor;

private class TestDefinitionProvider implements DefinitionProvider {
    final links:Array<LocationLink>;
    public function new(links:Array<LocationLink>) {
        this.links = links;
    }
    public function provideDefinition(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void {
        resolve(links);
    }
}

private class TestReferenceProvider implements ReferenceProvider {
    final locations:Array<Location>;
    public var lastContext:Null<ReferenceContext> = null;
    public function new(locations:Array<Location>) {
        this.locations = locations;
    }
    public function provideReferences(model:ITextModel, position:Position, context:ReferenceContext, token:CancellationToken, resolve:(locations:Null<Array<Location>>) -> Void):Void {
        lastContext = context;
        resolve(locations);
    }
}

class GoToCommandsTest extends TestCase {

    var context:Cityscape;
    var model:TextModel;
    var editors:Array<TestCodeEditor>;

    static final TEXT = [
        'function foo() {}',
        'foo();',
        'foo();',
        'foo();',
        ''
    ].join('\n');

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'navlang', extensions: ['.nav']});
        model = cast context.modelService.createModel(TEXT, 'navlang', Uri.parse('file:///a.nav'));
        editors = [];
        // the editor opens the locations of its own model
        context.codeEditorService.registerCodeEditorOpenHandler((input, source, sideBySide, resolve) -> {
            if (source != null && source.getModel() != null && source.getModel().uri.toString() == input.resource.toString()) {
                if (input.options != null && input.options.selection != null) {
                    source.setSelection(input.options.selection);
                }
                resolve(source);
            }
            else {
                resolve(null);
            }
        });
    }

    override public function teardown():Void {
        for (e in editors) {
            e.dispose();
        }
        model.dispose();
    }

    function newEditor(?options:cityscape.common.config.EditorOptions.IEditorOptions):TestCodeEditor {
        final editor = new TestCodeEditor(context, model, options != null ? options : {}, context.editorExtensions.getSomeEditorContributions([
            ReferencesController.ID,
            GotoDefinitionAtPosition.ID
        ]));
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        return editor;
    }

    function link(line:Int, start:Int, end:Int):LocationLink {
        return {uri: model.uri, range: new Range(line, start, line, end)};
    }

    function testOneDefinitionGoesToIt() {
        context.registerDefinitionProvider('navlang', new TestDefinitionProvider([link(1, 10, 13)]));
        final editor = newEditor();
        editor.setPosition(new Position(3, 1));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        assertEquals(1, editor.getPosition().lineNumber);
        assertEquals(10, editor.getPosition().column);
        assertNull(ReferencesController.get(editor).getWidget(), 'no peek view for one location');
    }

    function testSeveralDefinitionsPeekByDefault() {
        // gotoLocation.multipleDefinitions is 'peek' by default
        context.registerDefinitionProvider('navlang', new TestDefinitionProvider([link(2, 1, 4), link(4, 1, 4)]));
        final editor = newEditor();
        editor.setPosition(new Position(1, 10));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        // the cursor stays, the peek view shows the definitions
        assertEquals(1, editor.getPosition().lineNumber);
        final widget = ReferencesController.get(editor).getWidget();
        assertNotNull(widget);
        assertEquals('Definitions (2)', widget.metaTitle);
        assertEquals('a.nav', widget.title);
        assertEquals(2, widget.getModel().references.length);
        assertEquals(true, editor.contextKeyService.getContextKeyValue('referenceSearchVisible'));
    }

    function testGotoModeKeepsTheOtherLocationsForF12() {
        context.registerDefinitionProvider('navlang', new TestDefinitionProvider([link(2, 1, 4), link(3, 1, 4), link(4, 1, 4)]));
        final editor = newEditor({gotoLocation: {multipleDefinitions: 'goto'}});
        editor.setPosition(new Position(1, 10));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        assertEquals(2, editor.getPosition().lineNumber);
        assertNull(ReferencesController.get(editor).getWidget());
        // symbolNavigation.ts: `hasSymbols`, then F12 goes to the next ones
        assertEquals(true, context.contextKeyService.getContextKeyValue('hasSymbols'));
        editor.trigger('keyboard', 'editor.gotoNextSymbolFromResult', null);
        assertEquals(3, editor.getPosition().lineNumber);
        editor.trigger('keyboard', 'editor.gotoNextSymbolFromResult', null);
        assertEquals(4, editor.getPosition().lineNumber);
        // and around
        editor.trigger('keyboard', 'editor.gotoNextSymbolFromResult', null);
        assertEquals(2, editor.getPosition().lineNumber);
        // moving away from the locations resets it
        editor.setPosition(new Position(1, 1));
        assertNotEquals(true, context.contextKeyService.getContextKeyValue('hasSymbols'));
    }

    function testGotoAndPeekGoesToTheFirstAndPeeks() {
        context.registerDefinitionProvider('navlang', new TestDefinitionProvider([link(2, 1, 4), link(4, 1, 4)]));
        final editor = newEditor({gotoLocation: {multipleDefinitions: 'gotoAndPeek'}});
        editor.setPosition(new Position(1, 10));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        assertEquals(2, editor.getPosition().lineNumber);
        final widget = ReferencesController.get(editor).getWidget();
        assertNotNull(widget);
        assertEquals(2, widget.position.lineNumber);
    }

    function testAtTheOnlyResultRunsTheAlternativeCommand() {
        // goToCommands.ts: on the only definition, the alternative command
        // (`editor.action.goToReferences` by default) runs instead
        context.registerDefinitionProvider('navlang', new TestDefinitionProvider([link(1, 10, 13)]));
        final references = new TestReferenceProvider([{uri: model.uri, range: new Range(2, 1, 2, 4)}]);
        context.registerReferenceProvider('navlang', references);
        final editor = newEditor();
        editor.setPosition(new Position(1, 11));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        assertEquals(2, editor.getPosition().lineNumber, 'went to the reference');
        // goToSymbol.ts: the references with the declaration (asked again
        // without it only when there are two)
        assertEquals(true, references.lastContext.includeDeclaration);
    }

    function testNoDefinitionMessage() {
        context.registerDefinitionProvider('navlang', new TestDefinitionProvider([]));
        final messages:Array<String> = [];
        context.onNoResult = (editor, message, position) -> messages.push(message);
        final editor = newEditor();
        editor.setPosition(new Position(2, 2));
        editor.trigger('keyboard', DefinitionAction.ID, null);
        assertEquals(1, messages.length);
        assertEquals("No definition found for 'foo'", messages[0]);
    }

    function testPeekReferences() {
        final references = new TestReferenceProvider([
            {uri: model.uri, range: new Range(1, 10, 1, 13)},
            {uri: model.uri, range: new Range(2, 1, 2, 4)},
            {uri: model.uri, range: new Range(3, 1, 3, 4)}
        ]);
        context.registerReferenceProvider('navlang', references);
        final editor = newEditor();
        editor.setPosition(new Position(2, 2));
        editor.trigger('keyboard', 'editor.action.referenceSearch.trigger', null);
        // peek: with the declaration
        assertEquals(true, references.lastContext.includeDeclaration);
        final controller = ReferencesController.get(editor);
        final widget = controller.getWidget();
        assertNotNull(widget);
        assertEquals('References (3)', widget.metaTitle);
        // the nearest reference is selected
        assertEquals(2, widget.focusedReference.range.startLineNumber);
        assertTrue(widget.previewModel == model);
        // one file: the rows are the references
        assertEquals(3, widget.rows().length);
        // next and previous reference (F4, Shift+F4) go through them
        controller.goToNextOrPreviousReference(true);
        assertEquals(3, controller.getWidget().focusedReference.range.startLineNumber);
        assertEquals(3, editor.getPosition().lineNumber);
        controller.goToNextOrPreviousReference(true);
        assertEquals(1, controller.getWidget().focusedReference.range.startLineNumber);
        controller.goToNextOrPreviousReference(false);
        assertEquals(3, controller.getWidget().focusedReference.range.startLineNumber);
        // the tree: Down shows the next reference in the preview
        controller.getWidget().moveFocus(-1);
        assertEquals(2, controller.getWidget().focusedReference.range.startLineNumber);
        // Escape (closeReferenceSearch) closes it
        context.codeEditorService.withInvokingEditor(editor, () -> {
            context.commandService.executeCommand('closeReferenceSearch', []);
            return null;
        });
        assertNull(controller.getWidget());
        assertNotEquals(true, editor.contextKeyService.getContextKeyValue('referenceSearchVisible'));
    }

    function testGoToReferencesWithOneResultGoesToIt() {
        context.registerReferenceProvider('navlang', new TestReferenceProvider([{uri: model.uri, range: new Range(3, 1, 3, 4)}]));
        final editor = newEditor();
        editor.setPosition(new Position(1, 1));
        editor.trigger('keyboard', 'editor.action.goToReferences', null);
        assertEquals(3, editor.getPosition().lineNumber);
    }

    function testGoToLocationsCommand() {
        final editor = newEditor();
        // one location: goes to it
        context.codeEditorService.withInvokingEditor(editor, () -> {
            context.commandService.executeCommand('editor.action.goToLocations', [
                model.uri, {lineNumber: 1, column: 1}, [({uri: model.uri, range: new Range(4, 2, 4, 3)} : LocationLink)], 'goto'
            ]);
            return null;
        });
        assertEquals(4, editor.getPosition().lineNumber);
        assertEquals(2, editor.getPosition().column);
    }

}
