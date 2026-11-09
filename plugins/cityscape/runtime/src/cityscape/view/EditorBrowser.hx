// Ported from vscode src/vs/editor/browser/editorBrowser.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * The mouse targets of editorBrowser.ts, as the editor contributions read
 * them (`onMouseDown`, `onMouseUp`).
 *
 * TODO(step 3, editor surface): the rest of editorBrowser.ts (the full
 * `ICodeEditor`, overlay and content widgets) comes with the standalone
 * editor API.
 */

/**
 * Type of hit element with the mouse in the editor.
 */
enum abstract MouseTargetType(Int) from Int to Int {
    /**
     * Mouse is on top of an unknown element.
     */
    var UNKNOWN = 0;
    /**
     * Mouse is on top of the textarea used for input.
     */
    var TEXTAREA = 1;
    /**
     * Mouse is on top of the glyph margin
     */
    var GUTTER_GLYPH_MARGIN = 2;
    /**
     * Mouse is on top of the line numbers
     */
    var GUTTER_LINE_NUMBERS = 3;
    /**
     * Mouse is on top of the line decorations
     */
    var GUTTER_LINE_DECORATIONS = 4;
    /**
     * Mouse is on top of the whitespace left in the gutter by a view zone.
     */
    var GUTTER_VIEW_ZONE = 5;
    /**
     * Mouse is on top of text in the content.
     */
    var CONTENT_TEXT = 6;
    /**
     * Mouse is on top of empty space in the content (e.g. after line text or below last line)
     */
    var CONTENT_EMPTY = 7;
    /**
     * Mouse is on top of a view zone in the content.
     */
    var CONTENT_VIEW_ZONE = 8;
    /**
     * Mouse is on top of a content widget.
     */
    var CONTENT_WIDGET = 9;
    /**
     * Mouse is on top of the decorations overview ruler.
     */
    var OVERVIEW_RULER = 10;
    /**
     * Mouse is on top of a scrollbar.
     */
    var SCROLLBAR = 11;
    /**
     * Mouse is on top of an overlay widget.
     */
    var OVERLAY_WIDGET = 12;
    /**
     * Mouse is outside of the editor.
     */
    var OUTSIDE_EDITOR = 13;
}

/**
 * Target hit with the mouse in the editor (Monaco's `IMouseTarget` union,
 * flattened: the `detail` fields of each kind are fields here).
 */
class MouseTarget {

    /**
     * The target type
     */
    public final type:MouseTargetType;

    /**
     * The 'approximate' editor position
     */
    public final position:Null<Position>;

    /**
     * Desired mouse column (e.g. when position.column gets clamped to text length -- clicking after text on a line).
     */
    public final mouseColumn:Int;

    /**
     * The 'approximate' editor range
     */
    public final range:Null<Range>;

    /**
     * Gutter targets: the left of the gutter element hit (Monaco's
     * `target.element.offsetLeft`: the line decorations start at
     * `layoutInfo.decorationsLeft`).
     */
    public final elementOffsetLeft:Float;

    /**
     * Gutter targets: `detail.offsetX`, the x of the mouse from the left of
     * the editor.
     */
    public final offsetX:Float;

    /**
     * Gutter and empty content targets: `detail.isAfterLines`.
     */
    public final isAfterLines:Bool;

    /**
     * Empty content targets inside the lines: `detail.horizontalDistanceToText`.
     */
    public final horizontalDistanceToText:Float;

    public function new(type:MouseTargetType, position:Null<Position>, mouseColumn:Int, range:Null<Range>, elementOffsetLeft:Float = 0, offsetX:Float = 0, isAfterLines:Bool = false, horizontalDistanceToText:Float = 0) {
        this.type = type;
        this.position = position;
        this.mouseColumn = mouseColumn;
        this.range = range;
        this.elementOffsetLeft = elementOffsetLeft;
        this.offsetX = offsetX;
        this.isAfterLines = isAfterLines;
        this.horizontalDistanceToText = horizontalDistanceToText;
    }

    public function toString():String {
        return 'MouseTarget(' + type + ', ' + (range != null ? range.toString() : 'null') + ')';
    }

}

/**
 * The mouse event of Monaco's `IMouseEvent`, the fields the contributions
 * read.
 */
class EditorMouseEventData {

    public final leftButton:Bool;
    public final middleButton:Bool;
    public final rightButton:Bool;
    public final ctrlKey:Bool;
    public final shiftKey:Bool;
    public final altKey:Bool;
    public final metaKey:Bool;
    /**
     * The click count.
     */
    public final detail:Int;

    public function new(leftButton:Bool, middleButton:Bool, rightButton:Bool, ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, detail:Int) {
        this.leftButton = leftButton;
        this.middleButton = middleButton;
        this.rightButton = rightButton;
        this.ctrlKey = ctrlKey;
        this.shiftKey = shiftKey;
        this.altKey = altKey;
        this.metaKey = metaKey;
        this.detail = detail;
    }

}

/**
 * A mouse event in the editor (Monaco's `IEditorMouseEvent`).
 */
class EditorMouseEvent {

    public final event:EditorMouseEventData;
    public final target:MouseTarget;

    public function new(event:EditorMouseEventData, target:MouseTarget) {
        this.event = event;
        this.target = target;
    }

}
