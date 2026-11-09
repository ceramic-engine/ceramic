// Ported from vscode src/vs/editor/common/core/position.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.JsValues;

/**
 * A position in the editor. This interface is suitable for serialization.
 */
typedef IPosition = {
    /**
     * line number (starts at 1)
     */
    final lineNumber:Int;
    /**
     * column (the first character in a line is between column 1 and column 2)
     */
    final column:Int;
}

/**
 * A position in the editor.
 */
class Position {

    /**
     * line number (starts at 1)
     */
    public final lineNumber:Int;

    /**
     * column (the first character in a line is between column 1 and column 2)
     */
    public final column:Int;

    public function new(lineNumber:Int, column:Int) {
        this.lineNumber = lineNumber;
        this.column = column;
    }

    /**
     * Create a new position from this position.
     *
     * @param newLineNumber new line number (this position's when null)
     * @param newColumn new column (this position's when null)
     */
    public function with(?newLineNumber:Int, ?newColumn:Int):Position {
        final lineNumber:Int = newLineNumber != null ? newLineNumber : this.lineNumber;
        final column:Int = newColumn != null ? newColumn : this.column;
        if (lineNumber == this.lineNumber && column == this.column) {
            return this;
        }
        else {
            return new Position(lineNumber, column);
        }
    }

    /**
     * Derive a new position from this position.
     *
     * @param deltaLineNumber line number delta
     * @param deltaColumn column delta
     */
    public function delta(deltaLineNumber:Int = 0, deltaColumn:Int = 0):Position {
        return this.with(this.lineNumber + deltaLineNumber, this.column + deltaColumn);
    }

    /**
     * Test if this position equals other position
     */
    public function equals(other:Null<IPosition>):Bool {
        return other != null && this.lineNumber == other.lineNumber && this.column == other.column;
    }

    /**
     * Test if position `a` equals position `b` (Monaco's static
     * `Position.equals`)
     */
    public static function equalsStatic(a:Null<IPosition>, b:Null<IPosition>):Bool {
        if (a == null && b == null) {
            return true;
        }
        return (
            a != null &&
            b != null &&
            a.lineNumber == b.lineNumber &&
            a.column == b.column
        );
    }

    /**
     * Test if this position is before other position.
     * If the two positions are equal, the result will be false.
     */
    public function isBefore(other:IPosition):Bool {
        final otherLineNumber = other.lineNumber;
        if (this.lineNumber < otherLineNumber) {
            return true;
        }
        if (otherLineNumber < this.lineNumber) {
            return false;
        }
        return this.column < other.column;
    }

    /**
     * Test if position `a` is before position `b`.
     * If the two positions are equal, the result will be false.
     * (Monaco's static `Position.isBefore`)
     */
    public static function isBeforeStatic(a:IPosition, b:IPosition):Bool {
        if (a.lineNumber < b.lineNumber) {
            return true;
        }
        if (b.lineNumber < a.lineNumber) {
            return false;
        }
        return a.column < b.column;
    }

    /**
     * Test if this position is before other position.
     * If the two positions are equal, the result will be true.
     */
    public function isBeforeOrEqual(other:IPosition):Bool {
        final otherLineNumber = other.lineNumber;
        if (this.lineNumber < otherLineNumber) {
            return true;
        }
        if (otherLineNumber < this.lineNumber) {
            return false;
        }
        return this.column <= other.column;
    }

    /**
     * Test if position `a` is before position `b`.
     * If the two positions are equal, the result will be true.
     * (Monaco's static `Position.isBeforeOrEqual`)
     */
    public static function isBeforeOrEqualStatic(a:IPosition, b:IPosition):Bool {
        if (a.lineNumber < b.lineNumber) {
            return true;
        }
        if (b.lineNumber < a.lineNumber) {
            return false;
        }
        return a.column <= b.column;
    }

    /**
     * A function that compares positions, useful for sorting
     */
    public static function compare(a:IPosition, b:IPosition):Int {
        final aLineNumber = a.lineNumber;
        final bLineNumber = b.lineNumber;

        if (aLineNumber == bLineNumber) {
            final aColumn = a.column;
            final bColumn = b.column;
            return aColumn - bColumn;
        }

        return aLineNumber - bLineNumber;
    }

    /**
     * Clone this position.
     */
    public function clone():Position {
        return new Position(this.lineNumber, this.column);
    }

    /**
     * Convert to a human-readable representation.
     */
    public function toString():String {
        return '(' + this.lineNumber + ',' + this.column + ')';
    }

    // ---

    /**
     * Create a `Position` from an `IPosition`.
     */
    public static function lift(pos:IPosition):Position {
        return new Position(pos.lineNumber, pos.column);
    }

    /**
     * Test if `obj` is an `IPosition`.
     */
    public static function isIPosition(obj:Any):Bool {
        return (
            JsValues.truthy(obj)
            && JsValues.isNumber(JsValues.field(obj, 'lineNumber'))
            && JsValues.isNumber(JsValues.field(obj, 'column'))
        );
    }

    public function toJSON():IPosition {
        return {
            lineNumber: this.lineNumber,
            column: this.column
        };
    }

}
