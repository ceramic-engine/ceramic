// Ported from vscode src/vs/editor/common/tokens/contiguousMultilineTokensBuilder.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.tokens;

import haxe.io.UInt32Array;

/**
 * Collects the tokens of consecutive lines into `ContiguousMultilineTokens`.
 * The binary serialization of Monaco is not ported.
 */
class ContiguousMultilineTokensBuilder {

    final _tokens:Array<ContiguousMultilineTokens>;

    public function new() {
        _tokens = [];
    }

    public function add(lineNumber:Int, lineTokens:UInt32Array):Void {
        if (_tokens.length > 0) {
            final last = _tokens[_tokens.length - 1];
            if (last.endLineNumber + 1 == lineNumber) {
                // append
                last.appendLineTokens(lineTokens);
                return;
            }
        }
        _tokens.push(new ContiguousMultilineTokens(lineNumber, [lineTokens]));
    }

    // Monaco's `finalize()`: named `finalizeResult` because the C# target (Unity)
    // reserves `finalize` for a `Void->Void` finalizer.
    public function finalizeResult():Array<ContiguousMultilineTokens> {
        return _tokens;
    }

}
