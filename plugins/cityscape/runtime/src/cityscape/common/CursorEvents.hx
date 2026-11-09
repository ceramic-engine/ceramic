// Ported from vscode src/vs/editor/common/cursorEvents.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.core.Position;
import cityscape.common.core.Selection;

/**
 * Describes the reason the cursor has changed its position.
 */
enum abstract CursorChangeReason(Int) from Int to Int {
    /**
     * Unknown or not set.
     */
    var NotSet = 0;
    /**
     * A `model.setValue()` was called.
     */
    var ContentFlush = 1;
    /**
     * The `model` has been changed outside of this cursor and the cursor recovers its position from associated markers.
     */
    var RecoverFromMarkers = 2;
    /**
     * There was an explicit user gesture.
     */
    var Explicit = 3;
    /**
     * There was a Paste.
     */
    var Paste = 4;
    /**
     * There was an Undo.
     */
    var Undo = 5;
    /**
     * There was a Redo.
     */
    var Redo = 6;
}

/**
 * An event describing that the cursor position has changed.
 */
typedef ICursorPositionChangedEvent = {
    /**
     * Primary cursor's position.
     */
    final position:Position;
    /**
     * Secondary cursors' position.
     */
    final secondaryPositions:Array<Position>;
    /**
     * Reason.
     */
    final reason:CursorChangeReason;
    /**
     * Source of the call that caused the event.
     */
    final source:String;
}

/**
 * An event describing that the cursor selection has changed.
 */
typedef ICursorSelectionChangedEvent = {
    /**
     * The primary selection.
     */
    final selection:Selection;
    /**
     * The secondary selections.
     */
    final secondarySelections:Array<Selection>;
    /**
     * The model version id.
     */
    final modelVersionId:Int;
    /**
     * The old selections.
     */
    final oldSelections:Null<Array<Selection>>;
    /**
     * The model version id the that `oldSelections` refer to.
     */
    final oldModelVersionId:Int;
    /**
     * Source of the call that caused the event.
     */
    final source:String;
    /**
     * Reason.
     */
    final reason:CursorChangeReason;
}
