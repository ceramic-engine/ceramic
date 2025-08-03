package ceramic;

import ceramic.Shortcuts.*;
import format.tmx.Data.TmxMap;
import format.tmx.Data.TmxTileset;
import format.tmx.Reader as TmxReader;

/**
 * Internal parser for TMX (Tiled Map Editor) format files.
 * 
 * This class handles the low-level parsing of TMX XML data using the format.tmx library,
 * including support for external TSX tileset files. It implements caching for TSX files
 * to improve performance when multiple maps reference the same tilesets.
 * 
 * ## Features
 * 
 * - **TMX Parsing**: Converts TMX XML to structured data
 * - **TSX Support**: Resolves and caches external tileset files
 * - **Error Handling**: Catches and logs parsing errors
 * - **Caching**: Maintains cache of parsed TSX files by path
 * 
 * ## Internal Usage
 * 
 * This class is used internally by TilemapParser and should not be instantiated directly.
 * Use TilemapParser.parseTmx() instead.
 * 
 * @see TilemapParser
 * @see format.tmx.Reader
 */
@:noCompletion
class TilemapTmxParser {

    /**
     * Cache for parsed TSX tileset files, keyed by "cwd:filename".
     * Prevents re-parsing the same tileset multiple times.
     */
    private var tsxCache:Map<String, TmxTileset> = null;

    /**
     * TMX reader instance from the format.tmx library.
     */
    private var r:TmxReader = null;

    /**
     * Callback function to resolve external TSX file data.
     * Provided by the caller to load TSX files from disk or assets.
     */
    private var resolveTsxRawData:(name:String,cwd:String)->String = null;

    /**
     * Current working directory for resolving relative TSX paths.
     */
    private var cwd:String;

    /**
     * Creates a new TMX parser instance.
     */
    public function new() {

    }

    /**
     * Parses raw TMX XML data into a structured TmxMap object.
     * @param rawTmxData The TMX file content as an XML string
     * @param cwd Current working directory for resolving relative TSX paths
     * @param resolveTsxRawData Optional callback to load external TSX files. If not provided,
     *                          external tilesets will not be resolved
     * @return Parsed TmxMap object, or null if parsing fails
     * @throws String if rawTmxData is empty
     */
    public function parseTmx(rawTmxData:String, cwd:String, ?resolveTsxRawData:(name:String,cwd:String)->String):TmxMap {

        if (rawTmxData.length == 0) {
            throw "Tilemap: rawTmxData is 0 length";
        }

        this.resolveTsxRawData = resolveTsxRawData != null ? resolveTsxRawData : (function(_,_) { return null; });

        if (tsxCache == null) {
            tsxCache = new Map();
        }

        try
        {
            r = new TmxReader();
            r.resolveTSX = getTsx;
            this.cwd = cwd;
            var result = r.read(Xml.parse(rawTmxData));
            this.cwd = null;
            return result;
        }
        catch (e:Dynamic)
        {
            log.error(e);
        }

        return null;

    }

    /**
     * Clears the TSX cache, forcing re-parsing of tileset files.
     * Only accessible by TilemapParser.
     */
    @:allow(ceramic.TilemapParser)
    function clearCache():Void {

        tsxCache = null;

    }

    /**
     * Resolves and returns a TSX tileset, using cache when available.
     * Called by the TMX reader when it encounters an external tileset reference.
     * @param name The TSX filename referenced in the TMX
     * @return The parsed TmxTileset object
     */
    function getTsx(name:String):TmxTileset {

        var cacheKey = cwd + ':' + name;
        var cached:TmxTileset = tsxCache.get(cacheKey);
        if (cached != null) return cached;

        cached = r.readTSX(Xml.parse(resolveTsxRawData(name, cwd)));
        tsxCache.set(cacheKey, cached);

        return cached;

    }

}
