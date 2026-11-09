// Ported from vscode src/vs/editor/common/languages/nullTokenize.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import haxe.io.UInt32Array;

/**
 * The state of the null tokenizer (one immutable instance, compared by identity).
 */
class NullStateImpl implements IState {

    public function new() {}

    public function clone():IState {
        return this;
    }

    public function equals(other:IState):Bool {
        return (this == other);
    }

}

class NullTokenize {

    public static final NullState:IState = new NullStateImpl();

    public static function nullTokenize(languageId:String, state:IState):TokenizationResult {
        return new TokenizationResult([new Token(0, '', languageId)], state);
    }

    public static function nullTokenizeEncoded(languageId:LanguageId, state:Null<IState>):EncodedTokenizationResult {
        final tokens = new UInt32Array(2);
        tokens[0] = 0;
        tokens[1] = (
            ((languageId : Int) << MetadataConsts.LANGUAGEID_OFFSET)
            | (StandardTokenType.Other << MetadataConsts.TOKEN_TYPE_OFFSET)
            | (FontStyle.None << MetadataConsts.FONT_STYLE_OFFSET)
            | (ColorId.DefaultForeground << MetadataConsts.FOREGROUND_OFFSET)
            | (ColorId.DefaultBackground << MetadataConsts.BACKGROUND_OFFSET)
        );

        return new EncodedTokenizationResult(tokens, state == null ? NullState : state);
    }

}
