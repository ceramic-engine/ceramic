// Original code (not a port), written for Glaze.
// MIT License, see Ceramic's LICENSE file.
package glaze.platform;

import haxe.io.Bytes;

using StringTools;

/**
 * The font families installed on the operating system, found by name, for
 * `CeramicTextSystem`: a family that no added font provides (`'SF Mono'`,
 * `'Menlo'`) is loaded from the system font files, all its faces, and then
 * behaves like an added font. A CSS like list of families
 * (`'SF Mono', Menlo, Monaco, monospace`) takes the first one found
 * (`Font.fallbacks`, or the caller trying each, like Cityscape's editor
 * fonts).
 *
 * The files are never copied or bundled: they are read where they are
 * installed, through `ceramic.Files`, and parsed by `ttf` like the bundled
 * fonts. On first use the font directories are listed and the `name` table
 * of each file is read (a few KB per file); a family's files are read when
 * it is first asked for.
 *
 * - macOS: `/System/Library/Fonts` (and `Supplemental`), `/Library/Fonts`,
 *   `~/Library/Fonts`, the folders CoreText reads.
 * - Windows and Linux: TODO (`C:\Windows\Fonts` and the user fonts folder;
 *   the fontconfig folders `/usr/share/fonts`, `~/.local/share/fonts`):
 *   no folder is listed yet, so the families are not found and the well
 *   known names keep their substitutes (`CeramicTextSystem.substituteFamily`).
 * - Web: the browser cannot list the fonts of the system (the Local Font
 *   Access API needs a permission prompt): families must be added as font
 *   files. The browser's own fonts only draw the graphemes no added font
 *   has (the Canvas fallback).
 *
 * Not loaded: fonts the `ttf` library cannot draw (Apple's `hvgl` outlines),
 * and variable fonts give their default instance only.
 */
class SystemFontFamilies {

    /** Font directories, in order of precedence (null: those of the platform) */
    final directories:Null<Array<String>>;

    /** Lowercased family name to its files and face indexes */
    var index:Null<Map<String, Array<FaceLocation>>> = null;

    /** Families already loaded (lowercased names) */
    final loaded:Map<String, Bool> = new Map();

    /** Total time spent listing and indexing, in seconds */
    public var indexTime(default, null):Float = 0;

    public function new(?directories:Array<String>) {
        this.directories = directories;
    }

    /**
     * The installed families the generic family `monospace` stands for, in
     * order: the default fixed font of a browser on this platform (Menlo
     * for Chromium on macOS, Consolas on Windows; fontconfig's usual
     * monospace match on Linux).
     */
    public static function genericMonospaceFamilies():Array<String> {
        var os = '';
        try {
            if (ceramic.App.app != null && ceramic.App.app.backend != null)
                os = ceramic.App.app.backend.info.operatingSystem();
        }
        catch (e:Dynamic) {}
        return switch os {
            case 'mac': ['Menlo'];
            case 'windows': ['Consolas', 'Courier New'];
            case 'linux': ['DejaVu Sans Mono', 'Noto Sans Mono', 'Liberation Mono'];
            case _: [];
        }
    }

    /**
     * The font directories of this platform.
     */
    public static function platformDirectories():Array<String> {
        #if (sys && (mac || macos))
        final result = ['/System/Library/Fonts', '/System/Library/Fonts/Supplemental', '/Library/Fonts'];
        final home = Sys.getEnv('HOME');
        if (home != null && home.length > 0)
            result.push(home + '/Library/Fonts');
        return result;
        #elseif sys
        if (Sys.systemName() == 'Mac') {
            final result = ['/System/Library/Fonts', '/System/Library/Fonts/Supplemental', '/Library/Fonts'];
            final home = Sys.getEnv('HOME');
            if (home != null && home.length > 0)
                result.push(home + '/Library/Fonts');
            return result;
        }
        // TODO: Windows (C:\Windows\Fonts, %LOCALAPPDATA%\Microsoft\Windows\Fonts)
        // and Linux (fontconfig directories)
        return [];
        #else
        return [];
        #end
    }

    /**
     * Whether a family of this name is installed.
     */
    public function hasFamily(name:String):Bool {
        return ensureIndex().exists(name.toLowerCase());
    }

    /**
     * The faces of the installed family `name` (case insensitive), read
     * from their files, or an empty array. A family is read once: the
     * next calls return an empty array (its faces were added already).
     */
    public function loadFamily(name:String):Array<ttf.Font> {
        final key = name.toLowerCase();
        if (loaded.exists(key))
            return [];
        final locations = ensureIndex().get(key);
        if (locations == null)
            return [];
        loaded.set(key, true);
        final result:Array<ttf.Font> = [];
        final files:Map<String, Bytes> = new Map();
        for (location in locations) {
            try {
                var bytes = files.get(location.path);
                if (bytes == null) {
                    bytes = ceramic.Files.getBytes(location.path);
                    if (bytes == null)
                        continue;
                    files.set(location.path, bytes);
                }
                final face = ttf.Font.fromBytes(bytes, location.faceIndex);
                if (face.glyphForChar('m'.code) == 0 && face.glyphForChar(0x6C34) == 0)
                    continue;
                result.push(face);
            }
            catch (e:Dynamic) {
                // a format ttf does not read: skipped
            }
        }
        return result;
    }

    function ensureIndex():Map<String, Array<FaceLocation>> {
        var result = index;
        if (result != null)
            return result;
        final start = haxe.Timer.stamp();
        result = new Map();
        index = result;
        final dirs = directories != null ? directories : platformDirectories();
        for (dir in dirs) {
            #if sys
            if (!ceramic.Files.exists(dir) || !ceramic.Files.isDirectory(dir))
                continue;
            final names = try sys.FileSystem.readDirectory(dir) catch (e:Dynamic) [];
            names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
            for (file in names) {
                final lower = file.toLowerCase();
                if (!(lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.ttc') || lower.endsWith('.otc')))
                    continue;
                final path = dir + '/' + file;
                try {
                    indexFile(path, result);
                }
                catch (e:Dynamic) {}
            }
            #end
        }
        indexTime = haxe.Timer.stamp() - start;
        return result;
    }

    static inline function u16(b:Bytes, o:Int):Int {
        return (b.get(o) << 8) | b.get(o + 1);
    }

    static inline function u32(b:Bytes, o:Int):Int {
        return (b.get(o) << 24) | (b.get(o + 1) << 16) | (b.get(o + 2) << 8) | b.get(o + 3);
    }

    function indexFile(path:String, result:Map<String, Array<FaceLocation>>):Void {
        final head = ceramic.Files.getBytesRange(path, 0, 12);
        if (head == null || head.length < 12)
            return;
        final tag = u32(head, 0);
        if (tag == 0x74746366) { // 'ttcf'
            final count = u32(head, 8);
            final offsets = ceramic.Files.getBytesRange(path, 12, count * 4);
            if (offsets == null)
                return;
            for (i in 0...count)
                indexFace(path, i, u32(offsets, i * 4), result);
        }
        else {
            indexFace(path, 0, 0, result);
        }
    }

    function indexFace(path:String, faceIndex:Int, offset:Int, result:Map<String, Array<FaceLocation>>):Void {
        final header = ceramic.Files.getBytesRange(path, offset, 12);
        if (header == null || header.length < 12)
            return;
        final numTables = u16(header, 4);
        final dir = ceramic.Files.getBytesRange(path, offset + 12, numTables * 16);
        if (dir == null || dir.length < numTables * 16)
            return;
        for (t in 0...numTables) {
            if (u32(dir, t * 16) != 0x6E616D65) // 'name'
                continue;
            final nameOffset = u32(dir, t * 16 + 8);
            final nameLength = u32(dir, t * 16 + 12);
            final table = ceramic.Files.getBytesRange(path, nameOffset, nameLength);
            if (table == null)
                return;
            for (family in familyNames(table)) {
                final key = family.toLowerCase();
                var list = result.get(key);
                if (list == null) {
                    list = [];
                    result.set(key, list);
                }
                var found = false;
                for (l in list)
                    if (l.path == path && l.faceIndex == faceIndex)
                        found = true;
                if (!found)
                    list.push(new FaceLocation(path, faceIndex));
            }
            return;
        }
    }

    /**
     * The family names of a `name` table: IDs 1 (family) and 16
     * (typographic family), Windows (UTF-16) and Mac Roman (ASCII only)
     * records, every language.
     */
    static function familyNames(table:Bytes):Array<String> {
        final names:Array<String> = [];
        if (table.length < 6)
            return names;
        final count = u16(table, 2);
        final storage = u16(table, 4);
        for (i in 0...count) {
            final r = 6 + i * 12;
            if (r + 12 > table.length)
                break;
            final platformId = u16(table, r);
            final nameId = u16(table, r + 6);
            if (nameId != 1 && nameId != 16)
                continue;
            final length = u16(table, r + 8);
            final start = storage + u16(table, r + 10);
            if (start + length > table.length)
                continue;
            var name = '';
            if (platformId == 3 || platformId == 0) {
                final buf = new StringBuf();
                var k = 0;
                while (k + 1 < length) {
                    final c = u16(table, start + k);
                    k += 2;
                    if (c >= 0xD800 && c <= 0xDBFF && k + 1 < length) {
                        final low = u16(table, start + k);
                        k += 2;
                        buf.addChar(0x10000 + ((c - 0xD800) << 10) + (low - 0xDC00));
                    }
                    else {
                        buf.addChar(c);
                    }
                }
                name = buf.toString();
            }
            else if (platformId == 1) {
                var ascii = true;
                final buf = new StringBuf();
                for (k in 0...length) {
                    final c = table.get(start + k);
                    if (c >= 128)
                        ascii = false;
                    buf.addChar(c);
                }
                if (!ascii)
                    continue;
                name = buf.toString();
            }
            if (name.length > 0 && names.indexOf(name) == -1)
                names.push(name);
        }
        return names;
    }

}

private class FaceLocation {

    public final path:String;

    public final faceIndex:Int;

    public function new(path:String, faceIndex:Int) {
        this.path = path;
        this.faceIndex = faceIndex;
    }

}
