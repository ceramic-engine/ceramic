package ceramic;

import ceramic.Shortcuts.*;

/**
 * Sprite visual that displays animations from sprite sheets.
 * Supports frame-by-frame animation playback with timing control,
 * easing, and automatic size computation from frames.
 * 
 * The sprite can play animations from SpriteSheet data which can be
 * loaded from various formats including Aseprite JSON exports.
 * 
 * @param T The type used for animation identifiers. Defaults to String
 *          but can be an enum for type-safe animation names.
 * 
 * Example usage:
 * ```haxe
 * var sprite = new Sprite();
 * sprite.sheet = assets.sheet("character");
 * sprite.animation = "walk";
 * sprite.loop = true;
 * ```
 */
class Sprite<T=String> extends Visual {

    /**
     * Whether to automatically compute the sprite's size from the
     * current animation frame. When true, the sprite will resize
     * itself to match the original frame dimensions.
     */
    public var autoComputeSize:Bool = true;

    /**
     * The current texture region being displayed.
     * This is automatically updated during animation playback.
     */
    public var region(get, set):TextureAtlasRegion;
    inline function get_region():TextureAtlasRegion {
        return quad.tile != null ? cast quad.tile : null;
    }

    /**
     * The name of the current animation as a string.
     * This is the string representation of the `animation` property.
     */
    public var animationName(default,null):String;

    /**
     * Optional easing function to apply to animation playback.
     * When set, the animation timeline will be transformed by this easing.
     */
    public var easing(default,null):Easing = null;

    /**
     * Time scale multiplier for animation playback speed.
     * Values > 1.0 speed up the animation, < 1.0 slow it down.
     */
    public var timeScale:Float = 1.0;

    /**
     * The current animation being played.
     * Can be a String or an enum value depending on the type parameter T.
     * Setting this property resets the animation time to 0.
     */
    public var animation(default,set):T = null;
    function set_animation(animation:T):T {
        if (this.animation == animation) return animation;
        this.animation = animation;

        // Convert value to string key
        if (animation == null) {
            animationName = null;
        }
        else {
            animationName = Std.string(animation);
        }

        time = 0;
        currentAnimationDirty = true;

        if (autoComputeSize && animationName != null && sheet != null) {
            computeSizeFromAnimation();
        }

        return animation;
    }

    /**
     * Horizontal offset applied to the frame position.
     * Useful for fine-tuning sprite alignment.
     */
    public var frameOffsetX(default,set):Float = 0;
    function set_frameOffsetX(frameOffsetX:Float):Float {
        if (this.frameOffsetX != frameOffsetX) {
            this.frameOffsetX = frameOffsetX;
            contentDirty = true;
        }
        return frameOffsetX;
    }

    /**
     * Vertical offset applied to the frame position.
     * Useful for fine-tuning sprite alignment.
     */
    public var frameOffsetY(default,set):Float = 0;
    function set_frameOffsetY(frameOffsetY:Float):Float {
        if (this.frameOffsetY != frameOffsetY) {
            this.frameOffsetY = frameOffsetY;
            contentDirty = true;
        }
        return frameOffsetY;
    }

    /**
     * Set both frame offset values at once.
     * @param frameOffsetX Horizontal offset
     * @param frameOffsetY Vertical offset
     */
    public function frameOffset(frameOffsetX:Float, frameOffsetY:Float) {
        this.frameOffsetX = frameOffsetX;
        this.frameOffsetY = frameOffsetY;
    }

    /**
     * The sprite sheet containing animation data.
     * Setting this property resets the animation time.
     */
    public var sheet(default,set):SpriteSheet = null;
    function set_sheet(sheet:SpriteSheet):SpriteSheet {
        if (this.sheet == sheet) return sheet;
        this.sheet = sheet;
        time = 0;
        currentAnimationDirty = true;

        if (autoComputeSize && animationName != null && sheet != null) {
            computeSizeFromAnimation();
        }

        return sheet;
    }

    /**
     * Compute the sprite size based on the first frame of the current animation.
     * This is called automatically when autoComputeSize is true and an animation is set.
     */
    public function computeSizeFromAnimation() {

        if (animationName != null && sheet != null) {
            var sheetAnimations = sheet.animations;
            var foundAnimation = null;
            if (sheetAnimations != null) {
                for (i in 0...sheetAnimations.length) {
                    var sheetAnimation = sheetAnimations.unsafeGet(i);
                    if (sheetAnimation.name == animationName) {
                        foundAnimation = sheetAnimation;
                        break;
                    }
                }
            }
            if (foundAnimation != null && foundAnimation.frames != null && foundAnimation.frames.length > 0) {
                var region = foundAnimation.frames[0].region;
                if (region != null) {
                    width = region.originalWidth * region.frameWidth / region.width;
                    height = region.originalHeight * region.frameHeight / region.height;
                }
            }
        }

    }

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        super.set_width(width);
        contentDirty = true;
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        super.set_height(height);
        contentDirty = true;
        return height;
    }

    /**
     * Set to `false` if you want to disable auto update on this sprite object.
     * If auto update is disabled, you become responsible to explicitly call
     * `update(delta)` at every frame yourself. Use this if you want to have control over
     * when the animation update is actually happening. Don't use it to pause animation.
     * (animation can be paused with `paused` property instead)
     */
    public var autoUpdate:Bool = true;

    /**
     * Is this sprite paused?
     * When true, animation playback is suspended but time is preserved.
     */
    public var paused:Bool = false;

    /**
     * Is this sprite looping?
     * When true, animation restarts from beginning after completion.
     * When false, animation stops on the last frame.
     */
    public var loop:Bool = true;

    /**
     * The internal quad used to render the sprite frame.
     * This is automatically managed by the sprite.
     */
    public var quad(default,null):Quad;

    /**
     * Current playback time in seconds within the animation.
     * Automatically increments during update unless paused.
     */
    public var time(default,null):Float = 0;

    /**
     * Internal flag tracking when animation data needs to be refreshed.
     */
    var currentAnimationDirty:Bool = false;

    /**
     * The current animation data from the sprite sheet.
     * Automatically resolved from animationName when accessed.
     */
    public var currentAnimation(get, null):SpriteSheetAnimation = null;
    function get_currentAnimation():SpriteSheetAnimation {
        // Process current animation (if needed)
        if (currentAnimationDirty) {
            if (sheet != null && animationName != null) {
                var sheetAnimations = sheet.animations;
                var foundAnimation = null;
                if (sheetAnimations != null) {
                    for (i in 0...sheetAnimations.length) {
                        var sheetAnimation = sheetAnimations.unsafeGet(i);
                        if (sheetAnimation.name == animationName) {
                            foundAnimation = sheetAnimation;
                            break;
                        }
                    }
                }
                if (foundAnimation == null) {
                    log.warning('Failed to find sprite animation: $animation');
                }
                this.currentAnimation = foundAnimation;
                currentAnimationFrame = null;
            }
            else {
                this.currentAnimation = null;
                currentAnimationFrame = null;
            }
            currentAnimationDirty = false;
        }
        return this.currentAnimation;
    }

    /**
     * The current frame being displayed from the animation.
     */
    var currentAnimationFrame:SpriteSheetFrame = null;

    /**
     * Create a new Sprite instance.
     * The sprite is automatically added to the SpriteSystem for updates.
     */
    public function new() {

        super();

        quad = new Quad();
        quad.inheritAlpha = true;
        add(quad);

        SpriteSystem.shared.sprites.push(cast this);

    }

    #if cs
    /**
     * Internal method for C# target compatibility.
     */
    function _updateIfNotPausedAndAutoUpdating(delta:Float) {
        if (!paused && autoUpdate) {
            update(delta);
        }
    }
    #end

    /**
     * Update the sprite animation.
     * This is called automatically each frame if autoUpdate is true.
     * @param delta Time elapsed since last update in seconds
     */
    public function update(delta:Float):Void {

        var currentAnimation = this.currentAnimation;

        // Update frame
        var foundFrame = null;
        if (currentAnimation != null) {

            var sheetFrames = currentAnimation.frames;

            if (sheetFrames.length == 1) {
                foundFrame = sheetFrames.unsafeGet(0);
            }
            else {
                var duration:Float = currentAnimation.duration;
                var usedTime:Float = loop ? (time % duration) : Math.min(time, duration);
                if (easing != null) {
                    usedTime = Tween.ease(easing, usedTime / duration) * duration;
                }
                var consumedTime:Float = 0.0;
                for (i in 0...sheetFrames.length) {
                    var sheetFrame = sheetFrames.unsafeGet(i);
                    consumedTime += sheetFrame.duration;
                    if (consumedTime > usedTime) {
                        // Current frame matches
                        foundFrame = sheetFrame;
                        break;
                    }
                }
                // Nothing found?
                if (foundFrame == null) {
                    // Or just stay in last frame
                    if (sheetFrames.length > 0) {
                        var n = sheetFrames.length - 1;
                        foundFrame = sheetFrames.unsafeGet(n);
                    }
                }
            }
        }

        // Apply frame
        if (currentAnimationFrame != foundFrame) {
            currentAnimationFrame = foundFrame;
            region = foundFrame.region;
        }

        // Increment time
        time += delta * timeScale;

    }

    function set_region(region:TextureAtlasRegion) {

        if (quad.tile != region) {
            quad.tile = region;
            contentDirty = true;

            // When just assigning a region that does not come from an animation,
            // compute size and content right away
            if (region != null && currentAnimation == null) {

                if (autoComputeSize) {
                    width = region.originalWidth * region.frameWidth / region.width;
                    height = region.originalHeight * region.frameHeight / region.height;
                }

                computeContent();
            }
        }

        return region;

    }

    /**
     * Compute the visual content of the sprite.
     * Updates the internal quad position and texture based on the current frame.
     * This is called automatically when contentDirty is true.
     */
    override function computeContent() {

        var region = this.region;
        if (region != null) {
            quad.active = true;
            quad.tile = region;
            var quadX:Float = frameOffsetX;
            var quadY:Float = frameOffsetY;
            quad.pos(
                quadX + region.offsetX * region.frameWidth / region.width,
                quadY + region.offsetY * region.frameHeight / region.height
            );
        }
        else {
            quad.active = false;
            quad.texture = null;
        }

        contentDirty = false;

    }

    /**
     * Destroy this sprite and remove it from the update system.
     */
    override function destroy() {

        SpriteSystem.shared.sprites.remove(cast this);

        super.destroy();

    }

}
