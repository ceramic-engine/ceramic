// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

/*
 * The enums of languages.ts whose value names hide Haxe types (`Type`,
 * `Text`) when imported: kept out of `cityscape.common.Languages`. Import
 * the one needed (`import cityscape.common.languages.LanguageKinds.InlayHintKind;`).
 */

enum abstract InlayHintKind(Int) from Int to Int {
    var Type = 1;
    var Parameter = 2;
}
