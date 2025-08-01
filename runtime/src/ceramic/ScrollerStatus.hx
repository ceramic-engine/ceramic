package ceramic;

/**
 * Represents the current state of a Scroller component during user interaction.
 * 
 * ScrollerStatus tracks the different phases of touch/mouse interaction with
 * scrollable content, from initial touch through dragging to momentum scrolling.
 * This enum is essential for implementing proper scroll behavior and visual
 * feedback in scrollable UI components.
 * 
 * State transitions:
 * - IDLE → TOUCHING: User touches/clicks the scroller
 * - TOUCHING → DRAGGING: User moves beyond drag threshold
 * - TOUCHING → IDLE: User releases without dragging
 * - DRAGGING → SCROLLING: User releases after dragging (momentum scroll)
 * - DRAGGING → IDLE: User releases with no velocity
 * - SCROLLING → IDLE: Momentum scrolling completes
 * - SCROLLING → TOUCHING: User touches during momentum scroll
 * 
 * Example usage:
 * ```haxe
 * scroller.onStatusChange(this, (status, prevStatus) -> {
 *     switch (status) {
 *         case IDLE:
 *             scrollbar.fadeOut();
 *         case TOUCHING:
 *             scrollbar.show();
 *         case DRAGGING:
 *             scrollbar.highlight();
 *         case SCROLLING:
 *             scrollbar.fadeIn();
 *     }
 * });
 * ```
 * 
 * @see ceramic.Scroller The main scrolling component that uses this enum
 */
enum ScrollerStatus {

    /**
     * Nothing happening - no user interaction or animation.
     * The scroller is at rest and not being interacted with.
     */
    IDLE;

    /**
     * Being touched, but not dragging yet.
     * User has initiated contact but hasn't moved beyond the drag threshold.
     * This state helps distinguish between taps and drag attempts.
     */
    TOUCHING;

    /**
     * Being dragged by a touch/mouse event.
     * User is actively moving the content by dragging.
     * The content follows the touch/mouse position directly.
     */
    DRAGGING;

    /**
     * Scrolling after dragging has ended.
     * Momentum/inertial scrolling is in progress after the user released.
     * The content continues moving based on the release velocity.
     */
    SCROLLING;

}
