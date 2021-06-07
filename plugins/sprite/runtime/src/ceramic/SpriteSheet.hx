package ceramic;

import tracker.Model;
import ceramic.Assert.assert;
import ceramic.Shortcuts.*;

class SpriteSheet extends Model {

    @serialize public var animations:ReadOnlyArray<SpriteSheetAnimation> = [];

    @serialize public var image:SpriteSheetImage = null;

    @serialize public var gridWidth:Int = -1;

    @serialize public var gridHeight:Int = -1;

    inline public function grid(gridWidth:Int, gridHeight:Int):Void {
        this.gridWidth = gridWidth;
        this.gridHeight = gridHeight;
    }

    /**
     * Internal: `true` if SpriteSheetImage instance was created
     * implicitly from assigning a texture object.
     */
    var implicitImage:Bool = false;

    /**
     * The texture used to display sprites in this spritesheet.
     * This is a shorthand of `image.texture`
     */
    public var texture(get, set):Texture;
    inline function get_texture():Texture {
        return image != null ? unobservedImage.texture : null;
    }
    function set_texture(texture:Texture):Texture {
        if (texture != null) {
            if (unobservedImage == null || unobservedImage.texture != texture) {
                unobservedImage = new SpriteSheetImage();
                implicitImage = true;
                unobservedImage.texture = texture;
            }
        }
        else {
            unobservedImage = null;
        }
        return texture;
    }

/// Helpers

    public function extractAsepriteData(asepriteData:Dynamic):Void {

        log.warning('Not implemented (todo)');

    }

    public function addAnimation(animation:SpriteSheetAnimation):Void {

        var animations = [].concat(this.animations.original);
        animations.push(animation);
        this.animations = animations;

    }

    /**
     * This can be used to configure animations on simple grid spritesheets.
     * @param name Name of the animation to add
     * @param start Start cell of the animation
     * @param end End cell of the animation
     * @param frameDuration Duration of a single frame
     * @return SpriteSheetAnimation the resulting animation instance
     */
    public function addGridAnimation(name:String, start:Int, end:Int, frameDuration:Float):SpriteSheetAnimation {

        assert(unobservedGridWidth > 0, 'gridWidth ($unobservedGridWidth) must be above zero before adding grid animation');
        assert(unobservedGridHeight > 0, 'gridHeight ($unobservedGridHeight) must be above zero before adding grid animation');
        assert(unobservedImage != null, 'an image must be defined before adding grid animation');

        var animation = new SpriteSheetAnimation();
        animation.name = name;

        var gridWidth = unobservedGridWidth;
        var gridHeight = unobservedGridHeight;
        var imageWidth = Math.floor(unobservedImage.width / gridWidth) * gridWidth;
        var cellsByRow = Math.round(imageWidth / gridWidth);

        var frames = [];
        var i = start;
        while (i <= end) {

            var column = i % cellsByRow;
            var row = Math.floor(i / cellsByRow);

            var frame = new SpriteSheetFrame();
            frame.duration = frameDuration;
            frame.frame(
                column * gridWidth,
                row * gridHeight,
                gridWidth,
                gridHeight
            );

            frames.push(frame);

            i++;
        }

        animation.frames = frames;

        addAnimation(animation);

        return animation;

    }

}