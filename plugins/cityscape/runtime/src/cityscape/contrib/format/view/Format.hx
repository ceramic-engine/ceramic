// Ported from vscode src/vs/editor/contrib/format/browser/formatActions.ts
// (FormatOnType), format.ts (getOnTypeFormattingEdits) and formattingEdit.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.format.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.services.EditorSimpleWorker;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;
import cityscape.view.StableEditorScroll;

/**
 * formattingEdit.ts: applies formatting edits to an editor, keeping the
 * cursor at its place on the screen.
 */
class FormattingEdit {

    static function _handleEolEdits(editor:ICodeEditor, edits:Array<TextEdit>):Array<TextEdit> {
        var newEol:Null<EndOfLineSequence> = null;
        final singleEdits:Array<TextEdit> = [];

        for (edit in edits) {
            if (edit.eol != null) {
                newEol = edit.eol;
            }
            if (edit.range != null && edit.text != null) {
                singleEdits.push(edit);
            }
        }

        if (newEol != null) {
            if (editor.hasModel()) {
                editor.getModel().pushEOL(newEol);
            }
        }

        return singleEdits;
    }

    static function _isFullModelReplaceEdit(editor:ICodeEditor, edit:TextEdit):Bool {
        if (!editor.hasModel()) {
            return false;
        }
        final model = editor.getModel();
        final editRange = model.validateRange(edit.range);
        final fullModelRange = model.getFullModelRange();
        return fullModelRange.equalsRange(editRange);
    }

    public static function execute(editor:ICodeEditor, _edits:Array<TextEdit>, addUndoStops:Bool):Void {
        if (addUndoStops) {
            editor.pushUndoStop();
        }
        final scrollState = StableEditorScrollState.capture(new FormatScrollStateEditor(editor));
        final edits = FormattingEdit._handleEolEdits(editor, _edits);
        if (edits.length == 1 && FormattingEdit._isFullModelReplaceEdit(editor, edits[0])) {
            // We use replace semantics and hope that markers stay put...
            editor.executeEdits('formatEditsCommand', [for (edit in edits) EditOperation.replace(Range.lift(edit.range), edit.text)]);
        } else {
            editor.executeEdits('formatEditsCommand', [for (edit in edits) EditOperation.replaceMove(Range.lift(edit.range), edit.text)]);
        }
        if (addUndoStops) {
            editor.pushUndoStop();
        }
        scrollState.restoreRelativeVerticalPositionOfCursor(new FormatScrollStateEditor(editor));
    }

}

/**
 * format.ts functions.
 */
class Format {

    /**
     * `getOnTypeFormattingEdits`: the edits of the first on type formatting
     * provider of the model when `ch` is one of its trigger characters,
     * made more minimal (Monaco's editor worker, run here on the model).
     * `callback` gets null when there is no provider or no edit.
     */
    public static function getOnTypeFormattingEdits(languageFeaturesService:LanguageFeaturesService, model:ITextModel, position:Position, ch:String, options:FormattingOptions, token:CancellationToken, callback:(edits:Null<Array<TextEdit>>) -> Void):Void {

        final providers = languageFeaturesService.onTypeFormattingEditProvider.ordered(model);

        if (providers.length == 0) {
            callback(null);
            return;
        }

        if (providers[0].autoFormatTriggerCharacters.indexOf(ch) < 0) {
            callback(null);
            return;
        }

        var called = false;
        try {
            providers[0].provideOnTypeFormattingEdits(model, position, ch, options, token, edits -> {
                if (called) {
                    return;
                }
                called = true;
                if (edits == null || model.isDisposed()) {
                    callback(edits);
                    return;
                }
                callback(EditorSimpleWorker.computeMoreMinimalEdits(model, edits, false));
            });
        } catch (e:Dynamic) {
            Errors.onUnexpectedExternalError(e);
            if (!called) {
                called = true;
                callback(null);
            }
        }
    }

}

/**
 * formatActions.ts `FormatOnType`: with the `formatOnType` option, typing
 * one of the trigger characters of the model's on type formatting provider
 * asks it for edits, applied unless the text before the position changed in
 * the meantime.
 */
class FormatOnType implements IEditorContribution {

    public static inline final ID = 'editor.contrib.autoFormat';

    final _disposables = new DisposableStore();
    final _sessionDisposables = new DisposableStore();

    final _editor:ICodeEditor;
    final _languageFeaturesService:LanguageFeaturesService;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this._languageFeaturesService = editor.context.languageFeaturesService;
        this._disposables.add(_languageFeaturesService.onTypeFormattingEditProvider.onDidChange(_ -> this._update()));
        this._disposables.add(_editor.onDidChangeModel(_ -> this._update()));
        this._disposables.add(_editor.onDidChangeModelLanguage(_ -> this._update()));
        this._disposables.add(_editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.formatOnType)) {
                this._update();
            }
        }));
        this._update();
    }

    public function dispose():Void {
        this._disposables.dispose();
        this._sessionDisposables.dispose();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    function _update():Void {

        // clean up
        this._sessionDisposables.clear();

        // we are disabled
        final enabled:Bool = this._editor.getOption(EditorOption.formatOnType);
        if (!enabled) {
            return;
        }

        // no model
        if (!this._editor.hasModel()) {
            return;
        }

        final model = this._editor.getModel();

        // no support
        final providers = this._languageFeaturesService.onTypeFormattingEditProvider.ordered(model);
        final support = providers.length > 0 ? providers[0] : null;
        if (support == null || support.autoFormatTriggerCharacters == null) {
            return;
        }

        // register typing listeners that will trigger the format
        final triggerChars = new Map<Int, Bool>();
        for (ch in support.autoFormatTriggerCharacters) {
            if (ch.length > 0) {
                triggerChars.set(StringTools.fastCodeAt(ch, 0), true);
            }
        }
        this._sessionDisposables.add(this._editor.onDidType(text -> {
            if (text.length == 0) {
                return;
            }
            final lastCharCode = StringTools.fastCodeAt(text, text.length - 1);
            if (triggerChars.exists(lastCharCode)) {
                this._trigger(String.fromCharCode(lastCharCode));
            }
        }));
    }

    function _trigger(ch:String):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        if (this._editor.getSelections().length > 1 || !this._editor.getSelection().isEmpty()) {
            return;
        }

        final model = this._editor.getModel();
        final position = this._editor.getPosition();
        final cts = new CancellationTokenSource();

        // install a listener that checks if edits happens before the
        // position on which we format right now. If so, we won't
        // apply the format edits
        var unbind:Null<IDisposable> = null;
        unbind = this._editor.onDidChangeModelContent(e -> {
            if (e.isFlush) {
                // a model.setValue() was called
                // cancel only once
                cts.cancel();
                unbind.dispose();
                return;
            }

            for (change in e.changes) {
                if (change.range.endLineNumber <= position.lineNumber) {
                    // cancel only once
                    cts.cancel();
                    unbind.dispose();
                    return;
                }
            }
        });

        Format.getOnTypeFormattingEdits(
            this._languageFeaturesService,
            model,
            position,
            ch,
            model.getFormattingOptions(),
            cts.token,
            edits -> {
                unbind.dispose();
                if (cts.token.isCancellationRequested) {
                    return;
                }
                if (edits != null && edits.length > 0) {
                    FormattingEdit.execute(this._editor, edits, true);
                }
            }
        );
    }

}

/**
 * An editor as `StableEditorScrollState` reads it.
 */
private class FormatScrollStateEditor implements IScrollStateEditor {

    final editor:ICodeEditor;

    public function new(editor:ICodeEditor) {
        this.editor = editor;
    }

    public function getScrollTop():Float {
        return editor.getScrollTop();
    }

    public function setScrollTop(newScrollTop:Float, ?scrollType:cityscape.common.EditorCommon.ScrollType):Void {
        editor.setScrollTop(newScrollTop, scrollType);
    }

    public function hasPendingScrollAnimation():Bool {
        return false;
    }

    public function getContentHeight():Float {
        return editor.getContentHeight();
    }

    public function getVisibleRanges():Array<Range> {
        return editor.getVisibleRanges();
    }

    public function getTopForLineNumber(lineNumber:Int):Float {
        return editor.getTopForLineNumber(lineNumber);
    }

    public function getTopForPosition(lineNumber:Int, column:Int):Float {
        return editor.getTopForPosition(lineNumber, column);
    }

    public function getPosition():Null<Position> {
        return editor.getPosition();
    }

}

/**
 * The registration of formatActions.ts (its module level code): the
 * `FormatOnType` contribution. The format document and format selection
 * actions and format on paste are not ported yet.
 */
class FormatRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(FormatOnType.ID, editor -> new FormatOnType(editor), EditorContributionInstantiation.BeforeFirstInteraction);
    }

}
