package ceramic;

import ceramic.Shortcuts.*;

class Sprite<T=String> extends Visual {

    public var autoComputeSize:Bool = true;

    public var region(get, set):TextureAtlasRegion;
    inline function get_region():TextureAtlasRegion {
        return quad.tile != null ? cast quad.tile : null;
    }

    public var animationName(default,null):String;

    public var easing(default,null):Easing = null;

    public var timeScale:Float = 1.0;

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

    public var frameOffsetX(default,set):Float = 0;
    function set_frameOffsetX(frameOffsetX:Float):Float {
        if (this.frameOffsetX != frameOffsetX) {
            this.frameOffsetX = frameOffsetX;
            contentDirty = true;
        }
        return frameOffsetX;
    }

    public var frameOffsetY(default,set):Float = 0;
    function set_frameOffsetY(frameOffsetY:Float):Float {
        if (this.frameOffsetY != frameOffsetY) {
            this.frameOffsetY = frameOffsetY;
            contentDirty = true;
        }
        return frameOffsetY;
    }

    public function frameOffset(anchorX:Float, anchorY:Float) {
        this.frameOffsetX = anchorX;
        this.frameOffsetY = anchorY;
    }

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
     */
    public var paused:Bool = false;

    /**
     * Is this sprite looping?
     */
    public var loop:Bool = true;

    public var quad(default,null):Quad;

    public var time(default,null):Float = 0;

    var currentAnimationDirty:Bool = false;

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

    var currentAnimationFrame:SpriteSheetFrame = null;

    public function new() {

        super();

        quad = new Quad();
        add(quad);

        SpriteSystem.shared.sprites.push(cast this);

    }

    #if cs
    function _updateIfNotPausedAndAutoUpdating(delta:Float) {
        if (!paused && autoUpdate) {
            update(delta);
        }
    }
    #end

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
        time += delta / timeScale;

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

    override function computeContent() {

        var region = this.region;
        if (region != null) {
            quad.active = true;
            quad.tile = region;
            var frameW = region.originalWidth * region.frameWidth / region.width;
            var frameH = region.originalHeight * region.frameHeight / region.height;
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

    override function destroy() {

        SpriteSystem.shared.sprites.remove(cast this);

        super.destroy();

    }

}
