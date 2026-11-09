// Ported from vscode src/vs/editor/common/textModelGuides.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.core.Position.IPosition;

interface IGuidesTextModelPart {
    /**
     * @internal
     */
    function getActiveIndentGuide(lineNumber:Int, minLineNumber:Int, maxLineNumber:Int):IActiveIndentGuideInfo;

    /**
     * @internal
     */
    function getLinesIndentGuides(startLineNumber:Int, endLineNumber:Int):Array<Int>;

    /**
     * Requests the the indent guides for the given range of lines.
     * `result[i]` will contain the indent guides of the `startLineNumber + i`th line.
     * @internal
     */
    function getLinesBracketGuides(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>>;
}

typedef IActiveIndentGuideInfo = {
    var startLineNumber:Int;
    var endLineNumber:Int;
    var indent:Int;
}

enum abstract HorizontalGuidesState(Int) from Int to Int {
    var Disabled = 0;
    var EnabledForActive = 1;
    var Enabled = 2;
}

typedef BracketGuideOptions = {
    var includeInactive:Bool;
    var horizontalGuides:HorizontalGuidesState;
    var highlightActive:Bool;
}

class IndentGuide {

    public final visibleColumn:Int;

    public final column:Int;

    public final className:String;

    public final horizontalLine:Null<IndentGuideHorizontalLine>;

    public final forWrappedLinesAfterColumn:Int;

    public final forWrappedLinesBeforeOrAtColumn:Int;

    /**
     * `visibleColumn` and `column` are -1 when not set; exactly one of them
     * must be set.
     */
    public function new(visibleColumn:Int, column:Int, className:String, horizontalLine:Null<IndentGuideHorizontalLine>, forWrappedLinesAfterColumn:Int, forWrappedLinesBeforeOrAtColumn:Int) {
        this.visibleColumn = visibleColumn;
        this.column = column;
        this.className = className;
        this.horizontalLine = horizontalLine;
        this.forWrappedLinesAfterColumn = forWrappedLinesAfterColumn;
        this.forWrappedLinesBeforeOrAtColumn = forWrappedLinesBeforeOrAtColumn;
        if ((visibleColumn != -1) == (column != -1)) {
            throw 'IndentGuide: exactly one of visibleColumn and column must be set';
        }
    }

}

class IndentGuideHorizontalLine {

    public final top:Bool;

    public final endColumn:Int;

    public function new(top:Bool, endColumn:Int) {
        this.top = top;
        this.endColumn = endColumn;
    }

}
