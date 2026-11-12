package tests.model;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.services.LanguagesRegistry.LanguageIdCodec;
import cityscape.common.tokens.LineTokens;
import haxe.io.UInt32Array;
import testing.TestCase;

/**
 * Metadata reads past the last token (Cityscape tests, not ported). vscode's
 * `IndentationLineProcessor.getProcessedTokens` asks for the language of
 * token 0 of an empty slice (Enter at the start of a line with indentation
 * rules): JavaScript reads `undefined`, 0 in the bit operations. On C# the
 * read threw, so the Enter was lost (reported as an unexpected error).
 */
class LineTokensBoundsTest extends TestCase {

    function testMetadataOfNoTokens() {
        final codec = new LanguageIdCodec();
        final tokens = new LineTokens(new UInt32Array(0), '', codec);
        assertEquals(0, tokens.getCount());
        assertEquals(codec.decodeLanguageId(0), tokens.getLanguageId(0));
        assertEquals(StandardTokenType.Other, tokens.getStandardTokenType(0));
        assertEquals(0, tokens.getMetadata(0));
    }

}
