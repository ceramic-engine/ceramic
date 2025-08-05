package ceramic;

/**
 * Configuration data for a single animation within a SpineMontage.
 * 
 * This class defines all the parameters needed to play a Spine animation,
 * including playback settings, visual options, and lifecycle callbacks.
 * It's designed to be used with SpineMontage to create rich, interactive
 * animation sequences with automatic transitions and event handling.
 * 
 * The @:structInit metadata allows for convenient object literal syntax
 * when creating instances, making configuration clean and readable.
 * 
 * ```haxe
 * var jumpAnimation:SpineMontageAnimation<HeroState> = {
 *     anim: "jump_animation",
 *     speed: 1.2,
 *     next: HeroState.Idle,
 *     begin: () -> playJumpSound(),
 *     complete: () -> trace("Jump completed!")
 * };
 * ```
 */
@:structInit
class SpineMontageAnimation<T> {

    /**
     * The name of the Spine animation to play.
     * This must match an animation name defined in the Spine skeleton data.
     * This is the only required field when creating an animation configuration.
     */
    public var anim:String;

    /**
     * The skin to apply when playing this animation.
     * 
     * Skins in Spine allow you to swap out attachments (images) to create
     * variations of the same animation (e.g., different outfits, weapons).
     * If null, the current skin or default skin will be used.
     * 
     * "warrior", "mage", "red_armor"
     */
    public var skin:Null<String> = null;

    /**
     * Whether this animation should loop continuously.
     * 
     * - true: Animation repeats indefinitely until explicitly stopped
     * - false: Animation plays once and triggers completion
     * - null: Uses the default loop setting from SpineMontageDefaults
     * 
     * Non-looping animations will trigger their complete callback and
     * potentially transition to the next animation when finished.
     */
    public var loop:Null<Bool> = null;

    /**
     * Starting position within the animation as a normalized value (0-1).
     * 
     * - 0: Start at the beginning (default)
     * - 0.5: Start halfway through
     * - 1: Start at the end
     * 
     * This is useful for synchronizing animations or creating seamless
     * transitions between related animations.
     */
    public var time:Float = 0;

    /**
     * Playback speed multiplier for this animation.
     * 
     * - 1.0: Normal speed (default when using montage defaults)
     * - 2.0: Double speed
     * - 0.5: Half speed
     * - 0: Paused
     * - -1: Use default speed from SpineMontageDefaults
     * 
     * Negative values (except -1) will play the animation in reverse.
     */
    public var speed:Float = -1;

    /**
     * The animation track index to use for this animation.
     * 
     * Spine supports multiple animation tracks for layering animations
     * (e.g., running on track 0 while shooting on track 1).
     * 
     * - 0: Primary track (most common)
     * - 1+: Additional layered tracks
     * - -1: Use default track from SpineMontageDefaults
     */
    public var track:Int = -1;

    /**
     * The animation to automatically transition to when this one completes.
     * 
     * This enables creation of animation sequences and state machines.
     * Only applies to non-looping animations. The transition happens
     * immediately after the complete callback (if any) is executed.
     * 
     * Set to null for no automatic transition.
     * 
     * ```haxe
     * animations: {
     *     "jump": { anim: "jump", next: "fall" },
     *     "fall": { anim: "fall", next: "land" },
     *     "land": { anim: "land", next: "idle" },
     *     "idle": { anim: "idle", loop: true }
     * }
     * ```
     */
    public var next:T = null;

    /**
     * Callback function executed when this animation begins playing.
     * 
     * Called after the animation has been applied to the Spine instance
     * but before the beginAnimation event is emitted. Useful for:
     * - Playing sound effects
     * - Spawning particles
     * - Setting up animation-specific state
     * - Triggering UI updates
     * 
     * The callback receives no parameters and should not return a value.
     */
    public var begin:()->Void = null;

    /**
     * Callback function executed when this animation completes.
     * 
     * Only called for non-looping animations when they finish playing.
     * Executed before any transition to the next animation and before
     * the completeAnimation event is emitted. Useful for:
     * - Cleanup after animation
     * - Triggering game logic
     * - Scoring or achievement checks
     * - Queuing follow-up actions
     * 
     * The callback receives no parameters and should not return a value.
     */
    public var complete:()->Void = null;

}
