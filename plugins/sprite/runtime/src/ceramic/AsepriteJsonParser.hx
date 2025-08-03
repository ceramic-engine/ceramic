package ceramic;

import ceramic.Shortcuts.*;

/**
 * Parser for Aseprite JSON format sprite sheets.
 * Converts Aseprite JSON data into Ceramic's TextureAtlas and SpriteSheet structures.
 * 
 * Supports:
 * - Frame extraction with trimming and rotation
 * - Animation sequences from frame tags
 * - Directional playback (forward, reverse, pingpong)
 * - Frame timing information
 * 
 * Note: Only supports the array format for frames, not the hash format.
 */
class AsepriteJsonParser {

    /**
     * Internal flag to prevent spamming warnings about unsupported formats.
     */
    static var didLogHashWarning:Bool = false;

    /**
     * Check if the provided JSON data is in Aseprite format.
     * @param json The JSON data to validate
     * @return True if this is valid Aseprite JSON with frames as an array
     */
    public static function isAsepriteJson(json:Dynamic):Bool {

        if (json != null && json.frames != null) {
            // Aseprite JSON
            if (Std.isOfType(json.frames, Array)) {
                return true;
            }
            else {
                if (!didLogHashWarning) {
                    didLogHashWarning = true;
                    log.warning('Aseprite JSON format with frames as hash is not supported. Please export using array.');
                }
            }
        }

        return false;

    }

    /**
     * Parse Aseprite JSON data into a TextureAtlas.
     * Creates texture regions for each frame in the sprite sheet.
     * @param data The Aseprite JSON data
     * @return A TextureAtlas containing all frame regions
     */
    public static function parseAtlasFromJson(data:AsepriteJson):TextureAtlas {

        var page:TextureAtlasPage = new TextureAtlasPage(
            data.meta.image,
            data.meta.size.w,
            data.meta.size.h,
            NEAREST
        );

        var atlas = new TextureAtlas();
        atlas.pages.push(page);

        for (frame in data.frames) {

            var region = new TextureAtlasRegion(
                frame.filename, atlas, 0
            );

            region.x = Math.round(frame.frame.x + (frame.frame.w - frame.spriteSourceSize.w) * 0.5);
            region.y = Math.round(frame.frame.y + (frame.frame.h - frame.spriteSourceSize.h) * 0.5);
            region.originalWidth = Std.int(frame.sourceSize.w);
            region.originalHeight = Std.int(frame.sourceSize.h);
            region.width = Std.int(frame.spriteSourceSize.w);
            region.height = Std.int(frame.spriteSourceSize.h);
            region.offsetX = Std.int(frame.spriteSourceSize.x);
            region.offsetY = Std.int(frame.spriteSourceSize.y);

            region.rotateFrame = frame.rotated;
            if (region.rotateFrame) {
                region.packedWidth = region.height;
                region.packedHeight = region.width;
            } else {
                region.packedWidth = region.width;
                region.packedHeight = region.height;
            }

        }

        return atlas;

    }

    /**
     * Parse Aseprite JSON data into a SpriteSheet with animations.
     * Creates animation sequences from frame tags with proper timing.
     * @param data The Aseprite JSON data
     * @param atlas The TextureAtlas containing frame regions
     * @return A SpriteSheet with all animations configured
     */
    public static function parseSheetFromJson(data:AsepriteJson, atlas:TextureAtlas):SpriteSheet {

        var sheet = new SpriteSheet();

        sheet.atlas = atlas;

        var animations:Array<SpriteSheetAnimation> = [];

        for (frameTag in data.meta.frameTags) {

            var animation = new SpriteSheetAnimation();
            animation.name = frameTag.name;

            var from:Int = Std.int(frameTag.from);
            var to:Int = Std.int(frameTag.to);

            var frames:Array<SpriteSheetFrame> = [];

            /**
             * Helper function to add a frame to the animation.
             * @param index Frame index in the atlas
             */
            inline function addFrame(index:Int) {

                var region = atlas.regions[index];
                var frame = new SpriteSheetFrame(atlas, region.name, 0, region);
                frame.duration = data.frames[index].duration * 0.001; // Convert ms to seconds
                frames.push(frame);

            }

            switch frameTag.direction {

                case FORWARD:
                    var i = from;
                    while (i <= to) {
                        addFrame(i);
                        i++;
                    }

                case REVERSE:
                    var i = to;
                    while (i >= from) {
                        addFrame(i);
                        i--;
                    }

                case PINGPONG:
                    var i = from;
                    while (i <= to) {
                        addFrame(i);
                        i++;
                    }
                    i = to - 1;
                    while (i > from) {
                        addFrame(i);
                        i--;
                    }
            }

            animation.frames = frames;
            animations.push(animation);
        }

        sheet.animations = animations;

        return sheet;

    }

}