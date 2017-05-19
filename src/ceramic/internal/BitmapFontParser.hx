package ceramic.internal;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/luxe/importers/bitmapfont/BitmapFontParser.hx)

import ceramic.BitmapFont;

class BitmapFontParser {

/// Public API

    public static function parse(rawFontData:String):BitmapFontData {

        if (rawFontData.length == 0) {
            throw "BitmapFont: fontData is 0 length";
        }

        var info : BitmapFontData = {
            face : null,
            chars : new Map(),
            pointSize : 0, baseSize : 0,
            charCount : 0, lineHeight : 0,
            pages : [], kernings : new Map()
        };

        var lines : Array<String> = rawFontData.split("\n");

        if (lines.length == 0) {
            throw "BitmapFont: invalid font data specified for parser.";
        }

        var first = lines[0];
        if (StringTools.ltrim(first).substr(0, 4) != 'info') {
            throw "BitmapFont: invalid font data specified for parser. Format should be plain ascii text .fnt file only currently.";
        }

        for (line in lines) {
            var tokens = line.split(" ");
            for (current in tokens) {
                parseToken(current, tokens, info);
            }
            tokens = null;
        }

        lines = null;

        return info;

    } //parse

/// Internal

    static function parseToken(token:String, tokens:Array<String>, info:BitmapFontData) {

        // Remove the first token
        tokens.shift();
        // Fetch the items from the line
        var items = tokenizeLine(tokens);

        switch (token) {

            case 'info': {
                info.face = unquote(items['face']);
                info.pointSize = Std.parseFloat(items['size']);
            }

            case 'common': {
                info.lineHeight = Std.parseFloat(items['lineHeight']);
                info.baseSize = Std.parseFloat(items['base']);
            }

            case 'page': {
                info.pages.push({
                    id : Std.parseInt(items['id']),
                    file : trim(unquote(items['file']))
                });
            }

            case 'chars': {
                info.charCount = Std.parseInt(items["count"]);
            }

            case 'char': {

                var char : BitmapFontCharacter = {
                    id : Std.parseInt(items["id"]),
                    x : Std.parseFloat(items["x"]),
                    y : Std.parseFloat(items["y"]),
                    width : Std.parseFloat(items["width"]),
                    height : Std.parseFloat(items["height"]),
                    xOffset : Std.parseFloat(items["xoffset"]),
                    yOffset : Std.parseFloat(items["yoffset"]),
                    xAdvance : Std.parseFloat(items["xadvance"]),
                    page : Std.parseInt(items["page"])
                }

                info.chars.set(char.id, char);

            }

            case 'kerning': {

                var first = Std.parseInt(items["first"]);
                var second = Std.parseInt(items["second"]);
                var amount = Std.parseFloat(items["amount"]);

                var map = info.kernings.get(first);
                if (map == null) {
                    map = new Map();
                    info.kernings.set(first, map);
                }

                map.set(second, amount);

            }

            default:
        }

        items = null;

    } //parseToken

    static function tokenizeLine( tokens:Array<String> ) {

        var itemMap : Map<String, String> = new Map();

        for (token in tokens) {
            var items = token.split("=");
            itemMap.set( items[0], items[1] );
            items = null;
        }

        return itemMap;

    } //tokenizeLine

    inline static function trim(s:String) { return StringTools.trim(s); }
    inline static function unquote(s:String) {
        if (s.indexOf('"') != -1) {
            s = StringTools.replace(s,'"', '');
        } return s;
    } //unquote

} //BitmapFontParser
