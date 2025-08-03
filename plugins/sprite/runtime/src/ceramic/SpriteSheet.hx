package ceramic;

import ceramic.Assert.assert;
import ceramic.Shortcuts.*;
import tracker.Model;

using ceramic.Extensions;

/**
 * Container for sprite animations and texture atlas data.
 * Manages frame-based animations with timing information and texture regions.
 * 
 * Can be created from:
 * - Aseprite JSON exports via SpriteAsset
 * - Manual configuration using grid-based animations
 * - Custom animation definitions
 * 
 * Example usage:
 * ```haxe
 * // Load from asset
 * var sheet = assets.sheet("character");
 * 
 * // Or create manually with grid
 * var sheet = new SpriteSheet();
 * sheet.texture = myTexture;
 * sheet.grid(32, 32);
 * sheet.addGridAnimation("walk", 0, 3, 0.1);
 * ```
 */
class SpriteSheet extends Model {

    /**
     * Array of animations available in this sprite sheet.
     * Each animation contains frames with timing information.
     */
    @serialize public var animations:ReadOnlyArray<SpriteSheetAnimation> = [];

    /**
     * The texture atlas containing all sprite frames.
     * Automatically manages asset retention when changed.
     */
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

    /**
     * Grid cell width for grid-based sprite sheets.
     * Set to -1 when not using grid layout.
     */
    @serialize public var gridWidth:Int = -1;

    /**
     * Grid cell height for grid-based sprite sheets.
     * Set to -1 when not using grid layout.
     */
    @serialize public var gridHeight:Int = -1;

    /**
     * Configure the sprite sheet as a grid with uniform cell dimensions.
     * Required before using addGridAnimation().
     * @param gridWidth Width of each cell in pixels
     * @param gridHeight Height of each cell in pixels
     */
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
     * Setting this creates an implicit atlas if one doesn't exist.
     * This is a convenience property for simple single-texture sprite sheets.
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
                unobservedAtlas.pages[0] = new TextureAtlasPage(
                    'page0',
                    texture.width,
                    texture.height,
                    texture.filter,
                    texture
                );
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
     * The reference to the sprite sheet source file path.
     * Used for debugging and asset tracking.
     */
    @serialize public var source:String = null;

    /**
     * The asset instance that loaded this sprite sheet.
     * Null if the sheet was created manually.
     */
    public var asset:SpriteAsset = null;

/// Lifecycle

    override function destroy() {

        if (atlas != null && implicitAtlas) {
            var _atlas = atlas;
            atlas = null;
            _atlas.destroy();
        }

        if (asset != null) {
            var _asset = asset;
            asset = null;
            _asset.destroy();
        }

        super.destroy();

    }

/// Helpers

    /**
     * Find an animation by name.
     * @param name The animation name to search for
     * @return The animation if found, null otherwise
     */
    public function animation(name:String):Null<SpriteSheetAnimation> {

        for (i in 0...animations.length) {
            final anim = animations.unsafeGet(i);
            if (anim.name == name) {
                return anim;
            }
        }

        return null;

    }

    /**
     * Add a new animation to this sprite sheet.
     * @param animation The animation to add
     */
    public function addAnimation(animation:SpriteSheetAnimation):Void {

        var animations = [].concat(this.animations.original);
        animations.push(animation);
        this.animations = animations;

    }

    /**
     * Add an animation using grid cell indices.
     * Requires grid dimensions to be set first via grid().
     * Cells are numbered left-to-right, top-to-bottom starting from 0.
     * @param name Name of the animation to add
     * @param start Start cell index (inclusive)
     * @param end End cell index (inclusive)
     * @param frameDuration Duration of each frame in seconds
     * @return The created animation instance
     */
    public extern inline overload function addGridAnimation(name:String, start:Int, end:Int, frameDuration:Float):SpriteSheetAnimation {

        return _addGridAnimation(name, cellsFromStartEnd(start, end), frameDuration);

    }

    /**
     * Add an animation using specific grid cell indices.
     * Allows non-sequential frame ordering.
     * @param name Name of the animation to add
     * @param cells Array of cell indices to include in the animation
     * @param frameDuration Duration of each frame in seconds
     * @return The created animation instance
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
