// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;

/*
 * The `inlineSuggest` editor option (`#region inlineSuggest` of
 * editorOptions.ts), ported with the inline completions contribution.
 * Registered by `EditorOptions.init()` through
 * `EditorLanguageFeatureOptionsRegistration.registerSimple`.
 */

typedef IInlineSuggestOptions = {
    /**
     * Enable or disable the rendering of automatic inline completions.
     */
    @:optional var enabled:Bool;

    /**
     * Configures the mode: `'prefix'`, `'subword'` or `'subwordSmart'`.
     * Use `prefix` to only show ghost text if the text to replace is a prefix of the suggestion text.
     * Use `subword` to only show ghost text if the replace text is a subword of the suggestion text.
     * Use `subwordSmart` to only show ghost text if the replace text is a subword of the suggestion text, but the subword must start after the cursor position.
     * Defaults to `subwordSmart`.
     */
    @:optional var mode:String;

    /**
     * `'always'`, `'onHover'` or `'never'` (the toolbar is not ported).
     */
    @:optional var showToolbar:String;

    @:optional var suppressSuggestions:Bool;

    /**
     * Does not clear active inline suggestions when the editor loses focus.
     */
    @:optional var keepOnBlur:Bool;

    /**
     * Font family for inline suggestions (`'default'`: the editor's).
     */
    @:optional var fontFamily:String;
}

/**
 * @internal
 */
typedef InternalInlineSuggestOptions = {
    final enabled:Bool;
    final mode:String;
    final showToolbar:String;
    final suppressSuggestions:Bool;
    final keepOnBlur:Bool;
    final fontFamily:String;
}

/**
 * Configuration options for inline suggestions
 */
class InlineEditorSuggest extends BaseEditorOption<InternalInlineSuggestOptions> {

    public function new() {
        final defaults:InternalInlineSuggestOptions = {
            enabled: true,
            mode: 'subwordSmart',
            showToolbar: 'onHover',
            suppressSuggestions: false,
            keepOnBlur: false,
            fontFamily: 'default'
        };
        super(EditorOption.inlineSuggest, 'inlineSuggest', defaults);
    }

    public function validate(_input:Any):InternalInlineSuggestOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            enabled: EditorOptions.boolean(JsValues.field(input, 'enabled'), this.defaultValue.enabled),
            mode: EditorOptions.stringSet(JsValues.field(input, 'mode'), this.defaultValue.mode, ['prefix', 'subword', 'subwordSmart']),
            showToolbar: EditorOptions.stringSet(JsValues.field(input, 'showToolbar'), this.defaultValue.showToolbar, ['always', 'onHover', 'never']),
            suppressSuggestions: EditorOptions.boolean(JsValues.field(input, 'suppressSuggestions'), this.defaultValue.suppressSuggestions),
            keepOnBlur: EditorOptions.boolean(JsValues.field(input, 'keepOnBlur'), this.defaultValue.keepOnBlur),
            fontFamily: EditorStringOption.string(JsValues.field(input, 'fontFamily'), this.defaultValue.fontFamily)
        };
    }

}

class EditorInlineSuggestOptionsRegistration {

    /**
     * Registers the `inlineSuggest` option (called by `EditorOptions.init()`).
     */
    public static function registerSimple(register:(option:IEditorOption<Any>) -> Void):Void {
        register(cast new InlineEditorSuggest());
    }

}
