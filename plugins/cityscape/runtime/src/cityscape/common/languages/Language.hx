// Ported from vscode src/vs/editor/common/languages/language.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.Event;

/**
 * A language chosen for a model, which can change (`onDidChange`).
 *
 * TODO(step 1): language.ts (`ILanguageService`) comes with the language
 * registry, as a field of the `Cityscape` context.
 */
interface ILanguageSelection {
    final languageId:String;
    final onDidChange:Event<String>;
}
