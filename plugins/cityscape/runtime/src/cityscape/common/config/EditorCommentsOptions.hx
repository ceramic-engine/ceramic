// Ported from vscode src/vs/editor/common/config/editorOptions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorOptions.AnyEditorOption;

/*
 * The `comments` editor option (`#region comments` of editorOptions.ts),
 * ported with the comment contribution. Registered by `EditorOptions.init()`
 * through `registerSimple()` below.
 */

/**
 * Configuration options for editor comments
 */
typedef IEditorCommentsOptions = {
    /**
     * Insert a space after the line comment token and inside the block comments tokens.
     * Defaults to true.
     */
    @:optional var insertSpace:Bool;
    /**
     * Ignore empty lines when inserting line comments.
     * Defaults to true.
     */
    @:optional var ignoreEmptyLines:Bool;
}

/**
 * @internal
 */
typedef EditorCommentsOptions = {
    final insertSpace:Bool;
    final ignoreEmptyLines:Bool;
}

class EditorComments extends BaseEditorOption<EditorCommentsOptions> {

    public function new() {
        final defaults:EditorCommentsOptions = {
            insertSpace: true,
            ignoreEmptyLines: true,
        };
        super(EditorOption.comments, 'comments', defaults);
    }

    public function validate(_input:Any):EditorCommentsOptions {
        if (!JsValues.truthy(_input) || !JsValues.isObject(_input)) {
            return this.defaultValue;
        }
        final input = _input;
        return {
            insertSpace: EditorOptions.boolean(JsValues.field(input, 'insertSpace'), this.defaultValue.insertSpace),
            ignoreEmptyLines: EditorOptions.boolean(JsValues.field(input, 'ignoreEmptyLines'), this.defaultValue.ignoreEmptyLines),
        };
    }

}

class EditorCommentsOptionsRegistration {

    /**
     * Registers the `comments` option (called by `EditorOptions.init()`).
     */
    public static function registerSimple(register:(option:AnyEditorOption) -> Void):Void {
        register(cast new EditorComments());
    }

}
