// Ported from vscode src/vs/editor/test/common/modesTestUtils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.languages.Supports;
import cityscape.common.services.LanguagesRegistry.LanguageIdCodec;
import cityscape.common.tokens.LineTokens;
import haxe.io.UInt32Array;

typedef TokenText = {
    final text:String;
    final type:StandardTokenType;
}

class ModesTestUtils {

    public static function createFakeScopedLineTokens(rawTokens:Array<TokenText>):ScopedLineTokens {
        // Without tokens, vscode reads past the end of an empty Uint32Array (undefined, read
        // as 0: language 0, StandardTokenType.Other). A typed array read out of bounds
        // throws on C# and is undefined on hxcpp: one zero token gives the same values
        // (the single token of an empty line, `LineTokens.createEmpty`).
        final tokens = new UInt32Array(rawTokens.length == 0 ? 2 : rawTokens.length << 1);
        var line = '';

        for (i in 0...rawTokens.length) {
            final rawToken = rawTokens[i];

            final startOffset = line.length;
            final metadata = (
                (rawToken.type << MetadataConsts.TOKEN_TYPE_OFFSET)
            ) >>> 0;

            tokens[(i << 1)] = startOffset;
            tokens[(i << 1) + 1] = metadata;
            line += rawToken.text;
        }

        LineTokens.convertToEndOffset(tokens, line.length);
        return Supports.createScopedLineTokens(new LineTokens(tokens, line, new LanguageIdCodec()), 0);
    }

}
