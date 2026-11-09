// Ported from vscode src/vs/editor/contrib/hover/browser/hoverOperation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.config.EditorOptions;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * What a hover operation computes (Monaco's `IHoverComputer`): Monaco's
 * `computeAsync` gives an async iterable; here it gives each item to
 * `onItem` and calls `onDone` at the end (null when there is nothing
 * asynchronous). `computeSync` is null when there is nothing synchronous.
 */
interface IHoverComputer<T> {
    /**
     * This is called after half the hover time
     */
    var computeAsync(default, null):Null<(token:CancellationToken, onItem:(item:T) -> Void, onDone:() -> Void) -> Void>;
    /**
     * This is called after all the hover time
     */
    var computeSync(default, null):Null<() -> Array<T>>;
}

private enum abstract HoverOperationState(Int) {
    var Idle = 0;
    var FirstWait = 1;
    var SecondWait = 2;
    var WaitingForAsync = 3;
    var WaitingForAsyncShowingLoading = 4;
}

enum abstract HoverStartMode(Int) from Int to Int {
    var Delayed = 0;
    var Immediate = 1;
}

enum abstract HoverStartSource(Int) from Int to Int {
    var Mouse = 0;
    var Keyboard = 1;
}

class HoverOperationResult<T> {
    public final value:Array<T>;
    public final isComplete:Bool;
    public final hasLoadingMessage:Bool;

    public function new(value:Array<T>, isComplete:Bool, hasLoadingMessage:Bool) {
        this.value = value;
        this.isComplete = isComplete;
        this.hasLoadingMessage = hasLoadingMessage;
    }
}

/**
 * Computing the hover is very fine tuned.
 *
 * Suppose the hover delay is 300ms (the default). Then, when resting the mouse at an anchor:
 * - at 150ms, the async computation is triggered (i.e. semantic hover)
 *   - if async results already come in, they are not rendered yet.
 * - at 300ms, the sync computation is triggered (i.e. decorations, markers)
 *   - if there are sync or async results, they are rendered.
 * - at 900ms, if the async computation hasn't finished, a "Loading..." result is added.
 */
class HoverOperation<T> extends Disposable {

    final _onResult = new Emitter<HoverOperationResult<T>>();
    public final onResult:Event<HoverOperationResult<T>>;

    final _firstWaitScheduler:RunOnceScheduler;
    final _secondWaitScheduler:RunOnceScheduler;
    final _loadingMessageScheduler:RunOnceScheduler;

    var _state = HoverOperationState.Idle;
    var _asyncTokenSource:Null<CancellationTokenSource> = null;
    var _asyncIterableDone:Bool = false;
    var _result:Array<T> = [];

    final _editor:ICodeEditor;
    final _computer:IHoverComputer<T>;

    public function new(editor:ICodeEditor, computer:IHoverComputer<T>) {
        super();
        this._editor = editor;
        this._computer = computer;
        this.onResult = _onResult.event;
        this._firstWaitScheduler = this._register(new RunOnceScheduler(() -> this._triggerAsyncComputation(), 0));
        this._secondWaitScheduler = this._register(new RunOnceScheduler(() -> this._triggerSyncComputation(), 0));
        this._loadingMessageScheduler = this._register(new RunOnceScheduler(() -> this._triggerLoadingMessage(), 0));
        this._register(_onResult);
    }

    override public function dispose():Void {
        if (this._asyncTokenSource != null) {
            this._asyncTokenSource.cancel();
            this._asyncTokenSource = null;
        }
        super.dispose();
    }

    var _hoverTime(get, never):Float;
    function get__hoverTime():Float {
        return this._editor.getOption(EditorOption.hover).delay;
    }

    var _firstWaitTime(get, never):Float;
    function get__firstWaitTime():Float {
        return this._hoverTime / 2;
    }

    var _secondWaitTime(get, never):Float;
    function get__secondWaitTime():Float {
        return this._hoverTime - this._firstWaitTime;
    }

    var _loadingMessageTime(get, never):Float;
    function get__loadingMessageTime():Float {
        return 3 * this._hoverTime;
    }

    function _setState(state:HoverOperationState, fireResult:Bool = true):Void {
        this._state = state;
        if (fireResult) {
            this._fireResult();
        }
    }

    function _triggerAsyncComputation():Void {
        this._setState(HoverOperationState.SecondWait);
        this._secondWaitScheduler.schedule(this._secondWaitTime);

        final computeAsync = this._computer.computeAsync;
        if (computeAsync != null) {
            this._asyncIterableDone = false;
            final source = new CancellationTokenSource();
            this._asyncTokenSource = source;
            final token = source.token;

            try {
                computeAsync(token, item -> {
                    if (token.isCancellationRequested) {
                        return;
                    }
                    if (item != null) {
                        this._result.push(item);
                        this._fireResult();
                    }
                }, () -> {
                    if (token.isCancellationRequested) {
                        return;
                    }
                    this._asyncIterableDone = true;

                    if (this._state == HoverOperationState.WaitingForAsync || this._state == HoverOperationState.WaitingForAsyncShowingLoading) {
                        this._setState(HoverOperationState.Idle);
                    }
                });
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }

        }
        else {
            this._asyncIterableDone = true;
        }
    }

    function _triggerSyncComputation():Void {
        final computeSync = this._computer.computeSync;
        if (computeSync != null) {
            this._result = this._result.concat(computeSync());
        }
        this._setState(this._asyncIterableDone ? HoverOperationState.Idle : HoverOperationState.WaitingForAsync);
    }

    function _triggerLoadingMessage():Void {
        if (this._state == HoverOperationState.WaitingForAsync) {
            this._setState(HoverOperationState.WaitingForAsyncShowingLoading);
        }
    }

    function _fireResult():Void {
        if (this._state == HoverOperationState.FirstWait || this._state == HoverOperationState.SecondWait) {
            // Do not send out results before the hover time
            return;
        }
        final isComplete = (this._state == HoverOperationState.Idle);
        final hasLoadingMessage = (this._state == HoverOperationState.WaitingForAsyncShowingLoading);
        this._onResult.fire(new HoverOperationResult(this._result.copy(), isComplete, hasLoadingMessage));
    }

    public function start(mode:HoverStartMode):Void {
        if (mode == HoverStartMode.Delayed) {
            if (this._state == HoverOperationState.Idle) {
                this._setState(HoverOperationState.FirstWait);
                this._firstWaitScheduler.schedule(this._firstWaitTime);
                this._loadingMessageScheduler.schedule(this._loadingMessageTime);
            }
        }
        else {
            switch (this._state) {
                case HoverOperationState.Idle:
                    this._triggerAsyncComputation();
                    this._secondWaitScheduler.cancel();
                    this._triggerSyncComputation();
                case HoverOperationState.SecondWait:
                    this._secondWaitScheduler.cancel();
                    this._triggerSyncComputation();
                case _:
            }
        }
    }

    public function cancel():Void {
        this._firstWaitScheduler.cancel();
        this._secondWaitScheduler.cancel();
        this._loadingMessageScheduler.cancel();
        if (this._asyncTokenSource != null) {
            this._asyncTokenSource.cancel();
            this._asyncTokenSource = null;
        }
        this._result = [];
        this._setState(HoverOperationState.Idle, false);
    }

    /**
     * Runs the pending waits at once (tests; Monaco's tests wait for the
     * hover time).
     * @internal
     */
    public function _flush():Void {
        this._firstWaitScheduler.flush();
        this._secondWaitScheduler.flush();
    }

}
