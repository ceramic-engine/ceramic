// Ported from vscode src/vs/editor/common/core/wordHelper.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

/**
 * Word information.
 */
typedef IWordAtPosition = {
    /**
     * The word.
     */
    final word:String;
    /**
     * The column where the word starts.
     */
    final startColumn:Int;
    /**
     * The column where the word ends.
     */
    final endColumn:Int;
}

/**
 * Module values of wordHelper.ts.
 *
 * TODO(step 1): `DEFAULT_WORD_REGEXP`, `ensureValidWordDefinition` and
 * `getWordAtText` come with the model (they need the regular expression
 * engine chosen there).
 */
class WordHelper {

    public static inline final USUAL_WORD_SEPARATORS = "`~!@#$%^&*()-=+[{]}\\|;:'\",.<>/?";

}
