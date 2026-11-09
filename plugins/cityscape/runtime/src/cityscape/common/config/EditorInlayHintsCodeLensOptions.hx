// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;

/*
 * The options of the inlay hints and code lens contributions (`inlayHints`,
 * `codeLens`, `codeLensFontFamily`, `codeLensFontSize`), registered by
 * `EditorOptions.init()` with the others.
 */

/**
 * Configuration options for editor inlay hints.
 */
typedef IEditorInlayHintsOptions = {
    /**
     * Enable the inline hints: `'on'` (the default), `'off'`,
     * `'offUnlessPressed'` or `'onUnlessPressed'` (a boolean is turned into
     * `'on'` or `'off'`).
     */
    @:optional var enabled:Any;
    /**
     * Font size of inline hints.
     * Default to 90% of the editor font size.
     */
    @:optional var fontSize:Int;
    /**
     * Font family of inline hints.
     * Defaults to editor font family.
     */
    @:optional var fontFamily:String;
    /**
     * Enables the padding around the inlay hint.
     * Defaults to false.
     */
    @:optional var padding:Bool;
}

/**
 * The validated inlay hints options (Monaco's `EditorInlayHintsOptions`).
 */
typedef EditorInlayHintsOptions = {
    /**
     * `'on'`, `'off'`, `'offUnlessPressed'` or `'onUnlessPressed'`.
     */
    final enabled:String;
    final fontSize:Int;
    final fontFamily:String;
    final padding:Bool;
}

class EditorInlayHints extends BaseEditorOption<EditorInlayHintsOptions> {

    public function new() {
        super(EditorOption.inlayHints, 'inlayHints', {enabled: 'on', fontSize: 0, fontFamily: '', padding: false});
    }

    public function validate(_input:Any):EditorInlayHintsOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        var enabled:Any = JsValues.field(_input, 'enabled');
        if (JsValues.isBoolean(enabled)) {
            // Monaco writes the converted value back into the input
            enabled = (enabled : Bool) ? 'on' : 'off';
        }
        return {
            enabled: EditorOptions.stringSet(enabled, this.defaultValue.enabled, ['on', 'off', 'offUnlessPressed', 'onUnlessPressed']),
            fontSize: EditorIntOption.clampedInt(JsValues.field(_input, 'fontSize'), this.defaultValue.fontSize, 0, 100),
            fontFamily: EditorStringOption.string(JsValues.field(_input, 'fontFamily'), this.defaultValue.fontFamily),
            padding: EditorOptions.boolean(JsValues.field(_input, 'padding'), this.defaultValue.padding)
        };
    }

}

class EditorInlayHintsCodeLensOptionsRegistration {

    /**
     * Registers the options (called by `EditorOptions.init()`).
     */
    public static function registerSimple(register:(option:IEditorOption<Any>) -> Void):Void {
        register(cast new EditorBooleanOption(EditorOption.codeLens, 'codeLens', true));
        register(cast new EditorStringOption(EditorOption.codeLensFontFamily, 'codeLensFontFamily', ''));
        register(cast new EditorIntOption(EditorOption.codeLensFontSize, 'codeLensFontSize', 0, 0, 100));
        register(cast new EditorInlayHints());
    }

}
