// Ported from vscode src/vs/editor/browser/observableCodeEditor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.observableInternal.Base;
import cityscape.base.common.observableInternal.Utils.ObservableSignal;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Selection;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * A facade for the code editor that provides observables for various
 * states and events (Monaco's `ObservableCodeEditor`, the part the inline
 * completions use: model, read only, version id, selections, typed text).
 *
 * Monaco keeps one instance per editor in a static map
 * (`observableCodeEditor(editor)`); here the owner creates it and disposes
 * it (no editor state in statics). The begin and end of the editor's updates
 * (`onBeginUpdate`, `onEndUpdate`) come from the `CodeEditorWidget` when the
 * editor is one (they are not part of `ICodeEditor` here).
 */
class ObservableCodeEditor extends Disposable {

    var _updateCounter:Int = 0;
    var _currentTransaction:Null<TransactionImpl> = null;

    public final editor:ICodeEditor;

    final _model:ISettableObservable<Null<ITextModel>>;
    public final model:IObservable<Null<ITextModel>>;

    public final isReadonly:IObservable<Bool>;

    final _versionId:ISettableObservable<Null<Int>>;
    /**
     * The version of the model; the change is the
     * `IModelContentChangedEvent` (null when forced).
     */
    public final versionId:IObservable<Null<Int>>;

    final _selections:ISettableObservable<Null<Array<Selection>>>;
    /**
     * The selections; the change is the `ICursorSelectionChangedEvent`
     * (null when forced).
     */
    public final selections:IObservable<Null<Array<Selection>>>;

    /**
     * Triggered with the typed text as change.
     */
    public final onDidType:ObservableSignal;

    function _beginUpdate():Void {
        this._updateCounter++;
        if (this._updateCounter == 1) {
            this._currentTransaction = new TransactionImpl();
        }
    }

    function _endUpdate():Void {
        this._updateCounter--;
        if (this._updateCounter == 0) {
            final t = this._currentTransaction;
            this._currentTransaction = null;
            t.finish();
        }
    }

    public function new(editor:ICodeEditor) {
        super();
        this.editor = editor;

        this._model = Observable.observableValue('model', editor.getModel());
        this.model = this._model;
        this.isReadonly = Observable.observableFromEvent(cb -> this.editor.onDidChangeConfiguration(_ -> cb()), () -> this.editor.getOption(EditorOption.readOnly));
        final model = this.editor.getModel();
        this._versionId = Observable.observableValue('versionId', model != null ? (model.getVersionId() : Null<Int>) : null);
        this.versionId = this._versionId;
        this._selections = Observable.observableValueOpts('selections', selectionsEquals, this.editor.getSelections());
        this.selections = this._selections;
        this.onDidType = Observable.observableSignal('onDidType');

        final widget = Std.downcast(editor, cityscape.view.widget.codeEditor.CodeEditorWidget);
        if (widget != null) {
            this._register(widget.onBeginUpdate(() -> this._beginUpdate()));
            this._register(widget.onEndUpdate(() -> this._endUpdate()));
        }

        this._register(this.editor.onDidChangeModel(_ -> {
            this._beginUpdate();
            this._model.set(this.editor.getModel(), this._currentTransaction);
            this._forceUpdate();
            this._endUpdate();
        }));

        this._register(this.editor.onDidType(e -> {
            this._beginUpdate();
            this._forceUpdate();
            this.onDidType.trigger(this._currentTransaction, e);
            this._endUpdate();
        }));

        this._register(this.editor.onDidChangeModelContent(e -> {
            this._beginUpdate();
            final model = this.editor.getModel();
            this._versionId.set(model != null ? (model.getVersionId() : Null<Int>) : null, this._currentTransaction, e);
            this._forceUpdate();
            this._endUpdate();
        }));

        this._register(this.editor.onDidChangeCursorSelection(e -> {
            this._beginUpdate();
            this._selections.set(this.editor.getSelections(), this._currentTransaction, e);
            this._forceUpdate();
            this._endUpdate();
        }));
    }

    /**
     * Updates the observables from the editor, then runs `cb` (if given) in
     * the transaction of the update.
     */
    public function forceUpdate(?cb:(tx:ITransaction) -> Void):Void {
        this._beginUpdate();
        this._forceUpdate();
        if (cb != null) {
            cb(this._currentTransaction);
        }
        this._endUpdate();
    }

    function _forceUpdate():Void {
        this._beginUpdate();
        this._model.set(this.editor.getModel(), this._currentTransaction);
        final model = this.editor.getModel();
        this._versionId.set(model != null ? (model.getVersionId() : Null<Int>) : null, this._currentTransaction, null);
        this._selections.set(this.editor.getSelections(), this._currentTransaction, null);
        this._endUpdate();
    }

    /**
     * Calls `cb` with the value and the changes (non null) each time
     * `observable` changes, not initially (Monaco's `reactToChange`).
     */
    public static function reactToChange<T>(observable:IObservable<T>, cb:(value:T, deltas:Array<Any>) -> Void):IDisposable {
        return Observable.autorunHandleChanges({
            createEmptyChangeSummary: () -> new ReactToChangeSummary(),
            handleChange: (context, changeSummary:ReactToChangeSummary) -> {
                if (context.didChange(observable)) {
                    final e = context.change;
                    if (e != null) {
                        changeSummary.deltas.push(e);
                    }
                    changeSummary.didChange = true;
                }
                return true;
            },
        }, (reader, changeSummary:ReactToChangeSummary) -> {
            final value = observable.read(reader);
            if (changeSummary.didChange) {
                cb(value, changeSummary.deltas);
            }
        });
    }

    /**
     * `equalsIfDefined(itemsEquals(Selection.selectionsEqual))`.
     */
    static function selectionsEquals(a:Null<Array<Selection>>, b:Null<Array<Selection>>):Bool {
        if (a == null || b == null) {
            return a == b;
        }
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!Selection.selectionsEqual(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

}

private class ReactToChangeSummary {

    public final deltas:Array<Any> = [];
    public var didChange:Bool = false;

    public function new() {}

}
