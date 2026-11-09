// Ported from vscode src/vs/editor/contrib/hover/browser/hoverTypes.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.view.EditorBrowser.IEditorMouseEvent;
import glaze.App;
import glaze.IntoElement;
import glaze.Window;

/**
 * A part of a hover (Monaco's `IHoverPart`): a markdown hover, a marker...
 */
interface IHoverPart {
    /**
     * The creator of this hover part.
     */
    var owner(default, null):IEditorHoverParticipant;
    /**
     * The range where this hover part applies.
     */
    var range(default, null):Range;
    /**
     * Force the hover to always be rendered at this specific range,
     * even in the case of multiple hover parts.
     */
    var forceShowAtRange(default, null):Bool;
    /**
     * If true, the hover item should appear before content
     */
    var isBeforeContent(default, null):Bool;
    /**
     * Is this hover part still valid for this new anchor?
     */
    function isValidForHoverAnchor(anchor:HoverAnchor):Bool;
}


/**
 * Where a hover is computed: a range (Monaco's `HoverRangeAnchor`) or a
 * participant's own element (`HoverForeignElementAnchor`), one class here
 * (Monaco's union type).
 */
class HoverAnchor {

    public final type:HoverAnchorType;
    public final priority:Float;
    public final range:Range;
    public final initialMousePosX:Null<Float>;
    public final initialMousePosY:Null<Float>;
    /** The participant of a foreign element anchor. */
    public final owner:Null<IEditorHoverParticipant>;
    public final supportsMarkerHover:Bool;

    public function new(type:HoverAnchorType, priority:Float, range:Range, initialMousePosX:Null<Float>, initialMousePosY:Null<Float>, ?owner:IEditorHoverParticipant, supportsMarkerHover:Bool = false) {
        this.type = type;
        this.priority = priority;
        this.range = range;
        this.initialMousePosX = initialMousePosX;
        this.initialMousePosY = initialMousePosY;
        this.owner = owner;
        this.supportsMarkerHover = supportsMarkerHover;
    }

    /**
     * Monaco's `new HoverRangeAnchor(priority, range, x, y)`.
     */
    public static function rangeAnchor(priority:Float, range:Range, ?initialMousePosX:Float, ?initialMousePosY:Float):HoverAnchor {
        return new HoverAnchor(HoverAnchorType.Range, priority, range, initialMousePosX, initialMousePosY);
    }

    public function equals(other:HoverAnchor):Bool {
        if (type == HoverAnchorType.Range) {
            return other.type == HoverAnchorType.Range && this.range.equalsRange(other.range);
        }
        return other.type == HoverAnchorType.ForeignElement && this.owner == other.owner;
    }

    public function canAdoptVisibleHover(lastAnchor:HoverAnchor, showAtPosition:Position):Bool {
        if (type == HoverAnchorType.Range) {
            return lastAnchor.type == HoverAnchorType.Range && showAtPosition.lineNumber == this.range.startLineNumber;
        }
        return lastAnchor.type == HoverAnchorType.ForeignElement && this.owner == lastAnchor.owner;
    }

}

/**
 * What a participant gets to render its parts (Monaco's
 * `IEditorHoverRenderContext`): the status bar actions, hiding the hover.
 */
interface IEditorHoverRenderContext {
    /**
     * Adds an action to the status bar of the hover (Monaco's
     * `statusBar.addAction`).
     */
    function addStatusBarAction(label:String, commandId:String, run:() -> Void):Void;
    /**
     * Adds a text to the status bar (Monaco's `statusBar.append` of a
     * message: "No quick fixes available"...). It can change later through
     * the returned setter.
     */
    function addStatusBarText(text:String):(text:Null<String>) -> Void;
    /**
     * Hides the hover.
     */
    function hide():Void;
    /**
     * The window bounds of the status bar (where Monaco anchors the quick
     * fix menu opened from the hover), null when not rendered yet.
     */
    function statusBarBounds():Null<glaze.Bounds>;
    /**
     * The content changed (the hover renders again).
     */
    function onContentsChanged():Void;
}

/**
 * A participant of the content hover (Monaco's `IEditorHoverParticipant`):
 * it computes hover parts for an anchor and renders them. Monaco's
 * `computeAsync` gives an async iterable; here it gives each part to
 * `onItem` and calls `onDone` at the end (null when the participant has no
 * async parts). `renderHoverParts` returns Glaze elements (Monaco renders
 * DOM nodes into a fragment).
 */
interface IEditorHoverParticipant {
    var hoverOrdinal(default, null):Int;
    function suggestHoverAnchor(mouseEvent:IEditorMouseEvent):Null<HoverAnchor>;
    function computeSync(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>):Array<IHoverPart>;
    var computeAsync(default, null):Null<(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>, token:CancellationToken, onItem:(part:IHoverPart) -> Void, onDone:() -> Void) -> Void>;
    function createLoadingMessage(anchor:HoverAnchor):Null<IHoverPart>;
    function renderHoverParts(context:IEditorHoverRenderContext, hoverParts:Array<IHoverPart>, window:Window, cx:App):Array<IntoElement>;
    function getAccessibleContent(hoverPart:IHoverPart):String;
}
