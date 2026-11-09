// Ported from vscode src/vs/editor/contrib/folding/browser/hiddenRangeModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.core.EolCounter;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

/**
 * The hidden areas of the collapsed regions of a folding model. Monaco's
 * ranges are `IRange`s built as `Range` instances: they are `Range`s here.
 */
class HiddenRangeModel implements IDisposable {

    final _foldingModel:FoldingModel;
    var _hiddenRanges:Array<Range>;
    var _foldingModelListener:Null<IDisposable>;
    final _updateEventEmitter = new Emitter<Array<Range>>();
    var _hasLineChanges:Bool = false;

    public var onDidChange(get, never):Event<Array<Range>>;
    inline function get_onDidChange():Event<Array<Range>> {
        return _updateEventEmitter.event;
    }

    public var hiddenRanges(get, never):Array<Range>;
    inline function get_hiddenRanges():Array<Range> {
        return _hiddenRanges;
    }

    public function new(model:FoldingModel) {
        _foldingModel = model;
        _foldingModelListener = model.onDidChange(_ -> updateHiddenRanges());
        _hiddenRanges = [];
        if (model.regions.length > 0) {
            updateHiddenRanges();
        }
    }

    public function notifyChangeModelContent(e:IModelContentChangedEvent):Void {
        if (_hiddenRanges.length > 0 && !_hasLineChanges) {
            final eol = new EolCount();
            for (change in e.changes) {
                final range = change.range;
                if (range.endLineNumber != range.startLineNumber || EolCounter.countEOL(change.text, eol).eolCount != 0) {
                    _hasLineChanges = true;
                    break;
                }
            }
        }
    }

    function updateHiddenRanges():Void {
        var updateHiddenAreas = false;
        final newHiddenAreas:Array<Range> = [];
        var i = 0; // index into hidden
        var k = 0;

        var lastCollapsedStart = 0x7FFFFFFF;
        var lastCollapsedEnd = -1;

        final ranges = _foldingModel.regions;
        while (i < ranges.length) {
            if (!ranges.isCollapsed(i)) {
                i++;
                continue;
            }

            final startLineNumber = ranges.getStartLineNumber(i) + 1; // the first line is not hidden
            final endLineNumber = ranges.getEndLineNumber(i);
            if (lastCollapsedStart <= startLineNumber && endLineNumber <= lastCollapsedEnd) {
                // ignore ranges contained in collapsed regions
                i++;
                continue;
            }

            if (!updateHiddenAreas && k < _hiddenRanges.length && _hiddenRanges[k].startLineNumber == startLineNumber && _hiddenRanges[k].endLineNumber == endLineNumber) {
                // reuse the old ranges
                newHiddenAreas.push(_hiddenRanges[k]);
                k++;
            }
            else {
                updateHiddenAreas = true;
                newHiddenAreas.push(new Range(startLineNumber, 1, endLineNumber, 1));
            }
            lastCollapsedStart = startLineNumber;
            lastCollapsedEnd = endLineNumber;
            i++;
        }
        if (_hasLineChanges || updateHiddenAreas || k < _hiddenRanges.length) {
            applyHiddenRanges(newHiddenAreas);
        }
    }

    function applyHiddenRanges(newHiddenAreas:Array<Range>):Void {
        _hiddenRanges = newHiddenAreas;
        _hasLineChanges = false;
        _updateEventEmitter.fire(newHiddenAreas);
    }

    public function hasRanges():Bool {
        return _hiddenRanges.length > 0;
    }

    public function isHidden(line:Int):Bool {
        return findRange(_hiddenRanges, line) != null;
    }

    public function adjustSelections(selections:Array<Selection>):Bool {
        var hasChanges = false;
        final editorModel = _foldingModel.textModel;
        var lastRange:Null<Range> = null;

        function adjustLine(line:Int):Int {
            if (lastRange == null || !isInside(line, lastRange)) {
                lastRange = findRange(_hiddenRanges, line);
            }
            if (lastRange != null) {
                return lastRange.startLineNumber - 1;
            }
            return 0; // Monaco's null (both are falsy)
        }
        for (i in 0...selections.length) {
            var selection = selections[i];
            final adjustedStartLine = adjustLine(selection.startLineNumber);
            if (adjustedStartLine != 0) {
                selection = selection.setStartPosition(adjustedStartLine, editorModel.getLineMaxColumn(adjustedStartLine));
                hasChanges = true;
            }
            final adjustedEndLine = adjustLine(selection.endLineNumber);
            if (adjustedEndLine != 0) {
                selection = selection.setEndPosition(adjustedEndLine, editorModel.getLineMaxColumn(adjustedEndLine));
                hasChanges = true;
            }
            selections[i] = selection;
        }
        return hasChanges;
    }

    public function dispose():Void {
        if (hiddenRanges.length > 0) {
            _hiddenRanges = [];
            _updateEventEmitter.fire(_hiddenRanges);
        }
        if (_foldingModelListener != null) {
            _foldingModelListener.dispose();
            _foldingModelListener = null;
        }
    }

    static function isInside(line:Int, range:Range):Bool {
        return line >= range.startLineNumber && line <= range.endLineNumber;
    }

    static function findRange(ranges:Array<Range>, line:Int):Null<Range> {
        // findFirstIdxMonotonousOrArrLen(ranges, r => line < r.startLineNumber) - 1
        var low = 0;
        var high = ranges.length;
        while (low < high) {
            final mid = (low + high) >> 1;
            if (line < ranges[mid].startLineNumber) {
                high = mid;
            }
            else {
                low = mid + 1;
            }
        }
        final i = low - 1;
        if (i >= 0 && ranges[i].endLineNumber >= line) {
            return ranges[i];
        }
        return null;
    }
}
