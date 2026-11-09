// Ported from vscode src/vs/editor/contrib/folding/browser/syntaxRangeProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle.DisposableStore;
import cityscape.common.Languages.FoldingContext;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeKind;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.contrib.folding.view.Folding.FoldingLimitReporter;
import cityscape.contrib.folding.view.Folding.RangeProvider;
import cityscape.contrib.folding.view.FoldingRanges;
import haxe.io.UInt32Array;

class IFoldingRangeData {
    public final start:Int;
    public final end:Int;
    public final rank:Int;
    public final kind:Null<FoldingRangeKind>;

    public function new(start:Int, end:Int, rank:Int, kind:Null<FoldingRangeKind>) {
        this.start = start;
        this.end = end;
        this.rank = rank;
        this.kind = kind;
    }
}

class SyntaxRangeProvider implements RangeProvider {

    static inline final ID_SYNTAX_PROVIDER = 'syntax';

    static final foldingContext:FoldingContext = {};

    public var id(default, null):String = ID_SYNTAX_PROVIDER;

    public final disposables:DisposableStore;

    final editorModel:ITextModel;
    final providers:Array<FoldingRangeProvider>;
    public final handleFoldingRangesChange:() -> Void;
    final foldingRangesLimit:FoldingLimitReporter;
    final fallbackRangeProvider:Null<RangeProvider>; // used when all providers return null

    public function new(editorModel:ITextModel, providers:Array<FoldingRangeProvider>, handleFoldingRangesChange:() -> Void, foldingRangesLimit:FoldingLimitReporter, fallbackRangeProvider:Null<RangeProvider>) {
        this.editorModel = editorModel;
        this.providers = providers;
        this.handleFoldingRangesChange = handleFoldingRangesChange;
        this.foldingRangesLimit = foldingRangesLimit;
        this.fallbackRangeProvider = fallbackRangeProvider;
        disposables = new DisposableStore();
        if (fallbackRangeProvider != null) {
            disposables.add(fallbackRangeProvider);
        }

        for (provider in providers) {
            final onDidChange = provider.onDidChange;
            if (onDidChange != null) {
                disposables.add(onDidChange(_ -> handleFoldingRangesChange()));
            }
        }
    }

    /**
     * Monaco returns a promise: `resolve` is called when every provider
     * answered (at once when they all answer synchronously).
     */
    public function compute(cancellationToken:CancellationToken, resolve:(regions:Null<FoldingRegions>) -> Void):Void {
        collectSyntaxRanges(providers, editorModel, cancellationToken, ranges -> {
            if (ranges != null) {
                final res = sanitizeRanges(ranges, foldingRangesLimit);
                resolve(res);
                return;
            }
            if (fallbackRangeProvider != null) {
                fallbackRangeProvider.compute(cancellationToken, resolve);
            }
            else {
                resolve(null);
            }
        });
    }

    public function dispose():Void {
        disposables.dispose();
    }

    static function collectSyntaxRanges(providers:Array<FoldingRangeProvider>, model:ITextModel, cancellationToken:CancellationToken, done:(rangeData:Null<Array<IFoldingRangeData>>) -> Void):Void {
        var rangeData:Null<Array<IFoldingRangeData>> = null;
        // `Promise.all`: the results are added as they come, `done` runs
        // when every provider answered (or failed)
        var pending = providers.length;
        var finished = false;
        function settle():Void {
            pending--;
            if (pending == 0 && !finished) {
                finished = true;
                done(rangeData);
            }
        }
        if (pending == 0) {
            done(null);
            return;
        }
        for (i in 0...providers.length) {
            final provider = providers[i];
            var answered = false;
            try {
                provider.provideFoldingRanges(model, foldingContext, cancellationToken, ranges -> {
                    if (answered) {
                        return;
                    }
                    answered = true;
                    if (!cancellationToken.isCancellationRequested && ranges != null) {
                        if (rangeData == null) {
                            rangeData = [];
                        }
                        final nLines = model.getLineCount();
                        for (r in ranges) {
                            if (r.start > 0 && r.end > r.start && r.end <= nLines) {
                                rangeData.push(new IFoldingRangeData(r.start, r.end, i, r.kind));
                            }
                        }
                    }
                    settle();
                });
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                if (!answered) {
                    answered = true;
                    settle();
                }
            }
        }
    }

    public static function sanitizeRanges(rangeData:Array<IFoldingRangeData>, foldingRangesLimit:FoldingLimitReporter):FoldingRegions {
        final sorted = rangeData;
        haxe.ds.ArraySort.sort(sorted, (d1, d2) -> {
            var diff = d1.start - d2.start;
            if (diff == 0) {
                diff = d1.rank - d2.rank;
            }
            return diff;
        });
        final collector = new SyntaxRangesCollector(foldingRangesLimit);

        var top:Null<IFoldingRangeData> = null;
        final previous:Array<IFoldingRangeData> = [];
        for (entry in sorted) {
            if (top == null) {
                top = entry;
                collector.add(entry.start, entry.end, entry.kind != null ? entry.kind.value : null, previous.length);
            }
            else {
                if (entry.start > top.start) {
                    if (entry.end <= top.end) {
                        previous.push(top);
                        top = entry;
                        collector.add(entry.start, entry.end, entry.kind != null ? entry.kind.value : null, previous.length);
                    }
                    else {
                        if (entry.start > top.end) {
                            do {
                                top = previous.pop();
                            } while (top != null && entry.start > top.end);
                            if (top != null) {
                                previous.push(top);
                            }
                            top = entry;
                        }
                        collector.add(entry.start, entry.end, entry.kind != null ? entry.kind.value : null, previous.length);
                    }
                }
            }
        }
        return collector.toIndentRanges();
    }
}

/**
 * The `RangesCollector` of syntaxRangeProvider.ts (renamed: Haxe has one
 * namespace per package, and indentRangeProvider.ts has its own).
 */
private class SyntaxRangesCollector {
    final _startIndexes:Array<Int>;
    final _endIndexes:Array<Int>;
    final _nestingLevels:Array<Int>;
    final _nestingLevelCounts:Array<Int>;
    final _types:Array<Null<String>>;
    var _length:Int;
    final _foldingRangesLimit:FoldingLimitReporter;

    public function new(foldingRangesLimit:FoldingLimitReporter) {
        _startIndexes = [];
        _endIndexes = [];
        _nestingLevels = [];
        _nestingLevelCounts = [];
        _types = [];
        _length = 0;
        _foldingRangesLimit = foldingRangesLimit;
    }

    public function add(startLineNumber:Int, endLineNumber:Int, type:Null<String>, nestingLevel:Int):Void {
        if (startLineNumber > FoldingRangesConstants.MAX_LINE_NUMBER || endLineNumber > FoldingRangesConstants.MAX_LINE_NUMBER) {
            return;
        }
        final index = _length;
        _startIndexes[index] = startLineNumber;
        _endIndexes[index] = endLineNumber;
        _nestingLevels[index] = nestingLevel;
        _types[index] = type;
        _length++;
        if (nestingLevel < 30) {
            while (_nestingLevelCounts.length <= nestingLevel) {
                _nestingLevelCounts.push(0);
            }
            _nestingLevelCounts[nestingLevel] = _nestingLevelCounts[nestingLevel] + 1;
        }
    }

    public function toIndentRanges():FoldingRegions {
        final limit = _foldingRangesLimit.limit;
        if (_length <= limit) {
            _foldingRangesLimit.update(_length, null);

            final startIndexes = new UInt32Array(_length);
            final endIndexes = new UInt32Array(_length);
            for (i in 0..._length) {
                startIndexes[i] = _startIndexes[i];
                endIndexes[i] = _endIndexes[i];
            }
            return new FoldingRegions(startIndexes, endIndexes, _types);
        }
        else {
            _foldingRangesLimit.update(_length, limit);

            var entries = 0;
            var maxLevel = _nestingLevelCounts.length;
            for (i in 0..._nestingLevelCounts.length) {
                final n = _nestingLevelCounts[i];
                if (n != 0) {
                    if (n + entries > limit) {
                        maxLevel = i;
                        break;
                    }
                    entries += n;
                }
            }

            final startIndexes = new UInt32Array(limit);
            final endIndexes = new UInt32Array(limit);
            final types:Array<Null<String>> = [];
            var k = 0;
            for (i in 0..._length) {
                final level = _nestingLevels[i];
                if (level < maxLevel || (level == maxLevel && entries++ < limit)) {
                    startIndexes[k] = _startIndexes[i];
                    endIndexes[k] = _endIndexes[i];
                    types[k] = _types[i];
                    k++;
                }
            }
            return new FoldingRegions(startIndexes, endIndexes, types);
        }

    }

}
