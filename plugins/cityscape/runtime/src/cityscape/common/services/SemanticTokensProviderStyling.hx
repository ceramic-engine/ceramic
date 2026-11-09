// Ported from vscode src/vs/editor/common/services/semanticTokensProviderStyling.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.common.EncodedTokenAttributes.FontStyle;
import cityscape.common.EncodedTokenAttributes.MetadataConsts;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensLegend;
import cityscape.common.tokens.SparseMultilineTokens;
import cityscape.platform.theme.common.ThemeService.IColorTheme;
import haxe.io.UInt32Array;

/**
 * What the styling reads from the theme service (Monaco's `IThemeService`):
 * the current color theme. The theme service of a `Cityscape` context
 * (`StandaloneThemeService`) is one.
 */
typedef ISemanticTokensThemeService = {
    function getColorTheme():IColorTheme;
}

/**
 * The styling of the semantic tokens of one provider (its legend) in the
 * current theme: token type and modifiers to metadata, cached in a hash
 * table. The warnings of Monaco's log service are kept as flags
 * (`hasWarned...`), the log service is not ported.
 */
class SemanticTokensProviderStyling {

    /**
     * `SemanticTokensProviderStylingConstants.NO_STYLING`
     */
    public static inline final NO_STYLING = 0x7FFFFFFF;

    final _legend:SemanticTokensLegend;
    final _themeService:ISemanticTokensThemeService;
    final _languageIdCodec:ILanguageIdCodec;
    final _hashTable:HashTable;
    public var hasWarnedOverlappingTokens(default, null) = false;
    public var hasWarnedInvalidLengthTokens(default, null) = false;
    public var hasWarnedInvalidEditStart(default, null) = false;

    /**
     * `languageIdCodec`: the codec of the language service
     * (`context.languageService.languageIdCodec`).
     */
    public function new(legend:SemanticTokensLegend, themeService:ISemanticTokensThemeService, languageIdCodec:ILanguageIdCodec) {
        this._legend = legend;
        this._themeService = themeService;
        this._languageIdCodec = languageIdCodec;
        this._hashTable = new HashTable();
    }

    public function getMetadata(tokenTypeIndex:Int, tokenModifierSet:Int, languageId:String):Int {
        final encodedLanguageId:Int = this._languageIdCodec.encodeLanguageId(languageId);
        final entry = this._hashTable.get(tokenTypeIndex, tokenModifierSet, encodedLanguageId);
        var metadata:Int;
        if (entry != null) {
            metadata = entry.metadata;
        }
        else {
            final tokenType:Null<String> = (tokenTypeIndex >= 0 && tokenTypeIndex < this._legend.tokenTypes.length) ? this._legend.tokenTypes[tokenTypeIndex] : null;
            final tokenModifiers:Array<String> = [];
            if (tokenType != null) {
                var modifierSet = tokenModifierSet;
                var modifierIndex = 0;
                while (modifierSet > 0 && modifierIndex < this._legend.tokenModifiers.length) {
                    if ((modifierSet & 1) != 0) {
                        tokenModifiers.push(this._legend.tokenModifiers[modifierIndex]);
                    }
                    modifierSet = modifierSet >> 1;
                    modifierIndex++;
                }

                final tokenStyle = this._themeService.getColorTheme().getTokenStyleMetadata(tokenType, tokenModifiers, languageId);
                if (tokenStyle == null) {
                    metadata = NO_STYLING;
                }
                else {
                    metadata = 0;
                    if (tokenStyle.italic != null) {
                        final italicBit = (tokenStyle.italic ? FontStyle.Italic : 0) << MetadataConsts.FONT_STYLE_OFFSET;
                        metadata |= italicBit | MetadataConsts.SEMANTIC_USE_ITALIC;
                    }
                    if (tokenStyle.bold != null) {
                        final boldBit = (tokenStyle.bold ? FontStyle.Bold : 0) << MetadataConsts.FONT_STYLE_OFFSET;
                        metadata |= boldBit | MetadataConsts.SEMANTIC_USE_BOLD;
                    }
                    if (tokenStyle.underline != null) {
                        final underlineBit = (tokenStyle.underline ? FontStyle.Underline : 0) << MetadataConsts.FONT_STYLE_OFFSET;
                        metadata |= underlineBit | MetadataConsts.SEMANTIC_USE_UNDERLINE;
                    }
                    if (tokenStyle.strikethrough != null) {
                        final strikethroughBit = (tokenStyle.strikethrough ? FontStyle.Strikethrough : 0) << MetadataConsts.FONT_STYLE_OFFSET;
                        metadata |= strikethroughBit | MetadataConsts.SEMANTIC_USE_STRIKETHROUGH;
                    }
                    final foreground:Null<Int> = tokenStyle.foreground;
                    if (foreground != null && foreground != 0) {
                        final foregroundBits = foreground << MetadataConsts.FOREGROUND_OFFSET;
                        metadata |= foregroundBits | MetadataConsts.SEMANTIC_USE_FOREGROUND;
                    }
                    if (metadata == 0) {
                        // Nothing!
                        metadata = NO_STYLING;
                    }
                }
            }
            else {
                metadata = NO_STYLING;
            }
            this._hashTable.add(tokenTypeIndex, tokenModifierSet, encodedLanguageId, metadata);
        }

        return metadata;
    }

    public function warnOverlappingSemanticTokens(lineNumber:Int, startColumn:Int):Void {
        if (!this.hasWarnedOverlappingTokens) {
            this.hasWarnedOverlappingTokens = true;
        }
    }

    public function warnInvalidLengthSemanticTokens(lineNumber:Int, startColumn:Int):Void {
        if (!this.hasWarnedInvalidLengthTokens) {
            this.hasWarnedInvalidLengthTokens = true;
        }
    }

    public function warnInvalidEditStart(previousResultId:Null<String>, resultId:Null<String>, editIndex:Int, editStart:Int, maxExpectedStart:Int):Void {
        if (!this.hasWarnedInvalidEditStart) {
            this.hasWarnedInvalidEditStart = true;
        }
    }

    /**
     * Let's aim at having 8KB buffers if possible...
     * So that would be 8192 / (5 * 4) = 409.6 tokens per area
     */
    static inline final DesiredTokensPerArea = 400;

    /**
     * Try to keep the total number of areas under 1024 if possible,
     * simply compensate by having more tokens per area...
     */
    static inline final DesiredMaxAreas = 1024;

    /**
     * The module function `toMultilineTokens2` of semanticTokensProviderStyling.ts:
     * the encoded tokens of a provider (5 numbers per token, relative to the
     * previous one) as sparse tokens areas. The numbers are read as
     * JavaScript reads `Uint32Array` items and casts them with `| 0`
     * (32 bit integers, the same bits on every target).
     */
    public static function toMultilineTokens2(tokens:SemanticTokens, styling:SemanticTokensProviderStyling, languageId:String):Array<SparseMultilineTokens> {
        final srcData = tokens.data;
        final tokenCount = Std.int(srcData.length / 5);
        final tokensPerArea = Std.int(Math.max(Math.ceil(tokenCount / DesiredMaxAreas), DesiredTokensPerArea));
        final result:Array<SparseMultilineTokens> = [];

        inline function src(i:Int):Int {
            return (srcData[i] : Int) | 0;
        }

        var tokenIndex = 0;
        var lastLineNumber = 1;
        var lastStartCharacter = 0;
        while (tokenIndex < tokenCount) {
            final tokenStartIndex = tokenIndex;
            var tokenEndIndex = Std.int(Math.min(tokenStartIndex + tokensPerArea, tokenCount));

            // Keep tokens on the same line in the same area...
            if (tokenEndIndex < tokenCount) {

                var smallTokenEndIndex = tokenEndIndex;
                while (smallTokenEndIndex - 1 > tokenStartIndex && src(5 * smallTokenEndIndex) == 0) {
                    smallTokenEndIndex--;
                }

                if (smallTokenEndIndex - 1 == tokenStartIndex) {
                    // there are so many tokens on this line that our area would be empty, we must now go right
                    var bigTokenEndIndex = tokenEndIndex;
                    while (bigTokenEndIndex + 1 < tokenCount && src(5 * bigTokenEndIndex) == 0) {
                        bigTokenEndIndex++;
                    }
                    tokenEndIndex = bigTokenEndIndex;
                }
                else {
                    tokenEndIndex = smallTokenEndIndex;
                }
            }

            var destData = new UInt32Array((tokenEndIndex - tokenStartIndex) * 4);
            var destOffset = 0;
            var areaLine = 0;
            var prevLineNumber = 0;
            var prevEndCharacter = 0;
            while (tokenIndex < tokenEndIndex) {
                final srcOffset = 5 * tokenIndex;
                final deltaLine = src(srcOffset);
                final deltaCharacter = src(srcOffset + 1);
                // Casting both `lineNumber`, `startCharacter` and `endCharacter` here to uint32 using `|0`
                // to validate below with the actual values that will be inserted in the Uint32Array result
                final lineNumber = (lastLineNumber + deltaLine) | 0;
                final startCharacter = (deltaLine == 0 ? (lastStartCharacter + deltaCharacter) | 0 : deltaCharacter);
                final length = src(srcOffset + 2);
                final endCharacter = (startCharacter + length) | 0;
                final tokenTypeIndex = src(srcOffset + 3);
                final tokenModifierSet = src(srcOffset + 4);

                if (endCharacter <= startCharacter) {
                    // this token is invalid (most likely a negative length casted to uint32)
                    styling.warnInvalidLengthSemanticTokens(lineNumber, startCharacter + 1);
                }
                else if (prevLineNumber == lineNumber && prevEndCharacter > startCharacter) {
                    // this token overlaps with the previous token
                    styling.warnOverlappingSemanticTokens(lineNumber, startCharacter + 1);
                }
                else {
                    final metadata = styling.getMetadata(tokenTypeIndex, tokenModifierSet, languageId);

                    if (metadata != NO_STYLING) {
                        if (areaLine == 0) {
                            areaLine = lineNumber;
                        }
                        destData[destOffset] = lineNumber - areaLine;
                        destData[destOffset + 1] = startCharacter;
                        destData[destOffset + 2] = endCharacter;
                        destData[destOffset + 3] = metadata;
                        destOffset += 4;

                        prevLineNumber = lineNumber;
                        prevEndCharacter = endCharacter;
                    }
                }

                lastLineNumber = lineNumber;
                lastStartCharacter = startCharacter;
                tokenIndex++;
            }

            if (destOffset != destData.length) {
                destData = destData.subarray(0, destOffset);
            }

            result.push(SparseMultilineTokens.create(areaLine, destData));
        }

        return result;
    }

}

private class HashTableEntry {
    public final tokenTypeIndex:Int;
    public final tokenModifierSet:Int;
    public final languageId:Int;
    public final metadata:Int;
    public var next:Null<HashTableEntry>;

    public function new(tokenTypeIndex:Int, tokenModifierSet:Int, languageId:Int, metadata:Int) {
        this.tokenTypeIndex = tokenTypeIndex;
        this.tokenModifierSet = tokenModifierSet;
        this.languageId = languageId;
        this.metadata = metadata;
        this.next = null;
    }
}

private class HashTable {

    static final _SIZES = [3, 7, 13, 31, 61, 127, 251, 509, 1021, 2039, 4093, 8191, 16381, 32749, 65521, 131071, 262139, 524287, 1048573, 2097143];

    var _elementsCount:Int;
    var _currentLengthIndex:Int;
    var _currentLength:Int;
    var _growCount:Int;
    var _elements:Array<Null<HashTableEntry>>;

    public function new() {
        this._elementsCount = 0;
        this._currentLengthIndex = 0;
        this._currentLength = _SIZES[this._currentLengthIndex];
        this._growCount = Math.round(this._currentLengthIndex + 1 < _SIZES.length ? 2 / 3 * this._currentLength : 0);
        this._elements = [];
        _nullOutEntries(this._elements, this._currentLength);
    }

    static function _nullOutEntries(entries:Array<Null<HashTableEntry>>, length:Int):Void {
        for (i in 0...length) {
            entries[i] = null;
        }
    }

    inline function _hash2(n1:Int, n2:Int):Int {
        return (((n1 << 5) - n1) + n2) | 0;  // n1 * 31 + n2, keep as int32
    }

    function _hashFunc(tokenTypeIndex:Int, tokenModifierSet:Int, languageId:Int):Int {
        // JavaScript's `%` keeps the sign of the dividend: a negative hash
        // gives a negative index (an empty slot, `undefined`, in Monaco)
        return this._hash2(this._hash2(tokenTypeIndex, tokenModifierSet), languageId) % this._currentLength;
    }

    public function get(tokenTypeIndex:Int, tokenModifierSet:Int, languageId:Int):Null<HashTableEntry> {
        final hash = this._hashFunc(tokenTypeIndex, tokenModifierSet, languageId);

        var p = _slot(hash);
        while (p != null) {
            if (p.tokenTypeIndex == tokenTypeIndex && p.tokenModifierSet == tokenModifierSet && p.languageId == languageId) {
                return p;
            }
            p = p.next;
        }

        return null;
    }

    /**
     * Monaco stores negative indices as properties of the array; they are
     * kept in a map here.
     */
    var _negative:Null<Map<Int, HashTableEntry>> = null;

    inline function _slot(hash:Int):Null<HashTableEntry> {
        return hash >= 0 ? this._elements[hash] : (_negative != null ? _negative.get(hash) : null);
    }

    function _setSlot(hash:Int, element:HashTableEntry):Void {
        if (hash >= 0) {
            this._elements[hash] = element;
        }
        else {
            if (_negative == null) {
                _negative = new Map();
            }
            _negative.set(hash, element);
        }
    }

    public function add(tokenTypeIndex:Int, tokenModifierSet:Int, languageId:Int, metadata:Int):Void {
        this._elementsCount++;
        if (this._growCount != 0 && this._elementsCount >= this._growCount) {
            // expand!
            final oldElements = this._elements;
            final oldNegative = this._negative;

            this._currentLengthIndex++;
            this._currentLength = _SIZES[this._currentLengthIndex];
            this._growCount = Math.round(this._currentLengthIndex + 1 < _SIZES.length ? 2 / 3 * this._currentLength : 0);
            this._elements = [];
            this._negative = null;
            _nullOutEntries(this._elements, this._currentLength);

            function readd(first:Null<HashTableEntry>):Void {
                var p = first;
                while (p != null) {
                    final oldNext = p.next;
                    p.next = null;
                    this._add(p);
                    p = oldNext;
                }
            }
            for (first in oldElements) {
                readd(first);
            }
            if (oldNegative != null) {
                for (first in oldNegative) {
                    readd(first);
                }
            }
        }
        this._add(new HashTableEntry(tokenTypeIndex, tokenModifierSet, languageId, metadata));
    }

    function _add(element:HashTableEntry):Void {
        final hash = this._hashFunc(element.tokenTypeIndex, element.tokenModifierSet, element.languageId);
        element.next = _slot(hash);
        _setSlot(hash, element);
    }
}
