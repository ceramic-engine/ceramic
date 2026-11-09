// New code for Cityscape (not a port): the rename of an editor with a rename
// provider (vscode has no tests of contrib/rename).
package tests.contrib.rename;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.contrib.rename.view.Rename;
import cityscape.contrib.rename.view.RenameWidget;
import haxe.extern.EitherType;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * Renames every occurrence of the word at the position.
 */
private class WordRenameProvider implements RenameProvider {

    public var resolveRenameLocation(default, null):Null<(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void) -> Void> = null;
    public var rejectEditsReason:Null<String> = null;
    public var answerNull = false;
    public var throwError = false;
    public final calls:Array<String> = [];

    public function new(?prepare:(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void) -> Void) {
        this.resolveRenameLocation = prepare;
    }

    public function provideRenameEdits(model:ITextModel, position:Position, newName:String, token:CancellationToken, resolve:(edit:Null<WorkspaceEditAndRejection>) -> Void):Void {
        calls.push(newName);
        if (throwError) {
            throw 'provider failure';
        }
        if (answerNull) {
            resolve(null);
            return;
        }
        if (rejectEditsReason != null) {
            resolve({edits: [], rejectReason: rejectEditsReason});
            return;
        }
        final word = model.getWordAtPosition(position);
        final edits:Array<EitherType<IWorkspaceTextEdit, IWorkspaceFileEdit>> = [];
        for (match in model.findMatches(word.word, false, false, true, null, false)) {
            final edit:IWorkspaceTextEdit = {resource: model.uri, textEdit: {range: match.range, text: newName}, versionId: model.getVersionId()};
            edits.push(edit);
        }
        resolve({edits: edits});
    }

}

class RenameTest extends TestCase {

    var context:Cityscape;
    var model:TextModel;
    var editor:TestCodeEditor;
    final messages:Array<{message:String, position:Position}> = [];
    final disposables:Array<{function dispose():Void;}> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'ren'});
        context.onNoResult = (editor, message, position) -> messages.push({message: message, position: position});
        model = context.modelService.createModel('let count = 1;\ncount = count + 1;\n', 'ren', Uri.parse('file:///rename.ren'));
        editor = new TestCodeEditor(context, model, {}, context.editorExtensions.getSomeEditorContributions([RenameController.ID]));
        editor.getViewModel().setHasFocus(true);
    }

    override public function teardown():Void {
        for (d in disposables) {
            d.dispose();
        }
        disposables.resize(0);
        messages.resize(0);
        editor.dispose();
        model.dispose();
    }

    function register(provider:WordRenameProvider):WordRenameProvider {
        disposables.push(context.registerRenameProvider('ren', provider));
        return provider;
    }

    function widget():RenameWidget {
        return RenameController.get(editor).getRenameWidget();
    }

    function renameInputVisible():Bool {
        return editor.contextKeyService.getContextKeyValue('renameInputVisible') == true;
    }

    function testF2ShowsTheInputWithTheWord() {
        register(new WordRenameProvider());
        editor.setPosition(new Position(1, 7));
        editor.trigger('keyboard', RenameAction.ID, null);
        final w = widget();
        assertTrue(w.isVisible);
        assertTrue(renameInputVisible());
        // at the start of the word, with the word selected
        assertTrue(new Position(1, 5).equals(w.getWidgetPosition()));
        assertEquals('count', w.getInputValue());
        assertDeepEquals({start: 0, end: 5}, w.getInputSelection());
        // `input.size`: max(length * 1.1, 20) characters
        assertEquals(20.0, w.getInputSize());
    }

    function testSelectionInsideTheWordIsSelectedInTheInput() {
        register(new WordRenameProvider());
        editor.setSelection(new Range(1, 6, 1, 8));
        editor.trigger('keyboard', RenameAction.ID, null);
        assertDeepEquals({start: 1, end: 3}, widget().getInputSelection());
    }

    function testAcceptAppliesTheEditsWithOneUndoStop() {
        final provider = register(new WordRenameProvider());
        editor.setPosition(new Position(2, 2));
        editor.trigger('keyboard', RenameAction.ID, null);
        final w = widget();
        w.setInputValue('total');
        editor.trigger('keyboard', 'acceptRenameInput', null);
        assertFalse(w.isVisible);
        assertFalse(renameInputVisible());
        assertDeepEquals(['total'], provider.calls);
        assertEquals('let total = 1;\ntotal = total + 1;\n', model.getValue());
        assertEquals(0, messages.length);
        // the selection collapsed to its active end
        assertTrue(editor.getSelection().isEmpty());
        // one undo
        model.undo();
        assertEquals('let count = 1;\ncount = count + 1;\n', model.getValue());
    }

    function testSameNameOrBlankCancels() {
        final provider = register(new WordRenameProvider());
        editor.setPosition(new Position(1, 6));
        editor.trigger('keyboard', RenameAction.ID, null);
        widget().acceptInput(false);
        assertFalse(widget().isVisible);
        editor.trigger('keyboard', RenameAction.ID, null);
        widget().setInputValue('   ');
        widget().acceptInput(false);
        assertFalse(widget().isVisible);
        assertEquals(0, provider.calls.length);
        assertEquals('let count = 1;\ncount = count + 1;\n', model.getValue());
    }

    function testEscapeCancels() {
        final provider = register(new WordRenameProvider());
        editor.setPosition(new Position(1, 6));
        editor.trigger('keyboard', RenameAction.ID, null);
        widget().setInputValue('other');
        editor.trigger('keyboard', 'cancelRenameInput', null);
        assertFalse(widget().isVisible);
        assertFalse(renameInputVisible());
        assertEquals(0, provider.calls.length);
    }

    function testMovingTheCursorOutOfTheWordCancels() {
        register(new WordRenameProvider());
        editor.setPosition(new Position(1, 6));
        editor.trigger('keyboard', RenameAction.ID, null);
        assertTrue(widget().isVisible);
        editor.setPosition(new Position(2, 16));
        assertFalse(widget().isVisible);
    }

    function testPrepareRenameRejection() {
        register(new WordRenameProvider((model, position, token, resolve) -> {
            resolve({range: new Range(1, 1, 1, 4), text: 'let', rejectReason: 'You cannot rename this element.'});
        }));
        editor.setPosition(new Position(1, 2));
        editor.trigger('keyboard', RenameAction.ID, null);
        assertFalse(widget().isVisible);
        assertEquals(1, messages.length);
        assertEquals('You cannot rename this element.', messages[0].message);
        assertTrue(new Position(1, 2).equals(messages[0].position));
    }

    function testPrepareRenameGivesTheRange() {
        register(new WordRenameProvider((model, position, token, resolve) -> {
            resolve({range: new Range(2, 9, 2, 14), text: 'count'});
        }));
        editor.setPosition(new Position(2, 10));
        editor.trigger('keyboard', RenameAction.ID, null);
        assertTrue(new Position(2, 9).equals(widget().getWidgetPosition()));
        assertEquals('count', widget().getInputValue());
    }

    function testNoResultMessage() {
        final provider = register(new WordRenameProvider());
        provider.answerNull = true;
        editor.setPosition(new Position(1, 6));
        editor.trigger('keyboard', RenameAction.ID, null);
        widget().setInputValue('x');
        widget().acceptInput(false);
        assertEquals(1, messages.length);
        assertEquals('No result.', messages[0].message);
        assertEquals('let count = 1;\ncount = count + 1;\n', model.getValue());
    }

    function testRejectedEditsMessage() {
        final provider = register(new WordRenameProvider());
        provider.rejectEditsReason = 'Cannot rename here';
        editor.setPosition(new Position(1, 6));
        editor.trigger('keyboard', RenameAction.ID, null);
        widget().setInputValue('x');
        widget().acceptInput(false);
        assertEquals(1, messages.length);
        assertEquals('Cannot rename here', messages[0].message);
    }

    function testFailedEditsMessage() {
        final provider = register(new WordRenameProvider());
        provider.throwError = true;
        final previous = cityscape.base.common.Errors.unexpectedErrorHandler;
        cityscape.base.common.Errors.unexpectedErrorHandler = _ -> {};
        editor.setPosition(new Position(1, 6));
        editor.trigger('keyboard', RenameAction.ID, null);
        widget().setInputValue('x');
        widget().acceptInput(false);
        cityscape.base.common.Errors.unexpectedErrorHandler = previous;
        assertEquals(1, messages.length);
        assertEquals('Rename failed to compute edits', messages[0].message);
    }

    function testNoRenameProviderNoAction() {
        editor.setPosition(new Position(1, 6));
        assertFalse(editor.contextKeyService.getContextKeyValue('editorHasRenameProvider') == true);
        editor.trigger('keyboard', RenameAction.ID, null);
        assertFalse(widget().isVisible);
        register(new WordRenameProvider());
        assertTrue(editor.contextKeyService.getContextKeyValue('editorHasRenameProvider') == true);
    }

    function testRenameFunction() {
        final provider = register(new WordRenameProvider());
        var result:Null<WorkspaceEditAndRejection> = null;
        RenameRegistration.rename(context.languageFeaturesService.renameProvider, model, new Position(2, 10), 'n').done(r -> result = r);
        assertTrue(result != null);
        assertEquals(3, result.edits.length);
        assertNull(result.rejectReason);
        assertDeepEquals(['n'], provider.calls);
    }

    function testKeybindings() {
        final kb = context.keybindingService;
        assertEquals('F2', kb.lookupKeybindings(RenameAction.ID)[0].getLabel());
        assertEquals('Enter', kb.lookupKeybindings('acceptRenameInput')[0].getLabel());
        assertEquals('Escape', kb.lookupKeybindings('cancelRenameInput')[0].getLabel());
    }

}
