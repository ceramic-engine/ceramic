// New code for the Haxe port of GPUI (no GPUI origin): the debug check of
// the view cache (define `glaze_verify_cache`). See NOTICE.md.
package glaze;

/**
 * `glaze_verify_cache`: a view that would have been reused from the cache in
 * this frame renders for real instead, and what it draws is compared with
 * what the reuse would have drawn (see `Window.endVerifyScope`).
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

    /**
     * `existing` (or a new verification) holding the ranges recorded in
     * `state` by the last frame, for a view that renders for real in this
     * frame without being compared (dirty, moved): the views around it
     * leave its ranges out of their own comparison (`Window.endVerifyScope`).
     */
    public static function oldRangesOf(existing:Null<CacheVerification>, state:ViewElement.ViewElementState):CacheVerification {
        final verification = of(existing, state);
        verification.pending = false;
        return verification;
    }

    public function reset():Void {
        pending = false;
        compare = false;
    }

}

/**
 * `glaze_verify_cache`: a view drawn for real in this frame, while it paints
 * (see `Window.beginVerifyScope`): what the comparison of the views around
 * it must know about it (the ranges it drew in the last frame and in this
 * one, whether it had any), and what it learnt from the views inside it.
 */
class VerifyScope {

    public var entityId:Int = -1;

    /** The ranges of the last frame, `null` when the view was not drawn in it */
    public var old:Null<CacheVerification> = null;

    /** The ranges of this frame (recorded by the view's prepaint and paint) */
    public var state:Null<ViewElement.ViewElementState> = null;

    /** Rendered because it was dirty (notified, or a descendant was) */
    public var dirty:Bool = false;

    /** The views drawn for real inside it, in paint order */
    public final nested:Array<VerifyScope> = [];

    /** A view inside it drew a view that was not drawn in the last frame */
    public var newViewInside:Bool = false;

    /** A view without a cache (`.uncached()`) was drawn inside it: its ranges cannot be compared */
    public var unverifiable:Bool = false;

    public function new() {}

    public function reset():Void {
        entityId = -1;
        old = null;
        state = null;
        dirty = false;
        nested.resize(0);
        newViewInside = false;
        unverifiable = false;
    }

}
