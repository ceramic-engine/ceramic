package ceramic;

import ceramic.Shortcuts.*;
import format.tmx.Data.TmxMap;
import format.tmx.Data.TmxTileset;
import format.tmx.Reader as TmxReader;

@:noCompletion
class TilemapTmxParser {

    private var tsxCache:Map<String, TmxTileset> = null;

    private var r:TmxReader = null;

    private var resolveTsxRawData:(name:String,cwd:String)->String = null;

    private var cwd:String;

    public function new() {

    }

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

    @:allow(ceramic.TilemapParser)
    function clearCache():Void {

        tsxCache = null;

    }

    function getTsx(name:String):TmxTileset {

        var cacheKey = cwd + ':' + name;
        var cached:TmxTileset = tsxCache.get(cacheKey);
        if (cached != null) return cached;

        cached = r.readTSX(Xml.parse(resolveTsxRawData(name, cwd)));
        tsxCache.set(cacheKey, cached);

        return cached;

    }

}
