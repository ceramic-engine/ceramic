// Ported from vscode src/vs/editor/contrib/folding/browser/indentRangeProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.RegExp;
import cityscape.common.Model.ITextModel;
import cityscape.common.languages.LanguageConfiguration.FoldingMarkers;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.model.Utils;
import cityscape.contrib.folding.view.Folding.FoldingLimitReporter;
import cityscape.contrib.folding.view.Folding.RangeProvider;
import cityscape.contrib.folding.view.FoldingRanges;
import haxe.io.UInt32Array;

class IndentRangeProvider implements RangeProvider {

    static inline final ID_INDENT_PROVIDER = 'indent';

    public var id(default, null):String = ID_INDENT_PROVIDER;

    final editorModel:ITextModel;
    final languageConfigurationService:ILanguageConfigurationService;
    final foldingRangesLimit:FoldingLimitReporter;

    public function new(editorModel:ITextModel, languageConfigurationService:ILanguageConfigurationService, foldingRangesLimit:FoldingLimitReporter) {
        this.editorModel = editorModel;
        this.languageConfigurationService = languageConfigurationService;
        this.foldingRangesLimit = foldingRangesLimit;
    }

    public function dispose():Void {}

    /**
     * Monaco returns a resolved promise: `resolve` is called at once.
     */
    public function compute(cancelationToken:CancellationToken, resolve:(regions:Null<FoldingRegions>) -> Void):Void {
        final foldingRules = languageConfigurationService.getLanguageConfiguration(editorModel.getLanguageId()).foldingRules;
        final offSide = foldingRules != null && foldingRules.offSide == true;
        final markers = foldingRules != null ? foldingRules.markers : null;
        resolve(IndentRangeProviderUtils.computeRanges(editorModel, offSide, markers, foldingRangesLimit));
    }
}

// public only for testing
class RangesCollector {
    final _startIndexes:Array<Int>;
    final _endIndexes:Array<Int>;
    final _indentOccurrences:Array<Int>;
    var _length:Int;
    final _foldingRangesLimit:FoldingLimitReporter;

    public function new(foldingRangesLimit:FoldingLimitReporter) {
        _startIndexes = [];
        _endIndexes = [];
        _indentOccurrences = [];
        _length = 0;
        _foldingRangesLimit = foldingRangesLimit;
    }

    public function insertFirst(startLineNumber:Int, endLineNumber:Int, indent:Int):Void {
        if (startLineNumber > FoldingRangesConstants.MAX_LINE_NUMBER || endLineNumber > FoldingRangesConstants.MAX_LINE_NUMBER) {
            return;
        }
        final index = _length;
        _startIndexes[index] = startLineNumber;
        _endIndexes[index] = endLineNumber;
        _length++;
        if (indent < 1000) {
            while (_indentOccurrences.length <= indent) {
                _indentOccurrences.push(0);
            }
            _indentOccurrences[indent] = _indentOccurrences[indent] + 1;
        }
    }

    public function toIndentRanges(model:ITextModel):FoldingRegions {
        final limit = _foldingRangesLimit.limit;
        if (_length <= limit) {
            _foldingRangesLimit.update(_length, null);

            // reverse and create arrays of the exact length
            final startIndexes = new UInt32Array(_length);
            final endIndexes = new UInt32Array(_length);
            var i = _length - 1, k = 0;
            while (i >= 0) {
                startIndexes[k] = _startIndexes[i];
                endIndexes[k] = _endIndexes[i];
                i--;
                k++;
            }
            return new FoldingRegions(startIndexes, endIndexes);
        }
        else {
            _foldingRangesLimit.update(_length, limit);

            var entries = 0;
            var maxIndent = _indentOccurrences.length;
            for (i in 0..._indentOccurrences.length) {
                final n = _indentOccurrences[i];
                if (n != 0) {
                    if (n + entries > limit) {
                        maxIndent = i;
                        break;
                    }
                    entries += n;
                }
            }
            final tabSize = model.getOptions().tabSize;
            // reverse and create arrays of the exact length
            final startIndexes = new UInt32Array(limit);
            final endIndexes = new UInt32Array(limit);
            var i = _length - 1, k = 0;
            while (i >= 0) {
                final startIndex = _startIndexes[i];
                final lineContent = model.getLineContent(startIndex);
                final indent = Utils.computeIndentLevel(lineContent, tabSize);
                if (indent < maxIndent || (indent == maxIndent && entries++ < limit)) {
                    startIndexes[k] = startIndex;
                    endIndexes[k] = _endIndexes[i];
                    k++;
                }
                i--;
            }
            return new FoldingRegions(startIndexes, endIndexes);
        }

    }
}

private class PreviousRegion {
    public var indent:Int; // indent or -2 if a marker
    public var endAbove:Int; // end line number for the region above
    public var line:Int; // start line of the region. Only used for marker regions.

    public function new(indent:Int, endAbove:Int, line:Int) {
        this.indent = indent;
        this.endAbove = endAbove;
        this.line = line;
    }
}

private class DefaultFoldingLimitReporter implements FoldingLimitReporter {
    public var limit(get, never):Int;
    function get_limit():Int {
        return IndentRangeProviderUtils.MAX_FOLDING_REGIONS_FOR_INDENT_DEFAULT;
    }
    public function new() {}
    public function update(computed:Int, limited:Null<Int>):Void {}
}

/**
 * Module functions of indentRangeProvider.ts.
 */
class IndentRangeProviderUtils {

    public static inline final MAX_FOLDING_REGIONS_FOR_INDENT_DEFAULT = 5000;

    static final foldingRangesLimitDefault:FoldingLimitReporter = new DefaultFoldingLimitReporter();

    public static function computeRanges(model:ITextModel, offSide:Bool, ?markers:FoldingMarkers, ?foldingRangesLimit:FoldingLimitReporter):FoldingRegions {
        final tabSize = model.getOptions().tabSize;
        final result = new RangesCollector(foldingRangesLimit != null ? foldingRangesLimit : foldingRangesLimitDefault);

        var pattern:Null<RegExp> = null;
        if (markers != null) {
            pattern = new RegExp('(' + markers.start.source + ')|(?:' + markers.end.source + ')');
        }

        final previousRegions:Array<PreviousRegion> = [];
        final sentinelLine = model.getLineCount() + 1;
        previousRegions.push(new PreviousRegion(-1, sentinelLine, sentinelLine)); // sentinel, to make sure there's at least one entry

        var line = model.getLineCount();
        while (line > 0) {
            final lineContent = model.getLineContent(line);
            final indent = Utils.computeIndentLevel(lineContent, tabSize);
            var previous = previousRegions[previousRegions.length - 1];
            if (indent == -1) {
                if (offSide) {
                    // for offSide languages, empty lines are associated to the previous block
                    // note: the next block is already written to the results, so this only
                    // impacts the end position of the block before
                    previous.endAbove = line;
                }
                line--;
                continue; // only whitespace
            }
            var m:Null<RegExpExecArray> = null;
            if (pattern != null && (m = pattern.exec(lineContent)) != null) {
                // folding pattern match
                final m1 = m[1];
                if (m1 != null && m1.length > 0) { // start pattern match
                    // discard all regions until the folding pattern
                    var i = previousRegions.length - 1;
                    while (i > 0 && previousRegions[i].indent != -2) {
                        i--;
                    }
                    if (i > 0) {
                        previousRegions.resize(i + 1);
                        previous = previousRegions[i];

                        // new folding range from pattern, includes the end line
                        result.insertFirst(line, previous.line, indent);
                        previous.line = line;
                        previous.indent = indent;
                        previous.endAbove = line;
                        line--;
                        continue;
                    }
                    else {
                        // no end marker found, treat line as a regular line
                    }
                }
                else { // end pattern match
                    previousRegions.push(new PreviousRegion(-2, line, line));
                    line--;
                    continue;
                }
            }
            if (previous.indent > indent) {
                // discard all regions with larger indent
                do {
                    previousRegions.pop();
                    previous = previousRegions[previousRegions.length - 1];
                } while (previous.indent > indent);

                // new folding range
                final endLineNumber = previous.endAbove - 1;
                if (endLineNumber - line >= 1) { // needs at east size 1
                    result.insertFirst(line, endLineNumber, indent);
                }
            }
            if (previous.indent == indent) {
                previous.endAbove = line;
            }
            else { // previous.indent < indent
                // new region with a bigger indent
                previousRegions.push(new PreviousRegion(indent, line, line));
            }
            line--;
        }
        return result.toIndentRanges(model);
    }

}
