// Ported from vscode src/vs/editor/contrib/format/browser/formatActions.ts
// (FormatOnType, FormatDocumentAction, FormatSelectionAction), format.ts
// (getOnTypeFormattingEdits, the document and ranges formatting with a
// provider) and formattingEdit.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.format.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.DocumentFormattingEditProvider;
import cityscape.common.Languages.DocumentRangeFormattingEditProvider;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.services.EditorSimpleWorker;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.contrib.rename.view.Rename.CodeEditorStateFlag;
import cityscape.contrib.rename.view.Rename.EditorStateCancellationTokenSource;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
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
 * A range formatter used as a document formatter (format.ts,
 * `getRealAndSyntheticDocumentFormattersOrdered`): it formats the full
 * range of the model.
 */
private class RangeAsDocumentFormatter implements DocumentFormattingEditProvider {

    public var displayName(default, null):Null<String>;

    final _formatter:DocumentRangeFormattingEditProvider;

    public function new(formatter:DocumentRangeFormattingEditProvider) {
        this._formatter = formatter;
        this.displayName = formatter.displayName;
    }

    public function provideDocumentFormattingEdits(model:ITextModel, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void):Void {
        this._formatter.provideDocumentRangeFormattingEdits(model, model.getFullModelRange(), options, token, resolve);
    }

}

/**
 * format.ts: formatting a document or ranges of it with a provider, in an
 * editor. Monaco's selector of a formatter among several
 * (`FormattingConflicts`, set by the workbench) is not ported: the first
 * provider is the one, as in Monaco without a selector. The model-only
 * paths (no editor), the log and the accessibility signal are not ported.
 */
class FormatWithProvider {

    /**
     * `getRealAndSyntheticDocumentFormattersOrdered`: the document
     * formatters, then the range formatters as document formatters.
     * Monaco leaves out the range formatter of an extension that already
     * gave a document formatter; providers have no extension here.
     */
    public static function getRealAndSyntheticDocumentFormattersOrdered(languageFeaturesService:LanguageFeaturesService, model:ITextModel):Array<DocumentFormattingEditProvider> {
        final result:Array<DocumentFormattingEditProvider> = [];
        // (1) add all document formatter
        for (formatter in languageFeaturesService.documentFormattingEditProvider.ordered(model)) {
            result.push(formatter);
        }
        // (2) add all range formatter as document formatter
        for (formatter in languageFeaturesService.documentRangeFormattingEditProvider.ordered(model)) {
            result.push(new RangeAsDocumentFormatter(formatter));
        }
        return result;
    }

    /** `formatDocumentWithSelectedProvider`, for an editor. */
    public static function formatDocumentWithSelectedProvider(accessor:Cityscape, editor:ICodeEditor, token:CancellationToken):Void {
        if (!editor.hasModel()) {
            return;
        }
        final provider = getRealAndSyntheticDocumentFormattersOrdered(accessor.languageFeaturesService, editor.getModel());
        if (provider.length == 0) {
            return;
        }
        formatDocumentWithProvider(provider[0], editor, token);
    }

    /** `formatDocumentWithProvider`, for an editor, in the explicit mode (with undo stops and a reveal of the cursor). */
    public static function formatDocumentWithProvider(provider:DocumentFormattingEditProvider, editor:ICodeEditor, token:CancellationToken):Void {
        final model = editor.getModel();
        final cts = new EditorStateCancellationTokenSource(editor, CodeEditorStateFlag.Value | CodeEditorStateFlag.Position, null, token);
        var called = false;
        final done = (rawEdits:Null<Array<TextEdit>>) -> {
            if (called) {
                return;
            }
            called = true;
            final cancelled = cts.token.isCancellationRequested;
            cts.dispose();
            if (cancelled || rawEdits == null || model.isDisposed()) {
                return;
            }
            final edits = EditorSimpleWorker.computeMoreMinimalEdits(model, rawEdits, false);
            if (edits == null || edits.length == 0) {
                return;
            }
            // use editor to apply edits
            FormattingEdit.execute(editor, edits, true);
            editor.revealPositionInCenterIfOutsideViewport(editor.getPosition(), ScrollType.Immediate);
        };
        try {
            provider.provideDocumentFormattingEdits(model, model.getFormattingOptions(), cts.token, done);
        } catch (e:Dynamic) {
            Errors.onUnexpectedExternalError(e);
            done(null);
        }
    }

    /** `formatDocumentRangesWithSelectedProvider`, for an editor. */
    public static function formatDocumentRangesWithSelectedProvider(accessor:Cityscape, editor:ICodeEditor, ranges:Array<Range>, token:CancellationToken):Void {
        if (!editor.hasModel()) {
            return;
        }
        final provider = accessor.languageFeaturesService.documentRangeFormattingEditProvider.ordered(editor.getModel());
        if (provider.length == 0) {
            return;
        }
        formatDocumentRangesWithProvider(provider[0], editor, ranges, token);
    }

    /**
     * `formatDocumentRangesWithProvider`, for an editor. Monaco merges two
     * ranges whose edits intersect and asks again for the merged range;
     * here the edits of each range are asked one after the other and
     * applied together, and ranges whose edits intersect are left to the
     * provider that gave them (a provider with
     * `provideDocumentRangesFormattingEdits` gets all the ranges at once,
     * as in Monaco).
     */
    public static function formatDocumentRangesWithProvider(provider:DocumentRangeFormattingEditProvider, editor:ICodeEditor, rangeOrRanges:Array<Range>, token:CancellationToken):Void {
        final model = editor.getModel();
        final cts = new EditorStateCancellationTokenSource(editor, CodeEditorStateFlag.Value | CodeEditorStateFlag.Position, null, token);

        // make sure that ranges don't overlap nor touch each other
        final sorted = rangeOrRanges.copy();
        sorted.sort((a, b) -> Range.compareRangesUsingStarts(a, b));
        final ranges:Array<Range> = [];
        for (range in sorted) {
            final len = ranges.length;
            if (len > 0 && Range.areIntersectingOrTouching(ranges[len - 1], range)) {
                ranges[len - 1] = Range.fromPositions(ranges[len - 1].getStartPosition(), range.getEndPosition());
            } else {
                ranges.push(range);
            }
        }

        final allEdits:Array<TextEdit> = [];
        final finish = () -> {
            final cancelled = cts.token.isCancellationRequested;
            cts.dispose();
            if (cancelled || model.isDisposed() || allEdits.length == 0) {
                return;
            }
            // use editor to apply edits
            FormattingEdit.execute(editor, allEdits, true);
            editor.revealPositionInCenterIfOutsideViewport(editor.getPosition(), ScrollType.Immediate);
        };
        final collect = (rawEdits:Null<Array<TextEdit>>) -> {
            if (rawEdits == null || model.isDisposed()) {
                return;
            }
            final minimalEdits = EditorSimpleWorker.computeMoreMinimalEdits(model, rawEdits, false);
            if (minimalEdits != null) {
                for (edit in minimalEdits) {
                    allEdits.push(edit);
                }
            }
        };

        final all = provider.provideDocumentRangesFormattingEdits;
        if (all != null) {
            var called = false;
            try {
                all(model, ranges, model.getFormattingOptions(), cts.token, rawEdits -> {
                    if (called) {
                        return;
                    }
                    called = true;
                    collect(rawEdits);
                    finish();
                });
            } catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                if (!called) {
                    called = true;
                    finish();
                }
            }
            return;
        }

        var index = 0;
        var next:() -> Void = () -> {};
        next = () -> {
            if (index >= ranges.length || cts.token.isCancellationRequested) {
                finish();
                return;
            }
            final range = ranges[index++];
            var called = false;
            try {
                provider.provideDocumentRangeFormattingEdits(model, range, model.getFormattingOptions(), cts.token, rawEdits -> {
                    if (called) {
                        return;
                    }
                    called = true;
                    collect(rawEdits);
                    next();
                });
            } catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                if (!called) {
                    called = true;
                    next();
                }
            }
        };
        next();
    }

}

/**
 * `editor.action.formatDocument` (Shift+Alt+F, Ctrl+Shift+I on Linux):
 * Format Document. Monaco's progress indication is not ported.
 */
class FormatDocumentAction extends EditorAction {

    public static inline final ID = 'editor.action.formatDocument';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('formatDocument.label', "Format Document"),
            alias: 'Format Document',
            precondition: ContextKeyExpr.and(EditorContextKeys.notInCompositeEditor, EditorContextKeys.writable, EditorContextKeys.hasDocumentFormattingProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyMod.Alt | KeyCode.KeyF,
                linux: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyI},
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {
                group: '1_modification',
                order: 1.3
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (editor.hasModel() && accessor != null) {
            FormatWithProvider.formatDocumentWithSelectedProvider(accessor, editor, CancellationTokens.None);
        }
    }

}

/**
 * `editor.action.formatSelection` (Ctrl/Cmd+K Ctrl/Cmd+F): Format
 * Selection. An empty selection formats its line.
 */
class FormatSelectionAction extends EditorAction {

    public static inline final ID = 'editor.action.formatSelection';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('formatSelection.label', "Format Selection"),
            alias: 'Format Selection',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasDocumentSelectionFormattingProvider),
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyF),
                weight: KeybindingWeight.EditorContrib
            },
            contextMenuOpts: {
                when: EditorContextKeys.hasNonEmptySelection,
                group: '1_modification',
                order: 1.31
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel() || accessor == null) {
            return;
        }
        final model = editor.getModel();

        final ranges:Array<Range> = [for (range in editor.getSelections())
            range.isEmpty()
                ? new Range(range.startLineNumber, 1, range.startLineNumber, model.getLineMaxColumn(range.startLineNumber))
                : (range : Range)
        ];

        FormatWithProvider.formatDocumentRangesWithSelectedProvider(accessor, editor, ranges, CancellationTokens.None);
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
 * `FormatOnType` contribution, the format document and format selection
 * actions. Format on paste and the old `editor.action.format` command are
 * not ported yet.
 */
class FormatRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(FormatOnType.ID, editor -> new FormatOnType(editor), EditorContributionInstantiation.BeforeFirstInteraction);
        r.registerEditorAction(new FormatDocumentAction(r));
        r.registerEditorAction(new FormatSelectionAction(r));
    }

}
