// New code for the Haxe port of GPUI (no GPUI origin): observable storage of
// a global, replacing the `globals_by_type` boxes of gpui-pre 0.3.10. See NOTICE.md.
package glaze;

/**
 * Holds the value of one global. Reading `value` inside a tracker capture
 * (a view render) subscribes the view: `setGlobal` reassigns it and
 * `updateGlobal` calls `invalidateValue()` after mutating it in place.
 * A cell exists as soon as a global type is read, even without a value, so that
 * `tryGlobal` / `hasGlobal` in render also react to a later `setGlobal`.
 */
class GlobalCell extends ceramic.Entity implements tracker.Observable {

    @observe public var value:Dynamic = null;

    public function new() {
        super();
    }

}
