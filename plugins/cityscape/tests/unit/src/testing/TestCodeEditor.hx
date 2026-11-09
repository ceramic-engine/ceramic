// Ported from vscode src/vs/editor/test/browser/testCodeEditor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents;
import cityscape.common.ViewModelEventDispatcher;
import cityscape.common.EditorCommon;
import cityscape.common.Model;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.view.CoreCommands.ICodeEditor;
import cityscape.view.config.EditorConfiguration;
import haxe.extern.EitherType;
import tests.TestTextModel;

/**
 * vscode's test code editor without the DOM and the dependency injection:
 * the model, a `ViewModel` with the test configuration (Monaco's
 * `TestConfiguration`: 100x100, the mock font of 19 px lines and 10 px
 * characters, which is what `EditorConfiguration` computes without a font
 * measurer) and the parts of `CodeEditorWidget` the tests use.
 *
 * `context` is the `Cityscape` context of the test (vscode's test services:
 * languages, language configurations, tokenizers, undo/redo).
 */
class TestCodeEditor implements ICodeEditor {

    static var nextEditorId = 1;

    public final context:Cityscape;
    final _model:TextModel;
    final _configuration:EditorConfiguration;
    final _viewModel:ViewModel;
    final _disposables = new DisposableStore();
    var _disposed = false;

    public function new(context:Cityscape, model:TextModel, options:IEditorOptions) {
        this.context = context;
        this._model = model;
        this._configuration = new EditorConfiguration(false, options, {width: 100, height: 100});
        final factory = MonospaceLineBreaksComputerFactory.create(EditorViewOptions.DEFAULT_WORD_WRAP_BREAK_BEFORE_CHARACTERS, EditorViewOptions.DEFAULT_WORD_WRAP_BREAK_AFTER_CHARACTERS);
        this._viewModel = new ViewModel(nextEditorId++, this._configuration, model, factory, factory, null, context);
        // CodeEditorWidget detaches a model that will be disposed (`setModel(null)`)
        _disposables.add(model.onWillDispose(() -> this._detachModel()));
        this.onDidChangeCursorPosition = _onDidChangeCursorPosition.event;
        this.onDidChangeCursorSelection = _onDidChangeCursorSelection.event;
        // CodeEditorWidget's listener of the view model events (the cursor ones)
        _disposables.add(this._viewModel.onEvent((e) -> {
            if (e.kind == OutgoingViewModelEventKind.CursorStateChanged) {
                final e:CursorStateChangedEvent = cast e;
                final positions:Array<Position> = [];
                for (i in 0...e.selections.length) {
                    positions[i] = e.selections[i].getPosition();
                }

                final e1:ICursorPositionChangedEvent = {
                    position: positions[0],
                    secondaryPositions: positions.slice(1),
                    reason: e.reason,
                    source: e.source
                };
                _onDidChangeCursorPosition.fire(e1);

                final e2:ICursorSelectionChangedEvent = {
                    selection: e.selections[0],
                    secondarySelections: e.selections.slice(1),
                    modelVersionId: e.modelVersionId,
                    oldSelections: e.oldSelections,
                    oldModelVersionId: e.oldModelVersionId,
                    source: e.source,
                    reason: e.reason
                };
                _onDidChangeCursorSelection.fire(e2);
            }
        }));
    }

    final _onDidChangeCursorPosition = new Emitter<ICursorPositionChangedEvent>();
    public final onDidChangeCursorPosition:Event<ICursorPositionChangedEvent>;

    final _onDidChangeCursorSelection = new Emitter<ICursorSelectionChangedEvent>();
    public final onDidChangeCursorSelection:Event<ICursorSelectionChangedEvent>;

    public function registerDisposable(disposable:IDisposable):Void {
        _disposables.add(disposable);
    }

    var _modelDetached = false;

    function _detachModel():Void {
        if (_modelDetached) {
            return;
        }
        _modelDetached = true;
        _viewModel.dispose();
    }

    public function dispose():Void {
        if (_disposed) {
            return;
        }
        _disposed = true;
        _detachModel();
        _configuration.dispose();
        _disposables.dispose();
    }

    public function getViewModel():ViewModel {
        return _viewModel;
    }

    public function _getViewModel():Null<IViewModel> {
        return _viewModel;
    }

    public function getModel():TextModel {
        return _model;
    }

    public function getTextModel():Null<ITextModel> {
        return _model;
    }

    public function getValue():String {
        return _model.getValue();
    }

    public function getOption<V>(id:EditorOption<V>):V {
        return _configuration.options.get(id);
    }

    public function updateOptions(newOptions:IEditorOptions):Void {
        _configuration.updateOptions(newOptions);
    }

    public function getPosition():Position {
        return _viewModel.getPosition();
    }

    public function setPosition(position:IPosition, source:String = 'api'):Void {
        _viewModel.setSelections(source, [new Selection(position.lineNumber, position.column, position.lineNumber, position.column)]);
    }

    public function getSelection():Selection {
        return _viewModel.getSelection();
    }

    public function getSelections():Null<Array<Selection>> {
        return _viewModel.getSelections();
    }

    /**
     * Reveals a position (the test editor has no view: only checks the
     * arguments, like Monaco's `_sendRevealRange`).
     */
    public function revealPosition(position:IPosition, ?scrollType:ScrollType):Void {
        if (!Position.isIPosition(position)) {
            throw 'Invalid arguments';
        }
    }

    /**
     * `selection` is a `Selection` or a `Range` (a range selects from its
     * start to its end, like Monaco's `IRange` case).
     */
    public function setSelection(something:Range, source:String = 'api'):Void {
        final selection = Std.downcast(something, Selection);
        if (selection != null) {
            _viewModel.setSelections(source, [new Selection(selection.selectionStartLineNumber, selection.selectionStartColumn, selection.positionLineNumber, selection.positionColumn)]);
        }
        else {
            _viewModel.setSelections(source, [new Selection(something.startLineNumber, something.startColumn, something.endLineNumber, something.endColumn)]);
        }
    }

    public function setSelections(ranges:Array<Selection>, source:String = 'api', reason:CursorChangeReason = CursorChangeReason.NotSet):Void {
        if (ranges == null || ranges.length == 0) {
            throw 'Invalid arguments';
        }
        _viewModel.setSelections(source, ranges, reason);
    }

    public function trigger(source:Null<String>, handlerId:String, payload:Dynamic):Void {
        if (payload == null) {
            payload = {};
        }
        switch (handlerId) {
            case Handler.CompositionStart:
                _viewModel.startComposition();
            case Handler.CompositionEnd:
                _viewModel.endComposition(source);
            case Handler.Type:
                final text:Null<String> = payload.text;
                if (text != null && text.length > 0) {
                    _viewModel.type(text, source);
                }
            case Handler.ReplacePreviousChar:
                final text:Null<String> = payload.text;
                final replaceCharCnt:Null<Int> = payload.replaceCharCnt;
                _viewModel.compositionType(text != null ? text : '', replaceCharCnt != null ? replaceCharCnt : 0, 0, 0, source);
            case Handler.CompositionType:
                final text:Null<String> = payload.text;
                final replacePrevCharCnt:Null<Int> = payload.replacePrevCharCnt;
                final replaceNextCharCnt:Null<Int> = payload.replaceNextCharCnt;
                final positionDelta:Null<Int> = payload.positionDelta;
                _viewModel.compositionType(text != null ? text : '', replacePrevCharCnt != null ? replacePrevCharCnt : 0, replaceNextCharCnt != null ? replaceNextCharCnt : 0, positionDelta != null ? positionDelta : 0, source);
            case Handler.Paste:
                final text:Null<String> = payload.text;
                final pasteOnNewLine:Null<Bool> = payload.pasteOnNewLine;
                final multicursorText:Null<Array<String>> = payload.multicursorText;
                _viewModel.paste(text != null ? text : '', pasteOnNewLine == true, multicursorText, source);
            case Handler.Cut:
                _viewModel.cut(source);
            case _:
                throw 'Unknown handler ' + handlerId;
        }
    }

    public function pushUndoStop():Bool {
        if (_configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }
        _model.pushStackElement();
        return true;
    }

    public function popUndoStop():Bool {
        if (_configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }
        _model.popStackElement();
        return true;
    }

    /**
     * `endCursorState` is null, an array of selections or an
     * `ICursorStateComputer`.
     */
    public function executeEdits(source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, ?endCursorState:EitherType<Array<Selection>, ICursorStateComputer>):Bool {
        if (_configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }

        var cursorStateComputer:ICursorStateComputer;
        if (endCursorState == null) {
            cursorStateComputer = (_) -> null;
        }
        else if (Std.isOfType(endCursorState, Array)) {
            final selections:Array<Selection> = cast endCursorState;
            cursorStateComputer = (_) -> selections;
        }
        else {
            cursorStateComputer = cast endCursorState;
        }

        _viewModel.executeEdits(source, edits, cursorStateComputer);
        return true;
    }

    public function executeCommand(source:Null<String>, command:ICommand):Void {
        _viewModel.executeCommand(command, source);
    }

    public function executeCommands(source:Null<String>, commands:Array<Null<ICommand>>):Void {
        _viewModel.executeCommands(commands, source);
    }

    public function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T> {
        return _model.changeDecorations(callback);
    }

    // ---- withTestCodeEditor

    /**
     * vscode's `withTestCodeEditor`: `text` is a model, a string or an array
     * of lines (joined with `\n`). A model given is not disposed; a model
     * created here is. The editor has the focus.
     */
    public static function withTestCodeEditor(text:EitherType<TextModel, EitherType<String, Array<String>>>, options:Null<IEditorOptions>, callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void, ?context:Cityscape):Void {
        var model:TextModel;
        var ownModel = false;
        if (Std.isOfType(text, TextModel)) {
            model = cast text;
        }
        else {
            final ctx = context != null ? context : new Cityscape();
            final str:String = Std.isOfType(text, Array) ? (cast text : Array<String>).join('\n') : cast text;
            model = TestTextModel.instantiateTextModel(ctx, str);
            ownModel = true;
        }
        final ctx = context != null ? context : model.context;
        final editor = new TestCodeEditor(ctx, model, options != null ? options : {});
        final viewModel = editor.getViewModel();
        viewModel.setHasFocus(true);
        try {
            callback(editor, viewModel);
        }
        catch (e:Dynamic) {
            editor.dispose();
            if (ownModel) {
                model.dispose();
            }
            throw e;
        }
        editor.dispose();
        if (ownModel) {
            model.dispose();
        }
    }

}
