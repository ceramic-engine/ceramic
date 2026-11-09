// Ported from vscode src/vs/editor/contrib/semanticTokens/common/semanticTokensConfig.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.semanticTokens.common;

import cityscape.base.common.JsValues;
import cityscape.common.Model.ITextModel;
import cityscape.platform.configuration.common.Configuration.IConfigurationService;
import cityscape.platform.theme.common.ThemeService.IColorTheme;

/**
 * `IEditorSemanticHighlightingOptions`: `enabled` is `true`, `false` or
 * `'configuredByTheme'` (the default).
 */
typedef IEditorSemanticHighlightingOptions = {
    var enabled:Any;
}

class SemanticTokensConfig {

    public static inline final SEMANTIC_HIGHLIGHTING_SETTING_ID = 'editor.semanticHighlighting';

    /**
     * Whether semantic tokens color `model`: the
     * `editor.semanticHighlighting.enabled` setting of the configuration
     * when it is a boolean, else (`'configuredByTheme'`) the theme's
     * `semanticHighlighting`. The standalone configuration has no language
     * or resource overrides.
     */
    public static function isSemanticColoringEnabled(model:ITextModel, theme:IColorTheme, configurationService:IConfigurationService):Bool {
        final options:Any = configurationService.getValue(SEMANTIC_HIGHLIGHTING_SETTING_ID);
        final setting:Any = options != null && JsValues.isObject(options) ? JsValues.field(options, 'enabled') : null;
        if (JsValues.isBoolean(setting)) {
            return (setting : Bool);
        }
        return theme.semanticHighlighting;
    }

}
