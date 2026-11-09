// Ported from vscode src/vs/editor/contrib/parameterHints/browser/parameterHintsModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.parameterHints.view;

import cityscape.base.common.Async;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents.ICursorSelectionChangedEvent;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.SignatureHelp;
import cityscape.common.Languages.SignatureHelpContext;
import cityscape.common.Languages.SignatureHelpProvider;
import cityscape.common.Languages.SignatureHelpResult;
import cityscape.common.Languages.SignatureHelpTriggerKind;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.CharacterClassifier.CharacterSet;
import cityscape.view.EditorBrowser.ICodeEditor;

typedef TriggerContext = {
    final triggerKind:SignatureHelpTriggerKind;
    @:optional final triggerCharacter:Null<String>;
}

/**
 * `ParameterHintState.Type`
 */
enum abstract ParameterHintStateType(Int) {
    var Default = 0;
    var Active = 1;
    var Pending = 2;
}

/**
 * Monaco's `ParameterHintState.State`: `Default`, `Pending` (a request
 * and the hints active before it) or `Active` (the hints).
 */
class ParameterHintState {

    public static final Default = new ParameterHintState(ParameterHintStateType.Default, null, null, null);

    public final type:ParameterHintStateType;
    /** `Pending` */
    public final request:Null<CancelablePromise<SignatureHelpResult>>;
    /** `Pending` */
    public final previouslyActiveHints:Null<SignatureHelp>;
    /** `Active` */
    public final hints:Null<SignatureHelp>;

    function new(type:ParameterHintStateType, request:Null<CancelablePromise<SignatureHelpResult>>, previouslyActiveHints:Null<SignatureHelp>, hints:Null<SignatureHelp>) {
        this.type = type;
        this.request = request;
        this.previouslyActiveHints = previouslyActiveHints;
        this.hints = hints;
    }

    public static function pending(request:CancelablePromise<SignatureHelpResult>, previouslyActiveHints:Null<SignatureHelp>):ParameterHintState {
        return new ParameterHintState(ParameterHintStateType.Pending, request, previouslyActiveHints, null);
    }

    public static function active(hints:SignatureHelp):ParameterHintState {
        return new ParameterHintState(ParameterHintStateType.Active, null, null, hints);
    }

}

/**
 * When and with what the signature help providers are asked, and the
 * signature help shown (Monaco's `ParameterHintsModel`): triggered by the
 * trigger characters typed, retriggered by the retrigger characters, the
 * content changes and the cursor moves while it shows, throttled by a
 * `Delayer` (120 ms).
 */
class ParameterHintsModel extends Disposable {

    static inline final DEFAULT_DELAY = 120; // ms

    final _onChangedHints = new Emitter<Null<SignatureHelp>>();
    public final onChangedHints:Event<Null<SignatureHelp>>;

    final editor:ICodeEditor;
    final providers:LanguageFeatureRegistry<SignatureHelpProvider>;

    var triggerOnType = false;
    var _state:ParameterHintState = ParameterHintState.Default;
    var _pendingTriggers:Array<TriggerContext> = [];

    var _lastSignatureHelpResult:Null<SignatureHelpResult> = null;
    final triggerChars = new CharacterSet();
    final retriggerChars = new CharacterSet();

    final throttledDelayer:Delayer;
    var triggerId = 0;

    /**
     * `delay`: the throttling of the requests, in milliseconds.
     */
    public function new(editor:ICodeEditor, providers:LanguageFeatureRegistry<SignatureHelpProvider>, delay:Float = DEFAULT_DELAY) {
        super();

        this._register(this._onChangedHints);
        this.onChangedHints = this._onChangedHints.event;

        this.editor = editor;
        this.providers = providers;

        this.throttledDelayer = new Delayer(delay);

        this._register(this.editor.onDidBlurEditorWidget(() -> this.cancel()));
        this._register(this.editor.onDidChangeConfiguration(_ -> this.onEditorConfigurationChange()));
        this._register(this.editor.onDidChangeModel(_ -> this.onModelChanged()));
        this._register(this.editor.onDidChangeModelLanguage(_ -> this.onModelChanged()));
        this._register(this.editor.onDidChangeCursorSelection(e -> this.onCursorChange(e)));
        this._register(this.editor.onDidChangeModelContent(_ -> this.onModelContentChange()));
        this._register(this.providers.onDidChange(_ -> this.onModelChanged()));
        this._register(this.editor.onDidType(text -> this.onDidType(text)));

        this.onEditorConfigurationChange();
        this.onModelChanged();
    }

    var state(get, set):ParameterHintState;
    inline function get_state():ParameterHintState {
        return this._state;
    }
    function set_state(value:ParameterHintState):ParameterHintState {
        if (this._state.type == ParameterHintStateType.Pending) {
            this._state.request.cancel();
        }
        return this._state = value;
    }

    public function cancel(silent:Bool = false):Void {
        this.state = ParameterHintState.Default;

        this.throttledDelayer.cancel();

        if (!silent) {
            this._onChangedHints.fire(null);
        }
    }

    /**
     * `delay`: the throttling of this trigger, in milliseconds (the
     * default delay of the model when null).
     */
    public function trigger(context:TriggerContext, ?delay:Float):Void {
        final model = this.editor.getModel();
        if (model == null || !this.providers.has(model)) {
            return;
        }

        final triggerId = ++this.triggerId;

        this._pendingTriggers.push(context);
        this.throttledDelayer.trigger(() -> {
            try {
                this.doTrigger(triggerId);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
        }, delay);
    }

    public function next():Void {
        if (this.state.type != ParameterHintStateType.Active) {
            return;
        }

        final length = this.state.hints.signatures.length;
        final activeSignature = this.state.hints.activeSignature;
        final last = (activeSignature % length) == (length - 1);
        final cycle = this.editor.getOption(EditorOption.parameterHints).cycle;

        // If there is only one signature, or we're on last signature of list
        if ((length < 2 || last) && !cycle) {
            this.cancel();
            return;
        }

        this.updateActiveSignature(last && cycle ? 0 : activeSignature + 1);
    }

    public function previous():Void {
        if (this.state.type != ParameterHintStateType.Active) {
            return;
        }

        final length = this.state.hints.signatures.length;
        final activeSignature = this.state.hints.activeSignature;
        final first = activeSignature == 0;
        final cycle = this.editor.getOption(EditorOption.parameterHints).cycle;

        // If there is only one signature, or we're on first signature of list
        if ((length < 2 || first) && !cycle) {
            this.cancel();
            return;
        }

        this.updateActiveSignature(first && cycle ? length - 1 : activeSignature - 1);
    }

    function updateActiveSignature(activeSignature:Int):Void {
        if (this.state.type != ParameterHintStateType.Active) {
            return;
        }

        final hints = this.state.hints;
        // { ...this.state.hints, activeSignature }
        this.state = ParameterHintState.active({signatures: hints.signatures, activeSignature: activeSignature, activeParameter: hints.activeParameter});
        this._onChangedHints.fire(this.state.hints);
    }

    function doTrigger(triggerId:Int):Void {
        final isRetrigger = this.state.type == ParameterHintStateType.Active || this.state.type == ParameterHintStateType.Pending;
        final activeSignatureHelp = this.getLastActiveHints();
        this.cancel(true);

        if (this._pendingTriggers.length == 0) {
            return;
        }

        // this._pendingTriggers.reduce(mergeTriggerContexts)
        var context:TriggerContext = this._pendingTriggers[0];
        for (i in 1...this._pendingTriggers.length) {
            context = mergeTriggerContexts(context, this._pendingTriggers[i]);
        }
        this._pendingTriggers = [];

        final triggerContext:SignatureHelpContext = {
            triggerKind: context.triggerKind,
            triggerCharacter: context.triggerCharacter,
            isRetrigger: isRetrigger,
            activeSignatureHelp: activeSignatureHelp
        };

        if (!this.editor.hasModel()) {
            return;
        }

        final model = this.editor.getModel();
        final position = this.editor.getPosition();

        final request = Async.createCancelablePromise(token -> ProvideSignatureHelp.provideSignatureHelp(this.providers, model, position, triggerContext, token));
        this.state = ParameterHintState.pending(request, activeSignatureHelp);

        request.promise.done(result -> {

            // Check that we are still resolving the correct signature help
            if (triggerId != this.triggerId) {
                disposeResult(result);
                return;
            }

            if (result == null || result.value.signatures == null || result.value.signatures.length == 0) {
                disposeResult(result);
                this.clearLastSignatureHelpResult();
                this.cancel();
            }
            else {
                this.state = ParameterHintState.active(result.value);
                this.setLastSignatureHelpResult(result);
                this._onChangedHints.fire(this.state.hints);
            }
        }, error -> {
            if (triggerId == this.triggerId) {
                this.state = ParameterHintState.Default;
            }
            // Monaco's onUnexpectedError ignores cancellation errors
            if (!cityscape.base.common.Promise.CancellationError.isCancellationError(error)) {
                Errors.onUnexpectedError(error);
            }
        });
    }

    static function disposeResult(result:Null<SignatureHelpResult>):Void {
        if (result != null && result.dispose != null) {
            result.dispose();
        }
    }

    /** `_lastSignatureHelpResult.value = result` (the previous one is disposed) */
    function setLastSignatureHelpResult(result:SignatureHelpResult):Void {
        final old = this._lastSignatureHelpResult;
        this._lastSignatureHelpResult = result;
        if (old != null && old != result) {
            disposeResult(old);
        }
    }

    /** `_lastSignatureHelpResult.clear()` */
    function clearLastSignatureHelpResult():Void {
        final old = this._lastSignatureHelpResult;
        this._lastSignatureHelpResult = null;
        disposeResult(old);
    }

    function getLastActiveHints():Null<SignatureHelp> {
        return switch (this.state.type) {
            case ParameterHintStateType.Active: this.state.hints;
            case ParameterHintStateType.Pending: this.state.previouslyActiveHints;
            default: null;
        }
    }

    var isTriggered(get, never):Bool;
    function get_isTriggered():Bool {
        return this.state.type == ParameterHintStateType.Active
            || this.state.type == ParameterHintStateType.Pending
            || this.throttledDelayer.isTriggered();
    }

    function onModelChanged():Void {
        this.cancel();

        this.triggerChars.clear();
        this.retriggerChars.clear();

        final model = this.editor.getModel();
        if (model == null) {
            return;
        }

        for (support in this.providers.ordered(model)) {
            final triggerCharacters = support.signatureHelpTriggerCharacters;
            if (triggerCharacters != null) {
                for (ch in triggerCharacters) {
                    if (ch.length > 0) {
                        final charCode = StringTools.fastCodeAt(ch, 0);
                        this.triggerChars.add(charCode);

                        // All trigger characters are also considered retrigger characters
                        this.retriggerChars.add(charCode);
                    }
                }
            }

            final retriggerCharacters = support.signatureHelpRetriggerCharacters;
            if (retriggerCharacters != null) {
                for (ch in retriggerCharacters) {
                    if (ch.length > 0) {
                        this.retriggerChars.add(StringTools.fastCodeAt(ch, 0));
                    }
                }
            }
        }
    }

    function onDidType(text:String):Void {
        if (!this.triggerOnType) {
            return;
        }

        final lastCharIndex = text.length - 1;
        if (lastCharIndex < 0) {
            // text.charCodeAt(-1) is NaN in JavaScript: no trigger character
            return;
        }
        final triggerCharCode = StringTools.fastCodeAt(text, lastCharIndex);

        if (this.triggerChars.has(triggerCharCode) || this.isTriggered && this.retriggerChars.has(triggerCharCode)) {
            this.trigger({
                triggerKind: SignatureHelpTriggerKind.TriggerCharacter,
                triggerCharacter: text.charAt(lastCharIndex),
            });
        }
    }

    function onCursorChange(e:ICursorSelectionChangedEvent):Void {
        if (e.source == 'mouse') {
            this.cancel();
        }
        else if (this.isTriggered) {
            this.trigger({triggerKind: SignatureHelpTriggerKind.ContentChange});
        }
    }

    function onModelContentChange():Void {
        if (this.isTriggered) {
            this.trigger({triggerKind: SignatureHelpTriggerKind.ContentChange});
        }
    }

    function onEditorConfigurationChange():Void {
        this.triggerOnType = this.editor.getOption(EditorOption.parameterHints).enabled;

        if (!this.triggerOnType) {
            this.cancel();
        }
    }

    /**
     * Runs the pending (throttled) trigger at once (not in Monaco: tests
     * use it instead of waiting).
     */
    public function _flushPendingTrigger():Void {
        this.throttledDelayer.flush();
    }

    override public function dispose():Void {
        this.cancel(true);
        this.throttledDelayer.dispose();
        this.clearLastSignatureHelpResult();
        super.dispose();
    }

    static function mergeTriggerContexts(previous:TriggerContext, current:TriggerContext):TriggerContext {
        switch (current.triggerKind) {
            case SignatureHelpTriggerKind.Invoke:
                // Invoke overrides previous triggers.
                return current;

            case SignatureHelpTriggerKind.ContentChange:
                // Ignore content changes triggers
                return previous;

            case SignatureHelpTriggerKind.TriggerCharacter | _:
                return current;
        }
    }

}
