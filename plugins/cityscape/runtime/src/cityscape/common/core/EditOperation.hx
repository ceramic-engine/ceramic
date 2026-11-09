// Ported from vscode src/vs/editor/common/core/editOperation.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.common.Model.IIdentifiedSingleEditOperation;
import cityscape.common.core.Range.IRange;

/**
 * A single edit operation, that acts as a simple replace.
 * i.e. Replace text at `range` with `text` in model.
 */
typedef ISingleEditOperation = {
    /**
     * The range to replace. This can be empty to emulate a simple insert.
     */
    var range:IRange;
    /**
     * The text to replace with. This can be null to emulate a simple delete.
     */
    var text:Null<String>;
    /**
     * This indicates that this operation has "insert" semantics.
     * i.e. forceMoveMarkers = true => if `range` is collapsed, all markers at the position will be moved.
     */
    @:optional var forceMoveMarkers:Bool;
}

/**
 * Monaco's functions return `ISingleEditOperation`s, which TypeScript also
 * accepts where an `IIdentifiedSingleEditOperation` is expected (the extra
 * fields are optional). Haxe does not: they return the identified type here,
 * which also passes as an `ISingleEditOperation`.
 */
class EditOperation {

    public static function insert(position:Position, text:String):IIdentifiedSingleEditOperation {
        return {
            range: new Range(position.lineNumber, position.column, position.lineNumber, position.column),
            text: text,
            forceMoveMarkers: true
        };
    }

    public static function delete(range:Range):IIdentifiedSingleEditOperation {
        return {
            range: range,
            text: null
        };
    }

    public static function replace(range:Range, text:Null<String>):IIdentifiedSingleEditOperation {
        return {
            range: range,
            text: text
        };
    }

    public static function replaceMove(range:Range, text:Null<String>):IIdentifiedSingleEditOperation {
        return {
            range: range,
            text: text,
            forceMoveMarkers: true
        };
    }

}
