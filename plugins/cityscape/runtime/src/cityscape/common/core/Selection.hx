// Ported from vscode src/vs/editor/common/core/selection.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.JsValues;
import cityscape.common.core.Position.IPosition;

/**
 * A selection in the editor.
 * The selection is a range that has an orientation.
 */
typedef ISelection = {
    /**
     * The line number on which the selection has started.
     */
    final selectionStartLineNumber:Int;
    /**
     * The column on `selectionStartLineNumber` where the selection has started.
     */
    final selectionStartColumn:Int;
    /**
     * The line number on which the selection has ended.
     */
    final positionLineNumber:Int;
    /**
     * The column on `positionLineNumber` where the selection has ended.
     */
    final positionColumn:Int;
}

/**
 * The direction of a selection.
 */
enum abstract SelectionDirection(Int) from Int to Int {
    /**
     * The selection starts above where it ends.
     */
    var LTR = 0;
    /**
     * The selection starts below where it ends.
     */
    var RTL = 1;
}

/**
 * A selection in the editor.
 * The selection is a range that has an orientation.
 */
class Selection extends Range {

    /**
     * The line number on which the selection has started.
     */
    public final selectionStartLineNumber:Int;

    /**
     * The column on `selectionStartLineNumber` where the selection has started.
     */
    public final selectionStartColumn:Int;

    /**
     * The line number on which the selection has ended.
     */
    public final positionLineNumber:Int;

    /**
     * The column on `positionLineNumber` where the selection has ended.
     */
    public final positionColumn:Int;

    public function new(selectionStartLineNumber:Int, selectionStartColumn:Int, positionLineNumber:Int, positionColumn:Int) {
        super(selectionStartLineNumber, selectionStartColumn, positionLineNumber, positionColumn);
        this.selectionStartLineNumber = selectionStartLineNumber;
        this.selectionStartColumn = selectionStartColumn;
        this.positionLineNumber = positionLineNumber;
        this.positionColumn = positionColumn;
    }

    /**
     * Transform to a human-readable representation.
     */
    override public function toString():String {
        return '[' + this.selectionStartLineNumber + ',' + this.selectionStartColumn + ' -> ' + this.positionLineNumber + ',' + this.positionColumn + ']';
    }

    /**
     * Test if equals other selection.
     */
    public function equalsSelection(other:ISelection):Bool {
        return (
            this.selectionStartLineNumber == other.selectionStartLineNumber &&
            this.selectionStartColumn == other.selectionStartColumn &&
            this.positionLineNumber == other.positionLineNumber &&
            this.positionColumn == other.positionColumn
        );
    }

    /**
     * Test if the two selections are equal.
     */
    public static function selectionsEqual(a:ISelection, b:ISelection):Bool {
        return (
            a.selectionStartLineNumber == b.selectionStartLineNumber &&
            a.selectionStartColumn == b.selectionStartColumn &&
            a.positionLineNumber == b.positionLineNumber &&
            a.positionColumn == b.positionColumn
        );
    }

    /**
     * Get directions (LTR or RTL).
     */
    public function getDirection():SelectionDirection {
        if (this.selectionStartLineNumber == this.startLineNumber && this.selectionStartColumn == this.startColumn) {
            return SelectionDirection.LTR;
        }
        return SelectionDirection.RTL;
    }

    /**
     * Create a new selection with a different `positionLineNumber` and `positionColumn`.
     */
    override public function setEndPosition(endLineNumber:Int, endColumn:Int):Selection {
        if (this.getDirection() == SelectionDirection.LTR) {
            return new Selection(this.startLineNumber, this.startColumn, endLineNumber, endColumn);
        }
        return new Selection(endLineNumber, endColumn, this.startLineNumber, this.startColumn);
    }

    /**
     * Get the position at `positionLineNumber` and `positionColumn`.
     */
    public function getPosition():Position {
        return new Position(this.positionLineNumber, this.positionColumn);
    }

    /**
     * Get the position at the start of the selection.
     */
    public function getSelectionStart():Position {
        return new Position(this.selectionStartLineNumber, this.selectionStartColumn);
    }

    /**
     * Create a new selection with a different `selectionStartLineNumber` and `selectionStartColumn`.
     */
    override public function setStartPosition(startLineNumber:Int, startColumn:Int):Selection {
        if (this.getDirection() == SelectionDirection.LTR) {
            return new Selection(startLineNumber, startColumn, this.endLineNumber, this.endColumn);
        }
        return new Selection(this.endLineNumber, this.endColumn, startLineNumber, startColumn);
    }

    // ----

    /**
     * Create a `Selection` from one or two positions
     */
    public static function fromPositions(start:IPosition, ?end:IPosition):Selection {
        if (end == null)
            end = start;
        return new Selection(start.lineNumber, start.column, end.lineNumber, end.column);
    }

    /**
     * Creates a `Selection` from a range, given a direction.
     */
    public static function fromRange(range:Range, direction:SelectionDirection):Selection {
        if (direction == SelectionDirection.LTR) {
            return new Selection(range.startLineNumber, range.startColumn, range.endLineNumber, range.endColumn);
        }
        else {
            return new Selection(range.endLineNumber, range.endColumn, range.startLineNumber, range.startColumn);
        }
    }

    /**
     * Create a `Selection` from an `ISelection`.
     */
    public static function liftSelection(sel:ISelection):Selection {
        return new Selection(sel.selectionStartLineNumber, sel.selectionStartColumn, sel.positionLineNumber, sel.positionColumn);
    }

    /**
     * `a` equals `b`.
     */
    public static function selectionsArrEqual(a:Null<Array<ISelection>>, b:Null<Array<ISelection>>):Bool {
        if (a != null && b == null || a == null && b != null) {
            return false;
        }
        if (a == null && b == null) {
            return true;
        }
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!selectionsEqual(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * Test if `obj` is an `ISelection`.
     */
    public static function isISelection(obj:Any):Bool {
        return (
            JsValues.truthy(obj)
            && JsValues.isNumber(JsValues.field(obj, 'selectionStartLineNumber'))
            && JsValues.isNumber(JsValues.field(obj, 'selectionStartColumn'))
            && JsValues.isNumber(JsValues.field(obj, 'positionLineNumber'))
            && JsValues.isNumber(JsValues.field(obj, 'positionColumn'))
        );
    }

    /**
     * Create with a direction.
     */
    public static function createWithDirection(startLineNumber:Int, startColumn:Int, endLineNumber:Int, endColumn:Int, direction:SelectionDirection):Selection {
        if (direction == SelectionDirection.LTR) {
            return new Selection(startLineNumber, startColumn, endLineNumber, endColumn);
        }
        return new Selection(endLineNumber, endColumn, startLineNumber, startColumn);
    }

}
