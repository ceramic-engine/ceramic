// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/goToCommands.ts,
// link/clickLinkGesture.ts and link/goToDefinitionAtPosition.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.LocationLink;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.contrib.gotoSymbol.view.ReferencesModel;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;

typedef SymbolNavigationActionConfig = {
    final openToSide:Bool;
    final openInPeek:Bool;
    final muteMessage:Bool;
}

/**
 * Module functions shared by the symbol navigation.
 */
class SymbolNavigation {

    /**
     * The model of a resource: a model of the model service, or the model of
     * an editor of the context.
     */
    public static function findModel(context:Cityscape, resource:Uri):Null<ITextModel> {
        final model = context.modelService.getModel(resource);
        if (model != null) {
            return model;
        }
        final key = resource.toString();
        for (editor in context.codeEditorService.listCodeEditors()) {
            final m = editor.getModel();
            if (m != null && m.uri.toString() == key) {
                return m;
            }
        }
        return null;
    }

}

/**
 * Goes to the definition of the symbol at the cursor (Monaco's
 * `DefinitionAction` and `GoToDefinitionAction`,
 * `editor.action.revealDefinition`, F12).
 *
 * The peek view is not ported: when there are several definitions, the
 * editor goes to the first one whatever the `gotoLocation` option (Monaco's
 * `'goto'`), and the locations are not kept for "go to next symbol". The
 * "no definition found" message is given to `onNoResult` of the context
 * (Monaco shows it next to the cursor). The location is opened through
 * `context.codeEditorService.openCodeEditor`: in the same editor when it
 * is in its model, else by the handlers a host registers.
 */
class DefinitionAction extends EditorAction {

    public static inline final ID = 'editor.action.revealDefinition';

    final configuration:SymbolNavigationActionConfig;
    final r:EditorExtensionsRegistry;

    public function new(r:EditorExtensionsRegistry, ?configuration:SymbolNavigationActionConfig, ?id:String) {
        final kbOpts:Array<ICommandKeybindingsOptions> = [{
            kbExpr: EditorContextKeys.editorTextFocus,
            primary: KeyCode.F12,
            weight: KeybindingWeight.EditorContrib
        }];
        #if js
        // IsWebContext
        kbOpts.push({
            kbExpr: EditorContextKeys.editorTextFocus,
            primary: KeyMod.CtrlCmd | KeyCode.F12,
            weight: KeybindingWeight.EditorContrib
        });
        #end
        super({
            id: id != null ? id : ID,
            label: r.localize('actions.goToDecl.label', "Go to Definition"),
            alias: 'Go to Definition',
            precondition: EditorContextKeys.hasDefinitionProvider,
            kbOpts: id != null ? null : kbOpts,
            contextMenuOpts: id != null ? null : {
                group: 'navigation',
                order: 1.1
            }
        });
        this.r = r;
        this.configuration = configuration != null ? configuration : {openToSide: false, openInPeek: false, muteMessage: false};
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        runOn(editor, null);
    }

    /**
     * Monaco's `SymbolNavigationAction.runEditorCommand`: `callback` is
     * called once the navigation is done (with the editor showing the
     * definition, or null).
     */
    public function runOn(editor:ICodeEditor, ?callback:(target:Null<ICodeEditor>) -> Void):Void {
        if (!editor.hasModel()) {
            if (callback != null) callback(null);
            return;
        }

        final model = editor.getModel();
        final position = editor.getPosition();
        final versionId = model.getVersionId();

        final cts = new CancellationTokenSource();
        // EditorStateCancellationTokenSource (Value | Position)
        final listener = editor.onDidChangeCursorPosition(_ -> {
            if (!editor.getPosition().equals(position)) {
                cts.cancel();
            }
        });
        final contentListener = editor.onDidChangeModelContent(_ -> cts.cancel());

        GoToSymbol.getDefinitionsAtPosition(editor.context.languageFeaturesService.definitionProvider, model, position, false, cts.token).done(links -> {
            listener.dispose();
            contentListener.dispose();
            if (links == null || cts.token.isCancellationRequested || model.getVersionId() != versionId) {
                if (callback != null) callback(null);
                return;
            }
            final references = new ReferencesModel(links, r.localize('def.title', 'Definitions'));
            final referenceCount = references.references.length;
            if (referenceCount == 0) {
                // no result -> show message
                if (!this.configuration.muteMessage) {
                    final info = model.getWordAtPosition(position);
                    final message = info != null && info.word.length > 0
                        ? r.localize('noResultWord', "No definition found for '{0}'", [info.word])
                        : r.localize('generic.noResults', "No definition found");
                    final f = editor.context.onNoResult;
                    if (f != null) {
                        f(editor, message, position);
                    }
                }
                references.dispose();
                if (callback != null) callback(null);
            }
            else {
                // normal results handling: go to the first
                final next = references.firstReference();
                _openReference(editor, next, this.configuration.openToSide, true, target -> {
                    references.dispose();
                    if (callback != null) callback(target);
                });
            }
        }, err -> {
            listener.dispose();
            contentListener.dispose();
            Errors.onUnexpectedError(err);
            if (callback != null) callback(null);
        });
    }

    static function _openReference(editor:ICodeEditor, reference:OneReference, sideBySide:Bool, highlight:Bool, callback:(target:Null<ICodeEditor>) -> Void):Void {
        // range is the target-selection-range when we have one
        // and the fallback is the 'full' range
        var range:Null<IRange> = reference.link.targetSelectionRange;
        if (range == null) {
            range = reference.link.range;
        }
        if (range == null) {
            callback(null);
            return;
        }
        final r:IRange = range;

        editor.context.codeEditorService.openCodeEditor({
            resource: reference.uri,
            options: {
                selection: Range.collapseToStartStatic(r)
            }
        }, editor, sideBySide, targetEditor -> {
            if (targetEditor == null) {
                callback(null);
                return;
            }
            if (highlight) {
                final modelNow = targetEditor.getModel();
                final decorations = targetEditor.createDecorationsCollection([{range: r, options: {description: 'symbol-navigate-action-highlight', className: 'symbolHighlight'}}]);
                Async.setTimeout(() -> {
                    if (targetEditor.getModel() == modelNow) {
                        decorations.clear();
                    }
                }, 350);
            }
            callback(targetEditor);
        });
    }

}

/**
 * `'ctrlKey'`, `'shiftKey'`, `'altKey'` or `'metaKey'`.
 */
typedef TriggerModifier = String;

class ClickLinkOptions {

    public final triggerKey:KeyCode;
    public final triggerModifier:TriggerModifier;
    public final triggerSideBySideKey:KeyCode;
    public final triggerSideBySideModifier:TriggerModifier;

    public function new(triggerKey:KeyCode, triggerModifier:TriggerModifier, triggerSideBySideKey:KeyCode, triggerSideBySideModifier:TriggerModifier) {
        this.triggerKey = triggerKey;
        this.triggerModifier = triggerModifier;
        this.triggerSideBySideKey = triggerSideBySideKey;
        this.triggerSideBySideModifier = triggerSideBySideModifier;
    }

    public function equals(other:ClickLinkOptions):Bool {
        return (
            this.triggerKey == other.triggerKey
            && this.triggerModifier == other.triggerModifier
            && this.triggerSideBySideKey == other.triggerSideBySideKey
            && this.triggerSideBySideModifier == other.triggerSideBySideModifier
        );
    }

    public static function create(multiCursorModifier:String):ClickLinkOptions {
        if (multiCursorModifier == 'altKey') {
            if (Platform.isMacintosh) {
                return new ClickLinkOptions(KeyCode.Meta, 'metaKey', KeyCode.Alt, 'altKey');
            }
            return new ClickLinkOptions(KeyCode.Ctrl, 'ctrlKey', KeyCode.Alt, 'altKey');
        }
        if (Platform.isMacintosh) {
            return new ClickLinkOptions(KeyCode.Alt, 'altKey', KeyCode.Meta, 'metaKey');
        }
        return new ClickLinkOptions(KeyCode.Alt, 'altKey', KeyCode.Ctrl, 'ctrlKey');
    }

    public static function hasModifier(ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, modifier:TriggerModifier):Bool {
        return switch modifier {
            case 'ctrlKey': ctrlKey;
            case 'shiftKey': shiftKey;
            case 'altKey': altKey;
            case 'metaKey': metaKey;
            case _: false;
        };
    }
}

/**
 * An event that encapsulates the various trigger modifiers logic needed for go to definition.
 */
class ClickLinkMouseEvent {

    public final target:IMouseTarget;
    public final hasTriggerModifier:Bool;
    public final hasSideBySideModifier:Bool;
    public final isNoneOrSingleMouseDown:Bool;
    public final isLeftClick:Bool;
    public final isMiddleClick:Bool;
    public final isRightClick:Bool;

    public function new(source:IEditorMouseEvent, opts:ClickLinkOptions) {
        final e = source.event;
        this.target = source.target;
        this.isLeftClick = e.leftButton;
        this.isMiddleClick = e.middleButton;
        this.isRightClick = e.rightButton;
        this.hasTriggerModifier = ClickLinkOptions.hasModifier(e.ctrlKey, e.shiftKey, e.altKey, e.metaKey, opts.triggerModifier);
        this.hasSideBySideModifier = ClickLinkOptions.hasModifier(e.ctrlKey, e.shiftKey, e.altKey, e.metaKey, opts.triggerSideBySideModifier);
        this.isNoneOrSingleMouseDown = (e.detail <= 1);
    }
}

/**
 * An event that encapsulates the various trigger modifiers logic needed for go to definition.
 */
class ClickLinkKeyboardEvent {

    public final keyCodeIsTriggerKey:Bool;
    public final keyCodeIsSideBySideKey:Bool;
    public final hasTriggerModifier:Bool;

    public function new(source:IKeyboardEvent, opts:ClickLinkOptions) {
        this.keyCodeIsTriggerKey = (source.keyCode == opts.triggerKey);
        this.keyCodeIsSideBySideKey = (source.keyCode == opts.triggerSideBySideKey);
        this.hasTriggerModifier = ClickLinkOptions.hasModifier(source.ctrlKey, source.shiftKey, source.altKey, source.metaKey, opts.triggerModifier);
    }
}

/**
 * The Cmd (Ctrl) click gesture (Monaco's `ClickLinkGesture`). Monaco also
 * resets on a mouse drag (`onMouseDrag`): a drag selects text, which
 * resets through the selection change here.
 */
class ClickLinkGesture extends Disposable {

    final _onMouseMoveOrRelevantKeyDown = new Emitter<{mouseEvent:ClickLinkMouseEvent, keyboardEvent:Null<ClickLinkKeyboardEvent>}>();
    public final onMouseMoveOrRelevantKeyDown:Event<{mouseEvent:ClickLinkMouseEvent, keyboardEvent:Null<ClickLinkKeyboardEvent>}>;

    final _onExecute = new Emitter<ClickLinkMouseEvent>();
    public final onExecute:Event<ClickLinkMouseEvent>;

    final _onCancel = new VoidEmitter();
    public final onCancel:VoidEvent;

    final _editor:ICodeEditor;
    var _opts:ClickLinkOptions;
    var _lastMouseMoveEvent:Null<ClickLinkMouseEvent> = null;
    var _hasTriggerKeyOnMouseDown:Bool = false;
    var _lineNumberOnMouseDown:Int = 0;

    static function extractLineNumberFromMouseEvent(e:ClickLinkMouseEvent):Int {
        return e.target.position != null ? e.target.position.lineNumber : 0;
    }

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this.onMouseMoveOrRelevantKeyDown = _onMouseMoveOrRelevantKeyDown.event;
        this.onExecute = _onExecute.event;
        this.onCancel = _onCancel.event;
        this._register(_onMouseMoveOrRelevantKeyDown);
        this._register(_onExecute);
        this._register(_onCancel);
        this._opts = ClickLinkOptions.create(this._editor.getOption(EditorOption.multiCursorModifier));

        this._register(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.multiCursorModifier)) {
                final newOpts = ClickLinkOptions.create(this._editor.getOption(EditorOption.multiCursorModifier));
                if (this._opts.equals(newOpts)) {
                    return;
                }
                this._opts = newOpts;
                this._lastMouseMoveEvent = null;
                this._hasTriggerKeyOnMouseDown = false;
                this._lineNumberOnMouseDown = 0;
                this._onCancel.fire();
            }
        }));
        this._register(this._editor.onMouseMove(e -> this._onEditorMouseMove(new ClickLinkMouseEvent(e, this._opts))));
        this._register(this._editor.onMouseDown(e -> this._onEditorMouseDown(new ClickLinkMouseEvent(e, this._opts))));
        this._register(this._editor.onMouseUp(e -> this._onEditorMouseUp(new ClickLinkMouseEvent(e, this._opts))));
        this._register(this._editor.onKeyDown(e -> this._onEditorKeyDown(new ClickLinkKeyboardEvent(e, this._opts))));
        this._register(this._editor.onKeyUp(e -> this._onEditorKeyUp(new ClickLinkKeyboardEvent(e, this._opts))));
        this._register(this._editor.onDidChangeCursorSelection(e -> this._onDidChangeCursorSelection(e)));
        this._register(this._editor.onDidChangeModel(_ -> this._resetHandler()));
        this._register(this._editor.onDidChangeModelContent(_ -> this._resetHandler()));
        this._register(this._editor.onDidScrollChange(e -> {
            if (e.scrollTopChanged || e.scrollLeftChanged) {
                this._resetHandler();
            }
        }));
    }

    function _onDidChangeCursorSelection(e:ICursorSelectionChangedEvent):Void {
        if (e.selection != null && e.selection.startColumn != e.selection.endColumn) {
            this._resetHandler(); // immediately stop this feature if the user starts to select (https://github.com/microsoft/vscode/issues/7827)
        }
    }

    function _onEditorMouseMove(mouseEvent:ClickLinkMouseEvent):Void {
        this._lastMouseMoveEvent = mouseEvent;

        this._onMouseMoveOrRelevantKeyDown.fire({mouseEvent: mouseEvent, keyboardEvent: null});
    }

    function _onEditorMouseDown(mouseEvent:ClickLinkMouseEvent):Void {
        // We need to record if we had the trigger key on mouse down because someone might select something in the editor
        // holding the mouse down and then while mouse is down start to press Ctrl/Cmd to start a copy operation and then
        // release the mouse button without wanting to do the navigation.
        // With this flag we prevent goto definition if the mouse was down before the trigger key was pressed.
        this._hasTriggerKeyOnMouseDown = mouseEvent.hasTriggerModifier;
        this._lineNumberOnMouseDown = extractLineNumberFromMouseEvent(mouseEvent);
    }

    function _onEditorMouseUp(mouseEvent:ClickLinkMouseEvent):Void {
        final currentLineNumber = extractLineNumberFromMouseEvent(mouseEvent);
        if (this._hasTriggerKeyOnMouseDown && this._lineNumberOnMouseDown != 0 && this._lineNumberOnMouseDown == currentLineNumber) {
            this._onExecute.fire(mouseEvent);
        }
    }

    function _onEditorKeyDown(e:ClickLinkKeyboardEvent):Void {
        if (
            this._lastMouseMoveEvent != null
            && (
                e.keyCodeIsTriggerKey // User just pressed Ctrl/Cmd (normal goto definition)
                || (e.keyCodeIsSideBySideKey && e.hasTriggerModifier) // User pressed Ctrl/Cmd+Alt (goto definition to the side)
            )
        ) {
            this._onMouseMoveOrRelevantKeyDown.fire({mouseEvent: this._lastMouseMoveEvent, keyboardEvent: e});
        }
        else if (e.hasTriggerModifier) {
            this._onCancel.fire(); // remove decorations if user holds another key with ctrl/cmd to prevent accident goto declaration
        }
    }

    function _onEditorKeyUp(e:ClickLinkKeyboardEvent):Void {
        if (e.keyCodeIsTriggerKey) {
            this._onCancel.fire();
        }
    }

    function _resetHandler():Void {
        this._lastMouseMoveEvent = null;
        this._hasTriggerKeyOnMouseDown = false;
        this._onCancel.fire();
    }

}

/**
 * Underlines the symbol under the mouse while Cmd (Ctrl) is held when it
 * has a definition, with a preview of the definition in its hover, and goes
 * to it on Cmd+click (Monaco's `GotoDefinitionAtPositionEditorContribution`).
 * The definition opens in place (`definitionLinkOpensInPeek` is accepted:
 * the peek view is not ported).
 */
class GotoDefinitionAtPosition implements IEditorContribution {

    public static inline final ID = 'editor.contrib.gotodefinitionatposition';
    static inline final MAX_SOURCE_PREVIEW_LINES = 8;

    public static function get(editor:ICodeEditor):Null<GotoDefinitionAtPosition> {
        return editor.getContribution(GotoDefinitionAtPosition.ID);
    }

    final editor:ICodeEditor;
    final toUnhook = new DisposableStore();
    final toUnhookForKeyboard = new DisposableStore();
    final linkDecorations:IEditorDecorationsCollection;
    var currentWordAtPosition:Null<IWordAtPosition> = null;
    var previousToken:Null<CancellationTokenSource> = null;
    final r:EditorExtensionsRegistry;

    public function new(editor:ICodeEditor, r:EditorExtensionsRegistry) {
        this.editor = editor;
        this.r = r;
        this.linkDecorations = this.editor.createDecorationsCollection();

        final linkGesture = new ClickLinkGesture(editor);
        this.toUnhook.add(linkGesture);

        this.toUnhook.add(linkGesture.onMouseMoveOrRelevantKeyDown(e -> {
            this.startFindDefinitionFromMouse(e.mouseEvent, e.keyboardEvent);
        }));

        this.toUnhook.add(linkGesture.onExecute(mouseEvent -> {
            if (this.isEnabled(mouseEvent)) {
                this.gotoDefinition(mouseEvent.target.position, mouseEvent.hasSideBySideModifier, () -> {
                    this.removeLinkDecorations();
                });
            }
        }));

        this.toUnhook.add(linkGesture.onCancel(() -> {
            this.removeLinkDecorations();
            this.currentWordAtPosition = null;
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * The link decoration (tests).
     */
    public function getLinkRanges():Array<Range> {
        return linkDecorations.getRanges();
    }

    public function startFindDefinitionFromCursor(position:Position):Void {
        // For issue: https://github.com/microsoft/vscode/issues/46257
        // equivalent to mouse move with meta/ctrl key

        // First find the definition and add decorations
        // to the editor to be shown with the content hover widget
        this.startFindDefinition(position);

        // Add listeners for editor cursor move and key down events
        // Dismiss the "extended" editor decorations when the user hides
        // the hover widget. There is no event for the widget itself so these
        // serve as a best effort. After removing the link decorations, the hover
        // widget is clean and will only show declarations per next request.
        this.toUnhookForKeyboard.add(this.editor.onDidChangeCursorPosition(_ -> {
            this.currentWordAtPosition = null;
            this.removeLinkDecorations();
            this.toUnhookForKeyboard.clear();
        }));
        this.toUnhookForKeyboard.add(this.editor.onKeyDown(e -> {
            if (e != null) {
                this.currentWordAtPosition = null;
                this.removeLinkDecorations();
                this.toUnhookForKeyboard.clear();
            }
        }));
    }

    function startFindDefinitionFromMouse(mouseEvent:ClickLinkMouseEvent, ?withKey:ClickLinkKeyboardEvent):Void {

        // check if we are active and on a content widget
        if (mouseEvent.target.type == MouseTargetType.CONTENT_WIDGET && this.linkDecorations.length > 0) {
            return;
        }

        if (!this.editor.hasModel() || !this.isEnabled(mouseEvent, withKey)) {
            this.currentWordAtPosition = null;
            this.removeLinkDecorations();
            return;
        }

        final position = mouseEvent.target.position;

        this.startFindDefinition(position);
    }

    function startFindDefinition(position:Position):Void {

        // Dispose listeners for updating decorations when using keyboard to show definition hover
        this.toUnhookForKeyboard.clear();

        // Find word at mouse position
        final model = this.editor.getModel();
        final word = position != null && model != null ? model.getWordAtPosition(position) : null;
        if (word == null) {
            this.currentWordAtPosition = null;
            this.removeLinkDecorations();
            return;
        }

        // Return early if word at position is still the same
        if (this.currentWordAtPosition != null && this.currentWordAtPosition.startColumn == word.startColumn && this.currentWordAtPosition.endColumn == word.endColumn && this.currentWordAtPosition.word == word.word) {
            return;
        }

        this.currentWordAtPosition = word;

        // Find definition and decorate word if found
        // EditorState (Position | Value | Selection | Scroll)
        final versionId = model.getVersionId();
        final selection = this.editor.getSelection();
        final scrollTop = this.editor.getScrollTop();
        final scrollLeft = this.editor.getScrollLeft();

        if (this.previousToken != null) {
            this.previousToken.cancel();
            this.previousToken = null;
        }
        final source = new CancellationTokenSource();
        this.previousToken = source;

        GoToSymbol.getDefinitionsAtPosition(this.editor.context.languageFeaturesService.definitionProvider, model, position, false, source.token).done(results -> {
            if (source.token.isCancellationRequested) {
                return;
            }
            final stateValid = this.editor.getModel() == model && model.getVersionId() == versionId
                && this.editor.getSelection().equalsSelection(selection)
                && this.editor.getScrollTop() == scrollTop && this.editor.getScrollLeft() == scrollLeft;
            if (results == null || results.length == 0 || !stateValid) {
                this.removeLinkDecorations();
                return;
            }

            final linkRange = results[0].originSelectionRange != null
                ? Range.lift(results[0].originSelectionRange)
                : new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);

            // Multiple results
            if (results.length > 1) {

                var combinedRange = linkRange;
                for (result in results) {
                    if (result.originSelectionRange != null) {
                        combinedRange = Range.plusRangeStatic(combinedRange, result.originSelectionRange);
                    }
                }

                this.addDecoration(
                    combinedRange,
                    {value: escapeMarkdown(r.localize('multipleResults', "Click to show {0} definitions.", [results.length]))}
                );
            }
            else {
                // Single result
                final result = results[0];

                if (result.uri == null) {
                    return;
                }

                final textEditorModel = SymbolNavigation.findModel(this.editor.context, result.uri);
                if (textEditorModel == null) {
                    // the model is not open: underline without preview
                    this.addDecoration(linkRange, null);
                    return;
                }

                final startLineNumber = result.range.startLineNumber;

                if (startLineNumber < 1 || startLineNumber > textEditorModel.getLineCount()) {
                    // invalid range
                    return;
                }

                final previewValue = this.getPreviewValue(textEditorModel, startLineNumber, result);
                final languageId = textEditorModel.getLanguageId();
                this.addDecoration(
                    linkRange,
                    previewValue != null && previewValue.length > 0 ? {value: '```' + (languageId != null ? languageId : '') + '\n' + previewValue + '\n```\n'} : null
                );
            }
        }, error -> {
            Errors.onUnexpectedError(error);
        });
    }

    /**
     * Monaco's `MarkdownString.appendText` escaping.
     */
    static function escapeMarkdown(text:String):String {
        final buf = new StringBuf();
        for (i in 0...text.length) {
            final c = text.charAt(i);
            if ('\\`*_{}[]()#+-.!<>|~'.indexOf(c) >= 0) {
                buf.add('\\');
            }
            buf.add(c);
        }
        return buf.toString();
    }

    function getPreviewValue(textEditorModel:ITextModel, startLineNumber:Int, result:LocationLink):String {
        var rangeToUse:IRange = result.range;
        final numberOfLinesInRange = rangeToUse.endLineNumber - rangeToUse.startLineNumber;
        if (numberOfLinesInRange >= MAX_SOURCE_PREVIEW_LINES) {
            rangeToUse = this.getPreviewRangeBasedOnIndentation(textEditorModel, startLineNumber);
        }

        return this.stripIndentationFromPreviewRange(textEditorModel, startLineNumber, rangeToUse);
    }

    function stripIndentationFromPreviewRange(textEditorModel:ITextModel, startLineNumber:Int, previewRange:IRange):String {
        final startIndent = textEditorModel.getLineFirstNonWhitespaceColumn(startLineNumber);
        var minIndent = startIndent;

        for (endLineNumber in startLineNumber + 1...previewRange.endLineNumber) {
            final endIndent = textEditorModel.getLineFirstNonWhitespaceColumn(endLineNumber);
            minIndent = Std.int(Math.min(minIndent, endIndent));
        }

        // replace(new RegExp(`^\\s{${minIndent - 1}}`, 'gm'), '').trim()
        final count = minIndent - 1;
        final lines = textEditorModel.getValueInRange(previewRange).split('\n');
        for (i in 0...lines.length) {
            final line = lines[i];
            var n = 0;
            while (n < count && n < line.length && StringTools.isSpace(line, n)) {
                n++;
            }
            if (n == count) {
                lines[i] = line.substr(count);
            }
        }
        return StringTools.trim(lines.join('\n'));
    }

    function getPreviewRangeBasedOnIndentation(textEditorModel:ITextModel, startLineNumber:Int):Range {
        final startIndent = textEditorModel.getLineFirstNonWhitespaceColumn(startLineNumber);
        final maxLineNumber = Std.int(Math.min(textEditorModel.getLineCount(), startLineNumber + MAX_SOURCE_PREVIEW_LINES));
        var endLineNumber = startLineNumber + 1;

        while (endLineNumber < maxLineNumber) {
            final endIndent = textEditorModel.getLineFirstNonWhitespaceColumn(endLineNumber);

            if (startIndent == endIndent) {
                break;
            }
            endLineNumber++;
        }

        return new Range(startLineNumber, 1, endLineNumber + 1, 1);
    }

    function addDecoration(range:Range, hoverMessage:Null<IMarkdownString>):Void {
        this.linkDecorations.set([{
            range: range,
            options: {
                description: 'goto-definition-link',
                inlineClassName: 'goto-definition-link',
                hoverMessage: hoverMessage
            }
        }]);
    }

    function removeLinkDecorations():Void {
        this.linkDecorations.clear();
    }

    function isEnabled(mouseEvent:ClickLinkMouseEvent, ?withKey:ClickLinkKeyboardEvent):Bool {
        return this.editor.hasModel()
            && mouseEvent.isLeftClick
            && mouseEvent.isNoneOrSingleMouseDown
            && mouseEvent.target.type == MouseTargetType.CONTENT_TEXT
            && (mouseEvent.hasTriggerModifier || (withKey != null ? withKey.keyCodeIsTriggerKey : false))
            && this.editor.context.languageFeaturesService.definitionProvider.has(this.editor.getModel());
    }

    function gotoDefinition(position:Position, openToSide:Bool, done:() -> Void):Void {
        this.editor.setPosition(position);
        final action = new DefinitionAction(r, {openToSide: openToSide, openInPeek: false, muteMessage: true}, '');
        action.runOn(this.editor, _ -> done());
    }

    public function dispose():Void {
        if (this.previousToken != null) {
            this.previousToken.cancel();
        }
        this.toUnhook.dispose();
        this.toUnhookForKeyboard.dispose();
    }

}

/**
 * The registration of goToCommands.ts and goToDefinitionAtPosition.ts
 * (their module level code, for the definition). The declaration, type
 * definition, implementation and references commands are not ported yet
 * (their providers are, with `GoToSymbol`).
 * TODO(step 7): the other symbol navigation commands and the peek view.
 */
class GoToSymbolRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        if (r.context.decorationStyles.get('goto-definition-link') == null) {
            // goToDefinitionAtPosition.css
            r.context.registerDecorationStyle('goto-definition-link', {
                color: {id: 'editorLink.activeForeground'},
                underline: {color: {id: 'editorLink.activeForeground'}}
            });
        }
        if (r.context.decorationStyles.get('symbolHighlight') == null) {
            r.context.registerDecorationStyle('symbolHighlight', {
                background: {id: 'editor.symbolHighlightBackground'},
                border: {color: {id: 'editor.symbolHighlightBorder'}}
            });
        }
        r.registerEditorAction(new DefinitionAction(r));
        r.registerEditorContribution(GotoDefinitionAtPosition.ID, editor -> new GotoDefinitionAtPosition(editor, r), EditorContributionInstantiation.BeforeFirstInteraction);
    }

}
