package ceramic;

import ceramic.Assert.assert;
import ceramic.Shortcuts.*;
import tracker.Model;

using ceramic.Extensions;

class SpriteSheet extends Model {

    @serialize public var animations:ReadOnlyArray<SpriteSheetAnimation> = [];

    @observe public var atlas(default,set):TextureAtlas = null;
    function set_atlas(atlas:TextureAtlas):TextureAtlas {
        if (this.atlas == atlas) return atlas;
        var prevAtlas = this.atlas;
        if (prevAtlas != null) {
            if (prevAtlas.asset != null) {
                prevAtlas.asset.offReplaceAtlas(replaceAtlas);
            }
            if (prevAtlas.asset != null) prevAtlas.asset.release();
            if (implicitAtlas)
                prevAtlas.destroy();
        }
        this.atlas = atlas;
        implicitAtlas = false;
        if (this.atlas != null) {
            if (this.atlas.asset != null) {
                this.atlas.asset.onReplaceAtlas(this, replaceAtlas);
            }
            if (this.atlas.asset != null) this.atlas.asset.retain();
        }
        return atlas;
    }

    @serialize public var gridWidth:Int = -1;

    @serialize public var gridHeight:Int = -1;

    inline public function grid(gridWidth:Int, gridHeight:Int):Void {
        this.gridWidth = gridWidth;
        this.gridHeight = gridHeight;
    }

    /**
     * Internal: `true` if SpriteSheetAtlas instance was created
     * implicitly from assigning a texture object.
     */
    var implicitAtlas:Bool = false;

    /**
     * The texture used to display sprites in this spritesheet.
     * This is a shorthand of `image.texture`
     */
    public var texture(get, set):Texture;
    inline function get_texture():Texture {
        return atlas != null ? unobservedAtlas.pages[0].texture : null;
    }
    function set_texture(texture:Texture):Texture {
        var prevAtlas = unobservedAtlas;
        var wasImplicitAtlas = implicitAtlas;

        var prevTexture = wasImplicitAtlas && prevAtlas != null ? prevAtlas.pages[0].texture : null;
        if (prevTexture != null) {
            if (prevTexture.asset != null) {
                prevTexture.asset.offReplaceTexture(replaceTexture);
                prevTexture.asset.release();
            }
        }

        if (texture != null) {
            if (texture.asset != null) {
                texture.asset.onReplaceTexture(this, replaceTexture);
                texture.asset.retain();
            }
            if (unobservedAtlas == null || unobservedAtlas.pages[0].texture != texture) {
                unobservedAtlas = new TextureAtlas();
                implicitAtlas = true;
                unobservedAtlas.pages[0] = {
                    name: 'page0',
                    width: texture.width,
                    height: texture.height,
                    filter: texture.filter,
                    texture: texture
                };
            }
        }
        else {
            unobservedAtlas = null;
            implicitAtlas = false;
        }
        if (wasImplicitAtlas && prevAtlas != null) {
            prevAtlas.destroy();
        }
        return texture;
    }

    /**
     * The reference to the sprite sheet file
     */
    @serialize public var source:String = null;

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
     public extern inline overload function addGridAnimation(name:String, start:Int, end:Int, frameDuration:Float):SpriteSheetAnimation {

        return _addGridAnimation(name, cellsFromStartEnd(start, end), frameDuration);

    }

    /**
     * This can be used to configure animations on simple grid spritesheets.
     * @param name Name of the animation to add
     * @param cells Cell array of the animation
     * @param frameDuration Duration of a single frame
     * @return SpriteSheetAnimation the resulting animation instance
     */
    public extern inline overload function addGridAnimation(name:String, cells:Array<Int>, frameDuration:Float):SpriteSheetAnimation {

        return _addGridAnimation(name, cells, frameDuration);

    }

    private function _addGridAnimation(name:String, cells:Array<Int>, frameDuration:Float):SpriteSheetAnimation {

        assert(unobservedGridWidth > 0, 'gridWidth ($unobservedGridWidth) must be above zero before adding grid animation');
        assert(unobservedGridHeight > 0, 'gridHeight ($unobservedGridHeight) must be above zero before adding grid animation');
        assert(unobservedAtlas != null, 'an atlas/texture must be defined before adding grid animation');

        var animation = new SpriteSheetAnimation();
        animation.name = name;

        var gridWidth = unobservedGridWidth;
        var gridHeight = unobservedGridHeight;
        var imageWidth = Math.floor(unobservedAtlas.pages[0].width / gridWidth) * gridWidth;
        var cellsByRow = Math.round(imageWidth / gridWidth);

        var frames = [];
        for (n in 0...cells.length) {

            var i = cells.unsafeGet(n);
            var column = i % cellsByRow;
            var row = Math.floor(i / cellsByRow);

            var frame = new SpriteSheetFrame(unobservedAtlas, name + '#' + i, 0);
            frame.duration = frameDuration;
            var region = frame.region;
            region.width = gridWidth;
            region.height = gridHeight;
            region.originalWidth = gridWidth;
            region.originalHeight = gridHeight;
            region.packedWidth = gridWidth;
            region.packedHeight = gridHeight;
            region.frame(
                column * gridWidth,
                row * gridHeight,
                gridWidth,
                gridHeight
            );

            frames.push(frame);
        }

        animation.frames = frames;

        addAnimation(animation);

        return animation;

    }

/// Internal

    function cellsFromStartEnd(start:Int, end:Int):Array<Int> {

        var cells:Array<Int> = [];

        var i = start;
        do {
            cells.push(i);
            i++;
        }
        while (i <= end);

        return cells;

    }

    function replaceAtlas(newAtlas:TextureAtlas, prevAtlas:TextureAtlas) {

        this.atlas = newAtlas;

    }

    function replaceTexture(newTexture:Texture, prevTexture:Texture) {

        var atlas = this.atlas;
        if (implicitAtlas && atlas != null) {
            // Update animation frames to point to correct texture & atlas
            atlas.pages[0].texture = newTexture;
            for (i in 0...animations.length) {
                var animation = animations.unsafeGet(i);
                var frames = animation.frames;
                for (j in 0...frames.length) {
                    var frame = frames.unsafeGet(j);
                    var region = frame.region;
                    if (region.texture == prevTexture) {
                        region.atlas = atlas;
                        region.texture = newTexture;
                    }
                }
            }
        }

    }

}
