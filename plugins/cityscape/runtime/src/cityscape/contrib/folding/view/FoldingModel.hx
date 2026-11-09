// Ported from vscode src/vs/editor/contrib/folding/browser/foldingModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.base.common.Event;
import cityscape.base.common.Hash;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.RegExp;
import cityscape.common.Model.IModelDecorationOptions;
import cityscape.common.Model.IModelDecorationsChangeAccessor;
import cityscape.common.Model.IModelDeltaDecoration;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.contrib.folding.view.Folding.SelectedLines;
import cityscape.contrib.folding.view.FoldingRanges;
import haxe.io.UInt32Array;

interface IDecorationProvider {
    function getDecorationOption(isCollapsed:Bool, isHidden:Bool, isManual:Bool):IModelDecorationOptions;
    function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T>;
    function removeDecorations(decorationIds:Array<String>):Void;
}

class FoldingModelChangeEvent {
    public final model:FoldingModel;
    public final collapseStateChanged:Null<Array<FoldingRegion>>;

    public function new(model:FoldingModel, ?collapseStateChanged:Array<FoldingRegion>) {
        this.model = model;
        this.collapseStateChanged = collapseStateChanged;
    }
}

typedef ILineMemento = {
    var startLineNumber:Int;
    var endLineNumber:Int;
    @:optional var checksum:Null<Int>;
    @:optional var isCollapsed:Null<Bool>;
    @:optional var source:Null<Int>;
}

typedef CollapseMemento = Array<ILineMemento>;

typedef RegionFilter = (r:FoldingRegion) -> Bool;
typedef RegionFilterWithLevel = (r:FoldingRegion, level:Int) -> Bool;

class FoldingModel implements IDisposable {
    final _textModel:ITextModel;
    final _decorationProvider:IDecorationProvider;

    var _regions:FoldingRegions;
    var _editorDecorationIds:Array<String>;

    final _updateEventEmitter = new Emitter<FoldingModelChangeEvent>();
    public final onDidChange:Event<FoldingModelChangeEvent>;

    public var regions(get, never):FoldingRegions;
    inline function get_regions():FoldingRegions {
        return _regions;
    }

    public var textModel(get, never):ITextModel;
    inline function get_textModel():ITextModel {
        return _textModel;
    }

    public var decorationProvider(get, never):IDecorationProvider;
    inline function get_decorationProvider():IDecorationProvider {
        return _decorationProvider;
    }

    public function new(textModel:ITextModel, decorationProvider:IDecorationProvider) {
        onDidChange = _updateEventEmitter.event;
        _textModel = textModel;
        _decorationProvider = decorationProvider;
        _regions = new FoldingRegions(new UInt32Array(0), new UInt32Array(0));
        _editorDecorationIds = [];
    }

    public function toggleCollapseState(toggledRegions:Array<FoldingRegion>):Void {
        if (toggledRegions.length == 0) {
            return;
        }
        haxe.ds.ArraySort.sort(toggledRegions, (r1, r2) -> r1.regionIndex - r2.regionIndex);

        final processed:Map<String, Bool> = new Map();
        _decorationProvider.changeDecorations(accessor -> {
            var k = 0; // index from [0 ... this.regions.length]
            var dirtyRegionEndLine = -1; // end of the range where decorations need to be updated
            var lastHiddenLine = -1; // the end of the last hidden lines
            function updateDecorationsUntil(index:Int):Void {
                while (k < index) {
                    final endLineNumber = _regions.getEndLineNumber(k);
                    final isCollapsed = _regions.isCollapsed(k);
                    if (endLineNumber <= dirtyRegionEndLine) {
                        final isManual = regions.getSource(k) != FoldSource.provider;
                        accessor.changeDecorationOptions(_editorDecorationIds[k], _decorationProvider.getDecorationOption(isCollapsed, endLineNumber <= lastHiddenLine, isManual));
                    }
                    if (isCollapsed && endLineNumber > lastHiddenLine) {
                        lastHiddenLine = endLineNumber;
                    }
                    k++;
                }
            }
            for (region in toggledRegions) {
                final index = region.regionIndex;
                final editorDecorationId = _editorDecorationIds[index];
                if (editorDecorationId != null && editorDecorationId.length > 0 && !processed.exists(editorDecorationId)) {
                    processed.set(editorDecorationId, true);

                    updateDecorationsUntil(index); // update all decorations up to current index using the old dirtyRegionEndLine

                    final newCollapseState = !_regions.isCollapsed(index);
                    _regions.setCollapsed(index, newCollapseState);

                    dirtyRegionEndLine = Std.int(Math.max(dirtyRegionEndLine, _regions.getEndLineNumber(index)));
                }
            }
            updateDecorationsUntil(_regions.length);
            return true;
        });
        _updateEventEmitter.fire(new FoldingModelChangeEvent(this, toggledRegions));
    }

    public function removeManualRanges(ranges:Array<ILineRange>):Void {
        final newFoldingRanges:Array<FoldRange> = [];
        function intersects(foldRange:FoldRange):Bool {
            for (range in ranges) {
                if (!(range.startLineNumber > foldRange.endLineNumber || foldRange.startLineNumber > range.endLineNumber)) {
                    return true;
                }
            }
            return false;
        }
        for (i in 0..._regions.length) {
            final foldRange = _regions.toFoldRange(i);
            if (foldRange.source == FoldSource.provider || !intersects(foldRange)) {
                newFoldingRanges.push(foldRange);
            }
        }
        updatePost(FoldingRegions.fromFoldRanges(newFoldingRanges));
    }

    public function update(newRegions:FoldingRegions, ?selection:SelectedLines):Void {
        final foldedOrManualRanges = _currentFoldedOrManualRanges(selection);
        final newRanges = FoldingRegions.sanitizeAndMerge(newRegions, foldedOrManualRanges, _textModel.getLineCount(), selection);
        updatePost(FoldingRegions.fromFoldRanges(newRanges));
    }

    public function updatePost(newRegions:FoldingRegions):Void {
        final newEditorDecorations:Array<IModelDeltaDecoration> = [];
        var lastHiddenLine = -1;
        for (index in 0...newRegions.length) {
            final startLineNumber = newRegions.getStartLineNumber(index);
            final endLineNumber = newRegions.getEndLineNumber(index);
            final isCollapsed = newRegions.isCollapsed(index);
            final isManual = newRegions.getSource(index) != FoldSource.provider;
            final decorationRange = new Range(
                startLineNumber,
                _textModel.getLineMaxColumn(startLineNumber),
                endLineNumber,
                _textModel.getLineMaxColumn(endLineNumber) + 1
            );
            newEditorDecorations.push({range: decorationRange, options: _decorationProvider.getDecorationOption(isCollapsed, endLineNumber <= lastHiddenLine, isManual)});
            if (isCollapsed && endLineNumber > lastHiddenLine) {
                lastHiddenLine = endLineNumber;
            }
        }
        _decorationProvider.changeDecorations(accessor -> _editorDecorationIds = accessor.deltaDecorations(_editorDecorationIds, newEditorDecorations));
        _regions = newRegions;
        _updateEventEmitter.fire(new FoldingModelChangeEvent(this));
    }

    function _currentFoldedOrManualRanges(?selection:SelectedLines):Array<FoldRange> {
        final foldedRanges:Array<FoldRange> = [];
        for (i in 0..._regions.length) {
            var isCollapsed = regions.isCollapsed(i);
            final source = regions.getSource(i);
            if (isCollapsed || source != FoldSource.provider) {
                final foldRange = _regions.toFoldRange(i);
                final decRange = _textModel.getDecorationRange(_editorDecorationIds[i]);
                if (decRange != null) {
                    if (isCollapsed && selection != null && selection.startsInside(decRange.startLineNumber + 1, decRange.endLineNumber)) {
                        isCollapsed = false; // uncollapse is the range is blocked
                    }
                    foldedRanges.push(new FoldRange(
                        decRange.startLineNumber,
                        decRange.endLineNumber,
                        foldRange.type,
                        isCollapsed,
                        source
                    ));
                }
            }
        }

        return foldedRanges;
    }

    /**
     * Collapse state memento, for persistence only
     */
    public function getMemento():Null<CollapseMemento> {
        final foldedOrManualRanges = _currentFoldedOrManualRanges();
        final result:Array<ILineMemento> = [];
        final maxLineNumber = _textModel.getLineCount();
        for (i in 0...foldedOrManualRanges.length) {
            final range = foldedOrManualRanges[i];
            if (range.startLineNumber >= range.endLineNumber || range.startLineNumber < 1 || range.endLineNumber > maxLineNumber) {
                continue;
            }
            final checksum = _getLinesChecksum(range.startLineNumber + 1, range.endLineNumber);
            result.push({
                startLineNumber: range.startLineNumber,
                endLineNumber: range.endLineNumber,
                isCollapsed: range.isCollapsed,
                source: range.source,
                checksum: checksum
            });
        }
        return (result.length > 0) ? result : null;
    }

    /**
     * Apply persisted state, for persistence only
     */
    public function applyMemento(state:Null<CollapseMemento>):Void {
        if (state == null) {
            return;
        }
        final rangesToRestore:Array<FoldRange> = [];
        final maxLineNumber = _textModel.getLineCount();
        for (range in state) {
            if (range.startLineNumber >= range.endLineNumber || range.startLineNumber < 1 || range.endLineNumber > maxLineNumber) {
                continue;
            }
            final checksum = _getLinesChecksum(range.startLineNumber + 1, range.endLineNumber);
            final rangeChecksum:Null<Int> = range.checksum;
            if (rangeChecksum == null || rangeChecksum == 0 || checksum == rangeChecksum) {
                final isCollapsed:Null<Bool> = range.isCollapsed;
                final source:Null<Int> = range.source;
                rangesToRestore.push(new FoldRange(
                    range.startLineNumber,
                    range.endLineNumber,
                    null,
                    isCollapsed != null ? isCollapsed : true,
                    source != null ? source : FoldSource.provider
                ));
            }
        }

        final newRanges = FoldingRegions.sanitizeAndMerge(_regions, rangesToRestore, maxLineNumber);
        updatePost(FoldingRegions.fromFoldRanges(newRanges));
    }

    function _getLinesChecksum(lineNumber1:Int, lineNumber2:Int):Int {
        final h = Hash.hashString(_textModel.getLineContent(lineNumber1)
            + _textModel.getLineContent(lineNumber2));
        return h % 1000000; // 6 digits is plenty
    }

    public function dispose():Void {
        _decorationProvider.removeDecorations(_editorDecorationIds);
    }

    public function getAllRegionsAtLine(lineNumber:Int, ?filter:RegionFilterWithLevel):Array<FoldingRegion> {
        final result:Array<FoldingRegion> = [];
        if (_regions != null) {
            var index = _regions.findRange(lineNumber);
            var level = 1;
            while (index >= 0) {
                final current = _regions.toRegion(index);
                if (filter == null || filter(current, level)) {
                    result.push(current);
                }
                level++;
                index = current.parentIndex;
            }
        }
        return result;
    }

    public function getRegionAtLine(lineNumber:Int):Null<FoldingRegion> {
        if (_regions != null) {
            final index = _regions.findRange(lineNumber);
            if (index >= 0) {
                return _regions.toRegion(index);
            }
        }
        return null;
    }

    /**
     * The regions inside `region` (all the regions when null) that pass
     * `filter`. Monaco takes a filter with or without a level and checks
     * its arity: the filter with a level is `getRegionsInsideWithLevel`.
     */
    public function getRegionsInside(region:Null<FoldingRegion>, ?filter:RegionFilter):Array<FoldingRegion> {
        final result:Array<FoldingRegion> = [];
        final index = region != null ? region.regionIndex + 1 : 0;
        final endLineNumber = region != null ? region.endLineNumber : 0x7FFFFFFF;

        for (i in index..._regions.length) {
            final current = _regions.toRegion(i);
            if (_regions.getStartLineNumber(i) < endLineNumber) {
                if (filter == null || filter(current)) {
                    result.push(current);
                }
            }
            else {
                break;
            }
        }
        return result;
    }

    /**
     * `getRegionsInside` with a filter taking the level of the region
     * (1 for the regions directly inside `region`).
     */
    public function getRegionsInsideWithLevel(region:Null<FoldingRegion>, filter:RegionFilterWithLevel):Array<FoldingRegion> {
        final result:Array<FoldingRegion> = [];
        final index = region != null ? region.regionIndex + 1 : 0;
        final endLineNumber = region != null ? region.endLineNumber : 0x7FFFFFFF;

        final levelStack:Array<FoldingRegion> = [];
        for (i in index..._regions.length) {
            final current = _regions.toRegion(i);
            if (_regions.getStartLineNumber(i) < endLineNumber) {
                while (levelStack.length > 0 && !current.containedBy(levelStack[levelStack.length - 1])) {
                    levelStack.pop();
                }
                levelStack.push(current);
                if (filter(current, levelStack.length)) {
                    result.push(current);
                }
            }
            else {
                break;
            }
        }
        return result;
    }

}

/**
 * Module functions of foldingModel.ts.
 */
class FoldingModelUtils {

    /**
     * Monaco's `Number.MAX_VALUE` as a number of levels.
     */
    public static inline final MAX_LEVELS = 0x7FFFFFFF;

    /**
     * Collapse or expand the regions at the given locations
     * @param levels The number of levels. Use 1 to only impact the regions at the location, use Number.MAX_VALUE for all levels.
     * @param lineNumbers the location of the regions to collapse or expand, or if not set, all regions in the model.
     */
    public static function toggleCollapseState(foldingModel:FoldingModel, levels:Int, lineNumbers:Array<Int>):Void {
        final toToggle:Array<FoldingRegion> = [];
        for (lineNumber in lineNumbers) {
            final region = foldingModel.getRegionAtLine(lineNumber);
            if (region != null) {
                final doCollapse = !region.isCollapsed;
                toToggle.push(region);
                if (levels > 1) {
                    final regionsInside = foldingModel.getRegionsInsideWithLevel(region, (r, level:Int) -> r.isCollapsed != doCollapse && level < levels);
                    for (r in regionsInside) {
                        toToggle.push(r);
                    }
                }
            }
        }
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Collapse or expand the regions at the given locations including all children.
     * @param doCollapse Whether to collapse or expand
     * @param levels The number of levels. Use 1 to only impact the regions at the location, use Number.MAX_VALUE for all levels.
     * @param lineNumbers the location of the regions to collapse or expand, or if not set, all regions in the model.
     */
    public static function setCollapseStateLevelsDown(foldingModel:FoldingModel, doCollapse:Bool, levels:Int = MAX_LEVELS, ?lineNumbers:Array<Int>):Void {
        final toToggle:Array<FoldingRegion> = [];
        if (lineNumbers != null && lineNumbers.length > 0) {
            for (lineNumber in lineNumbers) {
                final region = foldingModel.getRegionAtLine(lineNumber);
                if (region != null) {
                    if (region.isCollapsed != doCollapse) {
                        toToggle.push(region);
                    }
                    if (levels > 1) {
                        final regionsInside = foldingModel.getRegionsInsideWithLevel(region, (r, level:Int) -> r.isCollapsed != doCollapse && level < levels);
                        for (r in regionsInside) {
                            toToggle.push(r);
                        }
                    }
                }
            }
        }
        else {
            final regionsInside = foldingModel.getRegionsInsideWithLevel(null, (r, level:Int) -> r.isCollapsed != doCollapse && level < levels);
            for (r in regionsInside) {
                toToggle.push(r);
            }
        }
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Collapse or expand the regions at the given locations including all parents.
     * @param doCollapse Whether to collapse or expand
     * @param levels The number of levels. Use 1 to only impact the regions at the location, use Number.MAX_VALUE for all levels.
     * @param lineNumbers the location of the regions to collapse or expand.
     */
    public static function setCollapseStateLevelsUp(foldingModel:FoldingModel, doCollapse:Bool, levels:Int, lineNumbers:Array<Int>):Void {
        final toToggle:Array<FoldingRegion> = [];
        for (lineNumber in lineNumbers) {
            final regions = foldingModel.getAllRegionsAtLine(lineNumber, (region, level) -> region.isCollapsed != doCollapse && level <= levels);
            for (r in regions) {
                toToggle.push(r);
            }
        }
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Collapse or expand a region at the given locations. If the inner most region is already collapsed/expanded, uses the first parent instead.
     * @param doCollapse Whether to collapse or expand
     * @param lineNumbers the location of the regions to collapse or expand.
     */
    public static function setCollapseStateUp(foldingModel:FoldingModel, doCollapse:Bool, lineNumbers:Array<Int>):Void {
        final toToggle:Array<FoldingRegion> = [];
        for (lineNumber in lineNumbers) {
            final regions = foldingModel.getAllRegionsAtLine(lineNumber, (region, _) -> region.isCollapsed != doCollapse);
            if (regions.length > 0) {
                toToggle.push(regions[0]);
            }
        }
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Folds or unfolds all regions that have a given level, except if they contain one of the blocked lines.
     * @param foldLevel level. Level == 1 is the top level
     * @param doCollapse Whether to collapse or expand
     */
    public static function setCollapseStateAtLevel(foldingModel:FoldingModel, foldLevel:Int, doCollapse:Bool, blockedLineNumbers:Array<Int>):Void {
        final filter = (region:FoldingRegion, level:Int) -> {
            if (level != foldLevel || region.isCollapsed == doCollapse) {
                return false;
            }
            for (line in blockedLineNumbers) {
                if (region.containsLine(line)) {
                    return false;
                }
            }
            return true;
        };
        final toToggle = foldingModel.getRegionsInsideWithLevel(null, filter);
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Folds or unfolds all regions, except if they contain or are contained by a region of one of the blocked lines.
     * @param doCollapse Whether to collapse or expand
     * @param blockedLineNumbers the location of regions to not collapse or expand
     */
    public static function setCollapseStateForRest(foldingModel:FoldingModel, doCollapse:Bool, blockedLineNumbers:Array<Int>):Void {
        final filteredRegions:Array<FoldingRegion> = [];
        for (lineNumber in blockedLineNumbers) {
            final regions = foldingModel.getAllRegionsAtLine(lineNumber, null);
            if (regions.length > 0) {
                filteredRegions.push(regions[0]);
            }
        }
        final filter = (region:FoldingRegion) -> {
            for (filteredRegion in filteredRegions) {
                if (filteredRegion.containedBy(region) || region.containedBy(filteredRegion)) {
                    return false;
                }
            }
            return region.isCollapsed != doCollapse;
        };
        final toToggle = foldingModel.getRegionsInside(null, filter);
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Folds all regions for which the lines start with a given regex
     * @param foldingModel the folding model
     */
    public static function setCollapseStateForMatchingLines(foldingModel:FoldingModel, regExp:RegExp, doCollapse:Bool):Void {
        final editorModel = foldingModel.textModel;
        final regions = foldingModel.regions;
        final toToggle:Array<FoldingRegion> = [];
        var i = regions.length - 1;
        while (i >= 0) {
            if (doCollapse != regions.isCollapsed(i)) {
                final startLineNumber = regions.getStartLineNumber(i);
                if (regExp.test(editorModel.getLineContent(startLineNumber))) {
                    toToggle.push(regions.toRegion(i));
                }
            }
            i--;
        }
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Folds all regions of the given type
     * @param foldingModel the folding model
     */
    public static function setCollapseStateForType(foldingModel:FoldingModel, type:String, doCollapse:Bool):Void {
        final regions = foldingModel.regions;
        final toToggle:Array<FoldingRegion> = [];
        var i = regions.length - 1;
        while (i >= 0) {
            if (doCollapse != regions.isCollapsed(i) && type == regions.getType(i)) {
                toToggle.push(regions.toRegion(i));
            }
            i--;
        }
        foldingModel.toggleCollapseState(toToggle);
    }

    /**
     * Get line to go to for parent fold of current line
     * @param lineNumber the current line number
     * @param foldingModel the folding model
     *
     * @return Parent fold start line
     */
    public static function getParentFoldLine(lineNumber:Int, foldingModel:FoldingModel):Null<Int> {
        var startLineNumber:Null<Int> = null;
        final foldingRegion = foldingModel.getRegionAtLine(lineNumber);
        if (foldingRegion != null) {
            startLineNumber = foldingRegion.startLineNumber;
            // If current line is not the start of the current fold, go to top line of current fold. If not, go to parent fold
            if (lineNumber == startLineNumber) {
                final parentFoldingIdx = foldingRegion.parentIndex;
                if (parentFoldingIdx != -1) {
                    startLineNumber = foldingModel.regions.getStartLineNumber(parentFoldingIdx);
                }
                else {
                    startLineNumber = null;
                }
            }
        }
        return startLineNumber;
    }

    /**
     * Get line to go to for previous fold at the same level of current line
     * @param lineNumber the current line number
     * @param foldingModel the folding model
     *
     * @return Previous fold start line
     */
    public static function getPreviousFoldLine(lineNumber:Int, foldingModel:FoldingModel):Null<Int> {
        var foldingRegion = foldingModel.getRegionAtLine(lineNumber);
        // If on the folding range start line, go to previous sibling.
        if (foldingRegion != null && foldingRegion.startLineNumber == lineNumber) {
            // If current line is not the start of the current fold, go to top line of current fold. If not, go to previous fold.
            if (lineNumber != foldingRegion.startLineNumber) {
                return foldingRegion.startLineNumber;
            }
            else {
                // Find min line number to stay within parent.
                final expectedParentIndex = foldingRegion.parentIndex;
                var minLineNumber = 0;
                if (expectedParentIndex != -1) {
                    minLineNumber = foldingModel.regions.getStartLineNumber(foldingRegion.parentIndex);
                }

                // Find fold at same level.
                while (foldingRegion != null) {
                    if (foldingRegion.regionIndex > 0) {
                        foldingRegion = foldingModel.regions.toRegion(foldingRegion.regionIndex - 1);

                        // Keep at same level.
                        if (foldingRegion.startLineNumber <= minLineNumber) {
                            return null;
                        }
                        else if (foldingRegion.parentIndex == expectedParentIndex) {
                            return foldingRegion.startLineNumber;
                        }
                    }
                    else {
                        return null;
                    }
                }
            }
        }
        else {
            // Go to last fold that's before the current line.
            if (foldingModel.regions.length > 0) {
                foldingRegion = foldingModel.regions.toRegion(foldingModel.regions.length - 1);
                while (foldingRegion != null) {
                    // Found fold before current line.
                    if (foldingRegion.startLineNumber < lineNumber) {
                        return foldingRegion.startLineNumber;
                    }
                    if (foldingRegion.regionIndex > 0) {
                        foldingRegion = foldingModel.regions.toRegion(foldingRegion.regionIndex - 1);
                    }
                    else {
                        foldingRegion = null;
                    }
                }
            }
        }
        return null;
    }

    /**
     * Get line to go to next fold at the same level of current line
     * @param lineNumber the current line number
     * @param foldingModel the folding model
     *
     * @return Next fold start line
     */
    public static function getNextFoldLine(lineNumber:Int, foldingModel:FoldingModel):Null<Int> {
        var foldingRegion = foldingModel.getRegionAtLine(lineNumber);
        // If on the folding range start line, go to next sibling.
        if (foldingRegion != null && foldingRegion.startLineNumber == lineNumber) {
            // Find max line number to stay within parent.
            final expectedParentIndex = foldingRegion.parentIndex;
            var maxLineNumber = 0;
            if (expectedParentIndex != -1) {
                maxLineNumber = foldingModel.regions.getEndLineNumber(foldingRegion.parentIndex);
            }
            else if (foldingModel.regions.length == 0) {
                return null;
            }
            else {
                maxLineNumber = foldingModel.regions.getEndLineNumber(foldingModel.regions.length - 1);
            }

            // Find fold at same level.
            while (foldingRegion != null) {
                if (foldingRegion.regionIndex < foldingModel.regions.length) {
                    foldingRegion = foldingModel.regions.toRegion(foldingRegion.regionIndex + 1);

                    // Keep at same level.
                    if (foldingRegion.startLineNumber >= maxLineNumber) {
                        return null;
                    }
                    else if (foldingRegion.parentIndex == expectedParentIndex) {
                        return foldingRegion.startLineNumber;
                    }
                }
                else {
                    return null;
                }
            }
        }
        else {
            // Go to first fold that's after the current line.
            if (foldingModel.regions.length > 0) {
                foldingRegion = foldingModel.regions.toRegion(0);
                while (foldingRegion != null) {
                    // Found fold after current line.
                    if (foldingRegion.startLineNumber > lineNumber) {
                        return foldingRegion.startLineNumber;
                    }
                    if (foldingRegion.regionIndex < foldingModel.regions.length) {
                        foldingRegion = foldingModel.regions.toRegion(foldingRegion.regionIndex + 1);
                    }
                    else {
                        foldingRegion = null;
                    }
                }
            }
        }
        return null;
    }

}
