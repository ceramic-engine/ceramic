// New code for the Haxe port of GPUI (no GPUI origin): the debug check of
// the view cache (define `glaze_verify_cache`). See NOTICE.md.
package glaze;

/**
 * `glaze_verify_cache`: a view that would have been reused from the cache in
 * this frame renders for real instead, and what it draws is compared with
 * what the reuse would have drawn (see `Window.verifyCachedRendering`).
 * Holds the ranges of the last frame that the reuse would have replayed.
 */
class CacheVerification {

    /** The prepaint and paint ranges of the last frame */
    public final prepaintStart:PrepaintStateIndex = new PrepaintStateIndex();
    public final prepaintEnd:PrepaintStateIndex = new PrepaintStateIndex();
    public final paintStart:PaintIndex = new PaintIndex();
    public final paintEnd:PaintIndex = new PaintIndex();

    /** Its layout was reusable: the context of its prepaint is still to check */
    public var pending:Bool = false;

    /** Its prepaint and paint would have been reused: compare them */
    public var compare:Bool = false;

    public function new() {}

    /**
     * `existing` (or a new verification) holding the ranges recorded in `state`.
     */
    public static function of(existing:Null<CacheVerification>, state:ViewElement.ViewElementState):CacheVerification {
        final verification = existing != null ? existing : new CacheVerification();
        verification.prepaintStart.copyFrom(state.prepaintStart);
        verification.prepaintEnd.copyFrom(state.prepaintEnd);
        verification.paintStart.copyFrom(state.paintStart);
        verification.paintEnd.copyFrom(state.paintEnd);
        verification.pending = true;
        verification.compare = false;
        return verification;
    }

    public function reset():Void {
        pending = false;
        compare = false;
    }

}
