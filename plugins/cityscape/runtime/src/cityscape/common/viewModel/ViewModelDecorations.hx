// Ported from vscode src/vs/editor/common/viewModel/viewModelDecorations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewModel;

import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.Model.ITextModel;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.ViewModel;
import cityscape.common.config.EditorConfiguration.IEditorConfiguration;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.viewModel.ViewModelLines.IViewModelLines;

typedef IDecorationsViewportData = {
    /**
     * decorations in the viewport.
     */
    final decorations:Array<ViewModelDecoration>;
    /**
     * inline decorations grouped by each line in the viewport.
     */
    final inlineDecorations:Array<Array<InlineDecoration>>;
}

class ViewModelDecorations {

    final editorId:Int;
    final model:ITextModel;
    final configuration:IEditorConfiguration;
    final _linesCollection:IViewModelLines;
    final _coordinatesConverter:ICoordinatesConverter;

    var _decorationsCache:Map<String, ViewModelDecoration>;

    var _cachedModelDecorationsResolver:Null<IDecorationsViewportData>;
    var _cachedModelDecorationsResolverViewRange:Null<Range>;

    public function new(editorId:Int, model:ITextModel, configuration:IEditorConfiguration, linesCollection:IViewModelLines, coordinatesConverter:ICoordinatesConverter) {
        this.editorId = editorId;
        this.model = model;
        this.configuration = configuration;
        this._linesCollection = linesCollection;
        this._coordinatesConverter = coordinatesConverter;
        this._decorationsCache = new Map();
        this._cachedModelDecorationsResolver = null;
        this._cachedModelDecorationsResolverViewRange = null;
    }

    function _clearCachedModelDecorationsResolver():Void {
        this._cachedModelDecorationsResolver = null;
        this._cachedModelDecorationsResolverViewRange = null;
    }

    public function dispose():Void {
        this._decorationsCache = new Map();
        this._clearCachedModelDecorationsResolver();
    }

    public function reset():Void {
        this._decorationsCache = new Map();
        this._clearCachedModelDecorationsResolver();
    }

    public function onModelDecorationsChanged():Void {
        this._decorationsCache = new Map();
        this._clearCachedModelDecorationsResolver();
    }

    public function onLineMappingChanged():Void {
        this._decorationsCache = new Map();

        this._clearCachedModelDecorationsResolver();
    }

    function _getOrCreateViewModelDecoration(modelDecoration:IModelDecoration):ViewModelDecoration {
        final id = modelDecoration.id;
        var r = this._decorationsCache.get(id);
        if (r == null) {
            final modelRange = modelDecoration.range;
            final options = modelDecoration.options;
            var viewRange:Range;
            if (options.isWholeLine == true) {
                final start = this._coordinatesConverter.convertModelPositionToViewPosition(new Position(modelRange.startLineNumber, 1), PositionAffinity.Left, false, true);
                final end = this._coordinatesConverter.convertModelPositionToViewPosition(new Position(modelRange.endLineNumber, this.model.getLineMaxColumn(modelRange.endLineNumber)), PositionAffinity.Right);
                viewRange = new Range(start.lineNumber, start.column, end.lineNumber, end.column);
            } else {
                // For backwards compatibility reasons, we want injected text before any decoration.
                // Thus, move decorations to the right.
                viewRange = this._coordinatesConverter.convertModelRangeToViewRange(modelRange, PositionAffinity.Right);
            }
            r = new ViewModelDecoration(viewRange, options);
            this._decorationsCache.set(id, r);
        }
        return r;
    }

    public function getDecorationsViewportData(viewRange:Range):IDecorationsViewportData {
        var cacheIsValid = (this._cachedModelDecorationsResolver != null);
        cacheIsValid = cacheIsValid && (viewRange.equalsRange(this._cachedModelDecorationsResolverViewRange));
        if (!cacheIsValid) {
            this._cachedModelDecorationsResolver = this._getDecorationsInRange(viewRange, false, false);
            this._cachedModelDecorationsResolverViewRange = viewRange;
        }
        return this._cachedModelDecorationsResolver;
    }

    public function getInlineDecorationsOnLine(lineNumber:Int, onlyMinimapDecorations:Bool = false, onlyMarginDecorations:Bool = false):Array<InlineDecoration> {
        final range = new Range(lineNumber, this._linesCollection.getViewLineMinColumn(lineNumber), lineNumber, this._linesCollection.getViewLineMaxColumn(lineNumber));
        return this._getDecorationsInRange(range, onlyMinimapDecorations, onlyMarginDecorations).inlineDecorations[0];
    }

    function _getDecorationsInRange(viewRange:Range, onlyMinimapDecorations:Bool, onlyMarginDecorations:Bool):IDecorationsViewportData {
        final modelDecorations = this._linesCollection.getDecorationsInRange(viewRange, this.editorId, EditorViewOptions.filterValidationDecorations(this.configuration.options), onlyMinimapDecorations, onlyMarginDecorations);
        final startLineNumber = viewRange.startLineNumber;
        final endLineNumber = viewRange.endLineNumber;

        final decorationsInViewport:Array<ViewModelDecoration> = [];
        final inlineDecorations:Array<Array<InlineDecoration>> = [];
        for (j in startLineNumber...endLineNumber + 1) {
            inlineDecorations[j - startLineNumber] = [];
        }

        for (i in 0...modelDecorations.length) {
            final modelDecoration = modelDecorations[i];
            final decorationOptions = modelDecoration.options;

            if (!ViewModelDecorations.isModelDecorationVisible(this.model, modelDecoration)) {
                continue;
            }

            final viewModelDecoration = this._getOrCreateViewModelDecoration(modelDecoration);
            final viewRange = viewModelDecoration.range;

            decorationsInViewport.push(viewModelDecoration);

            // Cityscape: a typed `inlineStyle` is an inline decoration too
            final inlineClassName = decorationOptions.inlineClassName;
            final hasInlineClassName = (inlineClassName != null && inlineClassName != '');
            if (hasInlineClassName || decorationOptions.inlineStyle != null) {
                final inlineDecoration = new InlineDecoration(viewRange, hasInlineClassName ? inlineClassName : '', decorationOptions.inlineClassNameAffectsLetterSpacing == true ? InlineDecorationType.RegularAffectingLetterSpacing : InlineDecorationType.Regular, decorationOptions.inlineStyle);
                final intersectedStartLineNumber = (startLineNumber > viewRange.startLineNumber ? startLineNumber : viewRange.startLineNumber);
                final intersectedEndLineNumber = (endLineNumber < viewRange.endLineNumber ? endLineNumber : viewRange.endLineNumber);
                for (j in intersectedStartLineNumber...intersectedEndLineNumber + 1) {
                    inlineDecorations[j - startLineNumber].push(inlineDecoration);
                }
            }
            final beforeContentClassName = decorationOptions.beforeContentClassName;
            if (beforeContentClassName != null && beforeContentClassName != '') {
                if (startLineNumber <= viewRange.startLineNumber && viewRange.startLineNumber <= endLineNumber) {
                    final inlineDecoration = new InlineDecoration(
                        new Range(viewRange.startLineNumber, viewRange.startColumn, viewRange.startLineNumber, viewRange.startColumn),
                        beforeContentClassName,
                        InlineDecorationType.Before
                    );
                    inlineDecorations[viewRange.startLineNumber - startLineNumber].push(inlineDecoration);
                }
            }
            final afterContentClassName = decorationOptions.afterContentClassName;
            if (afterContentClassName != null && afterContentClassName != '') {
                if (startLineNumber <= viewRange.endLineNumber && viewRange.endLineNumber <= endLineNumber) {
                    final inlineDecoration = new InlineDecoration(
                        new Range(viewRange.endLineNumber, viewRange.endColumn, viewRange.endLineNumber, viewRange.endColumn),
                        afterContentClassName,
                        InlineDecorationType.After
                    );
                    inlineDecorations[viewRange.endLineNumber - startLineNumber].push(inlineDecoration);
                }
            }
        }

        return {
            decorations: decorationsInViewport,
            inlineDecorations: inlineDecorations
        };
    }

    public static function isModelDecorationVisible(model:ITextModel, decoration:IModelDecoration):Bool {
        if (decoration.options.hideInCommentTokens == true && isModelDecorationInComment(model, decoration)) {
            return false;
        }

        if (decoration.options.hideInStringTokens == true && isModelDecorationInString(model, decoration)) {
            return false;
        }

        return true;
    }

    public static function isModelDecorationInComment(model:ITextModel, decoration:IModelDecoration):Bool {
        return testTokensInRange(
            model,
            decoration.range,
            (tokenType) -> tokenType == StandardTokenType.Comment
        );
    }

    public static function isModelDecorationInString(model:ITextModel, decoration:IModelDecoration):Bool {
        return testTokensInRange(
            model,
            decoration.range,
            (tokenType) -> tokenType == StandardTokenType.String
        );
    }

    /**
     * Calls the callback for every token that intersects the range.
     * If the callback returns `false`, iteration stops and `false` is returned.
     * Otherwise, `true` is returned.
     */
    static function testTokensInRange(model:ITextModel, range:Range, callback:(tokenType:StandardTokenType) -> Bool):Bool {
        for (lineNumber in range.startLineNumber...range.endLineNumber + 1) {
            final lineTokens = model.tokenization.getLineTokens(lineNumber);
            final isFirstLine = lineNumber == range.startLineNumber;
            final isEndLine = lineNumber == range.endLineNumber;

            var tokenIdx = isFirstLine ? lineTokens.findTokenIndexAtOffset(range.startColumn - 1) : 0;
            while (tokenIdx < lineTokens.getCount()) {
                if (isEndLine) {
                    final startOffset = lineTokens.getStartOffset(tokenIdx);
                    if (startOffset > range.endColumn - 1) {
                        break;
                    }
                }

                final callbackResult = callback(lineTokens.getStandardTokenType(tokenIdx));
                if (!callbackResult) {
                    return false;
                }
                tokenIdx++;
            }
        }
        return true;
    }

}
