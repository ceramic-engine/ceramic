package ceramic;

import ceramic.Shortcuts.*;

/**
 * A powerful utility for managing and orchestrating Spine animations as a cohesive montage.
 *
 * SpineMontage provides a high-level interface for configuring, sequencing, and controlling
 * Spine animations with predefined settings. It allows you to group related animations
 * together and define transitions, callbacks, and default behaviors for each animation state.
 *
 * The class supports both enum-based and string-based animation keys through its generic
 * type parameter T, making it type-safe when used with enums while still flexible for
 * dynamic animation names.
 *
 * Key features:
 * - Type-safe animation management with enum support
 * - Animation chaining and sequencing with automatic transitions
 * - Per-animation configuration (speed, loop, track, skin)
 * - Begin/complete callbacks for animation lifecycle events
 * - Default settings that apply to all animations
 * - Automatic Spine instance lifecycle management
 *
 * Using with an enum
 * ```haxe
 * enum HeroAnimation {
 *     IDLE;
 *     WALK;
 *     RUN;
 *     JUMP;
 *     ATTACK;
 * }
 *
 * var montage = new SpineMontage<HeroAnimation>({
 *     spine: {
 *         data: heroSpineData,
 *         scale: 0.5
 *     },
 *     defaults: {
 *         track: 0,
 *         speed: 1.0
 *     },
 *     animations: {
 *         IDLE: { anim: "idle", loop: true },
 *         WALK: { anim: "walk", loop: true, speed: 1.2 },
 *         RUN: { anim: "run", loop: true, speed: 1.5 },
 *         JUMP: { anim: "jump", next: IDLE },
 *         ATTACK: {
 *             anim: "attack",
 *             next: IDLE,
 *             complete: () -> trace("Attack finished!")
 *         }
 *     },
 *     start: Idle
 * });
 *
 * // Later in code
 * montage.play(Walk);
 * montage.play(Attack); // Will auto-transition to Idle when complete
 * ```
 *
 * Using with strings
 * ```haxe
 * var montage = new SpineMontage<String>();
 * montage.createSpine(spineData);
 * montage.set("intro", { anim: "intro_animation", next: "loop" });
 * montage.set("loop", { anim: "loop_animation", loop: true });
 * montage.play("intro");
 * ```
 */
class SpineMontage<T> extends Entity implements Component {

    @:noCompletion public var entity:Spine;

    /**
     * Fired when starting an animation.
     * This event is emitted after the animation has been applied to the Spine instance
     * and after any begin callback has been executed.
     *
     * @param animation The animation key that just started
     */
    @event function beginAnimation(animation:T);

    /**
     * Fired when completing an animation.
     * This event is emitted when a non-looping animation finishes playing,
     * after any complete callback has been executed but before transitioning
     * to the next animation (if configured).
     *
     * @param animation The animation key that just completed
     */
    @event function completeAnimation(animation:T);

    /**
     * The Spine instance this montage controls.
     *
     * When setting a new Spine instance:
     * - Previous instance event listeners are cleaned up
     * - If the previous instance was bound, it gets destroyed
     * - Current animation (if any) is reapplied to the new instance
     *
     * The Spine instance can be bound to this montage's lifecycle,
     * meaning it will be automatically destroyed when the montage is destroyed.
     */
    public var spine(get, set):Spine;

    inline function get_spine():Spine {
        return entity;
    }

    function set_spine(spine:Spine):Spine {
        if (entity == spine)
            return spine;
        if (entity != null) {
            entity.offComplete(handleSpineComplete);
            if (boundToSpineInstance) {
                entity.offDestroy(handleSpineDestroy);
                entity.destroy();
            }
        }
        entity = spine;

        // Play (reset) animation on new spine if any running previously
        if (entity != null) {
            entity.onComplete(this, handleSpineComplete);
            if (animation != null) {
                play(animation, true);
            }
        }

        return spine;
    }

    /**
     * The currently playing animation in the montage.
     *
     * Setting this property will:
     * 1. Stop the current animation (if any)
     * 2. Apply the new animation's configuration
     * 3. Execute any begin callback
     * 4. Emit the beginAnimation event
     * 5. Start playing the animation on the Spine instance
     *
     * Set to null to stop all animations and hide the Spine instance.
     */
    @observe public var animation(default, set):T = null;

    /**
     * Default animation settings that apply to all animations unless overridden.
     *
     * These defaults include:
     * - track: The animation track to use (default: 0)
     * - speed: Time scale multiplier (default: 1.0)
     * - loop: Whether animations loop by default (default: false)
     * - skin: Default skin name to use (default: null)
     *
     * Individual animations can override any of these defaults.
     */
    public var defaults(default, null):SpineMontageDefaults = null;

    /**
     * Internal storage for animation configurations mapped by their string representation.
     * For enum-based montages, enum values are converted to strings for storage.
     * This allows the same storage mechanism to work for both enum and string keys.
     */
    var animationInstances:Map<String, SpineMontageAnimation<T>> = null;

    /**
     * The animation configuration currently being used to display an animation.
     * This holds the complete configuration including animation name, speed, loop settings, etc.
     * Will be null when no animation is playing.
     */
    var currentAnimationInstance:SpineMontageAnimation<T> = null;

    /**
     * Indicates whether the Spine instance lifecycle is bound to this montage.
     * When true:
     * - Destroying the montage will also destroy the Spine instance
     * - Destroying the Spine instance will also destroy the montage
     * This creates a strong ownership relationship between the two objects.
     */
    var boundToSpineInstance:Bool = false;

    /**
     * Internal counter tracking animation changes.
     * Used to detect when animations are changed externally during callbacks,
     * preventing the montage from overriding explicit animation changes.
     */
    var numSetAnimation:Int = 0;

    /**
     * Stores the enum type when T is an enum.
     * Currently unused but reserved for potential future enum-specific features.
     */
    var enumType:Enum<T> = null;

    function set_animation(animation:T):T {
        // Increment internal value
        numSetAnimation++;

        // Skip if animation is already the same
        if (this.animation == animation)
            return animation;

        // Update animation value
        this.animation = animation;

        if (animation != null) {
            this.currentAnimationInstance = get(animation);

            if (this.currentAnimationInstance != null) {

                // Run begin callback (if any)
                var begin:()->Void = this.currentAnimationInstance.begin;
                if (begin != null) {
                    begin();
                    begin = null;
                }

                // Emit event
                emitBeginAnimation(this.animation);

                // Check destroyed state (in case it happened in callback handlers)
                if (destroyed)
                    return animation;
            }
            else {
                log.warning('No configuration found for animation: $animation');
            }

        }
        else {
            this.currentAnimationInstance = null;
        }

        applyCurrentAnimation();

        return animation;
    }

    /// Lifecycle

    /**
     * Creates a new SpineMontage instance with optional initial configuration.
     *
     * The settings parameter allows you to configure all aspects of the montage
     * at creation time, including:
     * - Creating or using an existing Spine instance
     * - Setting default animation parameters
     * - Defining all animation configurations
     * - Specifying an initial animation to play
     *
     * @param settings Optional configuration object containing spine setup,
     *                 animation definitions, and default values.
     *                 See `SpineMontageSettings` for detailed options.
     */
    public function new(?settings:SpineMontageSettings<T>) {

        super();

        if (settings != null) {
            // Spine instance?
            if (settings.spine != null) {
                // Whether we bind this instance to our montage's lifecycle or not
                var bound = settings.spine.bound;

                // Use given spine instance?
                if (settings.spine.instance != null) {
                    useSpine(settings.spine.instance, bound);
                }

                // Create one?
                if (spine == null && settings.spine.data != null) {
                    createSpine(settings.spine.data, bound);
                }

                if (spine != null) {
                    // Apply skeleton scale
                    spine.skeletonScale = settings.spine.scale;
                    // Apply depth
                    spine.depth = settings.spine.depth;
                    // Apply depthRange
                    spine.depthRange = settings.spine.depthRange;
                }
            }

            // Default values
            if (settings.defaults != null) {
                setDefaults(settings.defaults);
            }

            // Montage animations
            if (settings.animations != null) {
                setAnimations(settings.animations);
            }

            // Starting montage with an animation already?
            if (settings.start != null) {
                var start = settings.start;
                var prevNumSetAnimation = this.numSetAnimation;
                app.onceImmediate(function() {
                    if (destroyed || prevNumSetAnimation != this.numSetAnimation)
                        return;
                    play(start);
                });
            }
        }

    }

    override function destroy() {

        if (boundToSpineInstance) {
            boundToSpineInstance = false;
            if (spine != null) {
                spine.destroy();
                spine = null;
            }
        }

        super.destroy();

    }

    function bindAsComponent():Void {

        // Nothing to do

    }

    /// Internal

    function handleSpineDestroy(_):Void {

        destroy();

    }

    function handleSpineComplete():Void {

        if (currentAnimationInstance == null) {
            log.warning('Spine animation completed $animation with no animationInstance set.');
            return;
        }

        var prevAnimation = this.animation;
        var prevNumSetAnimation = this.numSetAnimation;

        // Run complete callback, if any
        var complete:()->Void = currentAnimationInstance.complete;
        if (complete != null) {
            complete();
            complete = null;
        }

        // Emit a complete event
        emitCompleteAnimation(prevAnimation);

        // Check destroyed state (in case it happened in callback handlers)
        if (destroyed)
            return;

        // Check that another animation was not explicity set from outside
        if (prevNumSetAnimation == this.numSetAnimation) {

            // Fine, it wasn't. Then should we follow with another animation?
            var next:T = currentAnimationInstance.next;
            if (next != null) {
                this.animation = next;
            }
        }

    }

    function applyCurrentAnimation():Void {

        if (spine != null) {

            // Do play animation if spine instance is ready
            //
            if (currentAnimationInstance != null) {

                // Track index
                var trackIndex:Int = defaults != null ? defaults.track : 0;
                if (currentAnimationInstance.track >= 0) {
                    trackIndex = currentAnimationInstance.track;
                }

                // Speed (time scale)
                var speed:Float = defaults != null ? defaults.speed : 1.0;
                if (currentAnimationInstance.speed >= 0) {
                    speed = currentAnimationInstance.speed;
                }

                // Loop
                var loop:Bool = defaults != null ? defaults.loop : false;
                if (currentAnimationInstance.loop != null) {
                    loop = currentAnimationInstance.loop;
                }

                // Skin
                var skin:String = defaults != null ? defaults.skin : null;
                if (currentAnimationInstance.skin != null) {
                    skin = currentAnimationInstance.skin;
                }

                // Anim
                var anim:String = currentAnimationInstance.anim;

                // Run animation with requested settings
                spine.active = true;
                if (skin != null)
                    spine.skin = skin;
                spine.animate(
                    anim,
                    loop,
                    trackIndex
                );

                // Apply track time and time scale if needed
                var track = spine.state.getCurrent(trackIndex);
                if (currentAnimationInstance.time > 0) {
                    track.setTrackTime(track.animation.duration * currentAnimationInstance.time);
                }
                track.setTimeScale(speed);
            }
            else {
                // No animation to apply, hide spine
                spine.animate(null);
                spine.active = false;
            }
        }

    }

    function keyToString(key:T):String {

        var name:Dynamic = key;
        if (name == null)
            return null;
        return name.toString();

    }

    /**
     * Configure an animation for key matching name `name`.
     */
    function setByName(name:String, animationInstance:SpineMontageAnimation<T>):Void {

        if (name == null) {
            throw('Cannot set animation info with null name');
        }

        if (animationInstances == null) {
            animationInstances = new Map();
        }

        if (animationInstances.exists(name)) {
            var existing = animationInstances.get(name);
            if (existing == currentAnimationInstance) {
                currentAnimationInstance = null;
            }
        }

        animationInstances.set(name, animationInstance);

        if (animationInstance != null) {

            if (animation != null && name == keyToString(animation)) {
                // We changed animation instance for the current animation,
                // so we need to update `currentAnimationInstance` accordingly
                if (currentAnimationInstance == null) {
                    currentAnimationInstance = animationInstance;

                    // Reset animation, because it has changed
                    play(animation, true);
                }
            }
        }

    }

    /**
     * Get configured animation for key matching name `name`
     */
    function getByName(name:String):SpineMontageAnimation<T> {

        if (animationInstances == null) {
            return null;
        }

        return animationInstances.get(name);

    }

    /// Public API

    /**
     * Sets multiple animation configurations at once using a dynamic object.
     *
     * Each field in the animations object should have a name matching the
     * animation key (as a string) and a value of type SpineMontageAnimation<T>
     * containing the configuration for that animation.
     *
     * @param animations Object with animation configurations keyed by name
     * @throws String If any animation instance in the object is null
     *
     * ```haxe
     * montage.setAnimations({
     *     "idle": { anim: "idle_loop", loop: true },
     *     "walk": { anim: "walk_cycle", loop: true, speed: 1.2 },
     *     "jump": { anim: "jump_up", next: "idle" }
     * });
     * ```
     */
    public function setAnimations(animations:Dynamic<SpineMontageAnimation<T>>) {

        for (name in Reflect.fields(animations)) {

            var animationInstance:SpineMontageAnimation<T> = Reflect.field(animations, name);
            if (animationInstance == null) {
                throw 'Invalid animation instance for key: $name';
            }

            setByName(name, animationInstance);
        }

    }

    /**
     * Sets the default animation parameters that apply to all animations.
     *
     * These defaults are used as fallback values when an animation doesn't
     * specify its own value for a particular setting.
     *
     * @param defaults The default configuration to use
     */
    public function setDefaults(defaults:SpineMontageDefaults) {

        this.defaults = defaults;

    }

    /**
     * Associates an existing Spine instance with this montage.
     *
     * This method allows you to provide a pre-configured Spine instance
     * rather than creating a new one. Any previously associated Spine
     * instance will be properly cleaned up based on its binding status.
     *
     * @param spine The Spine instance to use
     * @param bound Whether to bind the Spine instance lifecycle to this montage.
     *              When true, destroying either object will destroy the other.
     */
    public function useSpine(spine:Spine, bound:Bool = true):Void {

        // Will unbind any managed spine if needed
        this.spine = null;

        boundToSpineInstance = bound;
        if (boundToSpineInstance) {
            spine.onDestroy(this, handleSpineDestroy);
        }
        this.spine = spine;

    }

    /**
     * Creates a new Spine instance using the provided SpineData.
     *
     * This is a convenience method that creates and configures a new Spine
     * instance with the given data. The created instance is automatically
     * set as inactive until an animation is played.
     *
     * @param spineData The SpineData containing skeleton and atlas information
     * @param bound Whether to bind the created Spine instance lifecycle to this montage.
     *              When true, destroying either object will destroy the other.
     */
    public function createSpine(spineData:SpineData, bound:Bool = true):Void {

        // Will unbind any managed spine if needed
        spine = null;

        // Create new spine instance
        var spine = new Spine();
        spine.spineData = spineData;
        spine.active = false;
        boundToSpineInstance = bound;
        if (boundToSpineInstance) {
            spine.onDestroy(this, handleSpineDestroy);
        }
        this.spine = spine;

    }

    /**
     * Stops the current animation and hides the Spine instance.
     *
     * This is equivalent to setting `animation = null` and will:
     * - Stop any playing animation
     * - Hide the Spine instance (set active to false)
     * - Clear the current animation state
     */
    public function stop():Void {

        animation = null;

    }

    /**
     * Plays the specified animation.
     *
     * This is the primary method for starting animations in the montage.
     * By default, if the same animation is already playing, it continues
     * without interruption. Use the reset parameter to force a restart.
     *
     * @param animation The animation key to play
     * @param reset If true, forces the animation to restart from the beginning,
     *              even if it's already the current animation
     *
     * ```haxe
     * montage.play(HeroAnimation.Walk);
     * montage.play(HeroAnimation.Jump, true); // Force restart
     * ```
     */
    public function play(animation:T, reset:Bool = false):Void {
        if (reset) {
            // Reset animation
            this.animation = null;
            currentAnimationInstance = null;
        }

        // The rest is handled in set_animation()
        this.animation = animation;
    }

    /**
     * Configures a single animation in the montage.
     *
     * Use this method to add or update the configuration for a specific
     * animation key. The configuration includes the actual Spine animation
     * name, playback settings, callbacks, and transition information.
     *
     * @param key The animation key to configure
     * @param animationInstance The configuration for this animation
     *
     * ```haxe
     * montage.set(HeroAnimation.Victory, {
     *     anim: "victory_dance",
     *     speed: 0.8,
     *     complete: () -> trace("Victory!"),
     *     next: HeroAnimation.Idle
     * });
     * ```
     */
    public function set(key:T, animationInstance:SpineMontageAnimation<T>):Void {

        setByName(keyToString(key), animationInstance);

    }

    /**
     * Retrieves the configuration for a specific animation key.
     *
     * @param key The animation key to look up
     * @return The animation configuration if found, null otherwise
     */
    public function get(key:T):SpineMontageAnimation<T> {

        if (animationInstances == null) {
            return null;
        }

        return getByName(keyToString(key));

    }

}
