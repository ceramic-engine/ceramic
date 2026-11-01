// Original code (not a port), written for ceramic-gpui.
// MIT License, see Ceramic's LICENSE file.
package gpui.platform;

import haxe.io.Bytes;

using StringTools;

/**
 * Fonts of the operating system used as a last fallback by
 * `CeramicTextSystem`, for characters that no added font covers (CJK
 * ideographs, kana, hangul, symbols). GPUI gets the same from CoreText on
 * macOS and from fontdb and cosmic-text's fallback lists on Linux and
 * Windows (`cosmic-text/src/font/fallback/{macos,unix,windows}.rs`).
 *
 * Font files are read through `ceramic.Files`, lazily: nothing is read until
 * a character is missing from every loaded face, and then only the files
 * listed for the kind of that character, in order, until one covers it. A
 * file is read once (whether it covers the character or not) and all its
 * faces are kept.
 *
 * Not covered: color emoji (`sbix`, `CBDT`, `COLR` fonts are not listed, the
 * `ttf` library has no color glyphs), and fonts the `ttf` library cannot
 * draw (macOS 26 PingFang uses Apple's `hvgl` outlines, so Chinese uses
 * Hiragino Sans GB and Heiti instead).
 */
class SystemFontFallback {

    /**
     * Locale used to pick between the CJK fonts for Han ideographs
     * (`zh-CN`, the default, `zh-TW`, `zh-HK`, `ja` or `ko`), like
     * cosmic-text's `han_unification`.
     */
    public var cjkLocale(default, set):String = 'zh-CN';

    /** Faces loaded so far, in the order they should be tried */
    public final faces:Array<ttf.Font> = [];

    /** Rank of the file of each face in `faces` (load order) */
    public final fileRanks:Array<Int> = [];

    /** Paths of the files read so far */
    public final loadedPaths:Array<String> = [];

    /** Total time spent reading and parsing font files, in seconds */
    public var loadTime(default, null):Float = 0;

    /** Total size of the font files read so far, in bytes */
    public var loadedBytes(default, null):Float = 0;

    final triedPaths:Map<String, Bool> = new Map();

    var candidates:Null<Candidates> = null;

    /**
     * Creates a fallback over the fonts of this system, or over the given
     * candidate files (paths per kind of character, mostly for tests).
     */
    public function new(?candidates:Candidates) {
        this.candidates = candidates;
    }

    function set_cjkLocale(locale:String):String {
        if (locale != cjkLocale)
            candidates = null;
        return cjkLocale = locale;
    }

    /**
     * Reads the next candidate files for `codePoint` until one of them has a
     * face that maps it. Returns false when no system font covers it (or
     * when it is a character this fallback skips, like emoji).
     */
    public function loadFaceFor(codePoint:Int):Bool {
        final kind = kindOf(codePoint);
        if (kind == SKIP)
            return false;
        if (candidates == null)
            candidates = systemCandidates(cjkLocale);
        final paths = switch kind {
            case HAN: candidates.han;
            case KANA: candidates.kana;
            case HANGUL: candidates.hangul;
            case _: candidates.other;
        }
        for (path in paths) {
            if (triedPaths.exists(path))
                continue;
            triedPaths.set(path, true);
            if (loadFile(path, codePoint))
                return true;
        }
        return false;
    }

    function loadFile(path:String, codePoint:Int):Bool {
        final start = haxe.Timer.stamp();
        var bytes:Null<Bytes> = null;
        try {
            if (!ceramic.Files.exists(path))
                return false;
            bytes = ceramic.Files.getBytes(path);
        }
        catch (e:Dynamic) {
            bytes = null;
        }
        if (bytes == null)
            return false;
        final fileFaces:Array<ttf.Font> = [];
        try {
            final count = ttf.Font.faceCount(bytes);
            for (i in 0...count)
                fileFaces.push(ttf.Font.fromBytes(bytes, i));
        }
        catch (e:Dynamic) {
            loadTime += haxe.Timer.stamp() - start;
            return false;
        }
        loadTime += haxe.Timer.stamp() - start;
        loadedBytes += bytes.length;
        loadedPaths.push(path);

        // Hidden faces (names starting with a dot: UI variants of the
        // collection) only when the file has nothing else
        var visible = [for (f in fileFaces) if (!f.familyName.startsWith('.') && f.numGlyphs > 1) f];
        if (visible.length == 0)
            visible = [for (f in fileFaces) if (f.numGlyphs > 1) f];

        // Faces of the locale's region first (Heiti SC before Heiti TC,
        // Noto Sans CJK SC before Noto Sans CJK JP...)
        final tags = regionTags(cjkLocale);
        final preferred = [for (f in visible) if (hasRegionTag(f, tags)) f];
        final rank = loadedPaths.length - 1;
        var covers = false;
        for (list in [preferred, [for (f in visible) if (preferred.indexOf(f) == -1) f]]) {
            for (f in list) {
                faces.push(f);
                fileRanks.push(rank);
                if (f.glyphForChar(codePoint) != 0)
                    covers = true;
            }
        }
        return covers;
    }

/// Kinds of characters

    static inline final SKIP = 0;
    static inline final HAN = 1;
    static inline final KANA = 2;
    static inline final HANGUL = 3;
    static inline final OTHER = 4;

    static function kindOf(c:Int):Int {
        if (c <= 0x7F)
            return SKIP;
        // Format characters, joiners, variation selectors, tags, emoji
        // modifiers: they belong to the previous character
        if ((c >= 0x200B && c <= 0x200F) || (c >= 0x2028 && c <= 0x202E) || (c >= 0x2060 && c <= 0x206F)
            || (c >= 0xFE00 && c <= 0xFE0F) || (c >= 0xE0000 && c <= 0xE01EF) || c == 0x20E3
            || (c >= 0xD800 && c <= 0xDFFF) || (c >= 0xE000 && c <= 0xF8FF))
            return SKIP;
        // Emoji (color fonts are not supported)
        if ((c >= 0x1F000 && c <= 0x1FAFF) || (c >= 0x1F1E6 && c <= 0x1F1FF))
            return SKIP;
        if ((c >= 0x3040 && c <= 0x30FF) || (c >= 0x31F0 && c <= 0x31FF) || (c >= 0xFF66 && c <= 0xFF9F) || (c >= 0x1B000 && c <= 0x1B16F))
            return KANA;
        if ((c >= 0xAC00 && c <= 0xD7AF) || (c >= 0x1100 && c <= 0x11FF) || (c >= 0x3130 && c <= 0x318F)
            || (c >= 0xA960 && c <= 0xA97F) || (c >= 0xD7B0 && c <= 0xD7FF) || (c >= 0xFFA0 && c <= 0xFFDC))
            return HANGUL;
        if ((c >= 0x2E80 && c <= 0x2FDF) || (c >= 0x3000 && c <= 0x303F) || (c >= 0x3100 && c <= 0x312F)
            || (c >= 0x31A0 && c <= 0x31EF) || (c >= 0x3200 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF)
            || (c >= 0xFE30 && c <= 0xFE4F) || (c >= 0xFF00 && c <= 0xFFEF) || (c >= 0x20000 && c <= 0x323AF))
            return HAN;
        return OTHER;
    }

    static function regionTags(locale:String):Array<String> {
        return switch locale {
            case 'ja' | 'ja-JP': ['JP', 'JA'];
            case 'ko' | 'ko-KR': ['KR'];
            case 'zh-TW': ['TC'];
            case 'zh-HK': ['HK', 'TC'];
            case _: ['SC', 'GB'];
        }
    }

    static function hasRegionTag(face:ttf.Font, tags:Array<String>):Bool {
        final words = ~/[ \-_]/g.split(face.familyName.toUpperCase());
        for (tag in tags) {
            if (words.indexOf(tag) != -1)
                return true;
        }
        return false;
    }

/// Candidate files

    /** Candidate files of this system for a CJK locale */
    public static function systemCandidates(locale:String):Candidates {
        // The operating system from the Ceramic backend (not
        // `gpui.OperatingSystem.current`, which apps and tests may override)
        var os = '';
        try {
            if (ceramic.App.app != null && ceramic.App.app.backend != null)
                os = ceramic.App.app.backend.info.operatingSystem();
        }
        catch (e:Dynamic) {}
        switch os {
            case 'mac':
                return macCandidates(locale);
            case 'windows':
                var windir = ceramic.Platform.getEnv('WINDIR');
                if (windir == null || windir == '')
                    windir = 'C:\\Windows';
                return windowsCandidates(windir + '\\Fonts', locale);
            case 'linux':
                return linuxCandidates(locale);
            case _:
                return {han: [], kana: [], hangul: [], other: []};
        }
    }

    static function macCandidates(locale:String):Candidates {
        final s = '/System/Library/Fonts';
        final hiraginoGb = '$s/Hiragino Sans GB.ttc';
        final heiti = '$s/STHeiti Light.ttc';
        final hiragino = '$s/ヒラギノ角ゴシック W3.ttc';
        final gothic = '$s/AppleSDGothicNeo.ttc';
        final arialUnicode = ['/Library/Fonts/Arial Unicode.ttf', '$s/Supplemental/Arial Unicode.ttf'];
        final han = switch locale {
            case 'ja' | 'ja-JP': [hiragino, hiraginoGb, heiti, gothic];
            case 'ko' | 'ko-KR': [gothic, hiraginoGb, heiti, hiragino];
            case 'zh-TW' | 'zh-HK': [heiti, hiraginoGb, hiragino, gothic];
            case _: [hiraginoGb, heiti, hiragino, gothic];
        }
        return {
            han: han.concat(arialUnicode),
            kana: [hiragino, hiraginoGb].concat(arialUnicode),
            hangul: [gothic].concat(arialUnicode),
            // cosmic-text's common fallbacks on macOS (".SF NS", Menlo,
            // Geneva, Arial Unicode MS), with Apple Symbols, then the CJK
            // fonts, which have many symbols too
            other: ['$s/SFNS.ttf', '$s/Menlo.ttc', '$s/Apple Symbols.ttf', '$s/Geneva.ttf']
                .concat(arialUnicode).concat(han).concat(['$s/ZapfDingbats.ttf']),
        };
    }

    static function windowsCandidates(dir:String, locale:String):Candidates {
        final yahei = '$dir\\msyh.ttc';
        final jhenghei = '$dir\\msjh.ttc';
        final yugothic = '$dir\\YuGothR.ttc';
        final meiryo = '$dir\\meiryo.ttc';
        final malgun = '$dir\\malgun.ttf';
        final simsun = '$dir\\simsun.ttc';
        final han = switch locale {
            case 'ja' | 'ja-JP': [yugothic, meiryo, yahei, jhenghei, malgun, simsun];
            case 'ko' | 'ko-KR': [malgun, yahei, jhenghei, yugothic, meiryo, simsun];
            case 'zh-TW' | 'zh-HK': [jhenghei, yahei, yugothic, meiryo, malgun, simsun];
            case _: [yahei, jhenghei, yugothic, meiryo, malgun, simsun];
        }
        return {
            han: han,
            kana: [yugothic, meiryo, yahei],
            hangul: [malgun, '$dir\\gulim.ttc'],
            // cosmic-text's common fallbacks on Windows
            other: ['$dir\\segoeui.ttf', '$dir\\seguisym.ttf', '$dir\\seguihis.ttf', '$dir\\arial.ttf'].concat(han),
        };
    }

    static final LINUX_FONT_DIRS = ['/usr/share/fonts', '/usr/local/share/fonts'];

    static function linuxCandidates(locale:String):Candidates {
        // Every font file of the usual directories, matched by file name in
        // the order of cosmic-text's fallback lists on Linux
        final files:Array<String> = [];
        final dirs = LINUX_FONT_DIRS.copy();
        final home = ceramic.Platform.getEnv('HOME');
        if (home != null && home != '') {
            dirs.push('$home/.local/share/fonts');
            dirs.push('$home/.fonts');
        }
        for (dir in dirs) {
            try {
                if (!ceramic.Files.exists(dir) || !ceramic.Files.isDirectory(dir))
                    continue;
                for (file in ceramic.Files.getFlatDirectory(dir)) {
                    final lower = file.toLowerCase();
                    if (lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.ttc') || lower.endsWith('.otc'))
                        files.push('$dir/$file');
                }
            }
            catch (e:Dynamic) {}
        }
        function matching(patterns:Array<String>):Array<String> {
            final result:Array<String> = [];
            for (pattern in patterns) {
                for (file in files) {
                    final name = file.substr(file.lastIndexOf('/') + 1).toLowerCase();
                    if (name.startsWith(pattern) && result.indexOf(file) == -1 && name.indexOf('bold') == -1
                        && name.indexOf('italic') == -1 && name.indexOf('mono') == -1 && name.indexOf('serif') == -1)
                        result.push(file);
                }
            }
            return result;
        }
        final region = switch locale {
            case 'ja' | 'ja-JP': 'jp';
            case 'ko' | 'ko-KR': 'kr';
            case 'zh-TW': 'tc';
            case 'zh-HK': 'hk';
            case _: 'sc';
        }
        final han = matching([
            'notosanscjk$region-regular', 'notosans$region-regular', 'notosanscjk-regular', 'notosanscjk-vf',
            'notosanscjk', 'sourcehansans', 'wqy-microhei', 'wqy-zenhei', 'droidsansfallback', 'ukai', 'uming'
        ]);
        return {
            han: han,
            kana: matching(['notosanscjkjp-regular', 'notosansjp-regular']).concat(han),
            hangul: matching(['notosanscjkkr-regular', 'notosanskr-regular', 'nanumgothic']).concat(han),
            other: matching([
                'notosans-regular', 'dejavusans.ttf', 'freesans', 'notosanssymbols-regular',
                'notosanssymbols2-regular', 'notosansmath-regular', 'dejavusans', 'notosans'
            ]).concat(han),
        };
    }
}

/** Candidate font files per kind of character, in the order they are tried */
typedef Candidates = {
    /** Han ideographs, CJK punctuation, full width forms, bopomofo */
    var han:Array<String>;
    /** Hiragana and katakana */
    var kana:Array<String>;
    /** Hangul syllables and jamo */
    var hangul:Array<String>;
    /** Everything else (symbols, other scripts) */
    var other:Array<String>;
}
