// Ported from vscode src/vs/editor/common/services/semanticTokensStylingService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Languages.DocumentRangeSemanticTokensProvider;
import cityscape.common.Languages.DocumentSemanticTokensProvider;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.Languages.SemanticTokensLegend;
import cityscape.common.services.SemanticTokensProviderStyling.ISemanticTokensThemeService;
import cityscape.common.services.SemanticTokensStyling.DocumentTokensProvider;
import cityscape.common.services.SemanticTokensStyling.ISemanticTokensStylingService;
import haxe.ds.ObjectMap;

/**
 * The styling of each semantic tokens provider, created on first use and
 * forgotten when the theme changes (Monaco keeps them in a `WeakMap`; the
 * map here is cleared with the theme, and holds the providers until then).
 */
class SemanticTokensStylingService extends Disposable implements ISemanticTokensStylingService {

    final _themeService:ISemanticTokensThemeService;
    final _languageIdCodec:ILanguageIdCodec;
    var _caches:ObjectMap<{}, SemanticTokensProviderStyling>;

    /**
     * `onDidColorThemeChange`: the theme service's event (Monaco reads it
     * from the theme service).
     */
    public function new(themeService:ISemanticTokensThemeService, onDidColorThemeChange:Null<VoidEvent>, languageIdCodec:ILanguageIdCodec) {
        super();
        this._themeService = themeService;
        this._languageIdCodec = languageIdCodec;
        this._caches = new ObjectMap();
        if (onDidColorThemeChange != null) {
            this._register(onDidColorThemeChange(() -> {
                this._caches = new ObjectMap();
            }));
        }
    }

    public function getStyling(provider:DocumentTokensProvider):SemanticTokensProviderStyling {
        final key:{} = cast provider;
        var styling = this._caches.get(key);
        if (styling == null) {
            styling = new SemanticTokensProviderStyling(legendOf(provider), this._themeService, this._languageIdCodec);
            this._caches.set(key, styling);
        }
        return styling;
    }

    static function legendOf(provider:DocumentTokensProvider):SemanticTokensLegend {
        if (Std.isOfType(provider, DocumentSemanticTokensProvider)) {
            final document:DocumentSemanticTokensProvider = cast provider;
            return document.getLegend();
        }
        final range:DocumentRangeSemanticTokensProvider = cast provider;
        return range.getLegend();
    }

}
