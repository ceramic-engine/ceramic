// Ported from vscode src/vs/editor/test/browser/testCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon;
import cityscape.common.Model;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import tests.TestTextModel;

/**
 * vscode's `testCommand` and `getEditOperation`. Monaco's
 * `ServicesAccessor` is the `Cityscape` context of the test.
 */
class TestCommand {

    public static function testCommand(
        test:TestCase,
        lines:Array<String>,
        languageId:Null<String>,
        selection:Selection,
        commandFactory:(accessor:Cityscape, selection:Selection) -> ICommand,
        expectedLines:Array<String>,
        expectedSelection:Selection,
        ?forceTokenization:Bool,
        ?prepare:(accessor:Cityscape, disposables:DisposableStore) -> Void,
        ?pos:haxe.PosInfos
    ):Void {
        final disposables = new DisposableStore();
        final context = new Cityscape();
        if (prepare != null) {
            prepare(context, disposables);
        }
        final model = TestTextModel.instantiateTextModel(context, lines.join('\n'), languageId);
        final editor = new TestCodeEditor(context, model, {});
        final viewModel = editor.getViewModel();

        if (forceTokenization == true) {
            model.tokenization.forceTokenization(model.getLineCount());
        }

        viewModel.setSelections('tests', [selection]);

        final command = commandFactory(context, viewModel.getSelection());
        viewModel.executeCommand(command, 'tests');

        @:privateAccess test.assertDeepEquals(expectedLines, model.getLinesContent(), null, pos);

        final actualSelection = viewModel.getSelection();
        @:privateAccess test.assertDeepEquals(expectedSelection.toString(), actualSelection.toString(), null, pos);

        editor.dispose();
        model.dispose();
        disposables.dispose();
    }

    /**
     * Extract edit operations if command `command` were to execute on model `model`
     */
    public static function getEditOperation(model:ITextModel, command:ICommand):Array<ISingleEditOperation> {
        final operations:Array<ISingleEditOperation> = [];
        command.getEditOperations(model, new RecordingEditOperationBuilder(operations));
        return operations;
    }

}

private class RecordingEditOperationBuilder implements IEditOperationBuilder {

    final operations:Array<ISingleEditOperation>;

    public function new(operations:Array<ISingleEditOperation>) {
        this.operations = operations;
    }

    public function addEditOperation(range:IRange, text:Null<String>, ?forceMoveMarkers:Bool):Void {
        operations.push({
            range: range,
            text: text,
            forceMoveMarkers: forceMoveMarkers == true
        });
    }

    public function addTrackedEditOperation(range:IRange, text:Null<String>, ?forceMoveMarkers:Bool):Void {
        operations.push({
            range: range,
            text: text,
            forceMoveMarkers: forceMoveMarkers == true
        });
    }

    public function trackSelection(selection:Selection, ?trackPreviousOnEmpty:Bool):String {
        return '';
    }

}
