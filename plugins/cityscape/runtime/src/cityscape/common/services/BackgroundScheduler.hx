// New code for Cityscape (not a port): the background work scheduler of a context.
// It replaces Monaco's runWhenGlobalIdle (vscode src/vs/base/common/async.ts) for the background tokenizers.
package cityscape.common.services;

import cityscape.base.common.Lifecycle.IDisposable;

/**
 * A piece of background work (the background tokenizer of a model).
 */
interface IBackgroundTask {
    /**
     * Works until `endTime` (`haxe.Timer.stamp()` seconds) or until done.
     * Returns true when there is more to do.
     */
    function runBackgroundTask(endTime:Float):Bool;
}

/**
 * Runs the background work of all the models of a `Cityscape` context with
 * one time budget per frame, shared by all of them.
 *
 * Monaco runs each model's background tokenizer in idle callbacks
 * (`runWhenGlobalIdle`, tokenizing until the idle deadline and yielding
 * every 1 to 2 ms). Ceramic has no idle callback: the scheduler runs on the
 * app's update event, before the frame is drawn, and gives the tasks at most
 * `budgetMs` milliseconds per frame. Tasks are served in turn (round robin),
 * each getting an equal share of what is left of the frame's budget, so
 * several models progress together. A task stays scheduled while it reports
 * more work.
 *
 * Viewport first, like Monaco: the lines an editor shows are tokenized
 * synchronously when its visible range changes (`IAttachedView.setVisibleLines`),
 * so the scheduler only handles the rest of the document.
 *
 * Without a Ceramic app (or before it is ready), call `runFor` to run the
 * tasks by hand.
 */
class BackgroundScheduler implements IDisposable {

    /**
     * The time all background tasks of the context may take per frame, in
     * milliseconds.
     */
    public var budgetMs:Float = 4.0;

    final _tasks:Array<IBackgroundTask> = [];

    var _next:Int = 0;

    var _listening:Bool = false;

    var _disposed:Bool = false;

    final _onUpdate:(delta:Float) -> Void;

    public function new() {
        _onUpdate = _handleUpdate;
    }

    /**
     * Adds a task (nothing happens if it is already scheduled).
     */
    public function schedule(task:IBackgroundTask):Void {
        if (_disposed) {
            return;
        }
        if (_tasks.indexOf(task) == -1) {
            _tasks.push(task);
        }
        _listen();
    }

    /**
     * Removes a task.
     */
    public function cancel(task:IBackgroundTask):Void {
        final index = _tasks.indexOf(task);
        if (index != -1) {
            _tasks.splice(index, 1);
            if (_next > index) {
                _next--;
            }
        }
        if (_tasks.length == 0) {
            _unlisten();
        }
    }

    /**
     * True when no task is scheduled.
     */
    public function isIdle():Bool {
        return _tasks.length == 0;
    }

    /**
     * The number of tasks scheduled (tests).
     */
    public function taskCount():Int {
        return _tasks.length;
    }

    public function hasTask(task:IBackgroundTask):Bool {
        return _tasks.indexOf(task) != -1;
    }

    /**
     * Runs the scheduled tasks for at most `ms` milliseconds (what a frame
     * does with `budgetMs`). Returns true when tasks remain.
     */
    public function runFor(ms:Float):Bool {
        final frameEnd = haxe.Timer.stamp() + ms / 1000.0;
        while (_tasks.length > 0) {
            final now = haxe.Timer.stamp();
            if (now >= frameEnd) {
                break;
            }
            if (_next >= _tasks.length) {
                _next = 0;
            }
            // An equal share of what is left for the tasks of this round, at least 1 ms
            final remainingInRound = _tasks.length - _next;
            var share = (frameEnd - now) / remainingInRound;
            if (share < 0.001) {
                share = 0.001;
            }
            var endTime = now + share;
            if (endTime > frameEnd) {
                endTime = frameEnd;
            }
            final task = _tasks[_next];
            var more = false;
            try {
                more = task.runBackgroundTask(endTime);
            }
            catch (e:Dynamic) {
                cityscape.base.common.Errors.onUnexpectedError(e);
                more = false;
            }
            // The task may have cancelled itself (or others) while running
            final index = _tasks.indexOf(task);
            if (index == -1) {
                continue;
            }
            if (!more) {
                _tasks.splice(index, 1);
                _next = index;
            }
            else {
                _next = index + 1;
            }
        }
        if (_tasks.length == 0) {
            _unlisten();
        }
        return _tasks.length > 0;
    }

    /**
     * Runs the scheduled tasks until none is left (tests, benchmarks).
     */
    public function runUntilIdle():Void {
        while (runFor(1000.0)) {}
    }

    public function dispose():Void {
        _disposed = true;
        _tasks.resize(0);
        _unlisten();
    }

    function _handleUpdate(delta:Float):Void {
        runFor(budgetMs);
    }

    function _listen():Void {
        if (_listening || _disposed) {
            return;
        }
        final app = ceramic.App.app;
        if (app == null) {
            return;
        }
        _listening = true;
        app.onUpdate(null, _onUpdate);
    }

    function _unlisten():Void {
        if (!_listening) {
            return;
        }
        _listening = false;
        final app = ceramic.App.app;
        if (app != null) {
            app.offUpdate(_onUpdate);
        }
    }

}
