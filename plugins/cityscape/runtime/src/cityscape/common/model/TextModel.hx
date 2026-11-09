// Ported from vscode src/vs/editor/common/model/textModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.Cityscape;
import cityscape.base.common.Arrays;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Strings;
import cityscape.base.common.Uri;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Model;
import cityscape.common.TextModelBracketPairs.IBracketPairsTextModelPart;
import cityscape.common.TextModelEvents;
import cityscape.common.TextModelGuides.IGuidesTextModelPart;
import cityscape.common.TokenizationTextModelPart.ITokenizationTextModelPart;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.EolCounter;
import cityscape.common.core.Indentation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.TextChange;
import cityscape.common.core.TextModelDefaults;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.common.languages.Language.ILanguageSelection;
import cityscape.common.model.IntervalTree;
import cityscape.common.model.Tokens.AttachedViews;
import cityscape.common.model.bracketPairsTextModelPart.BracketPairsImpl.BracketPairsTextModelPart;
import cityscape.common.model.bracketPairsTextModelPart.ColorizedBracketPairsDecorationProvider;
import cityscape.common.model.TextModelSearch;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBuffer;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeTextBufferBuilder;
import cityscape.platform.undoRedo.common.UndoRedo;
import cityscape.platform.undoRedo.common.UndoRedoService;
import haxe.extern.EitherType;

private enum abstract StringOffsetValidationType(Int) from Int to Int {
    /**
     * Even allowed in surrogate pairs
     */
    var Relaxed = 0;
    /**
     * Not allowed in surrogate pairs
     */
    var SurrogatePairs = 1;
}

class TextModelSnapshot implements ITextSnapshot {

    final _source:ITextSnapshot;

    var _eos:Bool;

    public function new(source:ITextSnapshot) {
        this._source = source;
        this._eos = false;
    }

    public function read():Null<String> {
        if (this._eos) {
            return null;
        }

        final result:Array<String> = [];
        var resultCnt = 0;
        var resultLength = 0;

        do {
            final tmp = this._source.read();

            if (tmp == null) {
                // end-of-stream
                this._eos = true;
                if (resultCnt == 0) {
                    return null;
                }
                else {
                    return result.join('');
                }
            }

            if (tmp.length > 0) {
                result[resultCnt++] = tmp;
                resultLength += tmp.length;
            }

            if (resultLength >= 64 * 1024) {
                return result.join('');
            }
        } while (true);
    }

}

/**
 * Monaco's `IDecorationsTreesHost`.
 */
interface IDecorationsTreesHost {
    function getVersionId():Int;
    function getRangeAt(start:Int, end:Int):Range;
}

/**
 * The text model.
 *
 * Monaco's constructor takes its services by dependency injection
 * (`IUndoRedoService`, `ILanguageService`, `ILanguageConfigurationService`,
 * `IInstantiationService`); here they come from the `Cityscape` context
 * given to the constructor (`Cityscape.defaultContext` when none).
 *
 */
class TextModel extends Disposable implements ITextModel implements IDecorationsTreesHost {

    static var MODEL_ID:Int = 0;

    static inline final LIMIT_FIND_COUNT = 999;

    static inline final LONG_LINE_BOUNDARY = 10000;

    /**
     * Used in tests.
     */
    public static var _MODEL_SYNC_LIMIT:Int = 50 * 1024 * 1024; // 50 MB

    static inline final LARGE_FILE_SIZE_THRESHOLD = 20 * 1024 * 1024; // 20 MB;

    static inline final LARGE_FILE_LINE_COUNT_THRESHOLD = 300 * 1000; // 300K lines

    static inline final LARGE_FILE_HEAP_OPERATION_THRESHOLD = 256 * 1024 * 1024; // 256M characters, usually ~> 512MB memory usage

    public static final DEFAULT_CREATION_OPTIONS:ITextModelCreationOptions = {
        isForSimpleWidget: false,
        tabSize: TextModelDefaults.EDITOR_MODEL_DEFAULTS.tabSize,
        indentSize: TextModelDefaults.EDITOR_MODEL_DEFAULTS.indentSize,
        insertSpaces: TextModelDefaults.EDITOR_MODEL_DEFAULTS.insertSpaces,
        detectIndentation: false,
        defaultEOL: DefaultEndOfLine.LF,
        trimAutoWhitespace: TextModelDefaults.EDITOR_MODEL_DEFAULTS.trimAutoWhitespace,
        largeFileOptimizations: TextModelDefaults.EDITOR_MODEL_DEFAULTS.largeFileOptimizations,
        bracketPairColorizationOptions: TextModelDefaults.EDITOR_MODEL_DEFAULTS.bracketPairColorizationOptions,
    };

    // #region module functions

    public static function createTextBufferFactory(text:String):ITextBufferFactory {
        final builder = new PieceTreeTextBufferBuilder();
        builder.acceptChunk(text);
        return builder.finish();
    }

    public static function createTextBufferFactoryFromSnapshot(snapshot:ITextSnapshot):ITextBufferFactory {
        final builder = new PieceTreeTextBufferBuilder();

        var chunk:Null<String>;
        while ((chunk = snapshot.read()) != null) {
            builder.acceptChunk(chunk);
        }

        return builder.finish();
    }

    /**
     * `value` is a string, an `ITextBufferFactory` or an `ITextSnapshot`.
     */
    public static function createTextBuffer(value:Any, defaultEOL:DefaultEndOfLine):{textBuffer:ITextBuffer, disposable:IDisposable} {
        var factory:ITextBufferFactory;
        if (Std.isOfType(value, String)) {
            factory = createTextBufferFactory(value);
        }
        else if (Std.isOfType(value, ITextSnapshot)) {
            factory = createTextBufferFactoryFromSnapshot(value);
        }
        else {
            factory = value;
        }
        return factory.create(defaultEOL);
    }

    public static function indentOfLine(line:String):Int {
        var indent = 0;
        for (i in 0...line.length) {
            final c = StringTools.fastCodeAt(line, i);
            if (c == ' '.code || c == '\t'.code) {
                indent++;
            }
            else {
                break;
            }
        }
        return indent;
    }

    // #endregion

    public static function resolveOptions(textBuffer:ITextBuffer, options:ITextModelCreationOptions):TextModelResolvedOptions {
        if (options.detectIndentation) {
            final guessedIndentation = IndentationGuesser.guessIndentation(textBuffer, options.tabSize, options.insertSpaces);
            return new TextModelResolvedOptions({
                tabSize: guessedIndentation.tabSize,
                indentSize: 'tabSize', // TODO@Alex: guess indentSize independent of tabSize
                insertSpaces: guessedIndentation.insertSpaces,
                trimAutoWhitespace: options.trimAutoWhitespace,
                defaultEOL: options.defaultEOL,
                bracketPairColorizationOptions: options.bracketPairColorizationOptions,
            });
        }

        return new TextModelResolvedOptions(options);
    }

    //#region Events

    final _onWillDispose:VoidEmitter;

    public final onWillDispose:VoidEvent;

    final _onDidChangeDecorations:DidChangeDecorationsEmitter;

    public final onDidChangeDecorations:Event<IModelDecorationsChangedEvent>;

    public final onDidChangeLanguage:Event<IModelLanguageChangedEvent>;

    public final onDidChangeLanguageConfiguration:Event<IModelLanguageConfigurationChangedEvent>;

    public final onDidChangeTokens:Event<IModelTokensChangedEvent>;

    final _onDidChangeOptions:Emitter<IModelOptionsChangedEvent>;

    public final onDidChangeOptions:Event<IModelOptionsChangedEvent>;

    final _onDidChangeAttached:VoidEmitter;

    public final onDidChangeAttached:VoidEvent;

    final _onDidChangeInjectedText:Emitter<ModelInjectedTextChangedEvent>;

    final _eventEmitter:DidChangeContentEmitter;

    public function onDidChangeContent(listener:(e:IModelContentChangedEvent) -> Void):IDisposable {
        return this._eventEmitter.slowEvent((e:InternalModelContentChangeEvent) -> listener(e.contentChangedEvent));
    }

    public final onDidChangeContentOrInjectedText:Event<ModelContentOrInjectedTextChangedEvent>;

    //#endregion

    public final id:String;

    public final isForSimpleWidget:Bool;

    public final uri:Uri;

    final _associatedResource:Uri;

    var _attachedEditorCount:Int;

    var _buffer:ITextBuffer;

    var _bufferDisposable:IDisposable;

    var _options:TextModelResolvedOptions;

    final _languageSelectionListener:MutableDisposable<IDisposable>;

    var _isDisposed:Bool;

    var __isDisposing:Bool;

    public function _isDisposing():Bool {
        return this.__isDisposing;
    }

    var _versionId:Int;

    /**
     * Unlike, versionId, this can go down (via undo) or go to previous values (via redo)
     */
    var _alternativeVersionId:Int;

    var _initialUndoRedoSnapshot:Null<ResourceEditStackSnapshot>;

    final _isTooLargeForSyncing:Bool;

    final _isTooLargeForTokenization:Bool;

    final _isTooLargeForHeapOperation:Bool;

    //#region Editing

    final _undoRedoService:UndoRedoService;

    final _commandManager:EditStack;

    var _isUndoing:Bool;

    var _isRedoing:Bool;

    var _trimAutoWhitespaceLines:Null<Array<Int>>;

    //#endregion

    //#region Decorations

    /**
     * Used to workaround broken clients that might attempt using a decoration id generated by a different model.
     * It is not globally unique in order to limit it to one character.
     */
    final _instanceId:String;

    var _deltaDecorationCallCnt:Int = 0;

    var _lastDecorationId:Int;

    var _decorations:Map<String, IntervalNode>;

    var _decorationsTree:DecorationsTrees;

    //#endregion

    final _tokenizationTextModelPart:TokenizationTextModelPart;

    public final tokenization:ITokenizationTextModelPart;

    final _bracketPairs:BracketPairsTextModelPart;

    final _decorationProvider:ColorizedBracketPairsDecorationProvider;

    public final bracketPairs:IBracketPairsTextModelPart;

    final _guidesTextModelPart:GuidesTextModelPart;

    public final guides:IGuidesTextModelPart;

    final _attachedViews:AttachedViews = new AttachedViews();

    /**
     * The context of the services of this model.
     */
    public final context:Cityscape;

    /**
     * @param source the text, or an `ITextBufferFactory`.
     * @param languageIdOrSelection a language id or an `ILanguageSelection`.
     * @param context the services (undo/redo, languages); `Cityscape.defaultContext` when null.
     */
    public function new(source:EitherType<String, ITextBufferFactory>, languageIdOrSelection:EitherType<String, ILanguageSelection>, creationOptions:ITextModelCreationOptions, ?associatedResource:Uri, ?context:Cityscape) {
        super();

        this.context = (context != null ? context : Cityscape.defaultContext);
        this._undoRedoService = this.context.undoRedoService;

        this._onWillDispose = this._register(new VoidEmitter());
        this.onWillDispose = this._onWillDispose.event;
        this._onDidChangeDecorations = this._register(new DidChangeDecorationsEmitter(affectedInjectedTextLines -> this.handleBeforeFireDecorationsChangedEvent(affectedInjectedTextLines)));
        this.onDidChangeDecorations = this._onDidChangeDecorations.event;
        this._onDidChangeOptions = this._register(new Emitter<IModelOptionsChangedEvent>());
        this.onDidChangeOptions = this._onDidChangeOptions.event;
        this._onDidChangeAttached = this._register(new VoidEmitter());
        this.onDidChangeAttached = this._onDidChangeAttached.event;
        this._onDidChangeInjectedText = this._register(new Emitter<ModelInjectedTextChangedEvent>());
        this._eventEmitter = this._register(new DidChangeContentEmitter());
        this.onDidChangeContentOrInjectedText = (listener:(e:ModelContentOrInjectedTextChangedEvent) -> Void) -> {
            return Lifecycle.combinedDisposable([
                this._eventEmitter.fastEvent(e -> listener(e)),
                this._onDidChangeInjectedText.event(e -> listener(e))
            ]);
        };
        this._languageSelectionListener = this._register(new MutableDisposable<IDisposable>());

        // Generate a new unique model id
        MODEL_ID++;
        this.id = '$$model' + MODEL_ID;
        this.isForSimpleWidget = creationOptions.isForSimpleWidget;
        if (associatedResource == null) {
            this._associatedResource = Uri.parse('inmemory://model/' + MODEL_ID);
        }
        else {
            this._associatedResource = associatedResource;
        }
        this.uri = this._associatedResource;
        this._attachedEditorCount = 0;

        final created = createTextBuffer(source, creationOptions.defaultEOL);
        this._buffer = created.textBuffer;
        this._bufferDisposable = created.disposable;

        this._options = TextModel.resolveOptions(this._buffer, creationOptions);

        final languageId:String = Std.isOfType(languageIdOrSelection, String) ? (cast languageIdOrSelection : String) : (cast languageIdOrSelection : ILanguageSelection).languageId;
        if (!Std.isOfType(languageIdOrSelection, String)) {
            final selection:ILanguageSelection = cast languageIdOrSelection;
            this._languageSelectionListener.value = selection.onDidChange(_ -> this._setLanguage(selection.languageId));
        }

        this._bracketPairs = this._register(new BracketPairsTextModelPart(this, this.context.languageConfigurationService));
        this.bracketPairs = this._bracketPairs;
        this._guidesTextModelPart = this._register(new GuidesTextModelPart(this));
        this.guides = this._guidesTextModelPart;
        this._decorationProvider = this._register(new ColorizedBracketPairsDecorationProvider(this));
        this._tokenizationTextModelPart = new TokenizationTextModelPart(this, this._bracketPairs, languageId, this._attachedViews, this.context);
        this.tokenization = this._tokenizationTextModelPart;
        this.onDidChangeLanguage = this._tokenizationTextModelPart.onDidChangeLanguage;
        this.onDidChangeLanguageConfiguration = this._tokenizationTextModelPart.onDidChangeLanguageConfiguration;
        this.onDidChangeTokens = this._tokenizationTextModelPart.onDidChangeTokens;

        final bufferLineCount = this._buffer.getLineCount();
        final bufferTextLength = this._buffer.getValueLengthInRange(new Range(1, 1, bufferLineCount, this._buffer.getLineLength(bufferLineCount) + 1), EndOfLinePreference.TextDefined);

        // !!! Make a decision in the ctor and permanently respect this decision !!!
        // If a model is too large at construction time, it will never get tokenized,
        // under no circumstances.
        if (creationOptions.largeFileOptimizations) {
            this._isTooLargeForTokenization = (
                (bufferTextLength > LARGE_FILE_SIZE_THRESHOLD)
                || (bufferLineCount > LARGE_FILE_LINE_COUNT_THRESHOLD)
            );

            this._isTooLargeForHeapOperation = bufferTextLength > LARGE_FILE_HEAP_OPERATION_THRESHOLD;
        }
        else {
            this._isTooLargeForTokenization = false;
            this._isTooLargeForHeapOperation = false;
        }

        this._isTooLargeForSyncing = (bufferTextLength > TextModel._MODEL_SYNC_LIMIT);

        this._versionId = 1;
        this._alternativeVersionId = 1;
        this._initialUndoRedoSnapshot = null;

        this._isDisposed = false;
        this.__isDisposing = false;

        this._instanceId = Strings.singleLetterHash(MODEL_ID);
        this._lastDecorationId = 0;
        this._decorations = new Map<String, IntervalNode>();
        this._decorationsTree = new DecorationsTrees();

        this._commandManager = new EditStack(this, this._undoRedoService);
        this._isUndoing = false;
        this._isRedoing = false;
        this._trimAutoWhitespaceLines = null;

        this._register(this._decorationProvider.onDidChange(() -> {
            this._onDidChangeDecorations.beginDeferredEmit();
            this._onDidChangeDecorations.fire();
            this._onDidChangeDecorations.endDeferredEmit();
        }));

        this.context.languageService.requestRichLanguageFeatures(languageId);

        this._register(this.context.languageConfigurationService.onDidChange(e -> {
            this._bracketPairs.handleLanguageConfigurationServiceChange(e);
            this._tokenizationTextModelPart.handleLanguageConfigurationServiceChange(e);
        }));
    }

    override public function dispose():Void {
        this.__isDisposing = true;
        this._onWillDispose.fire();
        this._tokenizationTextModelPart.dispose();
        this._isDisposed = true;
        super.dispose();
        this._bufferDisposable.dispose();
        this.__isDisposing = false;
        // Manually release reference to previous text buffer to avoid large leaks
        // in case someone leaks a TextModel reference
        final emptyDisposedTextBuffer = new PieceTreeTextBuffer([], '', '\n', false, false, true, true);
        emptyDisposedTextBuffer.dispose();
        this._buffer = emptyDisposedTextBuffer;
        this._bufferDisposable = Lifecycle.NONE_DISPOSABLE;
    }

    public function _hasListeners():Bool {
        return (
            this._onWillDispose.hasListeners()
            || this._onDidChangeDecorations.hasListeners()
            || this._tokenizationTextModelPart._hasListeners()
            || this._onDidChangeOptions.hasListeners()
            || this._onDidChangeAttached.hasListeners()
            || this._onDidChangeInjectedText.hasListeners()
            || this._eventEmitter.hasListeners()
        );
    }

    inline function _assertNotDisposed():Void {
        if (this._isDisposed) {
            throw new BugIndicatingError('Model is disposed!');
        }
    }

    public function equalsTextBuffer(other:ITextBuffer):Bool {
        this._assertNotDisposed();
        return this._buffer.equals(other);
    }

    public function getTextBuffer():ITextBuffer {
        this._assertNotDisposed();
        return this._buffer;
    }

    function _emitContentChangedEvent(rawChange:ModelRawContentChangedEvent, change:IModelContentChangedEvent):Void {
        if (this.__isDisposing) {
            // Do not confuse listeners by emitting any event after disposing
            return;
        }
        this._tokenizationTextModelPart.handleDidChangeContent(change);
        this._bracketPairs.handleDidChangeContent(change);
        this._eventEmitter.fire(new InternalModelContentChangeEvent(rawChange, change));
    }

    public function setValue(value:TextModelValue):Void {
        this._assertNotDisposed();

        if (value == null) {
            throw 'Illegal argument';
        }

        final created = createTextBuffer(value, this._options.defaultEOL);
        this._setValueFromTextBuffer(created.textBuffer, created.disposable);
    }

    function _createContentChanged2(range:Range, rangeOffset:Int, rangeLength:Int, text:String, isUndoing:Bool, isRedoing:Bool, isFlush:Bool, isEolChange:Bool):IModelContentChangedEvent {
        return {
            changes: [{
                range: range,
                rangeOffset: rangeOffset,
                rangeLength: rangeLength,
                text: text,
            }],
            eol: this._buffer.getEOL(),
            isEolChange: isEolChange,
            versionId: this.getVersionId(),
            isUndoing: isUndoing,
            isRedoing: isRedoing,
            isFlush: isFlush
        };
    }

    function _setValueFromTextBuffer(textBuffer:ITextBuffer, textBufferDisposable:IDisposable):Void {
        this._assertNotDisposed();
        final oldFullModelRange = this.getFullModelRange();
        final oldModelValueLength = this.getValueLengthInRange(oldFullModelRange);
        final endLineNumber = this.getLineCount();
        final endColumn = this.getLineMaxColumn(endLineNumber);

        this._buffer = textBuffer;
        this._bufferDisposable.dispose();
        this._bufferDisposable = textBufferDisposable;
        this._increaseVersionId();

        // Destroy all my decorations
        this._decorations = new Map<String, IntervalNode>();
        this._decorationsTree = new DecorationsTrees();

        // Destroy my edit history and settings
        this._commandManager.clear();
        this._trimAutoWhitespaceLines = null;

        this._emitContentChangedEvent(
            new ModelRawContentChangedEvent(
                [
                    new ModelRawFlush()
                ],
                this._versionId,
                false,
                false
            ),
            this._createContentChanged2(new Range(1, 1, endLineNumber, endColumn), 0, oldModelValueLength, this.getValue(), false, false, true, false)
        );
    }

    public function setEOL(eol:EndOfLineSequence):Void {
        this._assertNotDisposed();
        final newEOL = (eol == EndOfLineSequence.CRLF ? '\r\n' : '\n');
        if (this._buffer.getEOL() == newEOL) {
            // Nothing to do
            return;
        }

        final oldFullModelRange = this.getFullModelRange();
        final oldModelValueLength = this.getValueLengthInRange(oldFullModelRange);
        final endLineNumber = this.getLineCount();
        final endColumn = this.getLineMaxColumn(endLineNumber);

        this._onBeforeEOLChange();
        this._buffer.setEOL(newEOL);
        this._increaseVersionId();
        this._onAfterEOLChange();

        this._emitContentChangedEvent(
            new ModelRawContentChangedEvent(
                [
                    new ModelRawEOLChanged()
                ],
                this._versionId,
                false,
                false
            ),
            this._createContentChanged2(new Range(1, 1, endLineNumber, endColumn), 0, oldModelValueLength, this.getValue(), false, false, false, true)
        );
    }

    function _onBeforeEOLChange():Void {
        // Ensure all decorations get their `range` set.
        this._decorationsTree.ensureAllNodesHaveRanges(this);
    }

    function _onAfterEOLChange():Void {
        // Transform back `range` to offsets
        final versionId = this.getVersionId();
        this._decorationsTree.forEachNodePostOrder((tree, node) -> {
            final range = node.range; // the range is defined due to `_onBeforeEOLChange`

            final delta = node.cachedAbsoluteStart - node.start;

            final startOffset = this._buffer.getOffsetAt(range.startLineNumber, range.startColumn);
            final endOffset = this._buffer.getOffsetAt(range.endLineNumber, range.endColumn);

            node.cachedAbsoluteStart = startOffset;
            node.cachedAbsoluteEnd = endOffset;
            node.cachedVersionId = versionId;

            node.start = startOffset - delta;
            node.end = endOffset - delta;

            IntervalTree.recomputeMaxEnd(tree, node);
        });
    }

    public function onBeforeAttached():IAttachedView {
        this._attachedEditorCount++;
        if (this._attachedEditorCount == 1) {
            this._tokenizationTextModelPart.handleDidChangeAttached();
            this._onDidChangeAttached.fire();
        }
        return this._attachedViews.attachView();
    }

    public function onBeforeDetached(view:IAttachedView):Void {
        this._attachedEditorCount--;
        if (this._attachedEditorCount == 0) {
            this._tokenizationTextModelPart.handleDidChangeAttached();
            this._onDidChangeAttached.fire();
        }
        this._attachedViews.detachView(view);
    }

    public function isAttachedToEditor():Bool {
        return this._attachedEditorCount > 0;
    }

    public function getAttachedEditorCount():Int {
        return this._attachedEditorCount;
    }

    public function isTooLargeForSyncing():Bool {
        return this._isTooLargeForSyncing;
    }

    public function isTooLargeForTokenization():Bool {
        return this._isTooLargeForTokenization;
    }

    public function isTooLargeForHeapOperation():Bool {
        return this._isTooLargeForHeapOperation;
    }

    public function isDisposed():Bool {
        return this._isDisposed;
    }

    public function isDominatedByLongLines():Bool {
        this._assertNotDisposed();
        if (this.isTooLargeForTokenization()) {
            // Cannot word wrap huge files anyways, so it doesn't really matter
            return false;
        }
        var smallLineCharCount = 0;
        var longLineCharCount = 0;

        final lineCount = this._buffer.getLineCount();
        for (lineNumber in 1...lineCount + 1) {
            final lineLength = this._buffer.getLineLength(lineNumber);
            if (lineLength >= LONG_LINE_BOUNDARY) {
                longLineCharCount += lineLength;
            }
            else {
                smallLineCharCount += lineLength;
            }
        }

        return (longLineCharCount > smallLineCharCount);
    }

    //#region Options

    public function getOptions():TextModelResolvedOptions {
        this._assertNotDisposed();
        return this._options;
    }

    public function getFormattingOptions():FormattingOptions {
        return {
            tabSize: this._options.indentSize,
            insertSpaces: this._options.insertSpaces
        };
    }

    public function updateOptions(_newOpts:ITextModelUpdateOptions):Void {
        this._assertNotDisposed();
        final tabSize = (_newOpts.tabSize != null) ? _newOpts.tabSize : this._options.tabSize;
        final indentSize:IndentSize = (_newOpts.indentSize != null) ? _newOpts.indentSize : this._options.originalIndentSize;
        final insertSpaces = (_newOpts.insertSpaces != null) ? _newOpts.insertSpaces : this._options.insertSpaces;
        final trimAutoWhitespace = (_newOpts.trimAutoWhitespace != null) ? _newOpts.trimAutoWhitespace : this._options.trimAutoWhitespace;
        final bracketPairColorizationOptions = (_newOpts.bracketColorizationOptions != null) ? _newOpts.bracketColorizationOptions : this._options.bracketPairColorizationOptions;

        final newOpts = new TextModelResolvedOptions({
            tabSize: tabSize,
            indentSize: indentSize,
            insertSpaces: insertSpaces,
            defaultEOL: this._options.defaultEOL,
            trimAutoWhitespace: trimAutoWhitespace,
            bracketPairColorizationOptions: bracketPairColorizationOptions,
        });

        if (this._options.equals(newOpts)) {
            return;
        }

        final e = this._options.createChangeEvent(newOpts);
        this._options = newOpts;

        this._bracketPairs.handleDidChangeOptions(e);
        this._decorationProvider.handleDidChangeOptions(e);
        this._onDidChangeOptions.fire(e);
    }

    public function detectIndentation(defaultInsertSpaces:Bool, defaultTabSize:Int):Void {
        this._assertNotDisposed();
        final guessedIndentation = IndentationGuesser.guessIndentation(this._buffer, defaultTabSize, defaultInsertSpaces);
        this.updateOptions({
            insertSpaces: guessedIndentation.insertSpaces,
            tabSize: guessedIndentation.tabSize,
            indentSize: guessedIndentation.tabSize, // TODO@Alex: guess indentSize independent of tabSize
        });
    }

    public function normalizeIndentation(str:String):String {
        this._assertNotDisposed();
        return Indentation.normalizeIndentation(str, this._options.indentSize, this._options.insertSpaces);
    }

    //#endregion

    //#region Reading

    public function getVersionId():Int {
        this._assertNotDisposed();
        return this._versionId;
    }

    public function mightContainRTL():Bool {
        return this._buffer.mightContainRTL();
    }

    public function mightContainUnusualLineTerminators():Bool {
        return this._buffer.mightContainUnusualLineTerminators();
    }

    public function removeUnusualLineTerminators(?selections:Array<Selection>):Void {
        final matches = this.findMatches(Strings.UNUSUAL_LINE_TERMINATORS_SOURCE, false, true, false, null, false, 1 << 30);
        this._buffer.resetMightContainUnusualLineTerminators();
        final ops:Array<IIdentifiedSingleEditOperation> = [for (m in matches) {range: m.range, text: null}];
        this.pushEditOperations(selections, ops, _ -> null);
    }

    public function mightContainNonBasicASCII():Bool {
        return this._buffer.mightContainNonBasicASCII();
    }

    public function getAlternativeVersionId():Int {
        this._assertNotDisposed();
        return this._alternativeVersionId;
    }

    public function getInitialUndoRedoSnapshot():Null<ResourceEditStackSnapshot> {
        this._assertNotDisposed();
        return this._initialUndoRedoSnapshot;
    }

    public function getOffsetAt(rawPosition:IPosition):Int {
        this._assertNotDisposed();
        final position = this._validatePosition(rawPosition.lineNumber, rawPosition.column, StringOffsetValidationType.Relaxed);
        return this._buffer.getOffsetAt(position.lineNumber, position.column);
    }

    public function getPositionAt(rawOffset:Int):Position {
        this._assertNotDisposed();
        final length = this._buffer.getLength();
        final offset = (rawOffset < 0 ? 0 : (rawOffset > length ? length : rawOffset));
        return this._buffer.getPositionAt(offset);
    }

    function _increaseVersionId():Void {
        this._versionId = this._versionId + 1;
        this._alternativeVersionId = this._versionId;
    }

    public function _overwriteVersionId(versionId:Int):Void {
        this._versionId = versionId;
    }

    public function _overwriteAlternativeVersionId(newAlternativeVersionId:Int):Void {
        this._alternativeVersionId = newAlternativeVersionId;
    }

    public function _overwriteInitialUndoRedoSnapshot(newInitialUndoRedoSnapshot:Null<ResourceEditStackSnapshot>):Void {
        this._initialUndoRedoSnapshot = newInitialUndoRedoSnapshot;
    }

    public function getValue(?eol:EndOfLinePreference, ?preserveBOM:Bool):String {
        this._assertNotDisposed();
        if (this.isTooLargeForHeapOperation()) {
            throw new BugIndicatingError('Operation would exceed heap memory limits');
        }

        final fullModelRange = this.getFullModelRange();
        final fullModelValue = this.getValueInRange(fullModelRange, eol);

        if (preserveBOM == true) {
            return this._buffer.getBOM() + fullModelValue;
        }

        return fullModelValue;
    }

    public function createSnapshot(?preserveBOM:Bool):ITextSnapshot {
        return new TextModelSnapshot(this._buffer.createSnapshot(preserveBOM == true));
    }

    public function getValueLength(?eol:EndOfLinePreference, ?preserveBOM:Bool):Int {
        this._assertNotDisposed();
        final fullModelRange = this.getFullModelRange();
        final fullModelValue = this.getValueLengthInRange(fullModelRange, eol);

        if (preserveBOM == true) {
            return this._buffer.getBOM().length + fullModelValue;
        }

        return fullModelValue;
    }

    public function getValueInRange(rawRange:IRange, ?eol:EndOfLinePreference):String {
        this._assertNotDisposed();
        return this._buffer.getValueInRange(this.validateRange(rawRange), eol != null ? eol : EndOfLinePreference.TextDefined);
    }

    public function getValueLengthInRange(rawRange:IRange, ?eol:EndOfLinePreference):Int {
        this._assertNotDisposed();
        return this._buffer.getValueLengthInRange(this.validateRange(rawRange), eol != null ? eol : EndOfLinePreference.TextDefined);
    }

    public function getCharacterCountInRange(rawRange:IRange, ?eol:EndOfLinePreference):Int {
        this._assertNotDisposed();
        return this._buffer.getCharacterCountInRange(this.validateRange(rawRange), eol != null ? eol : EndOfLinePreference.TextDefined);
    }

    public function getLineCount():Int {
        this._assertNotDisposed();
        return this._buffer.getLineCount();
    }

    public function getLineContent(lineNumber:Int):String {
        this._assertNotDisposed();
        if (lineNumber < 1 || lineNumber > this._buffer.getLineCount()) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }

        return this._buffer.getLineContent(lineNumber);
    }

    public function getLineLength(lineNumber:Int):Int {
        this._assertNotDisposed();
        if (lineNumber < 1 || lineNumber > this._buffer.getLineCount()) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }

        return this._buffer.getLineLength(lineNumber);
    }

    public function getLinesContent():Array<String> {
        this._assertNotDisposed();
        if (this.isTooLargeForHeapOperation()) {
            throw new BugIndicatingError('Operation would exceed heap memory limits');
        }

        return this._buffer.getLinesContent();
    }

    public function getEOL():String {
        this._assertNotDisposed();
        return this._buffer.getEOL();
    }

    public function getEndOfLineSequence():EndOfLineSequence {
        this._assertNotDisposed();
        return (
            this._buffer.getEOL() == '\n'
                ? EndOfLineSequence.LF
                : EndOfLineSequence.CRLF
        );
    }

    public function getLineMinColumn(lineNumber:Int):Int {
        this._assertNotDisposed();
        return 1;
    }

    public function getLineMaxColumn(lineNumber:Int):Int {
        this._assertNotDisposed();
        if (lineNumber < 1 || lineNumber > this._buffer.getLineCount()) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }
        return this._buffer.getLineLength(lineNumber) + 1;
    }

    public function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int {
        this._assertNotDisposed();
        if (lineNumber < 1 || lineNumber > this._buffer.getLineCount()) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }
        return this._buffer.getLineFirstNonWhitespaceColumn(lineNumber);
    }

    public function getLineLastNonWhitespaceColumn(lineNumber:Int):Int {
        this._assertNotDisposed();
        if (lineNumber < 1 || lineNumber > this._buffer.getLineCount()) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }
        return this._buffer.getLineLastNonWhitespaceColumn(lineNumber);
    }

    /**
     * Validates `range` is within buffer bounds, but allows it to sit in between surrogate pairs, etc.
     * Will try to not allocate if possible.
     */
    public function _validateRangeRelaxedNoAllocations(range:IRange):Range {
        final linesCount = this._buffer.getLineCount();

        final initialStartLineNumber = range.startLineNumber;
        final initialStartColumn = range.startColumn;
        var startLineNumber = initialStartLineNumber;
        var startColumn = initialStartColumn;

        if (startLineNumber < 1) {
            startLineNumber = 1;
            startColumn = 1;
        }
        else if (startLineNumber > linesCount) {
            startLineNumber = linesCount;
            startColumn = this.getLineMaxColumn(startLineNumber);
        }
        else {
            if (startColumn <= 1) {
                startColumn = 1;
            }
            else {
                final maxColumn = this.getLineMaxColumn(startLineNumber);
                if (startColumn >= maxColumn) {
                    startColumn = maxColumn;
                }
            }
        }

        final initialEndLineNumber = range.endLineNumber;
        final initialEndColumn = range.endColumn;
        var endLineNumber = initialEndLineNumber;
        var endColumn = initialEndColumn;

        if (endLineNumber < 1) {
            endLineNumber = 1;
            endColumn = 1;
        }
        else if (endLineNumber > linesCount) {
            endLineNumber = linesCount;
            endColumn = this.getLineMaxColumn(endLineNumber);
        }
        else {
            if (endColumn <= 1) {
                endColumn = 1;
            }
            else {
                final maxColumn = this.getLineMaxColumn(endLineNumber);
                if (endColumn >= maxColumn) {
                    endColumn = maxColumn;
                }
            }
        }

        if (
            initialStartLineNumber == startLineNumber
            && initialStartColumn == startColumn
            && initialEndLineNumber == endLineNumber
            && initialEndColumn == endColumn
            && Std.isOfType(range, Range)
            && !Std.isOfType(range, Selection)
        ) {
            return cast range;
        }

        return new Range(startLineNumber, startColumn, endLineNumber, endColumn);
    }

    function _isValidPosition(lineNumber:Int, column:Int, validationType:StringOffsetValidationType):Bool {
        if (lineNumber < 1 || column < 1) {
            return false;
        }

        final lineCount = this._buffer.getLineCount();
        if (lineNumber > lineCount) {
            return false;
        }

        if (column == 1) {
            return true;
        }

        final maxColumn = this.getLineMaxColumn(lineNumber);
        if (column > maxColumn) {
            return false;
        }

        if (validationType == StringOffsetValidationType.SurrogatePairs) {
            // !!At this point, column > 1
            final charCodeBefore = this._buffer.getLineCharCode(lineNumber, column - 2);
            if (Strings.isHighSurrogate(charCodeBefore)) {
                return false;
            }
        }

        return true;
    }

    function _validatePosition(lineNumber:Int, column:Int, validationType:StringOffsetValidationType):Position {
        final lineCount = this._buffer.getLineCount();

        if (lineNumber < 1) {
            return new Position(1, 1);
        }

        if (lineNumber > lineCount) {
            return new Position(lineCount, this.getLineMaxColumn(lineCount));
        }

        if (column <= 1) {
            return new Position(lineNumber, 1);
        }

        final maxColumn = this.getLineMaxColumn(lineNumber);
        if (column >= maxColumn) {
            return new Position(lineNumber, maxColumn);
        }

        if (validationType == StringOffsetValidationType.SurrogatePairs) {
            // If the position would end up in the middle of a high-low surrogate pair,
            // we move it to before the pair
            // !!At this point, column > 1
            final charCodeBefore = this._buffer.getLineCharCode(lineNumber, column - 2);
            if (Strings.isHighSurrogate(charCodeBefore)) {
                return new Position(lineNumber, column - 1);
            }
        }

        return new Position(lineNumber, column);
    }

    public function validatePosition(position:IPosition):Position {
        final validationType = StringOffsetValidationType.SurrogatePairs;
        this._assertNotDisposed();

        // Avoid object allocation and cover most likely case
        if (Std.isOfType(position, Position)) {
            final position:Position = cast position;
            if (this._isValidPosition(position.lineNumber, position.column, validationType)) {
                return position;
            }
            return this._validatePosition(position.lineNumber, position.column, validationType);
        }

        return this._validatePosition(position.lineNumber, position.column, validationType);
    }

    function _isValidRange(range:Range, validationType:StringOffsetValidationType):Bool {
        final startLineNumber = range.startLineNumber;
        final startColumn = range.startColumn;
        final endLineNumber = range.endLineNumber;
        final endColumn = range.endColumn;

        if (!this._isValidPosition(startLineNumber, startColumn, StringOffsetValidationType.Relaxed)) {
            return false;
        }
        if (!this._isValidPosition(endLineNumber, endColumn, StringOffsetValidationType.Relaxed)) {
            return false;
        }

        if (validationType == StringOffsetValidationType.SurrogatePairs) {
            final charCodeBeforeStart = (startColumn > 1 ? this._buffer.getLineCharCode(startLineNumber, startColumn - 2) : 0);
            final charCodeBeforeEnd = (endColumn > 1 && endColumn <= this._buffer.getLineLength(endLineNumber) ? this._buffer.getLineCharCode(endLineNumber, endColumn - 2) : 0);

            final startInsideSurrogatePair = Strings.isHighSurrogate(charCodeBeforeStart);
            final endInsideSurrogatePair = Strings.isHighSurrogate(charCodeBeforeEnd);

            if (!startInsideSurrogatePair && !endInsideSurrogatePair) {
                return true;
            }
            return false;
        }

        return true;
    }

    public function validateRange(_range:IRange):Range {
        final validationType = StringOffsetValidationType.SurrogatePairs;
        this._assertNotDisposed();

        var startLineNumber:Int;
        var startColumn:Int;
        var endLineNumber:Int;
        var endColumn:Int;

        // Avoid object allocation and cover most likely case
        if (Std.isOfType(_range, Range)) {
            final range:Range = cast _range;
            if (!Std.isOfType(_range, Selection) && this._isValidRange(range, validationType)) {
                return range;
            }
            startLineNumber = range.startLineNumber;
            startColumn = range.startColumn;
            endLineNumber = range.endLineNumber;
            endColumn = range.endColumn;
        }
        else {
            startLineNumber = _range.startLineNumber;
            startColumn = _range.startColumn;
            endLineNumber = _range.endLineNumber;
            endColumn = _range.endColumn;
        }

        final start = this._validatePosition(startLineNumber, startColumn, StringOffsetValidationType.Relaxed);
        final end = this._validatePosition(endLineNumber, endColumn, StringOffsetValidationType.Relaxed);

        final startLineNumber = start.lineNumber;
        final startColumn = start.column;
        final endLineNumber = end.lineNumber;
        final endColumn = end.column;

        if (validationType == StringOffsetValidationType.SurrogatePairs) {
            final charCodeBeforeStart = (startColumn > 1 ? this._buffer.getLineCharCode(startLineNumber, startColumn - 2) : 0);
            final charCodeBeforeEnd = (endColumn > 1 && endColumn <= this._buffer.getLineLength(endLineNumber) ? this._buffer.getLineCharCode(endLineNumber, endColumn - 2) : 0);

            final startInsideSurrogatePair = Strings.isHighSurrogate(charCodeBeforeStart);
            final endInsideSurrogatePair = Strings.isHighSurrogate(charCodeBeforeEnd);

            if (!startInsideSurrogatePair && !endInsideSurrogatePair) {
                return new Range(startLineNumber, startColumn, endLineNumber, endColumn);
            }

            if (startLineNumber == endLineNumber && startColumn == endColumn) {
                // do not expand a collapsed range, simply move it to a valid location
                return new Range(startLineNumber, startColumn - 1, endLineNumber, endColumn - 1);
            }

            if (startInsideSurrogatePair && endInsideSurrogatePair) {
                // expand range at both ends
                return new Range(startLineNumber, startColumn - 1, endLineNumber, endColumn + 1);
            }

            if (startInsideSurrogatePair) {
                // only expand range at the start
                return new Range(startLineNumber, startColumn - 1, endLineNumber, endColumn);
            }

            // only expand range at the end
            return new Range(startLineNumber, startColumn, endLineNumber, endColumn + 1);
        }

        return new Range(startLineNumber, startColumn, endLineNumber, endColumn);
    }

    public function modifyPosition(rawPosition:IPosition, offset:Int):Position {
        this._assertNotDisposed();
        final candidate = this.getOffsetAt(rawPosition) + offset;
        final length = this._buffer.getLength();
        return this.getPositionAt(candidate < 0 ? 0 : (candidate > length ? length : candidate));
    }

    public function getFullModelRange():Range {
        this._assertNotDisposed();
        final lineCount = this.getLineCount();
        return new Range(1, 1, lineCount, this.getLineMaxColumn(lineCount));
    }

    function findMatchesLineByLine(searchRange:Range, searchData:SearchData, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        return this._buffer.findMatchesLineByLine(searchRange, searchData, captureMatches, limitResultCount);
    }

    public function findMatches(searchString:String, rawSearchScope:FindMatchesScope, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, captureMatches:Bool, ?limitResultCount:Int):Array<FindMatch> {
        this._assertNotDisposed();
        if (limitResultCount == null) {
            limitResultCount = LIMIT_FIND_COUNT;
        }

        var searchRanges:Null<Array<Range>> = null;

        if (rawSearchScope != null) {
            final scopes:Array<Any> = Std.isOfType(rawSearchScope, Array) ? cast rawSearchScope : [rawSearchScope];

            var allRanges = true;
            for (searchScope in scopes) {
                if (!Range.isIRange(searchScope)) {
                    allRanges = false;
                    break;
                }
            }
            if (allRanges) {
                searchRanges = [for (searchScope in scopes) this.validateRange(searchScope)];
            }
        }

        if (searchRanges == null) {
            searchRanges = [this.getFullModelRange()];
        }

        haxe.ds.ArraySort.sort(searchRanges, (d1, d2) -> {
            final r = d1.startLineNumber - d2.startLineNumber;
            return r != 0 ? r : d1.startColumn - d2.startColumn;
        });

        final uniqueSearchRanges:Array<Range> = [];
        var prev = searchRanges[0];
        for (i in 1...searchRanges.length) {
            final curr = searchRanges[i];
            if (Range.areIntersecting(prev, curr)) {
                prev = prev.plusRange(curr);
                continue;
            }
            uniqueSearchRanges.push(prev);
            prev = curr;
        }
        uniqueSearchRanges.push(prev);

        var matchMapper:(searchRange:Range) -> Array<FindMatch>;
        if (!isRegex && searchString.indexOf('\n') < 0) {
            // not regex, not multi line
            final searchParams = new SearchParams(searchString, isRegex, matchCase, wordSeparators);
            final searchData = searchParams.parseSearchRequest();

            if (searchData == null) {
                return [];
            }

            matchMapper = (searchRange:Range) -> this.findMatchesLineByLine(searchRange, searchData, captureMatches, limitResultCount);
        }
        else {
            matchMapper = (searchRange:Range) -> TextModelSearch.findMatches(this, new SearchParams(searchString, isRegex, matchCase, wordSeparators), searchRange, captureMatches, limitResultCount);
        }

        final result:Array<FindMatch> = [];
        for (searchRange in uniqueSearchRanges) {
            Arrays.pushMany(result, matchMapper(searchRange));
        }
        return result;
    }

    public function findNextMatch(searchString:String, rawSearchStart:IPosition, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, captureMatches:Bool):Null<FindMatch> {
        this._assertNotDisposed();
        final searchStart = this.validatePosition(rawSearchStart);

        if (!isRegex && searchString.indexOf('\n') < 0) {
            final searchParams = new SearchParams(searchString, isRegex, matchCase, wordSeparators);
            final searchData = searchParams.parseSearchRequest();
            if (searchData == null) {
                return null;
            }

            final lineCount = this.getLineCount();
            var searchRange = new Range(searchStart.lineNumber, searchStart.column, lineCount, this.getLineMaxColumn(lineCount));
            var ret = this.findMatchesLineByLine(searchRange, searchData, captureMatches, 1);
            // Monaco also calls `TextModelSearch.findNextMatch` here and drops the result
            if (ret.length > 0) {
                return ret[0];
            }

            searchRange = new Range(1, 1, searchStart.lineNumber, this.getLineMaxColumn(searchStart.lineNumber));
            ret = this.findMatchesLineByLine(searchRange, searchData, captureMatches, 1);

            if (ret.length > 0) {
                return ret[0];
            }

            return null;
        }

        return TextModelSearch.findNextMatch(this, new SearchParams(searchString, isRegex, matchCase, wordSeparators), searchStart, captureMatches);
    }

    public function findPreviousMatch(searchString:String, rawSearchStart:IPosition, isRegex:Bool, matchCase:Bool, wordSeparators:Null<String>, captureMatches:Bool):Null<FindMatch> {
        this._assertNotDisposed();
        final searchStart = this.validatePosition(rawSearchStart);
        return TextModelSearch.findPreviousMatch(this, new SearchParams(searchString, isRegex, matchCase, wordSeparators), searchStart, captureMatches);
    }

    //#endregion

    //#region Editing

    public function pushStackElement():Void {
        this._commandManager.pushStackElement();
    }

    public function popStackElement():Void {
        this._commandManager.popStackElement();
    }

    public function pushEOL(eol:EndOfLineSequence):Void {
        final currentEOL = (this.getEOL() == '\n' ? EndOfLineSequence.LF : EndOfLineSequence.CRLF);
        if (currentEOL == eol) {
            return;
        }
        this._onDidChangeDecorations.beginDeferredEmit();
        this._eventEmitter.beginDeferredEmit();
        try {
            if (this._initialUndoRedoSnapshot == null) {
                this._initialUndoRedoSnapshot = this._undoRedoService.createSnapshot(this.uri);
            }
            this._commandManager.pushEOL(eol);
        }
        catch (e:Dynamic) {
            this._eventEmitter.endDeferredEmit();
            this._onDidChangeDecorations.endDeferredEmit();
            throw e;
        }
        this._eventEmitter.endDeferredEmit();
        this._onDidChangeDecorations.endDeferredEmit();
    }

    function _validateEditOperation(rawOperation:IIdentifiedSingleEditOperation):ValidAnnotatedEditOperation {
        if (Std.isOfType(rawOperation, ValidAnnotatedEditOperation)) {
            return cast rawOperation;
        }
        return new ValidAnnotatedEditOperation(
            rawOperation.identifier,
            this.validateRange(rawOperation.range),
            rawOperation.text,
            rawOperation.forceMoveMarkers == true,
            rawOperation.isAutoWhitespaceEdit == true,
            rawOperation._isTracked == true
        );
    }

    function _validateEditOperations(rawOperations:Array<IIdentifiedSingleEditOperation>):Array<ValidAnnotatedEditOperation> {
        final result:Array<ValidAnnotatedEditOperation> = [];
        for (i in 0...rawOperations.length) {
            result[i] = this._validateEditOperation(rawOperations[i]);
        }
        return result;
    }

    public function pushEditOperations(beforeCursorState:Null<Array<Selection>>, editOperations:Array<IIdentifiedSingleEditOperation>, cursorStateComputer:ICursorStateComputer, ?group:UndoRedoGroup):Null<Array<Selection>> {
        this._onDidChangeDecorations.beginDeferredEmit();
        this._eventEmitter.beginDeferredEmit();
        var result:Null<Array<Selection>>;
        try {
            result = this._pushEditOperations(beforeCursorState, this._validateEditOperations(editOperations), cursorStateComputer, group);
        }
        catch (e:Dynamic) {
            this._eventEmitter.endDeferredEmit();
            this._onDidChangeDecorations.endDeferredEmit();
            throw e;
        }
        this._eventEmitter.endDeferredEmit();
        this._onDidChangeDecorations.endDeferredEmit();
        return result;
    }

    function _pushEditOperations(beforeCursorState:Null<Array<Selection>>, editOperations:Array<ValidAnnotatedEditOperation>, cursorStateComputer:Null<ICursorStateComputer>, ?group:UndoRedoGroup):Null<Array<Selection>> {
        if (this._options.trimAutoWhitespace && this._trimAutoWhitespaceLines != null) {
            // Go through each saved line number and insert a trim whitespace edit
            // if it is safe to do so (no conflicts with other edits).

            final incomingEdits = [for (op in editOperations) {
                range: this.validateRange(op.range),
                text: op.text
            }];

            // Sometimes, auto-formatters change ranges automatically which can cause undesired auto whitespace trimming near the cursor
            // We'll use the following heuristic: if the edits occur near the cursor, then it's ok to trim auto whitespace
            var editsAreNearCursors = true;
            if (beforeCursorState != null) {
                for (i in 0...beforeCursorState.length) {
                    final sel = beforeCursorState[i];
                    var foundEditNearSel = false;
                    for (j in 0...incomingEdits.length) {
                        final editRange = incomingEdits[j].range;
                        final selIsAbove = editRange.startLineNumber > sel.endLineNumber;
                        final selIsBelow = sel.startLineNumber > editRange.endLineNumber;
                        if (!selIsAbove && !selIsBelow) {
                            foundEditNearSel = true;
                            break;
                        }
                    }
                    if (!foundEditNearSel) {
                        editsAreNearCursors = false;
                        break;
                    }
                }
            }

            if (editsAreNearCursors) {
                for (i in 0...this._trimAutoWhitespaceLines.length) {
                    final trimLineNumber = this._trimAutoWhitespaceLines[i];
                    final maxLineColumn = this.getLineMaxColumn(trimLineNumber);

                    var allowTrimLine = true;
                    for (j in 0...incomingEdits.length) {
                        final editRange = incomingEdits[j].range;
                        final editText = incomingEdits[j].text;

                        if (trimLineNumber < editRange.startLineNumber || trimLineNumber > editRange.endLineNumber) {
                            // `trimLine` is completely outside this edit
                            continue;
                        }

                        // At this point:
                        //   editRange.startLineNumber <= trimLine <= editRange.endLineNumber

                        if (
                            trimLineNumber == editRange.startLineNumber && editRange.startColumn == maxLineColumn
                            && editRange.isEmpty() && editText != null && editText.length > 0 && editText.charAt(0) == '\n'
                        ) {
                            // This edit inserts a new line (and maybe other text) after `trimLine`
                            continue;
                        }

                        if (
                            trimLineNumber == editRange.startLineNumber && editRange.startColumn == 1
                            && editRange.isEmpty() && editText != null && editText.length > 0 && editText.charAt(editText.length - 1) == '\n'
                        ) {
                            // This edit inserts a new line (and maybe other text) before `trimLine`
                            continue;
                        }

                        // Looks like we can't trim this line as it would interfere with an incoming edit
                        allowTrimLine = false;
                        break;
                    }

                    if (allowTrimLine) {
                        final trimRange = new Range(trimLineNumber, 1, trimLineNumber, maxLineColumn);
                        editOperations.push(new ValidAnnotatedEditOperation(null, trimRange, null, false, false, false));
                    }
                }
            }

            this._trimAutoWhitespaceLines = null;
        }
        if (this._initialUndoRedoSnapshot == null) {
            this._initialUndoRedoSnapshot = this._undoRedoService.createSnapshot(this.uri);
        }
        return this._commandManager.pushEditOperation(beforeCursorState, editOperations, cursorStateComputer, group);
    }

    public function _applyUndo(changes:Array<TextChange>, eol:EndOfLineSequence, resultingAlternativeVersionId:Int, resultingSelection:Null<Array<Selection>>):Void {
        final edits:Array<IIdentifiedSingleEditOperation> = [for (change in changes) {
            final rangeStart = this.getPositionAt(change.newPosition);
            final rangeEnd = this.getPositionAt(change.newEnd);
            {
                range: new Range(rangeStart.lineNumber, rangeStart.column, rangeEnd.lineNumber, rangeEnd.column),
                text: change.oldText
            };
        }];
        this._applyUndoRedoEdits(edits, eol, true, false, resultingAlternativeVersionId, resultingSelection);
    }

    public function _applyRedo(changes:Array<TextChange>, eol:EndOfLineSequence, resultingAlternativeVersionId:Int, resultingSelection:Null<Array<Selection>>):Void {
        final edits:Array<IIdentifiedSingleEditOperation> = [for (change in changes) {
            final rangeStart = this.getPositionAt(change.oldPosition);
            final rangeEnd = this.getPositionAt(change.oldEnd);
            {
                range: new Range(rangeStart.lineNumber, rangeStart.column, rangeEnd.lineNumber, rangeEnd.column),
                text: change.newText
            };
        }];
        this._applyUndoRedoEdits(edits, eol, false, true, resultingAlternativeVersionId, resultingSelection);
    }

    function _applyUndoRedoEdits(edits:Array<IIdentifiedSingleEditOperation>, eol:EndOfLineSequence, isUndoing:Bool, isRedoing:Bool, resultingAlternativeVersionId:Int, resultingSelection:Null<Array<Selection>>):Void {
        this._onDidChangeDecorations.beginDeferredEmit();
        this._eventEmitter.beginDeferredEmit();
        try {
            this._isUndoing = isUndoing;
            this._isRedoing = isRedoing;
            this.applyEdits(edits, false);
            this.setEOL(eol);
            this._overwriteAlternativeVersionId(resultingAlternativeVersionId);
        }
        catch (e:Dynamic) {
            this._isUndoing = false;
            this._isRedoing = false;
            this._eventEmitter.endDeferredEmit(resultingSelection);
            this._onDidChangeDecorations.endDeferredEmit();
            throw e;
        }
        this._isUndoing = false;
        this._isRedoing = false;
        this._eventEmitter.endDeferredEmit(resultingSelection);
        this._onDidChangeDecorations.endDeferredEmit();
    }

    public function applyEdits(rawOperations:Array<IIdentifiedSingleEditOperation>, ?computeUndoEdits:Bool):Null<Array<IValidEditOperation>> {
        return this._applyValidatedEdits(this._validateEditOperations(rawOperations), computeUndoEdits == true);
    }

    /**
     * `applyEdits` on operations that are already validated (Monaco passes
     * `ValidAnnotatedEditOperation`s to `applyEdits`, which keeps them).
     * @internal
     */
    public function _applyValidatedEdits(operations:Array<ValidAnnotatedEditOperation>, computeUndoEdits:Bool):Null<Array<IValidEditOperation>> {
        this._onDidChangeDecorations.beginDeferredEmit();
        this._eventEmitter.beginDeferredEmit();
        var result:Null<Array<IValidEditOperation>>;
        try {
            result = this._doApplyEdits(operations, computeUndoEdits);
        }
        catch (e:Dynamic) {
            this._eventEmitter.endDeferredEmit();
            this._onDidChangeDecorations.endDeferredEmit();
            throw e;
        }
        this._eventEmitter.endDeferredEmit();
        this._onDidChangeDecorations.endDeferredEmit();
        return result;
    }

    function _doApplyEdits(rawOperations:Array<ValidAnnotatedEditOperation>, computeUndoEdits:Bool):Null<Array<IValidEditOperation>> {

        final oldLineCount = this._buffer.getLineCount();
        final result = this._buffer.applyEdits(rawOperations, this._options.trimAutoWhitespace, computeUndoEdits);
        final newLineCount = this._buffer.getLineCount();

        final contentChanges = result.changes;
        this._trimAutoWhitespaceLines = result.trimAutoWhitespaceLineNumbers;

        if (contentChanges.length != 0) {
            // We do a first pass to update decorations
            // because we want to read decorations in the second pass
            // where we will emit content change events
            // and we want to read the final decorations
            for (i in 0...contentChanges.length) {
                final change = contentChanges[i];
                this._decorationsTree.acceptReplace(change.rangeOffset, change.rangeLength, change.text.length, change.forceMoveMarkers);
            }

            final rawContentChanges:Array<ModelRawChange> = [];

            this._increaseVersionId();

            var lineCount = oldLineCount;
            final eolCounter = new EolCount();
            for (i in 0...contentChanges.length) {
                final change = contentChanges[i];
                final eolCount = EolCounter.countEOL(change.text, eolCounter).eolCount;
                this._onDidChangeDecorations.fire();

                final startLineNumber = change.range.startLineNumber;
                final endLineNumber = change.range.endLineNumber;

                final deletingLinesCnt = endLineNumber - startLineNumber;
                final insertingLinesCnt = eolCount;
                final editingLinesCnt = (deletingLinesCnt < insertingLinesCnt ? deletingLinesCnt : insertingLinesCnt);

                final changeLineCountDelta = (insertingLinesCnt - deletingLinesCnt);

                final currentEditStartLineNumber = newLineCount - lineCount - changeLineCountDelta + startLineNumber;
                final firstEditLineNumber = currentEditStartLineNumber;
                final lastInsertedLineNumber = currentEditStartLineNumber + insertingLinesCnt;

                final decorationsWithInjectedTextInEditedRange = this._decorationsTree.getInjectedTextInInterval(
                    this,
                    this.getOffsetAt(new Position(firstEditLineNumber, 1)),
                    this.getOffsetAt(new Position(lastInsertedLineNumber, this.getLineMaxColumn(lastInsertedLineNumber))),
                    0
                );

                final injectedTextInEditedRange = LineInjectedText.fromDecorations(decorationsWithInjectedTextInEditedRange);
                final injectedTextInEditedRangeQueue = new ArrayQueue(injectedTextInEditedRange);

                var j = editingLinesCnt;
                while (j >= 0) {
                    final editLineNumber = startLineNumber + j;
                    final currentEditLineNumber = currentEditStartLineNumber + j;

                    injectedTextInEditedRangeQueue.takeFromEndWhile(r -> r.lineNumber > currentEditLineNumber);
                    final decorationsInCurrentLine = injectedTextInEditedRangeQueue.takeFromEndWhile(r -> r.lineNumber == currentEditLineNumber);

                    rawContentChanges.push(
                        new ModelRawLineChanged(
                            editLineNumber,
                            this.getLineContent(currentEditLineNumber),
                            decorationsInCurrentLine
                        ));
                    j--;
                }

                if (editingLinesCnt < deletingLinesCnt) {
                    // Must delete some lines
                    final spliceStartLineNumber = startLineNumber + editingLinesCnt;
                    rawContentChanges.push(new ModelRawLinesDeleted(spliceStartLineNumber + 1, endLineNumber));
                }

                if (editingLinesCnt < insertingLinesCnt) {
                    final injectedTextInEditedRangeQueue = new ArrayQueue(injectedTextInEditedRange);
                    // Must insert some lines
                    final spliceLineNumber = startLineNumber + editingLinesCnt;
                    final cnt = insertingLinesCnt - editingLinesCnt;
                    final fromLineNumber = newLineCount - lineCount - cnt + spliceLineNumber + 1;
                    final injectedTexts:Array<Null<Array<LineInjectedText>>> = [];
                    final newLines:Array<String> = [];
                    for (i in 0...cnt) {
                        final lineNumber = fromLineNumber + i;
                        newLines[i] = this.getLineContent(lineNumber);

                        injectedTextInEditedRangeQueue.takeWhile(r -> r.lineNumber < lineNumber);
                        injectedTexts[i] = injectedTextInEditedRangeQueue.takeWhile(r -> r.lineNumber == lineNumber);
                    }

                    rawContentChanges.push(
                        new ModelRawLinesInserted(
                            spliceLineNumber + 1,
                            startLineNumber + insertingLinesCnt,
                            newLines,
                            injectedTexts
                        )
                    );
                }

                lineCount += changeLineCountDelta;
            }

            this._emitContentChangedEvent(
                new ModelRawContentChangedEvent(
                    rawContentChanges,
                    this.getVersionId(),
                    this._isUndoing,
                    this._isRedoing
                ),
                {
                    changes: cast contentChanges,
                    eol: this._buffer.getEOL(),
                    isEolChange: false,
                    versionId: this.getVersionId(),
                    isUndoing: this._isUndoing,
                    isRedoing: this._isRedoing,
                    isFlush: false
                }
            );
        }

        return result.reverseEdits;
    }

    public function undo():Void {
        this._undoRedoService.undo(this.uri);
    }

    public function canUndo():Bool {
        return this._undoRedoService.canUndo(this.uri);
    }

    public function redo():Void {
        this._undoRedoService.redo(this.uri);
    }

    public function canRedo():Bool {
        return this._undoRedoService.canRedo(this.uri);
    }

    //#endregion

    //#region Decorations

    function handleBeforeFireDecorationsChangedEvent(affectedInjectedTextLines:Null<Array<Int>>):Void {
        // This is called before the decoration changed event is fired.

        if (affectedInjectedTextLines == null || affectedInjectedTextLines.length == 0) {
            return;
        }

        final affectedLines = affectedInjectedTextLines.copy();
        final lineChangeEvents = [for (lineNumber in affectedLines) new ModelRawLineChanged(lineNumber, this.getLineContent(lineNumber), this._getInjectedTextInLine(lineNumber))];

        this._onDidChangeInjectedText.fire(new ModelInjectedTextChangedEvent(lineChangeEvents));
    }

    public function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T, ?ownerId:Int):Null<T> {
        this._assertNotDisposed();
        if (ownerId == null) {
            ownerId = 0;
        }

        this._onDidChangeDecorations.beginDeferredEmit();
        var result:Null<T>;
        try {
            result = this._changeDecorations(ownerId, callback);
        }
        catch (e:Dynamic) {
            this._onDidChangeDecorations.endDeferredEmit();
            throw e;
        }
        this._onDidChangeDecorations.endDeferredEmit();
        return result;
    }

    function _changeDecorations<T>(ownerId:Int, callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T> {
        final changeAccessor = new DecorationsChangeAccessor(this, ownerId);
        var result:Null<T> = null;
        try {
            result = callback(changeAccessor);
        }
        catch (e:Dynamic) {
            Errors.onUnexpectedError(e);
        }
        // Invalidate change accessor
        changeAccessor.invalidate();
        return result;
    }

    public function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>, ?ownerId:Int):Array<String> {
        this._assertNotDisposed();
        if (ownerId == null) {
            ownerId = 0;
        }
        if (oldDecorations == null) {
            oldDecorations = [];
        }
        if (oldDecorations.length == 0 && newDecorations.length == 0) {
            // nothing to do
            return [];
        }

        this._deltaDecorationCallCnt++;
        if (this._deltaDecorationCallCnt > 1) {
            Errors.onUnexpectedError('Invoking deltaDecorations recursively could lead to leaking decorations.');
        }
        this._onDidChangeDecorations.beginDeferredEmit();
        var result:Array<String>;
        try {
            result = this._deltaDecorationsImpl(ownerId, oldDecorations, newDecorations);
        }
        catch (e:Dynamic) {
            this._onDidChangeDecorations.endDeferredEmit();
            this._deltaDecorationCallCnt--;
            throw e;
        }
        this._onDidChangeDecorations.endDeferredEmit();
        this._deltaDecorationCallCnt--;
        return result;
    }

    public function _getTrackedRange(id:String):Null<Range> {
        return this.getDecorationRange(id);
    }

    public function _setTrackedRange(id:Null<String>, newRange:Null<Range>, newStickiness:TrackedRangeStickiness):Null<String> {
        final node = (id != null ? this._decorations.get(id) : null);

        if (node == null) {
            if (newRange == null) {
                // node doesn't exist, the request is to delete => nothing to do
                return null;
            }
            // node doesn't exist, the request is to set => add the tracked range
            return this._deltaDecorationsImpl(0, [], [{range: newRange, options: cast ModelDecorationOptions.TRACKED_RANGE_OPTIONS[newStickiness]}], true)[0];
        }

        if (newRange == null) {
            // node exists, the request is to delete => delete node
            this._decorationsTree.delete(node);
            this._decorations.remove(node.id);
            return null;
        }

        // node exists, the request is to set => change the tracked range and its options
        final range = this._validateRangeRelaxedNoAllocations(newRange);
        final startOffset = this._buffer.getOffsetAt(range.startLineNumber, range.startColumn);
        final endOffset = this._buffer.getOffsetAt(range.endLineNumber, range.endColumn);
        this._decorationsTree.delete(node);
        node.reset(this.getVersionId(), startOffset, endOffset, range);
        node.setOptions(ModelDecorationOptions.TRACKED_RANGE_OPTIONS[newStickiness]);
        this._decorationsTree.insert(node);
        return node.id;
    }

    public function removeAllDecorationsWithOwnerId(ownerId:Int):Void {
        if (this._isDisposed) {
            return;
        }
        final nodes = this._decorationsTree.collectNodesFromOwner(ownerId);
        for (i in 0...nodes.length) {
            final node = nodes[i];

            this._decorationsTree.delete(node);
            this._decorations.remove(node.id);
        }
    }

    public function getDecorationOptions(decorationId:String):Null<IModelDecorationOptions> {
        final node = this._decorations.get(decorationId);
        if (node == null) {
            return null;
        }
        return cast node.options;
    }

    public function getDecorationRange(decorationId:String):Null<Range> {
        final node = this._decorations.get(decorationId);
        if (node == null) {
            return null;
        }
        return this._decorationsTree.getNodeRange(this, node);
    }

    public function getLineDecorations(lineNumber:Int, ?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration> {
        if (lineNumber < 1 || lineNumber > this.getLineCount()) {
            return [];
        }
        return this.getLinesDecorations(lineNumber, lineNumber, ownerId, filterOutValidation);
    }

    public function getLinesDecorations(_startLineNumber:Int, _endLineNumber:Int, ?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration> {
        return this._getLinesDecorations(_startLineNumber, _endLineNumber, ownerId != null ? ownerId : 0, filterOutValidation == true, false);
    }

    /**
     * Monaco's `getLinesDecorations` with its `onlyMarginDecorations`
     * argument (not in the `ITextModel` interface).
     */
    public function _getLinesDecorations(_startLineNumber:Int, _endLineNumber:Int, ownerId:Int, filterOutValidation:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration> {
        final lineCount = this.getLineCount();
        final startLineNumber = Std.int(Math.min(lineCount, Math.max(1, _startLineNumber)));
        final endLineNumber = Std.int(Math.min(lineCount, Math.max(1, _endLineNumber)));
        final endColumn = this.getLineMaxColumn(endLineNumber);
        final range = new Range(startLineNumber, 1, endLineNumber, endColumn);

        final decorations = this._getDecorationsInRange(range, ownerId, filterOutValidation, onlyMarginDecorations);
        Arrays.pushMany(decorations, this._decorationProvider.getDecorationsInRange(range, ownerId, filterOutValidation));
        return decorations;
    }

    public function getDecorationsInRange(range:IRange, ?ownerId:Int, ?filterOutValidation:Bool, ?onlyMinimapDecorations:Bool, ?onlyMarginDecorations:Bool):Array<IModelDecoration> {
        final validatedRange = this.validateRange(range);

        final decorations = this._getDecorationsInRange(validatedRange, ownerId != null ? ownerId : 0, filterOutValidation == true, onlyMarginDecorations == true);
        Arrays.pushMany(decorations, this._decorationProvider.getDecorationsInRange(validatedRange, ownerId, filterOutValidation, onlyMinimapDecorations));
        return decorations;
    }

    public function getOverviewRulerDecorations(?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration> {
        return this._decorationsTree.getAll(this, ownerId != null ? ownerId : 0, filterOutValidation == true, true, false);
    }

    public function getInjectedTextDecorations(?ownerId:Int):Array<IModelDecoration> {
        return this._decorationsTree.getAllInjectedText(this, ownerId != null ? ownerId : 0);
    }

    function _getInjectedTextInLine(lineNumber:Int):Array<LineInjectedText> {
        final startOffset = this._buffer.getOffsetAt(lineNumber, 1);
        final endOffset = startOffset + this._buffer.getLineLength(lineNumber);

        final result = this._decorationsTree.getInjectedTextInInterval(this, startOffset, endOffset, 0);
        return LineInjectedText.fromDecorations(result).filter(t -> t.lineNumber == lineNumber);
    }

    public function getAllDecorations(?ownerId:Int, ?filterOutValidation:Bool):Array<IModelDecoration> {
        var result = this._decorationsTree.getAll(this, ownerId != null ? ownerId : 0, filterOutValidation == true, false, false);
        result = result.concat(this._decorationProvider.getAllDecorations(ownerId, filterOutValidation));
        return result;
    }

    public function getAllMarginDecorations(?ownerId:Int):Array<IModelDecoration> {
        return this._decorationsTree.getAll(this, ownerId != null ? ownerId : 0, false, false, true);
    }

    function _getDecorationsInRange(filterRange:Range, filterOwnerId:Int, filterOutValidation:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration> {
        final startOffset = this._buffer.getOffsetAt(filterRange.startLineNumber, filterRange.startColumn);
        final endOffset = this._buffer.getOffsetAt(filterRange.endLineNumber, filterRange.endColumn);
        return this._decorationsTree.getAllInInterval(this, startOffset, endOffset, filterOwnerId, filterOutValidation, onlyMarginDecorations);
    }

    public function getRangeAt(start:Int, end:Int):Range {
        return this._buffer.getRangeAt(start, end - start);
    }

    @:allow(cityscape.common.model.DecorationsChangeAccessor)
    function _changeDecorationImpl(decorationId:String, _range:IRange):Void {
        final node = this._decorations.get(decorationId);
        if (node == null) {
            return;
        }

        if (node.options.after != null) {
            final oldRange = this.getDecorationRange(decorationId);
            this._onDidChangeDecorations.recordLineAffectedByInjectedText(oldRange.endLineNumber);
        }
        if (node.options.before != null) {
            final oldRange = this.getDecorationRange(decorationId);
            this._onDidChangeDecorations.recordLineAffectedByInjectedText(oldRange.startLineNumber);
        }

        final range = this._validateRangeRelaxedNoAllocations(_range);
        final startOffset = this._buffer.getOffsetAt(range.startLineNumber, range.startColumn);
        final endOffset = this._buffer.getOffsetAt(range.endLineNumber, range.endColumn);

        this._decorationsTree.delete(node);
        node.reset(this.getVersionId(), startOffset, endOffset, range);
        this._decorationsTree.insert(node);
        this._onDidChangeDecorations.checkAffectedAndFire(node.options);

        if (node.options.after != null) {
            this._onDidChangeDecorations.recordLineAffectedByInjectedText(range.endLineNumber);
        }
        if (node.options.before != null) {
            this._onDidChangeDecorations.recordLineAffectedByInjectedText(range.startLineNumber);
        }
    }

    @:allow(cityscape.common.model.DecorationsChangeAccessor)
    function _changeDecorationOptionsImpl(decorationId:String, options:ModelDecorationOptions):Void {
        final node = this._decorations.get(decorationId);
        if (node == null) {
            return;
        }

        final nodeWasInOverviewRuler = (node.options.overviewRuler != null && JsValuesBridge.truthy(node.options.overviewRuler.color));
        final nodeIsInOverviewRuler = (options.overviewRuler != null && JsValuesBridge.truthy(options.overviewRuler.color));

        this._onDidChangeDecorations.checkAffectedAndFire(node.options);
        this._onDidChangeDecorations.checkAffectedAndFire(options);

        if (node.options.after != null || options.after != null) {
            final nodeRange = this._decorationsTree.getNodeRange(this, node);
            this._onDidChangeDecorations.recordLineAffectedByInjectedText(nodeRange.endLineNumber);
        }
        if (node.options.before != null || options.before != null) {
            final nodeRange = this._decorationsTree.getNodeRange(this, node);
            this._onDidChangeDecorations.recordLineAffectedByInjectedText(nodeRange.startLineNumber);
        }

        final movedInOverviewRuler = nodeWasInOverviewRuler != nodeIsInOverviewRuler;
        final changedWhetherInjectedText = DecorationsTrees.isOptionsInjectedText(options) != DecorationsTrees.isNodeInjectedText(node);
        if (movedInOverviewRuler || changedWhetherInjectedText) {
            this._decorationsTree.delete(node);
            node.setOptions(options);
            this._decorationsTree.insert(node);
        }
        else {
            node.setOptions(options);
        }
    }

    @:allow(cityscape.common.model.DecorationsChangeAccessor)
    function _deltaDecorationsImpl(ownerId:Int, oldDecorationsIds:Array<String>, newDecorations:Array<IModelDeltaDecoration>, suppressEvents:Bool = false):Array<String> {
        final versionId = this.getVersionId();

        final oldDecorationsLen = oldDecorationsIds.length;
        var oldDecorationIndex = 0;

        final newDecorationsLen = newDecorations.length;
        var newDecorationIndex = 0;

        this._onDidChangeDecorations.beginDeferredEmit();
        final result:Array<String> = [];
        result.resize(newDecorationsLen);
        try {
            while (oldDecorationIndex < oldDecorationsLen || newDecorationIndex < newDecorationsLen) {

                var node:Null<IntervalNode> = null;

                if (oldDecorationIndex < oldDecorationsLen) {
                    // (1) get ourselves an old node
                    do {
                        node = this._decorations.get(oldDecorationsIds[oldDecorationIndex++]);
                    } while (node == null && oldDecorationIndex < oldDecorationsLen);

                    // (2) remove the node from the tree (if it exists)
                    if (node != null) {
                        if (node.options.after != null) {
                            final nodeRange = this._decorationsTree.getNodeRange(this, node);
                            this._onDidChangeDecorations.recordLineAffectedByInjectedText(nodeRange.endLineNumber);
                        }
                        if (node.options.before != null) {
                            final nodeRange = this._decorationsTree.getNodeRange(this, node);
                            this._onDidChangeDecorations.recordLineAffectedByInjectedText(nodeRange.startLineNumber);
                        }

                        this._decorationsTree.delete(node);

                        if (!suppressEvents) {
                            this._onDidChangeDecorations.checkAffectedAndFire(node.options);
                        }
                    }
                }

                if (newDecorationIndex < newDecorationsLen) {
                    // (3) create a new node if necessary
                    if (node == null) {
                        final internalDecorationId = (++this._lastDecorationId);
                        final decorationId = '${this._instanceId};${internalDecorationId}';
                        node = new IntervalNode(decorationId, 0, 0);
                        this._decorations.set(decorationId, node);
                    }

                    // (4) initialize node
                    final newDecoration = newDecorations[newDecorationIndex];
                    final range = this._validateRangeRelaxedNoAllocations(newDecoration.range);
                    final options = ModelDecorationOptions._normalizeOptions(newDecoration.options);
                    final startOffset = this._buffer.getOffsetAt(range.startLineNumber, range.startColumn);
                    final endOffset = this._buffer.getOffsetAt(range.endLineNumber, range.endColumn);

                    node.ownerId = ownerId;
                    node.reset(versionId, startOffset, endOffset, range);
                    node.setOptions(options);

                    if (node.options.after != null) {
                        this._onDidChangeDecorations.recordLineAffectedByInjectedText(range.endLineNumber);
                    }
                    if (node.options.before != null) {
                        this._onDidChangeDecorations.recordLineAffectedByInjectedText(range.startLineNumber);
                    }

                    if (!suppressEvents) {
                        this._onDidChangeDecorations.checkAffectedAndFire(options);
                    }

                    this._decorationsTree.insert(node);

                    result[newDecorationIndex] = node.id;

                    newDecorationIndex++;
                }
                else {
                    if (node != null) {
                        this._decorations.remove(node.id);
                    }
                }
            }
        }
        catch (e:Dynamic) {
            this._onDidChangeDecorations.endDeferredEmit();
            throw e;
        }
        this._onDidChangeDecorations.endDeferredEmit();
        return result;
    }

    //#endregion

    //#region Tokenization

    // TODO move them to the tokenization part.
    public function getLanguageId():String {
        return this._tokenizationTextModelPart.getLanguageId();
    }

    public function setLanguage(languageIdOrSelection:EitherType<String, ILanguageSelection>, ?source:String):Void {
        if (Std.isOfType(languageIdOrSelection, String)) {
            this._languageSelectionListener.clear();
            this._setLanguage(cast languageIdOrSelection, source);
        }
        else {
            final selection:ILanguageSelection = cast languageIdOrSelection;
            this._languageSelectionListener.value = selection.onDidChange(_ -> this._setLanguage(selection.languageId, source));
            this._setLanguage(selection.languageId, source);
        }
    }

    function _setLanguage(languageId:String, ?source:String):Void {
        this._tokenizationTextModelPart.setLanguageId(languageId, source);
        this.context.languageService.requestRichLanguageFeatures(languageId);
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return this._tokenizationTextModelPart.getLanguageIdAtPosition(lineNumber, column);
    }

    public function getWordAtPosition(position:IPosition):Null<IWordAtPosition> {
        return this._tokenizationTextModelPart.getWordAtPosition(position);
    }

    public function getWordUntilPosition(position:IPosition):IWordAtPosition {
        return this._tokenizationTextModelPart.getWordUntilPosition(position);
    }

    //#endregion

    public function normalizePosition(position:Position, affinity:PositionAffinity):Position {
        return position;
    }

    /**
     * Gets the column at which indentation stops at a given line.
     * @internal
     */
    public function getLineIndentColumn(lineNumber:Int):Int {
        // Columns start with 1.
        return indentOfLine(this.getLineContent(lineNumber)) + 1;
    }

}

/**
 * JavaScript truthiness of the values of decoration options (colors are a
 * string or a `ThemeColor`).
 */
private class JsValuesBridge {

    public static inline function truthy(value:Any):Bool {
        return cityscape.base.common.JsValues.truthy(value);
    }

}

/**
 * The change accessor of `TextModel.changeDecorations`: valid only during
 * the callback.
 */
class DecorationsChangeAccessor implements IModelDecorationsChangeAccessor {

    var model:Null<TextModel>;

    final ownerId:Int;

    public function new(model:TextModel, ownerId:Int) {
        this.model = model;
        this.ownerId = ownerId;
    }

    public function invalidate():Void {
        this.model = null;
    }

    inline function getModel():TextModel {
        if (this.model == null) {
            throw 'Invalid change accessor';
        }
        return this.model;
    }

    public function addDecoration(range:IRange, options:IModelDecorationOptions):String {
        return getModel()._deltaDecorationsImpl(ownerId, [], [{range: range, options: options}])[0];
    }

    public function changeDecoration(id:String, newRange:IRange):Void {
        getModel()._changeDecorationImpl(id, newRange);
    }

    public function changeDecorationOptions(id:String, options:IModelDecorationOptions):Void {
        getModel()._changeDecorationOptionsImpl(id, ModelDecorationOptions._normalizeOptions(options));
    }

    public function removeDecoration(id:String):Void {
        getModel()._deltaDecorationsImpl(ownerId, [id], []);
    }

    public function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>):Array<String> {
        final model = getModel();
        if (oldDecorations.length == 0 && newDecorations.length == 0) {
            // nothing to do
            return [];
        }
        return model._deltaDecorationsImpl(ownerId, oldDecorations, newDecorations);
    }

}

//#region Decorations

class DecorationsTrees {

    /**
     * This tree holds decorations that do not show up in the overview ruler.
     */
    final _decorationsTree0:IntervalTree;

    /**
     * This tree holds decorations that show up in the overview ruler.
     */
    final _decorationsTree1:IntervalTree;

    /**
     * This tree holds decorations that contain injected text.
     */
    final _injectedTextDecorationsTree:IntervalTree;

    public function new() {
        this._decorationsTree0 = new IntervalTree();
        this._decorationsTree1 = new IntervalTree();
        this._injectedTextDecorationsTree = new IntervalTree();
    }

    public static function isNodeInOverviewRuler(node:IntervalNode):Bool {
        return (node.options.overviewRuler != null && cityscape.base.common.JsValues.truthy(node.options.overviewRuler.color));
    }

    public static function isOptionsInjectedText(options:ModelDecorationOptions):Bool {
        return options.after != null || options.before != null;
    }

    public static function isNodeInjectedText(node:IntervalNode):Bool {
        return node.options.after != null || node.options.before != null;
    }

    public function ensureAllNodesHaveRanges(host:IDecorationsTreesHost):Void {
        this.getAll(host, 0, false, false, false);
    }

    /**
     * Gives the nodes their range, and returns them as `IModelDecoration`s
     * (Monaco casts the nodes, which have the fields of a decoration).
     */
    static function _ensureNodesHaveRanges(host:IDecorationsTreesHost, nodes:Array<IntervalNode>, result:Array<IModelDecoration>, filterInjectedText:Bool):Array<IModelDecoration> {
        for (node in nodes) {
            if (node.range == null) {
                node.range = host.getRangeAt(node.cachedAbsoluteStart, node.cachedAbsoluteEnd);
            }
            if (filterInjectedText && !(node.options.showIfCollapsed || !node.range.isEmpty())) {
                continue;
            }
            result.push(cast node);
        }
        return result;
    }

    public function getAllInInterval(host:IDecorationsTreesHost, start:Int, end:Int, filterOwnerId:Int, filterOutValidation:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration> {
        final versionId = host.getVersionId();
        final result:Array<IModelDecoration> = [];
        _ensureNodesHaveRanges(host, this._decorationsTree0.intervalSearch(start, end, filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
        _ensureNodesHaveRanges(host, this._decorationsTree1.intervalSearch(start, end, filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
        _ensureNodesHaveRanges(host, this._injectedTextDecorationsTree.intervalSearch(start, end, filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
        return result;
    }

    public function getInjectedTextInInterval(host:IDecorationsTreesHost, start:Int, end:Int, filterOwnerId:Int):Array<IModelDecoration> {
        final versionId = host.getVersionId();
        final result = this._injectedTextDecorationsTree.intervalSearch(start, end, filterOwnerId, false, versionId, false);
        return _ensureNodesHaveRanges(host, result, [], true);
    }

    public function getAllInjectedText(host:IDecorationsTreesHost, filterOwnerId:Int):Array<IModelDecoration> {
        final versionId = host.getVersionId();
        final result = this._injectedTextDecorationsTree.search(filterOwnerId, false, versionId, false);
        return _ensureNodesHaveRanges(host, result, [], true);
    }

    public function getAll(host:IDecorationsTreesHost, filterOwnerId:Int, filterOutValidation:Bool, overviewRulerOnly:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration> {
        final versionId = host.getVersionId();
        final result:Array<IModelDecoration> = [];
        if (overviewRulerOnly) {
            _ensureNodesHaveRanges(host, this._decorationsTree1.search(filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
        }
        else {
            _ensureNodesHaveRanges(host, this._decorationsTree0.search(filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
            _ensureNodesHaveRanges(host, this._decorationsTree1.search(filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
            _ensureNodesHaveRanges(host, this._injectedTextDecorationsTree.search(filterOwnerId, filterOutValidation, versionId, onlyMarginDecorations), result, false);
        }
        return result;
    }

    public function collectNodesFromOwner(ownerId:Int):Array<IntervalNode> {
        final r0 = this._decorationsTree0.collectNodesFromOwner(ownerId);
        final r1 = this._decorationsTree1.collectNodesFromOwner(ownerId);
        final r2 = this._injectedTextDecorationsTree.collectNodesFromOwner(ownerId);
        return r0.concat(r1).concat(r2);
    }

    public function collectNodesPostOrder():Array<IntervalNode> {
        final r0 = this._decorationsTree0.collectNodesPostOrder();
        final r1 = this._decorationsTree1.collectNodesPostOrder();
        final r2 = this._injectedTextDecorationsTree.collectNodesPostOrder();
        return r0.concat(r1).concat(r2);
    }

    /**
     * Calls `callback` with the nodes of `collectNodesPostOrder` and their
     * tree (Monaco's `recomputeMaxEnd(node)` needs the tree's sentinel here).
     */
    public function forEachNodePostOrder(callback:(tree:IntervalTree, node:IntervalNode) -> Void):Void {
        for (tree in [this._decorationsTree0, this._decorationsTree1, this._injectedTextDecorationsTree]) {
            for (node in tree.collectNodesPostOrder()) {
                callback(tree, node);
            }
        }
    }

    public function insert(node:IntervalNode):Void {
        if (isNodeInjectedText(node)) {
            this._injectedTextDecorationsTree.insert(node);
        }
        else if (isNodeInOverviewRuler(node)) {
            this._decorationsTree1.insert(node);
        }
        else {
            this._decorationsTree0.insert(node);
        }
    }

    public function delete(node:IntervalNode):Void {
        if (isNodeInjectedText(node)) {
            this._injectedTextDecorationsTree.delete(node);
        }
        else if (isNodeInOverviewRuler(node)) {
            this._decorationsTree1.delete(node);
        }
        else {
            this._decorationsTree0.delete(node);
        }
    }

    public function getNodeRange(host:IDecorationsTreesHost, node:IntervalNode):Range {
        final versionId = host.getVersionId();
        if (node.cachedVersionId != versionId) {
            this._resolveNode(node, versionId);
        }
        if (node.range == null) {
            node.range = host.getRangeAt(node.cachedAbsoluteStart, node.cachedAbsoluteEnd);
        }
        return node.range;
    }

    function _resolveNode(node:IntervalNode, cachedVersionId:Int):Void {
        if (isNodeInjectedText(node)) {
            this._injectedTextDecorationsTree.resolveNode(node, cachedVersionId);
        }
        else if (isNodeInOverviewRuler(node)) {
            this._decorationsTree1.resolveNode(node, cachedVersionId);
        }
        else {
            this._decorationsTree0.resolveNode(node, cachedVersionId);
        }
    }

    public function acceptReplace(offset:Int, length:Int, textLength:Int, forceMoveMarkers:Bool):Void {
        this._decorationsTree0.acceptReplace(offset, length, textLength, forceMoveMarkers);
        this._decorationsTree1.acceptReplace(offset, length, textLength, forceMoveMarkers);
        this._injectedTextDecorationsTree.acceptReplace(offset, length, textLength, forceMoveMarkers);
    }

}

class DecorationOptions {

    public final color:DecorationColor;

    public final darkColor:DecorationColor;

    public function new(options:IDecorationOptions) {
        this.color = cityscape.base.common.JsValues.truthy(options.color) ? options.color : '';
        this.darkColor = cityscape.base.common.JsValues.truthy(options.darkColor) ? options.darkColor : '';
    }

}

/**
 * TODO(step 2): `getColor(theme)` (resolving a `ThemeColor` with the theme
 * of the editor) comes with the view and the themes.
 */
class ModelDecorationOverviewRulerOptions extends DecorationOptions {

    public final position:OverviewRulerLane;

    public function new(options:IModelDecorationOverviewRulerOptions) {
        super(options);
        // `typeof options.position === 'number' ? options.position : OverviewRulerLane.Center`
        final position:Null<Int> = cityscape.base.common.JsValues.isNumber(options.position) ? cast options.position : null;
        this.position = (position != null ? position : OverviewRulerLane.Center);
    }

}

class ModelDecorationGlyphMarginOptions {

    public final position:GlyphMarginLane;

    public final persistLane:Null<Bool>;

    public function new(options:Null<IModelDecorationGlyphMarginOptions>) {
        // `options?.position ?? GlyphMarginLane.Center`
        final position:Null<Int> = options != null ? cast options.position : null;
        this.position = (position != null) ? position : GlyphMarginLane.Center;
        this.persistLane = options != null ? options.persistLane : null;
    }

}

/**
 * Cityscape has no minimap: kept so that Monaco decoration options pass as
 * they are.
 */
class ModelDecorationMinimapOptions extends DecorationOptions {

    public final position:MinimapPosition;

    public final sectionHeaderStyle:Null<MinimapSectionHeaderStyle>;

    public final sectionHeaderText:Null<String>;

    public function new(options:IModelDecorationMinimapOptions) {
        super(options);
        this.position = options.position;
        this.sectionHeaderStyle = options.sectionHeaderStyle;
        this.sectionHeaderText = options.sectionHeaderText;
    }

}

class ModelDecorationInjectedTextOptions {

    public static function from(options:InjectedTextOptions):ModelDecorationInjectedTextOptions {
        if (Std.isOfType(options, ModelDecorationInjectedTextOptions)) {
            return cast options;
        }
        return new ModelDecorationInjectedTextOptions(options);
    }

    public final content:String;

    public final inlineClassName:Null<String>;

    public final inlineClassNameAffectsLetterSpacing:Bool;

    public final attachedData:Any;

    public final cursorStops:Null<InjectedTextCursorStops>;

    function new(options:InjectedTextOptions) {
        this.content = (options.content != null ? options.content : '');
        this.inlineClassName = (options.inlineClassName != null && options.inlineClassName.length > 0) ? options.inlineClassName : null;
        this.inlineClassNameAffectsLetterSpacing = options.inlineClassNameAffectsLetterSpacing == true;
        this.attachedData = cityscape.base.common.JsValues.truthy(options.attachedData) ? options.attachedData : null;
        this.cursorStops = (options.cursorStops != null && options.cursorStops != 0) ? options.cursorStops : null;
    }

}

/**
 * The normalized options of a decoration (Monaco's class implementing
 * `IModelDecorationOptions`). The `options` of the `IModelDecoration`s
 * returned by the model are instances of this class: read them through
 * `IModelDecorationOptions`, or cast them to `ModelDecorationOptions` for
 * typed access (`Std.downcast`).
 */
class ModelDecorationOptions {

    public static final EMPTY:ModelDecorationOptions = ModelDecorationOptions.register({description: 'empty'});

    /**
     * The order carefully matches the values of the enum.
     */
    public static final TRACKED_RANGE_OPTIONS:Array<ModelDecorationOptions> = [
        ModelDecorationOptions.register({description: 'tracked-range-always-grows-when-typing-at-edges', stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges}),
        ModelDecorationOptions.register({description: 'tracked-range-never-grows-when-typing-at-edges', stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges}),
        ModelDecorationOptions.register({description: 'tracked-range-grows-only-when-typing-before', stickiness: TrackedRangeStickiness.GrowsOnlyWhenTypingBefore}),
        ModelDecorationOptions.register({description: 'tracked-range-grows-only-when-typing-after', stickiness: TrackedRangeStickiness.GrowsOnlyWhenTypingAfter}),
    ];

    public static function register(options:IModelDecorationOptions):ModelDecorationOptions {
        return new ModelDecorationOptions(options);
    }

    public static function createDynamic(options:IModelDecorationOptions):ModelDecorationOptions {
        return new ModelDecorationOptions(options);
    }

    public static function _normalizeOptions(options:IModelDecorationOptions):ModelDecorationOptions {
        if (Std.isOfType(options, ModelDecorationOptions)) {
            return cast options;
        }
        return ModelDecorationOptions.createDynamic(options);
    }

    static function cleanClassName(className:String):String {
        // className.replace(/[^a-z0-9\-_]/gi, ' ')
        final buf = new StringBuf();
        for (i in 0...className.length) {
            final c = StringTools.fastCodeAt(className, i);
            if ((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '-'.code || c == '_'.code) {
                buf.addChar(c);
            }
            else if (Strings.isHighSurrogate(c) && i + 1 < className.length && Strings.isLowSurrogate(StringTools.fastCodeAt(className, i + 1))) {
                // A surrogate pair is replaced by two spaces (no `u` flag)
                buf.addChar(' '.code);
            }
            else {
                buf.addChar(' '.code);
            }
        }
        return buf.toString();
    }

    static inline function nonEmpty(s:Null<String>):Bool {
        return s != null && s.length > 0;
    }

    public final description:String;

    public final blockClassName:Null<String>;

    public final blockIsAfterEnd:Null<Bool>;

    public final blockDoesNotCollapse:Null<Bool>;

    public final blockPadding:Null<Array<Float>>;

    public final stickiness:TrackedRangeStickiness;

    public final zIndex:Float;

    public final className:Null<String>;

    public final shouldFillLineOnLineBreak:Null<Bool>;

    public final hoverMessage:Null<HoverMessage>;

    public final glyphMarginHoverMessage:Null<HoverMessage>;

    public final isWholeLine:Bool;

    public final showIfCollapsed:Bool;

    public final collapseOnReplaceEdit:Bool;

    public final overviewRuler:Null<ModelDecorationOverviewRulerOptions>;

    public final minimap:Null<ModelDecorationMinimapOptions>;

    public final glyphMargin:Null<ModelDecorationGlyphMarginOptions>;

    public final glyphMarginClassName:Null<String>;

    public final linesDecorationsClassName:Null<String>;

    public final lineNumberClassName:Null<String>;

    public final lineNumberHoverMessage:Null<HoverMessage>;

    public final linesDecorationsTooltip:Null<String>;

    public final firstLineDecorationClassName:Null<String>;

    public final marginClassName:Null<String>;

    public final inlineClassName:Null<String>;

    public final inlineClassNameAffectsLetterSpacing:Bool;

    public final beforeContentClassName:Null<String>;

    public final afterContentClassName:Null<String>;

    public final after:Null<ModelDecorationInjectedTextOptions>;

    public final before:Null<ModelDecorationInjectedTextOptions>;

    public final hideInCommentTokens:Null<Bool>;

    public final hideInStringTokens:Null<Bool>;

    function new(options:IModelDecorationOptions) {
        this.description = options.description;
        this.blockClassName = nonEmpty(options.blockClassName) ? cleanClassName(options.blockClassName) : null;
        this.blockDoesNotCollapse = options.blockDoesNotCollapse;
        this.blockIsAfterEnd = options.blockIsAfterEnd;
        this.blockPadding = options.blockPadding;
        this.stickiness = (options.stickiness != null && options.stickiness != 0) ? options.stickiness : TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges;
        this.zIndex = (options.zIndex != null && !Math.isNaN(options.zIndex)) ? options.zIndex : 0;
        this.className = nonEmpty(options.className) ? cleanClassName(options.className) : null;
        this.shouldFillLineOnLineBreak = options.shouldFillLineOnLineBreak;
        this.hoverMessage = options.hoverMessage;
        this.glyphMarginHoverMessage = options.glyphMarginHoverMessage;
        this.lineNumberHoverMessage = options.lineNumberHoverMessage;
        this.isWholeLine = options.isWholeLine == true;
        this.showIfCollapsed = options.showIfCollapsed == true;
        this.collapseOnReplaceEdit = options.collapseOnReplaceEdit == true;
        this.overviewRuler = options.overviewRuler != null ? new ModelDecorationOverviewRulerOptions(options.overviewRuler) : null;
        this.minimap = options.minimap != null ? new ModelDecorationMinimapOptions(options.minimap) : null;
        this.glyphMargin = nonEmpty(options.glyphMarginClassName) ? new ModelDecorationGlyphMarginOptions(options.glyphMargin) : null;
        this.glyphMarginClassName = nonEmpty(options.glyphMarginClassName) ? cleanClassName(options.glyphMarginClassName) : null;
        this.linesDecorationsClassName = nonEmpty(options.linesDecorationsClassName) ? cleanClassName(options.linesDecorationsClassName) : null;
        this.lineNumberClassName = nonEmpty(options.lineNumberClassName) ? cleanClassName(options.lineNumberClassName) : null;
        this.linesDecorationsTooltip = nonEmpty(options.linesDecorationsTooltip) ? Strings.htmlAttributeEncodeValue(options.linesDecorationsTooltip) : null;
        this.firstLineDecorationClassName = nonEmpty(options.firstLineDecorationClassName) ? cleanClassName(options.firstLineDecorationClassName) : null;
        this.marginClassName = nonEmpty(options.marginClassName) ? cleanClassName(options.marginClassName) : null;
        this.inlineClassName = nonEmpty(options.inlineClassName) ? cleanClassName(options.inlineClassName) : null;
        this.inlineClassNameAffectsLetterSpacing = options.inlineClassNameAffectsLetterSpacing == true;
        this.beforeContentClassName = nonEmpty(options.beforeContentClassName) ? cleanClassName(options.beforeContentClassName) : null;
        this.afterContentClassName = nonEmpty(options.afterContentClassName) ? cleanClassName(options.afterContentClassName) : null;
        this.after = options.after != null ? ModelDecorationInjectedTextOptions.from(options.after) : null;
        this.before = options.before != null ? ModelDecorationInjectedTextOptions.from(options.before) : null;
        this.hideInCommentTokens = options.hideInCommentTokens != null ? options.hideInCommentTokens : false;
        this.hideInStringTokens = options.hideInStringTokens != null ? options.hideInStringTokens : false;
    }

}

class DidChangeDecorationsEmitter extends Disposable {

    final _actual:Emitter<IModelDecorationsChangedEvent>;

    public final event:Event<IModelDecorationsChangedEvent>;

    var _deferredCnt:Int;

    var _shouldFireDeferred:Bool;

    var _affectsMinimap:Bool;

    var _affectsOverviewRuler:Bool;

    /**
     * Monaco's `Set<number>`: the lines in insertion order.
     */
    var _affectedInjectedTextLines:Null<Array<Int>> = null;

    var _affectsGlyphMargin:Bool;

    var _affectsLineNumber:Bool;

    final handleBeforeFire:(affectedInjectedTextLines:Null<Array<Int>>) -> Void;

    public function new(handleBeforeFire:(affectedInjectedTextLines:Null<Array<Int>>) -> Void) {
        super();
        this._actual = this._register(new Emitter<IModelDecorationsChangedEvent>());
        this.event = this._actual.event;
        this.handleBeforeFire = handleBeforeFire;
        this._deferredCnt = 0;
        this._shouldFireDeferred = false;
        this._affectsMinimap = false;
        this._affectsOverviewRuler = false;
        this._affectsGlyphMargin = false;
        this._affectsLineNumber = false;
    }

    public function hasListeners():Bool {
        return this._actual.hasListeners();
    }

    public function beginDeferredEmit():Void {
        this._deferredCnt++;
    }

    public function endDeferredEmit():Void {
        this._deferredCnt--;
        if (this._deferredCnt == 0) {
            if (this._shouldFireDeferred) {
                this.doFire();
            }

            this._affectedInjectedTextLines = null;
        }
    }

    public function recordLineAffectedByInjectedText(lineNumber:Int):Void {
        if (this._affectedInjectedTextLines == null) {
            this._affectedInjectedTextLines = [];
        }
        if (this._affectedInjectedTextLines.indexOf(lineNumber) == -1) {
            this._affectedInjectedTextLines.push(lineNumber);
        }
    }

    public function checkAffectedAndFire(options:ModelDecorationOptions):Void {
        if (!this._affectsMinimap) {
            this._affectsMinimap = options.minimap != null && options.minimap.position != 0;
        }
        if (!this._affectsOverviewRuler) {
            this._affectsOverviewRuler = options.overviewRuler != null && cityscape.base.common.JsValues.truthy(options.overviewRuler.color);
        }
        if (!this._affectsGlyphMargin) {
            this._affectsGlyphMargin = options.glyphMarginClassName != null && options.glyphMarginClassName.length > 0;
        }
        if (!this._affectsLineNumber) {
            this._affectsLineNumber = options.lineNumberClassName != null && options.lineNumberClassName.length > 0;
        }
        this.tryFire();
    }

    public function fire():Void {
        this._affectsMinimap = true;
        this._affectsOverviewRuler = true;
        this._affectsGlyphMargin = true;
        this.tryFire();
    }

    function tryFire():Void {
        if (this._deferredCnt == 0) {
            this.doFire();
        }
        else {
            this._shouldFireDeferred = true;
        }
    }

    function doFire():Void {
        this.handleBeforeFire(this._affectedInjectedTextLines);

        if (!this._actual.hasListeners()) {
            // Cityscape: the same state without allocating an event nobody gets
            this._shouldFireDeferred = false;
            this._affectsMinimap = false;
            this._affectsOverviewRuler = false;
            this._affectsGlyphMargin = false;
            return;
        }

        final event:IModelDecorationsChangedEvent = {
            affectsMinimap: this._affectsMinimap,
            affectsOverviewRuler: this._affectsOverviewRuler,
            affectsGlyphMargin: this._affectsGlyphMargin,
            affectsLineNumber: this._affectsLineNumber,
        };
        this._shouldFireDeferred = false;
        this._affectsMinimap = false;
        this._affectsOverviewRuler = false;
        this._affectsGlyphMargin = false;
        this._actual.fire(event);
    }

}

class DidChangeContentEmitter extends Disposable {

    /**
     * Both `fastEvent` and `slowEvent` work the same way and contain the same events, but first we invoke `fastEvent` and then `slowEvent`.
     */
    final _fastEmitter:Emitter<InternalModelContentChangeEvent>;

    public final fastEvent:Event<InternalModelContentChangeEvent>;

    final _slowEmitter:Emitter<InternalModelContentChangeEvent>;

    public final slowEvent:Event<InternalModelContentChangeEvent>;

    var _deferredCnt:Int;

    var _deferredEvent:Null<InternalModelContentChangeEvent>;

    public function new() {
        super();
        this._fastEmitter = this._register(new Emitter<InternalModelContentChangeEvent>());
        this.fastEvent = this._fastEmitter.event;
        this._slowEmitter = this._register(new Emitter<InternalModelContentChangeEvent>());
        this.slowEvent = this._slowEmitter.event;
        this._deferredCnt = 0;
        this._deferredEvent = null;
    }

    public function hasListeners():Bool {
        return (
            this._fastEmitter.hasListeners()
            || this._slowEmitter.hasListeners()
        );
    }

    public function beginDeferredEmit():Void {
        this._deferredCnt++;
    }

    public function endDeferredEmit(?resultingSelection:Array<Selection>):Void {
        this._deferredCnt--;
        if (this._deferredCnt == 0) {
            if (this._deferredEvent != null) {
                this._deferredEvent.rawContentChangedEvent.resultingSelection = resultingSelection;
                final e = this._deferredEvent;
                this._deferredEvent = null;
                this._fastEmitter.fire(e);
                this._slowEmitter.fire(e);
            }
        }
    }

    public function fire(e:InternalModelContentChangeEvent):Void {
        if (this._deferredCnt > 0) {
            if (this._deferredEvent != null) {
                this._deferredEvent = this._deferredEvent.merge(e);
            }
            else {
                this._deferredEvent = e;
            }
            return;
        }
        this._fastEmitter.fire(e);
        this._slowEmitter.fire(e);
    }

}

//#endregion
