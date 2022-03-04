package ceramic;

import ceramic.Shortcuts.*;

/**
 * An utility to group an pre-configure spine animations together as a single `montage`
 */
class SpineMontage<T> extends Entity implements Component {

    @:noCompletion public var entity:Spine;

    /**
     * Fired when starting an animation
     */
    @event function beginAnimation(animation:T);

    /**
     * Fired when completing an animation
     */
    @event function completeAnimation(animation:T);

    /**
     * The spine object this montage works with
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
     * The current animation in montage
     */
    @observe public var animation(default, set):T = null;

    /**
     * Default animation settings
     */
    public var defaults(default, null):SpineMontageDefaults = null;

    /**
     * Animation instances by (stringified) key.
     * Note: this is not used on enum-based SpineMontage instances.
     */
    var animationInstances:Map<String, SpineMontageAnimation<T>> = null;

    /**
     * Montage animation instance currently applied to display an animation (if any)
     */
    var currentAnimationInstance:SpineMontageAnimation<T> = null;

    /**
     * Is `true` if the linked `Spine` instance is bound to this montage,
     * meaning it will be destroyed if montage gets destroyed and vice versa.
     */
    var boundToSpineInstance:Bool = false;

    /**
     * Internal value to keep track of the number of times we set animation
     */
    var numSetAnimation:Int = 0;

    /**
     * Used enum type, if applicable
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
     * Create a new spine montage.
     * @param  settings if provided, will be used to configure this montage.
     *         See `SpineMontageSettings` for more info.
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

    public function setAnimations(animations:Dynamic<SpineMontageAnimation<T>>) {

        for (name in Reflect.fields(animations)) {

            var animationInstance:SpineMontageAnimation<T> = Reflect.field(animations, name);
            if (animationInstance == null) {
                throw 'Invalid animation instance for key: $name';
            }

            setByName(name, animationInstance);
        }

    }

    public function setDefaults(defaults:SpineMontageDefaults) {

        this.defaults = defaults;

    }

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
     * Create a spine object with the given `SpineData` object.
     * @param spineData The `SpineData` object to use
     * @param bound (default `true`) Whether this spine object is bound to montage lifecycle.
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
     * Stop current animation (this is equivalent to `montage.animation = null;`)
     */
    public function stop():Void {

        animation = null;

    }

    /**
     * `montage.play(animation);` is stricly equivalent to: `montage.animation = animation;`
     * @param reset If set to `true`, will reset the animation to its initial state, even if setting the same animation a second time.
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
     * Configure an animation for key `key`
     */
    public function set(key:T, animationInstance:SpineMontageAnimation<T>):Void {

        setByName(keyToString(key), animationInstance);

    }

    /**
     * Get configured animation for key `key`
     */
    public function get(key:T):SpineMontageAnimation<T> {

        if (animationInstances == null) {
            return null;
        }

        return getByName(keyToString(key));

    }

}
