// Original code (not a port), written for Glaze.
// MIT License, see Ceramic's LICENSE file.
package glaze.platform;

import haxe.io.Bytes;

/**
 * A font file of the operating system opened for `SystemFontFamilies` and
 * `SystemFontFallback`, without reading it whole when that can be avoided.
 *
 * TrueType files (`glyf` outlines) are read piece by piece
 * (`ttf.Font.fromSource()` over `ceramic.Files.getBytesRange()`): each face
 * loads its small tables, and the outlines (`glyf`) and outline variations
 * (`gvar`) of a glyph are read the first time the glyph is drawn. A
 * fallback face such as Arial Unicode (23 MB) then holds about 1 MB, the
 * system font (SFNS, 8 MB) about 1 MB.
 *
 * CFF files (Hiragino) are read whole, as before: their outlines are one
 * table that `ttf` reads in memory, and the faces of a collection share
 * the bytes of the file instead of a copy each.
 *
 * Each read opens the file, reads the range and closes it
 * (`ceramic.Files.getBytesRange()`), so a face keeps no file handle. A
 * face is used by one thread at a time, like any `ttf.Font`.
 */
class SystemFontFile {

    /** Tables left in the file for TrueType faces: the outlines and their variations, read glyph by glyph. */
    public static final ON_DEMAND_TABLES:Array<String> = ttf.Font.LARGE_TABLES.concat(['glyf', 'gvar']);

    /** Path of the file. */
    public final path:String;

    /** Number of faces of the file (1 for a single font). */
    public final faceCount:Int;

    /** Bytes read from the file so far (at load, then as glyphs are drawn). */
    public var bytesRead(default, null):Float = 0;

    /** Whether the faces read their outlines on demand (TrueType), or the file was read whole (CFF). */
    public final onDemand:Bool;

    var source:Null<ttf.FontSource> = null;

    var bytes:Null<Bytes> = null;

    function new(path:String, faceCount:Int, onDemand:Bool) {
        this.path = path;
        this.faceCount = faceCount;
        this.onDemand = onDemand;
    }

    /**
     * Opens a font file, or returns null if it does not exist or is not a
     * font `ttf` reads.
     */
    public static function open(path:String):Null<SystemFontFile> {
        try {
            if (!ceramic.Files.exists(path))
                return null;
            final size = ceramic.Files.getSize(path);
            if (size <= 12 || size > 0x7FFFFFFF)
                return null;
            final header = ceramic.Files.getBytesRange(path, 0, 12);
            if (header == null || header.length < 12)
                return null;
            final count = ttf.Font.faceCount(header);
            if (count <= 0)
                return null;
            var file:SystemFontFile;
            if (hasGlyf(path, header)) {
                file = new SystemFontFile(path, count, true);
                file.bytesRead = 12;
                file.source = new ttf.FontSource.FunctionFontSource(Std.int(size), (offset, length) -> {
                    file.bytesRead += length;
                    return ceramic.Files.getBytesRange(path, offset, length);
                });
            }
            else {
                final bytes = ceramic.Files.getBytes(path);
                if (bytes == null)
                    return null;
                file = new SystemFontFile(path, ttf.Font.faceCount(bytes), false);
                file.bytes = bytes;
                file.bytesRead = bytes.length;
            }
            return file;
        }
        catch (e:Dynamic) {
            return null;
        }
    }

    /**
     * The face at `index`. Throws if it is not a face `ttf` reads.
     */
    public function face(index:Int):ttf.Font {
        if (source != null)
            return ttf.Font.fromSource(source, index, ON_DEMAND_TABLES);
        return ttf.Font.fromBytes(bytes, index);
    }

    /** Whether the first face of the file has TrueType outlines (a `glyf` table). */
    static function hasGlyf(path:String, header:Bytes):Bool {
        var directory = 0;
        if (ttf.Bin.u32(header, 0) == 0x74746366) {
            final entry = ceramic.Files.getBytesRange(path, 12, 4);
            if (entry == null || entry.length < 4)
                return false;
            directory = ttf.Bin.u32(entry, 0);
        }
        final dirHeader = ceramic.Files.getBytesRange(path, directory, 12);
        if (dirHeader == null || dirHeader.length < 12)
            return false;
        final numTables = ttf.Bin.u16(dirHeader, 4);
        final records = ceramic.Files.getBytesRange(path, directory + 12, numTables * 16);
        if (records == null || records.length < numTables * 16)
            return false;
        final glyf = ttf.Bin.tagToInt('glyf');
        for (i in 0...numTables) {
            if (ttf.Bin.u32(records, i * 16) == glyf)
                return true;
        }
        return false;
    }

}
