package ceramic;

import haxe.Json;

using StringTools;

/**
 * Generic sprite sheet data parser with auto-detection.
 * Automatically identifies the format of sprite sheet data and
 * delegates to the appropriate parser.
 * 
 * Currently supports:
 * - Aseprite JSON format (detected by JSON structure)
 * 
 * The parser is extensible - new formats can be added by checking
 * for format-specific markers and delegating to appropriate parsers.
 */
class SpriteSheetParser {

    /**
     * Parse sprite sheet data into a TextureAtlas.
     * Auto-detects the format and uses the appropriate parser.
     * @param text Raw sprite sheet data text
     * @return Parsed TextureAtlas, or null if format is not recognized
     */
    public static function parseAtlas(text:String):TextureAtlas {

        text = text.ltrim();
        if (text.startsWith('{')) {
            // JSON format detected
            var json:Dynamic = Json.parse(text);
            if (AsepriteJsonParser.isAsepriteJson(json)) {
                return AsepriteJsonParser.parseAtlasFromJson(json);
            }
        }

        return null;

    }

    /**
     * Parse sprite sheet data into a SpriteSheet with animations.
     * Auto-detects the format and uses the appropriate parser.
     * @param text Raw sprite sheet data text
     * @param atlas The TextureAtlas to use for this sheet
     * @return Parsed SpriteSheet with animations, or null if format is not recognized
     */
    public static function parseSheet(text:String, atlas:TextureAtlas):SpriteSheet {

        text = text.ltrim();
        if (text.startsWith('{')) {
            // JSON format detected
            var json:Dynamic = Json.parse(text);
            if (AsepriteJsonParser.isAsepriteJson(json)) {
                return AsepriteJsonParser.parseSheetFromJson(json, atlas);
            }
        }

        return null;

    }

}
