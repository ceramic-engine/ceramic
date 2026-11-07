// New code for the Haxe port of GPUI (no GPUI origin): debug counters of the
// objects built every frame, to measure allocations (see tests/bench).
package glaze.util;

/**
 * Counts the creation of the main objects built while drawing frames:
 * elements, styles, element ids, layout nodes. Only compiled with the
 * `glaze_count_allocations` define (otherwise every counter stays 0).
 * `AnyElement.allocatedCount` and scene primitive pools are counted apart.
 */
class AllocationCounters {

    public static var divs:Int = 0;
    public static var texts:Int = 0;
    public static var svgs:Int = 0;
    public static var viewElements:Int = 0;
    public static var styles:Int = 0;
    public static var styleRefinements:Int = 0;
    public static var textStyles:Int = 0;
    public static var globalElementIds:Int = 0;
    public static var layoutNodes:Int = 0;

    /**
     * Sum of every counter.
     */
    public static function total():Int {
        return divs + texts + svgs + viewElements + styles + styleRefinements + textStyles + globalElementIds + layoutNodes;
    }

    /**
     * One line with every counter.
     */
    public static function summary():String {
        return 'divs=$divs texts=$texts svgs=$svgs viewElements=$viewElements styles=$styles styleRefinements=$styleRefinements textStyles=$textStyles globalElementIds=$globalElementIds layoutNodes=$layoutNodes';
    }

    public static function reset():Void {
        divs = texts = svgs = viewElements = styles = styleRefinements = textStyles = globalElementIds = layoutNodes = 0;
    }

}
