package ceramic;

/**
 * Phase of the scroll gesture a `Screen.mouseScroll` event belongs to, read
 * with `screen.mouseScrollPhase` while the event is emitted.
 *
 * A trackpad or Magic Mouse gesture on macOS goes through
 * `GESTURE_MAY_BEGIN` (the fingers touch the surface), `GESTURE_BEGAN`,
 * `GESTURE` events, then `GESTURE_ENDED` when the fingers leave (or
 * `GESTURE_CANCELLED`). The momentum follows, if any: `MOMENTUM_BEGAN`,
 * `MOMENTUM` events, `MOMENTUM_ENDED`. Some of these events have zero deltas
 * (the fingers touch the trackpad, a gesture or its momentum ends): they are
 * emitted anyway, so that an app can stop its own animation when a gesture
 * begins, or settle when the momentum ends.
 *
 * Only macOS native builds report phases (clay, from the `phase` and
 * `momentumPhase` of the system's scroll events). Every other platform and
 * backend gives `NONE`: browsers (`WheelEvent`), Windows wheel messages,
 * Linux and Unity's Input System do not carry the phase of a gesture. A
 * notched mouse wheel is always `NONE`.
 */
enum abstract ScrollPhase(Int) from Int to Int {

    /** No phase: a mouse wheel, or a platform that does not tell. */
    var NONE = 0;

    /** First movement of a gesture. */
    var GESTURE_BEGAN = 1;

    /** Movement of a gesture, the fingers on the surface. */
    var GESTURE = 2;

    /** The fingers left the surface: end of the gesture (momentum may follow). */
    var GESTURE_ENDED = 3;

    /** The system cancelled the gesture. */
    var GESTURE_CANCELLED = 4;

    /** First event of the momentum that follows a gesture. */
    var MOMENTUM_BEGAN = 5;

    /** Movement of the momentum. */
    var MOMENTUM = 6;

    /** End of the momentum (or the momentum was interrupted). */
    var MOMENTUM_ENDED = 7;

    /** The fingers touched the surface; a gesture may begin. Deltas are zero. */
    var GESTURE_MAY_BEGIN = 8;

    /** Whether this is a phase of the fingers on the surface (`GESTURE_*`). */
    public function isGesture():Bool {
        return this == GESTURE_BEGAN || this == GESTURE || this == GESTURE_ENDED
            || this == GESTURE_CANCELLED || this == GESTURE_MAY_BEGIN;
    }

    /** Whether this is a phase of the momentum (`MOMENTUM_*`). */
    public function isMomentum():Bool {
        return this == MOMENTUM_BEGAN || this == MOMENTUM || this == MOMENTUM_ENDED;
    }

    public function toString():String {
        return switch (cast this:ScrollPhase) {
            case NONE: 'NONE';
            case GESTURE_BEGAN: 'GESTURE_BEGAN';
            case GESTURE: 'GESTURE';
            case GESTURE_ENDED: 'GESTURE_ENDED';
            case GESTURE_CANCELLED: 'GESTURE_CANCELLED';
            case MOMENTUM_BEGAN: 'MOMENTUM_BEGAN';
            case MOMENTUM: 'MOMENTUM';
            case MOMENTUM_ENDED: 'MOMENTUM_ENDED';
            case GESTURE_MAY_BEGIN: 'GESTURE_MAY_BEGIN';
            case _: 'ScrollPhase(' + this + ')';
        }
    }

}
