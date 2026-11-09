// Ported from vscode src/vs/editor/common/cursorCommon.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.Model.PositionAffinity;
import cityscape.common.core.Position;

/**
 * Types of cursorCommon.ts used by the frozen interfaces.
 *
 * TODO(step 3): `CursorConfiguration`, `CursorState`, `SingleCursorState`,
 * `PartialModelCursorState`, `PartialViewCursorState` and `CursorColumns`
 * are ported with the cursor controller; the classes below are placeholders.
 */

typedef IColumnSelectData = {
    var isReal:Bool;
    var fromViewLineNumber:Int;
    var fromViewVisualColumn:Int;
    var toViewLineNumber:Int;
    var toViewVisualColumn:Int;
}

/**
 * This is an operation type that will be recorded for undo/redo purposes.
 * The goal is to introduce an undo stop when the controller switches between different operation types.
 */
enum abstract EditOperationType(Int) from Int to Int {
    var Other = 0;
    var DeletingLeft = 2;
    var DeletingRight = 3;
    var TypingOther = 4;
    var TypingFirstSpace = 5;
    var TypingConsecutiveSpace = 6;
}

interface ICursorSimpleModel {
    function getLineCount():Int;
    function getLineContent(lineNumber:Int):String;
    function getLineMinColumn(lineNumber:Int):Int;
    function getLineMaxColumn(lineNumber:Int):Int;
    function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int;
    function getLineLastNonWhitespaceColumn(lineNumber:Int):Int;
    function normalizePosition(position:Position, affinity:PositionAffinity):Position;

    /**
     * Gets the column at which indentation stops at a given line.
     * @internal
     */
    function getLineIndentColumn(lineNumber:Int):Int;
}

/**
 * The cursor configuration (tab size, word separators, auto closing...).
 * TODO(step 3): placeholder.
 */
class CursorConfiguration {}

/**
 * The state of one cursor (model and view states).
 * TODO(step 3): placeholder.
 */
class CursorState {}

/**
 * Monaco's `PartialCursorState`: `CursorState | PartialModelCursorState |
 * PartialViewCursorState`.
 * TODO(step 3): placeholder, a common base of the three classes.
 */
class PartialCursorState {}
