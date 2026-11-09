// Ported from vscode src/vs/editor/contrib/codeAction/browser/codeActionModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.view;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.markers.common.Markers.IMarkerService;
import cityscape.view.EditorBrowser.ICodeEditor;

class CodeActionModelConstants {
    public static final SUPPORTED_CODE_ACTIONS = new RawContextKey<String>('supportedCodeAction', '');
    public static inline final APPLY_FIX_ALL_COMMAND_ID = '_typescript.applyFixAllCodeAction';
}

typedef TriggeredCodeAction = {
    final selection:Selection;
    final trigger:CodeActionTrigger;
}

class CodeActionOracle extends Disposable {

    final _autoTriggerTimer:TimeoutTimer;

    final _editor:ICodeEditor;
    final _markerService:IMarkerService;
    final _signalChange:(triggered:Null<TriggeredCodeAction>) -> Void;
    final _delay:Float;

    public function new(editor:ICodeEditor, markerService:IMarkerService, signalChange:(triggered:Null<TriggeredCodeAction>) -> Void, delay:Float = 250) {
        super();
        this._editor = editor;
        this._markerService = markerService;
        this._signalChange = signalChange;
        this._delay = delay;
        this._autoTriggerTimer = this._register(new TimeoutTimer());
        this._register(this._markerService.onMarkerChanged(e -> this._onMarkerChanges(e)));
        this._register(this._editor.onDidChangeCursorPosition(_ -> this._tryAutoTrigger()));
    }

    public function trigger(trigger:CodeActionTrigger):Void {
        final selection = this._getRangeOfSelectionUnlessWhitespaceEnclosed(trigger);
        this._signalChange(selection != null ? {trigger: trigger, selection: selection} : null);
    }

    function _onMarkerChanges(resources:Array<Uri>):Void {
        final model = this._editor.getModel();
        if (model != null) {
            final key = model.uri.toString();
            for (resource in resources) {
                if (resource.toString() == key) {
                    this._tryAutoTrigger();
                    return;
                }
            }
        }
    }

    function _tryAutoTrigger():Void {
        this._autoTriggerTimer.cancelAndSet(() -> {
            this.trigger({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default});
        }, this._delay);
    }

    /**
     * Runs the pending automatic trigger at once (tests).
     * @internal
     */
    public function _flushAutoTrigger():Void {
        this._autoTriggerTimer.flush();
    }

    static function isWhitespace(ch:String):Bool {
        if (ch == null || ch.length == 0) {
            return false;
        }
        final c = StringTools.fastCodeAt(ch, 0);
        return c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code || c == 0x0b || c == 0x0c || c == 0xa0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200a) || c == 0x2028 || c == 0x2029 || c == 0x202f || c == 0x205f || c == 0x3000 || c == 0xfeff;
    }

    function _getRangeOfSelectionUnlessWhitespaceEnclosed(trigger:CodeActionTrigger):Null<Selection> {
        if (!this._editor.hasModel()) {
            return null;
        }
        final selection = this._editor.getSelection();
        if (trigger.type == CodeActionTriggerType.Invoke) {
            return selection;
        }
        final enabled = this._editor.getOption(EditorOption.lightbulb).enabled;
        if (enabled == 'off') {
            return null;
        }
        else if (enabled == 'on') {
            return selection;
        }
        else if (enabled == 'onCode') {
            final isSelectionEmpty = selection.isEmpty();
            if (!isSelectionEmpty) {
                return selection;
            }
            final model = this._editor.getModel();
            final position = selection.getPosition();
            final lineNumber = position.lineNumber;
            final column = position.column;
            final line = model.getLineContent(lineNumber);
            if (line.length == 0) {
                // empty line
                return null;
            }
            else if (column == 1) {
                // look only right
                if (isWhitespace(line.charAt(0))) {
                    return null;
                }
            }
            else if (column == model.getLineMaxColumn(lineNumber)) {
                // look only left
                if (isWhitespace(line.charAt(line.length - 1))) {
                    return null;
                }
            }
            else {
                // look left and right
                if (isWhitespace(line.charAt(column - 2)) && isWhitespace(line.charAt(column - 1))) {
                    return null;
                }
            }
        }
        return selection;
    }
}

enum abstract CodeActionsStateType(Int) {
    var Empty = 0;
    var Triggered = 1;
}

/**
 * The state of the code actions of an editor (Monaco's
 * `CodeActionsState.State`: `Empty` or a `Triggered` request).
 */
class CodeActionsState {

    public static final Empty = new CodeActionsState(CodeActionsStateType.Empty, null, null, null);

    public final type:CodeActionsStateType;
    public final trigger:Null<CodeActionTrigger>;
    public final position:Null<Position>;
    /**
     * The code actions (an empty set when the request was cancelled).
     */
    public final actions:Null<Promise<CodeActionSet>>;
    final _cancel:Null<() -> Void>;

    function new(type:CodeActionsStateType, trigger:Null<CodeActionTrigger>, position:Null<Position>, actions:Null<Promise<CodeActionSet>>, ?cancel:() -> Void) {
        this.type = type;
        this.trigger = trigger;
        this.position = position;
        this.actions = actions;
        this._cancel = cancel;
    }

    public static function triggered(trigger:CodeActionTrigger, position:Position, actions:Promise<CodeActionSet>, cancel:() -> Void):CodeActionsState {
        return new CodeActionsState(CodeActionsStateType.Triggered, trigger, position, actions.catchError(e -> {
            if (CancellationError.isCancellationError(e)) {
                return emptyCodeActionSet();
            }
            throw e;
        }), cancel);
    }

    public function cancel():Void {
        if (_cancel != null) {
            _cancel();
        }
    }

    public static function emptyCodeActionSet():CodeActionSet {
        return new ManagedCodeActionSet([], [], new DisposableStore());
    }
}

/**
 * A set of code actions with a list replaced (the nearby quick fixes).
 */
private class DerivedCodeActionSet implements CodeActionSet {
    public var validActions(default, null):Array<CodeActionItem>;
    public var allActions(default, null):Array<CodeActionItem>;
    public var documentation(default, null):Array<Command>;
    final source:CodeActionSet;

    public function new(source:CodeActionSet, validActions:Array<CodeActionItem>, allActions:Array<CodeActionItem>) {
        this.source = source;
        this.validActions = validActions;
        this.allActions = allActions;
        this.documentation = source.documentation;
    }

    public var hasAutoFix(get, never):Bool;
    function get_hasAutoFix():Bool {
        return source.hasAutoFix;
    }

    public var hasAIFix(get, never):Bool;
    function get_hasAIFix():Bool {
        return source.hasAIFix;
    }

    public var allAIFixes(get, never):Bool;
    function get_allAIFixes():Bool {
        return source.allAIFixes;
    }

    public function dispose():Void {
        source.dispose();
    }
}

/**
 * Requests the code actions at the selection when it moves or when the
 * markers change, and when asked (Monaco's `CodeActionModel`). The
 * `editor.codeActionWidget.includeNearbyQuickFixes` setting of VS Code is
 * on (its default): a quick fix request on a line with markers also
 * offers the quick fixes of those markers.
 */
class CodeActionModel extends Disposable {

    final _codeActionOracle = new MutableDisposable<CodeActionOracle>();
    var _state:CodeActionsState = CodeActionsState.Empty;

    final _supportedCodeActions:IContextKey<String>;

    final _onDidChangeState = new Emitter<CodeActionsState>();
    public final onDidChangeState:Event<CodeActionsState>;

    var _disposed = false;

    final _editor:ICodeEditor;
    final _registry:LanguageFeatureRegistry<CodeActionProvider>;
    final _markerService:IMarkerService;

    /**
     * Whether the nearby quick fixes are included (VS Code's
     * `editor.codeActionWidget.includeNearbyQuickFixes`).
     */
    public var includeNearbyQuickFixes:Bool = true;

    public function new(editor:ICodeEditor, registry:LanguageFeatureRegistry<CodeActionProvider>, markerService:IMarkerService, contextKeyService:IContextKeyService) {
        super();
        this._editor = editor;
        this._registry = registry;
        this._markerService = markerService;
        this.onDidChangeState = _onDidChangeState.event;
        this._register(_codeActionOracle);
        this._register(_onDidChangeState);
        this._supportedCodeActions = CodeActionModelConstants.SUPPORTED_CODE_ACTIONS.bindTo(contextKeyService);

        this._register(this._editor.onDidChangeModel(_ -> this._update()));
        this._register(this._editor.onDidChangeModelLanguage(_ -> this._update()));
        this._register(this._registry.onDidChange(_ -> this._update()));
        this._register(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.lightbulb)) {
                this._update();
            }
        }));
        this._update();
    }

    override public function dispose():Void {
        if (this._disposed) {
            return;
        }
        this._disposed = true;

        super.dispose();
        this.setState(CodeActionsState.Empty, true);
    }

    /**
     * The oracle (tests run its pending automatic trigger).
     * @internal
     */
    public function _getOracle():Null<CodeActionOracle> {
        return _codeActionOracle.value;
    }

    function _computeActions(model:cityscape.common.Model.ITextModel, trigger:TriggeredCodeAction, token:CancellationToken):Promise<CodeActionSet> {
        final quickFixFilter = trigger.trigger.filter != null && trigger.trigger.filter.include != null && trigger.trigger.filter.include.contains(CodeActionKind.QuickFix);
        if (this.includeNearbyQuickFixes && trigger.trigger.type == CodeActionTriggerType.Invoke && (trigger.trigger.triggerAction == CodeActionTriggerSource.QuickFix || quickFixFilter)) {
            return CodeActionUtils.getCodeActions(this._registry, model, trigger.selection, trigger.trigger, null, token).thenPromise(codeActionSet -> {
                final allCodeActions = codeActionSet.allActions.copy();
                if (token.isCancellationRequested) {
                    return Promise.resolve(CodeActionsState.emptyCodeActionSet());
                }

                // Search for quickfixes in the curret code action set.
                var foundQuickfix = false;
                for (action in codeActionSet.validActions) {
                    if (action.action.kind != null && action.action.kind.length > 0 && CodeActionKind.QuickFix.contains(new HierarchicalKind(action.action.kind))) {
                        foundQuickfix = true;
                        break;
                    }
                }
                final allMarkers = this._markerService.read({resource: model.uri});
                if (foundQuickfix) {
                    return Promise.resolve((new DerivedCodeActionSet(codeActionSet, codeActionSet.validActions, allCodeActions) : CodeActionSet));
                }
                // If markers exists, and there are no quickfixes found or length is zero, check for quickfixes on that line.
                if (allMarkers.length == 0) {
                    return Promise.resolve(codeActionSet);
                }
                final currPosition = trigger.selection.getPosition();
                var distance = Math.POSITIVE_INFINITY;
                final currentActions = codeActionSet.validActions.copy();

                final markersOnLine = [for (marker in allMarkers) if (marker.endLineNumber == currPosition.lineNumber || marker.startLineNumber == currPosition.lineNumber) marker];
                function next(index:Int):Promise<CodeActionSet> {
                    if (index >= markersOnLine.length) {
                        final seen = new Map<String, Bool>();
                        final filteredActions = [for (action in currentActions) if (!seen.exists(action.action.title)) {
                            seen.set(action.action.title, true);
                            action;
                        }];
                        haxe.ds.ArraySort.sort(filteredActions, (a, b) -> {
                            if (a.action.isPreferred == true && b.action.isPreferred != true) {
                                return -1;
                            }
                            else if (a.action.isPreferred != true && b.action.isPreferred == true) {
                                return 1;
                            }
                            else if (a.action.isAI == true && b.action.isAI != true) {
                                return 1;
                            }
                            else if (a.action.isAI != true && b.action.isAI == true) {
                                return -1;
                            }
                            return 0;
                        });
                        // Only retriggers if actually found quickfix on the same line as cursor
                        return Promise.resolve((new DerivedCodeActionSet(codeActionSet, filteredActions, allCodeActions) : CodeActionSet));
                    }
                    final marker = markersOnLine[index];
                    final col = marker.endColumn;
                    final row = marker.endLineNumber;
                    // Found quickfix on the same line and check relative distance to other markers
                    final trackedPosition = new Position(row, col);
                    final newCodeActionTrigger:CodeActionTrigger = {
                        type: trigger.trigger.type,
                        triggerAction: trigger.trigger.triggerAction,
                        filter: {include: trigger.trigger.filter != null && trigger.trigger.filter.include != null ? trigger.trigger.filter.include : CodeActionKind.QuickFix},
                        autoApply: trigger.trigger.autoApply,
                        context: {notAvailableMessage: trigger.trigger.context != null ? trigger.trigger.context.notAvailableMessage : '', position: trackedPosition}
                    };
                    final selectionAsPosition = new Selection(trackedPosition.lineNumber, trackedPosition.column, trackedPosition.lineNumber, trackedPosition.column);
                    return CodeActionUtils.getCodeActions(this._registry, model, selectionAsPosition, newCodeActionTrigger, null, token).thenPromise(actionsAtMarker -> {
                        if (actionsAtMarker.validActions.length != 0) {
                            if (codeActionSet.allActions.length == 0) {
                                for (a in actionsAtMarker.allActions) {
                                    allCodeActions.push(a);
                                }
                            }
                            // Already filtered through to only get quickfixes, so no need to filter again.
                            if (Math.abs(currPosition.column - col) < distance) {
                                final valid = actionsAtMarker.validActions;
                                var i = valid.length - 1;
                                while (i >= 0) {
                                    currentActions.unshift(valid[i]);
                                    i--;
                                }
                            }
                            else {
                                for (a in actionsAtMarker.validActions) {
                                    currentActions.push(a);
                                }
                            }
                        }
                        distance = Math.abs(currPosition.column - col);
                        return next(index + 1);
                    });
                }
                return next(0);
            });
        }

        return CodeActionUtils.getCodeActions(this._registry, model, trigger.selection, trigger.trigger, null, token);
    }

    function _update():Void {
        if (this._disposed) {
            return;
        }

        this._codeActionOracle.value = null;

        this.setState(CodeActionsState.Empty);

        final model = this._editor.getModel();
        if (model != null
            && this._registry.has(model)
            && !this._editor.getOption(EditorOption.readOnly)
        ) {
            final supportedActions:Array<String> = [];
            for (provider in this._registry.all(model)) {
                if (provider.providedCodeActionKinds != null) {
                    for (kind in provider.providedCodeActionKinds) {
                        supportedActions.push(kind);
                    }
                }
            }
            this._supportedCodeActions.set(supportedActions.join(' '));

            this._codeActionOracle.value = new CodeActionOracle(this._editor, this._markerService, trigger -> {
                if (trigger == null) {
                    this.setState(CodeActionsState.Empty);
                    return;
                }

                final startPosition = trigger.selection.getStartPosition();

                final source = new CancellationTokenSource();
                final actions = this._computeActions(model, trigger, source.token);
                final newState = CodeActionsState.triggered(trigger.trigger, startPosition, actions, () -> source.cancel());
                var isManualToAutoTransition = false;
                if (this._state.type == CodeActionsStateType.Triggered) {
                    // Check if the current state is manual and the new state is automatic
                    isManualToAutoTransition = this._state.trigger.type == CodeActionTriggerType.Invoke
                        && newState.trigger.type == CodeActionTriggerType.Auto
                        && this._state.position != newState.position;
                }

                // Do not trigger state if current state is manual and incoming state is automatic
                if (!isManualToAutoTransition) {
                    this.setState(newState);
                }
                else {
                    // Reset the new state after getting code actions back.
                    Async.setTimeout(() -> {
                        this.setState(newState);
                    }, 500);
                }
            });
            this._codeActionOracle.value.trigger({type: CodeActionTriggerType.Auto, triggerAction: CodeActionTriggerSource.Default});
        }
        else {
            this._supportedCodeActions.reset();
        }
    }

    public function trigger(trigger:CodeActionTrigger):Void {
        final oracle = this._codeActionOracle.value;
        if (oracle != null) {
            oracle.trigger(trigger);
        }
    }

    function setState(newState:CodeActionsState, skipNotify:Bool = false):Void {
        if (newState == this._state) {
            return;
        }

        // Cancel old request
        if (this._state.type == CodeActionsStateType.Triggered) {
            this._state.cancel();
        }

        this._state = newState;

        if (!skipNotify && !this._disposed) {
            this._onDidChangeState.fire(newState);
        }
    }

}
