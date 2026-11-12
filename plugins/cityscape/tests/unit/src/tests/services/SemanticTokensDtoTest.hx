// Ported from vscode src/vs/editor/test/common/services/semanticTokensDto.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.services;

import cityscape.common.services.SemanticTokensDto;
import haxe.io.Bytes;
import haxe.io.UInt32Array;
import cityscape.common.tokens.UInt32Arrays;
import testing.TestCase;

/**
 * vscode's suite `SemanticTokensDto`. Monaco's `VSBuffer` is
 * `haxe.io.Bytes`: `issue #94521: unusual backing array buffer` wraps the
 * encoded bytes in a larger buffer and decodes a slice of it (a copy here,
 * `Bytes.sub`; the decoder reads bytes, alignment does not matter).
 */
class SemanticTokensDtoTest extends TestCase {

    static function toArr(arr:Null<UInt32Array>):Null<Array<Int>> {
        if (arr == null) {
            return null;
        }
        return [for (i in 0...arr.length) (arr[i] : Int)];
    }

    function convert(dto:ISemanticTokensDto):Dynamic {
        if (dto.type == 'full') {
            return {id: dto.id, type: dto.type, data: toArr(dto.data)};
        }
        return {
            id: dto.id,
            type: dto.type,
            deltas: [for (delta in dto.deltas) {start: delta.start, deleteCount: delta.deleteCount, data: toArr(delta.data)}]
        };
    }

    function doTestRoundTrip(value:ISemanticTokensDto):Void {
        final decoded = SemanticTokensDto.decodeSemanticTokensDto(SemanticTokensDto.encodeSemanticTokensDto(value));
        if (value.type != decoded.type) {
            fail('wrong type');
        }
        assertDeepEquals(convert(value), convert(decoded));
    }

    function testFullEncoding() {
        doTestRoundTrip({
            id: 12,
            type: 'full',
            data: UInt32Arrays.fromInts([(1 << 24) + (2 << 16) + (3 << 8) + 4])
        });
    }

    function testDeltaEncoding() {
        doTestRoundTrip({
            id: 12,
            type: 'delta',
            deltas: [{
                start: 0,
                deleteCount: 4,
                data: null
            }, {
                start: 15,
                deleteCount: 0,
                data: UInt32Arrays.fromInts([(1 << 24) + (2 << 16) + (3 << 8) + 4])
            }, {
                start: 27,
                deleteCount: 5,
                data: UInt32Arrays.fromInts([(1 << 24) + (2 << 16) + (3 << 8) + 4, 1, 2, 3, 4, 5, 6, 7, 8, 9])
            }]
        });
    }

    function testPartialArrayBuffer() {
        final sharedArr = UInt32Arrays.fromInts([
            (1 << 24) + (2 << 16) + (3 << 8) + 4,
            1, 2, 3, 4, 5, (1 << 24) + (2 << 16) + (3 << 8) + 4
        ]);
        doTestRoundTrip({
            id: 12,
            type: 'delta',
            deltas: [{
                start: 0,
                deleteCount: 4,
                data: sharedArr.subarray(0, 1)
            }, {
                start: 15,
                deleteCount: 0,
                data: sharedArr.subarray(1, sharedArr.length)
            }]
        });
    }

    function testIssue94521UnusualBackingArrayBuffer() {
        function wrapAndSlice(buff:Bytes, prefixLength:Int, suffixLength:Int):Bytes {
            final wrapped = Bytes.alloc(prefixLength + buff.length + suffixLength);
            wrapped.blit(prefixLength, buff, 0, buff.length);
            return wrapped.sub(prefixLength, buff.length);
        }
        final dto:ISemanticTokensDto = {
            id: 5,
            type: 'full',
            data: UInt32Arrays.fromInts([1, 2, 3, 4, 5])
        };
        final encoded = SemanticTokensDto.encodeSemanticTokensDto(dto);

        // with misaligned prefix and misaligned suffix
        assertDeepEquals(convert(dto), convert(SemanticTokensDto.decodeSemanticTokensDto(wrapAndSlice(encoded, 1, 1))));
        // with misaligned prefix and aligned suffix
        assertDeepEquals(convert(dto), convert(SemanticTokensDto.decodeSemanticTokensDto(wrapAndSlice(encoded, 1, 4))));
        // with aligned prefix and misaligned suffix
        assertDeepEquals(convert(dto), convert(SemanticTokensDto.decodeSemanticTokensDto(wrapAndSlice(encoded, 4, 1))));
        // with aligned prefix and aligned suffix
        assertDeepEquals(convert(dto), convert(SemanticTokensDto.decodeSemanticTokensDto(wrapAndSlice(encoded, 4, 4))));
    }

}
