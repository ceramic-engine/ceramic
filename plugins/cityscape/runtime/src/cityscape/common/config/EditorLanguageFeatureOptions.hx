// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorOptions.AnyEditorOption;

/*
 * The options of the language feature contributions (suggest, code
 * actions), registered by `EditorOptions.init()` with the others.
 */

/**
 * `'off'`, `'onCode'` or `'on'` (Monaco's `ShowLightbulbIconMode`).
 */
typedef ShowLightbulbIconMode = String;

/**
 * Configuration options for editor lightbulb
 */
typedef IEditorLightbulbOptions = {
    /**
     * Enable the lightbulb code action: `'off'`, `'onCode'` (the default)
     * or `'on'`.
     */
    @:optional var enabled:ShowLightbulbIconMode;
}

typedef EditorLightbulbOptions = {
    final enabled:ShowLightbulbIconMode;
}

class EditorLightbulb extends BaseEditorOption<EditorLightbulbOptions> {

    public function new() {
        super(EditorOption.lightbulb, 'lightbulb', {enabled: 'onCode'});
    }

    public function validate(_input:Any):EditorLightbulbOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        return {
            enabled: EditorOptions.stringSet(JsValues.field(_input, 'enabled'), this.defaultValue.enabled, ['off', 'onCode', 'on'])
        };
    }

}

class EditorLanguageFeatureOptionsRegistration {

    /**
     * Registers the options (called by `EditorOptions.init()`).
     */
    public static function registerSimple(register:(option:AnyEditorOption) -> Void):Void {
        register(cast new EditorBooleanOption(EditorOption.acceptSuggestionOnCommitCharacter, 'acceptSuggestionOnCommitCharacter', true));
        register(cast new EditorLightbulb());
        register(cast new EditorStringEnumOption(EditorOption.snippetSuggestions, 'snippetSuggestions', 'inline', ['top', 'bottom', 'inline', 'none']));
        register(cast new EditorIntOption(EditorOption.suggestFontSize, 'suggestFontSize', 0, 0, 1000));
        register(cast new EditorIntOption(EditorOption.suggestLineHeight, 'suggestLineHeight', 0, 0, 1000));
        register(cast new EditorStringEnumOption(EditorOption.suggestSelection, 'suggestSelection', 'first', ['first', 'recentlyUsed', 'recentlyUsedByPrefix']));
        // peek view (cs7-rest)
        register(cast new EditorStringEnumOption(EditorOption.peekWidgetDefaultFocus, 'peekWidgetDefaultFocus', 'tree', ['tree', 'editor']));
        // Color decorators (step 7, cs7-rest-links)
        cityscape.common.config.EditorColorDecoratorsOptions.EditorColorDecoratorsOptionsRegistration.registerSimple(register);
        // Inlay hints and code lens (step 7, cs7-rest-inlay)
        cityscape.common.config.EditorInlayHintsCodeLensOptions.EditorInlayHintsCodeLensOptionsRegistration.registerSimple(register);
        register(cast new cityscape.common.config.EditorParameterHintsOptions.EditorParameterHints()); // parameterHints (step 7, cs7-rest-snip)
        cityscape.common.config.EditorInlineSuggestOptions.EditorInlineSuggestOptionsRegistration.registerSimple(register); // inline completions (cs7-rest-inline)
    }

}
