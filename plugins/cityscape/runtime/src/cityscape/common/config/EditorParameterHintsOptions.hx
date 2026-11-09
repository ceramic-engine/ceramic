// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;

/*
 * The `parameterHints` editor option (`#region parameterHints` of
 * editorOptions.ts), ported with the parameter hints contribution.
 * Registered by `EditorOptions.init()` through
 * `EditorLanguageFeatureOptionsRegistration.registerSimple()`.
 */

/**
 * Configuration options for parameter hints
 */
typedef IEditorParameterHintOptions = {
    /**
     * Enable parameter hints.
     * Defaults to true.
     */
    @:optional var enabled:Bool;
    /**
     * Enable cycling of parameter hints.
     * Defaults to false.
     */
    @:optional var cycle:Bool;
}

/**
 * @internal
 */
typedef InternalParameterHintOptions = {
    final enabled:Bool;
    final cycle:Bool;
}

class EditorParameterHints extends BaseEditorOption<InternalParameterHintOptions> {

    public function new() {
        final defaults:InternalParameterHintOptions = {
            enabled: true,
            cycle: true
        };
        super(EditorOption.parameterHints, 'parameterHints', defaults);
    }

    public function validate(_input:Any):InternalParameterHintOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            enabled: EditorOptions.boolean(JsValues.field(input, 'enabled'), this.defaultValue.enabled),
            cycle: EditorOptions.boolean(JsValues.field(input, 'cycle'), this.defaultValue.cycle)
        };
    }

}
