// Ported from vscode src/vs/editor/common/viewLayout/viewLinesViewportData.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewLayout;

import cityscape.common.ViewModel;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;

/**
 * Contains all data needed to render at a specific viewport.
 */
class ViewportData {

    public final selections:Array<Selection>;

    /**
     * The line number at which to start rendering (inclusive).
     */
    public final startLineNumber:Int;

    /**
     * The line number at which to end rendering (inclusive).
     */
    public final endLineNumber:Int;

    /**
     * relativeVerticalOffset[i] is the `top` position for line at `i` + `startLineNumber`.
     */
    public final relativeVerticalOffset:Array<Float>;

    /**
     * The viewport as a range (startLineNumber,1) -> (endLineNumber,maxColumn(endLineNumber)).
     */
    public final visibleRange:Range;

    /**
     * Value to be substracted from `scrollTop` (in order to vertical offset numbers < 1MM)
     */
    public final bigNumbersDelta:Float;

    /**
     * Positioning information about gaps whitespace.
     */
    public final whitespaceViewportData:Array<IViewWhitespaceViewportData>;

    final _model:IViewModel;

    public final lineHeight:Float;

    public function new(selections:Array<Selection>, partialData:IPartialViewLinesViewportData, whitespaceViewportData:Array<IViewWhitespaceViewportData>, model:IViewModel) {
        this.selections = selections;
        this.startLineNumber = partialData.startLineNumber;
        this.endLineNumber = partialData.endLineNumber;
        this.relativeVerticalOffset = partialData.relativeVerticalOffset;
        this.bigNumbersDelta = Std.int(partialData.bigNumbersDelta);
        this.lineHeight = Std.int(partialData.lineHeight);
        this.whitespaceViewportData = whitespaceViewportData;

        this._model = model;

        this.visibleRange = new Range(
            partialData.startLineNumber,
            this._model.getLineMinColumn(partialData.startLineNumber),
            partialData.endLineNumber,
            this._model.getLineMaxColumn(partialData.endLineNumber)
        );
    }

    public function getViewLineRenderingData(lineNumber:Int):ViewLineRenderingData {
        return this._model.getViewportViewLineRenderingData(this.visibleRange, lineNumber);
    }

    public function getDecorationsInViewport():Array<ViewModelDecoration> {
        return this._model.getDecorationsInViewport(this.visibleRange);
    }

}
