package ceramic;

using StringTools;

// Some portions of this code taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/luxe/importers/bitmapfont/BitmapFontParser.hx)

class BitmapFontParser {

/// Public API

    public static function parse(rawFontData:String):BitmapFontData {

        if (rawFontData.length == 0) {
            throw "BitmapFont: fontData is 0 length";
        }

        if (rawFontData.trim().startsWith('<')) {
            try {
                rawFontData = convertXmlFontData(rawFontData);
            }
            catch (e:Dynamic) {
                throw "BitmapFont: invalid xml font data specified for parser: " + e;
            }
        }

        var info:BitmapFontData = {
            path: '.',
            face: null,
            chars: new IntMap(),
            distanceField: null,
            pointSize: 0,
            baseSize: 0,
            charCount: 0,
            lineHeight: 0,
            pages: [],
            kernings: new IntMap()
        };

        var lines:Array<String> = rawFontData.replace("\r", '').replace("\t", ' ').split("\n");

        if (lines.length == 0) {
            throw "BitmapFont: invalid font data specified for parser.";
        }

        var first = lines[0];
        if (StringTools.ltrim(first).substr(0, 4) != 'info') {
            throw "BitmapFont: invalid font data specified for parser. Format should be plain ascii text .fnt file only currently.";
        }

        for (line in lines) {
            parseLine(line, info);
        }

        lines = null;

        return info;

    }

/// From XML

    static function convertXmlFontData(rawFontData:String):String {

        var result = new StringBuf();

        inline function addValue(attr:String, value:String) {
            if (attr == 'face' || attr == 'char' || attr == 'file' || value.indexOf(' ') != -1 || value.indexOf('"') != -1 || value.indexOf('=') != -1) {
                result.add(haxe.Json.stringify(value));
            }
            else {
                result.add(value);
            }
        }

        inline function addElementAndAttributes(el:Xml) {
            result.add(el.nodeName);
            for (attr in el.attributes()) {
                var value = el.get(attr);
                if (value != null) {
                    result.add(' ');
                    result.add(attr);
                    result.add('=');
                    addValue(attr, value);
                }
            }
            result.add('\n');
        }

        var xml = Xml.parse(rawFontData).firstElement();

        for (el in xml.elements()) {
            switch el.nodeName {
                default:
                    addElementAndAttributes(el);
                case 'pages' | 'chars':
                    if (el.nodeName == 'chars') {
                        addElementAndAttributes(el);
                    }
                    for (subEl in el.elements()) {
                        addElementAndAttributes(subEl);
                    }
            }
        }

        return result.toString();

    }

/// Internal

    static function parseLine(line:String, info:BitmapFontData) {

        var items = new Map();
        var firstToken = extractLineTokens(line, items);

        switch (firstToken) {

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
                    id: Std.parseInt(items['id']),
                    file: StringTools.trim(unquote(items['file']))
                });
            }

            case 'chars': {
                info.charCount = Std.parseInt(items["count"]);
            }

            case 'char': {

                var char: BitmapFontCharacter = {
                    id: Std.parseInt(items["id"]),
                    x: Std.parseFloat(items["x"]),
                    y: Std.parseFloat(items["y"]),
                    width: Std.parseFloat(items["width"]),
                    height: Std.parseFloat(items["height"]),
                    xOffset: Std.parseFloat(items["xoffset"]),
                    yOffset: Std.parseFloat(items["yoffset"]),
                    xAdvance: Std.parseFloat(items["xadvance"]),
                    page: Std.parseInt(items["page"])
                };

                info.chars.set(char.id, char);

            }

            case 'kerning': {

                var first = Std.parseInt(items["first"]);
                var second = Std.parseInt(items["second"]);
                var amount = Std.parseFloat(items["amount"]);

                var map = info.kernings.get(first);
                if (map == null) {
                    map = new IntFloatMap();
                    info.kernings.set(first, map);
                }

                map.set(second, amount);

            }

            case 'distanceField': {

                var fieldType = items["fieldType"];
                var distanceRange = Std.parseInt(items["distanceRange"]);

                info.distanceField = {
                    fieldType: fieldType,
                    distanceRange: distanceRange
                };

            }

            default:
        }

    }

    static function extractLineTokens(line:String, map:Map<String,String>):String {

        var i = 0;
        var len = line.length;
        var firstToken:String = null;
        var keyToken:String = null;
        var nextToken:StringBuf = null;
        var inQuotes = false;

        while (i < len) {

            var c = line.charCodeAt(i);

            if (inQuotes) {
                if (c == '\\'.code) {
                    c = line.charCodeAt(i);
                    i++;
                }
                else if (c == '"'.code) {
                    inQuotes = false;
                }
                if (nextToken == null) {
                    throw 'Invalid bitmap font line: $line';
                }
                nextToken.add(line.charAt(i));
            }
            else if (c == ' '.code) {
                if (nextToken != null) {
                    if (firstToken == null) {
                        firstToken = nextToken.toString();
                    }
                    else if (keyToken == null) {
                        keyToken = nextToken.toString();
                        map.set(keyToken, null);
                    }
                    else {
                        map.set(keyToken, nextToken.toString());
                    }
                    keyToken = null;
                    nextToken = null;
                }
            }
            else if (keyToken == null && c == '='.code) {
                if (nextToken == null) {
                    throw 'Invalid bitmap font line: $line';
                }
                keyToken = nextToken.toString();
                nextToken = null;
            }
            else {
                if (c == '"'.code) {
                    inQuotes = true;
                }
                if (nextToken == null) {
                    nextToken = new StringBuf();
                }
                nextToken.add(line.charAt(i));
            }

            i++;

        }

        if (nextToken != null) {
            if (firstToken == null) {
                firstToken = nextToken.toString();
            }
            else if (keyToken == null) {
                keyToken = nextToken.toString();
                map.set(keyToken, null);
            }
            else {
                map.set(keyToken, nextToken.toString());
            }
            keyToken = null;
            nextToken = null;
        }

        return firstToken;

    }

    inline static function unquote(s:String) {

        var len = s.length;

        if (s.charCodeAt(0) == '"'.code && s.charCodeAt(len - 1) == '"'.code) {
            s = s.substring(1, len - 1);
        }

        return s;

    }

}
