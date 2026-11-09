// Ported from vscode src/vs/editor/common/cursorEvents.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

/**
 * Describes the reason the cursor has changed its position.
 *
 * TODO(step 3): the cursor events (`ICursorPositionChangedEvent`,
 * `ICursorSelectionChangedEvent`) come with the cursor controller.
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
