// Ported from vscode src/vs/editor/common/services/semanticTokensDto.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import haxe.io.Bytes;
import haxe.io.UInt32Array;

typedef ISemanticTokensDelta = {
    var start:Int;
    var deleteCount:Int;
    @:optional var data:Null<UInt32Array>;
}

/**
 * Monaco's `IFullSemanticTokensDto | IDeltaSemanticTokensDto`: `type` is
 * `'full'` (with `data`) or `'delta'` (with `deltas`).
 */
typedef ISemanticTokensDto = {
    var id:Int;
    var type:String;
    @:optional var data:Null<UInt32Array>;
    @:optional var deltas:Null<Array<ISemanticTokensDelta>>;
}

/**
 * The encoding of semantic tokens in a buffer (Monaco's `VSBuffer` is
 * `haxe.io.Bytes`): 32 bit little endian numbers on every target.
 */
class SemanticTokensDto {

    static inline final Full = 1;
    static inline final Delta = 2;

    public static function encodeSemanticTokensDto(semanticTokens:ISemanticTokensDto):Bytes {
        final dest = new UInt32Array(encodeSemanticTokensDtoSize(semanticTokens));
        var offset = 0;
        dest[offset++] = semanticTokens.id;
        if (semanticTokens.type == 'full') {
            final data = semanticTokens.data;
            dest[offset++] = Full;
            dest[offset++] = data.length;
            for (i in 0...data.length) {
                dest[offset++] = data[i];
            }
        }
        else {
            dest[offset++] = Delta;
            dest[offset++] = semanticTokens.deltas.length;
            for (delta in semanticTokens.deltas) {
                dest[offset++] = delta.start;
                dest[offset++] = delta.deleteCount;
                final data = delta.data;
                if (data != null) {
                    dest[offset++] = data.length;
                    for (i in 0...data.length) {
                        dest[offset++] = data[i];
                    }
                }
                else {
                    dest[offset++] = 0;
                }
            }
        }
        return toLittleEndianBuffer(dest);
    }

    static function toLittleEndianBuffer(arr:UInt32Array):Bytes {
        final bytes = Bytes.alloc(arr.length * 4);
        for (i in 0...arr.length) {
            bytes.setInt32(i * 4, (arr[i] : Int));
        }
        return bytes;
    }

    static function fromLittleEndianBuffer(buff:Bytes):UInt32Array {
        final length = Std.int(buff.length / 4);
        final result = new UInt32Array(length);
        for (i in 0...length) {
            result[i] = buff.getInt32(i * 4);
        }
        return result;
    }

    static function encodeSemanticTokensDtoSize(semanticTokens:ISemanticTokensDto):Int {
        var result = 0;
        result += 1 // id
            + 1; // type
        if (semanticTokens.type == 'full') {
            result += 1 // data length
                + semanticTokens.data.length;
        }
        else {
            result += 1; // delta count
            result += (1 // start
                + 1 // deleteCount
                + 1 // data length
            ) * semanticTokens.deltas.length;
            for (delta in semanticTokens.deltas) {
                if (delta.data != null) {
                    result += delta.data.length;
                }
            }
        }
        return result;
    }

    public static function decodeSemanticTokensDto(buff:Bytes):ISemanticTokensDto {
        final src = fromLittleEndianBuffer(buff);
        var offset = 0;
        final id:Int = src[offset++];
        final type:Int = src[offset++];
        if (type == Full) {
            final length:Int = src[offset++];
            final data = src.subarray(offset, offset + length);
            offset += length;
            return {
                id: id,
                type: 'full',
                data: data
            };
        }
        final deltaCount:Int = src[offset++];
        final deltas:Array<ISemanticTokensDelta> = [];
        for (i in 0...deltaCount) {
            final start:Int = src[offset++];
            final deleteCount:Int = src[offset++];
            final length:Int = src[offset++];
            var data:Null<UInt32Array> = null;
            if (length > 0) {
                data = src.subarray(offset, offset + length);
                offset += length;
            }
            deltas[i] = {start: start, deleteCount: deleteCount, data: data};
        }
        return {
            id: id,
            type: 'delta',
            deltas: deltas
        };
    }

}
