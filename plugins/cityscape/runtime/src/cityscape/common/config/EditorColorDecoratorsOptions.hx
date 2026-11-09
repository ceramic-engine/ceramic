// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.common.config.EditorOptions;

/**
 * `'clickAndHover'`, `'hover'` or `'click'`: what opens the color picker
 * from a color decorator (Monaco's `colorDecoratorsActivatedOn`).
 */
typedef EditorColorDecoratorsActivatedOn = String;

/**
 * The options of the color decorators (contrib/colorPicker), registered by
 * `EditorOptions.init()` with the others: `colorDecoratorsLimit`,
 * `defaultColorDecorators`, `colorDecoratorsActivatedOn`.
 */
class EditorColorDecoratorsOptionsRegistration {

    public static function registerSimple(register:(option:IEditorOption<Any>) -> Void):Void {
        register(cast new EditorStringEnumOption(EditorOption.colorDecoratorsActivatedOn, 'colorDecoratorsActivatedOn', 'clickAndHover', ['clickAndHover', 'hover', 'click']));
        register(cast new EditorIntOption(EditorOption.colorDecoratorsLimit, 'colorDecoratorsLimit', 500, 1, 1000000));
        register(cast new EditorBooleanOption(EditorOption.defaultColorDecorators, 'defaultColorDecorators', false));
    }

}
