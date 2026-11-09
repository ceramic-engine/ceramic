// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.EncodedTokenAttributes.LanguageId;

/**
 * Types of languages.ts (the provider registries and language features).
 *
 * TODO(step 1): only what the frozen interfaces need so far.
 */

/**
 * Encodes and decodes language ids to and from the numbers stored in tokens.
 */
interface ILanguageIdCodec {
    function encodeLanguageId(languageId:String):LanguageId;
    function decodeLanguageId(languageId:LanguageId):String;
}

/**
 * Interface used to format a model
 */
typedef FormattingOptions = {
    /**
     * Size of a tab in spaces.
     */
    var tabSize:Int;
    /**
     * Prefer spaces over tabs.
     */
    var insertSpaces:Bool;
}
