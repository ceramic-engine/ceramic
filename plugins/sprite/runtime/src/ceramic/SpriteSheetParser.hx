package ceramic;

import haxe.Json;

using StringTools;

/**
 * An utility to parse sprite sheet data.
 * Will try to auto-detect the type of data it is then use the correct parser for it.
 */
class SpriteSheetParser {

    public static function parseAtlas(text:String):TextureAtlas {

        text = text.ltrim();
        if (text.startsWith('{')) {
            // JSON
            var json:Dynamic = Json.parse(text);
            if (AsepriteParser.isAsepriteJson(json)) {
                return AsepriteParser.parseAtlas(json);
            }
        }

        return null;

    }

    public static function parseSheet(text:String, atlas:TextureAtlas):SpriteSheet {

        text = text.ltrim();
        if (text.startsWith('{')) {
            // JSON
            var json:Dynamic = Json.parse(text);
            if (AsepriteParser.isAsepriteJson(json)) {
                return AsepriteParser.parseSheet(json, atlas);
            }
        }

        return null;

    }

}
