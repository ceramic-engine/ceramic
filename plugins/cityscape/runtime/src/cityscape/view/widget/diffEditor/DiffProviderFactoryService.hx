// Ported from vscode src/vs/editor/browser/widget/diffEditor/diffProviderFactoryService.ts
// and the diff part of src/vs/editor/common/services/editorSimpleWorker.ts
// (EditorSimpleWorker.computeDiff).
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.LineRange;
import cityscape.common.diff.DocumentDiffProvider;
import cityscape.common.diff.LinesDiffComputer.ILinesDiffComputer;
import cityscape.common.diff.LinesDiffComputers;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;

/**
 * Where the diff is computed: Monaco computes it in its editor web worker.
 * Cityscape computes it on a background thread on the native targets
 * (`ceramic.Runner.runInBackground`, the result coming back on the main
 * thread), and on the main thread on the web, at the next frame
 * (`'deferred'`). `'synchronous'` computes it at once (tests, small texts).
 */
enum abstract DiffComputationMode(String) from String to String {
    var Background = 'background';
    var Deferred = 'deferred';
    var Synchronous = 'synchronous';
}

/**
 * Monaco's `WorkerBasedDocumentDiffProvider`, without the worker (see
 * `DiffComputationMode`) and without its global cache of results.
 *
 * `computeDiff` gives its result to `done` (Monaco returns a promise),
 * on the main thread.
 */
class WorkerBasedDocumentDiffProvider {

    final onDidChangeEventEmitter = new VoidEmitter();
    public var onDidChange(get, never):VoidEvent;
    inline function get_onDidChange() return onDidChangeEventEmitter.event;

    /**
     * `'legacy'` or `'advanced'`.
     */
    var diffAlgorithm:String = 'advanced';

    /**
     * Where the computation runs.
     */
    public var mode:DiffComputationMode;

    public function new(diffAlgorithm:String, ?mode:DiffComputationMode) {
        this.diffAlgorithm = diffAlgorithm;
        this.mode = mode != null ? mode : defaultMode();
    }

    public static function defaultMode():DiffComputationMode {
        #if (cpp || cs)
        return DiffComputationMode.Background;
        #else
        return DiffComputationMode.Deferred;
        #end
    }

    public function dispose():Void {
        onDidChangeEventEmitter.dispose();
    }

    public function computeDiff(original:ITextModel, modified:ITextModel, options:IDocumentDiffProviderOptions, cancellationToken:CancellationToken, done:(result:IDocumentDiff) -> Void):Void {
        if (original.isDisposed() || modified.isDisposed()) {
            // TODO@hediet
            done(new IDocumentDiff([], true, false, []));
            return;
        }

        // This significantly speeds up the case when the original file is empty
        if (original.getLineCount() == 1 && original.getLineMaxColumn(1) == 1) {
            if (modified.getLineCount() == 1 && modified.getLineMaxColumn(1) == 1) {
                done(new IDocumentDiff([], true, false, []));
                return;
            }

            done(new IDocumentDiff([
                new DetailedLineRangeMapping(
                    new LineRange(1, 2),
                    new LineRange(1, modified.getLineCount() + 1),
                    [
                        new RangeMapping(
                            original.getFullModelRange(),
                            modified.getFullModelRange()
                        )
                    ]
                )
            ], false, false, []));
            return;
        }

        // The worker reads the lines of its copy of the models: they are read
        // here, on the main thread
        final originalLines = original.getLinesContent();
        final modifiedLines = modified.getLinesContent();
        final algorithm = this.diffAlgorithm;

        final finish = (result:Null<IDocumentDiff>, error:Dynamic) -> {
            if (error != null) {
                Errors.onUnexpectedError(error);
            }
            if (cancellationToken.isCancellationRequested) {
                // Text models might be disposed!
                done(new IDocumentDiff([], false, true, []));
                return;
            }
            if (result == null) {
                throw 'no diff result available';
            }
            done(result);
        };

        final compute = () -> {
            try {
                return {result: computeDiffOfLines(originalLines, modifiedLines, options, algorithm), error: null};
            }
            catch (e:Dynamic) {
                return {result: null, error: e};
            }
        };

        switch (mode) {
            case DiffComputationMode.Synchronous:
                final r = compute();
                finish(r.result, r.error);
            case DiffComputationMode.Background:
                ceramic.Runner.runInBackground(() -> {
                    final r = compute();
                    ceramic.Runner.runInMain(() -> finish(r.result, r.error));
                });
            case _:
                ceramic.App.app.onceImmediate(() -> {
                    if (cancellationToken.isCancellationRequested) {
                        finish(null, null);
                        return;
                    }
                    final r = compute();
                    finish(r.result, r.error);
                });
        }
    }

    /**
     * `diffAlgorithm`: `'legacy'` or `'advanced'`.
     */
    public function setOptions(diffAlgorithm:Null<String>):Void {
        var didChange = false;
        if (diffAlgorithm != null) {
            if (this.diffAlgorithm != diffAlgorithm) {
                this.diffAlgorithm = diffAlgorithm;
                didChange = true;
            }
        }
        if (didChange) {
            this.onDidChangeEventEmitter.fire();
        }
    }

    /**
     * Monaco's `EditorSimpleWorker.computeDiff` on the lines of the two
     * models (the line changes are kept as range mappings: the worker's
     * serialization is not needed here).
     */
    public static function computeDiffOfLines(originalLines:Array<String>, modifiedLines:Array<String>, options:IDocumentDiffProviderOptions, algorithm:String):IDocumentDiff {
        final diffAlgorithm:ILinesDiffComputer = algorithm == 'advanced' ? LinesDiffComputers.getDefault() : LinesDiffComputers.getLegacy();

        final result = diffAlgorithm.computeDiff(originalLines, modifiedLines, {
            ignoreTrimWhitespace: options.ignoreTrimWhitespace,
            maxComputationTimeMs: options.maxComputationTimeMs,
            computeMoves: options.computeMoves
        });

        final identical = (result.changes.length > 0 ? false : modelsAreIdentical(originalLines, modifiedLines));

        return new IDocumentDiff(result.changes, identical, result.hitTimeout, result.moves);
    }

    static function modelsAreIdentical(originalLines:Array<String>, modifiedLines:Array<String>):Bool {
        final originalLineCount = originalLines.length;
        final modifiedLineCount = modifiedLines.length;
        if (originalLineCount != modifiedLineCount) {
            return false;
        }
        for (line in 0...originalLineCount) {
            if (originalLines[line] != modifiedLines[line]) {
                return false;
            }
        }
        return true;
    }

}
