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
 * Classifies characters as regular, whitespace or word separators.
 *
 * TODO(step 3, word operations): `intlSegmenterLocales` is kept, but the
 * segmentation by `Intl.Segmenter` (word segments of CJK text) has no
 * implementation yet: `findPrevIntlWordBeforeOrAtOffset` and
 * `findNextIntlWordAtOrAfterOffset` find nothing.
 */
class WordCharacterClassifier extends CharacterClassifier {

    public final intlSegmenterLocales:Array<String>;

    public function new(wordSeparators:String, intlSegmenterLocales:Array<String>) {
        super(WordCharacterClass.Regular);
        this.intlSegmenterLocales = intlSegmenterLocales;

        for (i in 0...wordSeparators.length) {
            this.set(StringTools.fastCodeAt(wordSeparators, i), WordCharacterClass.WordSeparator);
        }

        this.set(CharCode.Space, WordCharacterClass.Whitespace);
        this.set(CharCode.Tab, WordCharacterClass.Whitespace);
    }

    public function findPrevIntlWordBeforeOrAtOffset(line:String, offset:Int):Null<IntlWordSegmentData> {
        return null;
    }

    public function findNextIntlWordAtOrAfterOffset(lineContent:String, offset:Int):Null<IntlWordSegmentData> {
        return null;
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
