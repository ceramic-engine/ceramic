package ceramic;

/**
 * Default configuration values for animations in a SpineMontage.
 *
 * This class defines fallback values that are used when individual animations
 * don't specify their own values for certain properties. It helps reduce
 * repetition by establishing common settings that apply to most animations
 * in a montage.
 *
 * Individual animations can override any of these defaults by providing
 * their own values in their SpineMontageAnimation configuration.
 *
 * ```haxe
 * var montage = new SpineMontage<HeroState>({
 *     defaults: {
 *         track: 0,
 *         speed: 1.0,
 *         loop: false,
 *         skin: "default"
 *     },
 *     animations: {
 *         // This will use all defaults
 *         IDLE: { anim: "idle_animation" },
 *
 *         // This overrides just the loop default
 *         WALK: { anim: "walk_animation", loop: true },
 *
 *         // This overrides speed and adds a specific skin
 *         RUN: { anim: "run_animation", speed: 1.5, skin: "armored" }
 *     }
 * });
 * ```
 */
@:structInit
class SpineMontageDefaults {

    /**
     * The default skin to apply to animations.
     *
     * Skins in Spine allow you to change the visual appearance of a skeleton
     * by swapping out attachments (images). Common uses include:
     * - Character customization (different outfits, equipment)
     * - Team colors in multiplayer games
     * - Seasonal variations
     *
     * If null, the Spine skeleton's default skin will be used.
     * Individual animations can override this with their own skin setting.
     */
    public var skin:Null<String> = null;

    /**
     * Whether animations should loop by default.
     *
     * - false (default): Animations play once and stop, potentially triggering
     *   completion callbacks and transitions to next animations
     * - true: Animations repeat indefinitely until explicitly stopped or changed
     *
     * This is particularly useful when most animations in your montage are either
     * mostly looping (idle, walk, run) or mostly one-shot (jump, attack, death).
     * Set the default to match your most common case.
     */
    public var loop:Bool = false;

    /**
     * The default playback speed multiplier for animations.
     *
     * - 1.0 (default): Normal playback speed as designed in Spine
     * - 2.0: Double speed
     * - 0.5: Half speed
     * - 0: Paused (animations don't progress)
     *
     * This is useful for:
     * - Adjusting all animations to match game speed
     * - Creating slow-motion or fast-forward effects
     * - Fine-tuning animation timing without re-exporting from Spine
     *
     * Individual animations can override this to play at different speeds.
     */
    public var speed:Float = 1;

    /**
     * The default animation track index to use.
     *
     * Spine supports multiple animation tracks for layering animations:
     * - Track 0 (default): Primary animation track for main body movement
     * - Track 1+: Additional tracks for overlaying animations (e.g., facial
     *   expressions, weapon swings, special effects)
     *
     * In most cases, track 0 is the correct choice for primary animations.
     * Use higher tracks when you need animations to play simultaneously
     * (e.g., running while reloading a weapon).
     *
     * Individual animations can specify their own track to enable complex
     * layered animation scenarios.
     */
    public var track:Int = 0;

}
