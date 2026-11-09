// Ported from vscode src/vs/editor/common/encodedTokenAttributes.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

/**
 * Open ended enum at runtime
 */
enum abstract LanguageId(Int) from Int to Int {
    var Null = 0;
    var PlainText = 1;
}

/**
 * A font style. Values are 2^x such that a bit mask can be used.
 */
enum abstract FontStyle(Int) from Int to Int {
    var NotSet = -1;
    var None = 0;
    var Italic = 1;
    var Bold = 2;
    var Underline = 4;
    var Strikethrough = 8;
}

/**
 * Open ended enum at runtime
 */
enum abstract ColorId(Int) from Int to Int {
    var None = 0;
    var DefaultForeground = 1;
    var DefaultBackground = 2;
}

/**
 * A standard token type.
 */
enum abstract StandardTokenType(Int) from Int to Int {
    var Other = 0;
    var Comment = 1;
    var String = 2;
    var RegEx = 3;
}

/**
 * Helpers to manage the "collapsed" metadata of an entire StackElement stack.
 * The following assumptions have been made:
 *  - languageId < 256 => needs 8 bits
 *  - unique color count < 512 => needs 9 bits
 *
 * The binary format is:
 * - -------------------------------------------
 *     3322 2222 2222 1111 1111 1100 0000 0000
 *     1098 7654 3210 9876 5432 1098 7654 3210
 * - -------------------------------------------
 *     xxxx xxxx xxxx xxxx xxxx xxxx xxxx xxxx
 *     bbbb bbbb ffff ffff fFFF FBTT LLLL LLLL
 * - -------------------------------------------
 *  - L = LanguageId (8 bits)
 *  - T = StandardTokenType (2 bits)
 *  - B = Balanced bracket (1 bit)
 *  - F = FontStyle (4 bits)
 *  - f = foreground color (9 bits)
 *  - b = background color (8 bits)
 */
enum abstract MetadataConsts(Int) from Int to Int {
    var LANGUAGEID_MASK = 0x000000FF;
    var TOKEN_TYPE_MASK = 0x00000300;
    var BALANCED_BRACKETS_MASK = 0x00000400;
    var FONT_STYLE_MASK = 0x00007800;
    var FOREGROUND_MASK = 0x00FF8000;
    var BACKGROUND_MASK = 0xFF000000;

    var ITALIC_MASK = 0x00000800;
    var BOLD_MASK = 0x00001000;
    var UNDERLINE_MASK = 0x00002000;
    var STRIKETHROUGH_MASK = 0x00004000;

    // Semantic tokens cannot set the language id, so we can
    // use the first 8 bits for control purposes
    var SEMANTIC_USE_ITALIC = 0x00000001;
    var SEMANTIC_USE_BOLD = 0x00000002;
    var SEMANTIC_USE_UNDERLINE = 0x00000004;
    var SEMANTIC_USE_STRIKETHROUGH = 0x00000008;
    var SEMANTIC_USE_FOREGROUND = 0x00000010;
    var SEMANTIC_USE_BACKGROUND = 0x00000020;

    var LANGUAGEID_OFFSET = 0;
    var TOKEN_TYPE_OFFSET = 8;
    var BALANCED_BRACKETS_OFFSET = 10;
    var FONT_STYLE_OFFSET = 11;
    var FOREGROUND_OFFSET = 15;
    var BACKGROUND_OFFSET = 24;
}

class TokenMetadata {

    public static inline function getLanguageId(metadata:Int):LanguageId {
        return (metadata & MetadataConsts.LANGUAGEID_MASK) >>> MetadataConsts.LANGUAGEID_OFFSET;
    }

    public static inline function getTokenType(metadata:Int):StandardTokenType {
        return (metadata & MetadataConsts.TOKEN_TYPE_MASK) >>> MetadataConsts.TOKEN_TYPE_OFFSET;
    }

    public static inline function containsBalancedBrackets(metadata:Int):Bool {
        return (metadata & MetadataConsts.BALANCED_BRACKETS_MASK) != 0;
    }

    public static inline function getFontStyle(metadata:Int):FontStyle {
        return (metadata & MetadataConsts.FONT_STYLE_MASK) >>> MetadataConsts.FONT_STYLE_OFFSET;
    }

    public static inline function getForeground(metadata:Int):ColorId {
        return (metadata & MetadataConsts.FOREGROUND_MASK) >>> MetadataConsts.FOREGROUND_OFFSET;
    }

    public static inline function getBackground(metadata:Int):ColorId {
        return (metadata & MetadataConsts.BACKGROUND_MASK) >>> MetadataConsts.BACKGROUND_OFFSET;
    }

    public static function getClassNameFromMetadata(metadata:Int):String {
        final foreground:Int = getForeground(metadata);
        var className = 'mtk' + foreground;

        final fontStyle:Int = getFontStyle(metadata);
        if (fontStyle & FontStyle.Italic != 0) {
            className += ' mtki';
        }
        if (fontStyle & FontStyle.Bold != 0) {
            className += ' mtkb';
        }
        if (fontStyle & FontStyle.Underline != 0) {
            className += ' mtku';
        }
        if (fontStyle & FontStyle.Strikethrough != 0) {
            className += ' mtks';
        }

        return className;
    }

    public static function getInlineStyleFromMetadata(metadata:Int, colorMap:Array<String>):String {
        final foreground:Int = getForeground(metadata);
        final fontStyle:Int = getFontStyle(metadata);

        var result = 'color: ' + colorMap[foreground] + ';';
        if (fontStyle & FontStyle.Italic != 0) {
            result += 'font-style: italic;';
        }
        if (fontStyle & FontStyle.Bold != 0) {
            result += 'font-weight: bold;';
        }
        var textDecoration = '';
        if (fontStyle & FontStyle.Underline != 0) {
            textDecoration += ' underline';
        }
        if (fontStyle & FontStyle.Strikethrough != 0) {
            textDecoration += ' line-through';
        }
        if (textDecoration != '') {
            result += 'text-decoration:' + textDecoration + ';';
        }
        return result;
    }

    public static function getPresentationFromMetadata(metadata:Int):ITokenPresentation {
        final foreground = getForeground(metadata);
        final fontStyle:Int = getFontStyle(metadata);

        return {
            foreground: foreground,
            italic: fontStyle & FontStyle.Italic != 0,
            bold: fontStyle & FontStyle.Bold != 0,
            underline: fontStyle & FontStyle.Underline != 0,
            strikethrough: fontStyle & FontStyle.Strikethrough != 0,
        };
    }

}

typedef ITokenPresentation = {
    var foreground:ColorId;
    var italic:Bool;
    var bold:Bool;
    var underline:Bool;
    var strikethrough:Bool;
}
