package ceramic;

using StringTools;

class TextureAtlasParser {

    public static function parse(rawTextureAtlas:String):TextureAtlas {

        if (rawTextureAtlas.trim().startsWith('<')) {
            try {
                rawTextureAtlas = convertXmlTextureAtlas(rawTextureAtlas);
            }
            catch (e:Dynamic) {
                throw "TextureAtlas: invalid xml atlas data specified for parser: " + e;
            }
        }

        var reader = new TextureAtlasReader(rawTextureAtlas);
        var tuple:Array<String> = [null, null, null, null];
        var page:TextureAtlasPage = null;
        var atlas = new TextureAtlas();

        while (true) {

            var line:String = reader.readLine();
            if (line == null) {
                break;
            }

            line = reader.trim(line);
            if (line.length == 0) {
                page = null;
            }
            else {
                if (page == null) {
                    page = { name: line };

                    var key = reader.nextLineKey();
                    while (key != null) {

                        switch key {

                            case 'size':
                                reader.readTuple(tuple);
                                page.width = Std.parseInt(tuple[0]);
                                page.height = Std.parseInt(tuple[1]);

                            case 'filter':
                                reader.readTuple(tuple);
                                page.filter = tuple[0] != null && tuple[0].toLowerCase() == 'nearest' ? NEAREST : LINEAR;

                            default:
                                reader.readLine();

                        }

                        key = reader.nextLineKey();
                    }

                    atlas.pages.push(page);
                }
                else
                {
                    var name = line;
                    var lowerCaseName = name.toLowerCase();
                    if (lowerCaseName.endsWith('.png') || lowerCaseName.endsWith('.gif') || lowerCaseName.endsWith('.jpg')) {
                        name = name.substr(0, name.length - 4);
                    }
                    else if (lowerCaseName.endsWith('.jpeg')) {
                        name = name.substr(0, name.length - 5);
                    }

                    var region:TextureAtlasRegion = new TextureAtlasRegion(
                        name, atlas, atlas.pages.length - 1
                    );

                    var x:Int = 0;
                    var y:Int = 0;
                    var width:Int = 0;
                    var height:Int = 0;
                    var originalWidth:Int = 0;
                    var originalHeight:Int = 0;

                    var key = reader.nextLineKey();
                    while (key != null) {

                        switch key {

                            case 'bounds':
                                reader.readTuple(tuple);
                                x = Std.parseInt(tuple[0]);
                                y = Std.parseInt(tuple[1]);
                                width = Std.parseInt(tuple[2]);
                                height = Std.parseInt(tuple[3]);

                            case 'rotate':
                                var value = reader.readValue();
                                region.rotateFrame = (value == "true" || value == "90");

                            case 'xy':
                                reader.readTuple(tuple);
                                x = Std.parseInt(tuple[0]);
                                y = Std.parseInt(tuple[1]);

                            case 'size':
                                reader.readTuple(tuple);
                                width = Std.parseInt(tuple[0]);
                                height = Std.parseInt(tuple[1]);

                            case 'orig':
                                reader.readTuple(tuple);
                                originalWidth = Std.parseInt(tuple[0]);
                                originalHeight = Std.parseInt(tuple[1]);

                            case 'offset':
                                reader.readTuple(tuple);
                                region.offsetX = Std.parseInt(tuple[0]);
                                region.offsetY = Std.parseInt(tuple[1]);

                            case 'offsets':
                                reader.readTuple(tuple);
                                region.offsetX = Std.parseInt(tuple[0]);
                                region.offsetY = Std.parseInt(tuple[1]);
                                originalWidth = Std.parseInt(tuple[2]);
                                originalHeight = Std.parseInt(tuple[3]);

                            default:
                                reader.readLine();
                        }

                        key = reader.nextLineKey();
                    }

                    region.x = x;
                    region.y = y;
                    region.width = Std.int(Math.abs(width));
                    region.height = Std.int(Math.abs(height));
                    region.originalWidth = originalWidth != 0 ? originalWidth : region.width;
                    region.originalHeight = originalHeight != 0 ? originalHeight : region.height;

                    if (region.rotateFrame) {
                        region.packedWidth = region.height;
                        region.packedHeight = region.width;
                    } else {
                        region.packedWidth = region.width;
                        region.packedHeight = region.height;
                    }
                }
            }
        }

        return atlas;

    }

/// From XML

    static function convertXmlTextureAtlas(rawTextureAtlas:String):String {

        var result = new StringBuf();

        var xml = Xml.parse(rawTextureAtlas).firstElement();

        result.add(xml.get('imagePath'));
        result.add('\n');

        for (el in xml.elements()) {
            switch el.nodeName {
                default:
                case 'SubTexture':

                    result.add(el.get('name'));
                    result.add('\n');

                    if (el.exists('frameX') &&
                        el.exists('frameY') &&
                        el.exists('frameWidth') &&
                        el.exists('frameHeight')) {

                        result.add('offsets:');
                        result.add(-Std.parseFloat(el.get('frameX')));
                        result.add(',');
                        result.add(-Std.parseFloat(el.get('frameY')));
                        result.add(',');
                        result.add(Std.parseFloat(el.get('frameWidth')));
                        result.add(',');
                        result.add(Std.parseFloat(el.get('frameHeight')));
                        result.add('\n');
                    }

                    result.add('bounds:');
                    result.add(Std.parseFloat(el.get('x')));
                    result.add(',');
                    result.add(Std.parseFloat(el.get('y')));
                    result.add(',');
                    result.add(Std.parseFloat(el.get('width')));
                    result.add(',');
                    result.add(Std.parseFloat(el.get('height')));
                    result.add('\n');

                    if (el.exists('rotate')) {
                        result.add('rotate:');
                        result.add(el.get('rotate'));
                        result.add('\n');
                    }

            }
        }

        return result.toString();

    }

}

@:allow(ceramic.TextureAtlasParser)
private class TextureAtlasReader
{
    private var lines:Array<String>;
    private var index:Int;

    public function new(text:String)
    {
        lines = text.trim().replace("\r\n", "\n").replace("\r", "\n").split("\n");
        index = 0;
    }

    public function trim(value:String):String
    {
        return value.trim();
    }

    public function readLine():String
    {
        if (index >= lines.length)
        {
            return null;
        }
        return lines[index++];
    }

    public function nextLineKey():String {

        if (index >= lines.length) {
            return null;
        }
        else {
            var line = lines[index];
            var colon = line.indexOf(':');
            if (colon != -1) {
                return line.substring(0, colon).trim();
            }
            else {
                return null;
            }
        }

    }

    public function readValue():String
    {
        var line:String = readLine();
        var colon:Int = line.indexOf(":");
        if (colon == -1)
        {
            throw "Invalid line: " + line;
        }
        return trim(line.substring(colon + 1));
    }

    /** Returns the number of tuple values read (1, 2 or 4). */
    public function readTuple(tuple:Array<Dynamic>):Int
    {
        var line:String = readLine();
        var colon:Int = line.indexOf(":");
        if (colon == -1)
        {
            throw "Invalid line: " + line;
        }
        var i:Int = 0;
        var lastMatch:Int = colon + 1;
                while (i < 3)
        {
            var comma:Int = line.indexOf(",", lastMatch);
            if (comma == -1)
            {
                break;
            }
            tuple[i] = trim(line.substr(lastMatch, comma - lastMatch));
            lastMatch = comma + 1;
            i++;
        }
        tuple[i] = trim(line.substring(lastMatch));
        return i + 1;
    }

}
