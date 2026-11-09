// Ported from vscode src/vs/editor/common/languages/modesRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.languages.Language.ILanguageExtensionPoint;

/**
 * The languages registered in a `Cityscape` context (Monaco's global
 * `ModesRegistry`). Plain text is registered when it is created.
 */
class EditorModesRegistry {

    public static inline final PLAINTEXT_LANGUAGE_ID = 'plaintext';

    public static inline final PLAINTEXT_EXTENSION = '.txt';

    final _languages:Array<ILanguageExtensionPoint>;

    final _onDidChangeLanguages = new VoidEmitter();

    public final onDidChangeLanguages:VoidEvent;

    public function new() {
        _languages = [];
        onDidChangeLanguages = _onDidChangeLanguages.event;
        registerLanguage({
            id: PLAINTEXT_LANGUAGE_ID,
            extensions: [PLAINTEXT_EXTENSION],
            aliases: ['Plain Text', 'text'],
            mimetypes: ['text/plain']
        });
    }

    public function registerLanguage(def:ILanguageExtensionPoint):IDisposable {
        _languages.push(def);
        _onDidChangeLanguages.fire();
        return Lifecycle.toDisposable(() -> {
            for (i in 0..._languages.length) {
                if (_languages[i] == def) {
                    _languages.splice(i, 1);
                    return;
                }
            }
        });
    }

    public function getLanguages():Array<ILanguageExtensionPoint> {
        return _languages;
    }

}
