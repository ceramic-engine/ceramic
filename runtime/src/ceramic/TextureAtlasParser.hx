package ceramic;

using StringTools;

/**
 * Parser for texture atlas definition files in multiple formats.
 * 
 * TextureAtlasParser reads and parses atlas definition files that describe
 * how images are packed into texture pages. It supports:
 * - LibGDX/Spine text format (.atlas)
 * - Starling/Sparrow XML format (.xml)
 * - Automatic format detection based on content
 * 
 * The parser extracts:
 * - Page definitions with texture file references
 * - Region coordinates and dimensions
 * - Trimming information (offsets and original sizes)
 * - Rotation data for optimally packed regions
 * - Filtering modes per page
 * 
 * ```haxe
 * // Parse LibGDX format atlas
 * var atlasData = Assets.text('sprites.atlas');
 * var atlas = TextureAtlasParser.parse(atlasData);
 * 
 * // Load textures for each page
 * for (page in atlas.pages) {
 *     page.texture = Assets.texture(page.name);
 * }
 * 
 * // Compute UV coordinates
 * atlas.computeFrames();
 * ```
 * 
 * @see TextureAtlas The resulting atlas structure
 * @see TextureAtlasRegion Individual regions parsed from the file
 * @see AtlasAsset For automatic loading and parsing
 */
class TextureAtlasParser {

    /**
     * Parses a texture atlas definition file into a TextureAtlas instance.
     * 
     * Automatically detects the format based on content:
     * - XML format: Starts with '<' (Starling/Sparrow)
     * - Text format: LibGDX/Spine format
     * 
     * The parser handles:
     * - Multiple pages with different textures
     * - Regions with trimming and rotation
     * - Filter settings per page
     * - Automatic file extension stripping from region names
     * 
     * @param rawTextureAtlas The raw text content of the atlas file
     * @return Parsed TextureAtlas ready for texture assignment
     * @throws String if the atlas format is invalid
     */
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
                    page = new TextureAtlasPage(line);

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

    /**
     * Converts Starling/Sparrow XML format to LibGDX text format.
     * 
     * This internal method transforms XML atlas definitions into the
     * text-based format that the main parser understands. It extracts:
     * - Image path from root element
     * - SubTexture elements with coordinates
     * - Frame offsets for trimmed sprites
     * - Rotation flags
     * 
     * @param rawTextureAtlas XML content to convert
     * @return Equivalent atlas data in text format
     * @throws Dynamic if XML parsing fails
     */
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

/**
 * Internal line-based reader for parsing LibGDX format atlas files.
 * 
 * Provides utilities for reading key-value pairs and comma-separated
 * tuples from the text-based atlas format. Handles cross-platform
 * line endings and whitespace trimming.
 */
@:allow(ceramic.TextureAtlasParser)
private class TextureAtlasReader
{
    /**
     * All lines from the atlas file, normalized.
     */
    private var lines:Array<String>;
    
    /**
     * Current line index for sequential reading.
     */
    private var index:Int;

    /**
     * Creates a reader for the given atlas text.
     * 
     * Normalizes line endings and splits into array for processing.
     * 
     * @param text The raw atlas file content
     */
    public function new(text:String)
    {
        lines = text.trim().replace("\r\n", "\n").replace("\r", "\n").split("\n");
        index = 0;
    }

    /**
     * Trims whitespace from a string.
     * 
     * @param value String to trim
     * @return Trimmed string
     */
    public function trim(value:String):String
    {
        return value.trim();
    }

    /**
     * Reads the next line from the atlas.
     * 
     * @return Next line or null if end of file
     */
    public function readLine():String
    {
        if (index >= lines.length)
        {
            return null;
        }
        return lines[index++];
    }

    /**
     * Peeks at the key of the next line without consuming it.
     * 
     * Used to determine what type of data follows in the atlas format.
     * Keys are the part before the colon in "key: value" lines.
     * 
     * @return The key string or null if no key found
     */
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

    /**
     * Reads a key-value line and returns the value part.
     * 
     * Expects format "key: value" and returns trimmed value.
     * 
     * @return The value after the colon
     * @throws String if line format is invalid
     */
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

    /**
     * Reads comma-separated values into a tuple array.
     * 
     * Parses lines like "key: v1, v2, v3, v4" into the provided array.
     * Handles 1, 2, or 4 value tuples as used in atlas format.
     * 
     * @param tuple Array to fill with parsed values
     * @return Number of values read (1, 2, or 4)
     * @throws String if line format is invalid
     */
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
