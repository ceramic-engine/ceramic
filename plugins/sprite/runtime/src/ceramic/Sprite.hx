package ceramic;

import ceramic.Shortcuts.*;

class Sprite<T> extends Visual {

    public var animationName(default,null):String;

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
        return animation;
    }

    public var sheet(default,set):SpriteSheet = null;
    function set_sheet(sheet:SpriteSheet):SpriteSheet {
        if (this.sheet == sheet) return sheet;
        this.sheet = sheet;
        time = 0;
        currentAnimationDirty = true;
        return sheet;
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

    public var frameDirty:Bool = false;

    var currentAnimationDirty:Bool = false;

    var currentAnimation:SpriteSheetAnimation = null;

    var currentAnimationFrame:SpriteSheetFrame = null;

    public function new() {

        super();

        quad = new Quad();
        add(quad);

        SpriteSystem.shared.sprites.push(cast this);

    }

    public function update(delta:Float):Void {

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
                currentAnimation = foundAnimation;
                currentAnimationFrame = null;
            }
            else {
                currentAnimation = null;
                currentAnimationFrame = null;
            }
            currentAnimationDirty = false;
        }

        // Update frame
        var foundFrame = null;
        if (currentAnimation != null) {

            var sheetFrames = currentAnimation.frames;

            if (sheetFrames.length == 1) {
                foundFrame = sheetFrames.unsafeGet(0);
            }
            else {
                var totalTime = 0.0;
                for (i in 0...sheetFrames.length) {
                    var sheetFrame = sheetFrames.unsafeGet(i);
                    totalTime += sheetFrame.duration;
                    if (totalTime > time) {
                        // Current frame matches
                        foundFrame = sheetFrame;
                        break;
                    }
                }
                // Nothing found?
                if (foundFrame == null) {
                    if (loop) {
                        // Loop (if loop is enabled)
                        time = time % totalTime;
                        for (i in 0...sheetFrames.length) {
                            var sheetFrame = sheetFrames.unsafeGet(i);
                            totalTime += sheetFrame.duration;
                            if (totalTime > time) {
                                // Current frame matches
                                foundFrame = sheetFrame;
                                break;
                            }
                        }
                    }
                    else {
                        // Or just stay in last frame
                        if (sheetFrames.length > 0) {
                            var n = sheetFrames.length - 1;
                            foundFrame = sheetFrames.unsafeGet(n);
                        }
                    }
                }
            }
        }

        // Apply frame
        if (frameDirty || currentAnimationFrame != foundFrame) {
            currentAnimationFrame = foundFrame;
            applyFrame();
        }

        // Increment time
        time += delta;

    }

    function applyFrame() {

        var frame = currentAnimationFrame;
        if (frame != null && sheet != null) {

            quad.active = true;
            quad.texture = sheet.texture;
            var quadX:Float = width * quad.anchorX;
            var quadY:Float = height * quad.anchorY;
            if (frame.trimmed) {
                quad.pos(quadX + frame.trimX, quadY + frame.trimY);
                quad.size(frame.trimWidth, frame.trimHeight);
            }
            else {
                quad.pos(quadX, quadY);
                quad.size(frame.width, frame.height);
            }
            quad.frame(
                frame.x,
                frame.y,
                frame.width,
                frame.height
            );
        }
        else {
            quad.active = false;
            quad.texture = null;
        }
        
        frameDirty = false;

    }

    override function destroy() {

        SpriteSystem.shared.sprites.remove(cast this);

        super.destroy();

    }

}
