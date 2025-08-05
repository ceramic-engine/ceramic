package ceramic;

/**
 * Complete configuration for initializing a SpineMontage.
 *
 * This class provides a convenient way to configure all aspects of a SpineMontage
 * in a single object, which can be passed to the SpineMontage constructor.
 * It combines animation definitions, default settings, Spine instance configuration,
 * and initial state into one cohesive structure.
 *
 * The @:structInit metadata enables object literal syntax for easy configuration.
 *
 * Complete montage setup
 * ```haxe
 * enum PlayerState {
 *     IDLE;
 *     WALK;
 *     RUN;
 *     JUMP;
 *     ATTACK;
 * }
 *
 * var settings:SpineMontageSettings<PlayerState> = {
 *     spine: {
 *         data: playerSpineData,
 *         scale: 0.5,
 *         bound: true
 *     },
 *     defaults: {
 *         track: 0,
 *         speed: 1.0,
 *         loop: false
 *     },
 *     animations: {
 *         IDLE: { anim: "idle", loop: true },
 *         WALK: { anim: "walk", loop: true, speed: 1.0 },
 *         RUN: { anim: "run", loop: true, speed: 1.5 },
 *         JUMP: {
 *             anim: "jump",
 *             next: IDLE,
 *             begin: () -> playSound("jump")
 *         },
 *         ATTACK: {
 *             anim: "sword_swing",
 *             next: IDLE,
 *             complete: () -> dealDamage()
 *         }
 *     },
 *     start: Idle
 * };
 *
 * var montage = new SpineMontage(settings);
 * ```
 *
 * Minimal setup with existing Spine instance
 * ```haxe
 * var settings:SpineMontageSettings<String> = {
 *     spine: {
 *         instance: existingSpineObject,
 *         bound: false
 *     },
 *     animations: {
 *         "intro": { anim: "intro_animation" },
 *         "loop": { anim: "main_loop", loop: true }
 *     }
 * };
 * ```
 */
@:structInit
class SpineMontageSettings<T> {

    /**
     * The animation configurations that make up this montage.
     *
     * This is a dynamic object where:
     * - Keys are string representations of your animation identifiers (T)
     * - Values are SpineMontageAnimation<T> configurations
     *
     * For enum-based montages, use the enum constructor names as keys.
     * For string-based montages, use the string values directly.
     *
     * Each animation configuration defines how that particular animation
     * should be played, including its Spine animation name, playback settings,
     * callbacks, and transitions.
     *
     * ```haxe
     * animations: {
     *     IDLE: { anim: "idle_loop", loop: true },
     *     WALK: { anim: "walk_cycle", loop: true, speed: 1.2 },
     *     ATTACK: { anim: "attack_01", next: IDLE }
     * }
     * ```
     */
    public var animations:Null<Dynamic<SpineMontageAnimation<T>>> = null;

    /**
     * Default configuration values that apply to all animations.
     *
     * These defaults reduce repetition by providing common values that
     * animations will use unless they specify their own. Includes:
     * - Default track index
     * - Default playback speed
     * - Default loop behavior
     * - Default skin
     *
     * Individual animations can override any of these defaults.
     */
    public var defaults:Null<SpineMontageDefaults> = null;

    /**
     * Configuration for the Spine instance used by this montage.
     *
     * This can either:
     * - Provide an existing Spine instance to use
     * - Specify SpineData to create a new instance
     * - Configure scale, depth, and binding behavior
     *
     * If not provided, you must manually set the spine instance
     * on the montage after creation.
     */
    public var spine:Null<SpineMontageSpineSettings> = null;

    /**
     * The initial animation to play when the montage is created.
     *
     * This animation will be automatically started after the montage
     * is fully initialized. The animation begins on the next immediate
     * frame to ensure all setup is complete.
     *
     * If null, no animation will play initially and you must call
     * play() manually to start an animation.
     *
     * ```haxe
     * start: PlayerState.IDLE  // For enum-based montages
     * start: "intro"          // For string-based montages
     * ```
     */
    public var start:Null<T> = null;

}
