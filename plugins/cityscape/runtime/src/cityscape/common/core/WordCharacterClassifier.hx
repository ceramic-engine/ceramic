// Ported from vscode src/vs/editor/common/core/wordCharacterClassifier.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.CharCode;

enum abstract WordCharacterClass(Int) from Int to Int {
    var Regular = 0;
    var Whitespace = 1;
    var WordSeparator = 2;
}

/**
 * A word segment found by `Intl.Segmenter` (`segment`, `index`).
 */
typedef IntlWordSegmentData = {
    final segment:String;
    final index:Int;
    final isWordLike:Bool;
}

/**
 * Classifies characters as regular, whitespace or word separators, and
 * finds the words of a line with `Intl.Segmenter` when
 * `intlSegmenterLocales` is not empty (CJK text, which has no separators).
 *
 * Cityscape: on JavaScript the segments come from the native
 * `Intl.Segmenter` (word granularity), like Monaco. Other targets have no
 * `Intl`: the words are the UAX #29 word boundaries of
 * `unicode_segmentation.UnicodeSegmentation.unicodeWordIndices` (the
 * segments containing letters or numbers, Intl's `isWordLike`), whatever
 * the locales. UAX #29 has no dictionary: a run of ideographs or hiragana
 * is split per character where ICU finds dictionary words (see
 * DEVIATIONS.md).
 */
class WordCharacterClassifier extends CharacterClassifier {

    public final intlSegmenterLocales:Array<String>;

    #if js
    final _segmenter:Null<Dynamic> = null;
    #end
    final _hasSegmenter:Bool;
    var _cachedLine:Null<String> = null;
    var _cachedSegments:Array<IntlWordSegmentData> = [];

    public function new(wordSeparators:String, intlSegmenterLocales:Array<String>) {
        super(WordCharacterClass.Regular);
        this.intlSegmenterLocales = intlSegmenterLocales;
        this._hasSegmenter = this.intlSegmenterLocales.length > 0;
        #if js
        if (this._hasSegmenter) {
            this._segmenter = js.Syntax.code('new Intl.Segmenter({0}, {granularity: "word"})', this.intlSegmenterLocales);
        }
        #end

        for (i in 0...wordSeparators.length) {
            this.set(StringTools.fastCodeAt(wordSeparators, i), WordCharacterClass.WordSeparator);
        }

        this.set(CharCode.Space, WordCharacterClass.Whitespace);
        this.set(CharCode.Tab, WordCharacterClass.Whitespace);
    }

    public function findPrevIntlWordBeforeOrAtOffset(line:String, offset:Int):Null<IntlWordSegmentData> {
        var candidate:Null<IntlWordSegmentData> = null;
        for (segment in this._getIntlSegmenterWordsOnLine(line)) {
            if (segment.index > offset) {
                break;
            }
            candidate = segment;
        }
        return candidate;
    }

    public function findNextIntlWordAtOrAfterOffset(lineContent:String, offset:Int):Null<IntlWordSegmentData> {
        for (segment in this._getIntlSegmenterWordsOnLine(lineContent)) {
            if (segment.index < offset) {
                continue;
            }
            return segment;
        }
        return null;
    }

    function _getIntlSegmenterWordsOnLine(line:String):Array<IntlWordSegmentData> {
        if (!this._hasSegmenter) {
            return [];
        }

        // Check if the line has changed from the previous call
        if (this._cachedLine == line) {
            return this._cachedSegments;
        }

        // Update the cache with the new line
        this._cachedLine = line;
        this._cachedSegments = this._segmentWords(line);

        return this._cachedSegments;
    }

    function _segmentWords(line:String):Array<IntlWordSegmentData> {
        final result:Array<IntlWordSegmentData> = [];
        #if js
        final segments:Array<Dynamic> = js.Syntax.code('Array.from({0}.segment({1}))', this._segmenter, line);
        for (segment in segments) {
            if (segment.isWordLike == true) {
                result.push({segment: segment.segment, index: segment.index, isWordLike: true});
            }
        }
        #else
        // UAX #29 words (UTF-8 byte offsets), converted to UTF-16 offsets
        final bytes = unicode_segmentation.Utf8.encode(line);
        final words = new unicode_segmentation.UnicodeWordIndices(bytes, 0, bytes.length);
        var byteOffset = 0;
        var utf16Offset = 0;
        while (words.nextRange()) {
            final start = words.rangeStart;
            final end = words.rangeEnd;
            while (byteOffset < start) {
                final b = bytes.get(byteOffset);
                final len = (b < 0x80 ? 1 : (b < 0xE0 ? 2 : (b < 0xF0 ? 3 : 4)));
                byteOffset += len;
                utf16Offset += (len == 4 ? 2 : 1);
            }
            final index = utf16Offset;
            while (byteOffset < end) {
                final b = bytes.get(byteOffset);
                final len = (b < 0x80 ? 1 : (b < 0xE0 ? 2 : (b < 0xF0 ? 3 : 4)));
                byteOffset += len;
                utf16Offset += (len == 4 ? 2 : 1);
            }
            result.push({segment: line.substring(index, utf16Offset), index: index, isWordLike: true});
        }
        #end
        return result;
    }

    static final wordClassifierCache:Array<{key:String, value:WordCharacterClassifier}> = [];

    /**
     * The classifier of `wordSeparators`, from a cache of the 10 last used
     * (Monaco's `LRUCache`; the classifiers are immutable, safe to share).
     */
    public static function getMapForWordSeparators(wordSeparators:String, intlSegmenterLocales:Array<String>):WordCharacterClassifier {
        final key = '${wordSeparators}/${intlSegmenterLocales.join(',')}';
        final cache = wordClassifierCache;
        for (i in 0...cache.length) {
            final entry = cache[i];
            if (entry.key == key) {
                if (i != cache.length - 1) {
                    // Most recently used goes last
                    cache.splice(i, 1);
                    cache.push(entry);
                }
                return entry.value;
            }
        }
        final result = new WordCharacterClassifier(wordSeparators, intlSegmenterLocales);
        cache.push({key: key, value: result});
        if (cache.length > 10) {
            cache.shift();
        }
        return result;
    }

}
