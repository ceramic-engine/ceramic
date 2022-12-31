package ceramic;

import ceramic.Shortcuts.*;

enum abstract AsepriteFrameTagDirection(String) {

    var FORWARD = "forward";

    var REVERSE = "reverse";

    var PINGPONG = "pingpong";

}

typedef AsepriteData = {

    var frames:Array<AsepriteFrame>;

    var meta:AsepriteMeta;

}

typedef AsepriteMeta = {

    var app:String;

    var version:String;

    var image:String;

    var format:String;

    var size:AsepriteSize;

    var scale:String;

    var frameTags:Array<AsepriteFrameTag>;

    var layers:Array<AsepriteLayer>;

    var slices:Array<AsepriteSlice>;

}

typedef AsepriteFrameTag = {

    var name:String;

    var from:Int;

    var to:Int;

    var direction:AsepriteFrameTagDirection;

}

typedef AsepriteLayer = {

    var name:String;

    var opacity:Int;

    var blendMode:String;

}

typedef AsepriteSlice = {

}

typedef AsepriteFrame = {

    var filename:String;

    var frame:AsepriteRect;

    var rotated:Bool;

    var trimmed:Bool;

    var spriteSourceSize:AsepriteRect;

    var sourceSize:AsepriteSize;

    var duration:Float;

}

typedef AsepriteRect = {

    var x:Float;

    var y:Float;

    var w:Float;

    var h:Float;

}

typedef AsepriteSize = {

    var w:Float;

    var h:Float;

}

/**
 * Utility class to parse sprite sheet json data exported by aseprite
 */
class AsepriteParser {

    static var didLogHashWarning:Bool = false;

    public static function isAsepriteJson(json:Dynamic):Bool {

        if (json != null && json.frames != null) {
            // Aseprite
            if (Std.isOfType(json.frames, Array)) {
                return true;
            }
            else {
                if (!didLogHashWarning) {
                    didLogHashWarning = true;
                    log.warning('Aseprite format with frames as hash is not supported. Please export using array.');
                }
            }
        }

        return false;

    }

    public static function parseAtlas(data:AsepriteData):TextureAtlas {

        var page:TextureAtlasPage = {
            name: data.meta.image,
            width: data.meta.size.w,
            height: data.meta.size.h,
            filter: NEAREST
        };

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

    public static function parseSheet(data:AsepriteData, atlas:TextureAtlas):SpriteSheet {

        var sheet = new SpriteSheet();

        sheet.atlas = atlas;

        var animations:Array<SpriteSheetAnimation> = [];

        for (frameTag in data.meta.frameTags) {

            var animation = new SpriteSheetAnimation();
            animation.name = frameTag.name;

            var from:Int = Std.int(frameTag.from);
            var to:Int = Std.int(frameTag.to);

            var frames:Array<SpriteSheetFrame> = [];

            inline function addFrame(index:Int) {

                var region = atlas.regions[index];
                var frame = new SpriteSheetFrame(atlas, region.name, 0, region);
                frame.duration = data.frames[index].duration * 0.001;
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